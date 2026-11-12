extends Control
class_name MuTargetInfoWidget

## Widget Hiển Thị Tên & Máu Quái Vật Được Target (Target Unit Frame)
## Vị trí: Góc trên bên phải màn hình, nằm ngay dưới Mini Map
## Phong cách Mobile MU Origin: Viền kim loại vàng kim, nền tối huyền ảo, thanh máu đỏ rực rỡ

var player: MuPlayer = null
var current_target: MuMonster = null

var panel_bg: Panel
var lbl_type_badge: Label
var lbl_name: Label
var btn_close: Button
var pb_hp: ProgressBar
var lbl_hp_text: Label
var hp_fill_style: StyleBoxFlat

func _ready() -> void:
	visible = false
	_build_ui()

func setup(p_player: MuPlayer) -> void:
	if player and player.is_connected("target_monster_changed", _on_target_monster_changed):
		player.target_monster_changed.disconnect(_on_target_monster_changed)
	player = p_player
	if player:
		if not player.target_monster_changed.is_connected(_on_target_monster_changed):
			player.target_monster_changed.connect(_on_target_monster_changed)
		_on_target_monster_changed(player.target_monster)

func _build_ui() -> void:
	custom_minimum_size = Vector2(136, 46)
	# không gán size: giữ offset do HUD đặt (mép phải thẳng mini map)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# 1. Panel Khung Viền Phong Cách MU Online
	panel_bg = Panel.new()
	panel_bg.name = "PanelBg"
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.06, 0.08, 0.12, 0.92) # Nền xám đen mờ
	sb_bg.border_width_left = 1
	sb_bg.border_width_top = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_bottom = 1
	sb_bg.border_color = Color(0.75, 0.62, 0.3, 0.95) # Viền vàng kim
	sb_bg.corner_radius_top_left = 3
	sb_bg.corner_radius_top_right = 3
	sb_bg.corner_radius_bottom_right = 3
	sb_bg.corner_radius_bottom_left = 3
	sb_bg.shadow_color = Color(0, 0, 0, 0.55)
	sb_bg.shadow_size = 3
	panel_bg.add_theme_stylebox_override("panel", sb_bg)
	add_child(panel_bg)

	# 2. Huy hiệu Loại / Level Quái Vật (Lv.XX hoặc BOSS / GOLD)
	lbl_type_badge = Label.new()
	lbl_type_badge.name = "TypeBadge"
	lbl_type_badge.position = Vector2(4, 4)
	lbl_type_badge.size = Vector2(34, 15)
	lbl_type_badge.add_theme_font_size_override("font_size", 9)
	lbl_type_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lbl_type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_type_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var sb_badge = StyleBoxFlat.new()
	sb_badge.bg_color = Color(0.14, 0.06, 0.06, 0.9)
	sb_badge.border_width_left = 1
	sb_badge.border_width_top = 1
	sb_badge.border_width_right = 1
	sb_badge.border_width_bottom = 1
	sb_badge.border_color = Color(0.65, 0.48, 0.22, 0.85)
	sb_badge.corner_radius_top_left = 2
	sb_badge.corner_radius_top_right = 2
	sb_badge.corner_radius_bottom_right = 2
	sb_badge.corner_radius_bottom_left = 2
	lbl_type_badge.add_theme_stylebox_override("normal", sb_badge)
	add_child(lbl_type_badge)

	# 3. Tên Quái Vật
	lbl_name = Label.new()
	lbl_name.name = "MonsterName"
	lbl_name.position = Vector2(42, 3)
	lbl_name.size = Vector2(76, 17)
	lbl_name.add_theme_font_size_override("font_size", 10)
	lbl_name.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	lbl_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl_name.add_theme_constant_override("outline_size", 2)
	lbl_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl_name)

	# 4. Nút Hủy Target (✕)
	btn_close = Button.new()
	btn_close.name = "CloseBtn"
	btn_close.text = "×"
	btn_close.position = Vector2(119, 1)
	btn_close.size = Vector2(14, 14)
	btn_close.flat = true
	btn_close.add_theme_font_size_override("font_size", 11)
	btn_close.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	btn_close.add_theme_color_override("font_hover_color", Color(1.0, 0.35, 0.35))
	btn_close.pressed.connect(_on_close_pressed)
	add_child(btn_close)

	# 5. Thanh Máu Quái Vật (HP Progress Bar)
	pb_hp = ProgressBar.new()
	pb_hp.name = "HpBar"
	pb_hp.position = Vector2(4, 23)
	pb_hp.size = Vector2(128, 16)
	pb_hp.show_percentage = false
	pb_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb_hp_bg = StyleBoxFlat.new()
	sb_hp_bg.bg_color = Color(0.04, 0.04, 0.06, 0.95)
	sb_hp_bg.border_width_left = 1
	sb_hp_bg.border_width_top = 1
	sb_hp_bg.border_width_right = 1
	sb_hp_bg.border_width_bottom = 1
	sb_hp_bg.border_color = Color(0.28, 0.28, 0.32, 0.9)
	sb_hp_bg.corner_radius_top_left = 2
	sb_hp_bg.corner_radius_top_right = 2
	sb_hp_bg.corner_radius_bottom_right = 2
	sb_hp_bg.corner_radius_bottom_left = 2
	pb_hp.add_theme_stylebox_override("background", sb_hp_bg)

	hp_fill_style = StyleBoxFlat.new()
	hp_fill_style.bg_color = Color(0.85, 0.15, 0.15) # Đỏ rực
	hp_fill_style.corner_radius_top_left = 2
	hp_fill_style.corner_radius_top_right = 2
	hp_fill_style.corner_radius_bottom_right = 2
	hp_fill_style.corner_radius_bottom_left = 2
	pb_hp.add_theme_stylebox_override("fill", hp_fill_style)
	add_child(pb_hp)

	# 6. Số Máu (HP Text) đặt giữa thanh máu
	lbl_hp_text = Label.new()
	lbl_hp_text.name = "HpText"
	lbl_hp_text.position = Vector2(4, 23)
	lbl_hp_text.size = Vector2(128, 16)
	lbl_hp_text.add_theme_font_size_override("font_size", 9)
	lbl_hp_text.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	lbl_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl_hp_text.add_theme_constant_override("outline_size", 2)
	lbl_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl_hp_text)

