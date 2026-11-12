extends Control
class_name MuClassicHudBar

## Thanh Giao Diện Dưới Đáy Màn Hình Mới (Fantasy ARPG HUD Bar)
## Thay thế toàn bộ UI thanh đáy cũ (Ảnh 2):
## - Khung rồng kim loại chạm khắc cổ điển (784x156 dp)
## - Quả cầu Máu Ruby (Life Orb) & Mana Sapphire (Mana Orb) hiệu ứng sóng nước 3D
## - Cột Thể Lực AG (Vàng hoàng kim) & Giáp Chống Đỡ SD (Tím huyền bí)
## - 5 Nút Biểu Tượng Chạm Khắc Tinh Xảo:
##     1. Mũ Hiệp Sĩ (C): Thông tin nhân vật (Character Stats)
##     2. Ba Lô Da (I / V): Hành trang túi đồ (Inventory)
##     3. Bản Đồ & La Bàn (M): Bản đồ thế giới & Dịch chuyển (Move Window)
##     4. Cuộn Giấy Nhiệm Vụ (K): Bảng Kỹ năng & Nhiệm vụ (Skill Window)
##     5. Bánh Răng Cơ Khí (O / B): Kho Đồ GM & Cài đặt (Item Picker)
## - Bảng Thông Tin Tên Nhân Vật, Cấp Độ & Thanh EXP mạ vàng trên đỉnh
## - Tương tác mượt mà: Click chuột, Phím tắt PC và Chạm màn hình Mobile

@export var player: MuPlayer = null

@onready var life_orb: TextureProgressBar = $BarContainer/LifeOrb
@onready var mana_orb: TextureProgressBar = $BarContainer/ManaOrb
@onready var sd_bar: TextureProgressBar = $BarContainer/SdBar
@onready var ag_bar: TextureProgressBar = $BarContainer/AgBar
@onready var exp_bar: ProgressBar = $BarContainer/ExpProgressBar
@onready var lbl_hp: Label = $BarContainer/LifeOrb/HpLabel
@onready var lbl_mp: Label = $BarContainer/ManaOrb/MpLabel
@onready var lbl_zen: Label = $BarContainer/ZenLabel
@onready var lbl_char_info: Label = $BarContainer/CharInfoLabel

@onready var btn_char: TextureButton = $BarContainer/MenuButtons/CharBtn
@onready var btn_inv: TextureButton = $BarContainer/MenuButtons/InvBtn
@onready var btn_map: TextureButton = $BarContainer/MenuButtons/MapBtn
@onready var btn_quest: TextureButton = $BarContainer/MenuButtons/QuestBtn
@onready var btn_options: TextureButton = $BarContainer/MenuButtons/OptionsBtn

# Biến tương thích ngược cho các hệ thống cũ nếu cần
@onready var btn_party: TextureButton = btn_map
@onready var btn_exit: TextureButton = btn_options
var active_skill_box: TextureRect = null
var skill_cd_overlay: ColorRect = null
var skill_cd_label: Label = null
var current_skill_icon: TextureRect = null
var current_skill_type: int = 1

func _ready() -> void:
	if btn_char:
		btn_char.pressed.connect(_on_char_pressed)
	if btn_inv:
		btn_inv.pressed.connect(_on_inv_pressed)
	if btn_map:
		btn_map.pressed.connect(_on_map_pressed)
	if btn_quest:
		btn_quest.pressed.connect(_on_quest_pressed)
	if btn_options:
		btn_options.pressed.connect(_on_options_pressed)

	_build_active_skill_box()

	if life_orb:
		life_orb.gui_input.connect(_on_life_orb_gui_input)
	if mana_orb:
		mana_orb.gui_input.connect(_on_mana_orb_gui_input)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_on_char_pressed()
				get_viewport().set_input_as_handled()
			KEY_I, KEY_V:
				_on_inv_pressed()
				get_viewport().set_input_as_handled()
			KEY_M:
				_on_map_pressed()
				get_viewport().set_input_as_handled()
			KEY_K:
				_on_quest_pressed()
				get_viewport().set_input_as_handled()
			KEY_B, KEY_F2, KEY_G, KEY_O:
				_on_options_pressed()
				get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var idx: int = event.keycode - KEY_1
				if player:
					var sks := player.get_available_skills()
					if idx < sks.size():
						player.set_active_skill(sks[idx].get("id", ""))
						if MuAudioManager:
							MuAudioManager.play_ui_click()
			KEY_Q:
				if player:
					player.use_hp_potion()
			KEY_W:
				if player:
					player.use_mp_potion()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			execute_current_skill()

