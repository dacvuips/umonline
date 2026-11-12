#!/usr/bin/env python3
"""
mu_maps.py — Chuyển TOÀN BỘ bản đồ MU (Data/WorldN + Data/ObjectN) sang MuGodot.
Chỉ dùng thư viện chuẩn Python 3. Thường gọi qua: mu_toolkit.py maps

Mỗi WorldN tạo ra:
  assets/mu/maps/WorldN/terrain.mumap   (độ cao, 2 lớp tile, alpha, thuộc tính ô, độ sáng,
                                          TerrainLight.jpg, 30 texture tile, 3 texture cỏ)
  assets/mu/maps/WorldN/objects.json    (vật thể EncTerrainN.obj: loại, ma trận, model .glb)
  assets/mu/ObjectN/ObjectXX.glb        (model vật thể — chuyển bằng mu_convert_all)
  assets/mu/maps/maps_index.json        (danh sách bản đồ)

Thuật toán lấy đúng theo MapManager.cpp / ZzzLodTerrain.cpp:
  - EncTerrainN.map : MapFileDecrypt -> [ver, map, layer1 x65536, layer2 x65536, alpha x65536]
  - EncTerrainN.att : MapFileDecrypt + BuxConvert, 4 byte đầu, uint16 (hoặc uint8) mỗi ô
  - EncTerrainN.obj : MapFileDecrypt -> [ver, map, short số lượng] + 30 byte / vật thể
  - TerrainHeight.OZB: 8-bit (byte * 1.5) hoặc 24-bit "HeightNew" (r<<16|g<<8|b) - 500
  - Độ sáng ô = TerrainLight * clamp(N·Sun + 0.5), Sun = (0.5,-0.5,0.5) ((0.5,-1,1) ở Valley of Loren)
  - Tile: TileGrass01..TileRock07 (0..13), ExtTile01..16 (14..29), lặp sau width/64 ô
"""
import os, sys, struct, json, math, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mu_convert_all import map_decrypt, decode_ozt, png_bytes  # noqa: E402

N = 256
NN = N * N
MAGIC = b'MUMAP\x00\x01\x00'

# Thư mục WorldN = WD_(N-1) trong MapManager.h
WORLD_NAMES = {
    1: 'Lorencia', 2: 'Dungeon', 3: 'Devias', 4: 'Noria', 5: 'Lost Tower', 6: 'Exile', 7: 'Arena', 8: 'Atlans',
    9: 'Tarkan', 10: 'Devil Square', 11: 'Icarus', 12: 'Blood Castle', 19: 'Chaos Castle', 25: 'Kalima',
    31: 'Valley of Loren', 32: 'Land of Trials', 34: 'Aida', 35: 'Crywolf', 36: 'Crywolf 2', 37: 'Kalima 7',
    38: 'Kanturu Ruins', 39: 'Kanturu Relics', 40: 'Kanturu Refinery', 41: 'GM Island', 42: 'Balgass Barracks',
    43: 'Balgass Refuge', 46: 'Illusion Temple', 47: 'Illusion Temple 2', 48: 'Illusion Temple 3',
    49: 'Illusion Temple 4', 50: 'Illusion Temple 5', 51: 'Illusion Temple 6', 52: 'Elbeland',
    53: 'Blood Castle (Master)', 54: 'Chaos Castle (Master)', 55: 'Character Scene', 56: 'Login Scene',
    57: 'Swamp of Calmness', 58: 'Raklion', 59: 'Raklion Hatchery', 63: 'Santa Village', 64: 'Vulcanus',
    65: 'Duel Arena', 66: 'Doppelganger 1', 67: 'Doppelganger 2', 68: 'Doppelganger 3', 69: 'Doppelganger 4',
    70: 'Imperial Guardian 1', 71: 'Imperial Guardian 2', 72: 'Imperial Guardian 3', 73: 'Imperial Guardian 4',
    74: 'Login Scene (New)', 75: 'Character Scene (New)', 78: 'Login Scene 2', 79: 'Character Scene 2',
    80: 'Loren Market', 81: 'Karutan 1', 82: 'Karutan 2',
    94: 'Character Scene (Season 9)', 95: 'Login Scene (Season 9)',
}
# Tile thay thế bằng AlphaTile (.tga) theo MapManager::LoadWorld
ALPHA_TILES = {
    (52, 2): 'AlphaTileGround01', (40, 3): 'AlphaTileGround02', (74, 10): 'AlphaTile01', (75, 10): 'AlphaTile01',
    (70, 10): 'AlphaTile01', (71, 10): 'AlphaTile01', (72, 10): 'AlphaTile01', (73, 10): 'AlphaTile01',
    (81, 12): 'AlphaTile01', (82, 12): 'AlphaTile01',
}
for _w in range(46, 52):
    ALPHA_TILES[(_w, 4)] = 'AlphaTileGround03'
