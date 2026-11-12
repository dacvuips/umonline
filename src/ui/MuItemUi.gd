extends Control
class_name MuItemUi

## Lớp trên cùng của giao diện đồ: món đồ đang cầm theo chuột (nhặt lên / đặt xuống như MU)
## và bảng mô tả đồ (tooltip). Túi đồ, cửa hàng, ô trang bị dùng chung qua nhóm "MuItemUi".

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")

var held: Dictionary = {}
var held_from: String = ""        # "inv" | "equip:<slot>"
var held_time: int = 0
var _tip_lines: Array = []
var _cell := 30.0

var _confirm_modal: Control = null
var _confirm_cb: Callable
var _cancel_cb: Callable

static func get_ui(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.get_first_node_in_group("MuItemUi")

func _ready() -> void:
	add_to_group("MuItemUi")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

func hold(it: Dictionary, from: String) -> void:
	held = it
	held_from = from
	held_time = Time.get_ticks_msec()
	queue_redraw()

func drop_held() -> Dictionary:
	var it := held
	held = {}
	held_from = ""
	hide_tip()
	queue_redraw()
	return it

## Hủy cầm đồ và trả vật phẩm về vị trí ban đầu (túi đồ hoặc ô trang bị tương ứng)
func cancel_held(player: MuPlayer) -> void:
	if held.is_empty():
		return
	var it := held
	var from := held_from
	held = {}
	held_from = ""
	hide_tip()
	queue_redraw()
	if player == null:
		return
	if from.begins_with("equip:"):
		var slot := from.substr(6)
		if not player.equipment.has(slot):
			player.equipment[slot] = it
			player.rebuild_model()
			player.inventory_changed.emit()
			return
	if not player.inv_add(it):
		player.inventory.append(it)
	player.inventory_changed.emit()
	if MuAudioManager:
		MuAudioManager.play_item_pickup()

func is_confirm_open() -> bool:
	return _confirm_modal != null and is_instance_valid(_confirm_modal) and _confirm_modal.visible

func show_drop_confirm(it: Dictionary, on_confirm: Callable, on_cancel: Callable) -> void:
	if is_confirm_open():
		close_drop_confirm(false)

	_confirm_cb = on_confirm
	_cancel_cb = on_cancel
	hide_tip()

	_confirm_modal = Control.new()
	_confirm_modal.name = "DropConfirmModal"
	_confirm_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	# Lớp làm tối nền
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_modal.add_child(dim)

	# Khung hộp thoại chuẩn NewUI
	var S := 1.5
	var dw := 230.0 * S
	var dh := 130.0 * S
	var vs := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var v_rect := get_viewport_rect()
		if v_rect.size.x > 0 and v_rect.size.y > 0:
			vs = v_rect.size

	var box := Control.new()
	box.size = Vector2(dw, dh)
	box.position = Vector2((vs.x - dw) * 0.5, (vs.y - dh) * 0.5)
	box.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.texture = MuUiSkinRes.tex("newui_msgbox_back")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(dw, dh)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)

	var border := ReferenceRect.new()
	border.size = Vector2(dw, dh)
	border.border_color = Color(0.7, 0.55, 0.3)
	border.border_width = 1.5
	border.editor_only = false
	box.add_child(border)

	var title := Label.new()
	title.text = "Xác Nhận Vứt Đồ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.position = Vector2(0, 10 * S)
	title.size = Vector2(dw, 20)
	box.add_child(title)

	var msg1 := Label.new()
	msg1.text = "Bạn có chắc chắn muốn vứt bỏ:"
	msg1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg1.add_theme_font_size_override("font_size", 12)
	msg1.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	msg1.position = Vector2(10, 32 * S)
	msg1.size = Vector2(dw - 20, 18)
	box.add_child(msg1)

	var disp_name := MuItemsRes.display_name(it)
	var name_col: Color = MuItemsRes.name_color(it)
	var msg2 := Label.new()
	msg2.text = disp_name
	msg2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg2.add_theme_font_size_override("font_size", 13)
	msg2.add_theme_color_override("font_color", name_col)
	msg2.position = Vector2(10, 48 * S)
	msg2.size = Vector2(dw - 20, 20)
	box.add_child(msg2)

	var msg3 := Label.new()
	msg3.text = "ra ngoài mặt đất không?"
	msg3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg3.add_theme_font_size_override("font_size", 11)
	msg3.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	msg3.position = Vector2(10, 68 * S)
	msg3.size = Vector2(dw - 20, 18)
	box.add_child(msg3)

	# Nút Đồng Ý (Vứt bỏ)
	var btn_ok := Button.new()
	btn_ok.text = "Vứt Bỏ"
	btn_ok.position = Vector2(25 * S, 92 * S)
	btn_ok.size = Vector2(75 * S, 24 * S)
	btn_ok.add_theme_font_size_override("font_size", 12)
	btn_ok.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	btn_ok.pressed.connect(func(): close_drop_confirm(true))
	box.add_child(btn_ok)

	# Nút Hủy Bỏ
	var btn_cancel := Button.new()
	btn_cancel.text = "Hủy Bỏ"
	btn_cancel.position = Vector2(130 * S, 92 * S)
	btn_cancel.size = Vector2(75 * S, 24 * S)
	btn_cancel.add_theme_font_size_override("font_size", 12)
	btn_cancel.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	btn_cancel.pressed.connect(func(): close_drop_confirm(false))
	box.add_child(btn_cancel)

	_confirm_modal.add_child(box)
	add_child(_confirm_modal)

