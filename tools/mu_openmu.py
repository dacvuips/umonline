#!/usr/bin/env python3
"""
mu_openmu.py — Lấy dữ liệu server OpenMU: danh sách hàng của TẤT CẢ cửa hàng NPC từ server OpenMU (cùng thư mục MuMain)
-> assets/mu/shops.json   { "<số NPC>": {"store": "<tên hàm>", "items": [ {slot,g,n,lvl,dur,opt,luck,skill,exc}, ... ]} }

           assets/mu/warps.json   (bảng dịch chuyển Move: tên, giá, cấp, ô đến)
           assets/mu/spawns.json  (NPC + vùng quái + cổng xuất hiện của từng bản đồ WorldN)
slot = vị trí trong rương NPC 8 cột x 15 hàng (x = slot % 8, y = slot / 8) — giống MerchantStore của MU.
Nguồn: OpenMU/src/Persistence/Initialization/{Version075,VersionSeasonSix}/{MerchantStores,NpcInitialization}.cs
"""
import os, re, sys, json

GROUPS = {'Swords': 0, 'Axes': 1, 'Scepters': 2, 'Spears': 3, 'Bows': 4, 'Staff': 5, 'Shields': 6, 'Helm': 7, 'Armor': 8,
          'Pants': 9, 'Gloves': 10, 'Boots': 11, 'Orbs': 12, 'Misc1': 13, 'Misc2': 14, 'Scrolls': 15}


def split_args(s):
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur.strip()); cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def val(a):
    a = a.strip()
    if a.startswith('ItemGroups.'):
        return GROUPS.get(a.split('.')[1], 0)
    if a in ('true', 'false'):
        return a == 'true'
    if a == 'null':
        return None
    a = re.sub(r'^\(\w+\)', '', a)
    try:
        return int(a, 0)
    except ValueError:
        return a


def parse_call(fn, args):
    a = [val(x) for x in split_args(args)]
    a += [None] * 10
    it = {'slot': 0, 'g': 0, 'n': 0, 'lvl': 0, 'dur': 0, 'opt': 0, 'luck': False, 'skill': False, 'exc': False}
    if fn == 'CreatePotion':
        it.update(slot=a[0], g=14, n=a[1], dur=a[2] or 1, lvl=a[3] or 0)
    elif fn == 'CreateItem':
        it.update(slot=a[0], n=a[1], g=a[2], dur=a[3] or 1, lvl=a[4] or 0)
    elif fn == 'CreateSetItem':
        it.update(slot=a[0], n=a[1], g=a[2], exc=a[3] is not None and a[3] != 'null', lvl=a[4] or 0, opt=a[5] or 0, luck=bool(a[6]))
    elif fn == 'CreateShield':
        it.update(slot=a[0], g=6, n=a[1], skill=bool(a[2]), exc=a[3] is not None, lvl=a[4] or 0, opt=a[5] or 0, luck=bool(a[6]))
    elif fn == 'CreateWeapon':
        it.update(slot=a[0], g=a[1], n=a[2], lvl=a[3] or 0, opt=a[4] or 0, luck=bool(a[5]), skill=bool(a[6]), exc=a[7] is not None)
    elif fn == 'CreateOrb':
        it.update(slot=a[0], g=12, n=a[1], dur=1)
    elif fn == 'CreateSummonOrb':
        it.update(slot=a[0], g=12, n=11, lvl=a[1] or 0, dur=1)
    elif fn == 'CreateScroll':
        it.update(slot=a[0], g=15, n=a[1], dur=1)
    else:
        return None
    for k in ('slot', 'g', 'n', 'lvl', 'dur', 'opt'):
        if not isinstance(it[k], int):
            return None
    return it


CALL = re.compile(r'ItemHelper\.(Create\w+)\(')


def parse_stores(text):
    stores = {}
    for m in re.finditer(r'ItemStorage\s+(Create\w+)\s*\(\s*short\s+number\s*\)', text):
        start = m.end()
        nxt = re.search(r'ItemStorage\s+Create\w+\s*\(\s*short\s+number\s*\)', text[start:])
        body = text[start:start + nxt.start()] if nxt else text[start:]
        items = []
        for c in CALL.finditer(body):
            # lấy đối số tới dấu ) khớp
            i, depth = c.end(), 1
            while i < len(body) and depth:
                if body[i] == '(':
                    depth += 1
                elif body[i] == ')':
                    depth -= 1
                i += 1
            line_start = body.rfind('\n', 0, c.start())
            if body[line_start:c.start()].strip().startswith('//'):
                continue
            it = parse_call(c.group(1), body[c.end():i - 1])
            if it:
                items.append(it)
        stores[m.group(1)] = items
    return stores


