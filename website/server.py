"""
Máy chủ trang web MU Online (chỉ dùng thư viện chuẩn của Python, không cần cài thêm gì).

  python server.py                 # chạy tại http://localhost:8000
  python server.py --port 80       # cổng khác
  python server.py --host 0.0.0.0  # cho máy khác trong mạng truy cập

  - Phục vụ các file tĩnh trong thư mục này (index.html, style.css, app.js, assets/).
  - Thư mục ./game/ (nếu có) là bản export HTML5 của game Godot -> nút "Chơi ngay".
  - API đăng ký / đăng nhập: /api/register, /api/login, /api/logout, /api/me
  - Tài khoản lưu ở data/accounts.json, mật khẩu băm bằng PBKDF2-SHA256 (không lưu mật khẩu thô).

Khi đặt biến môi trường DB_HOST (+ DB_PASSWORD, tuỳ chọn DB_PORT/DB_USER/DB_NAME), tài khoản được lưu thẳng
trong CSDL OpenMU (bảng data."Account", BCrypt) nên dùng chung cho web và game. Không có DB_HOST thì dùng
data/accounts.json như trước (chỉ để chạy thử trên máy).
"""

import argparse
import hashlib
import hmac
import json
import os
import re
import secrets
import threading
import time
import uuid
from http import cookies
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA_FILE = ROOT / "data" / "accounts.json"
SESSION_TTL = 7 * 24 * 3600
USER_RE = re.compile(r"^[A-Za-z0-9]{4,10}$")
PBKDF2_ROUNDS = 200_000
MAX_BODY = 4096

# Chặn dò mật khẩu: tối đa 8 lần sai trong 5 phút cho mỗi (địa chỉ IP, tài khoản)
FAIL_LIMIT, FAIL_WINDOW = 8, 300


class Accounts:
    def __init__(self, path: Path):
        self.path = path
        self.lock = threading.Lock()
        self.users = {}
        if path.exists():
            try:
                self.users = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                self.users = {}

    @staticmethod
    def _hash(password: str, salt: bytes) -> str:
        return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PBKDF2_ROUNDS).hex()

    def register(self, username: str, password: str) -> bool:
        key = username.lower()
        with self.lock:
            if key in self.users:
                return False
            salt = secrets.token_bytes(16)
            self.users[key] = {
                "name": username,
                "salt": salt.hex(),
                "hash": self._hash(password, salt),
                "created": int(time.time()),
            }
            self.path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.path.with_suffix(".tmp")
            tmp.write_text(json.dumps(self.users, ensure_ascii=False, indent=1), encoding="utf-8")
            os.replace(tmp, self.path)
            return True

    def verify(self, username: str, password: str):
        with self.lock:
            rec = self.users.get(username.lower())
        # luôn băm một lần để thời gian phản hồi không lộ tài khoản có tồn tại hay không
        salt = bytes.fromhex(rec["salt"]) if rec else b"\x00" * 16
        digest = self._hash(password, salt)
        if rec and hmac.compare_digest(digest, rec["hash"]):
            return rec["name"]
        return None


