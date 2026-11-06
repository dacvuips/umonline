#!/usr/bin/env python3
"""mu_skill_fx.py — Trích hiệu ứng của MỌI skill từ source client gốc cho MuGodot.

Ghi:
  assets/mu/skill_fx.json   { "skills": { "<số skill>": {
                                   "name", "action": "<PLAYER_...>"|"magic"|"attack", "action_index": int,
                                   "sounds": ["sKnightSkill4.wav", ...],
                                   "fx": [ {"call": "effect"|"joint"|"particle"|"sprite", "type": "MODEL_FIRE",
                                            "sub": int, "at": "self"|"target", "count": int} ],
                                   "src": ["ZzzCharacter.cpp:4960", ...], "base": <skill gốc nếu kế thừa> } },
                              "types": { "MODEL_FIRE": {"glb": "Skill/Fire01", "tex": "flare01",
                                   "life": ticks, "velocity": float, "scale": float,
                                   "motion": "homing"|"follow"|"forward"|"static", "children": [...]} } }
  assets/mu/fx/skill/*.jpg|png  (texture mà các hiệu ứng cần, giải mã OZJ/OZT từ Client/Data)

Nguồn (Source/src/source):
  Core/Globals/_enum.h                  số AT_SKILL_*, chỉ số PLAYER_* (hành động), bảng skill nâng cấp -> skill gốc
  Engine/Object/ZzzCharacter.cpp        CreateEffect/Joint/Particle + PlayBuffer theo skill (lúc ra đòn)
  GameLogic/Combat/SkillCast.cpp,
  GameLogic/Combat/ClassAttack.cpp,
  Network/Server/WSclient.cpp,
  GameLogic/Social/MonkSystem.cpp,
  GameLogic/Skills/SummonSystem.cpp     SetAction / SetPlayerMagic + hiệu ứng / âm thanh theo skill
  Engine/Object/ZzzOpenData.cpp         MODEL_* -> .bmd (glb), BITMAP_* -> texture, SOUND_* -> .wav
  Render/Effects/ZzzEffect*.cpp         LifeTime / Velocity / Scale lúc tạo hiệu ứng
  Render/Effects/Behaviors/MoveHandlers.cpp   kiểu chuyển động (bay theo mục tiêu / bám người / đứng yên)

Đây là bản TỰ ĐỘNG, gần đúng: chuyển động chi tiết của từng hiệu ứng phải port tay
(xem src/effects/TwistingSlashEffect.gd). MuSkillFx.gd ưu tiên hiệu ứng port tay khi có.

    python tools/mu_skill_fx.py <Source/src/source> <Client/Data> <thư mục MuGodot>
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mu_styles import decode_texture, strip_comments  # noqa: E402

CALL_RE = re.compile(r'\b(CreateEffect|CreateJoint|CreateParticle|CreateSprite)(?:FpsChecked)?\s*\(\s*'
                     r'((?:MODEL|BITMAP)_\w+(?:\s*\+\s*\d+)?)\s*,([^;]*)\)\s*;')
SOUND_RE = re.compile(r'\bPlayBuffer\s*\(\s*(SOUND_\w+(?:\s*\+\s*\d+)?)')
ACTION_RE = re.compile(r'\bSetAction\s*\(\s*[\w&>.\-]+\s*,\s*((?:static_cast<int>\()?PLAYER_\w+\)?(?:\s*[+-]\s*(?:\d+|AT_SKILL_\w+))*)\s*\)')
CASE_RE = re.compile(r'^\s*case\s+(AT_SKILL_\w+(?:\s*\+\s*\d+)?)\s*:')
ANY_LABEL_RE = re.compile(r'^\s*(case\s+[^:]+|default)\s*:')

_eval_action = None
CALL_KIND = {'CreateEffect': 'effect', 'CreateJoint': 'joint', 'CreateParticle': 'particle', 'CreateSprite': 'sprite'}


def read(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        return strip_comments(f.read())


def norm(name):
    return re.sub(r'\s+', '', name)


# ---------------------------------------------------------------- enum
def parse_enum_block(lines):
    """Tính giá trị tuần tự của các phần tử enum (hỗ trợ '= số' và '= TÊN + n')."""
    values, cur = {}, -1
    for raw in lines:
        line = raw.split('//')[0].strip().rstrip(',')
        if not line or line.startswith('#'):
            continue
        for part in line.split(','):
            part = part.strip()
            if not part:
                continue
            m = re.match(r'^(\w+)\s*(?:=\s*(.+))?$', part)
            if not m:
                continue
            name, expr = m.group(1), m.group(2)
            if expr is not None:
                e = expr.strip()
                mm = re.match(r'^(\w+)\s*([+-])\s*(\d+)$', e)
                if re.match(r'^-?\d+$', e):
                    cur = int(e)
                elif re.match(r'^0x[0-9a-fA-F]+$', e):
                    cur = int(e, 16)
                elif mm and mm.group(1) in values:
                    cur = values[mm.group(1)] + (int(mm.group(3)) * (1 if mm.group(2) == '+' else -1))
                elif e in values:
                    cur = values[e]
                else:
                    cur += 1
            else:
                cur += 1
            values[name] = cur
    return values


def enum_containing(src, member):
    """Khối enum chứa member (từ 'enum' trước nó tới '};')."""
    k = re.search(r'\b' + member + r'\b', src)
    if not k:
        return []
    start = src.rfind('enum', 0, k.start())
    start = src.find('{', start) + 1
    end = src.find('};', k.start())
    return src[start:end].splitlines()


def skill_bases(src):
    """{AT_SKILL_X_STR, AT_SKILL_X} -> skill nâng cấp kế thừa hiệu ứng của skill gốc."""
    return {a: b for a, b in re.findall(r'\{\s*(AT_SKILL_\w+)\s*,\s*(AT_SKILL_\w+)\s*\}', src)}


# ---------------------------------------------------------------- case-group của switch
def case_groups(src, fname):
    """Tách các nhóm 'case AT_SKILL_...:' (cùng độ sâu ngoặc) -> [(labels, body, line, falls_through)]."""
    lines = src.splitlines()
    groups = []
    depth = 0
    cur = None  # [labels, body_lines, line_no, depth, has_body]

    def close():
        if cur is not None:
            body = '\n'.join(cur[1])
            ends = re.search(r'\b(break|return)\b[^;]*;\s*\}*\s*$', body.strip()) is not None
            groups.append((cur[0], body, '%s:%d' % (fname, cur[2]), not ends))

    for i, line in enumerate(lines):
        m = CASE_RE.match(line)
        lab = ANY_LABEL_RE.match(line)
        if lab and cur is not None and depth <= cur[3]:
            if m and not cur[4] and depth == cur[3]:
                cur[0].append(norm(m.group(1)))
            else:
                close()
                cur = None
        if m and cur is None:
            cur = [[norm(m.group(1))], [], i + 1, depth, False]
        elif cur is not None and not lab:
            cur[1].append(line)
            if line.strip() and line.strip() not in ('{', '}'):
                cur[4] = True
        depth += line.count('{') - line.count('}')
        if cur is not None and depth < cur[3]:
            close()
            cur = None
    close()
    return groups


def _balanced(src, i, open_ch, close_ch):
    """src[i] == open_ch -> chỉ số sau ký tự đóng tương ứng."""
    depth = 0
    for k in range(i, len(src)):
        if src[k] == open_ch:
            depth += 1
        elif src[k] == close_ch:
            depth -= 1
            if depth == 0:
                return k + 1
    return len(src)


def if_groups(src, fname):
    """'if (... Skill == AT_SKILL_X || ...) { ... }' -> [(labels, body, line, False)]."""
    out = []
    for m in re.finditer(r'\bif\s*\(', src):
        p = m.end() - 1
        q = _balanced(src, p, '(', ')')
        cond = src[p:q]
        labels = [norm(x) for x in re.findall(r'Skill\)?\s*==\s*(AT_SKILL_\w+(?:\s*\+\s*\d+)?)', cond)]
        if not labels:
            continue
        r = q
        while r < len(src) and src[r] in ' \t\r\n':
            r += 1
        if r < len(src) and src[r] == '{':
            body = src[r:_balanced(src, r, '{', '}')]
        else:
            body = src[r:src.find(';', r) + 1]
        out.append((labels, body, '%s:%d' % (fname, src.count('\n', 0, m.start()) + 1), False))
    return out


def calls_in(body):
    out = []
    for kind, typ, args in CALL_RE.findall(body):
        a = [x.strip() for x in args.split(',')]
        pos = a[0] if a else ''
        at = 'target' if re.search(r'\b(to|tc|TargetPosition|Target)\b|to->|tc->|TargetPos', pos) else 'self'
        sub_idx = {'CreateEffect': 3, 'CreateParticle': 3, 'CreateJoint': 3, 'CreateSprite': -1}[kind]
        sub = 0
        if 0 <= sub_idx < len(a) and re.match(r'^-?\d+$', a[sub_idx]):
            sub = int(a[sub_idx])
        if kind == 'CreateJoint':
            # CreateJoint(Type, Position, TargetPosition, Angle, SubType, Target, ...)
            sub = int(a[3]) if len(a) > 3 and re.match(r'^-?\d+$', a[3]) else 0
            tgt = a[1] if len(a) > 1 else ''
            if re.search(r'to->|tc->|TargetPosition', tgt) and at == 'self':
                at = 'beam'
        out.append({'call': CALL_KIND[kind], 'type': norm(typ), 'sub': sub, 'at': at})
    return out


def merge_fx(lst):
    seen = {}
    for f in lst:
        k = (f['call'], f['type'], f['sub'], f['at'])
        if k in seen:
            seen[k]['count'] += 1
        else:
            seen[k] = dict(f, count=1)
    return list(seen.values())


# ---------------------------------------------------------------- tài nguyên
def asset_tables(opendata):
    models = {}
    for typ, folder, name, idx in re.findall(
            r'AccessModel\s*\(\s*((?:MODEL)_\w+(?:\s*\+\s*\d+)?)\s*,\s*L"Data\\\\(\w+)\\\\"\s*,\s*L"([^"]+)"\s*(?:,\s*(\d+))?\s*\)', opendata):
        models[norm(typ)] = '%s/%s%s' % (folder, name, ('%02d' % int(idx)) if idx else '')
    bitmaps = {}
    for path, typ in re.findall(r'LoadBitmap\s*\(\s*L"([^"]+)"\s*,\s*((?:BITMAP)_\w+(?:\s*\+\s*\d+)?)', opendata):
        bitmaps.setdefault(norm(typ), path)
    sounds = {}
    for typ, path in re.findall(r'LoadWaveFile\s*\(\s*(SOUND_\w+(?:\s*\+\s*\d+)?)\s*,\s*L"([^"]+)"', opendata):
        sounds.setdefault(norm(typ), path.replace('\\\\', '/').replace('\\', '/').split('/')[-1])
    return models, bitmaps, sounds


def case_block(src, typ, start_at=0, max_lines=60):
    """Thân 'case TYPE:' đầu tiên sau start_at (tới case MODEL_/BITMAP_ kế tiếp có nội dung)."""
    m = re.search(r'case\s+' + re.escape(typ).replace(r'\+', r'\s*\+\s*') + r'\s*:', src[start_at:])
    if not m:
        return ''
    rest = src[start_at + m.end():].splitlines()[:max_lines]
    out, has = [], False
    for line in rest:
        if re.match(r'^\s*(case\s+(MODEL|BITMAP)_|default\s*:)', line) and has:
            break
        out.append(line)
        if line.strip() and not line.strip().startswith('case'):
            has = True
    return '\n'.join(out)


def first_num(body, field):
    m = re.search(r'o->' + field + r'\s*=\s*\(?(?:float\)\s*)?(-?\d+(?:\.\d+)?)f?', body)
    return float(m.group(1)) if m else None


def move_bodies(src):
    out = {}
    pos = [(m.start(), m.group(1)) for m in re.finditer(r'bool\s+Move_(\w+)\s*\(', src)]
    for i, (p, name) in enumerate(pos):
        end = pos[i + 1][0] if i + 1 < len(pos) else len(src)
        out[name] = src[p:end]
    return out


def motion_of(body):
    if not body:
        return 'static'
    if 'MoveHumming' in body or re.search(r'TargetPosition|Target->Position', body):
        return 'homing'
    if 'Owner->Position' in body:
        return 'follow'
    if re.search(r'VectorRotate|o->Direction|Velocity', body):
        return 'forward'
    return 'static'


# ---------------------------------------------------------------- chính
def main_all(source_root, client_data, mugodot, log=print):
    S = lambda *p: os.path.join(source_root, *p)  # noqa: E731
    enum_src = read(S('Core', 'Globals', '_enum.h'))
    skill_nums = parse_enum_block(enum_containing(enum_src, 'AT_SKILL_POISON'))
    actions = parse_enum_block(enum_containing(enum_src, 'PLAYER_STOP_MALE'))
    bases = skill_bases(enum_src)
    log('[skill_fx] %d AT_SKILL, %d PLAYER action (PLAYER_ATTACK_SKILL_WHEEL = %s)'
        % (len(skill_nums), len(actions), actions.get('PLAYER_ATTACK_SKILL_WHEEL')))

    def _eval_action_inner(expr):
        """'static_cast<int>(PLAYER_ATTACK_SKILL_SWORD1)+AT_SKILL_LUNGE-AT_SKILL_FALLING_SLASH' -> 'PLAYER_..+n'"""
        e = expr.replace('static_cast<int>(', '').replace(')', '')
        toks = re.findall(r'[+-]|\w+', e)
        if not toks or not toks[0].startswith('PLAYER_'):
            return expr
        off, sign = 0, 1
        for t in toks[1:]:
            if t in '+-':
                sign = 1 if t == '+' else -1
            elif t.isdigit():
                off += sign * int(t)
            elif t in skill_nums:
                off += sign * skill_nums[t]
        return toks[0] + ('+%d' % off if off else '')
    global _eval_action
    _eval_action = _eval_action_inner

    def skill_num(label):
        m = re.match(r'^(\w+)(?:\+(\d+))?$', label)
        if not m or m.group(1) not in skill_nums:
            return None
        return skill_nums[m.group(1)] + int(m.group(2) or 0)

    # nguồn: (file, ưu tiên hiệu ứng)
    files = [
        (S('Engine', 'Object', 'ZzzCharacter.cpp'), True),
        (S('Network', 'Server', 'WSclient.cpp'), True),
        (S('GameLogic', 'Combat', 'ClassAttack.cpp'), True),
        (S('GameLogic', 'Combat', 'SkillCast.cpp'), True),
        (S('GameLogic', 'Combat', 'SkillExecution.cpp'), True),
        (S('GameLogic', 'Social', 'MonkSystem.cpp'), True),      # Rage Fighter
        (S('GameLogic', 'Skills', 'SummonSystem.cpp'), True),    # Summoner
    ]
    per = {}  # số skill -> {fx, sounds, action, src}
    for path, _ in files:
        if not os.path.isfile(path):
            continue
        src = read(path)
        groups = case_groups(src, os.path.basename(path))
        n_case = len(groups)
        groups += if_groups(src, os.path.basename(path))
        for gi, (labels, body, where, falls) in enumerate(groups):
            full = body
            j = gi
            # case không break: chạy tiếp sang nhóm sau (tối đa 3 nhóm)
            while falls and j + 1 < n_case and j - gi < 3:
                j += 1
                full += '\n' + groups[j][1]
                falls = groups[j][3]
            fx = calls_in(full)
            snd = [norm(s) for s in SOUND_RE.findall(full)]
            act = [_eval_action(norm(a)) for a in ACTION_RE.findall(full)]
            if 'SetPlayerMagic' in full:
                act.append('magic')
            if 'SetPlayerAttack' in full:
                act.append('attack')
            if not (fx or snd or act):
                continue
            for lab in labels:
                n = skill_num(lab)
                if n is None:
                    continue
                d = per.setdefault(n, {'fx': [], 'sounds': [], 'actions': [], 'src': []})
                d['fx'] += fx
                d['sounds'] += [s for s in snd if s not in d['sounds']]
                d['actions'] += [a for a in act if a not in d['actions']]
                d['src'].append(where)

    opendata = read(S('Engine', 'Object', 'ZzzOpenData.cpp'))
    models, bitmaps, sounds = asset_tables(opendata)
    index_path = os.path.join(mugodot, 'assets', 'mu', 'mu_models_index.json')
    glb_index = set(json.load(open(index_path, encoding='utf-8')).keys()) if os.path.isfile(index_path) else set()
    snd_dir = os.path.join(mugodot, 'assets', 'mu', 'Sound')
    have_snd = {f.lower(): f for f in os.listdir(snd_dir)} if os.path.isdir(snd_dir) else {}

    eff_src = read(S('Render', 'Effects', 'ZzzEffect.cpp'))
    eff_start = eff_src.find('void CreateEffect(int Type')
    joint_src = read(S('Render', 'Effects', 'ZzzEffectJoint.cpp'))
    joint_start = joint_src.find('void CreateJoint(int Type')
    part_src = read(S('Render', 'Effects', 'ZzzEffectParticle.cpp'))
    moves = move_bodies(read(S('Render', 'Effects', 'Behaviors', 'MoveHandlers.cpp')))

    tex_out = os.path.join(mugodot, 'assets', 'mu', 'fx', 'skill')
    tex_cache = {}

    def tex(bitmap):
        if bitmap not in bitmaps:
            base = re.sub(r'\+\d+$', '', bitmap)
            if base not in bitmaps:
                return None
            bitmap = base
        rel = bitmaps[bitmap]
        if rel not in tex_cache:
            tex_cache[rel] = decode_texture(client_data, rel, tex_out)
        return tex_cache[rel]

    types = {}

    def describe(typ, call, depth=0):
        key = '%s:%s' % (call, typ)
        if key in types or depth > 1:
            return
        info = {'call': call}
        if call == 'effect':
            body = case_block(eff_src, typ, eff_start)
        elif call == 'joint':
            body = case_block(joint_src, typ, joint_start)
        else:
            body = case_block(part_src, typ, 0)
        for f, k in (('LifeTime', 'life'), ('Velocity', 'velocity'), ('Scale', 'scale')):
            v = first_num(body, f)
            if v is not None:
                info[k] = v
        if typ.startswith('MODEL_'):
            g = models.get(typ)
            if g and g in glb_index:
                info['glb'] = g
            elif g:
                info['bmd'] = g
        t = tex(typ) if typ.startswith('BITMAP_') else None
        if t:
            info['tex'] = t
        mv = moves.get(typ, '')
        info['motion'] = motion_of(mv + '\n' + body) if call == 'effect' else (
            'homing' if call == 'joint' and 'TargetPosition' in body else 'static')
        kids = merge_fx(calls_in(mv))[:6]
        if kids:
            info['children'] = [{'call': c['call'], 'type': c['type'], 'sub': c['sub']} for c in kids]
        types[key] = info
        for c in kids:
            describe(c['type'], c['call'], depth + 1)

    out = {}
    names = {v: k for k, v in skill_nums.items()}
    for n, d in sorted(per.items()):
        fx = merge_fx(d['fx'])
        for f in fx:
            describe(f['type'], f['call'])
        snds = [have_snd[sounds[s].lower()] for s in d['sounds'] if s in sounds and sounds[s].lower() in have_snd]
        # hành động khi đi bộ (bỏ bản cưỡi ngựa / thú: _UNI, _DINO, _FENRIR, RIDE)
        acts = [a for a in d['actions'] if a.startswith('PLAYER_')]
        walk = [a for a in acts if not re.search(r'UNI|DINO|FENRIR|RIDE', a)]
        act = (walk or acts or d['actions'] or [None])[0]
        e = {'name': names.get(n, str(n)), 'fx': fx, 'sounds': snds, 'src': d['src'][:6]}
        if act:
            e['action'] = act
            m = re.match(r'^(PLAYER_\w+?)(?:\+(\d+))?$', act)
            if m and m.group(1) in actions:
                e['action_index'] = actions[m.group(1)] + int(m.group(2) or 0)
        out[str(n)] = e

    # skill nâng cấp không có dữ liệu riêng -> kế thừa skill gốc
    for a, b in bases.items():
        na, nb = skill_nums.get(a), skill_nums.get(b)
        if na is None or nb is None or str(nb) not in out:
            continue
        if str(na) not in out or not out[str(na)]['fx']:
            e = dict(out[str(nb)])
            e['name'] = a
            e['base'] = nb
            out[str(na)] = e

    # skill Master (skills.json của OpenMU) chưa có dữ liệu: kế thừa skill gốc cùng tên
    # ("Meteor Strengthener" -> "Meteorite", "Death Stab Mastery" -> "Death Stab")
    sk_path = os.path.join(mugodot, 'assets', 'mu', 'skills.json')
    if os.path.isfile(sk_path):
        sk = json.load(open(sk_path, encoding='utf-8')).get('skills', {})
        suffix = re.compile(r'\s+(Strengthener|Strengthen|Streng|Str|Mastery|Mast|Proficiency|Proficie|Prof|M|'
                            r'Duel Master|Lord Emperor)$')

        def stem(name):
            prev = None
            while prev != name:
                prev, name = name, suffix.sub('', name).strip()
            return name.lower()
        # chỉ nguồn có dữ liệu riêng (không phải bản đã kế thừa)
        cands = [(k, stem(v.get('name', '')), set(v.get('classes', [])))
                 for k, v in sk.items() if k in out and out[k]['fx'] and 'base' not in out[k]]

        # OpenMU đặt tên bản Master khác tên skill gốc
        alias = {'electric spark': 'electric spike'}

        def find_src(k, v):
            s = stem(v.get('name', ''))
            s = alias.get(s, s)
            cls = set(v.get('classes', []))
            best = None
            for ck, cs, ccls in cands:
                if ck == k or len(cs) < 3 or len(s) < 3 or not (cls & ccls):
                    continue      # khác class -> không phải cùng skill ("Poison Arrow" của Elf != "Poison" của DW)
                if cs == s:
                    rank = 0
                elif s.startswith(cs + ' ') or s.startswith(cs) and s[len(cs):len(cs) + 1] in ('', 'i', 'e'):
                    rank = 1      # "meteor" -> "meteorite", tên rút gọn của bản Master
                elif cs.startswith(s):
                    rank = 1
                else:
                    continue
                key = (rank, int(ck) >= 300, int(ck))
                if best is None or key < best[0]:
                    best = (key, ck)
            return best[1] if best else None

        for k, v in sk.items():
            if v.get('type') == 'PassiveBoost' or (k in out and out[k]['fx']):
                continue
            src = find_src(k, v)
            if src and src != k:
                e = dict(out[src])
                e['name'] = v.get('name', '')
                e['base'] = int(src)
                out[k] = e

    # bảng BITMAP_* -> texture cho hiệu ứng port tay (MuFx.tex("BITMAP_SPARK+1")): texture trong Data/Effect, Data/Skill
    bitmap_tex = {}
    for name, rel in bitmaps.items():
        if not rel.replace('\\\\', '\\').lower().startswith(('effect\\', 'skill\\')) and name not in bitmap_tex:
            continue
        t = tex(name)
        if t:
            bitmap_tex[name] = t

    dst = os.path.join(mugodot, 'assets', 'mu', 'skill_fx.json')
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump({'skills': out, 'types': types, 'bitmaps': bitmap_tex}, f, ensure_ascii=False, indent=1)
    with_fx = sum(1 for e in out.values() if e['fx'])
    with_glb = sum(1 for t in types.values() if 'glb' in t)
    log('[skill_fx] %d skill (%d có hiệu ứng), %d loại hiệu ứng (%d có glb), %d texture -> %s'
        % (len(out), with_fx, len(types), with_glb, sum(1 for v in tex_cache.values() if v), dst))
    return out


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    main_all(sys.argv[1], sys.argv[2], sys.argv[3])
