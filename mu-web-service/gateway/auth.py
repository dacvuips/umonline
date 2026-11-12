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