TILE_NAMES = ['TileGrass01', 'TileGrass02', 'TileGround01', 'TileGround02', 'TileGround03', 'TileWater01', 'TileWood01',
              'TileRock01', 'TileRock02', 'TileRock03', 'TileRock04', 'TileRock05', 'TileRock06', 'TileRock07'] + \
             ['ExtTile%02d' % i for i in range(1, 17)]
NO_GRASS = {12, 19, 31, 53, 54} | set(range(13, 19)) | set(range(20, 25))   # Blood/Chaos/Battle Castle
HEIGHT_EXT = {43, 64, 67}   # IsTerrainHeightExtMap: WD_42, PK field (WD_63), Doppelganger 2 (WD_66)
WATER_SPEED = {9: 0.025, 43: 0.02, 31: -0.05}   # WaterMove / giây (mặc định 0.05)
# Vật thể ẩn trong client gốc (HiddenMesh = -2): PoseBox (ghế/điểm ngồi), bẫy ẩn, trigger hiệu ứng
HIDDEN_OBJECT_TYPES = {
    1: {130, 131, 132, 133},
    2: {51, 52, 60},
    3: {91, 100},
    4: {38},
    5: {24, 25},
    7: {38},
    8: {22, 39},
    9: {60, 64, 70, 76, 83},
    11: {0, 1, 2, 3, 4, 5},
}


class Dir:
    def __init__(self, path):
        self.path = path
        try:
            self.files = {f.lower(): f for f in os.listdir(path)}
        except OSError:
            self.files = {}

    def find(self, *names):
        for n in names:
            f = self.files.get(n.lower())
            if f:
                return os.path.join(self.path, f)
        return None


def find_world_dirs(data_root):
    out = {}
    for f in os.listdir(data_root):
        low = f.lower()
        if low.startswith('world') and low[5:].isdigit() and os.path.isdir(os.path.join(data_root, f)):
            out[int(low[5:])] = os.path.join(data_root, f)
    return dict(sorted(out.items()))


def find_object_dir(data_root, n):
    for f in os.listdir(data_root):
        if f.lower() == 'object%d' % n and os.path.isdir(os.path.join(data_root, f)):
            return f
    return None


# ----------------------------------------------------------------------------- địa hình
def read_enc(path):
    """Nội dung EncTerrain sau MapFileDecrypt. File IGCN Season 9+ ('MAP\x01', 'ATT\x01', 'OBJ\x01')
    dùng mã hoá 2 tầng như BMD v14 thay cho MapFileDecrypt (mu_bmd14.py)."""
    d = open(path, 'rb').read()
    if d[:3] in (b'MAP', b'ATT', b'OBJ') and d[3] == 1:
        from mu_bmd14 import decrypt_payload
        return decrypt_payload(d[4:])
    return map_decrypt(d)


def read_mapping(path):
    d = read_enc(path)
    if len(d) < 2 + NN * 3:
        raise ValueError('EncTerrain.map quá ngắn (%d)' % len(d))
    return d[2:2 + NN], d[2 + NN:2 + 2 * NN], d[2 + 2 * NN:2 + 3 * NN]


def read_attr(path):
    a = bytearray(read_enc(path))
    bux = (0xFC, 0xCF, 0xAB)
    for i in range(len(a)):
        a[i] ^= bux[i % 3]
    if len(a) >= 4 + NN * 2:
        return list(struct.unpack_from('<%dH' % NN, a, 4))
    return list(a[4:4 + NN]) + [0] * max(0, NN - (len(a) - 4))


def read_height(path, ext):
    d = open(path, 'rb').read()
    if ext or len(d) >= 4 + 54 + NN * 3:
        off = 4 + 14 + 40
        h = [0.0] * NN
        for i in range(NN):
            p = off + i * 3
            h[i] = float(d[p + 2] | (d[p + 1] << 8) | (d[p] << 16)) - 500.0
        return h, True
    off = 4 + 1080
    return [b * 1.5 for b in d[off:off + NN]], False


