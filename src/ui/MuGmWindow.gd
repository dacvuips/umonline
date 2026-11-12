extends Control
class_name MuGmWindow

## Bảng Điều Khiển Quản Trị GM (GM Control Panel)
## Cho phép Buff Cấp Độ (Level Buff) và Cài Đặt Reset (Reset Editor & Relife) tùy ý,
## đồng thời tích hợp Buff Point, Buff Zen, Bất Tử (God Mode), Mở Khóa Kỹ Năng và Đổi Lớp Nhân Vật.

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuAudioManagerRes = preload("res://src/audio/MuAudioManager.gd")
const MuWorldRes = preload("res://src/world/MuWorld.gd")

const W := 680.0
const H := 610.0

var player: MuPlayer = null

# Dragging window
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# UI Nodes
var _panel_root: Control

# Tabs
var _tab_char_btn: Button
var _tab_event_btn: Button
var _view_char: Control
var _view_events: Control

# Top Hero Info
var _lbl_hero_name: Label
var _lbl_hero_class: Label
var _lbl_hero_level: Label
var _lbl_hero_resets: Label
var _lbl_hero_points: Label
var _lbl_hero_zen: Label

# 1. Level Controls
var _input_level: LineEdit
var _slider_level: HSlider
var _chk_give_points_on_level: CheckBox
var _btn_apply_level: Button

# 2. Reset Controls
var _input_resets: LineEdit
var _input_points_per_reset: LineEdit
var _btn_apply_resets: Button
var _btn_perform_one_reset: Button
var _chk_reset_stats_on_reset: CheckBox
var _btn_reset_stats: Button

# 3. Quick Perks Controls
var _btn_god_mode: Button
var _btn_zen_10m: Button
var _btn_zen_100m: Button
var _btn_zen_max: Button
var _btn_point_1k: Button
var _btn_point_5k: Button
var _btn_point_50k: Button
var _btn_point_max: Button
var _btn_skill_class: Button
var _btn_skill_all: Button
var _class_dropdown: OptionButton
var _btn_open_item_picker: Button

const CLASS_NAMES := [
	"Phù Thủy (DW)",
	"Chiến Binh (DK)",
	"Tiên Nữ (Elf)",
	"Đấu Sĩ (MG)",
	"Chúa Tể (DL)",
	"Thuật Sĩ (SUM)",
	"Thiết Binh (RF)"
]

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)

	_build_ui()
	_center_window()
	var vp = get_viewport()
	if vp:
		vp.size_changed.connect(_center_window)

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player:
		if not player.exp_changed.is_connected(_on_player_data_changed):
			player.exp_changed.connect(_on_player_data_changed)
		if not player.hp_changed.is_connected(_on_player_data_changed_hp):
			player.hp_changed.connect(_on_player_data_changed_hp)
		if "resets_changed" in player and not player.resets_changed.is_connected(_on_resets_changed):
			player.resets_changed.connect(_on_resets_changed)
	update_display()

func _center_window() -> void:
	var vp = get_viewport()
	var vs = vp.get_visible_rect().size if vp else Vector2(1280, 720)
	position = Vector2(maxf(20.0, (vs.x - W) * 0.5), maxf(15.0, (vs.y - H) * 0.5))

func toggle() -> void:
	visible = not visible
	if visible:
		_center_window()
		update_display()
		if MuAudioManagerRes:
			MuAudioManagerRes.play_ui_window()

func open_panel() -> void:
	visible = true
	_center_window()
	update_display()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_ui_window()

func close_panel() -> void:
	visible = false
	if MuAudioManagerRes:
		MuAudioManagerRes.play_ui_window()

func _on_player_data_changed(_c: int, _m: int, _l: int) -> void:
	update_display()

func _on_player_data_changed_hp(_c: int, _m: int) -> void:
	update_display()

func _on_resets_changed(_r: int) -> void:
	update_display()