def parse_npc_map(text):
    out = {}
    for blk in re.split(r'def\.Number\s*=\s*', text)[1:]:
        m = re.match(r'(\d+)\s*;', blk)
        if not m:
            continue
        num = int(m.group(1))
        body = blk[:blk.find('this.GameConfiguration.Monsters.Add')] if 'this.GameConfiguration.Monsters.Add' in blk else blk[:800]
        s = re.search(r'def\.MerchantStore\s*=\s*this\.(Create\w+)\(', body)
        if s:
            out[num] = s.group(1)
    return out


def main(openmu_root, mugodot):
    base = os.path.join(openmu_root, 'src', 'Persistence', 'Initialization')
    stores, npc = {}, {}
    for ver in ('Version075', 'Version095d', 'Version097d', 'VersionSeasonSix'):
        d = os.path.join(base, ver)
        if not os.path.isdir(d):
            continue
        for fn in ('MerchantStores.cs', 'NpcInitialization.cs'):
            p = os.path.join(d, fn)
            if os.path.exists(p):
                t = open(p, encoding='utf-8-sig', errors='ignore').read()
                st = parse_stores(t)
                if ver == 'VersionSeasonSix' or ver == 'Version075':
                    stores.update({k: v for k, v in st.items() if v})
                npc.update(parse_npc_map(t)) if ver in ('Version075', 'VersionSeasonSix') else None
    out = {}
    for num, fn in sorted(npc.items()):
        if fn in stores:
            out[str(num)] = {'store': fn, 'items': sorted(stores[fn], key=lambda x: x['slot'])}
    path = os.path.join(mugodot, 'assets', 'mu', 'shops.json')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(out, open(path, 'w', encoding='utf-8'), separators=(',', ':'))
    print('== Cửa hàng NPC: %d cửa hàng, %d món -> %s' % (len(out), sum(len(v['items']) for v in out.values()), path), flush=True)
    return out




# ============================================================================= bản đồ: NPC, quái, cổng
DIR_DELTA = {
    'Undefined': (0, 0), 'North': (-1, 1), 'South': (1, -1), 'East': (1, 1), 'West': (-1, -1),
    'NorthEast': (0, 1), 'NorthWest': (-1, 0), 'SouthEast': (1, 0), 'SouthWest': (0, -1),
    '0': (0, 0), '1': (0, 0), '2': (1, 1), '3': (1, 0), '4': (1, -1), '5': (0, -1), '6': (-1, -1), '7': (-1, 0), '8': (-1, 1)
}

SPAWN_CALL_RE = re.compile(
    r'CreateMonsterSpawn\(\s*(\d+)\s*,\s*(?:this\.NpcDictionary\[(\d+)\]|this\.GameConfiguration\.Monsters\.First\(m\s*=>\s*m\.Number\s*==\s*(\d+)\)|(\w+))\s*,([^;]*?)\)\s*;'
)


def _method_body(text, name):
    m = re.search(r'IEnumerable<MonsterSpawnArea>\s+%s\s*\(\s*\)' % name, text)
    if not m:
        return None
    i = text.find('{', m.end())
    depth, j = 0, i
    while j < len(text):
        if text[j] == '{':
            depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0:
                break
        j += 1
    return text[i:j]


def parse_spawns(body, is_npc, class_text=''):
    items = []
    local_vars = {}
    for m in re.finditer(r'(?:const\s+byte|var|int|byte|short)\s+(\w+)\s*=\s*(\d+)', body or ''):
        local_vars[m.group(1)] = int(m.group(2))
    for m in re.finditer(r'var\s+(\w+)\s*=.*?First\(m\s*=>\s*m\.Number\s*==\s*(\d+)\)', body or ''):
        local_vars[m.group(1)] = int(m.group(2))
    for m in re.finditer(r'(?:const\s+short|const\s+int|const\s+byte)\s+(\w+)\s*=\s*(\d+)', class_text or ''):
        local_vars[m.group(1)] = int(m.group(2))

    for m in SPAWN_CALL_RE.finditer(body or ''):
        line_start = body.rfind('\n', 0, m.start())
        if body[line_start:m.start()].strip().startswith('//'):
            continue
        g1, g2, g3 = m.group(2), m.group(3), m.group(4)
        if g1:
            mid = int(g1)
        elif g2:
            mid = int(g2)
        elif g3 and g3 in local_vars:
            mid = local_vars[g3]
        else:
            continue

        raw_args = split_args(m.group(5))
        nums = []
        direction = 'Undefined'
        wander = False
        for a in raw_args:
            a = a.strip()
            if a.startswith('Direction.'):
                direction = a.split('.')[1]
            elif a.startswith('(Direction)'):
                direction = a.replace('(Direction)', '').strip()
            elif 'Wandering' in a:
                wander = True
            elif re.fullmatch(r'\d+', a):
                nums.append(int(a))
            elif a in local_vars:
                nums.append(local_vars[a])

        if is_npc:
            if len(nums) == 2:
                items.append({'id': mid, 'x': nums[0], 'y': nums[1], 'dir': DIR_DELTA.get(direction, (0, 0)), 'wander': wander})
            elif len(nums) >= 4:
                items.append({'id': mid, 'x': nums[0], 'y': nums[2], 'x2': nums[1], 'y2': nums[3], 'dir': DIR_DELTA.get(direction, (0, 0)), 'wander': True})
        else:
            if len(nums) == 2:
                items.append({'id': mid, 'x1': nums[0], 'x2': nums[0], 'y1': nums[1], 'y2': nums[1], 'count': 1, 'dir': DIR_DELTA.get(direction, (0, 0))})
            elif len(nums) >= 4:
                items.append({'id': mid, 'x1': nums[0], 'x2': nums[1], 'y1': nums[2], 'y2': nums[3], 'count': nums[4] if len(nums) > 4 else 1, 'dir': DIR_DELTA.get(direction, (0, 0))})
    return items