class OpenMuAccounts:
    """Tài khoản dùng CHUNG với game: đọc/ghi thẳng bảng data."Account" của OpenMU (Postgres).

    Mật khẩu băm BCrypt giống hệt OpenMU nên đăng ký ở web thì vào game được và ngược lại.
    Tài khoản cũ chỉ có ở accounts.json (đăng ký web trước đây) sẽ được chuyển sang OpenMU
    ngay lần đăng nhập đúng mật khẩu đầu tiên.
    """

    def __init__(self, legacy: Accounts):
        self.legacy = legacy
        self.params = dict(
            host=os.environ["DB_HOST"],
            port=int(os.environ.get("DB_PORT", "5432")),
            user=os.environ.get("DB_USER", "postgres"),
            password=os.environ.get("DB_PASSWORD", ""),
            database=os.environ.get("DB_NAME", "openmu"),
            timeout=8,
        )

    def _conn(self):
        import pg8000.native
        return pg8000.native.Connection(**self.params)

    @staticmethod
    def _bcrypt_hash(password: str) -> str:
        import bcrypt
        return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(11)).decode("ascii")

    @staticmethod
    def _bcrypt_ok(password: str, hashed: str) -> bool:
        import bcrypt
        try:
            return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("ascii"))
        except ValueError:
            return False

    def _insert(self, conn, username: str, pw_hash: str) -> bool:
        import pg8000.exceptions
        try:
            conn.run(
                'INSERT INTO data."Account" ("Id","LoginName","PasswordHash","SecurityCode","EMail",'
                '"LanguageIsoCode","RegistrationDate","State","TimeZone","VaultPassword","IsVaultExtended",'
                '"WCoinC","WCoinP","GoblinPoints","IsBot","IsNetworkObservationActive","IsTemplate") '
                "VALUES (:id,:n,:h,'','','en',now(),0,0,'',false,0,0,0,false,false,false)",
                id=uuid.uuid4(), n=username, h=pw_hash,
            )
            return True
        except pg8000.exceptions.DatabaseError:
            return False  # trùng tên (chỉ mục duy nhất) do đăng ký đồng thời

    def register(self, username: str, password: str) -> bool:
        conn = self._conn()
        try:
            if conn.run('SELECT 1 FROM data."Account" WHERE lower("LoginName") = lower(:n)', n=username):
                return False
            return self._insert(conn, username, self._bcrypt_hash(password))
        finally:
            conn.close()

    def verify(self, username: str, password: str):
        conn = self._conn()
        try:
            # Game so khớp tên phân biệt hoa thường -> web cũng vậy, để hai bên luôn đồng nhất.
            rows = conn.run('SELECT "LoginName","PasswordHash","State" FROM data."Account" WHERE "LoginName" = :n', n=username)
            if rows:
                name, hashed, state = rows[0]
                if self._bcrypt_ok(password, hashed) and state not in (4, 5):  # 4/5 = bị cấm
                    return name
                return None
            # Chưa có trong OpenMU: thử tài khoản web cũ rồi chuyển sang OpenMU.
            legacy_name = self.legacy.verify(username, password)
            if legacy_name and not conn.run('SELECT 1 FROM data."Account" WHERE lower("LoginName") = lower(:n)', n=legacy_name):
                if self._insert(conn, legacy_name, self._bcrypt_hash(password)):
                    return legacy_name
            return None
        finally:
            conn.close()


legacy_accounts = Accounts(DATA_FILE)
# Có DB_HOST -> dùng chung tài khoản với game (OpenMU). Không có (chạy thử trên máy) -> file JSON cục bộ.
accounts = OpenMuAccounts(legacy_accounts) if os.environ.get("DB_HOST") else legacy_accounts
sessions = {}  # token -> (tên, hết hạn)
failures = {}  # (ip, tên) -> [thời điểm lỗi]
state_lock = threading.Lock()


def too_many_failures(ip: str, name: str) -> bool:
    now = time.time()
    with state_lock:
        hits = [t for t in failures.get((ip, name.lower()), []) if now - t < FAIL_WINDOW]
        failures[(ip, name.lower())] = hits
        return len(hits) >= FAIL_LIMIT


