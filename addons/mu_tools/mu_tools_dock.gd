@tool
extends VBoxContainer

## Dock "MU Tools": chạy tools/mu_toolkit.py ngay trong Godot, xem log, tự quét lại tài nguyên khi xong.

const FOLDERS := ["Player", "Monster", "NPC", "Item", "Skill", "Effect"]
const VIEWER_SCENE := "res://src/tools/MuModelViewer.tscn"

var _data_edit: LineEdit
var _folder_opt: OptionButton
var _map_edit: LineEdit
var _log: RichTextLabel
var _status: Label
var _buttons: Array[Button] = []
var _thread: Thread
var _pid := -1
var _running := false
var _bake_after := false

func _ready() -> void:
	custom_minimum_size = Vector2(260, 300)
	var title := Label.new()
	title.text = "MU Toolkit — chuyển dữ liệu client gốc"
	add_child(title)

	var row := HBoxContainer.new()
	add_child(row)
	var l := Label.new()
	l.text = "Client\\Data:"
	row.add_child(l)
	_data_edit = LineEdit.new()
	_data_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_data_edit.text = _read_cfg().get("data_root", _default_data_root())
	row.add_child(_data_edit)
	var save := Button.new()
	save.text = "Lưu"
	save.pressed.connect(_save_cfg)
	row.add_child(save)

	_add_button("Chuyển TẤT CẢ (model + bản đồ + server + ảnh đồ)", func():
		_bake_after = true
		_run(["all"]))
	var r3 := HBoxContainer.new()
	add_child(r3)
	var b3 := _add_button("Chuyển bản đồ", func(): _run(["maps"] + ([_map_edit.text.strip_edges()] if _map_edit.text.strip_edges() != "" else [])), r3)
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_edit = LineEdit.new()
	_map_edit.placeholder_text = "số map, vd 3,4 (trống = tất cả)"
	_map_edit.custom_minimum_size = Vector2(150, 0)
	r3.add_child(_map_edit)
	var r2 := HBoxContainer.new()
	add_child(r2)
	_folder_opt = OptionButton.new()
	for f in FOLDERS:
		_folder_opt.add_item(f)
	r2.add_child(_folder_opt)
	var b2 := _add_button("Chuyển thư mục này", func(): _run(["models", FOLDERS[_folder_opt.selected]]), r2)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button("Chuyển LẠI từ đầu (ghi đè)", func(): _run(["all", "--force"]))
	_add_button("Nướng ẢNH TẤT CẢ ĐỒ (icons túi đồ / cửa hàng)", _bake_icons)
	_add_button("Kiểm tra dữ liệu còn thiếu", func(): _run(["check"]))
	_add_button("Quét lại tài nguyên (import)", _rescan)
	_add_button("Mở Model Viewer (F6)", _open_viewer)
	var stop := Button.new()
	stop.text = "Dừng"
	stop.pressed.connect(_stop)
	add_child(stop)

	_status = Label.new()
	_status.text = "Sẵn sàng."
	add_child(_status)
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 220)
	add_child(_log)

func _add_button(text: String, cb: Callable, parent: Node = self) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	_buttons.append(b)
	return b

# ------------------------------------------------------------------ cấu hình
func _project_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")

func _tools_dir() -> String:
	return _project_dir() + "/tools"

func _default_data_root() -> String:
	return _project_dir().get_base_dir() + "/Client/Data"

func _read_cfg() -> Dictionary:
	var p := _tools_dir() + "/mu_toolkit.json"
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary:
			return d
	return {}

func _save_cfg() -> void:
	var d := _read_cfg()
	d["data_root"] = _data_edit.text.strip_edges()
	d["mugodot"] = _project_dir()
	var f := FileAccess.open(_tools_dir() + "/mu_toolkit.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, " "))
		_append("[color=green]Đã lưu đường dẫn: %s[/color]" % d["data_root"])

# ------------------------------------------------------------------ chạy python
func _python() -> Array:
	# Windows: ưu tiên "py -3", sau đó python / python3
	for cand in [["py", ["-3"]], ["python", []], ["python3", []]]:
		var out := []
		if OS.execute(cand[0], cand[1] + ["--version"], out, true) == 0:
			return cand
	return []

func _run(args: Array) -> void:
	if _running:
		_append("[color=orange]Đang chạy, đợi xong hoặc bấm Dừng.[/color]")
		return
	_save_cfg()
	var py := _python()
	if py.is_empty():
		_append("[color=red]Không tìm thấy Python 3. Cài từ python.org (tick 'Add to PATH') rồi mở lại Godot.[/color]")
		return
	var full: Array = py[1] + ["-u", _tools_dir() + "/mu_toolkit.py"] + args
	_append("[b]> %s %s[/b]" % [py[0], " ".join(full)])
	var info := OS.execute_with_pipe(py[0], full)
	if info.is_empty():
		_append("[color=red]Không chạy được Python.[/color]")
		return
	_pid = int(info.get("pid", -1))
	_set_running(true)
	_thread = Thread.new()
	_thread.start(_reader.bind(info))

func _reader(info: Dictionary) -> void:
	var out: FileAccess = info["stdio"]
	var err: FileAccess = info["stderr"]
	while true:
		var line := out.get_line()
		if out.get_error() != OK and line == "":
			break
		call_deferred("_append", line.replace("[", "[lb]"))
	while err:
		var e := err.get_line()
		if err.get_error() != OK and e == "":
			break
		call_deferred("_append", "[color=red]%s[/color]" % e.replace("[", "[lb]"))
	call_deferred("_on_finished")

func _on_finished() -> void:
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	_set_running(false)
	_append("[color=green]Xong.[/color] Đang quét lại tài nguyên...")
	_rescan()
	if _bake_after:
		_bake_after = false
		await get_tree().create_timer(2.0).timeout
		_bake_icons()

func _stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
		_append("[color=orange]Đã dừng.[/color]")

func _set_running(v: bool) -> void:
	_running = v
	_status.text = "Đang chạy..." if v else "Sẵn sàng."
	for b in _buttons:
		b.disabled = v

func _append(t: String) -> void:
	if _log:
		_log.append_text(t + "\n")

func _rescan() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs and not fs.is_scanning():
		fs.scan()

func _open_viewer() -> void:
	if ResourceLoader.exists(VIEWER_SCENE):
		EditorInterface.play_custom_scene(VIEWER_SCENE)
	else:
		_append("[color=red]Không thấy %s[/color]" % VIEWER_SCENE)

func _exit_tree() -> void:
	_stop()
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

## Nướng ảnh mọi món đồ ra assets/mu/icons (dùng đúng góc xoay / tỉ lệ / anchor trong Items/Models)
func _bake_icons() -> void:
	if _running:
		return
	_set_running(true)
	_append("[b]Nướng ảnh đồ...[/b] (vài phút, đừng đóng Godot)")
	var IconRes = load("res://src/ui/MuItemIcon.gd")
	var CatRes = load("res://src/mu/MuCatalog.gd")
	var ModelRes = load("res://src/mu/MuModel.gd")
	ModelRes.reset_cache()
	CatRes.item_models.clear()
	CatRes._loaded = false
	var n: int = await IconRes.bake_all(get_tree(), func(d, t): if d % 50 == 0: _status.text = "Nướng ảnh %d/%d" % [d, t])
	_set_running(false)
	_append("[color=green]Đã lưu %d ảnh đồ vào assets/mu/icons[/color]" % n)
	_rescan()
