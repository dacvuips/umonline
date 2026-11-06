extends Control
class_name MuClassicHudBar

## Thanh Giao Diện Dưới Đáy Màn Hình (HUD Bar) Nguyên Bản 100% MU Online
## Khung kim loại đá đen 980x51dp: Quả cầu Máu & Mana Orb, Cột AG & SD,
## 5 ô Kỹ Năng 1-5, Ô Kỹ Năng chọn viền xanh neon, 4 ô Bình Máu Q-W-E-R và 5 Nút Menu Đá Chạm Khắc

@export var player: MuPlayer = null

@onready var life_orb: TextureProgressBar = $BarContainer/LifeOrb
@onready var mana_orb: TextureProgressBar = $BarContainer/ManaOrb
@onready var sd_bar: TextureProgressBar = $BarContainer/SdBar
@onready var ag_bar: TextureProgressBar = $BarContainer/AgBar
@onready var exp_bar: ProgressBar = $BarContainer/ExpProgressBar
@onready var lbl_hp: Label = $BarContainer/LifeOrb/HpLabel
@onready var lbl_mp: Label = $BarContainer/ManaOrb/MpLabel
@onready var lbl_zen: Label = $BarContainer/ZenLabel

@onready var btn_inv: TextureButton = $BarContainer/MenuButtons/InvBtn
@onready var btn_char: TextureButton = $BarContainer/MenuButtons/CharBtn
@onready var btn_party: TextureButton = $BarContainer/MenuButtons/PartyBtn
@onready var btn_options: TextureButton = $BarContainer/MenuButtons/OptionsBtn
@onready var btn_exit: TextureButton = $BarContainer/MenuButtons/ExitBtn

@onready var active_skill_box: TextureRect = $BarContainer/ActiveSkillBox
@onready var current_skill_icon: TextureRect = $BarContainer/ActiveSkillBox/SkillIcon

var current_skill_type: int = 1 # 1: Twisting Slash, 2: Fireball

func _ready() -> void:
	if btn_char:
		btn_char.pressed.connect(_on_char_pressed)
	if btn_inv:
		btn_inv.pressed.connect(_on_inv_pressed)
	if btn_options:
		btn_options.pressed.connect(_on_options_pressed)
	if btn_exit:
		btn_exit.pressed.connect(_on_exit_pressed)
	if active_skill_box:
		active_skill_box.gui_input.connect(_on_skill_box_gui_input)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_on_char_pressed()
			KEY_I, KEY_V:
				_on_inv_pressed()
			KEY_B, KEY_F2, KEY_G:
				var hud = get_tree().get_first_node_in_group("HUD")
				if hud and hud.has_method("toggle_item_picker"):
					hud.toggle_item_picker()
			KEY_1:
				set_skill(1)
			KEY_2:
				set_skill(2)
			KEY_Q:
				if player:
					player.use_hp_potion()
			KEY_W:
				if player:
					player.use_mp_potion()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			execute_current_skill()

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
		if lbl_zen:
			lbl_zen.text = "%d" % player.zen

func update_hp(cur: int, max_val: int) -> void:
	if life_orb:
		life_orb.max_value = max_val
		life_orb.value = cur
	if lbl_hp:
		lbl_hp.text = "%d" % cur

func update_mp(cur: int, max_val: int) -> void:
	if mana_orb:
		mana_orb.max_value = max_val
		mana_orb.value = cur
	if lbl_mp:
		lbl_mp.text = "%d" % cur

func update_exp(cur: int, max_val: int, _lvl: int) -> void:
	if exp_bar:
		exp_bar.max_value = max_val
		exp_bar.value = cur
		exp_bar.tooltip_text = "EXP: %d / %d" % [cur, max_val]

func _on_char_pressed() -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_character_stats"):
		hud.toggle_character_stats()

func _on_inv_pressed() -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_inventory"):
		hud.toggle_inventory()

func _on_options_pressed() -> void:
	print("[HUD] Mở cài đặt (Options)")

func _on_exit_pressed() -> void:
	print("[HUD] Nút Thoát Game (Exit)")

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
	if current_skill_icon and player:
		var sk = player.get_active_skill()
		if sk.has("icon_path") and ResourceLoader.exists(sk["icon_path"]):
			current_skill_icon.texture = load(sk["icon_path"])

func _toggle_skill() -> void:
	_cycle_next_skill()

func execute_current_skill() -> void:
	if not player:
		return
	if player.has_method("cast_active_skill"):
		player.cast_active_skill()
	elif current_skill_type == 1:
		player.cast_twisting_slash()
	else:
		player.cast_fireball()