# ==============================================================================
# XÂY DỰNG GIAO DIỆN CHUẨN MU ONLINE SANG TRỌNG
# ==============================================================================
func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_panel_root)

	# 1. Nền tổng thể Dark Metallic Gothic
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.06, 0.05, 0.05, 0.96)
	sb_bg.border_width_left = 2
	sb_bg.border_width_top = 2
	sb_bg.border_width_right = 2
	sb_bg.border_width_bottom = 2
	sb_bg.border_color = Color(0.85, 0.72, 0.35, 1.0)
	sb_bg.corner_radius_top_left = 6
	sb_bg.corner_radius_top_right = 6
	sb_bg.corner_radius_bottom_left = 6
	sb_bg.corner_radius_bottom_right = 6
	sb_bg.shadow_color = Color(0, 0, 0, 0.8)
	sb_bg.shadow_size = 14
	bg.add_theme_stylebox_override("panel", sb_bg)
	_panel_root.add_child(bg)

	# 2. Thanh Tiêu Đề kéo thả (Title Bar)
	var title_bar := Control.new()
	title_bar.position = Vector2(0, 0)
	title_bar.size = Vector2(W, 44)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_gui_input)
	_panel_root.add_child(title_bar)

	var title_bg := Panel.new()
	title_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb_title := StyleBoxFlat.new()
	sb_title.bg_color = Color(0.16, 0.12, 0.08, 0.95)
	sb_title.border_width_bottom = 2
	sb_title.border_color = Color(0.8, 0.65, 0.25, 0.9)
	sb_title.corner_radius_top_left = 6
	sb_title.corner_radius_top_right = 6
	title_bg.add_theme_stylebox_override("panel", sb_title)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_bg)

	var title_lbl := Label.new()
	title_lbl.text = "👑 BẢNG ĐIỀU KHIỂN QUẢN TRỊ GM (GM PANEL)"
	title_lbl.position = Vector2(16, 5)
	title_lbl.size = Vector2(500, 20)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Tùy Chỉnh Cấp Độ • Đặt Số Lần Reset • Tẩy Điểm • Buff Point • Bất Tử • Kỹ Năng"
	sub_lbl.position = Vector2(16, 24)
	sub_lbl.size = Vector2(550, 16)
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(sub_lbl)

	# Nút đóng [X]
	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.position = Vector2(W - 36, 8)
	btn_close.size = Vector2(28, 28)
	btn_close.add_theme_font_size_override("font_size", 13)
	btn_close.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	btn_close.pressed.connect(close_panel)
	title_bar.add_child(btn_close)

	# 3. Hero Status Banner (Thông tin nhân vật hiện tại)
	var hero_panel := Panel.new()
	hero_panel.position = Vector2(14, 50)
	hero_panel.size = Vector2(W - 28, 54)
	var sb_hero := StyleBoxFlat.new()
	sb_hero.bg_color = Color(0.12, 0.09, 0.07, 0.9)
	sb_hero.border_width_left = 1
	sb_hero.border_width_top = 1
	sb_hero.border_width_right = 1
	sb_hero.border_width_bottom = 1
	sb_hero.border_color = Color(0.7, 0.55, 0.25, 0.7)
	sb_hero.corner_radius_top_left = 4
	sb_hero.corner_radius_top_right = 4
	sb_hero.corner_radius_bottom_left = 4
	sb_hero.corner_radius_bottom_right = 4
	hero_panel.add_theme_stylebox_override("panel", sb_hero)
	_panel_root.add_child(hero_panel)

	var hero_hbox := HBoxContainer.new()
	hero_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hero_hbox.offset_left = 12
	hero_hbox.offset_right = -12
	hero_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_hbox.add_theme_constant_override("separation", 16)
	hero_panel.add_child(hero_hbox)

	_lbl_hero_name = _create_hero_label("Nhân vật:", "—", Color(1.0, 0.85, 0.3))
	hero_hbox.add_child(_lbl_hero_name.get_parent())

	_lbl_hero_class = _create_hero_label("Class:", "—", Color(0.5, 0.9, 1.0))
	hero_hbox.add_child(_lbl_hero_class.get_parent())

	_lbl_hero_level = _create_hero_label("Cấp độ:", "Lv.1", Color(0.4, 1.0, 0.5))
	hero_hbox.add_child(_lbl_hero_level.get_parent())

	_lbl_hero_resets = _create_hero_label("Số lần Reset:", "0 lần", Color(1.0, 0.5, 0.8))
	hero_hbox.add_child(_lbl_hero_resets.get_parent())

	_lbl_hero_points = _create_hero_label("Point:", "0", Color(1.0, 0.95, 0.2))
	hero_hbox.add_child(_lbl_hero_points.get_parent())

	_lbl_hero_zen = _create_hero_label("Zen:", "0", Color(1.0, 0.75, 0.2))
	hero_hbox.add_child(_lbl_hero_zen.get_parent())

	# 4. Thanh Tab chuyển đổi
	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(14, 108)
	tab_bar.size = Vector2(W - 28, 28)
	tab_bar.add_theme_constant_override("separation", 6)
	_panel_root.add_child(tab_bar)

	_tab_char_btn = Button.new()
	_tab_char_btn.text = "👑 NHÂN VẬT & TIỆN ÍCH GM"
	_tab_char_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_char_btn.add_theme_font_size_override("font_size", 11)
	_tab_char_btn.pressed.connect(func(): _switch_tab(0))
	tab_bar.add_child(_tab_char_btn)

	_tab_event_btn = Button.new()
	_tab_event_btn.text = "🎟️ VẬT PHẨM & VÉ SỰ KIỆN TOÀN GAME"
	_tab_event_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_event_btn.add_theme_font_size_override("font_size", 11)
	_tab_event_btn.pressed.connect(func(): _switch_tab(1))
	tab_bar.add_child(_tab_event_btn)

	# View 1: Nhân vật & Perks (Cột Trái Level + Reset, Cột Phải GM Tools)
	_view_char = Control.new()
	_view_char.position = Vector2(14, 140)
	_view_char.size = Vector2(W - 28, 456)
	_panel_root.add_child(_view_char)

	var col_left := Control.new()
	col_left.position = Vector2(0, 0)
	col_left.size = Vector2(330, 444)
	_view_char.add_child(col_left)

	var col_right := Control.new()
	col_right.position = Vector2(344, 0)
	col_right.size = Vector2(308, 444)
	_view_char.add_child(col_right)

	# View 2: Quản lý & Cấp phát vật phẩm Sự Kiện
	_view_events = Control.new()
	_view_events.position = Vector2(14, 140)
	_view_events.size = Vector2(W - 28, 456)
	_view_events.visible = false
	_panel_root.add_child(_view_events)
	_build_events_view(_view_events)

	_switch_tab(0)

	# --------------------------------------------------------------------------
	# A. CỘT TRÁI - KHỐI 1: BUFF CẤP ĐỘ THEO Ý MUỐN (LEVEL CONTROL)
	# --------------------------------------------------------------------------
	var box_lvl := _create_group_box(col_left, Vector2(0, 0), Vector2(330, 204), "⚡ BUFF CẤP ĐỘ (LEVEL CONTROL)")

	var lbl_target_lvl := Label.new()
	lbl_target_lvl.text = "Cấp độ muốn đạt (1 ~ 400):"
	lbl_target_lvl.position = Vector2(10, 26)
	lbl_target_lvl.size = Vector2(170, 20)
	lbl_target_lvl.add_theme_font_size_override("font_size", 11)
	lbl_target_lvl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	box_lvl.add_child(lbl_target_lvl)

	_input_level = LineEdit.new()
	_input_level.text = "400"
	_input_level.position = Vector2(184, 24)
	_input_level.size = Vector2(60, 24)
	_input_level.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input_level.add_theme_font_size_override("font_size", 12)
	_input_level.text_changed.connect(_on_input_level_changed)
	box_lvl.add_child(_input_level)

	var b_max := Button.new()
	b_max.text = "MAX"
	b_max.position = Vector2(248, 24)
	b_max.size = Vector2(72, 24)
	b_max.add_theme_font_size_override("font_size", 10)
	b_max.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	b_max.pressed.connect(func(): _set_input_level(400))
	box_lvl.add_child(b_max)

	# Thanh trượt HSlider
	_slider_level = HSlider.new()
	_slider_level.min_value = 1
	_slider_level.max_value = 400
	_slider_level.step = 1
	_slider_level.value = 400
	_slider_level.position = Vector2(10, 56)
	_slider_level.size = Vector2(310, 20)
	_slider_level.value_changed.connect(_on_slider_level_changed)
	box_lvl.add_child(_slider_level)

	# Hàng mốc cấp độ nhanh
	var row_lvl_presets := HBoxContainer.new()
	row_lvl_presets.position = Vector2(10, 80)
	row_lvl_presets.size = Vector2(310, 24)
	row_lvl_presets.add_theme_constant_override("separation", 4)
	box_lvl.add_child(row_lvl_presets)

	var presets = [1, 100, 200, 350, 400]
	for p in presets:
		var bp := Button.new()
		bp.text = "Lv %d" % p
		bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bp.add_theme_font_size_override("font_size", 10)
		bp.pressed.connect(func(): _set_input_level(p))
		row_lvl_presets.add_child(bp)

	# Hàng tăng cấp nhanh (+1, +10, +50, +100)
	var row_lvl_inc := HBoxContainer.new()
	row_lvl_inc.position = Vector2(10, 108)
	row_lvl_inc.size = Vector2(310, 22)
	row_lvl_inc.add_theme_constant_override("separation", 4)
	box_lvl.add_child(row_lvl_inc)

	for inc in [1, 5, 10, 50, 100]:
		var bi := Button.new()
		bi.text = "+%d" % inc
		bi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bi.add_theme_font_size_override("font_size", 10)
		bi.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		bi.pressed.connect(func(): _add_level(inc))
		row_lvl_inc.add_child(bi)

	_chk_give_points_on_level = CheckBox.new()
	_chk_give_points_on_level.text = "Tự cộng Point khi tăng cấp (+5..7 Point/Cấp)"
	_chk_give_points_on_level.button_pressed = true
	_chk_give_points_on_level.position = Vector2(8, 134)
	_chk_give_points_on_level.size = Vector2(314, 22)
	_chk_give_points_on_level.add_theme_font_size_override("font_size", 10)
	_chk_give_points_on_level.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	box_lvl.add_child(_chk_give_points_on_level)

	# Nút hành động BUFF CẤP ĐỘ NGAY
	_btn_apply_level = Button.new()
	_btn_apply_level.text = "⚡ BUFF CẤP ĐỘ THEO Ý MUỐN"
	_btn_apply_level.position = Vector2(10, 162)
	_btn_apply_level.size = Vector2(310, 32)
	_btn_apply_level.add_theme_font_size_override("font_size", 12)
	_btn_apply_level.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_btn_apply_level.pressed.connect(_on_apply_level_clicked)
	box_lvl.add_child(_btn_apply_level)

	# --------------------------------------------------------------------------
	# A. CỘT TRÁI - KHỐI 2: HỆ THỐNG RESET & CHUYỂN SINH (RESET SYSTEM)
	# --------------------------------------------------------------------------
	var box_reset := _create_group_box(col_left, Vector2(0, 212), Vector2(330, 232), "🔄 HỆ THỐNG RESET & CHUYỂN SINH")

	var lbl_target_resets := Label.new()
	lbl_target_resets.text = "Số lần Reset muốn đặt:"
	lbl_target_resets.position = Vector2(10, 26)
	lbl_target_resets.size = Vector2(160, 20)
	lbl_target_resets.add_theme_font_size_override("font_size", 11)
	lbl_target_resets.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	box_reset.add_child(lbl_target_resets)

	_input_resets = LineEdit.new()
	_input_resets.text = "10"
	_input_resets.position = Vector2(174, 24)
	_input_resets.size = Vector2(56, 24)
	_input_resets.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input_resets.add_theme_font_size_override("font_size", 12)
	box_reset.add_child(_input_resets)

	var lbl_ppr := Label.new()
	lbl_ppr.text = "+Point/R:"
	lbl_ppr.position = Vector2(234, 26)
	lbl_ppr.size = Vector2(50, 20)
	lbl_ppr.add_theme_font_size_override("font_size", 10)
	lbl_ppr.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box_reset.add_child(lbl_ppr)

	_input_points_per_reset = LineEdit.new()
	_input_points_per_reset.text = "500"
	_input_points_per_reset.position = Vector2(284, 24)
	_input_points_per_reset.size = Vector2(38, 24)
	_input_points_per_reset.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input_points_per_reset.add_theme_font_size_override("font_size", 10)
	box_reset.add_child(_input_points_per_reset)

	# Hàng tăng số lần Reset nhanh (+1, +5, +10, +50, +100)
	var row_res_inc := HBoxContainer.new()
	row_res_inc.position = Vector2(10, 54)
	row_res_inc.size = Vector2(310, 24)
	row_res_inc.add_theme_constant_override("separation", 4)
	box_reset.add_child(row_res_inc)

	for r_inc in [1, 5, 10, 50, 100]:
		var br := Button.new()
		br.text = "+%d Reset" % r_inc
		br.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_theme_font_size_override("font_size", 9)
		br.add_theme_color_override("font_color", Color(1.0, 0.65, 0.85))
		br.pressed.connect(func(): _add_resets(r_inc))
		row_res_inc.add_child(br)

	_btn_apply_resets = Button.new()
	_btn_apply_resets.text = "👑 ĐẶT SỐ LẦN RESET THEO Ý MUỐN"
	_btn_apply_resets.position = Vector2(10, 84)
	_btn_apply_resets.size = Vector2(310, 28)
	_btn_apply_resets.add_theme_font_size_override("font_size", 11)
	_btn_apply_resets.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))
	_btn_apply_resets.pressed.connect(_on_apply_resets_clicked)
	box_reset.add_child(_btn_apply_resets)

	# Dải phân cách mỏng
	var sep := HSeparator.new()
	sep.position = Vector2(10, 118)
	sep.size = Vector2(310, 4)
	box_reset.add_child(sep)

	# Thao tác Reset 1 lần chuẩn MU
	_chk_reset_stats_on_reset = CheckBox.new()
	_chk_reset_stats_on_reset.text = "Tẩy điểm Stat khi Reset (Hoàn lại point)"
	_chk_reset_stats_on_reset.button_pressed = false
	_chk_reset_stats_on_reset.position = Vector2(8, 126)
	_chk_reset_stats_on_reset.size = Vector2(314, 22)
	_chk_reset_stats_on_reset.add_theme_font_size_override("font_size", 10)
	_chk_reset_stats_on_reset.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	box_reset.add_child(_chk_reset_stats_on_reset)

	_btn_perform_one_reset = Button.new()
	_btn_perform_one_reset.text = "🔄 THỰC HIỆN RESET NGAY (Về Lv.1 + Thưởng Point)"
	_btn_perform_one_reset.position = Vector2(10, 152)
	_btn_perform_one_reset.size = Vector2(310, 34)
	_btn_perform_one_reset.add_theme_font_size_override("font_size", 11)
	_btn_perform_one_reset.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_btn_perform_one_reset.pressed.connect(_on_perform_one_reset_clicked)
	box_reset.add_child(_btn_perform_one_reset)

	_btn_reset_stats = Button.new()
	_btn_reset_stats.text = "🔄 Tẩy Điểm Stat (Reset Points về mặc định)"
	_btn_reset_stats.position = Vector2(10, 192)
	_btn_reset_stats.size = Vector2(310, 28)
	_btn_reset_stats.add_theme_font_size_override("font_size", 10)
	_btn_reset_stats.add_theme_color_override("font_color", Color(0.9, 0.6, 0.4))
	_btn_reset_stats.pressed.connect(_on_reset_stats_clicked)
	box_reset.add_child(_btn_reset_stats)

	# --------------------------------------------------------------------------
	# B. CỘT PHẢI - KHỐI 3: TIỆN ÍCH GM BỔ TRỢ (PERKS & QUICK TOOLS)
	# --------------------------------------------------------------------------
	var box_perks := _create_group_box(col_right, Vector2(0, 0), Vector2(274, 444), "🛠️ TIỆN ÍCH GM BỔ TRỢ")

	# 1. Bất Tử God Mode
	_btn_god_mode = Button.new()
	_btn_god_mode.position = Vector2(10, 26)
	_btn_god_mode.size = Vector2(254, 30)
	_btn_god_mode.add_theme_font_size_override("font_size", 11)
	_btn_god_mode.pressed.connect(_on_toggle_god_mode_clicked)
	box_perks.add_child(_btn_god_mode)

	# 2. Buff Point Nhanh
	var lbl_point := Label.new()
	lbl_point.text = "✨ Thêm Điểm Point Nâng Chỉ Số:"
	lbl_point.position = Vector2(10, 62)
	lbl_point.size = Vector2(254, 18)
	lbl_point.add_theme_font_size_override("font_size", 10)
	lbl_point.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box_perks.add_child(lbl_point)

	var row_pt1 := HBoxContainer.new()
	row_pt1.position = Vector2(10, 82)
	row_pt1.size = Vector2(254, 24)
	row_pt1.add_theme_constant_override("separation", 4)
	box_perks.add_child(row_pt1)

	_btn_point_1k = _create_quick_button(row_pt1, "+1K", func(): _add_points(1000), Color(1.0, 0.95, 0.3))
	_btn_point_5k = _create_quick_button(row_pt1, "+5K", func(): _add_points(5000), Color(1.0, 0.9, 0.3))
	_btn_point_50k = _create_quick_button(row_pt1, "+50K", func(): _add_points(50000), Color(1.0, 0.8, 0.2))
	_btn_point_max = _create_quick_button(row_pt1, "65K Stat", func(): _add_points(65000), Color(1.0, 0.5, 0.2))

	# 3. Buff Zen Nhanh
	var lbl_zen := Label.new()
	lbl_zen.text = "💰 Nhận Tiền Vàng (Zen):"
	lbl_zen.position = Vector2(10, 114)
	lbl_zen.size = Vector2(254, 18)
	lbl_zen.add_theme_font_size_override("font_size", 10)
	lbl_zen.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box_perks.add_child(lbl_zen)

	var row_zen := HBoxContainer.new()
	row_zen.position = Vector2(10, 134)
	row_zen.size = Vector2(254, 24)
	row_zen.add_theme_constant_override("separation", 4)
	box_perks.add_child(row_zen)

	_btn_zen_10m = _create_quick_button(row_zen, "+10M", func(): _add_zen(10000000), Color(1.0, 0.85, 0.3))
	_btn_zen_100m = _create_quick_button(row_zen, "+100M", func(): _add_zen(100000000), Color(1.0, 0.85, 0.3))
	_btn_zen_max = _create_quick_button(row_zen, "Max 2 Tỷ", func(): _add_zen(2000000000), Color(1.0, 0.6, 0.2))

	# 4. Kỹ Năng
	var lbl_skill := Label.new()
	lbl_skill.text = "⚡ Học & Mở Khóa Kỹ Năng (Skills):"
	lbl_skill.position = Vector2(10, 166)
	lbl_skill.size = Vector2(254, 18)
	lbl_skill.add_theme_font_size_override("font_size", 10)
	lbl_skill.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	box_perks.add_child(lbl_skill)

	var row_sk := HBoxContainer.new()
	row_sk.position = Vector2(10, 186)
	row_sk.size = Vector2(254, 26)
	row_sk.add_theme_constant_override("separation", 4)
	box_perks.add_child(row_sk)

	_btn_skill_class = _create_quick_button(row_sk, "⚡ Skill Class", _on_learn_class_skills_clicked, Color(0.5, 0.9, 1.0))
	_btn_skill_all = _create_quick_button(row_sk, "🌟 Mọi Class", _on_learn_all_skills_clicked, Color(0.4, 1.0, 0.5))

	# 5. Chuyển Lớp Nhân Vật (Class)
	var lbl_cls := Label.new()
	lbl_cls.text = "🧙 Đổi Lớp Nhân Vật (Class):"
	lbl_cls.position = Vector2(10, 222)
	lbl_cls.size = Vector2(254, 18)
	lbl_cls.add_theme_font_size_override("font_size", 10)
	lbl_cls.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	box_perks.add_child(lbl_cls)

	_class_dropdown = OptionButton.new()
	_class_dropdown.position = Vector2(10, 242)
	_class_dropdown.size = Vector2(254, 26)
	_class_dropdown.add_theme_font_size_override("font_size", 11)
	for i in range(CLASS_NAMES.size()):
		_class_dropdown.add_item(CLASS_NAMES[i], i)
	_class_dropdown.item_selected.connect(_on_class_selected)
	box_perks.add_child(_class_dropdown)

	# 6. Dịch chuyển nhanh (Fast Teleport)
	var lbl_tp := Label.new()
	lbl_tp.text = "🚀 Dịch Chuyển Nhanh (Teleport):"
	lbl_tp.position = Vector2(10, 278)
	lbl_tp.size = Vector2(254, 18)
	lbl_tp.add_theme_font_size_override("font_size", 10)
	lbl_tp.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	box_perks.add_child(lbl_tp)

	var row_tp := HBoxContainer.new()
	row_tp.position = Vector2(10, 298)
	row_tp.size = Vector2(254, 24)
	row_tp.add_theme_constant_override("separation", 4)
	box_perks.add_child(row_tp)

	_create_quick_button(row_tp, "Lorencia", func(): _teleport_to(0, Vector2i(140, 119)), Color(0.9, 0.8, 0.6))
	_create_quick_button(row_tp, "Noria", func(): _teleport_to(3, Vector2i(175, 110)), Color(0.6, 1.0, 0.7))
	_create_quick_button(row_tp, "Devias", func(): _teleport_to(2, Vector2i(220, 40)), Color(0.6, 0.8, 1.0))

	var row_tp2 := HBoxContainer.new()
	row_tp2.position = Vector2(10, 326)
	row_tp2.size = Vector2(254, 24)
	row_tp2.add_theme_constant_override("separation", 4)
	box_perks.add_child(row_tp2)

	_create_quick_button(row_tp2, "Dungeon", func(): _teleport_to(1, Vector2i(108, 247)), Color(0.8, 0.6, 0.6))
	_create_quick_button(row_tp2, "Atlans", func(): _teleport_to(7, Vector2i(24, 19)), Color(0.4, 0.8, 1.0))
	_create_quick_button(row_tp2, "LostTower", func(): _teleport_to(4, Vector2i(208, 78)), Color(1.0, 0.6, 0.4))

	# 7. Nút mở Kho Đồ GM (Item Generator / Item Picker)
	var sep2 := HSeparator.new()
	sep2.position = Vector2(10, 360)
	sep2.size = Vector2(254, 4)
	box_perks.add_child(sep2)

	_btn_open_item_picker = Button.new()
	_btn_open_item_picker.text = "🎒 MỞ KHO ĐỒ GM (ITEM PICKER)"
	_btn_open_item_picker.position = Vector2(10, 374)
	_btn_open_item_picker.size = Vector2(254, 34)
	_btn_open_item_picker.add_theme_font_size_override("font_size", 11)
	_btn_open_item_picker.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	_btn_open_item_picker.pressed.connect(_on_open_item_picker_clicked)
	box_perks.add_child(_btn_open_item_picker)

	# Nút đóng bảng ở đáy
	var btn_close_bot := Button.new()
	btn_close_bot.text = "Đóng Bảng GM"
	btn_close_bot.position = Vector2(10, 414)
	btn_close_bot.size = Vector2(288, 22)
	btn_close_bot.add_theme_font_size_override("font_size", 10)
	btn_close_bot.pressed.connect(close_panel)
	box_perks.add_child(btn_close_bot)