def parse_kanturu_event(t):
    consts = {
        'MayaBodyNumber': 364, 'MayaLeftHandNumber': 362, 'MayaRightHandNumber': 363,
        'NightmareNumber': 361, 'BladeHunterNumber': 354, 'DreadfearNumber': 360,
        'TwinTaleNumber': 359, 'GenociderNumber': 357, 'PersonaNumber': 358
    }
    mons = []
    for m in re.finditer(r'\(\s*\d+\s*,\s*(\w+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*\d+\s*\)', t):
        cname, x1, x2, y1, y2, cnt = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6))
        mid = consts.get(cname)
        if mid:
            mons.append({'id': mid, 'x1': x1, 'x2': x2, 'y1': y1, 'y2': y2, 'count': cnt, 'dir': (0, 0)})
    return mons


def parse_imperial_guardian(base):
    p = os.path.join(base, 'VersionSeasonSix', 'Events', 'ImperialGuardianSpawns.cs')
    if not os.path.exists(p):
        return {}
    t = open(p, encoding='utf-8-sig', errors='ignore').read()
    maps_spawns = {}
    for map_num in [69, 70, 71, 72]:
        arr_m = re.search(r'Map%dSpawns\s*=\s*\[(.*?)\];' % map_num, t, re.DOTALL)
        if not arr_m:
            continue
        sp_text = arr_m.group(1)
        mons = []
        seen = set()
        for sm in re.finditer(r'new\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*\(Direction\)(\d+)\s*,\s*(\d+)\s*,\s*ImperialGuardianDay\.(\w+)\)', sp_text):
            num, mid, x, y, direction, zone, day = int(sm.group(1)), int(sm.group(2)), int(sm.group(3)), int(sm.group(4)), sm.group(5), int(sm.group(6)), sm.group(7)
            if (num, mid, x, y) in seen:
                continue
            seen.add((num, mid, x, y))
            mons.append({'id': mid, 'x1': x, 'x2': x, 'y1': y, 'y2': y, 'count': 1, 'dir': DIR_DELTA.get(direction, (0, 0))})
        maps_spawns[map_num] = mons
    return maps_spawns


def parse_maps(base):
    classes = {}
    for ver in ('Version075', 'Version095d', 'Version097d', 'VersionSeasonSix'):
        d = os.path.join(base, ver, 'Maps')
        if not os.path.isdir(d):
            continue
        for f in os.listdir(d):
            if not f.endswith('.cs'):
                continue
            t = open(os.path.join(d, f), encoding='utf-8-sig', errors='ignore').read()
            m = re.search(r'class\s+(\w+)\s*:\s*([\w.]+)', t)
            if not m:
                continue
            name, parent = m.group(1), m.group(2)
            pver = ver
            if '.' in parent:
                parts = parent.split('.')
                pver = parts[0]
                parent = parts[-1]
            num_m = re.search(r'(?:(?:const|readonly)\s+byte\s+Number\s*=\s*|override\s+byte\s+MapNumber\s*=>\s*|override\s+byte\s+MapNumber\s*\{\s*get;\s*\}\s*=\s*)(\d+)', t)
            info = {'parent': (pver, parent), 'number': int(num_m.group(1)) if num_m else None, 'text': t}
            for meth in ('CreateNpcSpawns', 'CreateMonsterSpawns'):
                body = _method_body(t, meth)
                info[meth] = None if body is None else {
                    'base': ('base.%s' % meth) in body,
                    'list': parse_spawns(body, meth == 'CreateNpcSpawns', t)
                }
            classes[(ver, name)] = info
    return classes


