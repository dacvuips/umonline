extends Control
class_name CharacterStatsWindow

## Bảng Chỉ Số Nhân Vật (Character Stats - Phím C) chuẩn 100% MU Online Season 6
## Tái hiện chính xác nguyên bản giao diện MU Online gốc:
## - Khung viền và hoa văn rồng (newui_item_back04)
## - Tên nhân vật (testgmDl / tên player), Subserver ([Valhalla-1 (Gold Non-PvP)])
## - Khung tóm tắt Level, EXP, [+]:100%|[-]:100%, Added/Removed fruit
## - Điểm cộng còn lại (Point: 20000)
## - Các ô chỉ số chuẩn MU (STR, AGI, STA, ENG, Command) kèm nút [+] Level-up
## - Sát thương Dmg(rate), Attack rate, Phòng thủ Defense (rate), Attack speed, Defense rate, HP, Mana, Skill Damage
## - 4 nút chức năng chân bảng: Thoát [X], Nhiệm vụ, Thú nuôi, Bảng Master Skill
## - Hỗ trợ cầm kéo di chuyển cửa sổ (Draggable) mượt mà, double click để dock lại vị trí gốc

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")

const S := 1.5
const W := 190.0
const H := 429.0

var player: MuPlayer = null
var add_multiplier: int = 1
var user_has_dragged: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 5.0

var lbl_name: Label
var lbl_server: Label

# Summary box labels
var lbl_level: Label
var lbl_exp: Label
var lbl_fruit_rate: Label
var lbl_fruit_stats: Label

# Points & Multiplier
var lbl_points: Label
var btn_mult_badge: Button
var btn_gm_toggle: Button

# Stat labels and buttons
var lbl_str_val: Label
var lbl_agi_val: Label
var lbl_vit_val: Label
var lbl_ene_val: Label
var lbl_cmd_val: Label

var btn_add_str: TextureButton
var btn_add_agi: TextureButton
var btn_add_vit: TextureButton
var btn_add_ene: TextureButton
var btn_add_cmd: TextureButton

var row_cmd: Control = null

# Derived stats labels
var lbl_dmg: Label
var lbl_atk_rate: Label
var lbl_def: Label
var lbl_atk_speed: Label
var lbl_def_rate: Label
var lbl_hp: Label
var lbl_mana: Label
var lbl_skill_dmg: Label

# GM Drawer
var gm_drawer: PanelContainer = null
var _btn_god_mode: Button = null
var _btn_mults: Array[Button] = []

# Stat Allocation Dialog Popup
var _stat_dialog_overlay: Control = null
var _stat_dialog: Panel = null
var _stat_dialog_title: Label = null
var _stat_dialog_avail_lbl: Label = null
var _stat_dialog_preview_lbl: Label = null
var _stat_input: LineEdit = null
var _stat_current_val: int = 1
var _selected_stat_code: String = ""
var _selected_stat_label: String = ""

func _ready() -> void:
	visible = false
	add_to_group("CharacterStatsWindow")
	for c in get_children():
		c.queue_free()

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = W * S
	offset_bottom = H * S
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S

	# 1. Dựng khung MU nguyên bản với hoa văn rồng newui_item_back04
	MuUiSkinRes.build_frame(self, "", W, H, "newui_item_back04")

	# 2. Vùng header kéo thả cửa sổ (Drag Header)
	_setup_drag_header()

	# 3. Nút đóng cửa sổ ở góc trên phải (ẩn hình ảnh nhưng vẫn nhận click đóng)
	MuUiSkinRes.close_button(self, W, close, true)

	# 4. Tên nhân vật & Sub-server
	lbl_name = MuUiSkinRes.font_label("Hero", 13, Color(0.59, 1.0, 0.94)) # Cyan / PK-0
	lbl_name.position = Vector2(0, 11 * S)
	lbl_name.size = Vector2(W * S, 18 * S)
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl_name)

	lbl_server = MuUiSkinRes.font_label("[Valhalla-1 (Gold Non-PvP)]", 10, Color(0.9, 0.9, 0.95))
	lbl_server.position = Vector2(0, 26 * S)
	lbl_server.size = Vector2(W * S, 16 * S)
	lbl_server.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl_server)

	# 5. Khung tóm tắt Level / EXP / Fruit (RenderFrame chuẩn)
	_setup_summary_box()

	# 6. Hàng Điểm cộng (Point: X) và Nút chọn bội số cộng
	_setup_points_row()

	# 7. Các hàng chỉ số chính (STR, AGI, STA, ENG, Command)
	_setup_stat_rows()

	# 8. 4 nút chân bảng MU Season 6 (Exit, Quest, Pet, Master Level)
	_setup_bottom_buttons()

	# 9. Thanh công cụ GM mở rộng (Collapsible GM Drawer)
	_setup_gm_drawer()

	# 10. Popup cộng điểm chỉ số tuỳ chỉnh
	_setup_stat_dialog()

	_place()
	get_viewport().size_changed.connect(_place)

func _setup_drag_header() -> void:
	var drag_bar := Control.new()
	drag_bar.name = "DragHeader"
	drag_bar.position = Vector2.ZERO
	drag_bar.size = Vector2(W - 30.0, 42.0) * S
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_bar.gui_input.connect(_on_drag_header_input)
	add_child(drag_bar)
	move_child(drag_bar, 0)

func _on_drag_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			user_has_dragged = false
			_notify_arrange()
			return
		_is_dragging = event.pressed
		_drag_start_pos = get_global_mouse_position()
		_drag_offset = get_global_mouse_position() - global_position
		if event.pressed:
			_bring_to_front()
	elif event is InputEventMouseMotion and _is_dragging:
		if not user_has_dragged:
			if (get_global_mouse_position() - _drag_start_pos).length() < DRAG_THRESHOLD:
				return
			user_has_dragged = true
		var vs := get_viewport_rect().size
		var np = get_global_mouse_position() - _drag_offset
		global_position = Vector2(clampf(np.x, 0.0, vs.x - size.x), clampf(np.y, 0.0, vs.y - size.y))