def luminosity(h, sun):
    """CreateTerrainNormal + CreateStaticLightCell: clamp(N·Sun + 0.5)"""
    out = bytearray(NN)
    sl = math.sqrt(sun[0] ** 2 + sun[1] ** 2 + sun[2] ** 2)
    for y in range(N):
        y1 = (y + 1) & 255
        for x in range(N):
            x1 = (x + 1) & 255
            h4 = h[y * N + x]; h1 = h[y * N + x1]; h2 = h[y1 * N + x1]; h3 = h[y1 * N + x]
            # face (v1,v2,v3): v1=(x+1,y) v2=(x+1,y+1) v3=(x,y+1)
            ax, ay, az = 0.0, 100.0, h2 - h1
            bx, by, bz = -100.0, 100.0, h3 - h1
            n1 = (ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx)
            # face (v3,v4,v1)
            ax, ay, az = 0.0, -100.0, h4 - h3
            bx, by, bz = 100.0, -100.0, h1 - h3
            n2 = (ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx)
            l1 = math.sqrt(sum(c * c for c in n1)) or 1.0
            l2 = math.sqrt(sum(c * c for c in n2)) or 1.0
            n = (n1[0] / l1 + n2[0] / l2, n1[1] / l1 + n2[1] / l2, n1[2] / l1 + n2[2] / l2)
            v = (n[0] * sun[0] + n[1] * sun[1] + n[2] * sun[2]) + 0.5
            out[y * N + x] = max(0, min(255, int(v * 255 + 0.5)))
    _ = sl
    return bytes(out)


def image_blob(path):
    """-> (kind, bytes): 1 = jpg, 2 = png ; (0, b'') nếu không có"""
    if not path:
        return 0, b''
    d = open(path, 'rb').read()
    low = path.lower()
    if low.endswith('.ozj'):
        return 1, d[24:]
    if low.endswith('.jpg'):
        return 1, d
    if low.endswith('.ozt') or low.endswith('.tga'):
        dec = decode_ozt(d if low.endswith('.ozt') else b'\0\0\0\0' + d)
        if dec:
            w, h, rgba, _a = dec
            return 2, png_bytes(w, h, rgba)
    return 0, b''


# ----------------------------------------------------------------------------- vật thể
C_MAT = ((1, 0, 0), (0, 0, 1), (0, -1, 0))   # MU(x,y,z) -> Godot(x,z,-y)


def angle_matrix(a):
    a = [v * math.pi / 180.0 for v in a]
    sy, cy = math.sin(a[2]), math.cos(a[2]); sp, cp = math.sin(a[1]), math.cos(a[1]); sr, cr = math.sin(a[0]), math.cos(a[0])
    return ((cp * cy, sr * sp * cy + cr * -sy, cr * sp * cy + -sr * -sy),
            (cp * sy, sr * sp * sy + cr * cy, cr * sp * sy + -sr * cy),
            (-sp, sr * cp, cr * cp))


