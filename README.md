# MU Godot Online (UM Online)

Dự án client **MU Online** đa nền tảng (PC, Mobile, Web) được xây dựng hoàn toàn bằng **Godot Engine 4** với đồ họa 3D tương thích cao (GL Compatibility) và hệ thống mạng WebSocket nhị phân kết nối trực tiếp đến máy chủ OpenMU Season 6.

---

## 🌟 Tính Năng Nổi Bật

- **Godot 4.x Engine**: Render 3D mượt mà, hỗ trợ GL Compatibility chạy tốt trên PC, Mobile (Android/iOS) và WebAssembly HTML5.
- **Lorencia & Map 3D**: Chuyển đổi và tái hiện đầy đủ bản đồ Lorencia, hiệu ứng môi trường, nước, cây cối và ánh sáng theo phong cách MU Online nguyên bản.
- **Hệ Thống Nhân Vật & Monster**:
  - Dark Knight, Dark Wizard, Fairy Elf với đầy đủ animation gốc (Idle, Walk, Attack, Skill).
  - Tự động gắn vũ khí, khiên, giáp (Armor sets) đúng vị trí tay và xương.
  - Quái vật (Spider, Budge Dragon, Bull Fighter, Hound...) với hệ thống Spawn và AI cơ bản.
- **Giao Diện UI/HUD & Mobile Controls**:
  - Thanh máu (HP), năng lượng (MP), Stamina (AG), cấp độ và EXP.
  - Bảng túi đồ (Inventory 8x8) và trang bị nhân vật (Equipment slots) trực quan.
  - Điều khiển cảm ứng (Virtual Joystick, Vòng chọn kỹ năng Skill Ring, Nút tương tác nhanh).
- **Hệ Thống Mạng (Networking)**:
  - WebSocket nhị phân giao tiếp trực tiếp với WebSocket Gateway Proxy (`gateway/ws_proxy.py`).
  - Hỗ trợ cả 2 chế độ:
    - **Online**: Kết nối trực tiếp vào OpenMU GameServer (Season 6).
    - **Standalone / Mock Mode**: Tự động phản hồi kiểm thử nếu máy chủ GameServer chưa khởi động.
- **Bộ Công Cụ Tiện Ích (Tools)**:
  - Script trích xuất và chuyển đổi mô hình, texture BMD sang GLTF/GLB tự động (`tools/`).

---

## 🚀 Hướng Dẫn Cài Đặt & Khởi Chạy

### 1. Yêu Cầu Hệ Thống
- [Godot Engine 4.3+](https://godotengine.org/download) (hoặc 4.4/4.7).
- [Python 3.10+](https://www.python.org/) (để chạy WebSocket Gateway Proxy).
- Cài đặt thư viện websocket cho Python:
  ```bash
  pip install websockets
  ```

### 2. Khởi Chạy Gateway Proxy
Trước khi vào game, khởi chạy Gateway để client có thể kết nối:
```bat
Start-Gateway.bat
```
Hoặc chạy lệnh Python:
```bash
python gateway/ws_proxy.py
```

### 3. Mở Dự Án Với Godot Engine
1. Mở **Godot Engine**.
2. Chọn **Import** và trỏ đến thư mục dự án chứa file `project.godot`.
3. Nhấn **Edit** để mở editor hoặc nhấn **F5** (Play Project) để bắt đầu trải nghiệm!

---

## 📁 Cấu Trúc Thư Mục

```text
├── addons/             # Plugin và tiện ích mở rộng cho Godot
├── assets/             # Tài nguyên game (Models 3D, Textures, Sounds, UI, JSON dữ liệu)
├── gateway/            # WebSocket-to-TCP Gateway Proxy cho kết nối OpenMU
├── src/
│   ├── network/        # Client mạng WebSocket & Packet serializer/deserializer
│   ├── scenes/         # Các scene chính (Login, World, Character Select...)
│   ├── ui/             # Hệ thống UI (HUD, Inventory, Mobile Controls, Skill Ring...)
│   └── world/          # Quản lý thế giới, bản đồ Lorencia, NPC & Monsters
├── tools/              # Toolkit chuyển đổi dữ liệu và model MU Online
├── project.godot       # File cấu hình chính của Godot Engine
├── Start-Gateway.bat   # Script khởi động nhanh WebSocket Proxy
└── README.md
```

---

## 📜 Giấy Phép & Bản Quyền
Dự án được phát triển nhằm mục đích nghiên cứu, học tập và bảo tồn di sản game MU Online kinh điển. Tất cả tài nguyên đồ họa và âm thanh gốc thuộc bản quyền của Webzen Inc.