func _bring_to_front() -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.has_method("_bring_modal_to_front"):
		hud._bring_modal_to_front(self)
	else:
		move_to_front()

func _notify_arrange() -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.has_method("arrange_dock_windows"):
		hud.arrange_dock_windows()
	else:
		var vs := get_viewport_rect().size
		position = Vector2(vs.x - W * S, floorf(maxf(0.0, (vs.y - H * S) * 0.5)))

func _place() -> void:
	if user_has_dragged:
		return
	_notify_arrange()

func _add_rect_tex(parent: Control, tex_name: String, pos: Vector2, sz: Vector2) -> void:
	var r := TextureRect.new()
	r.texture = MuUiSkinRes.tex(tex_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _setup_summary_box() -> void:
	var box := Control.new()
	box.name = "SummaryBox"
	box.position = Vector2(12, 48) * S
	box.size = Vector2(166, 66) * S
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	# Nền tối mờ
	var fill := ColorRect.new()
	fill.color = Color(0.0, 0.0, 0.0, 0.45)
	fill.position = Vector2.ZERO
	fill.size = box.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fill)

	# 4 góc
	_add_rect_tex(box, "newui_item_table01(l)", Vector2(0, 0) * S, Vector2(14, 14) * S)
	_add_rect_tex(box, "newui_item_table01(r)", Vector2(166 - 14, 0) * S, Vector2(14, 14) * S)
	_add_rect_tex(box, "newui_item_table02(l)", Vector2(0, 66 - 14) * S, Vector2(14, 14) * S)
	_add_rect_tex(box, "newui_item_table02(r)", Vector2(166 - 14, 66 - 14) * S, Vector2(14, 14) * S)

	# 4 cạnh
	_add_rect_tex(box, "newui_item_table03(up)", Vector2(14, 0) * S, Vector2(166 - 28, 14) * S)
	_add_rect_tex(box, "newui_item_table03(dw)", Vector2(14, 66 - 14) * S, Vector2(166 - 28, 14) * S)
	_add_rect_tex(box, "newui_item_table03(l)", Vector2(0, 14) * S, Vector2(14, 66 - 28) * S)
	_add_rect_tex(box, "newui_item_table03(r)", Vector2(166 - 14, 14) * S, Vector2(14, 66 - 28) * S)

	# Đường phân cách ngang dưới dòng Level
	_add_rect_tex(box, "newui_item_table03(dw)", Vector2(2, 13) * S, Vector2(162, 3) * S)

	# Dòng 1: Level: 400 | Resets: 0 (Vàng đậm #e6e600)
	lbl_level = MuUiSkinRes.font_label("Level: 400 | Resets: 0", 11, Color(0.9, 0.9, 0.0))
	lbl_level.position = Vector2(8, 1) * S
	lbl_level.size = Vector2(150 * S, 14 * S)
	box.add_child(lbl_level)

	# Dòng 2: EXP: 3822148080 / 3892250000 (Trắng #ffffff)
	lbl_exp = MuUiSkinRes.font_label("EXP:3822148080 / 3892250000", 10, Color(1, 1, 1))
	lbl_exp.position = Vector2(8, 16) * S
	lbl_exp.size = Vector2(150 * S, 13 * S)
	box.add_child(lbl_exp)

	# Dòng 3: [+]:100%|[-]:100% (Xanh dương #4cc5fe)
	lbl_fruit_rate = MuUiSkinRes.font_label("[+]:100%|[-]:100%", 10, Color(0.30, 0.77, 1.0))
	lbl_fruit_rate.position = Vector2(8, 30) * S
	lbl_fruit_rate.size = Vector2(150 * S, 13 * S)
	box.add_child(lbl_fruit_rate)

	# Dòng 4: Added 0/127 | Removed 0/-127 (Xanh dương #4cc5fe)
	lbl_fruit_stats = MuUiSkinRes.font_label("Added 0/127 | Removed 0/-127", 10, Color(0.30, 0.77, 1.0))
	lbl_fruit_stats.position = Vector2(8, 44) * S
	lbl_fruit_stats.size = Vector2(150 * S, 13 * S)
	box.add_child(lbl_fruit_stats)

func _setup_points_row() -> void:
	# Nút chọn nhanh bội số cộng điểm [+1], click để xoay vòng: +1 -> +10 -> +100 -> +1k
	btn_mult_badge = Button.new()
	btn_mult_badge.text = "[+1]"
	btn_mult_badge.flat = true
	btn_mult_badge.position = Vector2(12, 115) * S
	btn_mult_badge.size = Vector2(38, 14) * S
	btn_mult_badge.add_theme_font_size_override("font_size", int(10 * S))
	btn_mult_badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	btn_mult_badge.tooltip_text = "Nhấp để đổi số điểm cộng mỗi click (+1, +10, +100, +1000)"
	btn_mult_badge.pressed.connect(_cycle_multiplier)
	add_child(btn_mult_badge)

	# Nút nhỏ bật/tắt bảng công cụ GM
	btn_gm_toggle = Button.new()
	btn_gm_toggle.text = "👑GM"
	btn_gm_toggle.flat = true
	btn_gm_toggle.position = Vector2(50, 115) * S
	btn_gm_toggle.size = Vector2(36, 14) * S
	btn_gm_toggle.add_theme_font_size_override("font_size", int(9 * S))
	btn_gm_toggle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	btn_gm_toggle.tooltip_text = "Bật/tắt thanh công cụ GM (Tẩy điểm, Buff điểm, Bất tử)"
	btn_gm_toggle.pressed.connect(_toggle_gm_drawer)
	add_child(btn_gm_toggle)

	# Dòng Point: 20000 (Cam đậm #ff8a00, căn phải)
	lbl_points = MuUiSkinRes.font_label("Point: 0", 11, Color(1.0, 0.54, 0.0))
	lbl_points.position = Vector2(75, 115) * S
	lbl_points.size = Vector2(102 * S, 15 * S)
	lbl_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lbl_points)

