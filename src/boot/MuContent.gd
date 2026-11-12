extends Node
## Tải ngầm các gói nội dung (.pck) trong lúc người chơi đang ở màn đăng nhập / chọn server.
##
## Web  : index.pck (core) tải cùng trang. Gói còn lại lấy từ <origin>/content/ -> lưu user:// (IndexedDB, giữ qua các lần mở).
## APK  : APK chỉ chứa core. Địa chỉ server đọc từ res://mu_content.json (build_content.py --public-url).
## Chạy trong editor hoặc bản đã đóng đủ gói: tự coi như xong, không tải gì.
##
## Cách dùng ở các màn hình:
##     await MuContent.require_tier(1)   # trước khi vào màn chọn nhân vật
##     await MuContent.require_tier(2)   # trước khi vào thế giới game
## Nếu chưa tải xong, hiện màn chặn có thanh tiến độ, tải xong mới đi tiếp.
## Đây phải là AUTOLOAD (project.godot) tên "MuContent".

signal progress(done_bytes: int, total_bytes: int, current_pack: String)
signal tier_ready(tier: int)
signal failed(message: String)

const CONFIG_PATH := "res://mu_content.json"
const CONTENT_DIR := "user://content"
const MANIFEST_PATH := "user://content/manifest.json"
const DEFAULT_URL := "http://127.0.0.1:8090"
const MAX_TRIES := 5
const LAUNCHER_VERSION := 1

var base_url := ""
var gateway_url := ""
var manifest: Dictionary = {}
var _packs: Array = []            # các gói cần có, theo thứ tự tải
var _state := "idle"              # idle | fetching | downloading | done | error
var _error := ""
var _total := 0
var _done := 0
var _ready_tiers := {}            # tier -> true
var _gate: Node = null

func _install_emoji_fallback() -> void:
	# Web export has no system fonts, so emoji render as hex boxes. Chain Noto Emoji as fallback.
	var emoji: Font = load("res://assets/fonts/NotoEmoji.ttf")
	if emoji == null:
		return
	var targets: Array = [ThemeDB.fallback_font, ThemeDB.get_default_theme().default_font]
	for f in targets:
		if f is Font and not (f.fallbacks as Array).has(emoji):
			var fb: Array[Font] = f.fallbacks
			fb.append(emoji)
			f.fallbacks = fb


## Giảm FPS khi cửa sổ game mất focus (đỡ nóng máy / quạt chạy khi để game ở nền)
const FPS_UNFOCUSED := 15
var _fps_focused := 60

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if Engine.max_fps != FPS_UNFOCUSED:
			_fps_focused = Engine.max_fps
		Engine.max_fps = FPS_UNFOCUSED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Engine.max_fps = _fps_focused

func _ready() -> void:
	_install_emoji_fallback()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("editor") or "--no-content" in OS.get_cmdline_user_args():
		_finish_all()
		return
	base_url = _resolve_base_url()
	print("[MuContent] ready base=%s" % base_url)
	_make_hud()
	DirAccess.make_dir_recursive_absolute(CONTENT_DIR)
	_run.call_deferred()

# --- API cho scene ---

func is_tier_ready(tier: int) -> bool:
	return _ready_tiers.has(tier) or _state == "done"

func is_all_ready() -> bool:
	return _state == "done"

## Chờ tới khi mọi gói có tier <= `tier` đã nạp. Chưa xong -> hiện màn chặn.
func require_tier(tier: int) -> void:
	if is_tier_ready(tier):
		return
	var gate := _ensure_gate()
	gate.call("open", tier)
	while not is_tier_ready(tier):
		await get_tree().process_frame
	gate.call("close")

func get_state() -> String:
	return _state

func get_error() -> String:
	return _error

func get_progress() -> Vector2i:
	return Vector2i(_done, _total)

func retry() -> void:
	if _state == "error":
		_run.call_deferred()

# --- Luồng chính ---