# ==============================================================================
# GIAO DIỆN QUẢN LÝ VẬT PHẨM SỰ KIỆN TOÀN GAME
# ==============================================================================
func _build_events_view(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# 1. TOP BANNER: 1-CLICK NHẬN ĐẦY ĐỦ VÉ TẤT CẢ SỰ KIỆN
	var top_card := _create_event_card(vbox, "⭐ [1-CLICK] NHẬN TRỌN BỘ VÉ TẤT CẢ CÁC SỰ KIỆN CỦA GAME", Color(1.0, 0.88, 0.2))
	var top_vbox = top_card.get_child(0)

	var top_desc := Label.new()
	top_desc.text = "Cấp phát đầy đủ vé tham gia TOÀN BỘ các sự kiện trong MU Online (BC 1-8, DS 1-7, CC 1-7, Kalima 1-7, IT 1-6, Gaion, Doppelganger, Santa, Crywolf, Kanturu, Công Thành Chiến) vào túi đồ!"
	top_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_desc.add_theme_font_size_override("font_size", 10)
	top_desc.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	top_vbox.add_child(top_desc)

	var top_actions := HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 8)
	top_vbox.add_child(top_actions)

	var btn_all_events := Button.new()
	btn_all_events.text = "⭐ NHẬN TRỌN BỘ VÉ TẤT CẢ SỰ KIỆN"
	btn_all_events.custom_minimum_size = Vector2(280, 32)
	btn_all_events.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_all_events.add_theme_font_size_override("font_size", 11)
	btn_all_events.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	btn_all_events.pressed.connect(_on_give_all_events_clicked)
	top_actions.add_child(btn_all_events)

	var btn_view_schedule := Button.new()
	btn_view_schedule.text = "📅 LỊCH TRÌNH SỰ KIỆN (EVENTS)"
	btn_view_schedule.custom_minimum_size = Vector2(170, 32)
	btn_view_schedule.add_theme_font_size_override("font_size", 11)
	btn_view_schedule.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	btn_view_schedule.pressed.connect(func():
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("toggle_event_schedule"):
			hud.toggle_event_schedule()
	)
	top_actions.add_child(btn_view_schedule)

	var btn_open_item_picker_ev := Button.new()
	btn_open_item_picker_ev.text = "🎒 KHO ĐỒ GM (LỌC SỰ KIỆN)"
	btn_open_item_picker_ev.custom_minimum_size = Vector2(180, 32)
	btn_open_item_picker_ev.add_theme_font_size_override("font_size", 11)
	btn_open_item_picker_ev.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	btn_open_item_picker_ev.pressed.connect(_on_open_item_picker_clicked)
	top_actions.add_child(btn_open_item_picker_ev)

	var btn_clear_inv := Button.new()
	btn_clear_inv.text = "🧹 Dọn Sạch Túi"
	btn_clear_inv.custom_minimum_size = Vector2(110, 32)
	btn_clear_inv.add_theme_font_size_override("font_size", 11)
	btn_clear_inv.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	btn_clear_inv.pressed.connect(_clear_inventory)
	top_actions.add_child(btn_clear_inv)

	# 2. BLOOD CASTLE (LÂU ĐÀI MÁU)
	var bc_card := _create_event_card(vbox, "🩸 LÂU ĐÀI MÁU (BLOOD CASTLE 1 ~ 8)", Color(1.0, 0.45, 0.45))
	var bc_vbox = bc_card.get_child(0)
	var bc_lbl := Label.new()
	bc_lbl.text = "Yêu cầu: Áo Tàng Hình (Invisibility Cloak +1..+8). Ép từ: Xương Máu + Cuộn Giấy Thiên Sứ + Ngọc Hỗn Nguyên (Jewel of Chaos)."
	bc_lbl.add_theme_font_size_override("font_size", 10)
	bc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bc_vbox.add_child(bc_lbl)

	var bc_row1 := HBoxContainer.new()
	bc_row1.add_theme_constant_override("separation", 6)
	bc_vbox.add_child(bc_row1)
	_create_quick_button(bc_row1, "🩸 Full Vé BC (+1..+8)", func(): _give_bundle(-551, "Đã nhận Full 8 Vé Blood Castle (+1..+8)!"), Color(1.0, 0.6, 0.6))
	_create_quick_button(bc_row1, "🛠️ NL Ép (Xương + Giấy + Chaos)", _give_bc_materials, Color(1.0, 0.85, 0.4))
	_create_quick_button(bc_row1, "⚔️ Vũ Khí Tuyệt Mệnh (Quest)", _give_archangel_weapons, Color(0.4, 0.9, 1.0))
	_create_quick_button(bc_row1, "🎟️ Vé BC Ticket", func(): _give_single_item(13, 47, 0, "Vé Lâu Đài Máu"), Color(0.9, 0.7, 1.0))
	_create_quick_button(bc_row1, "⚡ Mở Cổng BC (Test)", func(): _force_event("blood_castle"), Color(1.0, 0.4, 0.4))

	var bc_row_lv := HBoxContainer.new()
	bc_row_lv.add_theme_constant_override("separation", 4)
	bc_vbox.add_child(bc_row_lv)
	for lv in range(1, 9):
		_create_quick_button(bc_row_lv, "BC +%d" % lv, func(): _give_single_item(13, 18, lv, "Áo Tàng Hình (Blood Castle +%d)" % lv), Color(1.0, 0.8, 0.5))

	# 3. DEVIL SQUARE (QUẢNG TRƯỜNG QUỶ)
	var ds_card := _create_event_card(vbox, "😈 QUẢNG TRƯỜNG QUỶ (DEVIL SQUARE 1 ~ 7)", Color(1.0, 0.6, 0.3))
	var ds_vbox = ds_card.get_child(0)
	var ds_lbl := Label.new()
	ds_lbl.text = "Yêu cầu: Thiệp Mời Quỷ (Devil's Invitation +1..+7). Ép từ: Mắt Quỷ + Khóa Quỷ + Ngọc Hỗn Nguyên (Jewel of Chaos)."
	ds_lbl.add_theme_font_size_override("font_size", 10)
	ds_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ds_vbox.add_child(ds_lbl)

	var ds_row1 := HBoxContainer.new()
	ds_row1.add_theme_constant_override("separation", 6)
	ds_vbox.add_child(ds_row1)
	_create_quick_button(ds_row1, "😈 Full Vé DS (+1..+7)", func(): _give_bundle(-552, "Đã nhận Full 7 Vé Devil Square (+1..+7)!"), Color(1.0, 0.7, 0.4))
	_create_quick_button(ds_row1, "🛠️ NL Ép (Mắt + Khóa + Chaos)", _give_ds_materials, Color(1.0, 0.85, 0.4))
	_create_quick_button(ds_row1, "🎟️ Vé DS Ticket", func(): _give_single_item(13, 46, 0, "Vé Quảng Trường Quỷ"), Color(0.9, 0.7, 1.0))
	_create_quick_button(ds_row1, "⚡ Mở Cổng DS (Test)", func(): _force_event("devil_square"), Color(1.0, 0.5, 0.3))

	var ds_row_lv := HBoxContainer.new()
	ds_row_lv.add_theme_constant_override("separation", 4)
	ds_vbox.add_child(ds_row_lv)
	for lv in range(1, 8):
		_create_quick_button(ds_row_lv, "DS +%d" % lv, func(): _give_single_item(14, 19, lv, "Thiệp Mời Quỷ (Devil Square +%d)" % lv), Color(1.0, 0.85, 0.5))

	# 4. CHAOS CASTLE (HỖN NGUYÊN LÂU)
	var cc_card := _create_event_card(vbox, "🏰 HỖN NGUYÊN LÂU (CHAOS CASTLE 1 ~ 7)", Color(0.85, 0.65, 1.0))
	var cc_vbox = cc_card.get_child(0)
	var cc_lbl := Label.new()
	cc_lbl.text = "Yêu cầu: Áo Giáp Vệ Binh (Armor of Guardsman +1..+7). Mua tại NPC hoặc nhận trực tiếp để vào đấu trường sinh tồn."
	cc_lbl.add_theme_font_size_override("font_size", 10)
	cc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	cc_vbox.add_child(cc_lbl)

	var cc_row1 := HBoxContainer.new()
	cc_row1.add_theme_constant_override("separation", 6)
	cc_vbox.add_child(cc_row1)
	_create_quick_button(cc_row1, "🏰 Full Áo Giáp Vệ Binh (+1..+7)", func(): _give_bundle(-553, "Đã nhận Full 7 Áo Giáp Vệ Binh CC!"), Color(0.9, 0.7, 1.0))
	_create_quick_button(cc_row1, "🎟️ Vé Tự Do Hỗn Nguyên Lâu", func(): _give_single_item(13, 121, 0, "Vé Tự Do Hỗn Nguyên Lâu"), Color(1.0, 0.85, 0.4))
	_create_quick_button(cc_row1, "⚡ Mở Cổng CC (Test)", func(): _force_event("chaos_castle"), Color(0.85, 0.6, 1.0))

	var cc_row_lv := HBoxContainer.new()
	cc_row_lv.add_theme_constant_override("separation", 4)
	cc_vbox.add_child(cc_row_lv)
	for lv in range(1, 8):
		_create_quick_button(cc_row_lv, "CC +%d" % lv, func(): _give_single_item(13, 29, lv, "Áo Giáp Vệ Binh (Chaos Castle +%d)" % lv), Color(0.85, 0.75, 1.0))

	# 5. KALIMA & KUNDUN
	var k_card := _create_event_card(vbox, "🏛️ ĐỀN KALIMA & CHÚA TỂ KUNDUN (KALIMA 1 ~ 7)", Color(0.4, 0.9, 1.0))
	var k_vbox = k_card.get_child(0)
	var k_lbl := Label.new()
	k_lbl.text = "Yêu cầu: Bản Đồ Biến Mất (Lost Map +1..+7). Ghép từ 5 Huy Hiệu Kundun (Symbol of Kundun) để mở cổng đền Kalima."
	k_lbl.add_theme_font_size_override("font_size", 10)
	k_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	k_vbox.add_child(k_lbl)

	var k_row1 := HBoxContainer.new()
	k_row1.add_theme_constant_override("separation", 6)
	k_vbox.add_child(k_row1)
	_create_quick_button(k_row1, "🏛️ Full Bản Đồ Lost Map (+1..+7)", _give_kalima_maps, Color(0.4, 0.9, 1.0))
	_create_quick_button(k_row1, "👑 Full Huy Hiệu Kundun (+1..+7)", _give_kundun_symbols, Color(1.0, 0.85, 0.4))
	_create_quick_button(k_row1, "🎟️ Vé Kalima Ticket", func(): _give_single_item(13, 48, 0, "Vé Đền Kalima"), Color(0.9, 0.7, 1.0))

	var k_row_lv := HBoxContainer.new()
	k_row_lv.add_theme_constant_override("separation", 4)
	k_vbox.add_child(k_row_lv)
	for lv in range(1, 8):
		_create_quick_button(k_row_lv, "Kalima +%d" % lv, func(): _give_single_item(14, 28, lv, "Bản Đồ Biến Mất (Lost Map +%d)" % lv), Color(0.5, 0.9, 1.0))

	# 6. ILLUSION TEMPLE (ĐỀN ẢO ẢNH)
	var it_card := _create_event_card(vbox, "🔮 ĐỀN ẢO ẢNH (ILLUSION TEMPLE 1 ~ 6)", Color(0.95, 0.5, 1.0))
	var it_vbox = it_card.get_child(0)
	var it_lbl := Label.new()
	it_lbl.text = "Yêu cầu: Huyết Kính Ấn (Scroll of Blood +1..+6). Ép từ: Cuộn Giấy Cổ + Khế Ước Phù Thủy + Ngọc Hỗn Nguyên."
	it_lbl.add_theme_font_size_override("font_size", 10)
	it_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	it_vbox.add_child(it_lbl)

	var it_row1 := HBoxContainer.new()
	it_row1.add_theme_constant_override("separation", 6)
	it_vbox.add_child(it_row1)
	_create_quick_button(it_row1, "🔮 Full Vé Huyết Kính Ấn (+1..+6)", func(): _give_bundle(-556, "Đã nhận Full 6 Vé Illusion Temple!"), Color(0.9, 0.6, 1.0))
	_create_quick_button(it_row1, "🛠️ NL Ép (Giấy Cổ + Khế Ước + Chaos)", _give_it_materials, Color(1.0, 0.85, 0.4))
	_create_quick_button(it_row1, "🎟️ Vé IT Ticket", func(): _give_single_item(13, 61, 0, "Vé Đền Ảo Ảnh"), Color(0.7, 0.9, 1.0))

	var it_row_lv := HBoxContainer.new()
	it_row_lv.add_theme_constant_override("separation", 4)
	it_vbox.add_child(it_row_lv)
	for lv in range(1, 7):
		_create_quick_button(it_row_lv, "IT +%d" % lv, func(): _give_single_item(13, 51, lv, "Huyết Kính Ấn (Illusion Temple +%d)" % lv), Color(0.9, 0.7, 1.0))

	# 7. PHÓ BẢN IMPERIAL GUARDIAN & DOPPELGANGER
	var ig_card := _create_event_card(vbox, "👑 PHÓ BẢN IMPERIAL GUARDIAN & DOPPELGANGER", Color(1.0, 0.8, 0.4))
	var ig_vbox = ig_card.get_child(0)
	var ig_lbl := Label.new()
	ig_lbl.text = "Lệnh Bài Gaion (Gaion's Order), Sách Khải Huyền Hoàn Chỉnh (Complete Secromicon), Gương Không Gian (Doppelganger)."
	ig_lbl.add_theme_font_size_override("font_size", 10)
	ig_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ig_vbox.add_child(ig_lbl)

	var ig_row1 := HBoxContainer.new()
	ig_row1.add_theme_constant_override("separation", 6)
	ig_vbox.add_child(ig_row1)
	_create_quick_button(ig_row1, "👑 Lệnh Bài Gaion", func(): _give_single_item(14, 102, 0, "Lệnh Bài Gaion"), Color(1.0, 0.85, 0.3))
	_create_quick_button(ig_row1, "📜 Sách Khải Huyền (Secromicon)", func(): _give_single_item(14, 109, 0, "Sách Khải Huyền Hoàn Chỉnh"), Color(0.9, 0.7, 1.0))
	_create_quick_button(ig_row1, "🪞 Gương Không Gian (Doppel)", func(): _give_single_item(14, 111, 0, "Gương Chiều Không Gian"), Color(0.4, 0.9, 1.0))
	_create_quick_button(ig_row1, "✨ Dấu Ấn Không Gian", func(): _give_single_item(14, 110, 0, "Dấu Ấn Không Gian"), Color(0.6, 0.9, 0.6))

	var ig_row2 := HBoxContainer.new()
	ig_row2.add_theme_constant_override("separation", 6)
	ig_vbox.add_child(ig_row2)
	_create_quick_button(ig_row2, "🎟️ Vé Doppelganger", func(): _give_single_item(13, 125, 0, "Vé Vùng Đất Bóng Ma"), Color(0.8, 0.6, 1.0))
	_create_quick_button(ig_row2, "🏰 Vé Pháo Đài Varka", func(): _give_single_item(13, 126, 0, "Vé Pháo Đài Varka"), Color(1.0, 0.7, 0.4))
	_create_quick_button(ig_row2, "🔥 Vé Varka Tầng 7", func(): _give_single_item(13, 127, 0, "Vé Varka Tầng 7"), Color(1.0, 0.5, 0.4))
	_create_quick_button(ig_row2, "🧩 6 Mảnh Sách Khải Huyền", _give_secromicon_fragments, Color(1.0, 0.9, 0.5))

	# 8. CRYWOLF, KANTURU & CÔNG THÀNH CHIẾN (CASTLE SIEGE)
	var ctc_card := _create_event_card(vbox, "🛡️ PHÁO ĐÀI CRYWOLF, THÁP KANTURU & CÔNG THÀNH CHIẾN", Color(0.6, 0.95, 0.6))
	var ctc_vbox = ctc_card.get_child(0)
	var ctc_lbl := Label.new()
	ctc_lbl.text = "Hợp Đồng Triệu Hồi Crywolf, Dây Chuyền Ánh Trăng Kanturu (Moonstone Pendant), Đá Sinh Mệnh Life Stone, Huy Hiệu Hoàng Tộc, Dấu Ấn Lãnh Chúa."
	ctc_lbl.add_theme_font_size_override("font_size", 10)
	ctc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ctc_vbox.add_child(ctc_lbl)

	var ctc_row1 := HBoxContainer.new()
	ctc_row1.add_theme_constant_override("separation", 6)
	ctc_vbox.add_child(ctc_row1)
	_create_quick_button(ctc_row1, "🐺 Triệu Hồi Crywolf", func(): _give_single_item(13, 7, 0, "Hợp Đồng Triệu Hồi Crywolf"), Color(1.0, 0.8, 0.4))
	_create_quick_button(ctc_row1, "🌙 Dây Chuyền Kanturu", func(): _give_single_item(13, 38, 0, "Dây Chuyền Mặt Trăng Kanturu"), Color(0.5, 0.9, 1.0))
	_create_quick_button(ctc_row1, "💎 Đá Sinh Mệnh (Life Stone)", func(): _give_single_item(13, 11, 1, "Đá Sinh Mệnh Life Stone"), Color(0.4, 1.0, 0.6))

	var ctc_row2 := HBoxContainer.new()
	ctc_row2.add_theme_constant_override("separation", 6)
	ctc_vbox.add_child(ctc_row2)
	_create_quick_button(ctc_row2, "👑 Huy Hiệu Hoàng Tộc", func(): _give_single_item(13, 31, 0, "Huy Hiệu Hoàng Tộc"), Color(1.0, 0.9, 0.3))
	_create_quick_button(ctc_row2, "🛡️ Dấu Ấn Lãnh Chúa", func(): _give_single_item(14, 21, 0, "Dấu Ấn Lãnh Chúa (Sign of Lord)"), Color(0.9, 0.8, 0.5))
	_create_quick_button(ctc_row2, "🧪 Thuốc Công Thành Bless/Soul", _give_siege_potions, Color(0.6, 0.8, 1.0))

	# 9. NHIỆM VỤ CHUYỂN CẤP (CLASS 2 & 3 QUESTS)
	var q_card := _create_event_card(vbox, "📜 VẬT PHẨM NHIỆM VỤ CHUYỂN CẤP 2 & 3", Color(0.9, 0.8, 0.5))
	var q_vbox = q_card.get_child(0)
	var q_lbl := Label.new()
	q_lbl.text = "Sách Đế Vương, Gươm Gãy, Nước Mắt Tiên Nữ, Linh Hồn Phù Thủy, Lông Vũ Condor, Ngọn Lửa Condor, Lửa Hiệp Sĩ, Lông Phượng Hoàng."
	q_lbl.add_theme_font_size_override("font_size", 10)
	q_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	q_vbox.add_child(q_lbl)

	var q_row1 := HBoxContainer.new()
	q_row1.add_theme_constant_override("separation", 6)
	q_vbox.add_child(q_row1)
	_create_quick_button(q_row1, "📜 Combo Nhiệm Vụ Cấp 2", _give_class2_quest_items, Color(1.0, 0.85, 0.3))
	_create_quick_button(q_row1, "🪽 Condor Ép Cánh Cấp 3", _give_condor_materials, Color(0.9, 0.6, 1.0))
	_create_quick_button(q_row1, "🔥 Combo Đổi Class Cấp 3", _give_class3_quest_items, Color(1.0, 0.5, 0.4))

	var q_row2 := HBoxContainer.new()
	q_row2.add_theme_constant_override("separation", 6)
	q_vbox.add_child(q_row2)
	_create_quick_button(q_row2, "⚔️ Mở Khóa Combo DK (Marlon)", _unlock_marlon_combo, Color(0.2, 0.9, 1.0))
	_create_quick_button(q_row2, "⚡ Auto Combo Strike (Thử Nghiệm)", _test_auto_combo, Color(1.0, 0.5, 0.1))

	# 10. HỘP BÁU KUNDUN & SỰ KIỆN LỄ HỘI
	var b_card := _create_event_card(vbox, "🎁 HỘP BÁU KUNDUN & SỰ KIỆN LỄ HỘI", Color(1.0, 0.85, 0.3))
	var b_vbox = b_card.get_child(0)
	var b_lbl := Label.new()
	b_lbl.text = "Hộp Kundun +1..+5 (Rơi Đồ Hoàn Hảo), Hộp May Mắn, Trái Tim Yêu Thương, Hoa Anh Đào, Thiệp Làng Santa, Rương Vàng / Bạc."
	b_lbl.add_theme_font_size_override("font_size", 10)
	b_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	b_vbox.add_child(b_lbl)

	var b_row1 := HBoxContainer.new()
	b_row1.add_theme_constant_override("separation", 6)
	b_vbox.add_child(b_row1)
	_create_quick_button(b_row1, "👑 Combo 5 Hộp Kundun (+1..+5)", _give_kundun_boxes, Color(1.0, 0.85, 0.2))
	_create_quick_button(b_row1, "💖 Hộp May Mắn & Trái Tim", _give_luck_and_heart, Color(1.0, 0.6, 0.8))
	_create_quick_button(b_row1, "🌸 Trọn Bộ Hoa Anh Đào", _give_cherry_blossom, Color(1.0, 0.7, 0.9))

	var b_row2 := HBoxContainer.new()
	b_row2.add_theme_constant_override("separation", 6)
	b_vbox.add_child(b_row2)
	_create_quick_button(b_row2, "🎅 Thiệp Mời Làng Santa", func(): _give_single_item(13, 66, 0, "Thiệp Mời Đến Làng Santa"), Color(0.9, 0.3, 0.3))
	_create_quick_button(b_row2, "🗝️ Rương Vàng / Bạc & Chìa Khóa", _give_gold_silver_chests, Color(1.0, 0.85, 0.4))
	_create_quick_button(b_row2, "🎆 Pháo Hoa May Mắn", func(): _give_single_item(14, 63, 0, "Pháo Hoa May Mắn"), Color(0.4, 1.0, 0.5))

	# 11. SỰ KIỆN RỒNG ĐỎ & BINH ĐOÀN HOÀNG KIM (RED DRAGON & GOLDEN INVASION)
	var dragon_card := _create_event_card(vbox, "🔥 SỰ KIỆN RỒNG ĐỎ & BINH ĐOÀN HOÀNG KIM (SKY DRAGONS)", Color(1.0, 0.4, 0.15))
	var d_vbox = dragon_card.get_child(0)
	var d_lbl := Label.new()
	d_lbl.text = "Rồng Đỏ và Rồng Vàng bay trên bầu trời qua đầu người chơi như game gốc MU Online. Kích hoạt xuất hiện UI Rồng Đỏ và bầy rồng tuần tra không trung."
	d_lbl.add_theme_font_size_override("font_size", 10)
	d_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	d_vbox.add_child(d_lbl)

	var d_row1 := HBoxContainer.new()
	d_row1.add_theme_constant_override("separation", 6)
	d_vbox.add_child(d_row1)
	_create_quick_button(d_row1, "🔥 Kích Hoạt Rồng Đỏ Tấn Công (5 Phút)", func(): _force_event("red_dragon"), Color(1.0, 0.35, 0.15))
	_create_quick_button(d_row1, "👑 Binh Đoàn Rồng Vàng (5 Phút)", func(): _force_event("golden_invasion"), Color(1.0, 0.88, 0.2))

	var d_row2 := HBoxContainer.new()
	d_row2.add_theme_constant_override("separation", 6)
	d_vbox.add_child(d_row2)
	_create_quick_button(d_row2, "🐉 Bầy Rồng Bay Qua Đầu Ngay (Test Flyover)", _test_dragon_flyover, Color(0.3, 1.0, 0.6))
	_create_quick_button(d_row2, "🛡️ Nhận Thưởng Hộp Vàng & Ngọc Rồng", _give_dragon_rewards, Color(1.0, 0.65, 0.9))