func _on_close_pressed() -> void:
	if current_player != null:
		clear_player()
		return
	if player:
		player.clear_target()

func _on_target_monster_changed(new_target: MuMonster) -> void:
	if new_target != null and is_instance_valid(new_target):
		clear_player()
	elif current_player != null:
		return   # đang hiện người chơi: bỏ chọn quái không ẩn khung
	if current_target and is_instance_valid(current_target):
		if current_target.is_connected("hp_changed", _on_monster_hp_changed):
			current_target.hp_changed.disconnect(_on_monster_hp_changed)
		if current_target.is_connected("died", _on_monster_died):
			current_target.died.disconnect(_on_monster_died)
		if current_target.is_connected("tree_exiting", _on_monster_tree_exiting):
			current_target.tree_exiting.disconnect(_on_monster_tree_exiting)
	
	current_target = new_target
	
	if not is_instance_valid(current_target) or current_target.is_dead:
		current_target = null
		visible = false
		return

	if not current_target.is_connected("hp_changed", _on_monster_hp_changed):
		current_target.hp_changed.connect(_on_monster_hp_changed)
	if not current_target.is_connected("died", _on_monster_died):
		current_target.died.connect(_on_monster_died)
	if not current_target.is_connected("tree_exiting", _on_monster_tree_exiting):
		current_target.tree_exiting.connect(_on_monster_tree_exiting)

	modulate.a = 1.0
	_update_target_info()
	visible = true