func _cycle_multiplier() -> void:
	match add_multiplier:
		1: add_multiplier = 10
		10: add_multiplier = 100
		100: add_multiplier = 1000
		_: add_multiplier = 1
	_update_mult_badge()
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _update_mult_badge() -> void:
	if btn_mult_badge:
		btn_mult_badge.text = "[+%d]" % add_multiplier if add_multiplier < 1000 else "[+1k]"
	_update_mult_buttons()

func _setup_stat_rows() -> void:
	# STR
	var res_str = _build_stat_row(self, "str", "STR", 128.0)
	lbl_str_val = res_str["val"]
	btn_add_str = res_str["btn"]
	lbl_dmg = MuUiSkinRes.font_label("Dmg(rate): 1854~2507 (8868)", 10, Color(1, 1, 1))
	lbl_dmg.position = Vector2(20, 150) * S
	lbl_dmg.size = Vector2(150 * S, 13 * S)
	add_child(lbl_dmg)
	lbl_atk_rate = MuUiSkinRes.font_label("Attack rate: 9200", 10, Color(1, 1, 1))
	lbl_atk_rate.position = Vector2(20, 163) * S
	lbl_atk_rate.size = Vector2(150 * S, 13 * S)
	add_child(lbl_atk_rate)

	# AGI
	var res_agi = _build_stat_row(self, "agi", "AGI", 183.0)
	lbl_agi_val = res_agi["val"]
	btn_add_agi = res_agi["btn"]
	lbl_def = MuUiSkinRes.font_label("Defense (rate):1549 (313 +31)", 10, Color(1, 1, 1))
	lbl_def.position = Vector2(20, 205) * S
	lbl_def.size = Vector2(150 * S, 13 * S)
	add_child(lbl_def)
	lbl_atk_speed = MuUiSkinRes.font_label("Attack speed: 200", 10, Color(1, 1, 1))
	lbl_atk_speed.position = Vector2(20, 218) * S
	lbl_atk_speed.size = Vector2(150 * S, 13 * S)
	add_child(lbl_atk_speed)
	lbl_def_rate = MuUiSkinRes.font_label("Defense rate: 1800", 10, Color(1, 1, 1))
	lbl_def_rate.position = Vector2(20, 231) * S
	lbl_def_rate.size = Vector2(150 * S, 13 * S)
	add_child(lbl_def_rate)

	# STA
	var res_vit = _build_stat_row(self, "vit", "STA", 248.0)
	lbl_vit_val = res_vit["val"]
	btn_add_vit = res_vit["btn"]
	lbl_hp = MuUiSkinRes.font_label("HP: 3940 / 4938", 10, Color(1, 1, 1))
	lbl_hp.position = Vector2(20, 270) * S
	lbl_hp.size = Vector2(150 * S, 13 * S)
	add_child(lbl_hp)

	# ENG
	var res_ene = _build_stat_row(self, "ene", "ENG", 303.0)
	lbl_ene_val = res_ene["val"]
	btn_add_ene = res_ene["btn"]
	lbl_mana = MuUiSkinRes.font_label("Mana: 3598 / 3598", 10, Color(1, 1, 1))
	lbl_mana.position = Vector2(20, 325) * S
	lbl_mana.size = Vector2(150 * S, 13 * S)
	add_child(lbl_mana)
	lbl_skill_dmg = MuUiSkinRes.font_label("Skill Damage: 300%", 10, Color(1, 1, 1))
	lbl_skill_dmg.position = Vector2(20, 338) * S
	lbl_skill_dmg.size = Vector2(150 * S, 13 * S)
	add_child(lbl_skill_dmg)

	# Command (Dark Lord)
	var res_cmd = _build_stat_row(self, "cmd", "Command", 358.0)
	row_cmd = res_cmd["row"]
	lbl_cmd_val = res_cmd["val"]
	btn_add_cmd = res_cmd["btn"]

func _build_stat_row(parent: Control, stat_code: String, label_text: String, y_ref: float) -> Dictionary:
	var row := Control.new()
	row.position = Vector2(0, y_ref) * S
	row.size = Vector2(W, 21) * S
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	# Textbox background 170x21
	var bg := TextureRect.new()
	bg.texture = MuUiSkinRes.tex("newui_cha_textbox02")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.position = Vector2(10, 0) * S
	bg.size = Vector2(170, 21) * S
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)

	# Tên chỉ số (Vàng đậm)
	var l_name := MuUiSkinRes.font_label(label_text, 11, Color(0.87, 0.75, 0.40))
	l_name.position = Vector2(18, 2) * S
	l_name.size = Vector2(55 * S, 17 * S)
	row.add_child(l_name)

	# Giá trị chỉ số (Xanh dương / Vàng)
	var l_val := MuUiSkinRes.font_label("0", 11, Color(0.39, 0.59, 1.0))
	l_val.position = Vector2(74, 2) * S
	l_val.size = Vector2(74 * S, 17 * S)
	l_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l_val)

	# Nút [+] Level-up 16x15
	var btn_add := TextureButton.new()
	btn_add.ignore_texture_size = true
	btn_add.stretch_mode = TextureButton.STRETCH_SCALE
	var btn_tex = MuUiSkinRes.tex("newui_chainfo_btn_level")
	if btn_tex:
		btn_add.texture_normal = MuUiSkinRes.atlas_sub(btn_tex, Rect2(0, 0, 16, 15))
		btn_add.texture_pressed = MuUiSkinRes.atlas_sub(btn_tex, Rect2(0, 15, 16, 15))
	btn_add.position = Vector2(153, 3) * S
	btn_add.size = Vector2(16, 15) * S
	btn_add.pressed.connect(func(): _on_stat_btn_pressed(stat_code, label_text))
	btn_add.tooltip_text = "Cộng điểm %s (Click: Mở popup nhập điểm | Shift: +10 | Ctrl: +100)" % label_text
	row.add_child(btn_add)

	return {"row": row, "val": l_val, "btn": btn_add}

