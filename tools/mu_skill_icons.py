"""mu_skill_icons.py — Cắt icon TĨNH của từng skill cho nút bấm / bảng skill của MuGodot.

Đúng như client gốc (UI/HUD/Skills/SkillIconAtlas.cpp — CNewUISkillList::RenderSkillIcon):
  * ô icon 20x28 px trên atlas 256x256: newui_skill.jpg (Skill1), newui_skill2.jpg, newui_skill3.jpg,
    newui_command.jpg ; skill master (>= 300) lấy ô Magic_Icon trên new_Master_Icon (25 cột)
  * Magic_Icon + SkillUseType đọc từ Data/Local/Skill.bmd (bản ghi mã hoá BuxConvert)

Kết quả: assets/textures/ui/skills/skill_<số>.png (64x64, giữ tỉ lệ 20:28 ở giữa, nền đen)
          assets/textures/ui/skills_grey/skill_<số>.png (bản xám newui_non_* khi chưa dùng được)

    python tools/mu_skill_icons.py [E:/MuMain/Client/Data] [E:/MuMain/MuGodot]
"""
import json
import os
import struct
import sys

from PIL import Image

CELL_W, CELL_H = 20, 28
MASTER_COLS = 25
MAX_SKILLS = 650
BUX = (0xFC, 0xCF, 0xAB)

# _enum.h
AT_SKILL_SPIRAL_SLASH = 57
AT_SKILL_PLASMA_STORM_FENRIR = 76
AT_PET_COMMAND_DEFAULT = 120
AT_PET_COMMAND_END = 124
AT_SKILL_ALICE_DRAINLIFE, AT_SKILL_ALICE_THORNS = 214, 217
AT_SKILL_ALICE_BERSERKER, AT_SKILL_ALICE_SLEEP, AT_SKILL_ALICE_BLIND = 218, 219, 220
AT_SKILL_ALICE_WEAKNESS, AT_SKILL_ALICE_ENERVATION = 221, 222
AT_SKILL_SUMMON_EXPLOSION, AT_SKILL_SUMMON_REQUIEM, AT_SKILL_SUMMON_POLLUTION = 223, 224, 225
AT_SKILL_LIGHTNING_SHOCK = 230
AT_SKILL_STRIKE_OF_DESTRUCTION, AT_SKILL_EXPANSION_OF_WIZARDRY = 232, 233
AT_SKILL_RECOVER, AT_SKILL_MULTI_SHOT, AT_SKILL_FLAME_STRIKE = 234, 235, 236
AT_SKILL_GIGANTIC_STORM, AT_SKILL_CHAOTIC_DISEIER = 237, 238
AT_SKILL_KILLING_BLOW = 260
AT_SKILL_MASTER_BEGIN = 300
SKILL_USE_TYPE_MASTERACTIVE = 4


def _align(off, a):
    return (off + a - 1) // a * a


def record_layout(name_len):
    """Vị trí các trường của SKILL_ATTRIBUTE_FILE (căn lề tự nhiên của MSVC)."""
    fields = [('Level', 'H'), ('Damage', 'H'), ('Mana', 'H'), ('AbilityGuage', 'H'), ('Distance', 'I'),
              ('Delay', 'i'), ('Energy', 'i'), ('Charisma', 'H'), ('MasteryType', 'B'), ('SkillUseType', 'B'),
              ('SkillBrand', 'I'), ('KillCount', 'B'), ('RequireDutyClass', '3s'), ('RequireClass', '7s'),
              ('SkillRank', 'B'), ('Magic_Icon', 'H'), ('TypeSkill', 'B'), ('Strength', 'i'),
              ('Dexterity', 'i'), ('ItemSkill', 'B'), ('IsDamage', 'B'), ('Effect', 'H')]
    off = name_len
    out = {}
    max_a = 1
    for n, f in fields:
        size = struct.calcsize('<' + f)
        a = 1 if f.endswith('s') else size
        max_a = max(max_a, a)
        off = _align(off, a)
        out[n] = (off, f)
        off += size
    return out, _align(off, max_a)


