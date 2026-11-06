extends Control
class_name MuItemUi

## Lớp trên cùng của giao diện đồ: món đồ đang cầm theo chuột (nhặt lên / đặt xuống như MU)
## và bảng mô tả đồ (tooltip). Túi đồ, cửa hàng, ô trang bị dùng chung qua nhóm "MuItemUi".

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")

var held: Dictionary = {}
var held_from: String = ""        # "inv" | "equip:<slot>"
var _tip_lines: Array = []
var _cell := 30.0

static func get_ui(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("MuItemUi")

func _ready() -> void:
	add_to_group("MuItemUi")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

func hold(it: Dictionary, from: String) -> void:
	held = it
	held_from = from
	queue_redraw()

func drop_held() -> Dictionary:
	var it := held
	held = {}
	held_from = ""
	queue_redraw()
	return it

func show_tip(lines: Array) -> void:
	_tip_lines = lines
	queue_redraw()

func hide_tip() -> void:
	_tip_lines = []
	queue_redraw()

func _process(_d: float) -> void:
	if not held.is_empty() or not _tip_lines.is_empty():
		queue_redraw()

func _draw() -> void:
	var mp := get_local_mouse_position()
	if not held.is_empty():
		var sz: Vector2i = MuItemsRes.size_of(held)
		var rc := Rect2(mp - Vector2(_cell * 0.5, _cell * 0.5), Vector2(sz) * _cell)
		draw_rect(rc, Color(0.1, 0.18, 0.4, 0.35))
		var t: Texture2D = MuItemIconRes.icon(get_tree(), held)
		if t:
			draw_texture_rect(t, MuItemIconRes.overflow_rect(rc, sz), false)
	if _tip_lines.is_empty() or not held.is_empty():
		return
	var f := get_theme_default_font()
	var fs := 13
	var w := 0.0
	for l in _tip_lines:
		w = maxf(w, f.get_string_size(str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	w += 20
	var h := _tip_lines.size() * (fs + 5) + 12
	var pos := mp + Vector2(18, 10)
	var vs := get_viewport_rect().size
	if pos.x + w > vs.x:
		pos.x = mp.x - w - 10
	if pos.y + h > vs.y:
		pos.y = vs.y - h - 4
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.45, 0.4, 0.3, 0.9), false, 1.0)
	var y := pos.y + 6 + fs
	for l in _tip_lines:
		var s := str(l[0])
		var x := pos.x + (w - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) * 0.5
		draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, l[1])
		y += fs + 5