def mm(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def tr(a):
    return tuple(tuple(a[j][i] for j in range(3)) for i in range(3))


def read_objects(path, obj_folder, stems=None):
    d = read_enc(path)
    if len(d) < 4:
        return []
    cnt = struct.unpack_from('<h', d, 2)[0]
    p = 4
    out = []
    for _ in range(cnt):
        if p + 30 > len(d):
            break
        t = struct.unpack_from('<h', d, p)[0]
        pos = struct.unpack_from('<3f', d, p + 2)
        ang = struct.unpack_from('<3f', d, p + 14)
        s = struct.unpack_from('<f', d, p + 26)[0]
        p += 30
        if any(math.isnan(x) or math.isinf(x) for x in pos + ang + (s,)) or s <= 0:
            continue
        R = mm(mm(C_MAT, angle_matrix(ang)), tr(C_MAT))
        Rt = tr(R)   # cột của basis
        o = (pos[0] * 0.01, pos[2] * 0.01, -pos[1] * 0.01)
        want = 'object%02d' % (t + 1)
        stem = (stems or {}).get(want, 'Object%02d' % (t + 1))
        out.append({'t': t, 'm': '%s/%s' % (obj_folder, stem),
                    'b': [round(Rt[i][j] * s, 5) for i in range(3) for j in range(3)],
                    'o': [round(v, 4) for v in o], 's': round(s, 4)})
    return out


# ----------------------------------------------------------------------------- chuyển 1 bản đồ
def convert_world(data_root, mugodot, n, wdir):
    D = Dir(wdir)
    mp = D.find('EncTerrain%d.map' % n)
    if not mp:
        return None
    t0 = time.time()
    l1, l2, al = read_mapping(mp)
    att_p = D.find('EncTerrain%d.att' % n)
    attr = read_attr(att_p) if att_p else [0] * NN
    hp = D.find('TerrainHeight.OZB')
    if hp:
        heights, new_h = read_height(hp, n in HEIGHT_EXT)
    else:
        heights, new_h = [0.0] * NN, False
    sun = (0.5, -1.0, 1.0) if n == 31 else (0.5, -0.5, 0.5)
    lum = luminosity(heights, sun)
    flags = (1 if new_h else 0) | (0 if n in NO_GRASS else 2)
    blob = bytearray()
    blob += MAGIC
    blob += struct.pack('<II f 3f', n, flags, WATER_SPEED.get(n, 0.05), *sun)
    blob += struct.pack('<%df' % NN, *heights)
    blob += bytes(l1) + bytes(l2) + bytes(al)
    blob += struct.pack('<%dH' % NN, *[a & 0xFFFF for a in attr])
    blob += lum
    k, b = image_blob(D.find('TerrainLight.OZJ', 'TerrainLight.jpg'))
    blob += struct.pack('<BI', k, len(b)) + b
    tiles_ok = 0
    blob += struct.pack('<I', len(TILE_NAMES))
    for i, name in enumerate(TILE_NAMES):
        alt = ALPHA_TILES.get((n, i))
        path = D.find(alt + '.OZT', alt + '.tga') if alt else None
        if not path:
            path = D.find(name + '.OZJ', name + '.jpg')
        k, b = image_blob(path)
        tiles_ok += 1 if k else 0
        blob += struct.pack('<BI', k, len(b)) + b
    blob += struct.pack('<I', 3)
    for name in ('TileGrass01', 'TileGrass02', 'TileGrass03'):
        k, b = image_blob(D.find(name + '.OZT', name + '.tga'))
        blob += struct.pack('<BI', k, len(b)) + b
    out_dir = os.path.join(mugodot, 'assets', 'mu', 'maps', 'World%d' % n)
    os.makedirs(out_dir, exist_ok=True)
    open(os.path.join(out_dir, 'terrain.mumap'), 'wb').write(bytes(blob))
    # vật thể
    objs = []
    obj_folder = find_object_dir(data_root, n)
    op = D.find('EncTerrain%d.obj' % n)
    if op and obj_folder:
        try:
            od = os.path.join(data_root, obj_folder)
            stems = {os.path.splitext(f)[0].lower(): os.path.splitext(f)[0] for f in os.listdir(od) if f.lower().endswith('.bmd')}
            objs = read_objects(op, obj_folder, stems)
            # bỏ vật thể không có model (file BMD rỗng / thiếu) hoặc vật thể ẩn (HiddenMesh = -2)
            okm = {os.path.splitext(f)[0] for f in os.listdir(od) if f.lower().endswith('.bmd') and os.path.getsize(os.path.join(od, f)) >= 64}
            hidden = HIDDEN_OBJECT_TYPES.get(n, set())
            objs = [o for o in objs if o['m'].split('/', 1)[1] in okm and o['t'] not in hidden]
        except Exception as e:
            print('   ! %s: %s' % (op, e))
    types = sorted({o['t'] for o in objs})
    json.dump({'world': n, 'name': WORLD_NAMES.get(n, 'World %d' % n), 'object_folder': obj_folder or '',
               'objects': objs}, open(os.path.join(out_dir, 'objects.json'), 'w'), separators=(',', ':'), allow_nan=False)
    # điểm xuất hiện: ô an toàn (bit 1) gần tâm nhất, nếu không có thì ô đi được gần tâm nhất
    spawn = None
    for want in (lambda a: (a & 1) and not (a & 0x0C), lambda a: not (a & 0x0C)):
        best = None
        for i, a in enumerate(attr):
            if want(a):
                x, y = i % N, i // N
                d = (x - 128) ** 2 + (y - 128) ** 2
                if best is None or d < best[0]:
                    best = (d, x, y)
        if best:
            spawn = [best[1], best[2]]
            break
    info = {'world': n, 'name': WORLD_NAMES.get(n, 'World %d' % n), 'objects': len(objs), 'object_types': len(types),
            'object_folder': obj_folder or '', 'tiles': tiles_ok, 'height24': new_h, 'spawn': spawn or [128, 128]}
    print('   World%-3d %-22s %5d vật thể, %2d tile, %.1fs' % (n, info['name'], len(objs), tiles_ok, time.time() - t0), flush=True)
    return info


def main(data_root, mugodot, only=None):
    worlds = find_world_dirs(data_root)
    if only:
        worlds = {k: v for k, v in worlds.items() if k in only}
    print('== Bản đồ: %d thư mục World' % len(worlds), flush=True)
    idx_path = os.path.join(mugodot, 'assets', 'mu', 'maps', 'maps_index.json')
    index = {}
    if os.path.exists(idx_path):
        try:
            index = json.load(open(idx_path, encoding='utf-8'))
        except Exception:
            index = {}
    ok = err = 0
    for n, wdir in worlds.items():
        try:
            info = convert_world(data_root, mugodot, n, wdir)
            if info:
                index[str(n)] = info; ok += 1
        except Exception as e:
            err += 1
            print('   ! World%d: %s' % (n, e), flush=True)
    os.makedirs(os.path.dirname(idx_path), exist_ok=True)
    json.dump(index, open(idx_path, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    print('Bản đồ xong: %d map, %d lỗi' % (ok, err), flush=True)
    return index


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    main(os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]),
         [int(x) for x in sys.argv[3].split(',')] if len(sys.argv) > 3 else None)