func _create_event_card(parent: Control, title: String, title_color: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.65, 0.52, 0.28, 0.8)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", title_color)
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title_lbl)

	return pc

func _switch_tab(idx: int) -> void:
	if _view_char:
		_view_char.visible = (idx == 0)
	if _view_events:
		_view_events.visible = (idx == 1)
	if _tab_char_btn:
		_tab_char_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if idx == 0 else Color(0.7, 0.7, 0.7))
	if _tab_event_btn:
		_tab_event_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if idx == 1 else Color(0.7, 0.7, 0.7))
	if MuAudioManagerRes:
		MuAudioManagerRes.play_ui_click()

func _give_items(items: Array, success_msg: String = "") -> void:
	if not player:
		_notify("Lỗi: Không tìm thấy nhân vật!", Color.RED)
		return
	var count := 0
	for it in items:
		if player.inv_add(it):
			count += 1
	if count > 0:
		if MuAudioManagerRes:
			MuAudioManagerRes.play_jewel_drop()
		var msg := success_msg if success_msg != "" else ("Đã nhận %d vật phẩm vào túi đồ!" % count)
		_notify(msg, Color(0.2, 1.0, 0.5))
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.inventory_window:
			hud.inventory_window.visible = true
			hud.inventory_window.update_display()
	else:
		_notify("Túi đồ đã đầy! Hãy dọn bớt đồ trong túi trước.", Color.RED)

