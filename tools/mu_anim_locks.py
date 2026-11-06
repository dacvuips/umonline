"""Xuất cờ LockPositions của từng action trong các BMD gốc ra assets/mu/anim_locks.json.

MU (BMD::Animation): action có LockPositions giữ vị trí ngang của xương gốc (bone 0) bằng khung 0,
chỉ giữ chuyển động lên xuống -> animation đi / chạy không tự trượt người về trước.
Bộ chuyển glb không mang cờ này, MuModel.gd đọc file JSON để khoá khi nạp animation.

    python tools/mu_anim_locks.py <thư mục Data của client> <thư mục MuGodot>
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mu_convert_all import load_bmd, FOLDERS

def main():
    data_root = os.path.abspath(sys.argv[1]); mugodot = os.path.abspath(sys.argv[2])
    out = {}
    for folder in FOLDERS:
        d = os.path.join(data_root, folder)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.lower().endswith('.bmd'):
                continue
            try:
                m = load_bmd(os.path.join(d, name))
            except Exception:
                continue
            locked = [i for i, (nk, lk) in enumerate(zip(m.actions, m.locks)) if lk and nk > 0]
            if locked:
                out[('%s/%s' % (folder, os.path.splitext(name)[0])).lower()] = locked
    path = os.path.join(mugodot, 'assets', 'mu', 'anim_locks.json')
    json.dump(out, open(path, 'w', encoding='utf-8'), separators=(',', ':'))
    print('%d model co action khoa -> %s' % (len(out), path))

if __name__ == '__main__':
    main()