func _setup_bottom_buttons() -> void:
	# 4 nút chân bảng MU Season 6 (kích thước 36x29 tại y = 391)
	var btn_exit = MuUiSkinRes.make_btn_2state("newui_exit_00", 36, 29, close)
	btn_exit.position = Vector2(13, 391) * S
	btn_exit.size = Vector2(36, 29) * S
	btn_exit.tooltip_text = "Đóng bảng (C)"
	add_child(btn_exit)

	var btn_quest = MuUiSkinRes.make_btn_2state("newui_chainfo_btn_quest", 36, 29, _on_quest_clicked)
	btn_quest.position = Vector2(50, 391) * S
	btn_quest.size = Vector2(36, 29) * S
	btn_quest.tooltip_text = "Bảng Nhiệm Vụ (T)"
	add_child(btn_quest)

	var btn_pet = MuUiSkinRes.make_btn_2state("newui_chainfo_btn_pet", 36, 29, _on_pet_clicked)
	btn_pet.position = Vector2(87, 391) * S
	btn_pet.size = Vector2(36, 29) * S
	btn_pet.tooltip_text = "Thông Tin Thú Nuôi / Thú Cưỡi"
	add_child(btn_pet)

	var btn_master = MuUiSkinRes.make_btn_2state("newui_chainfo_btn_master", 36, 29, _on_master_clicked)
	btn_master.position = Vector2(124, 391) * S
	btn_master.size = Vector2(36, 29) * S
	btn_master.tooltip_text = "Bảng Kỹ Năng Master (A)"
	add_child(btn_master)

func _setup_gm_drawer() -> void:
	gm_drawer = PanelContainer.new()
	gm_drawer.name = "GmDrawer"
	gm_drawer.position = Vector2(10, 426) * S
	gm_drawer.size = Vector2(170, 75) * S
	gm_drawer.visible = false
	add_child(gm_drawer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	gm_drawer.add_child(vbox)

	# Hàng 1: Multipliers
	var mult_row := HBoxContainer.new()
	mult_row.add_theme_constant_override("separation", 2)
	vbox.add_child(mult_row)

	var ml := Label.new()
	ml.text = "Cộng:"
	ml.add_theme_font_size_override("font_size", 9)
	mult_row.add_child(ml)

	for m in [1, 10, 100, 1000]:
		var b := Button.new()
		b.text = "+%d" % m if m < 1000 else "+1k"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 9)
		b.pressed.connect(func(): _set_multiplier(m))
		mult_row.add_child(b)
		_btn_mults.append(b)

	# Hàng 2: GM +1K & Tẩy điểm
	var gm_row := HBoxContainer.new()
	gm_row.add_theme_constant_override("separation", 4)
	vbox.add_child(gm_row)

	var b_add_pt = Button.new()
	b_add_pt.text = "✨ +1K Điểm"
	b_add_pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_add_pt.add_theme_font_size_override("font_size", 9)
	b_add_pt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	b_add_pt.pressed.connect(_on_gm_add_point_clicked)
	gm_row.add_child(b_add_pt)

	var b_rst = Button.new()
	b_rst.text = "🔄 Tẩy Điểm"
	b_rst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_rst.add_theme_font_size_override("font_size", 9)
	b_rst.add_theme_color_override("font_color", Color(0.9, 0.6, 0.4))
	b_rst.pressed.connect(_on_gm_reset_clicked)
	gm_row.add_child(b_rst)

	# Hàng 3: Bất tử HP/MP & Bảng GM
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 4)
	vbox.add_child(act_row)

	_btn_god_mode = Button.new()
	_btn_god_mode.text = "🛡️ Bất Tử HP"
	_btn_god_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_god_mode.add_theme_font_size_override("font_size", 9)
	_btn_god_mode.pressed.connect(_on_toggle_god_mode_clicked)
	act_row.add_child(_btn_god_mode)

	var b_open_gm = Button.new()
	b_open_gm.text = "👑 BẢNG GM"
	b_open_gm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_open_gm.add_theme_font_size_override("font_size", 9)
	b_open_gm.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	b_open_gm.pressed.connect(func():
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("toggle_gm_panel"):
			hud.toggle_gm_panel()
	)
	act_row.add_child(b_open_gm)

	_update_mult_buttons()

func _toggle_gm_drawer() -> void:
	if gm_drawer:
		gm_drawer.visible = not gm_drawer.visible
		if MuAudioManager:
			MuAudioManager.play_ui_click()

func _set_multiplier(m: int) -> void:
	add_multiplier = m
	_update_mult_badge()

func _update_mult_buttons() -> void:
	var mults = [1, 10, 100, 1000]
	for i in range(_btn_mults.size()):
		var b = _btn_mults[i]
		if mults[i] == add_multiplier:
			b.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			b.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func _on_gm_add_point_clicked() -> void:
	if player:
		player.gm_add_points(1000)
		update_stats()
		if MuAudioManager:
			MuAudioManager.play_ui_click()