func _update_target_info() -> void:
	if not is_instance_valid(current_target):
		visible = false
		return
	
	# Tên hiển thị
	var disp_name: String = current_target.get_display_name() if current_target.has_method("get_display_name") else current_target.monster_name
	lbl_name.text = disp_name

	# Cấp độ / Loại quái
	if current_target.is_boss:
		lbl_type_badge.text = "BOSS"
		lbl_type_badge.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		lbl_name.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	elif current_target.is_golden:
		lbl_type_badge.text = "GOLD"
		lbl_type_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		lbl_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.15))
	else:
		lbl_type_badge.text = "Lv.%d" % current_target.level
		lbl_type_badge.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		lbl_name.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))

	# Máu
	_update_hp_bar(current_target.current_hp, current_target.max_hp)

func _update_hp_bar(cur_hp: int, max_hp: int) -> void:
	pb_hp.max_value = max_hp
	pb_hp.value = cur_hp
	lbl_hp_text.text = "%d / %d" % [cur_hp, max_hp]
	
	var ratio = float(cur_hp) / float(max(1, max_hp))
	if hp_fill_style:
		if ratio > 0.5:
			hp_fill_style.bg_color = Color(0.85, 0.15, 0.15) # Đỏ tươi
		elif ratio > 0.2:
			hp_fill_style.bg_color = Color(0.95, 0.55, 0.15) # Cam
		else:
			hp_fill_style.bg_color = Color(0.95, 0.1, 0.1) # Đỏ thẫm

func _on_monster_hp_changed(cur_hp: int, max_hp: int) -> void:
	_update_hp_bar(cur_hp, max_hp)
	if cur_hp <= 0:
		_fade_out()

func _on_monster_died(_m) -> void:
	_fade_out()

func _on_monster_tree_exiting() -> void:
	current_target = null
	visible = false

func _fade_out() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		visible = false
		modulate.a = 1.0
		current_target = null
	)

func _process(_delta: float) -> void:
	if current_player != null:
		if not is_instance_valid(current_player):
			clear_player()
		elif player:
			# m_bCanCommand: tên đỏ khi người kia ở ngoài tầm lệnh
			var far := player.global_position.distance_to(current_player.global_position) > 12.0
			lbl_name.add_theme_color_override("font_color", Color(1, 0, 0) if far else Color("#d2e6ff"))
		return
	if visible:
		if not is_instance_valid(current_target) or current_target.is_dead:
			current_target = null
			visible = false

# ================================================================== Chế độ người chơi (chạm vào người chơi khác)
## Lệnh của Command Window gốc theo thứ tự kCommandLabels (CommandWindow.cpp), bỏ Buy (không có đứng bán) + Xem đồ
const PLAYER_COMMANDS := [
	["trade", "Giao dịch"], ["party", "Tổ đội"],
	["whisper", "Tán gẫu"], ["guild", "Guild"], ["alliance", "Liên minh"],
	["rival", "Thù địch"], ["rival_off", "Hủy thù địch"], ["friend", "Kết bạn"],
	["follow", "Đi theo"], ["duel", "Quyết đấu"], ["special", "Đặc biệt"],
	["inspect", "Xem đồ"],
]
const PM_COLS := 3
const PM_BTN := Vector2(73, 24)
const PM_W := 231.0

var current_player: MuOtherPlayer = null
var _pm_box: Control = null
var _pm_sub: Label = null
var _saved_offsets := Vector4.ZERO

func has_player() -> bool:
	return current_player != null