func _resolve_base_url() -> String:
	var url := ""
	if FileAccess.file_exists(CONFIG_PATH):
		var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if cfg is Dictionary:
			url = str(cfg.get("content_url", ""))
			gateway_url = str(cfg.get("gateway_url", ""))
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--content-url="):
			url = arg.substr("--content-url=".length())
	if OS.has_feature("web"):
		# Bản web luôn dùng chính tên miền đang mở (cùng origin, không dính CORS).
		url = str(JavaScriptBridge.eval("location.origin", true))
	if url.is_empty():
		url = DEFAULT_URL
	return url.trim_suffix("/")

func _run() -> void:
	_state = "fetching"
	_error = ""
	print("[MuContent] fetch manifest")
	var m := await _fetch_manifest()
	print("[MuContent] manifest empty=%s" % str(m.is_empty()))
	if m.is_empty():
		# Mất mạng nhưng đã tải đủ trước đó -> dùng bản cũ.
		var cached: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if cached is Dictionary and _all_present(cached):
			manifest = cached
		else:
			_fail("Không kết nối được máy chủ nội dung (%s)." % base_url)
			return
	else:
		manifest = m
	if int(manifest.get("min_launcher", 1)) > LAUNCHER_VERSION:
		_fail("Phiên bản ứng dụng quá cũ, vui lòng tải bản mới.")
		return
	if gateway_url.is_empty():
		gateway_url = str(manifest.get("gateway_url", ""))
	if gateway_url.is_empty() and OS.has_feature("web"):
		# Web: gateway nằm cùng tên miền, đường dẫn /ws (nginx chuyển tới mu-gateway).
		gateway_url = base_url.replace("https://", "wss://").replace("http://", "ws://") + "/ws"
	_apply_gateway()

	_packs = manifest.get("packs", [])
	_packs.sort_custom(func(a, b): return int(a.get("tier", 2)) < int(b.get("tier", 2)))
	_total = 0
	_done = 0
	var todo: Array = []
	for p: Dictionary in _packs:
		if _bundled(p):
			continue
		if not _pack_present(p):
			todo.append(p)
			_total += int(p["size"])
	_state = "downloading"
	_save_manifest()

	var tiers := {1: true, 2: true}
	for p: Dictionary in _packs:
		tiers[int(p.get("tier", 2))] = true
	# Nạp những gói đã có sẵn trên máy.
	for p: Dictionary in _packs:
		if not todo.has(p):
			_mount(p)
	_check_tiers(tiers)

	for p: Dictionary in todo:
		var err := await _download_pack(p)
		if err != "":
			_fail(err)
			return
		_step = "nap goi"; print("[MuContent] %s mount bat dau t=%d" % [p["name"], Time.get_ticks_msec()])
		var _mok := _mount(p)
		_step = ""; print("[MuContent] %s mount xong ok=%s t=%d" % [p["name"], str(_mok), Time.get_ticks_msec()])
		if not _mok:
			DirAccess.remove_absolute(CONTENT_DIR.path_join(str(p["file"])))
			_fail("Gói %s bị lỗi, vui lòng thử lại." % p["name"])
			return
		_check_tiers(tiers)
	_cleanup()
	_finish_all()

## Gói đã đóng sẵn trong bản cài (bản đủ / editor): probe tồn tại trong res://.
func _bundled(p: Dictionary) -> bool:
	var probe := str(p.get("probe", ""))
	return probe != "" and ResourceLoader.exists(probe) and not _mounted.has(str(p["file"]))

var _mounted := {}

func _pack_present(p: Dictionary) -> bool:
	var path := CONTENT_DIR.path_join(str(p["file"]))
	return FileAccess.file_exists(path) and _file_size(path) == int(p["size"])

func _all_present(m: Dictionary) -> bool:
	for p: Dictionary in m.get("packs", []):
		if not _bundled(p) and not _pack_present(p):
			return false
	return true

func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n