func _process(_delta: float) -> void:
	if not player or not skill_cd_overlay:
		return
	var act: Dictionary = player.get_active_skill()
	var sk_num := int(act.get("skill", -1))
	var frac: float = player.get_skill_cooldown_fraction(sk_num) if player.has_method("get_skill_cooldown_fraction") else 0.0
	if frac > 0.0:
		skill_cd_overlay.visible = true
		skill_cd_overlay.size = Vector2(30, 36.0 * frac)
		if skill_cd_label:
			var sec: float = player.get_skill_cooldown_remaining(sk_num) if player.has_method("get_skill_cooldown_remaining") else 0.0
			if sec >= 1.0:
				skill_cd_label.text = "%d" % int(ceil(sec))
			elif sec >= 0.1:
				skill_cd_label.text = "%.1f" % sec
			else:
				skill_cd_label.text = ""
	else:
		skill_cd_overlay.visible = false
		if skill_cd_label:
			skill_cd_label.text = ""

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player:
		if not player.hp_changed.is_connected(update_hp):
			player.hp_changed.connect(update_hp)
		if not player.mana_changed.is_connected(update_mp):
			player.mana_changed.connect(update_mp)
		if not player.exp_changed.is_connected(update_exp):
			player.exp_changed.connect(update_exp)
		if player.has_signal("active_skill_changed") and not player.active_skill_changed.is_connected(_on_player_active_skill_changed):
			player.active_skill_changed.connect(_on_player_active_skill_changed)

		update_hp(player.current_hp, player.max_hp)
		update_mp(player.current_mp, player.max_mp)
		update_exp(player.current_exp, player.max_exp, player.level)
		update_player_info()
		_on_player_active_skill_changed(player.active_skill_id)

func update_hp(cur: int, max_val: int) -> void:
	if life_orb:
		life_orb.max_value = max(1, max_val)
		life_orb.value = cur
	if lbl_hp:
		lbl_hp.text = "%d / %d" % [cur, max_val]
	if ag_bar:
		ag_bar.max_value = 100
		ag_bar.value = 100

func update_mp(cur: int, max_val: int) -> void:
	if mana_orb:
		mana_orb.max_value = max(1, max_val)
		mana_orb.value = cur
	if lbl_mp:
		lbl_mp.text = "%d / %d" % [cur, max_val]
	if sd_bar:
		sd_bar.max_value = 100
		sd_bar.value = 100

func update_exp(cur: int, max_val: int, lvl: int) -> void:
	if exp_bar:
		var safe_max = max(1, max_val)
		exp_bar.max_value = safe_max
		exp_bar.value = cur
		var pct: float = (float(cur) / float(safe_max)) * 100.0
		exp_bar.tooltip_text = "Kinh nghiệm (EXP): %d / %d (%.1f%%)" % [cur, safe_max, pct]
	update_player_info()

func update_player_info() -> void:
	if not player:
		return
	if lbl_char_info:
		var c_name = player.character_name if player.character_name != "" else "Dark Knight"
		lbl_char_info.text = "%s  •  Lv. %d" % [c_name, player.level]
	if lbl_zen:
		lbl_zen.text = "🪙 %d" % player.zen

func _on_char_pressed() -> void:
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_character_stats"):
		hud.toggle_character_stats()

func _on_inv_pressed() -> void:
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_inventory"):
		hud.toggle_inventory()

func _on_map_pressed() -> void:
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_move_window"):
		hud.toggle_move_window()

func _on_quest_pressed() -> void:
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_skill_window"):
		hud.toggle_skill_window()

func _on_options_pressed() -> void:
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_item_picker"):
		hud.toggle_item_picker()

func _on_life_orb_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player:
			player.use_hp_potion()

func _on_mana_orb_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player:
			player.use_mp_potion()

