#!/usr/bin/env python3
"""
mu_convert_all.py — Chuyển TOÀN BỘ model MU (BMD) sang glTF (.glb) cho Godot.
Chỉ dùng thư viện chuẩn Python 3 (không cần numpy / Pillow).

  python mu_convert_all.py  <thư mục Client\\Data>  <thư mục MuGodot>

Ví dụ:
  python mu_convert_all.py E:\\MuMain\\Client\\Data E:\\MuMain\\MuGodot

Kết quả:
  <MuGodot>/assets/mu/<Thư mục gốc>/<tên>.glb      (Player, Monster, NPC, Item, Skill, Effect...)
  <MuGodot>/assets/mu/<Thư mục gốc>/tex/*.jpg|png  (texture dùng chung, glb tham chiếu ngoài)
  <MuGodot>/assets/mu/catalog/...                   (Monsters/*.json, Items/**/*.json chép nguyên)
  <MuGodot>/assets/mu/mu_models_index.json          (danh sách model + số action + bone)

Quy ước:
  - Trục MU (x, y, z-lên) -> Godot (x, z, -y), 1 đơn vị Godot = 100 đơn vị MU (phép quay, không lật).
  - Mọi model có xương đều xuất skeleton + skin; mỗi action MU = 1 animation tên "a000", "a001"...
    thời gian: 4 key / giây (Velocity mặc định 0.16 * 25 tick). Godot chỉnh speed_scale theo PlaySpeed.
  - Tên xương "b000".."bNNN" (theo chỉ số MU) để các mảnh trang phục gắn chung skeleton của Player.bmd.
  - Data/Player/*.bmd (trừ Player.bmd): mảnh trang phục -> dùng xương + bind pose của Player.bmd.
  - Vật liệu tên "mu<TextureIndex>__<tên texture>" ; texture 32-bit -> alphaMode MASK (0.25).
"""
import os, sys, struct, json, math, zlib, shutil, time, traceback

# ----------------------------------------------------------------------------- giải mã
KEY = bytes([0xD1, 0x73, 0x52, 0xF6, 0xD2, 0x9A, 0xCB, 0x27, 0x3E, 0xAF, 0x59, 0x31, 0x37, 0xB3, 0xE7, 0xA2])

def map_decrypt(src):
    out = bytearray(len(src)); k = 0x5E
    for i, b in enumerate(src):
        out[i] = ((b ^ KEY[i & 15]) - k) & 0xFF
        k = (b + 0x3D) & 0xFF
    return bytes(out)

# ----------------------------------------------------------------------------- toán
def angle_quat(a):
    sy, cy = math.sin(a[2] * .5), math.cos(a[2] * .5)
    sp, cp = math.sin(a[1] * .5), math.cos(a[1] * .5)
    sr, cr = math.sin(a[0] * .5), math.cos(a[0] * .5)
    return (sr * cp * cy - cr * sp * sy, cr * sp * cy + sr * cp * sy, cr * cp * sy - sr * sp * cy, cr * cp * cy + sr * sp * sy)

def quat_mat(q, t):
    x, y, z, w = q
    return [[1 - 2 * y * y - 2 * z * z, 2 * x * y - 2 * w * z, 2 * x * z + 2 * w * y, t[0]],
            [2 * x * y + 2 * w * z, 1 - 2 * x * x - 2 * z * z, 2 * y * z - 2 * w * x, t[1]],
            [2 * x * z - 2 * w * y, 2 * y * z + 2 * w * x, 1 - 2 * x * x - 2 * y * y, t[2]],
            [0, 0, 0, 1]]

def mmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def mpt(m, p):
    return [m[0][0] * p[0] + m[0][1] * p[1] + m[0][2] * p[2] + m[0][3],
            m[1][0] * p[0] + m[1][1] * p[1] + m[1][2] * p[2] + m[1][3],
            m[2][0] * p[0] + m[2][1] * p[1] + m[2][2] * p[2] + m[2][3]]

