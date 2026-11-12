"""Xác thực đăng nhập của gateway bằng CSDL OpenMU (data."Account", BCrypt) - cùng kho tài khoản với trang web.

Bật khi có biến môi trường DB_HOST (+ DB_PASSWORD, tuỳ chọn DB_PORT / DB_USER / DB_NAME).
Mọi lỗi (CSDL không truy cập được, hash lạ...) đều bị coi là đăng nhập THẤT BẠI (đóng cửa khi lỗi).
"""
import logging
import os
import threading
import time

log = logging.getLogger("mu-gateway")

ENABLED = bool(os.environ.get("DB_HOST"))
BANNED_STATES = (4, 5)          # Banned, TemporarilyBanned
FAIL_LIMIT, FAIL_WINDOW = 8, 300  # tối đa 8 lần sai / 5 phút cho mỗi (ip, tài khoản)

_failures: dict = {}
_lock = threading.Lock()

# Token phiên: cấp khi đăng nhập đúng, client gửi lại trong khung "join" của kênh người chơi (kết nối thứ hai, không mang mật khẩu).
# Không dùng IP để nhận diện vì reverse proxy phía trước làm mọi người chơi trông như cùng một IP.
TOKEN_TTL = 12 * 3600
_tokens: dict = {}
REQUIRE_JOIN_TOKEN = os.environ.get("REQUIRE_JOIN_TOKEN", "0") == "1"   # bật sau khi mọi client đã cập nhật
MAX_CONN_PER_IP = int(os.environ.get("MAX_CONN_PER_IP", "20"))
MAX_CONN_TOTAL = int(os.environ.get("MAX_CONN_TOTAL", "3000"))
_conns: dict = {}


def issue_token(account: str) -> str:
    import secrets
    tok = secrets.token_urlsafe(16)
    now = time.time()
    with _lock:
        if len(_tokens) > 20000:
            for k in [k for k, v in _tokens.items() if v[1] < now]:
                _tokens.pop(k, None)
        _tokens[tok] = (account, now + TOKEN_TTL)
    return tok


def account_for_token(tok):
    """Tài khoản sở hữu token (còn hạn), hoặc None."""
    if not tok or not isinstance(tok, str):
        return None
    with _lock:
        ent = _tokens.get(tok)
    if ent and ent[1] > time.time():
        return ent[0]
    return None


def _private(ip: str) -> bool:
    return ip.startswith(("10.", "192.168.", "127.", "172.16.", "172.17.", "172.18.", "172.19.", "172.2", "172.30.", "172.31."))


def conn_open(ip: str) -> bool:
    """Giới hạn tổng số kết nối; giới hạn theo IP chỉ áp dụng cho IP công cộng (IP nội bộ là proxy, dùng chung)."""
    with _lock:
        total = sum(_conns.values())
        n = _conns.get(ip, 0)
        if total >= MAX_CONN_TOTAL or (not _private(ip) and n >= MAX_CONN_PER_IP):
            return False
        _conns[ip] = n + 1
        return True


def conn_close(ip: str) -> None:
    with _lock:
        n = _conns.get(ip, 0) - 1
        if n > 0:
            _conns[ip] = n
        else:
            _conns.pop(ip, None)


def _params():
    return dict(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "5432")),
        user=os.environ.get("DB_USER", "postgres"),
        password=os.environ.get("DB_PASSWORD", ""),
        database=os.environ.get("DB_NAME", "openmu"),
        timeout=8,
    )


def locked_out(ip: str, name: str) -> bool:
    now = time.time()
    key = (ip, name.lower())
    with _lock:
        hits = [t for t in _failures.get(key, []) if now - t < FAIL_WINDOW]
        _failures[key] = hits
        return len(hits) >= FAIL_LIMIT


def note_failure(ip: str, name: str) -> None:
    with _lock:
        if len(_failures) > 5000:
            now = time.time()
            for k in [k for k, v in _failures.items() if not any(now - t < FAIL_WINDOW for t in v)]:
                _failures.pop(k, None)
        _failures.setdefault((ip, name.lower()), []).append(time.time())


def check_password(name: str, password: str) -> bool:
    """Chạy đồng bộ (gọi qua asyncio.to_thread). True nếu đúng tên + mật khẩu và tài khoản không bị cấm."""
    if not name or not password:
        return False
    import bcrypt
    import pg8000.native
    conn = pg8000.native.Connection(**_params())
    try:
        # Game so tên phân biệt hoa/thường -> làm giống hệt.
        rows = conn.run('SELECT "PasswordHash","State" FROM data."Account" WHERE "LoginName" = :n', n=name)
    finally:
        conn.close()
    if not rows:
        log.info("login '%s': không có tài khoản", name)
        return False
    hashed, state = rows[0]
    try:
        ok = bcrypt.checkpw(password.encode("utf-8"), hashed.encode("ascii"))
    except ValueError:
        ok = False
    if not ok:
        log.info("login '%s': sai mật khẩu", name)
        return False
    if state in BANNED_STATES:
        log.info("login '%s': tài khoản bị cấm", name)
        return False
    return True


# ---------------------------------------------------------------- đăng ký tài khoản (từ trong game)
import re
import uuid

USER_RE = re.compile(r"^[A-Za-z0-9]{4,10}$")
REG_PER_IP, REG_GLOBAL, REG_WINDOW = 5, 100, 3600   # IP công cộng: 5/giờ; toàn hệ thống: 100/giờ
_reg_hits: list = []
_reg_ip: dict = {}


def reg_allowed(ip: str) -> bool:
    now = time.time()
    with _lock:
        _reg_hits[:] = [t for t in _reg_hits if now - t < REG_WINDOW]
        if len(_reg_hits) >= REG_GLOBAL:
            return False
        if not _private(ip):
            hits = [t for t in _reg_ip.get(ip, []) if now - t < REG_WINDOW]
            _reg_ip[ip] = hits
            if len(hits) >= REG_PER_IP:
                return False
        return True


def reg_note(ip: str) -> None:
    with _lock:
        _reg_hits.append(time.time())
        if not _private(ip):
            _reg_ip.setdefault(ip, []).append(time.time())


def register_account(name: str, password: str, email: str) -> int:
    """Tạo tài khoản trong OpenMU (đồng bộ; gọi qua asyncio.to_thread).
    Trả: 1 = thành công, 0 = dữ liệu không hợp lệ, 2 = tên đã có, 4 = lỗi máy chủ."""
    if not USER_RE.match(name) or not 6 <= len(password) <= 10 or not password.isprintable():
        return 0
    email = "".join(ch for ch in email if ch.isprintable())[:30]
    import bcrypt
    import pg8000.exceptions
    import pg8000.native
    pw_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(11)).decode("ascii")
    conn = pg8000.native.Connection(**_params())
    try:
        if conn.run('SELECT 1 FROM data."Account" WHERE lower("LoginName") = lower(:n)', n=name):
            return 2
        try:
            conn.run(
                'INSERT INTO data."Account" ("Id","LoginName","PasswordHash","SecurityCode","EMail",'
                '"LanguageIsoCode","RegistrationDate","State","TimeZone","VaultPassword","IsVaultExtended",'
                '"WCoinC","WCoinP","GoblinPoints","IsBot","IsNetworkObservationActive","IsTemplate") '
                "VALUES (:id,:n,:h,'',:e,'en',now(),0,0,'',false,0,0,0,false,false,false)",
                id=uuid.uuid4(), n=name, h=pw_hash, e=email,
            )
        except pg8000.exceptions.DatabaseError:
            return 2   # trùng tên do đăng ký đồng thời
        return 1
    finally:
        conn.close()
