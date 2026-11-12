"""mu_monster_fx.py — Trích hiệu ứng TRÊN NGƯỜI quái từ source client gốc cho MuGodot.

Quét các hàm hiệu ứng quái của client gốc (ZzzCharacter.cpp: UpdateCharacterTypeEffects / MoveCharacterVisual /
UpdateMonsterBodyEffects, và *MonsterVisual / *MonsterEffects của từng bản đồ: Aida, Kanturu, Crywolf, Raklion,
Swamp, Karutan, Kalima (Hellas), Balgass, Empire Guardian, Doppelganger...). Với mỗi khối `case MODEL_xxx:` /
`o->Type == MODEL_xxx` / `MonsterIndex == MONSTER_xxx` lấy các lệnh chạy LIÊN TỤC (không phụ thuộc CurrentAction,
AttackTime...):
    CreateSprite(BITMAP_*, vị trí xương, Scale, Light, ..., Rotation, SubType)
    CreateParticle[FpsChecked](BITMAP_*, vị trí xương, Angle, Light, SubType, Scale)
kèm xương (BoneTransform[N], TransformByObjectBone(.., N), BoneManager::GetBonePosition(.., L"tên")), màu Light,
tần suất (rand_fps_check(n)).

Kết quả: assets/mu/monster_fx.json
    { "slots": {"WITCH_QUEEN": [fx...]}, "monsters": {"304": [fx...]} }
    fx = {"call": "sprite"|"particle", "tex": "flare01", "bones": [..], "scale": 1.0, "color": [r,g,b],
          "rot": độ/giây, "sub": SubType, "blend": "add"|"sub", "rate": hạt/giây, "flicker": bool, "src": "file:dòng"}
và texture cần dùng giải mã vào assets/mu/fx/skill/.

    python -I tools/mu_monster_fx.py E:/MuMain/Source/src/source E:/MuMain/Client/Data E:/MuMain/MuGodot
"""
import glob
import json
import os
import re
import sys

SRC_FUNCS = re.compile(
    r'^(?:bool|void)\s+([\w:]*(?:Monster\w*(?:Visual|Effects)|UpdateCharacterTypeEffects|MoveCharacterVisual|'
    r'UpdateMonsterBodyEffects)\w*)\s*\(', re.M)
TRANSIENT = re.compile(r'CurrentAction|AttackTime|->Dead|\bDead\b|LifeTime|AnimationFrame|->Skill|Kind\b|'
                       r'IsBuff|g_isCharacterBuff|Teleport|SceneFlag|Change\b|m_b|InChaosCastle|Blood\b|'
                       r'GetBaseClass|Class\b|PriorAction|Helper|Wing|Weapon|MONSTER01_')
SUBJECT_CASE = re.compile(r'^\s*case\s+((?:MODEL|MONSTER)_\w+)(?:\s*\+\s*(\d+))?\s*:')
SUBJECT_IF = re.compile(r'(?:->Type|MonsterIndex)\s*==\s*((?:MODEL|MONSTER)_\w+)(?:\s*\+\s*(\d+))?')
CTRL = re.compile(r'^\s*(?:\}\s*)?(if|else|for|while|switch|case|default)\b')


def num(expr, names=None):
    """Đánh giá biểu thức số đơn giản của C ("0.4f", "Luminosity * 0.6f", "1.5f + fLumi / 2.f")."""
    e = expr.strip()
    e = re.sub(r'(\d+\.?\d*)f\b', r'\1', e)
    e = re.sub(r'\(float\)', '', e)
    flick = False
    for w in set(re.findall(r'[A-Za-z_]\w*', e)):
        if w in ('sinf', 'cosf'):
            continue
        flick = True
        e = re.sub(r'\b%s\b' % w, '1.0', e)
    e = e.replace('sinf', '0*').replace('cosf', '0*')
    try:
        return float(eval(e, {'__builtins__': {}})), flick
    except Exception:
        return 1.0, True


def split_args(s):
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch == '(':
            depth += 1
        elif ch == ')':
            if depth == 0:
                break
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur.strip())
            cur = ''
        else:
            cur += ch
    out.append(cur.strip())
    return out