# Bản Season 6 gốc (struct trong ghi chú của _struct.h): 600 bản ghi x 80 byte
S6_LAYOUT = {'Level': (32, 'B'), 'Damage': (34, 'H'), 'Mana': (36, 'H'), 'AbilityGuage': (38, 'H'),
             'Distance': (40, 'B'), 'Delay': (44, 'i'), 'Energy': (48, 'i'), 'Charisma': (52, 'H'),
             'MasteryType': (54, 'B'), 'SkillUseType': (55, 'B'), 'SkillBrand': (56, 'B'), 'KillCount': (57, 'B'),
             'Magic_Icon': (68, 'H'), 'TypeSkill': (70, 'B'), 'Strength': (72, 'i'), 'Dexterity': (76, 'i')}


def read_skill_bmd(path):
    data = open(path, 'rb').read()
    candidates = [(32, S6_LAYOUT, 80, 600)]
    for name_len in (50, 32):
        lay, size = record_layout(name_len)
        candidates.append((name_len, lay, size, MAX_SKILLS))
    for name_len, lay, size, count in candidates:
        if len(data) == size * count + 4:
            break
    else:
        raise SystemExit('Skill.bmd size not recognised: %d' % len(data))
    skills = {}
    for i in range(count):
        rec = bytearray(data[i * size:(i + 1) * size])
        for j in range(size):
            rec[j] ^= BUX[j % 3]
        name = bytes(rec[:name_len]).split(b'\0')[0].decode('utf-8', 'replace')
        d = {'name': name}
        for n, (off, f) in lay.items():
            if not f.endswith('s'):
                d[n] = struct.unpack_from('<' + f, rec, off)[0]
        skills[i] = d
    return skills


