MU TOOLKIT — chuyển dữ liệu client MU gốc sang MuGodot (chỉ cần Python 3)

Cách 1 — trong Godot: dock "MU Tools" (bên phải). Bấm "Chuyển TẤT CẢ model + kiểm tra".
          Xong sẽ tự quét lại tài nguyên. "Mở Model Viewer" để xem / mặc thử đồ / chạy action.
Cách 2 — ngoài Godot: bấm đúp tools\MU_TOOLKIT.bat, chọn số trong menu.
Cách 3 — dòng lệnh:
   python tools\mu_toolkit.py all            (model + bản đồ + kiểm tra)
   python tools\mu_toolkit.py maps           (tất cả bản đồ WorldN + model vật thể ObjectN)
   python tools\mu_toolkit.py maps 3,4       (chỉ Devias, Noria)
   python tools\mu_toolkit.py server         (OpenMU: cửa hàng NPC, bảng Move, NPC từng bản đồ, chỉ số quái + skill)
   python tools\mu_toolkit.py ui             (ảnh giao diện gốc Data\Interface)
   python tools\mu_toolkit.py models Player  (1 thư mục)
   python tools\mu_toolkit.py all --force    (ghi đè)
   python tools\mu_toolkit.py check          (báo cáo -> assets\mu\mu_report.txt)
   python tools\mu_toolkit.py config E:\MuMain\Client\Data

Kết quả: assets\mu\<Player|Monster|NPC|Item|Skill|Effect|ObjectN>\*.glb, assets\mu\catalog\..., mu_models_index.json
         assets\mu\maps\WorldN\terrain.mumap + objects.json, assets\mu\maps\maps_index.json
Lần sau chỉ chuyển file mới/đổi (nhanh). Thêm model mới vào Client\Data rồi chạy lại là đủ.

Phím: M = bảng dịch chuyển, I/V = túi đồ, bấm NPC = đi tới & mở cửa hàng.
Lệnh chat trong game: /map (danh sách), /map 3 hoặc /map devias (đổi bản đồ), /class dk, /set 1 13 exc, /weapon 0 19 15 exc, /left 6 15 9, /wing 5, /help