def func_bodies(text):
    for m in SRC_FUNCS.finditer(text):
        i = text.find('{', m.end())
        if i < 0:
            continue
        # bỏ khai báo (dấu ; trước dấu {)
        if ';' in text[m.end():i]:
            continue
        depth, j = 0, i
        while j < len(text):
            if text[j] == '{':
                depth += 1
            elif text[j] == '}':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        yield m.group(1), text.count('\n', 0, i) + 1, text[i:j + 1]


def load_enums(src):
    t = open(os.path.join(src, 'Core', 'Globals', '_enum.h'), encoding='utf-8', errors='replace').read()
    model_off = {m.group(1): int(m.group(2)) for m in re.finditer(r'\b(MODEL_\w+)\s*=\s*MODEL_MONSTER01\s*\+\s*(\d+)', t)}
    slot_by_idx = {}
    for m in re.finditer(r'\bMONSTER_MODEL_(\w+)\s*=\s*(\d+)', t):
        slot_by_idx.setdefault(int(m.group(2)), m.group(1))
    monsters = {}
    for m in re.finditer(r'\b(MONSTER_(?!MODEL_)\w+)\s*=\s*(\d+)\s*,', t):
        monsters.setdefault(m.group(1), int(m.group(2)))
    return model_off, slot_by_idx, monsters


def load_bitmaps(src):
    out = {}
    for f in glob.glob(os.path.join(src, '**', '*.cpp'), recursive=True):
        for m in re.finditer(r'LoadBitmap\(\s*L"([^"]+)"\s*,\s*(BITMAP_\w+(?:\s*\+\s*\d+)?)',
                             open(f, encoding='utf-8', errors='replace').read()):
            key = re.sub(r'\s+', '', m.group(2))
            out.setdefault(key, m.group(1).replace('\\\\', '/').replace('\\', '/'))
    return out


def load_registered_bones(src):
    out = {}
    for f in glob.glob(os.path.join(src, '**', '*.cpp'), recursive=True):
        for m in re.finditer(r'RegisterBone\(\s*\w+\s*,\s*L"(\w+)"\s*,\s*(\d+)\s*\)',
                             open(f, encoding='utf-8', errors='replace').read()):
            out.setdefault(m.group(1), int(m.group(2)))
    return out


