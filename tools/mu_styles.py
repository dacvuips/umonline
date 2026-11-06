#!/usr/bin/env python3
"""mu_styles.py — chuyển TỰ ĐỘNG các kiểu vẽ đồ của client gốc sang Godot.

Đọc:
  <source>/Render/Items/ItemRenderStyles.cpp   (≈140 kiểu "renderStyle" của Data/Items/Models)
  <source>/Engine/Object/ZzzOpenData.cpp       (BITMAP_xxx -> file texture)
Ghi:
  assets/mu/item_styles.json   {"<renderStyle>": {"passes": [...], "partial": bool}}
  assets/mu/fx/<texture>.jpg|png  (texture hiệu ứng mà các kiểu cần, giải mã OZJ/OZT từ Client/Data)

Mỗi "pass" là một lần b->RenderMesh / b->RenderBody của code gốc:
  {"mesh": -1 (cả thân) | n, "flags": [...], "alpha": "<glsl>", "blend_mesh": n, "blend_light": "<glsl>",
   "u": "<glsl>", "v": "<glsl>", "hidden": n, "texture": "<tên file>"|null, "light": ["<glsl>"x3]}
Biểu thức được dịch sang GLSL: T = WorldTime (ms), body = BodyLight lúc vào kiểu (ánh sáng theo cấp).
Godot (src/mu/MuItemStyles.gd) dựng shader cho từng pass từ dữ liệu này.
"""
import json
import os
import re
import sys

# ---------------------------------------------------------------- tiện ích phân tích C++
def strip_comments(src):
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    return re.sub(r'//[^\n]*', '', src)


def find_functions(src):
    """name -> body (không gồm ngoặc ngoài) của mọi hàm 'bool RenderXxx(...)'."""
    out = {}
    for m in re.finditer(r'\bbool\s+(Render\w+)\s*\(([^)]*)\)\s*\{', src):
        name = m.group(1)
        i = m.end()
        depth = 1
        j = i
        while j < len(src) and depth:
            if src[j] == '{':
                depth += 1
            elif src[j] == '}':
                depth -= 1
            j += 1
        out[name] = src[i:j - 1]
    return out


def style_table(src):
    """renderStyle -> (tên hàm, texture tham số)"""
    tab = {}
    m = re.search(r'RenderStyle\s+\w+\s*\[\s*\]\s*=\s*\{(.*?)\n\};', src, flags=re.S)
    body = m.group(1) if m else src
    for e in re.finditer(r'\{\s*"(\w+)"\s*,\s*(\w+)\s*(?:,\s*([\w &+]+?))?\s*\}', body):
        tex = e.group(3)
        if tex and (tex.startswith('&') or not tex.strip().startswith('BITMAP')):
            tex = None
        tab[e.group(1)] = (e.group(2), tex.strip() if tex else None)
    return tab


def bitmap_files(src):
    """BITMAP_X (+n) -> 'Effect\\flare01.jpg'"""
    out = {}
    for m in re.finditer(r'LoadBitmap\(\s*L?"([^"]+)"\s*,\s*([A-Z0-9_]+(?:\s*\+\s*\d+)?)', src):
        key = re.sub(r'\s+', '', m.group(2))
        out[key] = m.group(1).replace('\\\\', '\\')
    return out


def split_statements(body):
    """Tách thân hàm thành câu lệnh; if/else giữ thành ('if', cond, then_body, else_body)."""
    stmts = []
    i = 0
    n = len(body)
    while i < n:
        while i < n and body[i] in ' \t\r\n;':
            i += 1
        if i >= n:
            break
        if body.startswith('if', i) and re.match(r'if\s*\(', body[i:]):
            j = body.index('(', i)
            depth = 0
            k = j
            while k < n:
                if body[k] == '(':
                    depth += 1
                elif body[k] == ')':
                    depth -= 1
                    if depth == 0:
                        break
                k += 1
            cond = body[j + 1:k]
            k += 1
            then_body, k = _block(body, k)
            else_body = ''
            m = re.match(r'\s*else\b', body[k:])
            if m:
                k += m.end()
                if re.match(r'\s*if\b', body[k:]):
                    # else if ... : phần còn lại coi như một khối
                    rest_start = k
                    _, k2 = _if_extent(body, k)
                    else_body = body[rest_start:k2]
                    k = k2
                else:
                    else_body, k = _block(body, k)
            stmts.append(('if', cond, then_body, else_body))
            i = k
            continue
        depth = 0
        j = i
        while j < n:
            c = body[j]
            if c in '({':
                depth += 1
            elif c in ')}':
                depth -= 1
            elif c == ';' and depth == 0:
                break
            j += 1
        stmts.append(body[i:j].strip())
        i = j + 1
    return stmts


