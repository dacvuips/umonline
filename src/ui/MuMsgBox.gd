extends Control
class_name MuMsgBox

## Hộp thoại chuẩn CCommonMessageBox của MU (generic_confirm_dialog trong Source):
##   rộng 230, mép trên ở y = 100 của khung 640x480, ảnh newui_msgbox_top (230x67) + middle (230x15) xếp chồng
##   + bottom (230x50), nền newui_msgbox_back, các dòng chữ từ y+35 cách nhau 15,
##   nút OK (newui_button_ok, x = 30) và Cancel (newui_button_cancel, x = 146), cách đáy 20 — mỗi nút 54x30, 3 trạng thái.
## Dùng: MuMsgBox.open(parent, [["dòng 1"], ["dòng 2", Color.RED, true]], on_ok, on_cancel, {"input": true})

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const S := 1.5
const W := 230.0
const LINE_H := 15.0

signal closed(ok: bool)

## Hộp thoại đang gọi callback (để on_ok đọc ô nhập / keep_open())
static var active: MuMsgBox = null

var _on_ok: Callable
var _on_cancel: Callable
var _input: LineEdit = null
var _keep_open := false

## lines: mảng [text, color?, bold?] ; opts: {"input": bool, "max_length": int, "numeric": bool, "cancel": bool}
static func open(parent: Node, lines: Array, on_ok: Callable = Callable(), on_cancel: Callable = Callable(), opts: Dictionary = {}) -> MuMsgBox:
	var box := MuMsgBox.new()
	box._on_ok = on_ok
	box._on_cancel = on_cancel
	parent.add_child(box)
	box._build(lines, opts)
	return box

func _build(lines: Array, opts: Dictionary) -> void:
	name = "MuMsgBox"
	z_index = 90
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # hộp thoại MU là modal
	var has_input := bool(opts.get("input", false))
	var show_cancel := bool(opts.get("cancel", true))
	# Cao 117 cho tối đa 2 dòng, mỗi dòng thêm 15 ; ô nhập chiếm thêm 2 hàng
	var rows := lines.size() + (2 if has_input else 0)
	var h := maxf(117.0, 35.0 + rows * LINE_H + 70.0)
	var vs := get_viewport_rect().size
	var canvas_top := maxf(0.0, (vs.y - 480.0 * S) * 0.5)
	var panel := Control.new()
	panel.position = Vector2((vs.x - W * S) * 0.5, canvas_top + 100.0 * S)
	panel.size = Vector2(W, h) * S
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	_tex(panel, "newui_msgbox_back", Vector2(4, 5), Vector2(W - 8, h - 10))
	_tex(panel, "newui_msgbox_top", Vector2.ZERO, Vector2(W, 67))
	if h - 117.0 > 0.0:
		_tex(panel, "newui_msgbox_middle", Vector2(0, 67), Vector2(W, h - 117.0))
	_tex(panel, "newui_msgbox_bottom", Vector2(0, h - 50), Vector2(W, 50))
	var y := 35.0
	for l in lines:
		var arr: Array = l if l is Array else [str(l)]
		var col: Color = arr[1] if arr.size() > 1 and arr[1] is Color else Color(1, 1, 1)
		var lb := MuUiSkinRes.font_label(str(arr[0]), 12, col)
		if arr.size() > 2 and bool(arr[2]):
			lb.add_theme_constant_override("outline_size", 4)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.position = Vector2(8, y) * S
		lb.size = Vector2(W - 16, LINE_H) * S
		panel.add_child(lb)
		y += LINE_H
	if has_input:
		_input = LineEdit.new()
		_input.max_length = int(opts.get("max_length", 8))
		_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_input.position = Vector2(55, y + 4) * S
		_input.size = Vector2(120, 18) * S
		_input.add_theme_font_size_override("font_size", 13)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.85)
		sb.border_color = Color(0.45, 0.4, 0.3)
		sb.set_border_width_all(1)
		_input.add_theme_stylebox_override("normal", sb)
		_input.add_theme_stylebox_override("focus", sb)
		if bool(opts.get("numeric", false)):
			_input.text_changed.connect(_numeric_only)
		_input.text_submitted.connect(func(_t): _press(true))
		panel.add_child(_input)
		_input.call_deferred("grab_focus")
	var by := h - 20.0 - 30.0
	var ok := _button(panel, "newui_button_ok", Vector2(30 if show_cancel else 88, by))
	ok.pressed.connect(_press.bind(true))
	if show_cancel:
		var cancel := _button(panel, "newui_button_cancel", Vector2(146, by))
		cancel.pressed.connect(_press.bind(false))

func _tex(parent: Control, tex_name: String, pos: Vector2, sz: Vector2) -> void:
	var r := TextureRect.new()
	r.texture = MuUiSkinRes.tex(tex_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos * S
	r.size = sz * S
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _button(parent: Control, tex_name: String, pos: Vector2) -> TextureButton:
	var t := MuUiSkinRes.tex(tex_name)
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.focus_mode = Control.FOCUS_NONE
	if t:
		b.texture_normal = MuUiSkinRes.atlas_sub(t, Rect2(0, 0, 54, 30))
		b.texture_hover = MuUiSkinRes.atlas_sub(t, Rect2(0, 30, 54, 30))
		b.texture_pressed = MuUiSkinRes.atlas_sub(t, Rect2(0, 60, 54, 30))
	b.position = pos * S
	b.size = Vector2(54, 30) * S
	parent.add_child(b)
	return b

func _numeric_only(t: String) -> void:
	var f := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			f += ch
	if f != t:
		var c := _input.caret_column
		_input.text = f
		_input.caret_column = mini(c, f.length())

## Văn bản trong ô nhập (rỗng nếu không có ô nhập)
func get_input_text() -> String:
	return _input.text.strip_edges() if _input else ""

## Gọi trong on_ok để giữ hộp thoại mở (GenericConfirmDialog::KeepOpen)
func keep_open() -> void:
	_keep_open = true

func _press(ok: bool) -> void:
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	_keep_open = false
	active = self
	if ok and _on_ok.is_valid():
		_on_ok.call()
	elif not ok and _on_cancel.is_valid():
		_on_cancel.call()
	active = null
	if _keep_open:
		return
	closed.emit(ok)
	queue_free()

func dismiss() -> void:
	queue_free()

func _gui_input(event: InputEvent) -> void:
	accept_event()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.keycode == KEY_ESCAPE:
			_press(false)
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			_press(true)
			get_viewport().set_input_as_handled()