func _mount(p: Dictionary) -> bool:
	var file := str(p["file"])
	if _mounted.has(file):
		return true
	# replace_files=false: gói chứa kèm project.binary/uid_cache của lúc xuất, không được đè bản của core.
	var ok := ProjectSettings.load_resource_pack(CONTENT_DIR.path_join(file), false)
	if ok:
		_mounted[file] = true
	else:
		push_error("MuContent: không nạp được gói " + file)
	return ok

func _check_tiers(tiers: Dictionary) -> void:
	for t: int in tiers:
		if _ready_tiers.has(t):
			continue
		var all_ok := true
		for p: Dictionary in _packs:
			if int(p.get("tier", 2)) <= t and not (_mounted.has(str(p["file"])) or _bundled(p)):
				all_ok = false
				break
		if all_ok:
			_ready_tiers[t] = true
			tier_ready.emit(t)

func _finish_all() -> void:
	_state = "done"
	for t in [0, 1, 2]:
		if not _ready_tiers.has(t):
			_ready_tiers[t] = true
			tier_ready.emit(t)
	progress.emit(_total, _total, "")

func _fail(msg: String) -> void:
	_state = "error"
	_error = msg
	push_warning("MuContent: " + msg)
	failed.emit(msg)

func _apply_gateway() -> void:
	# Ô Gateway ở màn đăng nhập lấy từ MuAccountSession.server_gateway_url (static) — điền sẵn địa chỉ thật.
	if gateway_url != "":
		MuAccountSession.server_gateway_url = gateway_url

# --- Mạng ---

func _fetch_manifest() -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	http.accept_gzip = false   # trình duyệt đã tự giải nén; Godot web giải nén lần nữa sẽ lỗi
	add_child(http)
	# ?t= tránh cache trung gian giữ manifest cũ.
	var err := http.request("%s/content/manifest.json?t=%d" % [base_url, Time.get_ticks_msec()])
	if err != OK:
		push_warning("MuContent: request manifest lỗi %d" % err)
		http.queue_free()
		return {}
	var st := {"done": false, "res": []}
	http.request_completed.connect(func(r, c, h, b): st["res"] = [r, c, h, b]; st["done"] = true)
	var waited := 0.0
	while not st["done"]:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		print("[MuContent] diag t=%.0f status=%d dl=%d body=%d" % [waited, http.get_http_client_status(), http.get_downloaded_bytes(), http.get_body_size()])
	var res: Array = st["res"]
	http.queue_free()
	print("[MuContent] manifest result=%d code=%d bytes=%d" % [int(res[0]), int(res[1]), (res[3] as PackedByteArray).size()])
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return {}
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary or not (data as Dictionary).has("packs"):
		return {}
	return data

## Tải gói theo từng khối Range (4 MB). Kết nối chập chờn / bị cắt giữa chừng chỉ phải thử lại đúng khối đó,
## không tải lại cả gói. Ghi nối vào file .part rồi kiểm tra kích thước + SHA-256.
const CHUNK_BYTES := 4194304
const CHUNK_TRIES := 8

