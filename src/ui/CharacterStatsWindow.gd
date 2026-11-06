extends Control
class_name CharacterStatsWindow

## Bảng Chỉ Số Nhân Vật (Character Stats - Phím C) chuẩn 100% MU Online
## Tích hợp Nâng Điểm Bằng Tay (x1, x10, x100, x1000, Shift/Ctrl), GM +Point, Tẩy Điểm và Bất Tử HP/MP

@onready var lbl_name: Label = $Content/NameRow/NameVal
@onready var lbl_level: Label = $Content/LevelRow/LevelVal
@onready var lbl_class: Label = $Content/ClassRow/ClassVal
@onready var lbl_points: Label = $Content/PointsRow/PointsVal

@onready var lbl_str: Label = $Content/StatsGrid/StrVal
@onready var lbl_agi: Label = $Content/StatsGrid/AgiVal
@onready var lbl_vit: Label = $Content/StatsGrid/VitVal
@onready var lbl_ene: Label = $Content/StatsGrid/EneVal

@onready var lbl_dmg: Label = get_node_or_null("Content/CombatStats/DmgRow/DmgVal")
@onready var lbl_def: Label = get_node_or_null("Content/CombatStats/DefRow/DefVal")

@onready var btn_add_str: TextureButton = $Content/StatsGrid/AddStr
@onready var btn_add_agi: TextureButton = $Content/StatsGrid/AddAgi
@onready var btn_add_vit: TextureButton = $Content/StatsGrid/AddVit
@onready var btn_add_ene: TextureButton = $Content/StatsGrid/AddEne

@onready var btn_close: TextureButton = $CloseButton

var player: MuPlayer = null
var add_multiplier: int = 1

var _btn_mults: Array[Button] = []
var _btn_add_point_gm: Button = null
var _btn_reset_point_gm: Button = null
var _btn_god_mode: Button = null

func _ready() -> void:
	visible = false
	add_to_group("CharacterStatsWindow")
	if btn_close:
		btn_close.pressed.connect(func(): visible = false)

	if btn_add_str:
		btn_add_str.pressed.connect(func(): _add_point("str"))
	if btn_add_agi:
		btn_add_agi.pressed.connect(func(): _add_point("agi"))
	if btn_add_vit:
		btn_add_vit.pressed.connect(func(): _add_point("vit"))
	if btn_add_ene:
		btn_add_ene.pressed.connect(func(): _add_point("ene"))

	_build_gm_ui()

func _build_gm_ui() -> void:
	var content = get_node_or_null("Content")
	if not content:
		return

	# Dải phân cách
	var sep := HSeparator.new()
	sep.position = Vector2(0, 276)
	sep.size = Vector2(154, 4)
	content.add_child(sep)

	# 1. Hàng chọn số điểm mỗi lần click: x1, x10, x100, x1000
	var mult_row := HBoxContainer.new()
	mult_row.position = Vector2(0, 282)
	mult_row.size = Vector2(154, 20)
	mult_row.add_theme_constant_override("separation", 2)
	content.add_child(mult_row)

	var mult_lbl := Label.new()
	mult_lbl.text = "Cộng:"
	mult_lbl.add_theme_font_size_override("font_size", 10)
	mult_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	mult_row.add_child(mult_lbl)

	for m in [1, 10, 100, 1000]:
		var b := Button.new()
		b.text = "+%d" % m if m < 1000 else "+1k"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 9)
		b.pressed.connect(func(): _set_multiplier(m))
		mult_row.add_child(b)
		_btn_mults.append(b)
	_update_mult_buttons()

	# 2. Hàng GM: +1,000 Point & Tẩy Điểm
	var gm_row := HBoxContainer.new()
	gm_row.position = Vector2(0, 305)
	gm_row.size = Vector2(154, 20)
	gm_row.add_theme_constant_override("separation", 4)
	content.add_child(gm_row)

	_btn_add_point_gm = Button.new()
	_btn_add_point_gm.text = "✨ +1K Điểm"
	_btn_add_point_gm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_add_point_gm.add_theme_font_size_override("font_size", 10)
	_btn_add_point_gm.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_btn_add_point_gm.pressed.connect(_on_gm_add_point_clicked)
	gm_row.add_child(_btn_add_point_gm)

	_btn_reset_point_gm = Button.new()
	_btn_reset_point_gm.text = "🔄 Tẩy Điểm"
	_btn_reset_point_gm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_reset_point_gm.add_theme_font_size_override("font_size", 10)
	_btn_reset_point_gm.add_theme_color_override("font_color", Color(0.9, 0.6, 0.4))
	_btn_reset_point_gm.pressed.connect(_on_gm_reset_clicked)
	gm_row.add_child(_btn_reset_point_gm)

	# 3. Hàng Bất Tử HP & MP (God Mode)
	_btn_god_mode = Button.new()
	_btn_god_mode.position = Vector2(0, 328)
	_btn_god_mode.size = Vector2(154, 22)
	_btn_god_mode.add_theme_font_size_override("font_size", 10)
	_btn_god_mode.pressed.connect(_on_toggle_god_mode_clicked)
	content.add_child(_btn_god_mode)

func _set_multiplier(m: int) -> void:
	add_multiplier = m
	_update_mult_buttons()

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

func setup(p_player: MuPlayer) -> void:
	player = p_player
	update_stats()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		visible = not visible
		if visible:
			update_stats()

func _add_point(stat: String) -> void:
	if not player:
		return
	var amt = add_multiplier
	# Hỗ trợ phím tắt bàn phím: giữ Shift cộng tối thiểu 10, giữ Ctrl cộng tối thiểu 100
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
		lbl_name.text = player.character_name
	if lbl_level:
		lbl_level.text = "Lv. %d" % player.level
	if lbl_points:
		lbl_points.text = "%d" % player.stat_points

	if lbl_str:
		lbl_str.text = "%d" % player.stat_str
	if lbl_agi:
		lbl_agi.text = "%d" % player.stat_agi
	if lbl_vit:
		lbl_vit.text = "%d" % player.stat_vit
	if lbl_ene:
		lbl_ene.text = "%d" % player.stat_ene

	if lbl_dmg:
		var min_d = int(player.stat_str / 6) + 20
		var max_d = int(player.stat_str / 4) + 35
		lbl_dmg.text = "%d ~ %d" % [min_d, max_d]
	if lbl_def:
		lbl_def.text = "%d" % player.defense_value()

	var has_points = player.stat_points > 0
	if btn_add_str:
		btn_add_str.visible = has_points
	if btn_add_agi:
		btn_add_agi.visible = has_points
	if btn_add_vit:
		btn_add_vit.visible = has_points
	if btn_add_ene:
		btn_add_ene.visible = has_points

	if _btn_god_mode:
		if player.infinite_hp_mp:
			_btn_god_mode.text = "🛡️ Bất Tử HP/MP: BẬT"
			_btn_god_mode.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			_btn_god_mode.text = "🛡️ Bất Tử HP/MP: TẮT"
			_btn_god_mode.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
