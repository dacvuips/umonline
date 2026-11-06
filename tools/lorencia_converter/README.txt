Bộ chuyển đổi dữ liệu Lorencia (Python 3 + numpy + Pillow)
- bmd.py        : đọc BMD (v10 / v12 giải mã MapFileDecrypt), ma trận xương
- convert.py    : Object1/*.bmd + texture OZJ/OZT -> assets/lorencia/models/*.glb (có skeleton + animation)
- terrain.py    : World1 EncTerrain1.map / TerrainHeight.OZB / EncTerrain1.att / TerrainLight.OZJ -> terrain.npz
- build_data.py : terrain PNG, atlas tile, atlas cỏ, lorencia_objects.json (EncTerrain1.obj), lorencia_collision.json
- preview.py    : render thử bằng phần mềm từ góc camera MU (kiểm tra nhanh)
Sửa biến SRC / OUT ở đầu convert.py & terrain.py cho đúng đường dẫn máy bạn rồi chạy:
  python terrain.py && python convert.py && python build_data.py
