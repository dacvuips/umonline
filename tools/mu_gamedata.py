#!/usr/bin/env python3
"""mu_gamedata.py — Lấy CHỈ SỐ QUÁI + SKILL từ server OpenMU (cùng thư mục MuMain) cho MuGodot.

Ghi:
  assets/mu/monster_stats.json  { "<số quái>": {name, level, hp, dmg_min, dmg_max, def, atk_rate, def_rate,
                                                move_range, attack_range, view_range, move_delay, attack_delay,
                                                respawn, attack_skill} }
  assets/mu/skills.json         { "skills": { "<số skill>": {name, key, classes, damage_type, damage, distance,
                                                               mana, ag, level, energy, leadership, element,
                                                               type, target, range, moves_to_target, cooldown} },
                                  "items":  { "<nhóm>:<số>": {skill, level, energy, strength, agility, leadership,
                                                              classes: {"<lớp>": cấp đổi lớp tối thiểu}} } }
Lớp nhân vật = chỉ số MuCatalog.CharClass: 0 DW, 1 DK, 2 Elf, 3 MG, 4 DL, 5 Summoner, 6 Rage Fighter.

Nguồn: OpenMU/src/Persistence/Initialization/
  Skills/SkillNumber.cs, VersionSeasonSix/SkillsInitializer.cs           (skill)
  VersionSeasonSix/Items/Orbs.cs, VersionSeasonSix/Items/Scrolls.cs      (orb / scroll / parchment dạy skill)
  Version075/**/*.cs rồi VersionSeasonSix/**/*.cs                         (quái; Season 6 ghi đè 0.75)

    python tools/mu_gamedata.py <thư mục OpenMU> <thư mục MuGodot>
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mu_openmu import split_args  # noqa: E402

INIT = os.path.join('src', 'Persistence', 'Initialization')

# CharacterClasses.cs (cờ bit) -> lớp của MuGodot
CLASS_BITS = {
    'DarkWizard': 1 << 0, 'SoulMaster': 1 << 1, 'GrandMaster': 1 << 2,
    'DarkKnight': 1 << 4, 'BladeKnight': 1 << 5, 'BladeMaster': 1 << 6,
    'FairyElf': 1 << 7, 'MuseElf': 1 << 9, 'HighElf': 1 << 10,
    'MagicGladiator': 1 << 12, 'DuelMaster': 1 << 13,
    'DarkLord': 1 << 16, 'LordEmperor': 1 << 17,
    'Summoner': 1 << 20, 'BloodySummoner': 1 << 21, 'DimensionMaster': 1 << 22,
    'RageFighter': 1 << 24, 'FistMaster': 1 << 25,
}
CLASS_GROUPS = {
    'AllWizards': ['DarkWizard', 'SoulMaster', 'GrandMaster'],
    'AllKnights': ['DarkKnight', 'BladeKnight', 'BladeMaster'],
    'AllElfs': ['FairyElf', 'MuseElf', 'HighElf'],
    'AllSummoners': ['Summoner', 'BloodySummoner', 'DimensionMaster'],
    'AllMGs': ['MagicGladiator', 'DuelMaster'],
    'AllLords': ['DarkLord', 'LordEmperor'],
    'AllFighters': ['RageFighter', 'FistMaster'],
    'AllMagicians': ['AllWizards', 'AllMGs'],
    'AllKnightsLordsAndMGs': ['AllKnights', 'AllLords', 'AllMGs'],
    'AllMastersAndSecondClass': [],
}
# lớp gốc của MuGodot theo nhóm bit
GODOT_CLASS = [(0, 1 << 0 | 1 << 1 | 1 << 2), (1, 1 << 4 | 1 << 5 | 1 << 6), (2, 1 << 7 | 1 << 9 | 1 << 10),
               (3, 1 << 12 | 1 << 13), (4, 1 << 16 | 1 << 17), (5, 1 << 20 | 1 << 21 | 1 << 22),
               (6, 1 << 24 | 1 << 25)]


CLASS_ENUM = {}   # tên -> cờ bit, đọc từ CharacterClasses.cs (có cả tên ghép như BladeKnightAndBladeMaster)


def load_class_enum(init):
    text = strip_comments(read(os.path.join(init, 'CharacterClasses', 'CharacterClasses.cs')))
    body = text[text.find('enum CharacterClasses'):]
    exprs = {m.group(1): m.group(2) for m in re.finditer(r'^\s*(\w+)\s*=\s*([^,\n]+),', body, flags=re.M)}
    for name in exprs:
        CLASS_ENUM[name] = _eval_class(name, exprs, set())


def _eval_class(name, exprs, seen):
    if name in CLASS_ENUM:
        return CLASS_ENUM[name]
    if name in seen or name not in exprs:
        return 0
    seen.add(name)
    e = exprs[name].strip()
    v = 0
    for tok in re.split(r'\s*\|\s*', e):
        tok = tok.strip()
        if re.match(r'^0[bBxX][0-9a-fA-F_]+$|^\d+$', tok):
            v |= int(tok, 0)
        else:
            v |= _eval_class(tok, exprs, seen)
    return v


def class_mask(expr):
    expr = (expr or '').replace('CharacterClasses.', '')
    mask = 0
    for tok in re.findall(r'\w+', expr):
        mask |= CLASS_ENUM.get(tok, _class_tok(tok))
    return mask


def _class_tok(tok):
    if tok == 'All':
        return 0xFFFFFFFF
    if tok in CLASS_BITS:
        return CLASS_BITS[tok]
    m = 0
    for sub in CLASS_GROUPS.get(tok, []):
        m |= _class_tok(sub)
    return m


def godot_classes(mask):
    return [c for c, bits in GODOT_CLASS if mask & bits]


def words(name):
    """FireBall -> Fire Ball ; TwistingSlash -> Twisting Slash"""
    return re.sub(r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])', ' ', name).strip()


def read(path):
    return open(path, encoding='utf-8-sig', errors='replace').read()


def strip_comments(src):
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    return re.sub(r'//[^\n]*', '', src)


def calls(text, fn):
    """Các lời gọi this.<fn>(...) / <fn>(...) -> danh sách chuỗi đối số (ngoặc lồng nhau)."""
    out = []
    for m in re.finditer(r'(?<![\w.])(?:this\.)?' + fn + r'\(', text):
        i = m.end()
        depth = 1
        j = i
        while j < len(text) and depth:
            if text[j] == '(':
                depth += 1
            elif text[j] == ')':
                depth -= 1
            j += 1
        out.append(text[i:j - 1])
    return out


def num(v, default=0):
    if v is None:
        return default
    v = str(v).strip().rstrip('fFdDmM').replace('_', '')
    try:
        return int(v)
    except ValueError:
        try:
            return float(v)
        except ValueError:
            return default


def enum_name(v):
    return str(v).split('.')[-1].strip() if v is not None else ''


# ------------------------------------------------------------------------------------------- skill
SKILL_PARAMS = ['number', 'name', 'characterClasses', 'damageType', 'damage', 'distance', 'abilityConsumption',
                'manaConsumption', 'levelRequirement', 'energyRequirement', 'leadershipRequirement',
                'elementalModifier', 'skillType', 'skillTarget', 'implicitTargetRange', 'targetRestriction',
                'movesToTarget', 'movesTarget', 'cooldownMinutes', 'hitsPerAttack']


def parse_skill_numbers(init):
    text = strip_comments(read(os.path.join(init, 'Skills', 'SkillNumber.cs')))
    return {m.group(1): int(m.group(2)) for m in re.finditer(r'(\w+)\s*=\s*(\d+)\s*,', text)}


def parse_skills(init, numbers):
    text = strip_comments(read(os.path.join(init, 'VersionSeasonSix', 'SkillsInitializer.cs')))
    skills = {}
    for args in calls(text, 'CreateSkill'):
        parts = split_args(args)
        a = {}
        for i, p in enumerate(parts):
            m = re.match(r'^(\w+)\s*:\s*(.*)$', p, flags=re.S)
            if m and m.group(1) in SKILL_PARAMS:
                a[m.group(1)] = m.group(2).strip()
            elif i < len(SKILL_PARAMS):
                a[SKILL_PARAMS[i]] = p.strip()
        key = enum_name(a.get('number'))
        if key not in numbers:
            continue
        mask = class_mask(a.get('characterClasses'))
        skills[str(numbers[key])] = {
            'name': words(key),
            'key': key,
            'classes': godot_classes(mask),
            'damage_type': enum_name(a.get('damageType')) or 'None',
            'damage': num(a.get('damage')),
            'distance': num(a.get('distance')),
            'mana': num(a.get('manaConsumption')),
            'ag': num(a.get('abilityConsumption')),
            'level': num(a.get('levelRequirement')),
            'energy': num(a.get('energyRequirement')),
            'leadership': num(a.get('leadershipRequirement')),
            'element': enum_name(a.get('elementalModifier')) or 'Undefined',
            'type': enum_name(a.get('skillType')) or 'DirectHit',
            'target': enum_name(a.get('skillTarget')) or 'Explicit',
            'range': num(a.get('implicitTargetRange')),
            'moves_to_target': str(a.get('movesToTarget', 'false')).strip() == 'true',
            'cooldown': num(a.get('cooldownMinutes')),
        }
    return skills


CLASS_LEVEL_ORDER = [0, 1, 2, 3, 4, 5, 6]   # dw, dk, elf, mg, dl, summoner, rf


def _class_levels(vals):
    return {str(c): num(v) for c, v in zip(CLASS_LEVEL_ORDER, vals) if num(v) > 0}


def parse_skill_items(init, numbers):
    items = {}
    orbs = strip_comments(read(os.path.join(init, 'VersionSeasonSix', 'Items', 'Orbs.cs')))
    # CreateOrb(number, SkillNumber.X, height, name, dropLevel, levelReq, energyReq, strengthReq, agilityReq,
    #           leadershipReq, money, dw, dk, elf, mg, dl, summoner, rf)
    for args in calls(orbs, 'CreateOrb'):
        p = split_args(args)
        if len(p) < 18 or not p[0].strip().isdigit():
            continue
        key = enum_name(p[1])
        if key not in numbers:
            continue
        items['12:%d' % num(p[0])] = {
            'skill': numbers[key], 'level': num(p[5]), 'energy': num(p[6]), 'strength': num(p[7]),
            'agility': num(p[8]), 'leadership': num(p[9]), 'classes': _class_levels(p[11:18])}
    scrolls = strip_comments(read(os.path.join(init, 'VersionSeasonSix', 'Items', 'Scrolls.cs')))
    # CreateScroll(number, skillNumber, name, dropLevel, levelReq, energyReq, money, dw, dk, elf, mg, dl, summoner, rf)
    for args in calls(scrolls, 'CreateScroll'):
        p = split_args(args)
        if len(p) < 14 or not p[0].strip().isdigit():
            continue
        items['15:%d' % num(p[0])] = {
            'skill': num(p[1]), 'level': num(p[4]), 'energy': num(p[5]), 'strength': 0, 'agility': 0,
            'leadership': 0, 'classes': _class_levels(p[7:14])}
    return items


# ------------------------------------------------------------------------------------------- quái
MONSTER_FIELDS = {'MoveRange': 'move_range', 'AttackRange': 'attack_range', 'ViewRange': 'view_range'}
MONSTER_TIMES = {'MoveDelay': 'move_delay', 'AttackDelay': 'attack_delay', 'RespawnDelay': 'respawn'}
MONSTER_STATS = {'Level': 'level', 'MaximumHealth': 'hp', 'MinimumPhysBaseDmg': 'dmg_min',
                 'MaximumPhysBaseDmg': 'dmg_max', 'DefenseBase': 'def', 'AttackRatePvm': 'atk_rate',
                 'DefenseRatePvm': 'def_rate'}


def _designation(v):
    m = re.search(r'MonsterNames\.(\w+)', v)
    if m:
        return words(m.group(1))
    m = re.search(r'"([^"]*)"', v)
    return m.group(1) if m else v.strip()


def parse_monsters_in(text):
    const_map = {m.group(1): int(m.group(2)) for m in re.finditer(r'(?:const\s+short|const\s+int|const\s+byte)\s+(\w+)\s*=\s*(\d+)', text)}
    out = {}
    starts = []
    for m in re.finditer(r'\b(\w+)\.Number\s*=\s*(\w+)\s*;', text):
        var, raw_num = m.group(1), m.group(2)
        if raw_num.isdigit():
            number = int(raw_num)
        elif raw_num in const_map:
            number = const_map[raw_num]
        else:
            continue
        starts.append((m.start(), var, number))
    for i, (pos, var, number) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(text)
        block = text[pos:end]
        if not re.search(r'\b' + re.escape(var) + r'\.Designation\s*=', block):
            continue   # không phải quái (vật phẩm, cổng...)
        mon = {}
        d = re.search(r'\b' + re.escape(var) + r'\.Designation\s*=\s*([^;]+);', block)
        mon['name'] = _designation(d.group(1)) if d else ''
        for f, k in MONSTER_FIELDS.items():
            m = re.search(r'\b' + re.escape(var) + r'\.' + f + r'\s*=\s*(\d+)', block)
            if m:
                mon[k] = int(m.group(1))
        for f, k in MONSTER_TIMES.items():
            m = re.search(r'\b' + re.escape(var) + r'\.' + f + r'\s*=\s*new TimeSpan\(\s*(\d+)\s*\*\s*TimeSpan\.Ticks(Per\w+)', block)
            if m:
                v = int(m.group(1))
                mon[k] = v * 1000 if m.group(2) == 'PerSecond' and k != 'respawn' else v
        for f, k in MONSTER_STATS.items():
            m = re.search(r'\{\s*Stats\.' + f + r'\s*,\s*([\d._]+)f?\s*\}', block)
            if m:
                mon[k] = num(m.group(1))
        sk = re.search(r'\b' + re.escape(var) + r'\.AttackSkill\s*=[^;]*SkillNumber\.(\w+)', block)
        if sk:
            mon['attack_skill'] = sk.group(1)
        if 'hp' in mon:
            out[number] = mon
    return out


def parse_monsters(init, catalog_path=None):
    monsters = {}
    for version in ('Version075', 'Version095d', 'Version097d', 'VersionSeasonSix', 'Updates'):
        base = os.path.join(init, version)
        if not os.path.isdir(base):
            continue
        for dirpath, _, files in os.walk(base):
            for f in sorted(files):
                if f.endswith('.cs'):
                    monsters.update(parse_monsters_in(strip_comments(read(os.path.join(dirpath, f)))))
    
    # Bổ sung quái / đối tượng từ catalog nếu chưa có chỉ số
    if catalog_path and os.path.exists(catalog_path):
        try:
            cat_data = json.load(open(catalog_path, encoding='utf-8'))
            for m in cat_data.get('monsters', []):
                num = m.get('number')
                if num is not None and num not in monsters:
                    name_en = m.get('name', {}).get('en', f'Monster {num}')
                    monsters[num] = {
                        'name': name_en,
                        'level': 50,
                        'hp': 5000,
                        'dmg_min': 50,
                        'dmg_max': 100,
                        'def': 60,
                        'atk_rate': 250,
                        'def_rate': 80,
                        'move_range': 3,
                        'attack_range': 2,
                        'view_range': 6,
                        'move_delay': 400,
                        'attack_delay': 1600,
                        'respawn': 10
                    }
        except Exception as e:
            pass

    return {str(k): v for k, v in sorted(monsters.items())}


# ------------------------------------------------------------------------------------------- main
def main(openmu_root, mugodot, log=print):
    init = os.path.join(openmu_root, INIT)
    load_class_enum(init)
    numbers = parse_skill_numbers(init)
    skills = parse_skills(init, numbers)
    items = parse_skill_items(init, numbers)
    cat_file = os.path.join(mugodot, 'assets', 'mu', 'catalog', 'Monsters', 'Monsters.json')
    monsters = parse_monsters(init, cat_file)
    out_dir = os.path.join(mugodot, 'assets', 'mu')
    with open(os.path.join(out_dir, 'skills.json'), 'w', encoding='utf-8') as f:
        json.dump({'skills': skills, 'items': items}, f, ensure_ascii=False, separators=(',', ':'))
    with open(os.path.join(out_dir, 'monster_stats.json'), 'w', encoding='utf-8') as f:
        json.dump(monsters, f, ensure_ascii=False, separators=(',', ':'))
    log('== Skill: %d skill, %d orb/scroll dạy skill -> skills.json' % (len(skills), len(items)))
    log('== Quái: %d loại có chỉ số -> monster_stats.json' % len(monsters))
    return skills, items, monsters


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    main(sys.argv[1], sys.argv[2])