def _block(body, k):
    while k < len(body) and body[k] in ' \t\r\n':
        k += 1
    if k < len(body) and body[k] == '{':
        depth = 0
        j = k
        while j < len(body):
            if body[j] == '{':
                depth += 1
            elif body[j] == '}':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        return body[k + 1:j], j + 1
    j = body.index(';', k)
    return body[k:j + 1], j + 1


def _if_extent(body, k):
    m = re.match(r'\s*if\s*\(', body[k:])
    j = k + m.end() - 1
    depth = 0
    while j < len(body):
        if body[j] == '(':
            depth += 1
        elif body[j] == ')':
            depth -= 1
            if depth == 0:
                break
        j += 1
    _, j = _block(body, j + 1)
    m = re.match(r'\s*else\b', body[j:])
    if m:
        j += m.end()
        if re.match(r'\s*if\b', body[j:]):
            return _if_extent(body, j)
        _, j = _block(body, j)
    return None, j


def split_args(s):
    args = []
    depth = 0
    cur = ''
    for c in s:
        if c in '([':
            depth += 1
        elif c in ')]':
            depth -= 1
        if c == ',' and depth == 0:
            args.append(cur.strip())
            cur = ''
        else:
            cur += c
    if cur.strip():
        args.append(cur.strip())
    return args


# ---------------------------------------------------------------- dịch biểu thức sang GLSL
class Ctx:
    def __init__(self, texture_param):
        self.vars = {}            # biến cục bộ -> glsl
        self.vec = {'Light': ['body.x', 'body.y', 'body.z']}
        self.light = ['body.x', 'body.y', 'body.z']   # b->BodyLight hiện tại
        self.blend_light = '1.0'
        self.u = '0.0'
        self.v = '0.0'
        self.stream = -1
        self.texture_param = texture_param
        self.partial = False


FUNCS = {'sinf': 'sin', 'cosf': 'cos', 'sin': 'sin', 'cos': 'cos', 'absf': 'abs', 'fabsf': 'abs', 'fabs': 'abs',
         'std::abs': 'abs', 'powf': 'pow', 'sqrtf': 'sqrt', 'std::min': 'min', 'std::max': 'max', 'min': 'min',
         'max': 'max', 'std::sin': 'sin', 'std::cos': 'cos', 'std::fmod': 'mod', 'fmodf': 'mod', 'fmod': 'mod'}