def mvec(m, p):
    return [m[0][0] * p[0] + m[0][1] * p[1] + m[0][2] * p[2],
            m[1][0] * p[0] + m[1][1] * p[1] + m[1][2] * p[2],
            m[2][0] * p[0] + m[2][1] * p[1] + m[2][2] * p[2]]

IDENT = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
S = 0.01

def cv(p):  # điểm MU -> Godot (có scale)
    return [p[0] * S, p[2] * S, -p[1] * S]

def cn(n):  # vector MU -> Godot (không scale)
    return [n[0], n[2], -n[1]]

def conv_mat(M):
    # C M C^-1, C: (x,y,z)->(x,z,-y)
    r = [[M[0][0], M[0][2], -M[0][1]], [M[2][0], M[2][2], -M[2][1]], [-M[1][0], -M[1][2], M[1][1]]]
    t = cv([M[0][3], M[1][3], M[2][3]])
    return [[r[0][0], r[0][1], r[0][2], t[0]], [r[1][0], r[1][1], r[1][2], t[1]], [r[2][0], r[2][1], r[2][2], t[2]], [0, 0, 0, 1]]

def minv_rigid(M):
    R = [[M[j][i] for j in range(3)] for i in range(3)]
    t = [-(R[i][0] * M[0][3] + R[i][1] * M[1][3] + R[i][2] * M[2][3]) for i in range(3)]
    return [[R[0][0], R[0][1], R[0][2], t[0]], [R[1][0], R[1][1], R[1][2], t[1]], [R[2][0], R[2][1], R[2][2], t[2]], [0, 0, 0, 1]]

# ----------------------------------------------------------------------------- BMD
class Model: pass

def load_bmd(path):
    d = open(path, 'rb').read()
    if d[:3] != b'BMD':
        raise ValueError('không phải BMD')
    ver = d[3]
    if ver == 0x0A:
        data, p = d, 4
    elif ver == 0x0C:
        n = struct.unpack_from('<i', d, 4)[0]
        data, p = map_decrypt(d[8:8 + n]), 0
    else:
        raise ValueError('BMD version %d chưa hỗ trợ' % ver)
    m = Model(); m.version = ver
    m.name = data[p:p + 32].split(b'\0')[0].decode('latin1'); p += 32
    nm, nb, na = struct.unpack_from('<hhh', data, p); p += 6
    m.meshes = []
    for _ in range(nm):
        nv, nn, nt, ntri, tex = struct.unpack_from('<hhhhh', data, p); p += 10
        me = Model(); me.tex_index = tex
        me.v = [(struct.unpack_from('<h', data, p + i * 16)[0], struct.unpack_from('<3f', data, p + i * 16 + 4)) for i in range(nv)]; p += nv * 16
        me.n = [(struct.unpack_from('<h', data, p + i * 20)[0], struct.unpack_from('<3f', data, p + i * 20 + 4)) for i in range(nn)]; p += nn * 20
        me.t = [struct.unpack_from('<2f', data, p + i * 8) for i in range(nt)]; p += nt * 8
        me.tris = []
        for _ in range(ntri):
            poly = data[p]
            vi = struct.unpack_from('<4h', data, p + 2); ni = struct.unpack_from('<4h', data, p + 10); ti = struct.unpack_from('<4h', data, p + 18)
            me.tris.append((poly, vi, ni, ti)); p += 64
        me.texname = data[p:p + 32].split(b'\0')[0].decode('latin1', 'replace').strip(); p += 32
        m.meshes.append(me)
    m.actions = []
    m.locks = []   # Action_t::LockPositions: action giữ chân tại chỗ (khoá x/y của xương gốc)
    for _ in range(na):
        nk = struct.unpack_from('<h', data, p)[0]; p += 2
        lock = data[p]; p += 1
        if lock and nk > 0:
            p += 12 * nk
        m.actions.append(nk)
        m.locks.append(bool(lock))
    m.bones = []
    for _ in range(nb):
        b = Model(); b.dummy = data[p]; p += 1
        b.name = ''; b.parent = -1; b.pos = []; b.rot = []
        if not b.dummy:
            b.name = data[p:p + 32].split(b'\0')[0].decode('latin1', 'replace'); p += 32
            b.parent = struct.unpack_from('<h', data, p)[0]; p += 2
            for nk in m.actions:
                if nk > 0:
                    b.pos.append([struct.unpack_from('<3f', data, p + k * 12) for k in range(nk)]); p += 12 * nk
                    b.rot.append([struct.unpack_from('<3f', data, p + k * 12) for k in range(nk)]); p += 12 * nk
                else:
                    b.pos.append(None); b.rot.append(None)
        m.bones.append(b)
    return m

