#!/usr/bin/env python3
"""Đóng gói game MuGodot cho web + APK "launcher" + tải ngầm.

Ý tưởng (giống launcher của kiem-hiep):
  * core  = chỉ phần cần để mở màn đăng nhập  -> nằm trong web index.pck / APK  (nhỏ, tải nhanh)
  * các gói còn lại (.pck, tên có mã băm) + manifest.json -> server phục vụ ở /content/, client tải NGẦM
    trong lúc người chơi đăng ký / đăng nhập, rồi bị chặn (cổng tải) cho tới khi xong đúng tier cần.

Cách chạy (Windows, Git Bash hoặc PowerShell):
    python tools/build_content.py --dry-run                      # chỉ in kế hoạch chia gói, KHÔNG cần Godot
    python tools/build_content.py --godot "C:/Godot/Godot_v4.7_console.exe" --web
    python tools/build_content.py --godot ... --web --apk --public-url https://mu.example.com

Kết quả trong dist/:
    web/               index.html, index.wasm, index.pck (core)...   -> build vào image nginx
    apk/mu-launcher.apk                                             -> /download/ trên server
    content/manifest.json, content/packs/<tên>-<sha8>.pck           -> /content/ trên server
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except Exception:
        pass

HERE = Path(__file__).resolve().parent.parent
DEFAULT_PROJECT = HERE.parent
TEXT_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".godot", ".cfg", ".json"}
SCAN_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".godot"}   # file được quét tham chiếu res://
RES_EXT = {".gd", ".tscn", ".scn", ".tres", ".res", ".gdshader", ".gdshaderinc", ".theme", ".ogv"}
REF_RE = re.compile(r"res://([^\"'\s)\]\},;]+)")


def glob_re(pat: str) -> re.Pattern:
    out, i = "", 0
    while i < len(pat):
        c = pat[i]
        if pat.startswith("**/", i):
            out += "(?:.*/)?"; i += 3; continue
        if pat.startswith("**", i):
            out += ".*"; i += 2; continue
        if c == "*":
            out += "[^/]*"
        elif c == "?":
            out += "[^/]"
        else:
            out += re.escape(c)
        i += 1
    return re.compile("^" + out + "$", re.I)


class Globs:
    def __init__(self, pats):
        self.res = [glob_re(p) for p in pats]

    def __call__(self, path: str) -> bool:
        return any(r.match(path) for r in self.res)


def human(n: int) -> str:
    return f"{n / 1048576:.1f} MB"


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# --------------------------------------------------------------------------------------- phân gói

def scan_project(project: Path, cfg: dict):
    never = Globs(cfg["never_ship"])
    files: dict[str, Path] = {}
    for dp, dn, fn in os.walk(project):
        d = Path(dp)
        rel_dir = d.relative_to(project).as_posix()
        dn[:] = [x for x in dn if not never(((rel_dir + "/") if rel_dir != "." else "") + x + "/x")]
        for n in fn:
            rel = ((rel_dir + "/") if rel_dir != "." else "") + n
            if never(rel):
                continue
            files[rel] = d / n
    # file nguồn "thật": bỏ qua nếu là bản copy .import (đã loại bởi never_ship), giữ nguyên các file còn lại
    return files


def is_resource(rel: str, files_all: set[str]) -> bool:
    return (rel + ".import") in files_all or Path(rel).suffix.lower() in RES_EXT


def plan(project: Path, cfg: dict):
    files = scan_project(project, cfg)
    import_markers = {str(p.relative_to(project).as_posix()) for p in project.rglob("*.import")
                      if ".godot" not in p.parts}
    res_flag = {r: (r + ".import") in import_markers or Path(r).suffix.lower() in RES_EXT for r in files}

    heavy, core_extra = Globs(cfg["heavy_zones"]), Globs(cfg["core_extra"])
    stop_at = set(cfg["stop_at"])
    roots = Globs(cfg["core_roots"])

    core: set[str] = {r for r in files if roots(r) or core_extra(r)}
    warnings: list[str] = []
    queue = list(core)
    while queue:
        cur = queue.pop()
        p = files.get(cur)
        if not p or Path(cur).suffix.lower() not in SCAN_EXT:
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for m in REF_RE.finditer(text):
            ref = m.group(1)
            if "%" in ref or ref.endswith("/") or "{" in ref:
                if ref.endswith("/") and heavy(ref + "x"):
                    warnings.append(f"{cur}: tham chiếu thư mục nặng res://{ref} (hãy liệt kê file cần trong core_extra)")
                continue
            if ref in stop_at or ref not in files or ref in core:
                continue
            if heavy(ref) and not core_extra(ref):
                warnings.append(f"{cur} -> res://{ref} (nằm vùng nặng, KHÔNG kéo vào core; nếu màn đăng nhập cần thì thêm vào core_extra)")
                continue
            core.add(ref)
            queue.append(ref)

    assigned: dict[str, list[str]] = {"core": sorted(core)}
    rules = [(p, Globs(p["globs"])) for p in cfg["packs"]]
    for rel in sorted(files):
        if rel in core:
            continue
        for pk, g in rules:
            if g(rel):
                assigned.setdefault(pk["name"], []).append(rel)
                break

    # chia nhỏ gói quá lớn: <tên>_1, <tên>_2 ...
    limit = int(cfg.get("max_pack_mb", 120)) * 1048576
    packs: list[dict] = []
    for pk in cfg["packs"]:
        lst = assigned.get(pk["name"], [])
        if not lst:
            continue
        parts, cur, cur_size = [], [], 0
        for rel in lst:
            sz = files[rel].stat().st_size
            if cur and cur_size + sz > limit:
                parts.append(cur); cur, cur_size = [], 0
            cur.append(rel); cur_size += sz
        if cur:
            parts.append(cur)
        for i, part in enumerate(parts):
            name = pk["name"] if len(parts) == 1 else f"{pk['name']}_{i + 1}"
            packs.append({"name": name, "tier": pk["tier"], "files": part,
                          "size_src": sum(files[r].stat().st_size for r in part)})
    return files, res_flag, assigned["core"], packs, warnings


def print_plan(files, core, packs, warnings):
    cs = sum(files[r].stat().st_size for r in core)
    print(f"\n{'gói':<14}{'tier':<6}{'file':>8}{'dung lượng nguồn':>20}")
    print(f"{'core':<14}{'-':<6}{len(core):>8}{human(cs):>20}")
    for p in packs:
        print(f"{p['name']:<14}{p['tier']:<6}{len(p['files']):>8}{human(p['size_src']):>20}")
    if warnings:
        print(f"\n{len(warnings)} tham chiếu từ core sang vùng nặng:")
        from collections import Counter
        per = Counter(w.split(" -> ")[0].split(":")[0] for w in warnings)
        for src, n in per.most_common(25):
            print(f"  - {src}: {n} tham chiếu vào vùng nặng (nạp lúc chạy, không kéo vào core)")
        dirs = sorted({w for w in warnings if "thư mục nặng" in w})
        for w in dirs[:10]:
            print("  -", w)
    if cs > 150 * 1048576:
        print(f"\n!! core nguồn {human(cs)} khá lớn — kiểm tra lại core_roots / core_extra / các file textures lớn.")


# --------------------------------------------------------------------------------------- export_presets

def parse_presets(text: str):
    blocks = re.split(r"(?m)^(?=\[preset\.\d+(?:\.options)?\]\s*$)", text)
    presets: dict[int, dict] = {}
    for b in blocks:
        m = re.match(r"\[preset\.(\d+)(\.options)?\]", b)
        if not m:
            continue
        idx = int(m.group(1))
        presets.setdefault(idx, {})["options" if m.group(2) else "main"] = b
    return presets


def set_key(block: str, key: str, value: str) -> str:
    line = f"{key}={value}"
    if re.search(rf"(?m)^{re.escape(key)}=.*$", block):
        return re.sub(rf"(?m)^{re.escape(key)}=.*$", lambda _m: line, block, count=1)
    return block.rstrip("\n") + "\n" + line + "\n"


# Khi trình duyệt ngắt WebGL (GPU quá tải), Godot chỉ hiện hộp thoại rồi màn đen. Tự tải lại trang (gói đã lưu nên vào lại nhanh),
# tối đa 3 lần liên tiếp để tránh vòng lặp.
CTX_LOST_JS = ("<script>window.addEventListener('webglcontextlost',function(e){e.preventDefault();e.stopImmediatePropagation();"
               "try{var n=+(sessionStorage.getItem('mu_ctxlost')||0);if(n<3){sessionStorage.setItem('mu_ctxlost',n+1);location.reload();return;}}catch(x){}"
               "alert('Trinh duyet da ngat GPU, vui long tai lai trang.');},true);"
               "setTimeout(function(){try{sessionStorage.removeItem('mu_ctxlost');}catch(x){}},90000);</script>")


def add_ctx_lost_reload(preset: str) -> str:
    return re.sub(r'(html/head_include=")(.*)(")', lambda m: m.group(1) + m.group(2) + CTX_LOST_JS.replace('"', '\\"') + m.group(3),
                  preset, count=1)



def gen_preset(idx: int, base_main: str, base_opts: str, name: str, platform: str, rel_files: list[str],
               res_flag: dict[str, bool], export_path: str, runnable: bool) -> str:
    res_list = [f"res://{r}" for r in rel_files if res_flag.get(r)]
    other = [r for r in rel_files if not res_flag.get(r)]
    main = re.sub(r"\[preset\.\d+\]", f"[preset.{idx}]", base_main, count=1)
    main = set_key(main, "name", f'"{name}"')
    main = set_key(main, "platform", f'"{platform}"')
    main = set_key(main, "runnable", "true" if runnable else "false")
    main = set_key(main, "export_filter", '"resources"')
    main = set_key(main, "export_files", "PackedStringArray(" + ", ".join(f'"{x}"' for x in res_list) + ")")
    main = set_key(main, "include_filter", '"' + ", ".join(other) + '"')
    main = set_key(main, "exclude_filter", '""')
    main = set_key(main, "export_path", f'"{export_path}"')
    opts = re.sub(r"\[preset\.\d+\.options\]", f"[preset.{idx}.options]", base_opts, count=1)
    return main.rstrip("\n") + "\n\n" + opts.rstrip("\n") + "\n\n"


def run(cmd: list[str], **kw):
    print("  $", " ".join(f'"{c}"' if " " in c else c for c in cmd)[:220])
    subprocess.run(cmd, check=True, **kw)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--project", default=str(DEFAULT_PROJECT), help="thư mục chứa project.godot")
    ap.add_argument("--godot", default=os.environ.get("GODOT", ""), help="đường dẫn Godot (bản console), hoặc biến GODOT")
    ap.add_argument("--out", default=str(HERE / "dist"))
    ap.add_argument("--packs-config", default=str(HERE / "packs.json"))
    ap.add_argument("--dry-run", action="store_true", help="chỉ in kế hoạch chia gói")
    ap.add_argument("--web", action="store_true", help="xuất web (core) vào dist/web")
    ap.add_argument("--apk", action="store_true", help="xuất APK launcher (core) vào dist/apk")
    ap.add_argument("--public-url", default="", help="URL công khai của server (ghi vào mu_content.json cho APK; web tự dùng origin)")
    ap.add_argument("--gateway-url", default="", help="VD wss://mu.example.com/ws (client tự điền vào ô Gateway)")
    ap.add_argument("--apk-url", default="", help="URL tải APK (nếu client quá cũ)")
    ap.add_argument("--min-launcher", type=int, default=1)
    ap.add_argument("--force", action="store_true", help="xuất lại mọi gói, bỏ qua cache")
    ap.add_argument("--prune", action="store_true", help="xoá gói cũ không còn trong manifest")
    a = ap.parse_args()

    project = Path(a.project).resolve()
    cfg = json.loads(Path(a.packs_config).read_text(encoding="utf-8"))
    if not (project / "project.godot").exists():
        sys.exit(f"Không thấy project.godot trong {project}")

    print(f"Dự án: {project}\nQuét tài nguyên...")
    files, res_flag, core, packs, warnings = plan(project, cfg)
    print_plan(files, core, packs, warnings)
    if a.dry_run:
        return
    if not a.godot or not Path(a.godot).exists():
        sys.exit("Cần --godot <đường dẫn Godot console> (hoặc đặt biến môi trường GODOT).")

    out = Path(a.out)
    packs_dir = out / "content" / "packs"
    packs_dir.mkdir(parents=True, exist_ok=True)
    fp_path = out / ".fingerprints.json"
    fps = json.loads(fp_path.read_text()) if fp_path.exists() and not a.force else {}

    # mu_content.json: địa chỉ server cho bản APK (web dùng origin hiện tại)
    cfg_json = project / "mu_content.json"
    if a.public_url or a.gateway_url or not cfg_json.exists():
        cfg_json.write_text(json.dumps({"content_url": a.public_url.rstrip("/"), "gateway_url": a.gateway_url}, indent=1),
                            encoding="utf-8")

    godot_ver = subprocess.run([a.godot, "--version"], capture_output=True, text=True, check=True).stdout.strip()
    m = re.match(r"(\d+)\.(\d+)", godot_ver)
    engine = f"{m.group(1)}.{m.group(2)}" if m else godot_ver

    presets_path = project / "export_presets.cfg"
    original = presets_path.read_text(encoding="utf-8")
    pre = parse_presets(original)
    by_name = {}
    for i, d in pre.items():
        mm = re.search(r'(?m)^name="([^"]*)"', d.get("main", ""))
        if mm:
            by_name[mm.group(1)] = i
    if "Web" not in by_name:
        sys.exit('export_presets.cfg không có preset "Web".')
    web_i = by_name["Web"]
    nxt = max(pre) + 1

    def fingerprint(lst):
        h = hashlib.sha256(engine.encode())
        for r in lst:
            st = files[r].stat()
            h.update(f"{r}\0{st.st_size}\0{st.st_mtime_ns}\n".encode())
            if (files[r].parent / (files[r].name + ".import")).exists():
                ist = (files[r].parent / (files[r].name + ".import")).stat()
                h.update(f"{ist.st_mtime_ns}\n".encode())
        return h.hexdigest()

    extra = ""
    jobs = []   # (preset_name, out_path, kind)
    manifest_packs: list[dict] = []
    todo = []
    for p in packs:
        fp = fingerprint(p["files"])
        cached = fps.get(p["name"])
        if cached and cached["fp"] == fp and (packs_dir / cached["file"]).exists():
            p["file"], p["sha256"], p["size"] = cached["file"], cached["sha256"], cached["size"]
            p["fp"] = fp
            print(f"  = {p['name']}: không đổi, dùng lại {p['file']}")
        else:
            p["fp"] = fp
            todo.append(p)

    work = out / ".work"
    work.mkdir(parents=True, exist_ok=True)
    for p in todo:
        pname = f"MuPack {p['name']}"
        extra += gen_preset(nxt, pre[web_i]["main"], pre[web_i]["options"], pname, "Web", p["files"], res_flag,
                            "", False)
        p["preset"] = pname
        nxt += 1
    core_presets = []
    if a.web:
        extra += add_ctx_lost_reload(gen_preset(nxt, pre[web_i]["main"], pre[web_i]["options"], "MuCore Web", "Web", core, res_flag,
                            os.path.relpath(out / "web" / "index.html", project).replace("\\", "/"), True
                            ).replace("progressive_web_app/enabled=true", "progressive_web_app/enabled=false"))  # SW cache cứng -> không cập nhật được
        core_presets.append(("MuCore Web", "web"))
        nxt += 1
    if a.apk:
        if "Android" not in by_name:
            sys.exit('export_presets.cfg không có preset "Android".')
        ai = by_name["Android"]
        extra += gen_preset(nxt, pre[ai]["main"], pre[ai]["options"], "MuCore Android", "Android", core, res_flag,
                            os.path.relpath(out / "apk" / "mu-launcher.apk", project).replace("\\", "/"), True)
        core_presets.append(("MuCore Android", "apk"))
        nxt += 1

    # Ghi tạm export_presets.cfg (có bản gốc để khôi phục), luôn khôi phục khi xong/lỗi.
    backup = presets_path.with_suffix(".cfg.mubackup")
    shutil.copyfile(presets_path, backup)
    try:
        presets_path.write_text(original.rstrip("\n") + "\n\n" + extra, encoding="utf-8")
        base = [a.godot, "--headless", "--path", str(project)]
        if todo or core_presets:
            print("\nNhập tài nguyên (nếu cần)...")
            subprocess.run(base + ["--import"], check=False)
        for p in todo:
            tmp = work / f"{p['name']}.pck"
            print(f"\nXuất gói {p['name']} ({len(p['files'])} file)...")
            run(base + ["--export-pack", p["preset"], str(tmp)])
            sha = sha256_file(tmp)
            fname = f"{p['name']}-{sha[:8]}.pck"
            shutil.move(str(tmp), str(packs_dir / fname))
            p["file"], p["sha256"], p["size"] = fname, sha, (packs_dir / fname).stat().st_size
            fps[p["name"]] = {"fp": p["fp"], "file": fname, "sha256": sha, "size": p["size"]}
        for preset, kind in core_presets:
            d = out / kind
            if d.exists():
                shutil.rmtree(d)
            d.mkdir(parents=True)
            print(f"\nXuất {preset}...")
            # Máy dev chỉ có template android_debug.apk -> APK xuất bằng --export-debug (ký bằng debug keystore)
            run(base + ["--export-debug" if kind == "apk" else "--export-release", preset])
    finally:
        shutil.move(str(backup), str(presets_path))
        shutil.rmtree(work, ignore_errors=True)

    fp_path.write_text(json.dumps(fps, indent=1))
    for p in packs:
        first_res = next((f"res://{r}" for r in p["files"] if res_flag.get(r)), "")
        manifest_packs.append({"name": p["name"], "tier": p["tier"], "file": p["file"], "size": p["size"],
                               "sha256": p["sha256"], "probe": first_res})
    manifest = {
        "version": int(time.time()),
        "engine": engine,
        "min_launcher": a.min_launcher,
        "gateway_url": a.gateway_url,
        "apk_url": a.apk_url,
        "packs": manifest_packs,
    }
    if a.prune:
        keep = {p["file"] for p in manifest_packs}
        for f in packs_dir.glob("*.pck"):
            if f.name not in keep:
                f.unlink()
                print("  xoá gói cũ", f.name)
    (out / "content" / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    total = sum(p["size"] for p in manifest_packs)
    print(f"\nXong. {len(manifest_packs)} gói, tổng {human(total)} -> {out / 'content'}")
    for k in ("web", "apk"):
        d = out / k
        if d.exists():
            s = sum(f.stat().st_size for f in d.rglob("*") if f.is_file())
            print(f"  {k}: {human(s)} ({d})")


if __name__ == "__main__":
    main()