def to_glsl(expr, ctx):
    e = expr.strip()
    e = re.sub(r'static_cast<\s*(?:float|double)\s*>', 'float', e)
    e = re.sub(r'static_cast<\s*(?:int|long|DWORD|unsigned int)\s*>', 'int_', e)
    e = re.sub(r'\(\s*(?:float|double)\s*\)', 'float', e)
    e = re.sub(r'\(\s*(?:int|long)\s*\)', 'int_', e)
    e = re.sub(r'(\d+\.\d*|\.\d+|\d+)[fF]\b', r'\1', e)
    e = e.replace('look.blendMeshLight', '(' + ctx.blend_light + ')')
    e = e.replace('look.blendMeshU', '(' + ctx.u + ')').replace('look.blendMeshV', '(' + ctx.v + ')')
    e = e.replace('look.alpha', '1.0').replace('o->Alpha', '1.0')
    e = re.sub(r'\bAlpha\b', '1.0', e)
    for i, c in enumerate('xyz'):
        e = e.replace('b->BodyLight[%d]' % i, '(' + ctx.light[i] + ')')
    for name, comps in ctx.vec.items():
        for i in range(3):
            e = re.sub(r'\b' + re.escape(name) + r'\s*\[\s*' + str(i) + r'\s*\]', '(' + comps[i] + ')', e)
    for name, val in sorted(ctx.vars.items(), key=lambda kv: -len(kv[0])):
        e = re.sub(r'\b' + re.escape(name) + r'\b', '(' + val + ')', e)
    # hàm phụ của ItemRenderStyles.cpp (không dịch thì thành "0.0(" -> shader lỗi biên dịch)
    e = re.sub(r'\bBlendMeshPulse\s*\(\s*\)', '(sin(WorldTime * 0.002) * 0.3 + 0.7)', e)
    e = re.sub(r'\bReferenceFrames\s*\(\s*\)', '(WorldTime * 0.025)', e)   # REFERENCE_FPS 25
    e = re.sub(r'\bWorldTime\b', 'T', e)
    # Random::DrawRand(o, k) % n: số ngẫu nhiên mỗi lần vẽ -> băm theo thời gian (đổi ~60 lần/giây)
    e = re.sub(r'Random::DrawRand\s*\(\s*\w+\s*,\s*(\d+)\s*\)\s*%\s*(\d+)',
               r'floor(fract(sin((floor(T * 0.06) + \1.0) * 12.9898) * 43758.5453) * \2.0)', e)
    e = re.sub(r'(?<![\w:])int\s*\(', 'int_(', e)   # ép kiểu dạng hàm int(x)
    for k, v in FUNCS.items():
        e = re.sub(r'(?<![\w:])' + re.escape(k) + r'\s*\(', v + '(', e)
    # a % b  ->  mod(a, b)   (chỉ dạng đơn giản: <nhóm> % <số>)
    for _ in range(4):
        e2 = re.sub(r'(int_\([^()]*\)|\([^()]*\)|-?\w+(?:\.\w+)?)\s*%\s*(\d+(?:\.\d+)?)', r'mod(\1, \2.0)', e)
        if e2 == e:
            break
        e = e2
    e = e.replace('int_(', 'floor(')
    # số nguyên -> số thực
    e = re.sub(r'(?<![\w.])(\d+)(?![\w.])', r'\1.0', e)
    e = e.replace('.0.0', '.0')
    # dạng số an toàn cho shader Godot: "1." -> "1.0", ".9" -> "0.9"
    e = re.sub(r'(\d)\.(?!\d)', r'\1.0', e)
    e = re.sub(r'(?<![\w.])\.(\d)', r'0.\1', e)
    # định danh lạ (o->, gMapManager, ...)
    bad = [t for t in re.findall(r'[A-Za-z_][\w:>-]*', e)
           if t not in ('T', 'body', 'x', 'y', 'z', 'sin', 'cos', 'abs', 'pow', 'sqrt', 'min', 'max', 'mod', 'floor', 'float', 'fract')
           and not t.startswith('body.')]
    if bad:
        ctx.partial = True
        for t in sorted(set(bad), key=len, reverse=True):
            e = re.sub(r'(?<![\w.])' + re.escape(t) + r'(?:\s*\.\s*\w+|\s*\[\s*\d+\s*\])?', '0.0', e)
    return e or '0.0'


FLAG_NAMES = ['RENDER_TEXTURE', 'RENDER_BRIGHT', 'RENDER_DARK', 'RENDER_CHROME', 'RENDER_CHROME2', 'RENDER_CHROME3',
              'RENDER_CHROME4', 'RENDER_CHROME5', 'RENDER_CHROME6', 'RENDER_CHROME7', 'RENDER_METAL', 'RENDER_OIL',
              'RENDER_LIGHTMAP', 'RENDER_NODEPTH', 'RENDER_EXTRA', 'RENDER_WAVE']


def flags_of(expr):
    if expr.strip() in ('RenderType', 'renderType'):
        return ['RENDER_TEXTURE']
    f = [x for x in FLAG_NAMES if re.search(r'\b' + x + r'\b', expr)]
    if 'RenderType' in expr and 'RENDER_TEXTURE' not in f:
        f.append('RENDER_TEXTURE')
    return f or ['RENDER_TEXTURE']


