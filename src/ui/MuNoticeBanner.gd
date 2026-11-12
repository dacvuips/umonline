extends Control
class_name MuNoticeBanner

## Hàng Chữ Thông Báo Màu Vàng Chạy Trên Đầu Màn Hình (Golden Server Marquee Notice)
## - Không nền, không viền: Dòng chữ trôi tự do trực tiếp trên đỉnh màn hình
## - Không in đậm chữ: Toàn bộ hiển thị font chữ thường (regular)
## - Tất cả chữ đều là màu vàng: Đồng nhất màu vàng hoàng kim MU kèm viền đen rõ nét
## - Cuộn đều đặn từ phải sang trái xuyên suốt màn hình

var _lbl: RichTextLabel
var _queue: Array[String] = []
var _is_scrolling: bool = false
var _current_tween: Tween = null
var _fade_tween: Tween = null

const BAR_HEIGHT: float = 28.0
const SCROLL_SPEED: float = 135.0 # Tốc độ chạy chữ: 135 pixel/giây (vừa tầm mắt người chơi)

func _ready() -> void:
	name = "MuNoticeBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true # Giới hạn không cho chữ chạy ra ngoài khung khoanh đỏ
	z_index = 80 # Nổi trên các cửa sổ giao diện khác

	anchors_preset = Control.PRESET_TOP_WIDE
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	_apply_layout()
	modulate.a = 0.0
	visible = false

	_setup_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _apply_layout() -> void:
	var vp_w := get_viewport_rect().size.x
	if vp_w <= 0.0:
		vp_w = 1280.0
	# Giới hạn đúng vị trí khung khoanh đỏ (bên dưới hàng nút Menu & bên phải thanh thông tin nhân vật, trước Mini Map)
	offset_left = 380.0
	offset_right = -200.0
	offset_top = 68.0
	offset_bottom = 68.0 + BAR_HEIGHT
	custom_minimum_size = Vector2(200.0, BAR_HEIGHT)
	size = Vector2(maxf(200.0, vp_w - 580.0), BAR_HEIGHT)

func _on_viewport_resized() -> void:
	_apply_layout()

func _setup_ui() -> void:
	# Nhãn hiển thị chữ chạy (Marquee Label) - Hoàn toàn KHÔNG nền, KHÔNG viền
	_lbl = RichTextLabel.new()
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl.bbcode_enabled = true
	_lbl.scroll_active = false
	_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_lbl.fit_content = false
	_lbl.clip_contents = false
	_lbl.position = Vector2(size.x, 3.0)
	_lbl.size = Vector2(2500, BAR_HEIGHT)

	# Thiết lập toàn bộ chữ màu vàng hoàng kim MU, chữ thường (không in đậm), viền đen sắc nét
	_lbl.add_theme_font_size_override("normal_font_size", 15)
	_lbl.add_theme_color_override("default_color", Color(1.0, 0.88, 0.15)) # Vàng hoàng kim MU
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1)) # Viền đen rõ nét
	_lbl.add_theme_constant_override("outline_size", 4)
	add_child(_lbl)

## Đưa thông báo vào hàng đợi chạy chữ trên đầu màn hình
func post_notice(raw_text: String, _duration_ignore: float = 5.0) -> void:
	_queue.append(raw_text)
	if not _is_scrolling:
		_start_next_scroll()

## Bắt đầu lượt chạy chữ tiếp theo
func _start_next_scroll() -> void:
	if _queue.is_empty():
		_is_scrolling = false
		_fade_out()
		return

	_is_scrolling = true
	var raw_text: String = _queue.pop_front()

	# Lọc bỏ in đậm ([b], [/b]), bỏ màu sắc cũ ([color=...], [/color]), ép 100% chữ thành màu vàng
	var formatted_text: String = _clean_and_colorize_yellow(raw_text)

	_lbl.text = formatted_text
	visible = true

	# Cập nhật kích thước khung và đo độ dài dòng chữ
	_apply_layout()
	var box_w: float = size.x

	var text_width := _measure_text_width(formatted_text)
	_lbl.size = Vector2(text_width + 100.0, BAR_HEIGHT)

	# Vị trí xuất phát ở mép phải của khung (bị cắt ẩn bởi clip_contents cho đến khi trôi vào khung)
	var start_x: float = box_w + 10.0
	# Vị trí kết thúc khi trôi khuất hoàn toàn qua mép trái của khung
	var end_x: float = -text_width - 20.0
	var distance: float = start_x - end_x

	# Tính thời gian chạy theo tốc độ pixel/giây đều đặn
	var travel_duration: float = maxf(4.0, distance / SCROLL_SPEED)

	_lbl.position = Vector2(start_x, 3.0)

	# Fade in mượt mà
	_fade_in()

	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	# Chạy chữ đều đặn từ phải qua trái (TRANS_LINEAR)
	_current_tween = create_tween()
	_current_tween.tween_property(_lbl, "position:x", end_x, travel_duration).from(start_x).set_trans(Tween.TRANS_LINEAR)
	_current_tween.finished.connect(_on_scroll_finished)

func _on_scroll_finished() -> void:
	_start_next_scroll()

func _fade_in() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _fade_out() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_fade_tween.tween_callback(func(): visible = false)

## Loại bỏ tag in đậm, loại bỏ tag màu sắc cũ, ép toàn bộ văn bản sang màu vàng kim đồng nhất
func _clean_and_colorize_yellow(raw_text: String) -> String:
	var cleaned := raw_text
	# Bỏ in đậm ([b], [/b], [i], [/i])
	cleaned = cleaned.replace("[b]", "").replace("[/b]", "")
	cleaned = cleaned.replace("[i]", "").replace("[/i]", "")

	# Bỏ tất cả tag [color=...] và [/color] cũ
	var regex_color := RegEx.new()
	regex_color.compile("\\[color=[^\\]]+\\]")
	cleaned = regex_color.sub(cleaned, "", true)
	cleaned = cleaned.replace("[/color]", "")

	# Bọc toàn bộ dòng chữ bằng màu vàng hoàng kim duy nhất
	return "[color=#FFDF24]%s[/color]" % cleaned.strip_edges()

## Đo độ dài pixel của chuỗi văn bản (bỏ qua tag BBCode)
func _measure_text_width(bbcode: String) -> float:
	var font = _lbl.get_theme_font("normal_font")
	if not font:
		font = ThemeDB.fallback_font
	var font_size = _lbl.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 15

	var regex := RegEx.new()
	regex.compile("\\[.*?\\]")
	var plain := regex.sub(bbcode, "", true)

	var sz = font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return maxf(200.0, sz.x)