def resolve(skill_type, use_type, magic_icon):
    """ResolveSkillIcon(): (atlas, cột, hàng)"""
    t = skill_type
    if t == 0:
        return None
    if t >= AT_SKILL_MASTER_BEGIN:
        return ('master', magic_icon % MASTER_COLS, magic_icon // MASTER_COLS)
    if AT_PET_COMMAND_DEFAULT <= t <= AT_PET_COMMAND_END:
        c = t - AT_PET_COMMAND_DEFAULT
        return ('command', c % 8, c // 8)
    if t == AT_SKILL_PLASMA_STORM_FENRIR:
        return ('command', 4, 0)
    if AT_SKILL_ALICE_DRAINLIFE <= t <= AT_SKILL_ALICE_THORNS:
        return ('skill2', (t - AT_SKILL_ALICE_DRAINLIFE) % 8, 3)
    if AT_SKILL_ALICE_SLEEP <= t <= AT_SKILL_ALICE_BLIND:
        return ('skill2', (t - AT_SKILL_ALICE_SLEEP + 4) % 8, 3)
    if t == AT_SKILL_ALICE_BERSERKER:
        return ('skill2', 10, 3)
    if AT_SKILL_ALICE_WEAKNESS <= t <= AT_SKILL_ALICE_ENERVATION:
        return ('skill2', t - AT_SKILL_ALICE_WEAKNESS + 8, 3)
    if AT_SKILL_SUMMON_EXPLOSION <= t <= AT_SKILL_SUMMON_REQUIEM:
        return ('skill2', (t - AT_SKILL_SUMMON_EXPLOSION + 6) % 8, 3)
    special = {AT_SKILL_SUMMON_POLLUTION: (11, 3), AT_SKILL_STRIKE_OF_DESTRUCTION: (7, 2),
               AT_SKILL_CHAOTIC_DISEIER: (3, 8), AT_SKILL_RECOVER: (9, 2), AT_SKILL_MULTI_SHOT: (0, 8),
               AT_SKILL_FLAME_STRIKE: (1, 8), AT_SKILL_GIGANTIC_STORM: (2, 8), AT_SKILL_LIGHTNING_SHOCK: (2, 3),
               AT_SKILL_EXPANSION_OF_WIZARDRY: (8, 2)}
    if t in special:
        return ('skill2',) + special[t]
    if use_type == SKILL_USE_TYPE_MASTERACTIVE:
        return ('skill2', magic_icon % 12, magic_icon // 12 + 4)
    if t >= AT_SKILL_KILLING_BLOW:
        return ('skill3', (t - AT_SKILL_KILLING_BLOW) % 12, (t - AT_SKILL_KILLING_BLOW) // 12)
    if t >= AT_SKILL_SPIRAL_SLASH:
        return ('skill2', (t - AT_SKILL_SPIRAL_SLASH) % 8, (t - AT_SKILL_SPIRAL_SLASH) // 8)
    return ('skill1', (t - 1) % 8, (t - 1) // 8)


ATLAS = {
    'skill1': ('newui_skill.png', 'newui_non_skill.png'),
    'skill2': ('newui_skill2.png', 'newui_non_skill2.png'),
    'skill3': ('newui_skill3.png', 'newui_non_skill3.png'),
    'command': ('newui_command.png', 'newui_non_command.png'),
    'master': ('new_Master_Icon.png', 'new_Master_non_Icon.png'),
}


def to_button(cell):
    """Ô 20x28 -> 64x64: phóng to giữ tỉ lệ, căn giữa trên nền đen (như ô skillbox của MU)."""
    h = 64
    w = round(CELL_W * h / CELL_H)
    big = cell.resize((w, h), Image.Resampling.LANCZOS)
    out = Image.new('RGB', (64, 64), (0, 0, 0))
    out.paste(big, ((64 - w) // 2, 0))
    return out


def main():
    data_dir = sys.argv[1] if len(sys.argv) > 1 else r'E:/MuMain/Client/Data'
    godot = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ui = os.path.join(godot, 'assets', 'textures', 'ui')
    out_lit = os.path.join(ui, 'skills')
    out_grey = os.path.join(ui, 'skills_grey')
    os.makedirs(out_lit, exist_ok=True)
    os.makedirs(out_grey, exist_ok=True)

    bmd = read_skill_bmd(os.path.join(data_dir, 'Local', 'Skill.bmd'))
    sheets = {}
    for k, (lit, grey) in ATLAS.items():
        sheets[k] = tuple(Image.open(os.path.join(ui, f)).convert('RGB') if os.path.exists(os.path.join(ui, f)) else None
                          for f in (lit, grey))
    skills = json.load(open(os.path.join(godot, 'assets', 'mu', 'skills.json'), encoding='utf-8'))['skills']

    meta = {}
    n = 0
    for k in sorted(skills, key=int):
        s = int(k)
        if s == 0 or s >= MAX_SKILLS:
            continue
        info = bmd.get(s, {})
        cell = resolve(s, info.get('SkillUseType', 0), info.get('Magic_Icon', 0))
        if cell is None:
            continue
        atlas, col, row = cell
        lit, grey = sheets[atlas]
        if lit is None:
            continue
        box = (col * CELL_W, row * CELL_H, (col + 1) * CELL_W, (row + 1) * CELL_H)
        if box[2] > lit.width or box[3] > lit.height:
            print('  ! skill %d: ô (%d,%d) nằm ngoài %s' % (s, col, row, atlas))
            continue
        to_button(lit.crop(box)).save(os.path.join(out_lit, 'skill_%d.png' % s))
        if grey is not None:
            to_button(grey.crop(box)).save(os.path.join(out_grey, 'skill_%d.png' % s))
        meta[s] = {'atlas': atlas, 'col': col, 'row': row, 'magic_icon': info.get('Magic_Icon', 0),
                   'use_type': info.get('SkillUseType', 0)}
        n += 1
    json.dump(meta, open(os.path.join(ui, 'skills', 'icon_cells.json'), 'w', encoding='utf-8'), indent=0)
    print('[skill_icons] %d icon tĩnh -> %s' % (n, out_lit))


if __name__ == '__main__':
    main()
