# MU Web Service — web game + APK launcher + tải ngầm (Docker Swarm)

Service riêng để đưa game `MuGodot` lên VPS. Học theo `kiem-hiep` / `kiem-hiep-server` (launcher + manifest + gói `.pck`), nhưng gọn hơn: không cần Go/Postgres riêng cho phần tải nội dung — chỉ nginx phục vụ file tĩnh.

```
Người chơi (web / APK)
   │  1. mở trang / APK  → chỉ tải "core" (màn đăng nhập, ~vài chục MB)
   │  2. vào màn đăng ký/đăng nhập ngay; MuContent (autoload) tải NGẦM các gói .pck từ /content/
   │  3. chọn server → chờ gói tier 1 (model nhân vật, nền chọn nhân vật)
   │  4. bấm Connect ở màn chọn nhân vật → chờ HẾT gói tier 2 (có màn chặn + thanh tiến độ) → mới vào game
   ▼
nginx (mu-web)  ── /            bản web core          ── /content/  manifest.json + packs/*.pck
                ── /download/   mu-launcher.apk        ── /ws        → mu-gateway → OpenMU (TCP 45901)
```

## Cấu trúc
| Đường dẫn | Việc |
|---|---|
| `packs.json` | Quy tắc chia gói: `core`, tier 1 (`charsel`), tier 2 (`monsters`, `sound`, `fx`, `maps`, `game`) |
| `tools/build_content.py` | Quét dự án, chia gói, xuất bằng Godot, băm tên file, ghi `manifest.json`, xuất web/APK core |
| `web/` | `Dockerfile` + `nginx.conf` (COOP/COEP cho Godot web, Range, cache bất biến cho gói) |
| `gateway/` | WebSocket ↔ TCP cho OpenMU (container) |
| `stack.yml` | Swarm stack `mu`: `mu-web`, `mu-gateway`, `openmu`, `mu-db` |
| `deploy.sh` + `deploy.env.example` | `setup`, `images`, `content`, `up`, `all`, `status`, `logs` |
| `../MuGodot/src/boot/` | `MuContent.gd` (autoload, tải ngầm) + `MuContentGate.gd` (màn chặn) |

Phía client đã nối sẵn: `project.godot` có autoload `MuContent`; `MuServerSelect.gd` chờ tier 1 trước khi vào chọn nhân vật; `MuCharacterSelect.gd` chờ tier 2 trước khi vào thế giới; `MuLogin.gd` điền sẵn địa chỉ Gateway từ server.

## Quy trình

### 1. Build (máy dev, cần Godot 4.7 bản *console*)
```bash
python tools/build_content.py --dry-run          # xem kế hoạch chia gói, KHÔNG cần Godot
python tools/build_content.py --godot "C:/Godot/Godot_v4.7-stable_win64_console.exe" --web --apk \
       --public-url https://mu.example.com --gateway-url wss://mu.example.com/ws --prune
```
Cần sẵn export template Web (+ Android và keystore nếu dùng `--apk`). Script tạm thời thêm các preset `MuPack …` / `MuCore …` vào `MuGodot/export_presets.cfg` rồi **khôi phục lại bản gốc** (bản lưu `.mubackup`). Chạy lại chỉ xuất gói có file đổi.

Kết quả ở `dist/`: `web/`, `apk/mu-launcher.apk`, `content/manifest.json`, `content/packs/*.pck`.

**Sau lần build đầu hãy xem bảng kích thước**: `core` phải nhỏ (mục tiêu < 60 MB). Nếu lớn, có scene/script ở core đang kéo tài nguyên nặng → sửa `core_roots` / `core_extra` / `heavy_zones` trong `packs.json`. Mục "tham chiếu vào vùng nặng" liệt kê script nào nạp tài nguyên nặng lúc chạy (đó là chỗ phải đã có gói tương ứng trước khi chạy).

### 2. Lên VPS
```bash
cp deploy.env.example deploy.env      # điền HUB, VPS, DOMAIN
bash deploy.sh setup                  # lần đầu: swarm, thư mục /opt/mu, mật khẩu DB
bash deploy.sh all                    # build image + đẩy nội dung + deploy stack
bash deploy.sh status
```
Lần sau: chỉ đổi nội dung game → `build_content.py` rồi `bash deploy.sh content` (không build lại image, người chơi tự tải phần đổi). Đổi bản web core → `bash deploy.sh all`.

HTTPS: stack chỉ mở `HTTP_PORT` (8090). Đặt Caddy/Nginx Proxy Manager/Cloudflare phía trước, ví dụ Caddy:
```
mu.example.com {
    reverse_proxy 127.0.0.1:8090
}
```
(hoặc nối proxy vào mạng overlay `mu_mu` và trỏ `mu-web:80`). WebSocket `/ws` đi chung tên miền nên không cần mở cổng game ra ngoài.

## Hành vi cần biết
- **Web**: gói lưu ở IndexedDB (`user://content`), lần sau mở lại không tải lại. Tổng nội dung ~900 MB nên **trình duyệt cần nhiều RAM** — nên thử thật trên máy yếu/điện thoại. Nếu nặng quá, giảm bằng cách tách gói / chỉ tải map đang chơi.
- **Mất mạng giữa chừng**: mỗi gói thử lại tối đa 5 lần (tải lại gói đang dở từ đầu — vì vậy gói được chia ≤ 120 MB, chỉnh `max_pack_mb`). Gói đã xong thì giữ.
- **Kiểm tra**: mỗi gói được kiểm kích thước + SHA-256 trước khi nạp.
- **Bản APK cũ**: `--min-launcher N` trong lần build buộc cập nhật APK khi sửa launcher theo cách bản game mới phụ thuộc.
- Gateway production **không** giả lập phản hồi (`MOCK_WHEN_OFFLINE=0`); OpenMU tắt thì client bị đóng kết nối.
- Editor Godot và bản đã đóng đủ gói: `MuContent` tự bỏ qua, không tải gì (`--no-content` để ép bỏ qua).

## Chưa kiểm chứng trên máy này
Máy hiện tại không có Godot và Docker Desktop đang tắt, nên **chưa** chạy thật: xuất `.pck`, build image, `docker stack deploy`, hay chạy client. Đã kiểm: kế hoạch chia gói trên dự án thật (`--dry-run`), luồng build với Godot giả (preset sinh ra, hash, manifest, cache, khôi phục `export_presets.cfg`), gateway chuyển tiếp byte, cú pháp `deploy.sh`. Lần đầu build thật nên mở game web và đi thử đủ luồng đăng nhập → chọn server → chọn nhân vật → vào game.

## Cấu hình hiện tại
`deploy.env`: domain `mu.viettheo.site`, VPS và Docker Hub lấy cùng với stack kiem-hiep (`HUB`, `VPS`). Lệnh build:
```bash
python tools/build_content.py --godot "<đường dẫn Godot console>" --web --apk \
       --public-url https://mu.viettheo.site --gateway-url wss://mu.viettheo.site/ws --prune
```
Caddy của kiem-hiep cần thêm khối `mu.viettheo.site { reverse_proxy 127.0.0.1:8090 }` (và bản ghi DNS A `mu` trỏ về IP VPS).