func _give_single_item(g: int, n: int, lv: int = 0, item_name: String = "") -> void:
	var it = MuItemsRes.make(g, n, lv)
	var dname = item_name if item_name != "" else MuItemsRes.display_name(it)
	_give_items([it], "Đã nhận: %s!" % dname)

func _give_bundle(category_id: int, msg: String = "") -> void:
	var items = MuItemsRes.get_event_bundle_items(category_id)
	_give_items(items, msg)

func _on_give_all_events_clicked() -> void:
	var items = MuItemsRes.get_all_event_tickets()
	_give_items(items, "⭐ GM: ĐÃ NHẬN TRỌN BỘ VÉ TẤT CẢ CÁC SỰ KIỆN CỦA GAME!")

func _clear_inventory() -> void:
	if not player:
		return
	player.inventory.clear()
	player.inventory_changed.emit()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_ui_click()
	_notify("🧹 GM: Đã dọn sạch toàn bộ túi đồ!", Color(1.0, 0.7, 0.3))
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.inventory_window:
		hud.inventory_window.update_display()

func _give_bc_materials() -> void:
	var items = []
	for lv in range(1, 9):
		items.append(MuItemsRes.make(13, 17, lv)) # Blood Bone
		items.append(MuItemsRes.make(13, 16, lv)) # Scroll of Archangel
		items.append(MuItemsRes.make(12, 15, 0))  # Jewel of Chaos
	_give_items(items, "Đã nhận bộ nguyên liệu ép vé Blood Castle (+1..+8)!")