func show_player(p: MuOtherPlayer) -> void:
	if current_player == null:
		_saved_offsets = Vector4(offset_left, offset_top, offset_right, offset_bottom)
	current_player = p
	_build_player_box()
	# khung rộng ra phía trái (giữ mép phải thẳng với mini map)
	var rows := ceili(PLAYER_COMMANDS.size() / float(PM_COLS))
	var h := 42.0 + rows * (PM_BTN.y + 2) + 4
	grow_horizontal = Control.GROW_DIRECTION_BEGIN   # nới rộng sang trái, mép phải thẳng mini map
	custom_minimum_size = Vector2(PM_W, h)
	offset_right = _saved_offsets.z
	offset_left = _saved_offsets.z - PM_W
	offset_bottom = _saved_offsets.y + h
	pb_hp.visible = false
	lbl_hp_text.visible = false
	_pm_box.visible = true
	btn_close.position = Vector2(PM_W - 17, 1)
	lbl_name.size = Vector2(PM_W - 62, 17)
	var b := 10
	for lv in [400, 300, 200, 100, 50]:
		if p.level >= lv:
			b = lv
			break
	lbl_type_badge.text = "Lv.%d" % b if b == 400 else "~%d" % b
	lbl_type_badge.add_theme_color_override("font_color", {10: Color("#ff0000"), 50: Color("#ff9600"), 100: Color("#00c918"),
		200: Color("#d2e6ff"), 300: Color("#ff99ff"), 400: Color("#ff9999")}[b])
	lbl_name.text = p.character_name
	lbl_name.add_theme_color_override("font_color", Color("#d2e6ff"))
	var guild := (" · [%s]%s" % [p.guild_name, " ★" if p.guild_master else ""]) if p.guild_name != "" else ""
	_pm_sub.text = p.get_class_display_name() + guild
	modulate.a = 1.0
	visible = true

func clear_player() -> void:
	if current_player == null:
		return
	current_player = null
	offset_left = _saved_offsets.x
	offset_top = _saved_offsets.y
	offset_right = _saved_offsets.z
	offset_bottom = _saved_offsets.w
	custom_minimum_size = Vector2(136, 46)
	btn_close.position = Vector2(119, 1)
	lbl_name.size = Vector2(76, 17)
	pb_hp.visible = true
	lbl_hp_text.visible = true
	if _pm_box:
		_pm_box.visible = false
	visible = false
	if player and is_instance_valid(player.target_monster):
		_on_target_monster_changed(player.target_monster)

func _build_player_box() -> void:
	if _pm_box != null:
		return
	_pm_box = Control.new()
	_pm_box.name = "PlayerCommands"
	_pm_box.position = Vector2(0, 20)
	_pm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pm_box)
	_pm_sub = Label.new()
	_pm_sub.position = Vector2(6, 0)
	_pm_sub.size = Vector2(PM_W - 12, 16)
	_pm_sub.add_theme_font_size_override("font_size", 10)
	_pm_sub.add_theme_color_override("font_color", Color("#ffd927"))
	_pm_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_pm_sub.add_theme_constant_override("outline_size", 2)
	_pm_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pm_box.add_child(_pm_sub)
	var tex := MuUiSkin.tex("newui_btn_empty")
	for i in PLAYER_COMMANDS.size():
		var c: Array = PLAYER_COMMANDS[i]
		var btn := TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.focus_mode = Control.FOCUS_NONE
		if tex:
			# newui_btn_empty: 3 trạng thái 108x29 (thường / rê chuột / nhấn) như .cmd-btn
			btn.texture_normal = MuUiSkin.atlas_sub(tex, Rect2(0, 0, 108, 29))
			btn.texture_hover = MuUiSkin.atlas_sub(tex, Rect2(0, 29, 108, 29))
			btn.texture_pressed = MuUiSkin.atlas_sub(tex, Rect2(0, 58, 108, 29))
		btn.position = Vector2(4 + (i % PM_COLS) * (PM_BTN.x + 2), 20 + (i / PM_COLS) * (PM_BTN.y + 2))
		btn.size = PM_BTN
		var l := Label.new()
		l.text = str(c[1])
		l.size = PM_BTN
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 9)
		l.clip_text = true
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 2)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(l)
		btn.pressed.connect(_on_player_command.bind(str(c[0])))
		_pm_box.add_child(btn)

func _on_player_command(cmd: String) -> void:
	if current_player == null or not is_instance_valid(current_player):
		return
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("run_player_command"):
		hud.run_player_command(cmd, current_player)