func set_skill(skill_type: int) -> void:
	current_skill_type = skill_type
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	if player:
		if current_skill_type == 1:
			player.set_active_skill("twisting")
		else:
			player.set_active_skill("fireball")

func _on_player_active_skill_changed(skill_id: String) -> void:
	if player:
		var sk = player.get_active_skill()
		var p: String = sk.get("icon_path", "")
		if current_skill_icon and p != "":
			var tex := _get_skill_texture(p)
			if tex:
				current_skill_icon.texture = tex
		if active_skill_box:
			var sname: String = sk.get("name", "Kỹ Năng")
			var mp: int = sk.get("mana_cost", 0)
			active_skill_box.tooltip_text = "%s (%d MP)\n[Chuột Phải để Dùng • Click mở Bảng Skill • Cuộn chuột để Đổi]" % [sname, mp]

func execute_current_skill() -> void:
	if not player:
		return
	var act: Dictionary = player.get_active_skill()
	var sk_num := int(act.get("skill", -1))
	if player.has_method("check_skill_delay") and not player.check_skill_delay(sk_num):
		return
	if player.has_method("cast_active_skill"):
		player.cast_active_skill()
	elif current_skill_type == 1:
		player.cast_twisting_slash()
	else:
		player.cast_fireball()

func _build_active_skill_box() -> void:
	if active_skill_box != null:
		return
	var box := TextureRect.new()
	box.name = "ActiveSkillBox"
	box.custom_minimum_size = Vector2(36, 44)
	box.size = Vector2(36, 44)
	box.position = Vector2(146, 46)
	box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists("res://assets/textures/ui/newui_skillbox.png"):
		box.texture = load("res://assets/textures/ui/newui_skillbox.png")
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = "Kỹ Năng Đang Chọn (Chuột Phải để Xuất Chiêu / Click để Mở Bảng Kỹ Năng / Cuộn Chuột để Đổi)"
	box.gui_input.connect(_on_skill_box_gui_input)

	var icon := TextureRect.new()
	icon.name = "SkillIcon"
	icon.position = Vector2(3, 4)
	icon.size = Vector2(30, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	# Overlay hồi chiêu bán trong suốt đen chuẩn MU Season 6 (RenderSkillDelay)
	var overlay := ColorRect.new()
	overlay.name = "CooldownOverlay"
	overlay.position = Vector2(3, 4)
	overlay.size = Vector2(30, 0)
	overlay.color = Color(0.02, 0.02, 0.02, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	box.add_child(overlay)
	skill_cd_overlay = overlay

	# Nhãn số giây đếm ngược
	var lbl := Label.new()
	lbl.name = "CooldownLabel"
	lbl.position = Vector2(3, 12)
	lbl.size = Vector2(30, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	skill_cd_label = lbl

	current_skill_icon = icon
	active_skill_box = box

	var bar_container = get_node_or_null("BarContainer")
	if bar_container:
		bar_container.add_child(box)
	else:
		add_child(box)

func _cycle_next_skill() -> void:
	if not player:
		return
	var skills = player.get_available_skills()
	if skills.is_empty():
		return
	var cur_id = player.active_skill_id
	var cur_idx := 0
	for i in skills.size():
		if skills[i].get("id") == cur_id:
			cur_idx = i
			break
	var next_idx = (cur_idx + 1) % skills.size()
	player.set_active_skill(skills[next_idx].get("id", ""))
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _cycle_prev_skill() -> void:
	if not player:
		return
	var skills = player.get_available_skills()
	if skills.is_empty():
		return
	var cur_id = player.active_skill_id
	var cur_idx := 0
	for i in skills.size():
		if skills[i].get("id") == cur_id:
			cur_idx = i
			break
	var prev_idx = (cur_idx - 1 + skills.size()) % skills.size()
	player.set_active_skill(skills[prev_idx].get("id", ""))
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_skill_box_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var hud = get_tree().get_first_node_in_group("HUD")
			if hud and hud.has_method("toggle_skill_window"):
				hud.toggle_skill_window()
			else:
				_cycle_next_skill()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_prev_skill()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_next_skill()

func _get_skill_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			return tex
	if path.begins_with("res://") and FileAccess.file_exists(path):
		var abs_p := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_p)
		if img:
			return ImageTexture.create_from_image(img)
	return null