func _give_archangel_weapons() -> void:
	var items = [
		MuItemsRes.make(13, 19, 0), # Absolute Weapon of Archangel
		MuItemsRes.make(0, 19, 0, {"luck": true, "skill": true}), # Tuyệt Mệnh Kiếm
		MuItemsRes.make(5, 10, 0, {"luck": true, "skill": true}), # Gậy Tuyệt Mệnh
		MuItemsRes.make(4, 18, 0, {"luck": true, "skill": true}), # Nỏ Tuyệt Mệnh
		MuItemsRes.make(2, 13, 0, {"luck": true, "skill": true}), # Quyền Trượng Tuyệt Mệnh
	]
	_give_items(items, "Đã nhận bộ Vũ Khí Thiên Sứ Archangel!")

func _give_ds_materials() -> void:
	var items = []
	for lv in range(1, 8):
		items.append(MuItemsRes.make(14, 17, lv)) # Devil's Eye
		items.append(MuItemsRes.make(14, 18, lv)) # Devil's Key
		items.append(MuItemsRes.make(12, 15, 0))  # Jewel of Chaos
	_give_items(items, "Đã nhận bộ nguyên liệu ép vé Devil Square (+1..+7)!")

func _give_kalima_maps() -> void:
	var items = []
	for lv in range(1, 8):
		items.append(MuItemsRes.make(14, 28, lv))
	_give_items(items, "Đã nhận Full 7 Bản Đồ Kalima (Lost Map +1..+7)!")

func _give_kundun_symbols() -> void:
	var items = []
	for lv in range(1, 8):
		items.append(MuItemsRes.make(14, 29, lv))
	_give_items(items, "Đã nhận Full Huy Hiệu Kundun (Symbol of Kundun +1..+7)!")