def extract_block_fx(lines, start_line, fname, arrays, regbones):
    """Duyệt các dòng của 1 hàm: trả về [(subjects, fx)]"""
    results = []
    stack = []  # (indent, text)
    lights = {}
    bones = None
    prev_case = False
    for k, raw in enumerate(lines):
        line = raw.split('//')[0].rstrip()
        if not line.strip():
            continue
        ind = len(line) - len(line.lstrip())
        s = line.strip()
        if s in ('{', '}', '};', '{}'):
            continue
        # đóng các khối có thụt lề >= dòng hiện tại
        mcase = SUBJECT_CASE.match(line)
        # các nhãn case đứng liền nhau dùng chung 1 khối ; sau break thì case mới là khối mới
        keep = mcase and prev_case
        while stack and stack[-1][0] >= ind and not (keep and stack[-1][1].startswith('case') and stack[-1][0] == ind):
            stack.pop()
        prev_case = bool(mcase) or (prev_case and s.startswith('case '))
        if mcase:
            name = mcase.group(1) + ('+' + mcase.group(2) if mcase.group(2) else '')
            if keep and stack and stack[-1][1].startswith('case') and stack[-1][0] == ind:
                stack[-1] = (ind, stack[-1][1] + ' ' + name)
            else:
                stack.append((ind, 'case ' + name))
            bones = None
            continue
        if CTRL.match(line):
            stack.append((ind, s))
            mif = SUBJECT_IF.search(s)
            if mif:
                bones = None
            # mảng xương cục bộ / for (int i = a; i < b
            continue
        for m in re.finditer(r'(\w+)\s*\[\s*\w*\s*\]\s*=\s*\{([\d,\s]+)\}', s):
            arrays[m.group(1)] = [int(x) for x in m.group(2).split(',') if x.strip()]
        mv = re.search(r'\bVector\((.+),\s*(\w+)\)\s*;', s)
        if mv:
            args = split_args(mv.group(1) + ')')
            if len(args) == 3:
                vals = [num(a) for a in args]
                lights[mv.group(2)] = ([round(v[0], 3) for v in vals], any(v[1] for v in vals))
        # xương
        mb = (re.search(r'BoneTransform\[\s*(\d+)\s*\]', s) or re.search(r'TransformByObjectBone\(\s*\w+\s*,\s*\w+\s*,\s*(\d+)', s))
        if mb:
            bones = [int(mb.group(1))]
        ma = re.search(r'BoneTransform\[\s*(\w+)\[\s*\w+\s*\]\s*\]', s) or re.search(r'TransformByObjectBone\(\s*\w+\s*,\s*\w+\s*,\s*(\w+)\[\s*\w+\s*\]', s)
        if ma and ma.group(1) in arrays:
            bones = list(arrays[ma.group(1)])
            for c in stack:
                mf = re.search(r'for\s*\(\s*\w+\s+\w+\s*=\s*(\d+)\s*;\s*\w+\s*<\s*(=?)\s*(\d+)', c[1])
                if mf:
                    bones = bones[int(mf.group(1)):int(mf.group(3)) + (1 if mf.group(2) else 0)]
        mi = re.search(r'BoneTransform\[\s*(\w+)\s*\]', s) or re.search(r'TransformByObjectBone\(\s*\w+\s*,\s*\w+\s*,\s*([a-z]\w*)\s*\)', s)
        if mi and not mi.group(1).isdigit() and mi.group(1) not in arrays:
            for c in reversed(stack):
                mf = re.search(r'for\s*\(\s*\w+\s+%s\s*=\s*(\d+)\s*;\s*%s\s*<\s*(=?)\s*(\d+)' % (mi.group(1), mi.group(1)), c[1])
                if mf:
                    bones = list(range(int(mf.group(1)), int(mf.group(3)) + (1 if mf.group(2) else 0)))
                    break
        mn = re.search(r'GetBonePosition\(\s*\w+\s*,\s*L"(\w+)"', s)
        if mn and mn.group(1) in regbones:
            bones = [regbones[mn.group(1)]]
        # lệnh tạo hiệu ứng
        mc = re.search(r'\b(CreateSprite|CreateParticle|CreateParticleFpsChecked)\(\s*(BITMAP_\w+(?:\s*\+\s*\d+)?)\s*,(.*)', s)
        if not mc:
            continue
        subjects = []
        transient = False
        rate_div = 1.0
        for c in stack:
            if c[1].startswith('case'):
                subjects = c[1].split()[1:]
            mif = SUBJECT_IF.search(c[1])
            if mif:
                subjects = [mif.group(1) + ('+' + mif.group(2) if mif.group(2) else '')]
            if TRANSIENT.search(c[1]):
                transient = True
            mr = re.search(r'rand_fps_check\(\s*(\d+)\s*\)', c[1]) or re.search(r'Rand\(\)\s*%\s*(\d+)', c[1])
            if mr:
                rate_div *= max(1, int(mr.group(1)))
        if not subjects or transient or bones is None:
            continue
        args = split_args(mc.group(3))
        bmp = re.sub(r'\s+', '', mc.group(2))
        fx = {'call': 'sprite' if mc.group(1) == 'CreateSprite' else 'particle', 'bitmap': bmp, 'bones': bones,
              'src': '%s:%d' % (fname, start_line + k)}
        if fx['call'] == 'sprite':
            # (Position, Scale, Light, Owner, Rotation, SubType)
            sc, f1 = num(args[1]) if len(args) > 1 else (1.0, False)
            fx['scale'] = round(sc, 3)
            col, f2 = lights.get(args[2], ([1.0, 1.0, 1.0], False)) if len(args) > 2 else ([1.0, 1.0, 1.0], False)
            fx['color'] = col
            fx['flicker'] = f1 or f2
            if len(args) > 4 and 'WorldTime' in args[4]:
                fx['rot'] = (-1 if '-' in args[4].split('WorldTime')[0] else 1) * 100.0
            sub = int(num(args[5])[0]) if len(args) > 5 else 0
            fx['blend'] = 'sub' if sub == 1 else 'add'
        else:
            # (Position, Angle, Light, SubType, Scale, Owner)
            col, f2 = lights.get(args[2], ([1.0, 1.0, 1.0], False)) if len(args) > 2 else ([1.0, 1.0, 1.0], False)
            fx['color'] = col
            fx['sub'] = int(num(args[3])[0]) if len(args) > 3 else 0
            fx['scale'] = round(num(args[4])[0], 3) if len(args) > 4 else 1.0
            r = 25.0 / rate_div
            if re.search(r'rand_fps_check\(\s*(\d+)\s*\)', s):
                r /= int(re.search(r'rand_fps_check\(\s*(\d+)\s*\)', s).group(1))
            fx['rate'] = round(r, 2)
        results.append((subjects, fx))
    return results


