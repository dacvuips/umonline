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
DIR_DELTA = {'Undefined': (0, 0), 'North': (-1, 1), 'South': (1, -1), 'East': (1, 1), 'West': (-1, -1),
             'NorthEast': (0, 1), 'NorthWest': (-1, 0), 'SouthEast': (1, 0), 'SouthWest': (0, -1)}

SPAWN_RE = re.compile(r'CreateMonsterSpawn\(\s*(\d+)\s*,\s*this\.NpcDictionary\[(\d+)\]\s*,([^;]*?)\)\s*;')


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


def _spawns(body):
    npcs, mons = [], []
    for m in SPAWN_RE.finditer(body or ''):
        line_start = body.rfind('\n', 0, m.start())
        if body[line_start:m.start()].strip().startswith('//'):
            continue
        num = int(m.group(2))
        args = split_args(m.group(3))
        nums = []
        direction = 'Undefined'
        wander = False
        for a in args:
            a = a.strip()
            if a.startswith('Direction.'):
                direction = a.split('.')[1]
            elif 'Wandering' in a:
                wander = True
            elif re.fullmatch(r'\d+', a):
                nums.append(int(a))
        if len(nums) == 2:       # (x, y, hướng)
            npcs.append({'id': num, 'x': nums[0], 'y': nums[1], 'dir': DIR_DELTA.get(direction, (0, 0)), 'wander': wander})
        elif len(nums) >= 4:     # (x1, x2, y1, y2, số lượng)
            mons.append({'id': num, 'x1': nums[0], 'x2': nums[1], 'y1': nums[2], 'y2': nums[3], 'count': nums[4] if len(nums) > 4 else 1})
    return npcs, mons


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
                pver, parent = parent.split('.')[0], parent.split('.')[-1]
            num = re.search(r'const\s+byte\s+Number\s*=\s*(\d+)', t)
            info = {'parent': (pver, parent), 'number': int(num.group(1)) if num else None}
            for meth in ('CreateNpcSpawns', 'CreateMonsterSpawns'):
                body = _method_body(t, meth)
                info[meth] = None if body is None else {'base': ('base.%s' % meth) in body, 'list': _spawns(body)}
            classes[(ver, name)] = info
    return classes


def resolve(classes, key, field):
    info = classes.get(key)
    if not info:
        return [], [], None
    num = info['number']
    pnpcs, pmons, pnum = resolve(classes, info['parent'], field)
    if num is None:
        num = pnum
    m = info.get(field)
    if m is None:
        return pnpcs, pmons, num
    npcs, mons = m['list']
    if m['base']:
        npcs = pnpcs + npcs
        mons = pmons + mons
    return npcs, mons, num


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
    spawns = {}
    for key in classes:
        if key[0] != 'VersionSeasonSix' and any(k[1] == key[1] and k[0] == 'VersionSeasonSix' for k in classes):
            continue
        npcs, _, num = resolve(classes, key, 'CreateNpcSpawns')
        _, mons, num2 = resolve(classes, key, 'CreateMonsterSpawns')
        num = num if num is not None else num2
        if num is None:
            continue
        w = str(num + 1)
        sp = [g for g in gates.values() if g['map'] == num and g['spawn']]
        spawns[w] = {'map': num, 'class': key[1], 'npcs': npcs, 'monsters': mons,
                     'spawn_gate': sp[0] if sp else None}
    json.dump(spawns, open(os.path.join(out_dir, 'spawns.json'), 'w', encoding='utf-8'), separators=(',', ':'))
    print('== NPC / quái theo bản đồ: %d bản đồ, %d NPC, %d vùng quái -> spawns.json' % (
        len(spawns), sum(len(v['npcs']) for v in spawns.values()), sum(len(v['monsters']) for v in spawns.values())), flush=True)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    main_all(os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]))