func _give_it_materials() -> void:
	var items = []
	for lv in range(1, 7):
		items.append(MuItemsRes.make(13, 49, lv)) # Old Scroll
		items.append(MuItemsRes.make(13, 50, lv)) # Covenant
		items.append(MuItemsRes.make(12, 15, 0))  # Chaos
	_give_items(items, "Đã nhận bộ nguyên liệu ép vé Illusion Temple (+1..+6)!")

func _give_secromicon_fragments() -> void:
	var items = []
	for frag in range(103, 109):
		items.append(MuItemsRes.make(14, frag, 0))
	_give_items(items, "Đã nhận trọn bộ 6 Mảnh Sách Khải Huyền Secromicon!")

func _give_siege_potions() -> void:
	var items = [
		MuItemsRes.make(14, 7, 0), # Potion of Bless
		MuItemsRes.make(14, 7, 1), # Potion of Soul
	]
	_give_items(items, "Đã nhận Thuốc Công Thành (Potion of Bless & Soul)!")

func _give_class2_quest_items() -> void:
	var items = [
		MuItemsRes.make(14, 23, 0), # Cuốn Sách Đế Vương
		MuItemsRes.make(14, 24, 0), # Gươm Gãy (DK)
		MuItemsRes.make(14, 25, 0), # Nước Mắt Tiên Nữ (Elf)
		MuItemsRes.make(14, 26, 0), # Linh Hồn Phù Thủy (DW)
	]
	_give_items(items, "Đã nhận trọn bộ Vật Phẩm Nhiệm Vụ Cấp 2!")

func _give_condor_materials() -> void:
	var items = [
		MuItemsRes.make(13, 53, 0), # Lông Vũ Condor
		MuItemsRes.make(13, 52, 0), # Ngọn Lửa Condor
		MuItemsRes.make(12, 15, 0), # Jewel of Chaos
		MuItemsRes.make(14, 22, 0), # Jewel of Creation
		MuItemsRes.make(12, 31, 0), # Cụm Soul 10
		MuItemsRes.make(12, 30, 0), # Cụm Bless 10
	]
	_give_items(items, "Đã nhận bộ nguyên liệu ép Cánh Cấp 3 (Condor Feather & Flame)!")

func _give_class3_quest_items() -> void:
	var items = [
		MuItemsRes.make(14, 65, 0), # Lửa Hiệp Sĩ Tia Chớp
		MuItemsRes.make(14, 67, 0), # Lông Phượng Hoàng
		MuItemsRes.make(14, 68, 0), # Mắt Quỷ Sâu Thẳm
	]
	_give_items(items, "Đã nhận bộ Vật Phẩm Nhiệm Vụ Chuyển Class Cấp 3!")

func _unlock_marlon_combo() -> void:
	if not player:
		return
	player.has_combo_skill = true
	player.quest_marlon_step = 3
	# Học trọn bộ skill Combo DK chuẩn gốc (19..23: vũ khí, 41..43, 232: class)
	for s_id in [19, 20, 21, 22, 23, 41, 42, 43, 232]:
		if not s_id in player.learned_skills:
			player.learned_skills.append(s_id)
	player._init_skills()
	player.emit_signal("skills_updated")
	_notify("★ [GM] Đã mở khóa Combo Skill & nạp trọn bộ kỹ năng Combo Blade Knight!", Color(0.2, 0.9, 1.0))
	if player.has_method("_say"):
		player._say("[color=#00FFFF]★ Đã mở khóa Combo Marlon! Quy tắc: Bước 1 (Vũ khí 19..23) -> Bước 2 (41,42,43,232) -> Bước 3 (Khác Bước 2) để nổ Combo bộc phá.[/color]")

func _test_auto_combo() -> void:
	if not player:
		return
	if not player.has_combo_skill:
		_unlock_marlon_combo()
	if player.has_method("trigger_auto_combo_strike"):
		player.trigger_auto_combo_strike()

func _give_kundun_boxes() -> void:
	var items = []
	for k in range(55, 60):
		items.append(MuItemsRes.make(14, k, 0))
	_give_items(items, "Đã nhận Combo 5 Loại Hộp Kundun (+1 đến +5)!")

func _give_jewels() -> void:
	var items = [
		MuItemsRes.make(12, 15, 0), # Jewel of Chaos
		MuItemsRes.make(14, 13, 0), # Jewel of Bless
		MuItemsRes.make(14, 14, 0), # Jewel of Soul
		MuItemsRes.make(14, 16, 0), # Jewel of Life
		MuItemsRes.make(14, 22, 0), # Jewel of Creation
		MuItemsRes.make(14, 31, 0), # Jewel of Guardian
		MuItemsRes.make(14, 42, 0), # Jewel of Harmony
	]
	_give_items(items, "⭐ GM: Đã nhận trọn bộ Ngọc Quý (Bless, Soul, Chaos, Life, Creation, Harmony)!")


func _give_luck_and_heart() -> void:
	var items = [
		MuItemsRes.make(14, 11, 0), # Box of Luck
		MuItemsRes.make(14, 12, 0), # Heart of Love
		MuItemsRes.make(14, 32, 0), # Pink Chocolate Box
		MuItemsRes.make(14, 33, 0), # Red Chocolate Box
		MuItemsRes.make(14, 34, 0), # Blue Chocolate Box
	]
	_give_items(items, "Đã nhận Hộp May Mắn, Trái Tim Yêu Thương & Hộp Sô-cô-la!")

func _give_cherry_blossom() -> void:
	var items = [
		MuItemsRes.make(14, 84, 0), # Cherry Blossom Play-Box
		MuItemsRes.make(14, 85, 0), # Wine
		MuItemsRes.make(14, 86, 0), # Rice Cake
		MuItemsRes.make(14, 87, 0), # Flower Petal
		MuItemsRes.make(14, 88, 0), # White Branch
		MuItemsRes.make(14, 89, 0), # Red Branch
		MuItemsRes.make(14, 90, 0), # Golden Branch
	]
	_give_items(items, "Đã nhận trọn bộ Sự Kiện Hoa Anh Đào!")

func _give_gold_silver_chests() -> void:
	var items = [
		MuItemsRes.make(14, 123, 0), # Golden Box
		MuItemsRes.make(14, 124, 0), # Silver Box
		MuItemsRes.make(14, 113, 0), # Gold Key
		MuItemsRes.make(14, 112, 0), # Silver Key
		MuItemsRes.make(14, 121, 0), # Sealed Golden Box
		MuItemsRes.make(14, 122, 0), # Sealed Silver Box
	]
	_give_items(items, "Đã nhận bộ Rương Vàng / Bạc & Chìa Khóa!")

# ==============================================================================
# HÀM HỖ TRỢ XÂY DỰNG UI
# ==============================================================================
func _create_group_box(parent: Control, pos: Vector2, size: Vector2, title: String) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.88)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.65, 0.52, 0.28, 0.8)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.position = Vector2(10, 5)
	title_lbl.size = Vector2(size.x - 20, 18)
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 2)
	p.add_child(title_lbl)

	return p

func _create_hero_label(title: String, val: String, val_color: Color) -> Label:
	var c := VBoxContainer.new()
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", 1)

	var l_t := Label.new()
	l_t.text = title
	l_t.add_theme_font_size_override("font_size", 9)
	l_t.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	l_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l_t)

	var l_v := Label.new()
	l_v.text = val
	l_v.add_theme_font_size_override("font_size", 12)
	l_v.add_theme_color_override("font_color", val_color)
	l_v.add_theme_color_override("font_outline_color", Color.BLACK)
	l_v.add_theme_constant_override("outline_size", 2)
	l_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l_v)

	return l_v