def bone_globals(m, action=0, key=0):
    out = []
    for b in m.bones:
        M = IDENT
        if not b.dummy and action < len(b.pos) and b.pos[action] is not None and key < len(b.pos[action]):
            M = quat_mat(angle_quat(b.rot[action][key]), b.pos[action][key])
            if 0 <= b.parent < len(out):
                M = mmul(out[b.parent], M)
        out.append(M)
    return out

def is_animated(m):
    for ai, nk in enumerate(m.actions):
        if nk <= 1:
            continue
        for b in m.bones:
            if b.dummy or ai >= len(b.pos) or b.pos[ai] is None:
                continue
            p0, r0 = b.pos[ai][0], b.rot[ai][0]
            for k in range(1, nk):
                if any(abs(b.pos[ai][k][c] - p0[c]) > 1e-3 for c in range(3)) or any(abs(b.rot[ai][k][c] - r0[c]) > 1e-4 for c in range(3)):
                    return True
    return False

# ----------------------------------------------------------------------------- texture
def png_bytes(w, h, rgba):
    raw = b''.join(b'\x00' + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b'')

def decode_ozt(d):
    """OZT = 4 byte + TGA 18 byte; MU đọc 32bpp BGRA, luôn lật dòng (đáy lên)."""
    t = d[4:]
    idlen, cmt, itype = t[0], t[1], t[2]
    w = t[12] | (t[13] << 8); h = t[14] | (t[15] << 8); bpp = t[16]
    if w <= 0 or h <= 0:
        return None
    off = 18 + idlen
    px = bytearray()
    bpp_b = bpp // 8
    if itype == 2:
        px = bytearray(t[off:off + w * h * bpp_b])
    elif itype == 10:  # RLE
        i = off; total = w * h
        while len(px) < total * bpp_b and i < len(t):
            c = t[i]; i += 1; cnt = (c & 0x7F) + 1
            if c & 0x80:
                px += t[i:i + bpp_b] * cnt; i += bpp_b
            else:
                px += t[i:i + bpp_b * cnt]; i += bpp_b * cnt
    else:
        return None
    if len(px) < w * h * bpp_b:
        px += bytes(w * h * bpp_b - len(px))
    out = bytearray(w * h * 4)
    alpha_used = False
    for y in range(h):
        sy = h - 1 - y
        for x in range(w):
            s = (sy * w + x) * bpp_b; o = (y * w + x) * 4
            out[o] = px[s + 2]; out[o + 1] = px[s + 1]; out[o + 2] = px[s]
            a = px[s + 3] if bpp_b == 4 else 255
            out[o + 3] = a
            if a < 250:
                alpha_used = True
    return w, h, bytes(out), alpha_used

