#!/usr/bin/env python3
"""
mu_toolkit.py — Bộ công cụ chuyển dữ liệu MU Online (client gốc) sang MuGodot.
Chỉ cần Python 3 (thư viện chuẩn). Chạy qua MU_TOOLKIT.bat hoặc dock "MU Tools" trong Godot.

  python mu_toolkit.py models  [Thư_mục,...] [--force]   chuyển BMD -> .glb (mặc định: Player,Monster,NPC,Item,Skill,Effect)
  python mu_toolkit.py maps    [số_map,...] [--force]   chuyển bản đồ WorldN + model vật thể ObjectN (mặc định: tất cả)
  python mu_toolkit.py server                           dữ liệu server OpenMU: cửa hàng NPC, bảng Move, NPC/quái từng bản đồ,
                                                        chỉ số quái + skill (monster_stats.json, skills.json)
  python mu_toolkit.py ui                               giao diện gốc (Data/Interface) -> assets/mu/ui
  python mu_toolkit.py styles                           kiểu vẽ đồ của source client (ItemRenderStyles.cpp) -> assets/mu/item_styles.json
  python mu_toolkit.py check                            kiểm tra: model nào trong danh mục quái / NPC / đồ / bản đồ còn thiếu
  python mu_toolkit.py all     [--force]                models + maps + check
  python mu_toolkit.py config  <Client\\Data> [MuGodot]   lưu đường dẫn (tools/mu_toolkit.json)

Đường dẫn mặc định: MuGodot = thư mục cha của tools/, Client\\Data = <MuGodot>/../Client/Data
"""
import os, sys, json, time

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.path.join(HERE, 'mu_toolkit.json')
sys.path.insert(0, HERE)


def load_cfg():
    mugodot = os.path.dirname(HERE)
    cfg = {'data_root': os.path.join(os.path.dirname(mugodot), 'Client', 'Data'), 'mugodot': mugodot,
           'openmu_root': os.path.join(os.path.dirname(mugodot), 'OpenMU'),
           'source_root': os.path.join(os.path.dirname(mugodot), 'Source', 'src', 'source')}
    if os.path.exists(CFG):
        try:
            cfg.update(json.load(open(CFG, encoding='utf-8')))
        except Exception as e:
            print('! Không đọc được %s: %s' % (CFG, e))
    return cfg