def resolve(classes, key, field):
    info = classes.get(key)
    if not info:
        return [], None
    num = info['number']
    pitems, pnum = resolve(classes, info['parent'], field)
    if num is None:
        num = pnum
    m = info.get(field)
    if m is None:
        return pitems, num
    items = m['list']
    if m['base']:
        items = pitems + items
    return items, num


def parse_gates_and_warps(base):
    p = os.path.join(base, 'VersionSeasonSix', 'Gates.cs')
    if not os.path.exists(p):
        return {}, []
    t = open(p, encoding='utf-8-sig', errors='ignore').read()
    gates = {}
    for m in re.finditer(r'targetGates\.Add\(\s*(\d+)\s*,\s*this\.CreateExitGate\(\s*maps\[(\d+)\]\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,\s*true)?', t):
        g = [int(x) for x in m.groups()[:7]]
        gates[g[0]] = {'map': g[1], 'x1': g[2], 'y1': g[3], 'x2': g[4], 'y2': g[5], 'dir': g[6], 'spawn': bool(m.group(8))}
    warps = []
    for m in re.finditer(r'CreateWarpInfo\(\s*(\d+)\s*,\s*LocalizedString\.FromResource\(\(\)\s*=>\s*WarpNames\.(\w+)\)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*gates\[(\d+)\]', t):
        idx, name, cost, lvl, gate = m.groups()
        g = gates.get(int(gate))
        if g:
            warps.append({'index': int(idx), 'name': re.sub(r'(?<=[a-z])(?=[A-Z0-9])', ' ', name), 'cost': int(cost), 'level': int(lvl),
                          'world': g['map'] + 1, 'x1': g['x1'], 'y1': g['y1'], 'x2': g['x2'], 'y2': g['y2']})
    return gates, warps


def main_all(openmu_root, mugodot):
    out_dir = os.path.join(mugodot, 'assets', 'mu')
    main(openmu_root, mugodot)
    base = os.path.join(openmu_root, 'src', 'Persistence', 'Initialization')
    gates, warps = parse_gates_and_warps(base)
    json.dump(warps, open(os.path.join(out_dir, 'warps.json'), 'w', encoding='utf-8'), indent=0, ensure_ascii=False)
    print('== Danh sách dịch chuyển (Move): %d mục -> warps.json' % len(warps), flush=True)
    
    classes = parse_maps(base)
    imp_spawns = parse_imperial_guardian(base)

    gmi_path = os.path.join(base, 'VersionSeasonSix', 'GameMapsInitializer.cs')
    type_matches = []
    if os.path.exists(gmi_path):
        gmi_text = open(gmi_path, encoding='utf-8-sig').read()
        type_matches = re.findall(r'typeof\((?:(Version\w+)\.Maps\.)?(\w+)\)', gmi_text)

    # Thêm các map khác nếu chưa có trong GameMapsInitializer
    checked_keys = set()
    map_list = []
    for ver, name in type_matches:
        actual_ver = ver if ver else 'VersionSeasonSix'
        k = (actual_ver, name)
        checked_keys.add(k)
        map_list.append(k)

    for k in sorted(classes.keys()):
        if k[0] != 'VersionSeasonSix' and any(k[1] == other[1] and other[0] == 'VersionSeasonSix' for other in classes):
            continue
        if k not in checked_keys:
            map_list.append(k)

    spawns = {}
    for key in map_list:
        npcs, num1 = resolve(classes, key, 'CreateNpcSpawns')
        mons, num2 = resolve(classes, key, 'CreateMonsterSpawns')
        num = num1 if num1 is not None else num2
        if num is None:
            continue

        if key[1] == 'KanturuEvent':
            mons = mons + parse_kanturu_event(classes[key]['text'])
        elif num in imp_spawns:
            mons = mons + imp_spawns[num]

        w = str(num + 1)
        sp = [g for g in gates.values() if g['map'] == num and g['spawn']]

        if w not in spawns:
            spawns[w] = {
                'map': num,
                'class': key[1],
                'npcs': npcs,
                'monsters': mons,
                'spawn_gate': sp[0] if sp else None
            }
        else:
            existing_npcs = spawns[w]['npcs']
            for n in npcs:
                if n not in existing_npcs:
                    existing_npcs.append(n)
            spawns[w]['monsters'].extend(mons)

    json.dump(spawns, open(os.path.join(out_dir, 'spawns.json'), 'w', encoding='utf-8'), separators=(',', ':'))
    tot_mon_areas = sum(len(v['monsters']) for v in spawns.values())
    tot_monsters = sum(sum(m.get('count', 1) for m in v['monsters']) for v in spawns.values())
    print('== NPC / quái theo bản đồ: %d bản đồ, %d NPC, %d vùng quái (%d tổng số quái) -> spawns.json' % (
        len(spawns), sum(len(v['npcs']) for v in spawns.values()), tot_mon_areas, tot_monsters), flush=True)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    main_all(os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]))