func _on_gm_reset_clicked() -> void:
	if player:
		player.reset_stat_points()
		update_stats()
		if MuAudioManager:
			MuAudioManager.play_ui_click()

func _on_toggle_god_mode_clicked() -> void:
	if player:
		player.toggle_god_mode()
		update_stats()
		if MuAudioManager:
			MuAudioManager.play_ui_click()

func _on_quest_clicked() -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Bảng Nhiệm Vụ (Quest Info) - Đang phát triển", Color(1.0, 0.85, 0.4))
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_pet_clicked() -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_inventory"):
		hud.toggle_inventory()
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_master_clicked() -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_skill_window"):
		hud.toggle_skill_window()
	elif hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Bảng Kỹ Năng Master Tree", Color(0.4, 0.8, 1.0))
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player and not player.resets_changed.is_connected(_on_resets_changed):
		player.resets_changed.connect(_on_resets_changed)
	update_stats()

func _on_resets_changed(_new_resets: int) -> void:
	update_stats()

func _add_point(stat: String) -> void:
	if not player:
		return
	var amt = add_multiplier
	if Input.is_key_pressed(KEY_SHIFT):
		amt = maxi(amt, 10)
	if Input.is_key_pressed(KEY_CTRL):
		amt = maxi(amt, 100)

	if player.add_stat_point(stat, amt):
		update_stats()
		if MuAudioManager:
			MuAudioManager.play_ui_click()

func update_stats() -> void:
	if not player:
		return

	if lbl_name:
		var cls_title = player.get_class_display_name() if player.has_method("get_class_display_name") else ""
		if not cls_title.is_empty():
			lbl_name.text = "%s - %s" % [player.character_name, cls_title]
		else:
			lbl_name.text = player.character_name

	if lbl_server:
		if "guild_name" in player and not player.guild_name.is_empty():
			lbl_server.text = "[Guild: %s]" % player.guild_name
		else:
			lbl_server.text = "[Valhalla-1 (Gold Non-PvP)]"

	if lbl_level:
		lbl_level.text = "Level: %d | Resets: %d" % [player.level, player.resets]

	if lbl_exp:
		if player.level >= 400:
			lbl_exp.text = "EXP:3822148080 / 3892250000"
		else:
			lbl_exp.text = "EXP:%d / %d" % [player.current_exp, player.max_exp]

	if lbl_points:
		lbl_points.text = "Point: %d" % player.stat_points

	if lbl_str_val:
		lbl_str_val.text = "%d" % player.stat_str
	if lbl_agi_val:
		lbl_agi_val.text = "%d" % player.stat_agi
	if lbl_vit_val:
		lbl_vit_val.text = "%d" % player.stat_vit
	if lbl_ene_val:
		lbl_ene_val.text = "%d" % player.stat_ene
	if lbl_cmd_val:
		var cmd_val = player.get("stat_cmd")
		lbl_cmd_val.text = "%d" % (cmd_val if cmd_val != null else 25)

	# Tính toán chỉ số phái sinh chuẩn MU Online gốc
	var str_val: int = player.stat_str
	var agi_val: int = player.stat_agi
	var ene_val: int = player.stat_ene
	var lvl_val: int = player.level

	if lbl_dmg:
		var min_d = int(str_val / 6.0) + (186 if player.equipment.has("right") else 20)
		var max_d = int(str_val / 4.0) + (255 if player.equipment.has("right") else 35)
		var dmg_rate = int(lvl_val * 3 + str_val * 0.75 + agi_val * 0.5)
		lbl_dmg.text = "Dmg(rate): %d~%d (%d)" % [min_d, max_d, dmg_rate]

	if lbl_atk_rate:
		var atk_rate = int(lvl_val * 5 + str_val * 0.65 + agi_val * 0.5)
		lbl_atk_rate.text = "Attack rate: %d" % atk_rate

	if lbl_def:
		var def_val = player.defense_value()
		var def_rate_base = int(agi_val / 3.0)
		var def_bonus = 31 if def_val > 500 else 0
		lbl_def.text = "Defense (rate):%d (%d +%d)" % [def_val, def_rate_base, def_bonus]

	if lbl_atk_speed:
		var atk_speed = int(agi_val / 15.0) + 67
		lbl_atk_speed.text = "Attack speed: %d" % atk_speed

	if lbl_def_rate:
		var def_rate = int(agi_val / 2.0) + lvl_val * 2
		lbl_def_rate.text = "Defense rate: %d" % def_rate

	if lbl_hp:
		lbl_hp.text = "HP: %d / %d" % [player.current_hp, player.max_hp]

	if lbl_mana:
		lbl_mana.text = "Mana: %d / %d" % [player.current_mp, player.max_mp]

	if lbl_skill_dmg:
		var sk_pct = 200 + int(ene_val / 20.0)
		lbl_skill_dmg.text = "Skill Damage: %d%%" % sk_pct

	# Hiển thị nút cộng khi còn điểm
	var has_pts = player.stat_points > 0
	if btn_add_str: btn_add_str.visible = has_pts
	if btn_add_agi: btn_add_agi.visible = has_pts
	if btn_add_vit: btn_add_vit.visible = has_pts
	if btn_add_ene: btn_add_ene.visible = has_pts
	if btn_add_cmd: btn_add_cmd.visible = has_pts

	# Hàng Command hiển thị khi là Dark Lord hoặc có điểm command
	if row_cmd:
		var is_dl = (player.char_class == 4) or (player.get("stat_cmd") != null and player.stat_cmd > 0)
		row_cmd.visible = is_dl

	if _btn_god_mode:
		if player.infinite_hp_mp:
			_btn_god_mode.text = "🛡️ Bất Tử: BẬT"
			_btn_god_mode.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			_btn_god_mode.text = "🛡️ Bất Tử: TẮT"
			_btn_god_mode.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	# Cập nhật thông tin trong popup cộng điểm nếu đang mở
	if _stat_dialog and _stat_dialog.visible:
		if player.stat_points <= 0:
			_close_stat_dialog()
		else:
			if _stat_dialog_avail_lbl:
				_stat_dialog_avail_lbl.text = "Điểm có thể cộng: %d" % player.stat_points
			if _stat_current_val > player.stat_points:
				_stat_current_val = player.stat_points
				if _stat_input:
					_stat_input.text = str(_stat_current_val)
			_update_stat_dialog_preview()