def decode_texture(data_dir, rel, out_dir):
    """Data/<rel>.jpg|tga -> OZJ (JPEG sau 24 byte) | OZT (TGA sau 4 byte) -> png/jpg"""
    stem = os.path.splitext(os.path.basename(rel))[0]
    for ext in ('.jpg', '.png'):
        if os.path.exists(os.path.join(out_dir, stem + ext)):
            return stem
    base = os.path.join(data_dir, os.path.splitext(rel)[0])
    for ext, skip in (('.OZJ', 24), ('.ozj', 24), ('.OZT', 4), ('.ozt', 4)):
        p = base + ext
        if os.path.exists(p):
            raw = open(p, 'rb').read()[skip:]
            try:
                import io
                from PIL import Image
                im = Image.open(io.BytesIO(raw))
                if ext.lower() == '.ozj':
                    im.convert('RGB').save(os.path.join(out_dir, stem + '.jpg'), quality=95)
                else:
                    im.convert('RGBA').save(os.path.join(out_dir, stem + '.png'))
                return stem
            except Exception:
                return None
    return None


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else r'E:/MuMain/Source/src/source'
    data_dir = sys.argv[2] if len(sys.argv) > 2 else r'E:/MuMain/Client/Data'
    godot = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    model_off, slot_by_idx, monster_ids = load_enums(src)
    bitmaps = load_bitmaps(src)
    regbones = load_registered_bones(src)
    tex_dir = os.path.join(godot, 'assets', 'mu', 'fx', 'skill')
    os.makedirs(tex_dir, exist_ok=True)

    out = {'slots': {}, 'monsters': {}}
    missing_tex = set()
    n_fx = 0
    for f in sorted(glob.glob(os.path.join(src, '**', '*.cpp'), recursive=True)):
        text = open(f, encoding='utf-8', errors='replace').read()
        fname = os.path.basename(f)
        for func, line0, body in func_bodies(text):
            arrays = {m.group(1): [int(x) for x in m.group(2).split(',') if x.strip()]
                      for m in re.finditer(r'(\w+)\s*\[\s*\d*\s*\]\s*=\s*\{([\d,\s]+)\}', text)}
            for subjects, fx in extract_block_fx(body.split('\n'), line0, fname, arrays, regbones):
                rel = bitmaps.get(fx['bitmap'])
                stem = decode_texture(data_dir, rel, tex_dir) if rel else None
                if not stem:
                    missing_tex.add(fx['bitmap'])
                    continue
                fx['tex'] = stem
                for subj in subjects:
                    base = subj.split('+')[0]
                    add = int(subj.split('+')[1]) if '+' in subj else 0
                    if base.startswith('MODEL_') and base in model_off:
                        slot = slot_by_idx.get(model_off[base] + add)
                        if slot:
                            out['slots'].setdefault(slot, []).append(fx)
                            n_fx += 1
                    elif base == 'MODEL_MONSTER01':
                        slot = slot_by_idx.get(add)
                        if slot:
                            out['slots'].setdefault(slot, []).append(fx)
                            n_fx += 1
                    elif base in monster_ids:
                        out['monsters'].setdefault(str(monster_ids[base] + add), []).append(fx)
                        n_fx += 1
    # bỏ trùng lặp (một khối có thể bị quét bởi 2 hàm)
    for grp in out.values():
        for k in grp:
            seen, uniq = set(), []
            for fx in grp[k]:
                key = json.dumps({a: b for a, b in fx.items() if a != 'src'}, sort_keys=True)
                if key not in seen:
                    seen.add(key)
                    uniq.append(fx)
            grp[k] = uniq
    p = os.path.join(godot, 'assets', 'mu', 'monster_fx.json')
    json.dump(out, open(p, 'w', encoding='utf-8'), indent=1)
    print('[monster_fx] %d model, %d quái riêng, %d hiệu ứng -> %s' % (len(out['slots']), len(out['monsters']), n_fx, p))
    if missing_tex:
        print('  thiếu texture:', ', '.join(sorted(missing_tex))[:600])


if __name__ == '__main__':
    main()