class TexStore:
    def __init__(self, data_root, out_root):
        self.data_root = data_root; self.out_root = out_root
        self.cache = {}; self.dir_cache = {}

    def _list(self, d):
        if d not in self.dir_cache:
            try:
                self.dir_cache[d] = {f.lower(): f for f in os.listdir(d)}
            except OSError:
                self.dir_cache[d] = {}
        return self.dir_cache[d]

    def find(self, texname, search_dirs):
        stem, ext = os.path.splitext(os.path.basename(texname.replace('\\', '/')))
        want = ['.ozj', '.jpg'] if ext.lower() in ('.jpg', '.jpeg') else ['.ozt', '.tga']
        if ext.lower() == '.bmp':
            want = ['.ozb', '.bmp']
        for d in search_dirs:
            files = self._list(d)
            for e in want:
                f = files.get((stem + e).lower())
                if f:
                    return os.path.join(d, f)
        return None

    def get(self, texname, search_dirs, out_dir):
        """-> (uri tương đối, có alpha) ; ghi file vào out_dir/tex/"""
        src = self.find(texname, search_dirs)
        if not src:
            return None
        key = (src, out_dir)
        if key in self.cache:
            return self.cache[key]
        os.makedirs(os.path.join(out_dir, 'tex'), exist_ok=True)
        stem = os.path.splitext(os.path.basename(src))[0]
        d = open(src, 'rb').read()
        res = None
        low = src.lower()
        try:
            if low.endswith('.ozj'):
                name = stem + '.jpg'; open(os.path.join(out_dir, 'tex', name), 'wb').write(d[24:]); res = ('tex/' + name, False)
            elif low.endswith('.jpg'):
                name = stem + '.jpg'; open(os.path.join(out_dir, 'tex', name), 'wb').write(d); res = ('tex/' + name, False)
            elif low.endswith('.ozt') or low.endswith('.tga'):
                dec = decode_ozt(d if low.endswith('.ozt') else b'\0\0\0\0' + d)
                if dec:
                    w, h, rgba, alpha = dec
                    name = stem + '.png'; open(os.path.join(out_dir, 'tex', name), 'wb').write(png_bytes(w, h, rgba)); res = ('tex/' + name, alpha)
        except Exception as e:
            print('   ! texture lỗi', src, e)
        self.cache[key] = res
        return res

# ----------------------------------------------------------------------------- glTF
class GLB:
    def __init__(self):
        self.bin = bytearray()
        self.g = {'asset': {'version': '2.0', 'generator': 'MuGodot mu_convert_all'}, 'buffers': [], 'bufferViews': [], 'accessors': [],
                  'meshes': [], 'nodes': [], 'materials': [], 'textures': [], 'images': [],
                  'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}], 'scenes': [{'nodes': []}], 'scene': 0}
        self.img_index = {}

    def view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin); self.bin += data
        v = {'buffer': 0, 'byteOffset': off, 'byteLength': len(data)}
        if target:
            v['target'] = target
        self.g['bufferViews'].append(v); return len(self.g['bufferViews']) - 1

    def acc_f(self, rows, typ, ncomp, target=None, minmax=False):
        rows = [r if isinstance(r, (list, tuple)) else [r] for r in rows]
        flat = [float(x) for r in rows for x in (r if isinstance(r, (list, tuple)) else [r])]
        bv = self.view(struct.pack('<%df' % len(flat), *flat), target)
        a = {'bufferView': bv, 'componentType': 5126, 'count': len(rows), 'type': typ}
        if minmax and rows:
            a['min'] = [min(r[i] for r in rows) for i in range(ncomp)]
            a['max'] = [max(r[i] for r in rows) for i in range(ncomp)]
        self.g['accessors'].append(a); return len(self.g['accessors']) - 1

    def acc_u16(self, rows, typ, target=None):
        flat = [int(x) for r in rows for x in r]
        bv = self.view(struct.pack('<%dH' % len(flat), *flat), target)
        self.g['accessors'].append({'bufferView': bv, 'componentType': 5123, 'count': len(rows), 'type': typ}); return len(self.g['accessors']) - 1

    def acc_idx(self, idx):
        bv = self.view(struct.pack('<%dI' % len(idx), *idx), 34963)
        self.g['accessors'].append({'bufferView': bv, 'componentType': 5125, 'count': len(idx), 'type': 'SCALAR'}); return len(self.g['accessors']) - 1

    def material(self, name, tex):
        m = {'name': name, 'pbrMetallicRoughness': {'metallicFactor': 0.0, 'roughnessFactor': 1.0}, 'doubleSided': True}
        if tex:
            uri, alpha = tex
            if uri not in self.img_index:
                self.g['images'].append({'uri': uri})
                self.g['textures'].append({'source': len(self.g['images']) - 1, 'sampler': 0})
                self.img_index[uri] = len(self.g['textures']) - 1
            m['pbrMetallicRoughness']['baseColorTexture'] = {'index': self.img_index[uri]}
            if alpha:
                m['alphaMode'] = 'MASK'; m['alphaCutoff'] = 0.25
        self.g['materials'].append(m); return len(self.g['materials']) - 1

    def save(self, path):
        self.g['buffers'] = [{'byteLength': len(self.bin)}]
        for k in ['textures', 'images', 'materials', 'meshes']:
            if not self.g[k]:
                del self.g[k]
        js = json.dumps(self.g, separators=(',', ':')).encode()
        while len(js) % 4:
            js += b' '
        while len(self.bin) % 4:
            self.bin.append(0)
        out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(self.bin), 0x004E4942) + bytes(self.bin)
        open(path, 'wb').write(out)