func _setup_stat_dialog() -> void:
	# Overlay mờ toàn màn hình của bảng để chặn click bên dưới
	_stat_dialog_overlay = Control.new()
	_stat_dialog_overlay.name = "StatDialogOverlay"
	_stat_dialog_overlay.position = Vector2.ZERO
	_stat_dialog_overlay.size = Vector2(W, H) * S
	_stat_dialog_overlay.visible = false
	_stat_dialog_overlay.z_index = 10
	_stat_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_stat_dialog_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_stat_dialog()
	)
	add_child(_stat_dialog_overlay)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.5)
	dimmer.size = Vector2(W, H) * S
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stat_dialog_overlay.add_child(dimmer)

	# Khung Dialog Popup
	var dlg_w := 172.0
	var dlg_h := 166.0
	_stat_dialog = Panel.new()
	_stat_dialog.name = "StatDialog"
	_stat_dialog.position = Vector2(round((W - dlg_w) * 0.5), 130.0) * S
	_stat_dialog.size = Vector2(dlg_w, dlg_h) * S
	_stat_dialog.visible = false
	_stat_dialog.z_index = 11
	_stat_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_stat_dialog.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_bring_to_front()
	)

	var sb_dialog := StyleBoxFlat.new()
	sb_dialog.bg_color = Color(0.08, 0.07, 0.06, 0.98)
	sb_dialog.border_color = Color(0.82, 0.68, 0.32)
	sb_dialog.border_width_left = 1
	sb_dialog.border_width_top = 1
	sb_dialog.border_width_right = 1
	sb_dialog.border_width_bottom = 1
	sb_dialog.corner_radius_top_left = 4
	sb_dialog.corner_radius_top_right = 4
	sb_dialog.corner_radius_bottom_left = 4
	sb_dialog.corner_radius_bottom_right = 4
	sb_dialog.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	sb_dialog.shadow_size = 6
	_stat_dialog.add_theme_stylebox_override("panel", sb_dialog)
	add_child(_stat_dialog)

	# Tiêu đề Header bar
	var header := Panel.new()
	header.position = Vector2.ZERO
	header.size = Vector2(dlg_w, 24.0) * S
	var sb_hdr := StyleBoxFlat.new()
	sb_hdr.bg_color = Color(0.18, 0.14, 0.09, 1.0)
	sb_hdr.border_color = Color(0.65, 0.52, 0.25)
	sb_hdr.border_width_bottom = 1
	sb_hdr.corner_radius_top_left = 4
	sb_hdr.corner_radius_top_right = 4
	header.add_theme_stylebox_override("panel", sb_hdr)
	_stat_dialog.add_child(header)

	_stat_dialog_title = MuUiSkinRes.font_label("Cộng Điểm Sức Mạnh", 11, Color(1.0, 0.88, 0.45))
	_stat_dialog_title.position = Vector2(6, 4) * S
	_stat_dialog_title.size = Vector2(dlg_w - 28, 16) * S
	_stat_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_dialog.add_child(_stat_dialog_title)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.flat = true
	btn_close.position = Vector2(dlg_w - 22, 2) * S
	btn_close.size = Vector2(18, 20) * S
	btn_close.add_theme_font_size_override("font_size", int(10 * S))
	btn_close.add_theme_color_override("font_color", Color(0.85, 0.7, 0.45))
	btn_close.add_theme_color_override("font_hover_color", Color(1.0, 0.35, 0.35))
	btn_close.pressed.connect(_close_stat_dialog)
	_stat_dialog.add_child(btn_close)

	# Điểm có thể cộng
	_stat_dialog_avail_lbl = MuUiSkinRes.font_label("Điểm có thể cộng: 0", 10, Color(1.0, 0.65, 0.15))
	_stat_dialog_avail_lbl.position = Vector2(6, 28) * S
	_stat_dialog_avail_lbl.size = Vector2(dlg_w - 12, 16) * S
	_stat_dialog_avail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_dialog.add_child(_stat_dialog_avail_lbl)

	# Xem trước chỉ số sau khi cộng
	_stat_dialog_preview_lbl = MuUiSkinRes.font_label("Hiện tại: 0  ->  Sau cộng: 0 (+0)", 9, Color(0.4, 0.82, 1.0))
	_stat_dialog_preview_lbl.position = Vector2(6, 46) * S
	_stat_dialog_preview_lbl.size = Vector2(dlg_w - 12, 15) * S
	_stat_dialog_preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_dialog.add_child(_stat_dialog_preview_lbl)

	# Hàng nhập điểm có nút (-) và (+)
	var btn_minus := Button.new()
	btn_minus.text = "-"
	btn_minus.position = Vector2(16, 66) * S
	btn_minus.size = Vector2(28, 26) * S
	btn_minus.add_theme_font_size_override("font_size", int(14 * S))
	btn_minus.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	btn_minus.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	btn_minus.add_theme_stylebox_override("normal", _create_btn_style(Color(0.2, 0.16, 0.11, 0.95), Color(0.75, 0.62, 0.3)))
	btn_minus.add_theme_stylebox_override("hover", _create_btn_style(Color(0.32, 0.25, 0.15, 1.0), Color(1.0, 0.9, 0.5)))
	btn_minus.add_theme_stylebox_override("pressed", _create_btn_style(Color(0.14, 0.11, 0.08, 1.0), Color(0.6, 0.5, 0.25)))
	btn_minus.tooltip_text = "Giảm (Click: -1 | Shift: -10 | Ctrl: -100)"
	btn_minus.pressed.connect(_on_stat_minus_pressed)
	_stat_dialog.add_child(btn_minus)

	_stat_input = LineEdit.new()
	_stat_input.position = Vector2(48, 66) * S
	_stat_input.size = Vector2(76, 26) * S
	_stat_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_input.add_theme_font_size_override("font_size", int(12 * S))
	_stat_input.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	var sb_input := StyleBoxFlat.new()
	sb_input.bg_color = Color(0.04, 0.04, 0.04, 0.95)
	sb_input.border_color = Color(0.65, 0.55, 0.28)
	sb_input.border_width_left = 1
	sb_input.border_width_top = 1
	sb_input.border_width_right = 1
	sb_input.border_width_bottom = 1
	sb_input.corner_radius_top_left = 2
	sb_input.corner_radius_top_right = 2
	sb_input.corner_radius_bottom_left = 2
	sb_input.corner_radius_bottom_right = 2
	_stat_input.add_theme_stylebox_override("normal", sb_input)
	_stat_input.add_theme_stylebox_override("focus", sb_input)
	_stat_input.text = "1"
	_stat_input.tooltip_text = "Nhập số điểm muốn cộng (tối đa bằng điểm hiện có)"
	_stat_input.text_changed.connect(_on_stat_input_changed)
	_stat_input.text_submitted.connect(_on_stat_input_submitted)
	_stat_dialog.add_child(_stat_input)

	var btn_plus := Button.new()
	btn_plus.text = "+"
	btn_plus.position = Vector2(128, 66) * S
	btn_plus.size = Vector2(28, 26) * S
	btn_plus.add_theme_font_size_override("font_size", int(14 * S))
	btn_plus.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	btn_plus.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	btn_plus.add_theme_stylebox_override("normal", _create_btn_style(Color(0.2, 0.16, 0.11, 0.95), Color(0.75, 0.62, 0.3)))
	btn_plus.add_theme_stylebox_override("hover", _create_btn_style(Color(0.32, 0.25, 0.15, 1.0), Color(1.0, 0.9, 0.5)))
	btn_plus.add_theme_stylebox_override("pressed", _create_btn_style(Color(0.14, 0.11, 0.08, 1.0), Color(0.6, 0.5, 0.25)))
	btn_plus.tooltip_text = "Tăng (Click: +1 | Shift: +10 | Ctrl: +100)"
	btn_plus.pressed.connect(_on_stat_plus_pressed)
	_stat_dialog.add_child(btn_plus)

	# Bội số nhanh: +10, +100, +1k, Max
	var presets: Array = [
		{"text": "+10", "val": 10, "pos": Vector2(14, 99), "w": 33},
		{"text": "+100", "val": 100, "pos": Vector2(51, 99), "w": 34},
		{"text": "+1k", "val": 1000, "pos": Vector2(89, 99), "w": 33},
		{"text": "Max", "val": -1, "pos": Vector2(126, 99), "w": 32},
	]
	for p in presets:
		var bp := Button.new()
		bp.text = p["text"]
		bp.position = p["pos"] * S
		bp.size = Vector2(p["w"], 19) * S
		bp.add_theme_font_size_override("font_size", int(10 * S))
		bp.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45))
		bp.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.65))
		bp.add_theme_stylebox_override("normal", _create_btn_style(Color(0.16, 0.13, 0.09, 0.9), Color(0.55, 0.44, 0.22), 2))
		bp.add_theme_stylebox_override("hover", _create_btn_style(Color(0.28, 0.22, 0.14, 1.0), Color(0.85, 0.7, 0.35), 2))
		var p_val: int = p["val"]
		bp.pressed.connect(func(): _on_stat_preset_pressed(p_val))
		_stat_dialog.add_child(bp)

	# Nút Đồng Ý / Hủy
	var btn_ok := Button.new()
	btn_ok.text = "Đồng Ý"
	btn_ok.position = Vector2(16, 126) * S
	btn_ok.size = Vector2(66, 26) * S
	btn_ok.add_theme_font_size_override("font_size", int(11 * S))
	btn_ok.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	btn_ok.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 0.85))
	btn_ok.add_theme_stylebox_override("normal", _create_btn_style(Color(0.12, 0.26, 0.14, 0.95), Color(0.35, 0.8, 0.4), 3))
	btn_ok.add_theme_stylebox_override("hover", _create_btn_style(Color(0.18, 0.38, 0.2, 1.0), Color(0.5, 0.95, 0.55), 3))
	btn_ok.pressed.connect(_confirm_add_stat)
	_stat_dialog.add_child(btn_ok)

	var btn_canc := Button.new()
	btn_canc.text = "Hủy"
	btn_canc.position = Vector2(90, 126) * S
	btn_canc.size = Vector2(66, 26) * S
	btn_canc.add_theme_font_size_override("font_size", int(11 * S))
	btn_canc.add_theme_color_override("font_color", Color(0.9, 0.75, 0.75))
	btn_canc.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.85))
	btn_canc.add_theme_stylebox_override("normal", _create_btn_style(Color(0.24, 0.12, 0.12, 0.95), Color(0.7, 0.35, 0.35), 3))
	btn_canc.add_theme_stylebox_override("hover", _create_btn_style(Color(0.34, 0.16, 0.16, 1.0), Color(0.85, 0.45, 0.45), 3))
	btn_canc.pressed.connect(_close_stat_dialog)
	_stat_dialog.add_child(btn_canc)