func close_drop_confirm(confirmed: bool) -> void:
	if _confirm_modal != null and is_instance_valid(_confirm_modal):
		_confirm_modal.queue_free()
		_confirm_modal = null
	if confirmed:
		if _confirm_cb.is_valid():
			_confirm_cb.call()
	else:
		if _cancel_cb.is_valid():
			_cancel_cb.call()
	_confirm_cb = Callable()
	_cancel_cb = Callable()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_confirm_open():
				close_drop_confirm(false)
				get_viewport().set_input_as_handled()
			elif not held.is_empty():
				var tree := get_tree()
				var player = tree.get_first_node_in_group("Player") if tree else null
				cancel_held(player)
				get_viewport().set_input_as_handled()

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
	if not held.is_empty() and not is_confirm_open():
		var sz: Vector2i = MuItemsRes.size_of(held)
		var rc := Rect2(mp - Vector2(_cell * 0.5, _cell * 0.5), Vector2(sz) * _cell)
		draw_rect(rc, Color(0.1, 0.18, 0.4, 0.35))
		var t: Texture2D = MuItemIconRes.icon(get_tree(), held)
		if t:
			draw_texture_rect(t, MuItemIconRes.overflow_rect(rc, sz), false)
	if _tip_lines.is_empty() or not held.is_empty() or is_confirm_open():
		return
	var f := get_theme_default_font()
	var fs := 13
	var w := 0.0
	for l in _tip_lines:
		w = maxf(w, f.get_string_size(str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	w += 20
	var h := _tip_lines.size() * (fs + 5) + 12
	var pos := mp + Vector2(18, 10)
	var vs := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var v_rect := get_viewport_rect()
		if v_rect.size.x > 0 and v_rect.size.y > 0:
			vs = v_rect.size
	if pos.x + w > vs.x:
		pos.x = mp.x - w - 10
	if pos.y + h > vs.y:
		pos.y = vs.y - h - 4
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.45, 0.4, 0.3, 0.9), false, 1.0)
	var y := pos.y + 6 + fs
	var line_step := float(fs + 5)
	var ascent := f.get_ascent(fs)
	var descent := f.get_descent(fs)
	var bg_h := minf(ascent + descent + 2.0, line_step - 2.0)
	for l in _tip_lines:
		var s := str(l[0])
		if l.size() >= 3 and l[2] is Color and (l[2] as Color).a > 0.0:
			var bg_top := y - (ascent - descent) * 0.5 - bg_h * 0.5
			draw_rect(Rect2(Vector2(pos.x + 4.0, bg_top), Vector2(w - 8.0, bg_h)), l[2])
		var x := pos.x + (w - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) * 0.5
		draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, l[1])
		y += fs + 5