def export(model, skel, out_path, tex_store, search_dirs, out_dir, with_anim=True):
    """model: mesh nguồn ; skel: model cung cấp xương (chính nó hoặc Player.bmd)."""
    nb = len(skel.bones)
    use_skin = nb > 0 and (is_animated(skel) or skel is not model)
    mats0 = bone_globals(skel, 0, 0) if skel.actions and skel.actions[0] > 0 else [IDENT] * nb
    g = GLB(); G = g.g
    prims = []
    for mi, me in enumerate(model.meshes):
        tex = tex_store.get(me.texname, search_dirs, out_dir) if me.texname else None
        stem = os.path.splitext(os.path.basename(me.texname.replace('\\', '/')))[0] if me.texname else 'none'
        mat = g.material('mu%d__%s' % (me.tex_index, stem), tex)
        verts = {}; P = []; N = []; T = []; J = []; I = []
        for poly, vi, ni, ti in me.tris:
            if poly not in (3, 4):
                continue
            corners = []
            ok = True
            for k in range(poly):
                if not (0 <= vi[k] < len(me.v)) or not (0 <= ni[k] < len(me.n)) or not (0 <= ti[k] < len(me.t)):
                    ok = False; break
                key = (vi[k], ni[k], ti[k])
                if key not in verts:
                    node, pos = me.v[vi[k]]
                    _, nrm = me.n[ni[k]]
                    Mb = mats0[node] if 0 <= node < nb else IDENT
                    p = mpt(Mb, pos); n = mvec(Mb, nrm)
                    ln = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2) or 1.0
                    P.append(cv(p)); N.append(cn([n[0] / ln, n[1] / ln, n[2] / ln])); T.append(me.t[ti[k]])
                    J.append(node if 0 <= node < nb else 0)
                    verts[key] = len(P) - 1
                corners.append(verts[key])
            if not ok:
                continue
            I += [corners[0], corners[1], corners[2]]
            if poly == 4:
                I += [corners[0], corners[2], corners[3]]
        if not I:
            continue
        attrs = {'POSITION': g.acc_f(P, 'VEC3', 3, 34962, True), 'NORMAL': g.acc_f(N, 'VEC3', 3, 34962), 'TEXCOORD_0': g.acc_f(T, 'VEC2', 2, 34962)}
        if use_skin:
            attrs['JOINTS_0'] = g.acc_u16([(j, 0, 0, 0) for j in J], 'VEC4', 34962)
            attrs['WEIGHTS_0'] = g.acc_f([(1.0, 0.0, 0.0, 0.0)] * len(J), 'VEC4', 4, 34962)
        prims.append({'attributes': attrs, 'indices': g.acc_idx(I), 'material': mat})
    base = os.path.splitext(os.path.basename(out_path))[0]
    if prims:
        G['meshes'].append({'name': base, 'primitives': prims})
    if not use_skin:
        G['nodes'].append({'name': base, 'mesh': 0} if prims else {'name': base})
        G['scenes'][0]['nodes'] = [0]
        g.save(out_path); return {'skinned': False, 'actions': [], 'bones': nb, 'meshes': len(prims)}
    # xương
    for i, b in enumerate(skel.bones):
        node = {'name': 'b%03d' % i}
        if not b.dummy and b.pos and b.pos[0] is not None:
            q = angle_quat(b.rot[0][0]); qv = cn(q[:3])
            node['rotation'] = [qv[0], qv[1], qv[2], q[3]]
            node['translation'] = cv(b.pos[0][0])
        G['nodes'].append(node)
    roots = []
    for i, b in enumerate(skel.bones):
        if not b.dummy and 0 <= b.parent < nb and b.parent != i:
            G['nodes'][b.parent].setdefault('children', []).append(i)
        else:
            roots.append(i)
    ibm = []
    for i in range(nb):
        M = minv_rigid(conv_mat(mats0[i]))
        ibm.append([M[r][c] for c in range(4) for r in range(4)])  # column-major
    G['skins'] = [{'joints': list(range(nb)), 'inverseBindMatrices': g.acc_f(ibm, 'MAT4', 16)}]
    if prims:
        G['nodes'].append({'name': base + '_mesh', 'mesh': 0, 'skin': 0})
        G['nodes'].append({'name': base, 'children': roots + [nb]})
    else:
        G['nodes'].append({'name': base, 'children': roots})
    G['scenes'][0]['nodes'] = [len(G['nodes']) - 1]
    actions = []
    if with_anim:
        G['animations'] = []
        tcache = {}
        for ai, nk in enumerate(skel.actions):
            if nk <= 0:
                continue
            keys = list(range(nk)) + ([0] if nk > 1 else [])
            n = len(keys)
            if n not in tcache:
                tcache[n] = g.acc_f([k / 4.0 for k in range(n)] if n > 1 else [0.0], 'SCALAR', 1, None, True)
                if n == 1:
                    G['accessors'][tcache[n]]['min'] = [0.0]; G['accessors'][tcache[n]]['max'] = [0.0]
            tacc = tcache[n]
            chans = []; samps = []
            for i, b in enumerate(skel.bones):
                if b.dummy or ai >= len(b.pos) or b.pos[ai] is None:
                    continue
                tr = [cv(b.pos[ai][k]) for k in keys]
                rq = []; prev = None
                for k in keys:
                    q = angle_quat(b.rot[ai][k]); qv = cn(q[:3]); qq = [qv[0], qv[1], qv[2], q[3]]
                    if prev is not None and sum(prev[c] * qq[c] for c in range(4)) < 0:
                        qq = [-c for c in qq]
                    rq.append(qq); prev = qq
                samps.append({'input': tacc, 'output': g.acc_f(tr, 'VEC3', 3), 'interpolation': 'LINEAR'}); chans.append({'sampler': len(samps) - 1, 'target': {'node': i, 'path': 'translation'}})
                samps.append({'input': tacc, 'output': g.acc_f(rq, 'VEC4', 4), 'interpolation': 'LINEAR'}); chans.append({'sampler': len(samps) - 1, 'target': {'node': i, 'path': 'rotation'}})
            if chans:
                G['animations'].append({'name': 'a%03d' % ai, 'channels': chans, 'samplers': samps})
                actions.append([ai, nk])
        if not G['animations']:
            del G['animations']
    g.save(out_path)
    return {'skinned': True, 'actions': actions, 'bones': nb, 'meshes': len(prims)}