func _create_btn_style(bg: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb

func _on_stat_btn_pressed(stat_code: String, label_text: String) -> void:
	if not player or player.stat_points <= 0:
		return
	if Input.is_key_pressed(KEY_SHIFT):
		_add_point_quick(stat_code, 10)
		return
	if Input.is_key_pressed(KEY_CTRL):
		_add_point_quick(stat_code, 100)
		return
	_open_stat_dialog(stat_code, label_text)

func _add_point_quick(stat: String, amt: int) -> void:
	if not player or player.stat_points <= 0:
		return
	if player.add_stat_point(stat, amt):
		update_stats()
		if MuAudioManager:
			MuAudioManager.play_ui_click()

func _open_stat_dialog(stat_code: String, label_text: String) -> void:
	if not player or player.stat_points <= 0:
		return
	
	_selected_stat_code = stat_code
	_selected_stat_label = label_text
	
	var stat_title := ""
	match stat_code:
		"str": stat_title = "Sức Mạnh (STR)"
		"agi": stat_title = "Nhanh Nhẹn (AGI)"
		"vit": stat_title = "Thể Lực (STA)"
		"ene": stat_title = "Năng Lượng (ENG)"
		"cmd": stat_title = "Mệnh Lệnh (CMD)"
		_: stat_title = label_text
	
	if _stat_dialog_title:
		_stat_dialog_title.text = "Cộng Điểm " + stat_title
	if _stat_dialog_avail_lbl:
		_stat_dialog_avail_lbl.text = "Điểm có thể cộng: %d" % player.stat_points
	
	_stat_current_val = mini(1, player.stat_points)
	if _stat_input:
		_stat_input.text = str(_stat_current_val)
	_update_stat_dialog_preview()
	
	if _stat_dialog_overlay:
		_stat_dialog_overlay.visible = true
		_stat_dialog_overlay.move_to_front()
	if _stat_dialog:
		_stat_dialog.visible = true
		_stat_dialog.move_to_front()
	
	_bring_to_front()
	
	if _stat_input:
		_stat_input.grab_focus()
		_stat_input.select_all()
	
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _close_stat_dialog() -> void:
	if _stat_dialog_overlay:
		_stat_dialog_overlay.visible = false
	if _stat_dialog:
		_stat_dialog.visible = false
	_selected_stat_code = ""

func _update_stat_dialog_preview() -> void:
	if not player or not _stat_dialog_preview_lbl:
		return
	var cur_val := 0
	match _selected_stat_code:
		"str": cur_val = player.stat_str
		"agi": cur_val = player.stat_agi
		"vit": cur_val = player.stat_vit
		"ene": cur_val = player.stat_ene
		"cmd":
			var c = player.get("stat_cmd")
			cur_val = int(c) if c != null else 25
	
	var next_val := cur_val + _stat_current_val
	_stat_dialog_preview_lbl.text = "Hiện tại: %d  ->  Sau cộng: %d (+%d)" % [cur_val, next_val, _stat_current_val]

func _on_stat_input_changed(new_text: String) -> void:
	if not player:
		return
	var digits := ""
	for i in range(new_text.length()):
		var ch := new_text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	
	var val := 0
	if digits != "":
		val = int(digits)
	
	if val > player.stat_points:
		val = player.stat_points
		digits = str(val)
	
	_stat_current_val = val
	if _stat_input and _stat_input.text != digits:
		_stat_input.text = digits
		_stat_input.caret_column = digits.length()
	
	_update_stat_dialog_preview()

func _on_stat_input_submitted(_new_text: String) -> void:
	_confirm_add_stat()

func _on_stat_minus_pressed() -> void:
	if not player:
		return
	var step := 1
	if Input.is_key_pressed(KEY_CTRL):
		step = 100
	elif Input.is_key_pressed(KEY_SHIFT):
		step = 10
	_stat_current_val = maxi(1, _stat_current_val - step)
	if _stat_input:
		_stat_input.text = str(_stat_current_val)
	_update_stat_dialog_preview()
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_stat_plus_pressed() -> void:
	if not player:
		return
	var step := 1
	if Input.is_key_pressed(KEY_CTRL):
		step = 100
	elif Input.is_key_pressed(KEY_SHIFT):
		step = 10
	_stat_current_val = mini(player.stat_points, _stat_current_val + step)
	_stat_current_val = maxi(1, _stat_current_val)
	if _stat_input:
		_stat_input.text = str(_stat_current_val)
	_update_stat_dialog_preview()
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_stat_preset_pressed(preset: int) -> void:
	if not player:
		return
	if preset == -1:
		_stat_current_val = player.stat_points
	else:
		_stat_current_val = mini(player.stat_points, _stat_current_val + preset)
	_stat_current_val = maxi(1, _stat_current_val)
	if _stat_input:
		_stat_input.text = str(_stat_current_val)
	_update_stat_dialog_preview()
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _confirm_add_stat() -> void:
	if not player or _selected_stat_code == "":
		_close_stat_dialog()
		return
	
	var amt := _stat_current_val
	if amt <= 0 and _stat_input and _stat_input.text.is_valid_int():
		amt = int(_stat_input.text)
	amt = clamp(amt, 1, player.stat_points)
	
	if amt > 0 and player.stat_points >= amt:
		if player.add_stat_point(_selected_stat_code, amt):
			update_stats()
			if MuAudioManager:
				MuAudioManager.play_ui_click()
	
	_close_stat_dialog()

func close() -> void:
	_close_stat_dialog()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _stat_dialog and _stat_dialog.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_stat_dialog()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		_bring_to_front()
	accept_event()
