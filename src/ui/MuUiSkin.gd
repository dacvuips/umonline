extends RefCounted
class_name MuUiSkin

## Ảnh giao diện gốc của MU (Data/Interface -> assets/mu/ui bằng mu_toolkit.py ui) + khung cửa sổ NewUI

const DIR := "res://assets/mu/ui/"
## Tỉ lệ so với màn hình gốc 640x480 của MU (cửa sổ 1280x720 -> 1.5)
const S := 1.5

static var _cache: Dictionary = {}

static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D = null
	for ext: String in [".png", ".jpg"]:
		var p: String = DIR + name.to_lower() + ext
		if ResourceLoader.exists(p):
			t = load(p)
			break
	_cache[name] = t
	return t

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
## nền newui_msgbox_back + newui_item_back01 (trên) + back02-L/R (hai bên) + back03 (dưới)
static func build_frame(parent: Control, title: String, w: float = 190.0, h: float = 429.0) -> Label:
	_rect(parent, tex("newui_msgbox_back"), Vector2.ZERO, Vector2(w, h) * S, Color(0.05, 0.04, 0.03, 0.95))
	_rect(parent, tex("newui_item_back01"), Vector2.ZERO, Vector2(w, 64) * S, Color(0, 0, 0, 0))
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

static func close_button(parent: Control, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.text = "X"
	b.add_theme_color_override("font_color", Color(0.9, 0.75, 0.45))
	b.position = Vector2(w - 26, 7) * S
	b.size = Vector2(20, 20) * S
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