def texture_of(arg, ctx, bitmaps):
    a = arg.strip()
    if a in ('Texture', 'texture'):
        a = ctx.texture_param or ''
    a = re.sub(r'\s+', '', a)
    if not a.startswith('BITMAP'):
        return None
    path = bitmaps.get(a)
    if path is None:
        ctx.partial = True
        return None
    return path


def translate(body, ctx, bitmaps, passes):
    for st in split_statements(body):
        if isinstance(st, tuple):
            _, cond, then_b, else_b = st
            if 'DOPPELGANGER' in cond:
                translate(else_b, ctx, bitmaps, passes)   # vẽ thường cho người chơi
                continue
            ctx.partial = True
            translate(then_b, ctx, bitmaps, passes)
            continue
        s = st.strip()
        if not s or s.startswith('return') or s.startswith('b->BeginRender') or s.startswith('b->EndRender'):
            continue
        m = re.match(r'vec3_t\s+([\w\s,]+)$', s)
        if m:
            for name in m.group(1).split(','):
                ctx.vec[name.strip()] = ['0.0', '0.0', '0.0']
            continue
        m = re.match(r'VectorCopy\(\s*b->BodyLight\s*,\s*(\w+)\s*\)', s)
        if m:
            ctx.vec[m.group(1)] = list(ctx.light)
            continue
        m = re.match(r'VectorCopy\(\s*(\w+)\s*,\s*b->BodyLight\s*\)', s)
        if m:
            ctx.light = list(ctx.vec.get(m.group(1), ['body.x', 'body.y', 'body.z']))
            continue
        m = re.match(r'Vector\((.*)\)$', s, flags=re.S)
        if m:
            a = split_args(m.group(1))
            if len(a) == 4:
                comps = [to_glsl(x, ctx) for x in a[:3]]
                if a[3].replace(' ', '') == 'b->BodyLight':
                    ctx.light = comps
                else:
                    ctx.vec[a[3].strip()] = comps
            continue
        m = re.match(r'(?:const\s+)?(?:float|double|auto|int)\s+(\w+)\s*=\s*(.+)$', s, flags=re.S)
        if m:
            ctx.vars[m.group(1)] = to_glsl(m.group(2), ctx)
            continue
        m = re.match(r'(\w+)\s*=\s*(.+)$', s, flags=re.S)
        if m and m.group(1) in ctx.vars:
            ctx.vars[m.group(1)] = to_glsl(m.group(2), ctx)
            continue
        m = re.match(r'look\.(blendMeshLight|blendMeshU|blendMeshV)\s*=\s*(.+)$', s, flags=re.S)
        if m:
            val = to_glsl(m.group(2), ctx)
            if m.group(1) == 'blendMeshLight':
                ctx.blend_light = val
            elif m.group(1) == 'blendMeshU':
                ctx.u = val
            else:
                ctx.v = val
            continue
        m = re.match(r'b->StreamMesh\s*=\s*(-?\d+)', s)
        if m:
            ctx.stream = int(m.group(1))
            continue
        m = re.match(r'b->(RenderBody|RenderMesh)\((.*)\)$', s, flags=re.S)
        if m:
            a = split_args(m.group(2))
            body_call = m.group(1) == 'RenderBody'
            if not body_call:
                mesh = a.pop(0)
                try:
                    mesh_i = int(mesh)
                except ValueError:
                    ctx.partial = True
                    continue
            else:
                mesh_i = -1
            # (flags, alpha, blendMesh, blendMeshLight, u, v, [hidden], [texture])
            a += [''] * (8 - len(a))
            p = {
                'mesh': mesh_i,
                'flags': flags_of(a[0]),
                'alpha': to_glsl(a[1] or '1', ctx),
                'blend_mesh': _int(a[2].replace('look.blendMesh', '-1'), -1),
                'blend_light': to_glsl(a[3] or 'look.blendMeshLight', ctx),
                'u': to_glsl(a[4] or '0', ctx),
                'v': to_glsl(a[5] or '0', ctx),
                'hidden': -1,
                'texture': None,
                'light': list(ctx.light),
                'stream': ctx.stream,
            }
            if body_call:
                p['hidden'] = _int(a[6].replace('look.hiddenMesh', '-1'), -1) if a[6] else -1
                p['texture'] = texture_of(a[7], ctx, bitmaps) if a[7] else None
            else:
                p['texture'] = texture_of(a[6], ctx, bitmaps) if a[6] else None
            passes.append(p)
            continue
        # câu lệnh khác (CreateSprite, VectorScale...) -> không dịch được
        ctx.partial = True