func _download_pack(p: Dictionary) -> String:
	var file := str(p["file"])
	if not file.is_valid_filename() or not file.ends_with(".pck"):
		return "Tên gói không hợp lệ trên máy chủ."
	var dest := CONTENT_DIR.path_join(file)
	var part := dest + ".part"
	var url := "%s/content/packs/%s" % [base_url, file]
	var size := int(p["size"])
	var before := _done
	DirAccess.remove_absolute(part)
	var out := FileAccess.open(part, FileAccess.WRITE)
	if out == null:
		return "Không tạo được file tạm (hết bộ nhớ?)."
	var offset := 0
	while offset < size:
		var end := mini(offset + CHUNK_BYTES, size) - 1
		var want := end - offset + 1
		var body := PackedByteArray()
		var ok := false
		var last := ""
		for attempt in CHUNK_TRIES:
			if attempt > 0:
				await get_tree().create_timer(minf(1.0 * attempt, 6.0)).timeout
			var http := HTTPRequest.new()
			http.accept_gzip = false
			http.timeout = 60.0
			add_child(http)
			if http.request(url, PackedStringArray(["Range: bytes=%d-%d" % [offset, end]])) != OK:
				http.queue_free()
				last = "không bắt đầu được yêu cầu"
				continue
			var st := {"done": false, "res": []}
			http.request_completed.connect(func(r, c, _h, b): st["res"] = [r, c, b]; st["done"] = true)
			while not st["done"]:
				await get_tree().create_timer(0.15).timeout
				_done = before + offset + mini(http.get_downloaded_bytes(), want)
				progress.emit(_done, _total, str(p["name"]))
			http.queue_free()
			var res: Array = st["res"]
			if int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) == 206 and (res[2] as PackedByteArray).size() == want:
				body = res[2]
				ok = true
				break
			last = "mã %d/%d, %d/%d byte" % [int(res[0]), int(res[1]), (res[2] as PackedByteArray).size(), want]
			print("[MuContent] khối %d lỗi (%s) lần %d" % [offset, last, attempt + 1])
		if not ok:
			out.close()
			DirAccess.remove_absolute(part)
			return "Tải gói %s lỗi (%s)." % [p["name"], last]
		out.store_buffer(body)
		offset += want
		_done = before + offset
		progress.emit(_done, _total, str(p["name"]))
	out.close()
	_step = "kiem tra"
	print("[MuContent] %s tai xong t=%d" % [p["name"], Time.get_ticks_msec()])
	if _file_size(part) != size:
		DirAccess.remove_absolute(part)
		return "Gói %s ghi sai kích thước." % p["name"]
	var sha := FileAccess.get_sha256(part)
	_step = "sha"
	print("[MuContent] %s sha xong t=%d" % [p["name"], Time.get_ticks_msec()])
	if sha != str(p["sha256"]):
		DirAccess.remove_absolute(part)
		return "Gói %s sai mã kiểm tra." % p["name"]
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	if DirAccess.rename_absolute(part, dest) != OK:
		return "Không ghi được dữ liệu vào máy (hết bộ nhớ?)."
	_done = before + size
	progress.emit(_done, _total, str(p["name"]))
	return ""

func _save_manifest() -> void:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(manifest))
		f.close()

## Xoá gói cũ không còn trong manifest.
func _cleanup() -> void:
	var keep := {}
	for p: Dictionary in _packs:
		keep[str(p["file"])] = true
	var d := DirAccess.open(CONTENT_DIR)
	if d == null:
		return
	for f in d.get_files():
		if (f.ends_with(".pck") and not keep.has(f)) or f.ends_with(".part"):
			d.remove(f)

# --- Màn chặn ---

func _ensure_gate() -> Node:
	if _gate == null or not is_instance_valid(_gate):
		_gate = load("res://src/boot/MuContentGate.gd").new()
		get_tree().root.add_child(_gate)
	return _gate


# --- Dòng trạng thái tải nền (góc dưới trái) ---
var _hud: Label = null
var _step := ""

func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	_hud = Label.new()
	_hud.position = Vector2(8, 4)
	_hud.add_theme_font_size_override("font_size", 12)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hud)
	add_child(layer)

var _beat := 0.0

func _process(_dt: float) -> void:
	_beat += _dt
	if _beat >= 2.0 and OS.has_feature("web"):
		_beat = 0.0
		# Nhịp tim chẩn đoán: dòng log nginx /t/... cho biết trình duyệt còn sống, FPS và bước tải hiện tại.
		JavaScriptBridge.eval("fetch('/t/%s_%d_%d_%d',{cache:'no-store'}).catch(function(){})" % [_state, _done / 1048576, int(Engine.get_frames_per_second()), Time.get_ticks_msec() / 1000], true)
	if _hud == null:
		return
	if _state == "done":
		_hud.visible = false
		return
	var t := "Tải nội dung: "
	if _state == "error":
		t += "LỖI - " + _error
	elif _total > 0:
		t += "%d/%d MB" % [_done / 1048576, _total / 1048576]
	else:
		t += _state
	_hud.text = t + ("  [" + _step + "]" if _step != "" else "")