def note_failure(ip: str, name: str) -> None:
    with state_lock:
        failures.setdefault((ip, name.lower()), []).append(time.time())


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    # ----- tiện ích -----
    def _json(self, status: int, obj: dict, extra_headers=None):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra_headers or []):
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        try:
            n = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        if n <= 0 or n > MAX_BODY:
            return None
        try:
            data = json.loads(self.rfile.read(n).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return None
        return data if isinstance(data, dict) else None

    def _session_user(self):
        raw = self.headers.get("Cookie", "")
        try:
            token = cookies.SimpleCookie(raw).get("mu_session")
        except cookies.CookieError:
            return None
        if not token:
            return None
        with state_lock:
            ent = sessions.get(token.value)
            if ent and ent[1] > time.time():
                return ent[0]
            sessions.pop(token.value, None)
        return None

    def _start_session(self, name: str):
        token = secrets.token_urlsafe(32)
        with state_lock:
            sessions[token] = (name, time.time() + SESSION_TTL)
        secure = "; Secure" if self.headers.get("X-Forwarded-Proto") == "https" else ""
        cookie = f"mu_session={token}; Path=/; HttpOnly; SameSite=Lax; Max-Age={SESSION_TTL}{secure}"
        return [("Set-Cookie", cookie)]

    def _same_origin(self) -> bool:
        origin = self.headers.get("Origin")
        return origin is None or origin.split("://", 1)[-1] == self.headers.get("Host")

    # ----- API -----
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/api/me":
            return self._json(200, {"username": self._session_user()})
        if path.startswith("/api/") or path.startswith("/data/") or path.endswith(".py"):
            return self._json(404, {"error": "Không tìm thấy."})
        return super().do_GET()

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if not self._same_origin():
            return self._json(403, {"error": "Yêu cầu không hợp lệ."})
        data = self._read_json()
        if data is None:
            return self._json(400, {"error": "Dữ liệu gửi lên không hợp lệ."})
        # Sau reverse proxy (NPM): proxy nối IP thật vào CUỐI X-Forwarded-For.
        xff = self.headers.get("X-Forwarded-For", "").split(",")[-1].strip()
        ip = xff or self.client_address[0]

        if path == "/api/register":
            name = str(data.get("username", "")).strip()
            pw = str(data.get("password", ""))
            if not USER_RE.match(name):
                return self._json(400, {"error": "Tên tài khoản gồm 4–10 chữ cái hoặc số, không dấu."})
            if not 6 <= len(pw) <= 20:
                return self._json(400, {"error": "Mật khẩu cần từ 6 đến 20 ký tự."})
            try:
                created = accounts.register(name, pw)
            except Exception as e:  # CSDL game không truy cập được
                print("[web] register lỗi CSDL:", repr(e))
                return self._json(503, {"error": "Máy chủ tài khoản đang bận, hãy thử lại sau."})
            if not created:
                return self._json(409, {"error": "Tên tài khoản đã có người dùng."})
            return self._json(200, {"username": name}, self._start_session(name))

        if path == "/api/login":
            name = str(data.get("username", "")).strip()
            pw = str(data.get("password", ""))
            if too_many_failures(ip, name):
                return self._json(429, {"error": "Đăng nhập sai quá nhiều lần. Hãy thử lại sau vài phút."})
            try:
                real = accounts.verify(name, pw) if name and pw else None
            except Exception as e:
                print("[web] login lỗi CSDL:", repr(e))
                return self._json(503, {"error": "Máy chủ tài khoản đang bận, hãy thử lại sau."})
            if not real:
                note_failure(ip, name)
                return self._json(401, {"error": "Sai tên tài khoản hoặc mật khẩu."})
            return self._json(200, {"username": real}, self._start_session(real))

        if path == "/api/logout":
            raw = self.headers.get("Cookie", "")
            try:
                token = cookies.SimpleCookie(raw).get("mu_session")
            except cookies.CookieError:
                token = None
            if token:
                with state_lock:
                    sessions.pop(token.value, None)
            return self._json(200, {"ok": True}, [("Set-Cookie", "mu_session=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax")])

        return self._json(404, {"error": "Không tìm thấy."})

    def end_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "SAMEORIGIN")
        self.send_header("Referrer-Policy", "same-origin")
        super().end_headers()

    def log_message(self, fmt, *args):
        print("[web] %s - %s" % (self.client_address[0], fmt % args))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8000)
    a = ap.parse_args()
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    print(f"MU Online web: http://{'localhost' if a.host in ('127.0.0.1', '0.0.0.0') else a.host}:{a.port}/")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