# ----------------------------------------------------------------------------- main
FOLDERS = ['Player', 'Monster', 'NPC', 'Item', 'Skill', 'Effect']

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    force = '--force' in sys.argv
    if len(args) < 2:
        print(__doc__); sys.exit(1)
    data_root = os.path.abspath(args[0]); mugodot = os.path.abspath(args[1])
    only = args[2].split(',') if len(args) > 2 and args[2] else FOLDERS
    out_root = os.path.join(mugodot, 'assets', 'mu')
    os.makedirs(out_root, exist_ok=True)
    tex_store = TexStore(data_root, out_root)
    all_dirs = [os.path.join(data_root, f) for f in FOLDERS] + [os.path.join(data_root, 'Object1')]
    index_path = os.path.join(out_root, 'mu_models_index.json')
    index = json.load(open(index_path)) if os.path.exists(index_path) else {}
    player = None
    pp = os.path.join(data_root, 'Player', 'Player.bmd')
    if os.path.exists(pp):
        player = load_bmd(pp)
        print('Player.bmd: %d xương, %d action' % (len(player.bones), len(player.actions)))
    # bộ phận NPC (Monsters/Models.json "parts"): dùng xương của model cha (giống Player)
    part_parent = {}
    mj = os.path.join(data_root, 'Monsters', 'Models.json')
    if os.path.exists(mj):
        try:
            for mm in json.load(open(mj, encoding='utf-8')).get('models', []):
                for pt in mm.get('parts', []) or []:
                    pf = pt.get('file', ''); mf = mm.get('file', '')
                    if pf and mf:
                        part_parent[pf.replace('\\', '/').lower()[5:]] = mf.replace('\\', '/')[5:]
        except Exception as e:
            print('  ! Models.json: %s' % e)
    skel_cache = {}
    def parent_skel(rel_key):
        mf = part_parent.get(rel_key.lower())
        if not mf:
            return None
        if mf not in skel_cache:
            fp = os.path.join(data_root, *mf.split('/'))
            skel_cache[mf] = load_bmd(fp) if os.path.exists(fp) else None
        return skel_cache[mf]
    t0 = time.time(); n_ok = n_err = 0
    for folder in only:
        src_dir = os.path.join(data_root, folder)
        if not os.path.isdir(src_dir):
            continue
        out_dir = os.path.join(out_root, folder)
        os.makedirs(out_dir, exist_ok=True)
        files = []
        for root, _dirs, fs in os.walk(src_dir):
            for f in fs:
                if f.lower().endswith('.bmd'):
                    files.append(os.path.relpath(os.path.join(root, f), src_dir))
        files.sort()
        print('== %s: %d model' % (folder, len(files)))
        for i, rel in enumerate(files):
            f = rel
            sub = os.path.dirname(rel)
            name = os.path.splitext(os.path.basename(rel))[0]
            m_dir = os.path.join(src_dir, sub)
            o_dir = os.path.join(out_dir, sub)
            os.makedirs(o_dir, exist_ok=True)
            out_path = os.path.join(o_dir, name + '.glb')
            key = (folder + '/' + rel.replace(os.sep, '/'))[:-4]
            search = [m_dir, src_dir] + [d for d in all_dirs if d != src_dir]
            try:
                if not force and os.path.exists(out_path) and key in index and os.path.getmtime(out_path) >= os.path.getmtime(os.path.join(src_dir, f)):
                    n_ok += 1; continue
                if os.path.getsize(os.path.join(src_dir, f)) < 64:
                    continue   # file rỗng (chỗ trống trong danh sách model)
                m = load_bmd(os.path.join(src_dir, f))
                skel = m
                part = folder == 'Player' and name.lower() != 'player' and player is not None and len(m.bones) <= len(player.bones) and (len(m.actions) <= 1 or not is_animated(m))
                if part:
                    skel = player
                else:
                    ps = parent_skel(key + '.bmd')
                    if ps is not None and len(m.bones) <= len(ps.bones):
                        part = True; skel = ps
                info = export(m, skel, out_path, tex_store, search, o_dir, with_anim=not part)
                info['part_of_player'] = part
                info['textures'] = [me.texname for me in m.meshes]
                index[key] = info
                n_ok += 1
                if (i + 1) % 25 == 0:
                    print('   %d/%d  (%.0fs)' % (i + 1, len(files), time.time() - t0), flush=True)
                    json.dump(index, open(index_path, 'w'), separators=(',', ':'))
            except Exception as e:
                n_err += 1
                print('   ! %s: %s' % (f, e))
        json.dump(index, open(index_path, 'w'), separators=(',', ':'))
    # chép catalog
    cat = os.path.join(out_root, 'catalog')
    for sub in ['Monsters', 'Items', 'Effects']:
        s = os.path.join(data_root, sub)
        if os.path.isdir(s):
            shutil.copytree(s, os.path.join(cat, sub), dirs_exist_ok=True)
    print('Xong: %d model, %d lỗi, %.0f giây. Kết quả: %s' % (n_ok, n_err, time.time() - t0, out_root))

if __name__ == '__main__':
    main()