def _int(s, default):
    try:
        return int(str(s).strip())
    except ValueError:
        return default


# ---------------------------------------------------------------- texture
def decode_texture(client_data, rel, out_dir):
    """rel 'Effect\\flare01.jpg' -> assets/mu/fx/styles/flare01.jpg|png ; trả về tên (không đuôi)"""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    rel = rel.replace('\\', '/')
    stem, ext = os.path.splitext(rel)
    name = os.path.basename(stem)
    cands = [stem + ('.OZJ' if ext.lower() == '.jpg' else '.OZT'), stem + ('.ozj' if ext.lower() == '.jpg' else '.ozt'), rel]
    src = None
    for c in cands:
        p = os.path.join(client_data, c)
        if os.path.isfile(p):
            src = p
            break
        d = os.path.dirname(p)
        if os.path.isdir(d):
            low = os.path.basename(p).lower()
            for f in os.listdir(d):
                if f.lower() == low:
                    src = os.path.join(d, f)
                    break
        if src:
            break
    if src is None:
        return None
    data = open(src, 'rb').read()
    os.makedirs(out_dir, exist_ok=True)
    if src.lower().endswith('.ozj'):
        open(os.path.join(out_dir, name + '.jpg'), 'wb').write(data[24:])
    elif src.lower().endswith('.ozt'):
        from mu_convert_all import decode_ozt, png_bytes
        d = decode_ozt(data)
        if not d:
            return None
        open(os.path.join(out_dir, name + '.png'), 'wb').write(png_bytes(d[0], d[1], d[2]))
    else:
        open(os.path.join(out_dir, os.path.basename(src)), 'wb').write(data)
    return name


def main_all(source_root, client_data, mugodot, log=print):
    rs = os.path.join(source_root, 'Render', 'Items', 'ItemRenderStyles.cpp')
    od = os.path.join(source_root, 'Engine', 'Object', 'ZzzOpenData.cpp')
    if not os.path.isfile(rs):
        log('  [styles] không thấy %s (đặt source_root trong mu_toolkit.json)' % rs)
        return False
    src = strip_comments(open(rs, encoding='utf-8', errors='replace').read())
    bitmaps = bitmap_files(strip_comments(open(od, encoding='utf-8', errors='replace').read())) if os.path.isfile(od) else {}
    funcs = find_functions(src)
    table = style_table(src)
    fx_dir = os.path.join(mugodot, 'assets', 'mu', 'fx', 'styles')
    out = {}
    textures = {}
    partial = 0
    for style, (fn, tex) in table.items():
        body = funcs.get(fn)
        if body is None:
            continue
        ctx = Ctx(tex)
        passes = []
        translate(body, ctx, bitmaps, passes)
        for p in passes:
            if p['texture']:
                if p['texture'] not in textures:
                    textures[p['texture']] = decode_texture(client_data, p['texture'], fx_dir) or \
                        os.path.splitext(os.path.basename(p['texture'].replace('\\', '/')))[0]
                p['texture'] = textures[p['texture']]
        out[style] = {'passes': passes, 'partial': ctx.partial}
        partial += 1 if ctx.partial else 0
    path = os.path.join(mugodot, 'assets', 'mu', 'item_styles.json')
    json.dump(out, open(path, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    log('  [styles] %d kiểu vẽ đồ (%d có phần không dịch được), %d texture -> %s' % (
        len(out), partial, len([t for t in textures.values() if t]), path))
    return True


if __name__ == '__main__':
    main_all(sys.argv[1], sys.argv[2], sys.argv[3])