def cmd_config(argv):
    cfg = load_cfg()
    if argv:
        cfg['data_root'] = os.path.abspath(argv[0])
    if len(argv) > 1:
        cfg['mugodot'] = os.path.abspath(argv[1])
    json.dump(cfg, open(CFG, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    print('Client\\Data : %s' % cfg['data_root'])
    print('MuGodot     : %s' % cfg['mugodot'])


def cmd_models(argv, cfg):
    import mu_convert_all
    folders = [a for a in argv if not a.startswith('--')]
    sys.argv = ['mu_convert_all.py', cfg['data_root'], cfg['mugodot']] + ([','.join(folders)] if folders else []) + \
               [a for a in argv if a.startswith('--')]
    mu_convert_all.main()


def cmd_maps(argv, cfg):
    import mu_maps, mu_convert_all
    nums = []
    for a in argv:
        if not a.startswith('--'):
            nums += [int(x) for x in a.split(',') if x.strip().isdigit()]
    worlds = mu_maps.find_world_dirs(cfg['data_root'])
    if nums:
        worlds = {k: v for k, v in worlds.items() if k in nums}
    folders = []
    for n in worlds:
        f = mu_maps.find_object_dir(cfg['data_root'], n)
        if f and n != 1:   # Object1 (Lorencia) đã có bộ riêng assets/lorencia
            folders.append(f)
    if folders:
        print('== Model vật thể bản đồ: %s' % ', '.join(folders), flush=True)
        sys.argv = ['mu_convert_all.py', cfg['data_root'], cfg['mugodot'], ','.join(folders)] + [a for a in argv if a.startswith('--')]
        mu_convert_all.main()
    mu_maps.main(cfg['data_root'], cfg['mugodot'], list(worlds.keys()))


def cmd_server(cfg):
    import mu_openmu
    root = cfg.get('openmu_root', '')
    if not os.path.isdir(os.path.join(root, 'src', 'Persistence', 'Initialization')):
        print('! Không thấy server OpenMU tại %s (bỏ qua cửa hàng / Move / NPC)' % root)
        return
    mu_openmu.main_all(root, cfg['mugodot'])
    import mu_gamedata
    mu_gamedata.main(root, cfg['mugodot'])   # chỉ số quái + skill + orb/scroll dạy skill


def cmd_styles(cfg):
    """Kiểu vẽ đồ (ItemRenderStyles.cpp của source client) -> assets/mu/item_styles.json + texture hiệu ứng"""
    import mu_styles
    mu_styles.main_all(cfg.get('source_root', ''), cfg['data_root'], cfg['mugodot'])


def cmd_ui(cfg):
    """Data/Interface/*.OZJ|OZT -> assets/mu/ui/*.jpg|png (giữ tên gốc, chữ thường)"""
    from mu_convert_all import decode_ozt, png_bytes
    src = os.path.join(cfg['data_root'], 'Interface')
    out = os.path.join(cfg['mugodot'], 'assets', 'mu', 'ui')
    os.makedirs(out, exist_ok=True)
    n = 0
    for f in os.listdir(src):
        p = os.path.join(src, f)
        stem, ext = os.path.splitext(f)
        ext = ext.lower()
        try:
            if ext == '.ozj':
                dst = os.path.join(out, stem.lower() + '.jpg')
                if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(p):
                    open(dst, 'wb').write(open(p, 'rb').read()[24:])
                n += 1
            elif ext == '.ozt':
                dst = os.path.join(out, stem.lower() + '.png')
                if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(p):
                    dec = decode_ozt(open(p, 'rb').read())
                    if dec:
                        open(dst, 'wb').write(png_bytes(dec[0], dec[1], dec[2]))
                n += 1
        except Exception as e:
            print('   ! %s: %s' % (f, e))
    print('== Giao diện gốc: %d ảnh -> %s' % (n, out), flush=True)


def _glb(out_root, file):
    """'Data/Monster/Monster01.bmd' -> <out>/Monster/Monster01.glb (không phân biệt hoa thường như Windows)"""
    f = file.replace('\\', '/')
    if f.lower().startswith('data/'):
        f = f[5:]
    return os.path.join(out_root, *os.path.splitext(f)[0].split('/')) + '.glb'


def _exists_ci(path):
    if os.path.exists(path):
        return True
    d, b = os.path.split(path)
    return os.path.isdir(d) and b.lower() in (x.lower() for x in os.listdir(d))


def cmd_check(cfg):
    out_root = os.path.join(cfg['mugodot'], 'assets', 'mu')
    cat = os.path.join(out_root, 'catalog')
    lines = []
    def log(s=''):
        print(s); lines.append(s)
    log('BÁO CÁO KIỂM TRA DỮ LIỆU MU  (%s)' % time.strftime('%Y-%m-%d %H:%M'))
    log('assets: %s' % out_root)
    idx_path = os.path.join(out_root, 'mu_models_index.json')
    if not os.path.exists(idx_path):
        log('! Chưa chuyển model nào. Chạy: mu_toolkit.py models'); _save(out_root, lines); return 1
    index = json.load(open(idx_path, encoding='utf-8'))
    by_folder = {}
    for k in index:
        by_folder[k.split('/')[0]] = by_folder.get(k.split('/')[0], 0) + 1
    log('Đã chuyển %d model: %s' % (len(index), ', '.join('%s %d' % kv for kv in sorted(by_folder.items()))))
    bad = 0
    # --- nhân vật
    log('\n[Nhân vật]')
    need = ['Player/player'] + ['Player/%sClass%02d' % (p, c) for p in ('Helm', 'Armor', 'Pant', 'Glove', 'Boot') for c in range(1, 8)]
    miss = [n for n in need if not _exists_ci(os.path.join(out_root, *n.split('/')) + '.glb')]
    log('  Player.bmd + thân mặc định 7 lớp: %d/%d có' % (len(need) - len(miss), len(need)))
    for n in miss:
        log('  - thiếu %s.glb' % n)
    bad += len(miss)
    # --- quái / NPC
    log('\n[Quái / NPC]')
    mons = _read(os.path.join(cat, 'Monsters', 'Monsters.json'))
    models = _read(os.path.join(cat, 'Monsters', 'Models.json'))
    if mons and models:
        slot = {m.get('slot'): m for m in models.get('models', [])}
        counts = {}
        miss = []
        nomodel = []
        for m in mons.get('monsters', []):
            kind = m.get('kind', 'other')
            md = slot.get(m.get('model', ''))
            ok = bool(md) and _exists_ci(_glb(out_root, md.get('file', '')))
            if ok:
                for p in md.get('parts', []) or []:
                    ok = ok and _exists_ci(_glb(out_root, p.get('file', '')))
            c = counts.setdefault(kind, [0, 0]); c[1] += 1
            if ok:
                c[0] += 1
            elif not md:
                # Client gốc không có model riêng (bẫy, cổng vô hình, quái dùng model người chơi, NPC của server...)
                nm = m.get('name', {})
                nomodel.append('#%d %s' % (m.get('number', -1), nm.get('en', nm) if isinstance(nm, dict) else nm))
            else:
                nm = m.get('name', {})
                miss.append('  - #%d %s (%s) -> %s' % (m.get('number', -1), nm.get('en', nm) if isinstance(nm, dict) else nm, kind,
                                                       md.get('file', 'không có model') if md else 'không có model'))
        for k, (a, b) in sorted(counts.items()):
            log('  %s: %d/%d có model' % (k, a, b))
        if nomodel:
            log('  (%d mục KHÔNG có model riêng trong client gốc — không phải lỗi chuyển đổi: %s)' % (len(nomodel), ', '.join(nomodel[:12]) + ' ...'))
        for s in miss[:300]:
            log(s)
        if len(miss) > 300:
            log('  ... và %d mục nữa' % (len(miss) - 300))
        bad += len(miss)
    else:
        log('  ! Thiếu catalog Monsters (chạy lại bước models)')
    # --- đồ
    log('\n[Đồ / vũ khí / cánh]')
    for g in range(13):
        fn = None
        d = os.path.join(cat, 'Items', 'Models')
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.startswith('Group%02d' % g):
                    fn = os.path.join(d, f)
        js = _read(fn) if fn else None
        if not js:
            continue
        total = ok = 0
        miss = []
        for m in js.get('models', []):
            if not m.get('file'):
                continue
            total += 1
            if _exists_ci(_glb(out_root, m['file'])):
                ok += 1
            else:
                miss.append('%d' % m.get('number', -1))
        log('  %s: %d/%d có model%s' % (os.path.basename(fn)[:-5], ok, total, ('  (thiếu số: %s)' % ', '.join(miss[:40])) if miss else ''))
        bad += len(miss)
    # --- hiệu ứng
    log('\n[Hiệu ứng / skill]')
    for f in ('Skill', 'Effect'):
        log('  %s: %d model' % (f, by_folder.get(f, 0)))
    for t in ('Chrome01', 'Chrome02', 'Shiny01'):
        if not os.path.exists(os.path.join(out_root, 'fx', t + '.jpg')):
            log('  - thiếu texture phát sáng fx/%s.jpg' % t); bad += 1
    # --- bản đồ
    log('\n[Bản đồ]')
    midx = _read(os.path.join(out_root, 'maps', 'maps_index.json')) or {}
    if not midx:
        log('  ! Chưa chuyển bản đồ. Chạy: mu_toolkit.py maps')
    for k in sorted(midx, key=lambda x: int(x)):
        m = midx[k]
        objs = _read(os.path.join(out_root, 'maps', 'World%s' % k, 'objects.json')) or {}
        need = sorted({o['m'] for o in objs.get('objects', [])})
        if int(k) == 1:
            have = len(need)   # Lorencia dùng assets/lorencia
        else:
            have = sum(1 for x in need if _exists_ci(os.path.join(out_root, *x.split('/')) + '.glb'))
        log('  World%-3s %-24s vật thể %5d, model %3d/%-3d, tile %2d%s' % (k, m.get('name', ''), m.get('objects', 0), have, len(need),
                                                                     m.get('tiles', 0), '' if have == len(need) else '  <- thiếu model'))
        bad += len(need) - have
    log('\nTổng: %d mục thiếu.' % bad if bad else '\nTổng: đủ dữ liệu.')
    _save(out_root, lines)
    return 0


def _read(p):
    try:
        return json.load(open(p, encoding='utf-8')) if p and os.path.exists(p) else None
    except Exception as e:
        print('! %s: %s' % (p, e)); return None


def _save(out_root, lines):
    os.makedirs(out_root, exist_ok=True)
    p = os.path.join(out_root, 'mu_report.txt')
    open(p, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print('\nĐã ghi báo cáo: %s' % p)


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
    except Exception:
        pass
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help', 'help'):
        print(__doc__); return 0
    cmd, argv = sys.argv[1], sys.argv[2:]
    if cmd == 'config':
        cmd_config(argv); return 0
    cfg = load_cfg()
    if not os.path.isdir(cfg['data_root']):
        print('! Không thấy thư mục Client\\Data: %s' % cfg['data_root'])
        print('  Đặt lại: python mu_toolkit.py config <đường dẫn Client\\Data>')
        return 1
    print('Client\\Data : %s\nMuGodot     : %s\n' % (cfg['data_root'], cfg['mugodot']))
    if cmd == 'models':
        cmd_models(argv, cfg)
    elif cmd == 'maps':
        cmd_maps(argv, cfg)
    elif cmd == 'server':
        cmd_server(cfg)
    elif cmd == 'ui':
        cmd_ui(cfg)
    elif cmd == 'styles':
        cmd_styles(cfg)
    elif cmd == 'check':
        return cmd_check(cfg)
    elif cmd == 'all':
        cmd_ui(cfg)
        cmd_server(cfg)
        cmd_styles(cfg)
        cmd_models([a for a in argv if a.startswith('--')], cfg)
        print()
        cmd_maps([a for a in argv if a.startswith('--')], cfg)
        print()
        return cmd_check(cfg)
    else:
        print('Lệnh không hợp lệ: %s' % cmd); print(__doc__); return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
