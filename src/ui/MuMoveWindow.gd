extends Control
class_name MuMoveWindow

## Bảng dịch chuyển (phím M) giống cửa sổ Move của MU: danh sách điểm đến lấy từ server OpenMU
## (assets/mu/warps.json: tên, cấp yêu cầu, Zen) + mọi bản đồ đã chuyển (assets/mu/maps/maps_index.json).
## Bấm vào một dòng -> nhảy tới bản đồ đó (đúng vùng cổng đến của MU).

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")
const S := 1.5
const W := 230.0
const H := 380.0

var player: MuPlayer = null
var _list: VBoxContainer

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	MuUiSkinRes.build_frame(self, "Dịch Chuyển (M)", W, H)
	MuUiSkinRes.close_button(self, W, func(): visible = false)
	var head := HBoxContainer.new()
	head.position = Vector2(16, 40) * S
	head.size = Vector2(W - 32, 16) * S
	add_child(head)
	for t in [["Bản đồ", 120], ["Cấp", 35], ["Zen", 45]]:
		var l := MuUiSkinRes.font_label(t[0], 12, Color(1, 0.8, 0.4))
		l.custom_minimum_size = Vector2(t[1], 0) * S
		head.add_child(l)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 58) * S
	scroll.size = Vector2(W - 28, H - 58 - 40) * S
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var vs := get_viewport_rect().size
	position = Vector2((vs.x - W * S) * 0.5, maxf(0.0, (vs.y - H * S) * 0.5))

func setup(p: MuPlayer) -> void:
	player = p

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_M:
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and k and k.pressed and k.keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()

func toggle() -> void:
	visible = not visible
	if visible:
		_fill()

static func _read(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(p))

func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var idx = _read("res://assets/mu/maps/maps_index.json")
	if not (idx is Dictionary):
		idx = {}
	var warps = _read("res://assets/mu/warps.json")
	var seen := {}
	if warps is Array:
		for w in warps:
			var world := int(w.get("world", 0))
			if world != 1 and not idx.has(str(world)):
				continue
			seen[world] = true
			_add_row(str(w.get("name", "")), int(w.get("level", 0)), int(w.get("cost", 0)), world,
				Rect2i(int(w["x1"]), int(w["y1"]), int(w["x2"]) - int(w["x1"]), int(w["y2"]) - int(w["y1"])))
	# các bản đồ không có trong bảng Move gốc (sự kiện, thành...)
	var keys: Array = idx.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	var first := true
	for k in keys:
		var n := int(k)
		if seen.has(n) or int(idx[k].get("objects", 0)) == 0 and n != 1:
			continue
		if first:
			var sep := MuUiSkinRes.font_label("— Bản đồ khác —", 11, Color(0.7, 0.7, 0.7))
			_list.add_child(sep)
			first = false
		var sp: Array = idx[k].get("spawn", [128, 128])
		_add_row(str(idx[k].get("name", "World %d" % n)), 0, 0, n, Rect2i(int(sp[0]), int(sp[1]), 0, 0))

func _add_row(name: String, level: int, cost: int, world: int, area: Rect2i) -> void:
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 15) * S
	var cur := MuTerrain.world_id == world
	var lvl_ok := player == null or player.level >= level
	var col := Color(1, 0.85, 0.3) if cur else (Color(0.9, 0.9, 0.9) if lvl_ok else Color(0.85, 0.45, 0.4))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(h)
	for t in [[name, 120], [str(level) if level > 0 else "-", 35], [MuItemsRes.format_zen(cost) if cost > 0 else "-", 45]]:
		var l := MuUiSkinRes.font_label(t[0], 12, col)
		l.custom_minimum_size = Vector2(t[1], 0) * S
		h.add_child(l)
	b.pressed.connect(_warp.bind(world, area, cost))
	_list.add_child(b)

func _warp(world: int, area: Rect2i, cost: int) -> void:
	if not MuTerrain.has_map(world):
		return
	# bản đồ không có trong bảng Move: dùng cổng xuất hiện (spawn gate) của server nếu có
	if area.size == Vector2i.ZERO:
		var sd = _read("res://assets/mu/spawns.json")
		if sd is Dictionary and sd.has(str(world)) and sd[str(world)].get("spawn_gate") is Dictionary:
			var g: Dictionary = sd[str(world)]["spawn_gate"]
			area = Rect2i(int(g["x1"]), int(g["y1"]), int(g["x2"]) - int(g["x1"]), int(g["y2"]) - int(g["y1"]))
	# điểm đến: ô ngẫu nhiên trong vùng cổng (Gate) như server MU
	var spawn := area.position + Vector2i(randi_range(0, maxi(area.size.x, 0)), randi_range(0, maxi(area.size.y, 0)))
	if player and cost > 0 and player.zen >= cost:
		player.add_zen(-cost)
	visible = false
	MuTerrain.change_world(world, spawn)
	get_tree().call_deferred("reload_current_scene")

func _gui_input(_event: InputEvent) -> void:
	accept_event()
