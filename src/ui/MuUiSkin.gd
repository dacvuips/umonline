extends RefCounted
class_name MuUiSkin

## Ảnh giao diện gốc của MU (Data/Interface -> assets/mu/ui bằng mu_toolkit.py ui) + khung cửa sổ NewUI

const DIRS := ["res://assets/mu/ui/", "res://assets/textures/ui/"]
## Tỉ lệ so với màn hình gốc 640x480 của MU (cửa sổ 1280x720 -> 1.5)
const S := 1.5

static var _cache: Dictionary = {}

static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D = null
	for d in DIRS:
		for ext: String in [".png", ".jpg"]:
			var p: String = d + name.to_lower() + ext
			if ResourceLoader.exists(p):
				t = load(p)
				break
			# Cũng thử case nguyên bản
			var p_orig: String = d + name + ext
			if ResourceLoader.exists(p_orig):
				t = load(p_orig)
				break
		if t != null:
			break
	_cache[name] = t
	return t

static func atlas_sub(t: Texture2D, rect: Rect2) -> AtlasTexture:
	if t == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = t
	a.region = rect
	return a

static func make_btn_2state(tex_name: String, w: float, h: float, cb: Callable) -> TextureButton:
	var t := tex(tex_name)
	var btn := TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	if t:
		btn.texture_normal = atlas_sub(t, Rect2(0, 0, w, h))
		btn.texture_pressed = atlas_sub(t, Rect2(0, h, w, h))
	btn.pressed.connect(cb)
	return btn

