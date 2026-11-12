extends Control
class_name MuMobileStatusFooter

## Thanh Trạng Thái Đáy Màn Hình (Mobile MU Origin Footer Bar)
## - Góc dưới trái: EXP kinh nghiệm người chơi (457.756 / 497.080)
## - Góc dưới phải: Tín hiệu mạng WiFi (📶), Dung lượng pin (🔋 43%), Cấp độ & Phần trăm (Lv 94 | 0,95%)
## - Đường chỉ viền EXP mỏng tinh tế chạy dọc cạnh đáy màn hình

@export var player: MuPlayer = null

var lbl_exp_left: Label
var lbl_status_right: Label
var exp_line_pbar: ProgressBar

func _ready() -> void:
	custom_minimum_size = Vector2(0, 20)
	size = Vector2(0, 20)
	anchors_preset = Control.PRESET_BOTTOM_WIDE
	offset_top = -20
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	if player:
		setup(player)

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if not player:
		return
	if not player.exp_changed.is_connected(_on_exp_changed):
		player.exp_changed.connect(_on_exp_changed)
	_on_exp_changed(player.current_exp, player.max_exp, player.level)

func _on_exp_changed(cur_exp: int, max_e: int, lvl: int) -> void:
	var pct = (float(cur_exp) / float(max(1, max_e))) * 100.0
	if lbl_exp_left:
		lbl_exp_left.text = "%d / %d EXP" % [cur_exp, max_e]
	if lbl_status_right:
		var r_txt = " (R%d)" % player.resets if player and player.resets > 0 else ""
		lbl_status_right.text = "📶 🔋 100%%    Lv %d%s | %.2f%%" % [lvl, r_txt, pct]
	if exp_line_pbar:
		exp_line_pbar.max_value = max(1, max_e)
		exp_line_pbar.value = cur_exp

func _build_ui() -> void:
	# 1. Đường EXP mỏng dọc cạnh đáy
	exp_line_pbar = ProgressBar.new()
	exp_line_pbar.anchors_preset = Control.PRESET_BOTTOM_WIDE
	exp_line_pbar.offset_top = -3
	exp_line_pbar.offset_bottom = 0
	exp_line_pbar.show_percentage = false
	exp_line_pbar.max_value = 100
	exp_line_pbar.value = 45
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.95, 0.82, 0.35, 0.9)
	exp_line_pbar.add_theme_stylebox_override("fill", sb_fill)
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.12, 0.16, 0.6)
	exp_line_pbar.add_theme_stylebox_override("background", sb_bg)
	add_child(exp_line_pbar)

	# 2. Text bên trái (EXP / Coords)
	lbl_exp_left = Label.new()
	lbl_exp_left.position = Vector2(12, 0)
	lbl_exp_left.size = Vector2(250, 18)
	lbl_exp_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_exp_left.text = "457.756 / 497.080"
	lbl_exp_left.add_theme_font_size_override("font_size", 9)
	lbl_exp_left.add_theme_color_override("font_color", Color(0.85, 0.88, 0.75, 0.85))
	lbl_exp_left.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_exp_left.add_theme_constant_override("outline_size", 2)
	add_child(lbl_exp_left)

	# 3. Text bên phải (Wifi, Pin, Level)
	lbl_status_right = Label.new()
	lbl_status_right.anchors_preset = Control.PRESET_TOP_RIGHT
	lbl_status_right.offset_left = -280
	lbl_status_right.offset_right = -12
	lbl_status_right.offset_top = 0
	lbl_status_right.offset_bottom = 18
	lbl_status_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_status_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_status_right.text = "📶 🔋 43%    Lv 94 | 0,95%"
	lbl_status_right.add_theme_font_size_override("font_size", 9)
	lbl_status_right.add_theme_color_override("font_color", Color(0.85, 0.88, 0.75, 0.85))
	lbl_status_right.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_status_right.add_theme_constant_override("outline_size", 2)
	add_child(lbl_status_right)
