extends CanvasLayer
## Màn chặn "Đang tải dữ liệu game" — hiện khi người chơi đi tiếp nhưng gói cần thiết chưa tải xong.
## Dựng hoàn toàn bằng mã: thẻ kính tối bo góc, logo nhỏ, thanh tiến độ vàng mảnh, % lớn.
## Chỉ dùng tài nguyên nằm trong core (logo), không phụ thuộc gói tải ngầm.

const LOGO_PATH := "res://assets/textures/ui/mu_logo_small.png"
const GOLD := Color(0.96, 0.74, 0.27)
const GOLD_SOFT := Color(0.96, 0.74, 0.27, 0.55)
const TEXT_DIM := Color(0.72, 0.75, 0.82)

var _root: Control
var _card: PanelContainer
var _title: Label
var _hint: Label
var _percent: Label
var _detail: Label
var _bar: ProgressBar
var _retry: Button
var _speed_t := 0
var _speed_b := 0
var _speed := 0.0
var _shown_value := 0.0
var _dots_t := 0.0

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Nền phủ tối + chặn bấm xuyên xuống scene dưới.
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_root = dim

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(560, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.075, 0.085, 0.12, 0.94)
	card_style.set_corner_radius_all(20)
	card_style.set_border_width_all(1)
	card_style.border_color = Color(1, 1, 1, 0.09)
	card_style.shadow_color = Color(0, 0, 0, 0.55)
	card_style.shadow_size = 28
	card_style.content_margin_left = 40
	card_style.content_margin_right = 40
	card_style.content_margin_top = 30
	card_style.content_margin_bottom = 34
	_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_card.add_child(box)

	# Logo nhỏ ở đầu thẻ.
	if ResourceLoader.exists(LOGO_PATH):
		var logo := TextureRect.new()
		logo.texture = load(LOGO_PATH)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(0, 84)
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		box.add_child(logo)

	_title = Label.new()
	_title.text = "Đang tải dữ liệu game"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	box.add_child(_title)

	_hint = Label.new()
	_hint.text = "Game chỉ tải dữ liệu 1 lần duy nhất, vui lòng chờ. Những lần sau vào game ngay."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", TEXT_DIM)
	box.add_child(_hint)

	box.add_child(_spacer(6))

	# Thanh tiến độ mảnh, bo tròn, màu vàng.
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.max_value = 1000
	_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.09)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(5)
	fill.shadow_color = GOLD_SOFT
	fill.shadow_size = 8
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)

	# Hàng dưới: chi tiết bên trái, % bên phải.
	var row := HBoxContainer.new()
	box.add_child(row)
	_detail = Label.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.add_theme_color_override("font_color", TEXT_DIM)
	row.add_child(_detail)
	_percent = Label.new()
	_percent.text = "0%"
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent.add_theme_font_size_override("font_size", 20)
	_percent.add_theme_color_override("font_color", GOLD)
	row.add_child(_percent)

	_retry = Button.new()
	_retry.text = "Thử lại"
	_retry.visible = false
	_retry.custom_minimum_size = Vector2(0, 40)
	_retry.add_theme_font_size_override("font_size", 15)
	_retry.add_theme_color_override("font_color", Color(0.1, 0.08, 0.03))
	_retry.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.03))
	_retry.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.03))
	_retry.add_theme_stylebox_override("normal", _btn_style(GOLD))
	_retry.add_theme_stylebox_override("hover", _btn_style(GOLD.lightened(0.15)))
	_retry.add_theme_stylebox_override("pressed", _btn_style(GOLD.darkened(0.15)))
	_retry.pressed.connect(func() -> void:
		_retry.visible = false
		_title.text = "Đang tải dữ liệu game"
		MuContent.retry())
	box.add_child(_retry)

	visible = false

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _btn_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(10)
	s.content_margin_left = 20
	s.content_margin_right = 20
	return s

func open(_tier: int) -> void:
	visible = true
	_speed_t = Time.get_ticks_msec()
	_speed_b = MuContent.get_progress().x
	_shown_value = 0.0
	# Hiện dần cho mượt.
	_root.modulate.a = 0.0
	_card.scale = Vector2(0.97, 0.97)
	_card.pivot_offset = _card.size / 2.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "modulate:a", 1.0, 0.25)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3)
	DisplayServer.screen_set_keep_on(true)

func close() -> void:
	visible = false
	DisplayServer.screen_set_keep_on(false)

func _process(dt: float) -> void:
	if not visible:
		return
	if MuContent.get_state() == "error":
		_title.text = "Tải dữ liệu bị gián đoạn"
		_hint.text = MuContent.get_error()
		_retry.visible = true
		return
	_dots_t += dt
	_title.text = "Đang tải dữ liệu game" + ".".repeat(int(_dots_t * 2.0) % 4)
	_hint.text = "Game chỉ tải dữ liệu 1 lần duy nhất, vui lòng chờ. Những lần sau vào game ngay."

	var p := MuContent.get_progress()
	var target := 1000.0 * float(p.x) / float(maxi(p.y, 1))
	_shown_value = lerpf(_shown_value, target, clampf(dt * 8.0, 0.0, 1.0))   # thanh chạy mượt, không giật theo từng khối
	_bar.value = _shown_value
	_percent.text = "%d%%" % int(round(_shown_value / 10.0))

	var now := Time.get_ticks_msec()
	if now - _speed_t >= 1000:
		_speed = float(p.x - _speed_b) / ((now - _speed_t) / 1000.0)
		_speed_t = now
		_speed_b = p.x
	var left := ""
	if _speed > 1.0 and p.y > p.x:
		var secs := int((p.y - p.x) / _speed)
		left = "  ·  còn khoảng %s" % (("%d giây" % secs) if secs < 90 else ("%d phút" % int(ceil(secs / 60.0))))
	_detail.text = "%.0f / %.0f MB  ·  %.1f MB/s%s" % [p.x / 1048576.0, p.y / 1048576.0, _speed / 1048576.0, left]