func _create_quick_button(parent: Control, text: String, cb: Callable, col: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ==============================================================================
# SỰ KIỆN KÉO THẢ CỬA SỔ
# ==============================================================================
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			_drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset

# ==============================================================================
# ĐỒNG BỘ VÀ CẬP NHẬT HIỂN THỊ
# ==============================================================================
func update_display() -> void:
	if not player:
		return

	if _lbl_hero_name:
		_lbl_hero_name.text = player.character_name if player.character_name != "" else "Hero"
	if _lbl_hero_class:
		var c_idx = player.char_class if "char_class" in player else 1
		if c_idx >= 0 and c_idx < CLASS_NAMES.size():
			_lbl_hero_class.text = CLASS_NAMES[c_idx]
	if _lbl_hero_level:
		_lbl_hero_level.text = "Lv. %d" % player.level
	if _lbl_hero_resets:
		_lbl_hero_resets.text = "%d lần" % player.resets
	if _lbl_hero_points:
		_lbl_hero_points.text = "%d" % player.stat_points
	if _lbl_hero_zen:
		_lbl_hero_zen.text = _format_number(player.zen)

	if _class_dropdown and "char_class" in player:
		_class_dropdown.select(player.char_class)

	_update_god_mode_button()

func _update_god_mode_button() -> void:
	if not _btn_god_mode or not player:
		return
	if player.infinite_hp_mp:
		_btn_god_mode.text = "🛡️ BẤT TỬ HP/MP: ĐANG BẬT"
		_btn_god_mode.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		_btn_god_mode.text = "🛡️ BẤT TỬ HP/MP: ĐANG TẮT"
		_btn_god_mode.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

func _format_number(val: int) -> String:
	var s := str(val)
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res

# ==============================================================================
# XỬ LÝ HÀNH ĐỘNG BUFF CẤP ĐỘ
# ==============================================================================
func _on_input_level_changed(new_text: String) -> void:
	if new_text.is_valid_int():
		var val = clampi(new_text.to_int(), 1, 400)
		if _slider_level and int(_slider_level.value) != val:
			_slider_level.value = val

func _on_slider_level_changed(val: float) -> void:
	if _input_level and _input_level.text != str(int(val)):
		_input_level.text = str(int(val))

func _set_input_level(val: int) -> void:
	val = clampi(val, 1, 400)
	if _input_level:
		_input_level.text = str(val)
	if _slider_level:
		_slider_level.value = val

func _add_level(inc: int) -> void:
	var cur = _input_level.text.to_int() if _input_level and _input_level.text.is_valid_int() else (player.level if player else 1)
	_set_input_level(cur + inc)

func _on_apply_level_clicked() -> void:
	if not player:
		_notify("Lỗi: Không tìm thấy nhân vật!", Color.RED)
		return

	var target_lvl = _input_level.text.to_int() if _input_level and _input_level.text.is_valid_int() else 400
	target_lvl = clampi(target_lvl, 1, 400)
	var give_pts = _chk_give_points_on_level.button_pressed if _chk_give_points_on_level else true

	if player.has_method("set_level"):
		player.set_level(target_lvl, give_pts)
	else:
		player.level = target_lvl
		player.update_max_hp_mp()

	update_display()
	_sync_all_ui()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_coin_pickup()
	_notify("⚡ GM: Đã buff nhân vật lên Cấp %d thành công!" % target_lvl, Color(1.0, 0.9, 0.2))

# ==============================================================================
# XỬ LÝ HÀNH ĐỘNG RESET & CHUYỂN SINH
# ==============================================================================
func _add_resets(inc: int) -> void:
	var cur = _input_resets.text.to_int() if _input_resets and _input_resets.text.is_valid_int() else (player.resets if player else 0)
	_input_resets.text = str(maxi(0, cur + inc))

func _on_apply_resets_clicked() -> void:
	if not player:
		_notify("Lỗi: Không tìm thấy nhân vật!", Color.RED)
		return

	var target_resets = _input_resets.text.to_int() if _input_resets and _input_resets.text.is_valid_int() else 0
	target_resets = maxi(0, target_resets)
	var ppr = _input_points_per_reset.text.to_int() if _input_points_per_reset and _input_points_per_reset.text.is_valid_int() else 500
	ppr = maxi(0, ppr)

	if player.has_method("set_resets"):
		player.set_resets(target_resets, ppr)
	else:
		player.resets = target_resets

	update_display()
	_sync_all_ui()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_coin_pickup()
	_notify("👑 GM: Đã cài đặt số lần Reset thành: %d lần (+Point tương ứng)!" % target_resets, Color(0.4, 1.0, 0.8))

func _on_perform_one_reset_clicked() -> void:
	if not player:
		_notify("Lỗi: Không tìm thấy nhân vật!", Color.RED)
		return

	var ppr = _input_points_per_reset.text.to_int() if _input_points_per_reset and _input_points_per_reset.text.is_valid_int() else 500
	var reset_stats = _chk_reset_stats_on_reset.button_pressed if _chk_reset_stats_on_reset else false

	if player.has_method("perform_reset"):
		player.perform_reset(ppr, 1, reset_stats)
	else:
		player.resets += 1
		player.level = 1
		player.stat_points += ppr

	_input_level.text = "1"
	if _slider_level:
		_slider_level.value = 1
	_input_resets.text = str(player.resets)

	update_display()
	_sync_all_ui()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_coin_pickup()
	_notify("🔄 GM: THỰC HIỆN RESET THÀNH CÔNG! Đạt %d lần Reset (+%d Point)!" % [player.resets, ppr], Color(1.0, 0.8, 0.3))

func _on_reset_stats_clicked() -> void:
	if not player:
		return
	player.reset_stat_points()
	update_display()
	_sync_all_ui()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_ui_click()
	_notify("🔄 GM: Đã tẩy toàn bộ điểm Stat về mặc định! Hoàn lại %d Point." % player.stat_points, Color(0.9, 0.7, 0.4))

# ==============================================================================
# XỬ LÝ TIỆN ÍCH GM BỔ TRỢ (PERKS)
# ==============================================================================
func _on_toggle_god_mode_clicked() -> void:
	if not player:
		return
	var active = player.toggle_god_mode()
	_update_god_mode_button()
	_sync_all_ui()
	if active:
		_notify("🛡️ GM: BẬT BẤT TỬ HP/MP (Không bao giờ hết Máu & Mana)!", Color(0.2, 1.0, 0.4))
	else:
		_notify("🛡️ GM: ĐÃ TẮT BẤT TỬ.", Color(1.0, 0.7, 0.4))

func _add_points(amt: int) -> void:
	if not player:
		return
	player.gm_add_points(amt)
	update_display()
	_sync_all_ui()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_coin_pickup()
	_notify("✨ GM: Đã cộng +%s Point nâng chỉ số!" % _format_number(amt), Color(1.0, 0.9, 0.3))

func _add_zen(amt: int) -> void:
	if not player:
		return
	player.add_zen(amt)
	update_display()
	_sync_all_ui()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_coin_pickup()
	_notify("💰 GM: Đã cộng +%s Zen vào túi đồ!" % _format_number(amt), Color(1.0, 0.85, 0.3))

func _on_learn_class_skills_clicked() -> void:
	if not player:
		return
	var n = player.learn_all_skills(false)
	var c_idx = player.char_class if "char_class" in player else 1
	var cname: String = CLASS_NAMES[c_idx] if c_idx >= 0 and c_idx < CLASS_NAMES.size() else "Class"
	_notify("⚡ GM: Đã mở khóa toàn bộ kỹ năng cho %s!" % cname, Color(0.4, 0.9, 1.0))

func _on_learn_all_skills_clicked() -> void:
	if not player:
		return
	var n = player.learn_all_skills(true)
	_notify("🌟 GM: Đã mở khóa TOÀN BỘ %d kỹ năng game cho mọi Class!" % player.learned_skills.size(), Color(0.4, 1.0, 0.4))

func _on_class_selected(idx: int) -> void:
	if not player:
		return
	if idx != player.char_class:
		player.set_class(idx)
		update_display()
		_sync_all_ui()
		_notify("🧙 GM: Đã chuyển sang lớp nhân vật %s!" % CLASS_NAMES[idx], Color(0.9, 0.8, 0.5))

func _teleport_to(map_id: int, grid_pos: Vector2i) -> void:
	if not player:
		return
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("teleport_player"):
		hud.teleport_player(map_id, grid_pos)
		_notify("🚀 GM: Đã dịch chuyển tức thời!", Color(0.6, 0.8, 1.0))
	else:
		player.grid_x = grid_pos.x
		player.grid_y = grid_pos.y
		player.global_position = MuWorldRes.grid_to_world(grid_pos.x, grid_pos.y)
		_notify("🚀 GM: Đã dịch chuyển đến tọa độ (%d, %d)!" % [grid_pos.x, grid_pos.y], Color(0.6, 0.8, 1.0))

func _on_open_item_picker_clicked() -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_item_picker"):
		hud.toggle_item_picker()
	visible = false

# Đồng bộ dữ liệu sang các UI khác
func _sync_all_ui() -> void:
	var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
	if stats_win and stats_win.has_method("update_stats"):
		stats_win.update_stats()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud:
		var status_widget = hud.get_node_or_null("MuPlayerStatusWidget")
		if status_widget and status_widget.has_method("_update_player_info"):
			status_widget._update_player_info()
			status_widget._on_exp_changed(player.current_exp, player.max_exp, player.level)

func _notify(text: String, col: Color = Color.WHITE) -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(text, col)
	var chat = get_tree().get_first_node_in_group("ChatWindow")
	if chat and chat.has_method("add_system_message"):
		var hex = col.to_html(false)
		chat.add_system_message("[color=#%s]%s[/color]" % [hex, text])

func _show_notification(text: String, col: Color = Color.WHITE) -> void:
	_notify(text, col)

func _force_event(eid: String) -> void:
	var mgr = get_tree().get_first_node_in_group("MuEventManager") if get_tree() else null
	if mgr and mgr.has_method("force_start_event"):
		mgr.force_start_event(eid, 300)
		_notify("⚡ GM: Đã kích hoạt khẩn cấp sự kiện '%s' (mở cửa 5 phút)!" % eid, Color(1.0, 0.85, 0.3))

func _test_dragon_flyover() -> void:
	var flock = get_tree().get_first_node_in_group("DragonFlockManager") if get_tree() else null
	if flock and flock.has_method("trigger_test_flyover"):
		flock.trigger_test_flyover()
		_notify("🐉 GM: Bầy Rồng Đỏ & Rồng Vàng đang bay sải cánh qua đầu!", Color(1.0, 0.45, 0.2))
	else:
		_notify("⚠️ Không tìm thấy DragonFlockManager trong thế giới hiện tại!", Color(1.0, 0.3, 0.3))

func _give_dragon_rewards() -> void:
	# Cấp Hộp Kundun 1-5 và Ngọc Rồng
	_give_kundun_boxes()
	_give_jewels()
	_notify("⭐ GM: Đã nhận phần thưởng Săn Rồng (Hộp Kundun + Ngọc Quý)!", Color(1.0, 0.88, 0.2))