static func font_label(text: String, size: int = 12, color: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _rect(parent: Control, t: Texture2D, pos: Vector2, size: Vector2, fallback: Color) -> void:
	if t:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.position = pos
		r.size = size
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(r)
	else:
		var c := ColorRect.new()
		c.color = fallback
		c.position = pos
		c.size = size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(c)

## Khung cửa sổ NewUI 190 x 429 (đơn vị MU) giống CNewUIMyInventory / CNewUINPCShop:
## nền newui_msgbox_back + newui_item_back01 / back04 (trên) + back02-L/R (hai bên) + back03 (dưới)
static func build_frame(parent: Control, title: String, w: float = 190.0, h: float = 429.0, top_texture: String = "newui_item_back01") -> Label:
	_rect(parent, tex("newui_msgbox_back"), Vector2.ZERO, Vector2(w, h) * S, Color(0.05, 0.04, 0.03, 0.95))
	_rect(parent, tex(top_texture), Vector2.ZERO, Vector2(w, 64) * S, Color(0, 0, 0, 0))
	_rect(parent, tex("newui_item_back02-l"), Vector2(0, 64) * S, Vector2(21, h - 64 - 45) * S, Color(0, 0, 0, 0))
	_rect(parent, tex("newui_item_back02-r"), Vector2(w - 21, 64) * S, Vector2(21, h - 64 - 45) * S, Color(0, 0, 0, 0))
	_rect(parent, tex("newui_item_back03"), Vector2(0, h - 45) * S, Vector2(w, 45) * S, Color(0, 0, 0, 0))
	var l := font_label(title, 15, Color(1.0, 0.85, 0.45))
	l.position = Vector2(0, 11 * S)
	l.size = Vector2(w * S, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	parent.custom_minimum_size = Vector2(w, h) * S
	parent.size = Vector2(w, h) * S
	return l

static func close_button(parent: Control, w: float, cb: Callable, hidden: bool = true) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.text = ""
	b.self_modulate = Color(1, 1, 1, 0)
	var empty_style = StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty_style)
	b.add_theme_stylebox_override("hover", empty_style)
	b.add_theme_stylebox_override("pressed", empty_style)
	b.add_theme_stylebox_override("focus", empty_style)
	b.add_theme_stylebox_override("disabled", empty_style)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "Đóng"
	b.position = Vector2(w - 28, 4) * S
	b.size = Vector2(24, 24) * S
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ------------------------------------------------------------------ các mảnh giao diện dùng chung (đơn vị MU, nhân S)
## Ảnh tại (pos, size) đơn vị MU
static func img(parent: Control, tex_name: String, pos: Vector2, sz: Vector2, modulate_col: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(tex_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos * S
	r.size = sz * S
	r.modulate = modulate_col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

## Nhãn chữ tại (pos, size) đơn vị MU
static func text(parent: Control, t: String, pos: Vector2, sz: Vector2, fs: int = 12, col: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := font_label(t, fs, col)
	l.position = pos * S
	l.size = sz * S
	l.horizontal_alignment = align
	l.clip_text = true
	parent.add_child(l)
	return l

## Khung bảng của theme gốc: góc newui_item_table01(L/R) / 02(L/R) 14x14 + cạnh newui_item_table03(Up/Dw/L/R), nền tối
static func table_box(parent: Control, rect: Rect2, fill: Color = Color(0, 0, 0, 0.6)) -> void:
	var p := rect.position
	var s := rect.size
	var bg := ColorRect.new()
	bg.color = fill
	bg.position = (p + Vector2(3, 3)) * S
	bg.size = (s - Vector2(6, 6)) * S
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	img(parent, "newui_item_table03(up)", p + Vector2(14, 0), Vector2(s.x - 28, 14))
	img(parent, "newui_item_table03(dw)", p + Vector2(14, s.y - 14), Vector2(s.x - 28, 14))
	img(parent, "newui_item_table03(l)", p + Vector2(0, 14), Vector2(14, s.y - 28))
	img(parent, "newui_item_table03(r)", p + Vector2(s.x - 14, 14), Vector2(14, s.y - 28))
	img(parent, "newui_item_table01(l)", p, Vector2(14, 14))
	img(parent, "newui_item_table01(r)", p + Vector2(s.x - 14, 0), Vector2(14, 14))
	img(parent, "newui_item_table02(l)", p + Vector2(0, s.y - 14), Vector2(14, 14))
	img(parent, "newui_item_table02(r)", p + Vector2(s.x - 14, s.y - 14), Vector2(14, 14))

## Nút chữ trên ảnh 3 trạng thái (newui_btn_empty 108x29, newui_btn_empty_small 64x29...)
static func text_button(parent: Control, label: String, pos: Vector2, sz: Vector2, cb: Callable, tex_name: String = "newui_btn_empty_small", frame: Vector2 = Vector2(64, 29), fs: int = 11) -> TextureButton:
	var t := tex(tex_name)
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.focus_mode = Control.FOCUS_NONE
	if t:
		b.texture_normal = atlas_sub(t, Rect2(Vector2(0, 0), frame))
		b.texture_hover = atlas_sub(t, Rect2(Vector2(0, frame.y), frame))
		b.texture_pressed = atlas_sub(t, Rect2(Vector2(0, frame.y * 2), frame))
		b.texture_disabled = b.texture_normal
	b.position = pos * S
	b.size = sz * S
	var l := font_label(label, fs, Color.WHITE)
	l.name = "Label"
	l.size = b.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.pressed.connect(func():
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		cb.call())
	parent.add_child(b)
	return b

## Bảng màu dấu guild (Guild/GuildMarkPalette.cpp) — chỉ số 0 = trong suốt
const GUILD_PALETTE := [Color8(0, 0, 0, 0), Color8(0, 0, 0), Color8(128, 128, 128), Color8(255, 255, 255),
	Color8(255, 0, 0), Color8(255, 128, 0), Color8(255, 255, 0), Color8(128, 255, 0), Color8(0, 255, 0),
	Color8(0, 255, 128), Color8(0, 255, 255), Color8(0, 128, 255), Color8(0, 0, 255), Color8(128, 0, 255),
	Color8(255, 0, 255), Color8(255, 0, 128)]

## Dấu guild 8x8 (64 chỉ số màu) vẽ trong một Control
static func guild_mark(parent: Control, mark: Array, pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.position = pos * S
	c.size = sz * S
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("mark", mark)
	c.draw.connect(func():
		var m: Array = c.get_meta("mark", [])
		var cs := c.size / 8.0
		for i in mini(64, m.size()):
			var idx := int(m[i])
			if idx > 0 and idx < GUILD_PALETTE.size():
				c.draw_rect(Rect2(Vector2(i % 8, i / 8) * cs, cs), GUILD_PALETTE[idx]))
	parent.add_child(c)
	return c

## Khung cửa sổ "docked" 190 x 429 có nút thoát ở góc
static func docked_window(win: Control, title: String, close_cb: Callable) -> Label:
	win.set_anchors_preset(Control.PRESET_TOP_LEFT)
	win.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := build_frame(win, title)
	close_button(win, 190.0, close_cb)
	var ex := make_btn_2state("newui_exit_00", 36, 29, close_cb)
	ex.position = Vector2(13, 391) * S
	ex.size = Vector2(36, 29) * S
	ex.tooltip_text = "Đóng"
	win.add_child(ex)
	return l
