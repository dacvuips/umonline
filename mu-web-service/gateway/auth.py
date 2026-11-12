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
