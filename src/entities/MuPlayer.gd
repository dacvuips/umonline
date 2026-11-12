extends CharacterBody3D
class_name MuPlayer

# nạp trực tiếp (không phụ thuộc bộ nhớ đệm class_name của editor)
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const MuWorldRes = preload("res://src/world/MuWorld.gd")
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

## Đại diện cho nhân vật người chơi (Dark Knight, Dark Wizard, Fairy Elf...)
## Tương thích hệ toạ độ Grid 256x256 của MU Online & Hệ thống Chiến đấu

signal position_changed(grid_x: int, grid_y: int)
signal monster_defeated(monster_name: String, exp_gained: int)
signal mana_changed(current_mp: int, max_mp: int)
signal hp_changed(current_hp: int, max_hp: int)
signal exp_changed(current_exp: int, max_exp: int, level: int)
signal resets_changed(new_resets: int)
signal active_skill_changed(skill_id: String)
signal skills_updated()

@export var move_speed: float = 4.5
@export var character_name: String = "Hero"
@export var attack_range: float = 2.2 # Cự ly đánh cận chiến
@export var attack_cooldown: float = 0.65 # Tốc độ đánh ~ 1.5 hit / giây
@export var max_hp: int = 93
@export var current_hp: int = 93
@export var max_mp: int = 336
@export var current_mp: int = 336
@export var max_ag: int = 56
@export var current_ag: int = 56
@export var max_sd: int = 100
@export var current_sd: int = 100
signal ag_changed(current_ag: int, max_ag: int)
signal sd_changed(current_sd: int, max_sd: int)

# Quyền hạn tài khoản & GM (chuẩn CTLCODE_20OPERATOR = 0x20 trong MU C++ Source)
@export var ctl_code: int = 32
@export var is_gm: bool = true

func check_is_gm() -> bool:
	return is_gm or (ctl_code & 0x28) != 0

## Danh sách kỹ năng hiện có của nhân vật (Available Skills)
var available_skills: Array[Dictionary] = []
var active_skill_id: String = "twisting"

var level: int = 1
var resets: int = 0
var current_exp: int = 0
var max_exp: int = 200

# Chỉ số nhân vật MU Online (Character Stats)
var stat_str: int = 28
var stat_agi: int = 20
var stat_vit: int = 25
var stat_ene: int = 10
var stat_cmd: int = 25
var stat_points: int = 0

# Hệ thống Cấp bậc Class (Class Tier) & Nhiệm vụ NPC (Quest System)
var class_tier: int = 1 # 1: Cơ bản, 2: Cấp 2 (Blade Knight...), 3: Cấp 3 Master Class (Blade Master...)
var quest_sevina_step: int = 0 # 0: chưa nhận, 1: tìm Scroll of Emperor, 2: tìm Bảo vật tộc hệ, 3: hoàn thành
var quest_marlon_step: int = 0 # 0: chưa nhận, 1: tìm Ring of Honor, 2: tìm Dark Stone, 3: hoàn thành
var quest_devin_step: int = 0 # 0: chưa nhận, 1: tìm 3 bảo vật sức mạnh, 2: hoàn thành
var has_marlon_stat_bonus: bool = false
var has_combo_skill: bool = false
var combo_step: int = 0 # 0: chưa bắt đầu, 1: đã dùng skill vũ khí, 2: đã dùng skill class 1
var combo_timer: float = 0.0
var combo_last_skill: int = -1
var guild_name: String = ""

## Quản lý Cooldown Kỹ Năng theo chuẩn MU Online gốc (SkillAttribute[Skill].Delay)
var skill_delays: Dictionary = {}
var skill_max_delays: Dictionary = {}

var grid_x: int = 140
var grid_y: int = 119
var is_moving: bool = false
var waypoints: Array[Vector2i] = []
var virtual_joystick: Node = null
var _manual_move_active: bool = false
var infinite_hp_mp: bool = false

# Buff Binh Sĩ Bóng Ma (Shadow Phantom Soldier Buff)
var shadow_buff_atk: int = 0
var shadow_buff_def: int = 0
var shadow_buff_timer: float = 0.0

# Túi đồ & Tiền
var zen: int = 0
var inventory_items: Array[String] = []
## Túi đồ 8x8 của MU: mỗi món là Dictionary MuItems (group, number, level, ..., x, y)
var inventory: Array = []
const INV_COLS := 8
const INV_ROWS := 8
signal inventory_changed

# Rương chứa đồ (Vault / Warehouse) 8x15 = 120 ô
var vault_zen: int = 0
var vault: Array = []
var vault_pin: String = ""
var vault_locked: bool = false
const VAULT_COLS := 8
const VAULT_ROWS := 15
const MAX_VAULT_ZEN := 2000000000
const MAX_INV_ZEN := 2000000000
signal vault_changed

# Chiến đấu
signal target_monster_changed(monster: MuMonster)

var target_monster: MuMonster:
	get:
		return _target_monster
	set(value):
		if _target_monster != value:
			if is_instance_valid(_target_monster) and _target_monster.has_method("set_targeted"):
				_target_monster.set_targeted(false)
			_target_monster = value
			if is_instance_valid(_target_monster) and _target_monster.has_method("set_targeted"):
				_target_monster.set_targeted(true)
			target_monster_changed.emit(_target_monster)
var _target_monster: MuMonster = null
var attack_timer: float = 0.0

@onready var visual_root: Node3D = $VisualRoot if has_node("VisualRoot") else self

# ---------------------------------------------------------------- model MU
## Lớp: 0 Dark Wizard, 1 Dark Knight, 2 Fairy Elf, 3 Magic Gladiator, 4 Dark Lord, 5 Summoner, 6 Rage Fighter
@export_range(0, 6) var char_class: int = 1:
	set(v):
		char_class = v
		learned_skills.clear()
		_init_skills()
## Đồ đang mặc: slot -> {"group", "number", "level", "excellent"} (xem MuCharModelRes.build_player)
@export var equipment: Dictionary = {}
var model = null
var _was_moving := false
var _action_lock := 0.0
var _auto_save_timer: float = 0.0
var _run_ticks := 0.0     # c->Run của MU: số tick đã đi liên tục (>= 40 thì chạy)   # thời gian còn lại của action đánh / skill / bị đánh (không bị idle/walk đè)

func _ready() -> void:
	process_priority = -10   # di chuyển trước camera: không lệch khung hình
	add_to_group("Player")
	
	# Đảm bảo nạp đúng nhân vật từ file tài khoản hoạt động
	if MuAccountSession.character_list.is_empty() or MuAccountSession.get_selected_character().is_empty():
		MuAccountSession.load_account_characters(MuAccountSession.get_active_account())

	# Đồng bộ thông tin nhân vật từ phiên đăng nhập & chọn nhân vật
	var session_char: Dictionary = MuAccountSession.get_selected_character()
	if not session_char.is_empty():
		character_name = session_char.get("name", character_name)
		char_class = int(session_char.get("class_id", char_class))
		level = int(session_char.get("level", 1))
		current_exp = int(session_char.get("current_exp", 0))
		stat_points = int(session_char.get("stat_points", 0))
		zen = int(session_char.get("zen", 0))
		stat_str = int(session_char.get("stat_str", stat_str))
		stat_agi = int(session_char.get("stat_agi", stat_agi))
		stat_vit = int(session_char.get("stat_vit", stat_vit))
		stat_ene = int(session_char.get("stat_ene", stat_ene))
		stat_cmd = int(session_char.get("stat_cmd", stat_cmd))
		equipment = session_char.get("equipment", {}).duplicate(true)
		if session_char.has("inventory") and session_char["inventory"] is Array:
			inventory = session_char["inventory"].duplicate(true)
	else:
		MuAccountSession.selected_slot = 0
		sync_to_session()

	if not inventory_changed.is_connected(sync_to_session):
		inventory_changed.connect(sync_to_session)

	# Lưu định kỳ (vị trí / map): đóng tab web hoặc tắt đột ngột có thể không kịp gọi lúc thoát
	var autosave := Timer.new()
	autosave.wait_time = 10.0
	autosave.autostart = true
	autosave.timeout.connect(sync_to_session)
	add_child(autosave)

	if MuTerrain.pending_spawn.x >= 0:
		grid_x = MuTerrain.pending_spawn.x
		grid_y = MuTerrain.pending_spawn.y
		MuTerrain.pending_spawn = Vector2i(-1, -1)
	global_position = MuWorld.grid_to_world(grid_x, grid_y)
	rebuild_model()
	_init_skills()
	update_max_hp_mp()
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
	sync_to_session()
	emit_signal("ag_changed", current_ag, max_ag)
	emit_signal("sd_changed", current_sd, max_sd)
	emit_signal("exp_changed", current_exp, max_exp, level)
	load_vault()

# ------------------------------------------------------------------ túi đồ
func _item_size(it: Dictionary) -> Vector2i:
	return load("res://src/mu/MuItems.gd").size_of(it)

func inv_fits(x: int, y: int, w: int, h: int, ignore: Dictionary = {}) -> bool:
	if x < 0 or y < 0 or x + w > INV_COLS or y + h > INV_ROWS:
		return false
	for it in inventory:
		if not ignore.is_empty() and it == ignore:
			continue
		var s := _item_size(it)
		if x < int(it["x"]) + s.x and int(it["x"]) < x + w and y < int(it["y"]) + s.y and int(it["y"]) < y + h:
			return false
	return true

## Ô trống đầu tiên (quét theo hàng như MU)
func inv_find_free(w: int, h: int) -> Vector2i:
	for y in INV_ROWS:
		for x in INV_COLS:
			if inv_fits(x, y, w, h):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func inv_add(it: Dictionary) -> bool:
	var s := _item_size(it)
	var p := inv_find_free(s.x, s.y)
	if p.x < 0:
		return false
	var n := it.duplicate()
	n["x"] = p.x
	n["y"] = p.y
	inventory.append(n)
	inventory_changed.emit()
	return true

func inv_place(it: Dictionary, x: int, y: int) -> bool:
	var s := _item_size(it)
	if not inv_fits(x, y, s.x, s.y):
		return false
	var n := it.duplicate()
	n["x"] = x
	n["y"] = y
	inventory.append(n)
	inventory_changed.emit()
	return true

func inv_remove(it: Dictionary) -> void:
	var i := inventory.find(it)
	if i >= 0:
		inventory.remove_at(i)
		inventory_changed.emit()

func add_zen(amount: int) -> void:
	zen = maxi(0, zen + amount)
	inventory_changed.emit()

## Dùng thuốc trong túi đồ (chuột phải) — Apple / bình máu / bình mana
func use_item(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	# orb / scroll / parchment: học skill (chuột phải như MU)
	if not MuCatalogRes.skill_item(g, n).is_empty():
		learn_skill_from_item(it)
		return true
	if g != 14 or n > 8:
		return false
	match n:
		0, 1, 2, 3:
			var heal: int = [10, 20, 40, 60][n] * max_hp / 100 + 10
			current_hp = mini(max_hp, current_hp + heal)
			emit_signal("hp_changed", current_hp, max_hp)
		4, 5, 6:
			var mp: int = [20, 40, 60][n - 4] * max_mp / 100 + 10
			current_mp = mini(max_mp, current_mp + mp)
			emit_signal("mana_changed", current_mp, max_mp)
	it["dur"] = int(it.get("dur", 1)) - 1
	if int(it["dur"]) <= 0:
		inv_remove(it)
	else:
		inventory_changed.emit()
	return true

# ------------------------------------------------------------------ Rương chứa đồ (Vault / Warehouse)
func vault_fits(x: int, y: int, w: int, h: int, ignore: Dictionary = {}) -> bool:
	if x < 0 or y < 0 or x + w > VAULT_COLS or y + h > VAULT_ROWS:
		return false
	for it in vault:
		if not ignore.is_empty() and it == ignore:
			continue
		var s := _item_size(it)
		if x < int(it.get("x", 0)) + s.x and int(it.get("x", 0)) < x + w and y < int(it.get("y", 0)) + s.y and int(it.get("y", 0)) < y + h:
			return false
	return true

func vault_find_free(w: int, h: int) -> Vector2i:
	for y in VAULT_ROWS:
		for x in VAULT_COLS:
			if vault_fits(x, y, w, h):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func vault_add(it: Dictionary) -> bool:
	var s := _item_size(it)
	var p := vault_find_free(s.x, s.y)
	if p.x < 0:
		return false
	var n := it.duplicate()
	n["x"] = p.x
	n["y"] = p.y
	vault.append(n)
	vault_changed.emit()
	save_vault()
	return true

func vault_place(it: Dictionary, x: int, y: int) -> bool:
	var s := _item_size(it)
	if not vault_fits(x, y, s.x, s.y):
		return false
	var n := it.duplicate()
	n["x"] = x
	n["y"] = y
	vault.append(n)
	vault_changed.emit()
	save_vault()
	return true

func vault_remove(it: Dictionary) -> void:
	var i := vault.find(it)
	if i >= 0:
		vault.remove_at(i)
		vault_changed.emit()
		save_vault()

func vault_deposit_zen(amount: int) -> bool:
	if amount <= 0 or zen < amount:
		return false
	var can_store := MAX_VAULT_ZEN - vault_zen
	if can_store <= 0:
		return false
	var to_deposit: int = mini(amount, can_store)
	zen -= to_deposit
	vault_zen += to_deposit
	inventory_changed.emit()
	vault_changed.emit()
	save_vault()
	return true

func vault_withdraw_zen(amount: int) -> bool:
	if amount <= 0 or vault_zen < amount:
		return false
	var can_receive := MAX_INV_ZEN - zen
	if can_receive <= 0:
		return false
	var to_withdraw: int = mini(amount, can_receive)
	vault_zen -= to_withdraw
	zen += to_withdraw
	inventory_changed.emit()
	vault_changed.emit()
	save_vault()
	return true

func set_vault_pin(pin: String) -> void:
	vault_pin = pin
	save_vault()

func lock_vault() -> void:
	if vault_pin != "":
		vault_locked = true
		vault_changed.emit()
		save_vault()

func unlock_vault(pin: String) -> bool:
	if vault_pin == "" or vault_pin == pin:
		vault_locked = false
		vault_changed.emit()
		save_vault()
		return true
	return false

const VAULT_SAVE_FILE := "user://vault_data.json"

func save_vault() -> void:
	var data := {
		"zen": vault_zen,
		"items": vault,
		"pin": vault_pin,
		"locked": vault_locked
	}
	var f := FileAccess.open(VAULT_SAVE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "	"))

func sync_to_session() -> void:
	save_vault()
	var s_idx: int = MuAccountSession.selected_slot
	if s_idx < 0 or s_idx >= MuAccountSession.MAX_SLOTS:
		s_idx = 0
		MuAccountSession.selected_slot = 0
	
	while MuAccountSession.character_list.size() <= s_idx:
		MuAccountSession.character_list.append({})
	
	var char_data: Dictionary = MuAccountSession.character_list[s_idx]
	if char_data.is_empty():
		char_data["slot"] = s_idx
		char_data["class_name"] = MuAccountSession.CLASS_INFO.get(char_class, {}).get("name", "Dark Knight")
		char_data["class_title"] = MuAccountSession.get_class_title(char_class)
	
	char_data["name"] = character_name
	char_data["class_id"] = char_class
	char_data["level"] = level
	char_data["current_exp"] = current_exp
	char_data["stat_points"] = stat_points
	char_data["stat_str"] = stat_str
	char_data["stat_agi"] = stat_agi
	char_data["stat_vit"] = stat_vit
	char_data["stat_ene"] = stat_ene
	char_data["stat_cmd"] = stat_cmd
	char_data["zen"] = zen
	char_data["equipment"] = equipment.duplicate(true)
	char_data["inventory"] = inventory.duplicate(true)
	# vị trí đứng: lần sau vào game quay lại đúng map + ô này (MuCharacterSelect._connect_to_game)
	char_data["map_id"] = MuTerrain.world_id
	char_data["pos_x"] = grid_x
	char_data["pos_y"] = grid_y
	MuAccountSession.character_list[s_idx] = char_data
	MuAccountSession.save_account_characters()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		sync_to_session()

func _exit_tree() -> void:
	sync_to_session()


func load_vault() -> void:
	if not FileAccess.file_exists(VAULT_SAVE_FILE):
		return
	var f := FileAccess.open(VAULT_SAVE_FILE, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		vault_zen = int(parsed.get("zen", 0))
		vault = parsed.get("items", [])
		vault_pin = str(parsed.get("pin", ""))
		vault_locked = bool(parsed.get("locked", false))
		vault_changed.emit()

## Giết quái: kinh nghiệm theo cấp quái (MuMonster.exp_reward)
func reward_kill(m) -> void:
	var e: int = m.exp_reward(level) if m.has_method("exp_reward") else 90
	add_exp(e)
	emit_signal("monster_defeated", m.monster_name, e)

## Phòng thủ của người chơi (MU: Nhanh nhẹn / 3, cộng phòng thủ đồ mặc ~ cấp đồ)
func defense_value() -> int:
	var d := stat_agi / 3
	for slot in ["helm", "armor", "pants", "gloves", "boots", "left"]:
		if equipment.has(slot):
			d += 4 + int(equipment[slot].get("level", 0)) * 3
	return d

var _dead := false

## Bị quái đánh: trừ phòng thủ, hiện số sát thương, hết máu thì chết rồi hồi sinh ở thành
func take_damage(damage: int, _attacker: Node = null) -> void:
	if _dead or current_hp <= 0:
		return
	if infinite_hp_mp:
		current_hp = max_hp
		current_sd = max_sd
		current_ag = max_ag
		emit_signal("hp_changed", current_hp, max_hp)
		emit_signal("sd_changed", current_sd, max_sd)
		emit_signal("ag_changed", current_ag, max_ag)
		return
	# Giảm sát thương từ Thú Cưỡi & Thần Thú (Helper absorption)
	if equipment.has("helper"):
		var hn := int(equipment["helper"].get("number", 0))
		if hn == 0: # Thiên Thần (-20%)
			damage = int(damage * 0.8)
		elif hn == 65: # Thần Hộ Mệnh (-30%)
			damage = int(damage * 0.7)
		elif hn == 4: # Chiến Mã DL (-30%)
			damage = int(damage * 0.7)
		elif hn == 3: # Dinorant (-10%)
			damage = int(damage * 0.9)
		elif hn == 37 and int(equipment["helper"].get("excellent_flags", 0)) == 2: # Sói Tinh Protect (-10%)
			damage = int(damage * 0.9)
	damage = maxi(maxi(1, damage / 10), damage - defense_value())
	
	# Giáp SD (Shield) hấp thụ 90% sát thương (chuẩn MU Online)
	if current_sd > 0:
		var sd_dmg = mini(current_sd, int(damage * 0.9))
		current_sd -= sd_dmg
		damage -= sd_dmg
		emit_signal("sd_changed", current_sd, max_sd)
	
	current_hp = maxi(0, current_hp - damage)
	emit_signal("hp_changed", current_hp, max_hp)
	var lbl = DamageNumber3D.new()
	get_parent().add_child(lbl)
	lbl.setup(damage, DamageNumber3D.DamageType.MISS if damage <= 0 else DamageNumber3D.DamageType.NORMAL, global_position)
	lbl.modulate = Color(1.0, 0.35, 0.3)
	if current_hp <= 0:
		_die()
	elif model and _action_lock <= 0.0 and not is_moving:
		model.play_shock()
		# cưỡi Uniria / Dinorant / Dark Horse: không có animation trúng đòn (SetPlayerShock) -> không khoá action
		if not (str(model.get("ride_kind")) in ["unidino", "darkhorse"]):
			_lock_action(0.3)

func _die() -> void:
	_dead = true
	waypoints.clear()
	is_moving = false
	target_monster = null
	if model:
		model.play_die()
	_lock_action(99.0)
	get_tree().create_timer(3.0).timeout.connect(_respawn)

## Hồi sinh: đầy máu / mana, về cổng xuất hiện của bản đồ (spawns.json "spawn_gate")
func _respawn() -> void:
	var tile := Vector2i(140, 119) if MuTerrain.world_id == 1 else Vector2i(grid_x, grid_y)
	var spf := "res://assets/mu/spawns.json"
	if FileAccess.file_exists(spf):
		var sd = JSON.parse_string(FileAccess.get_file_as_string(spf))
		var key := str(MuTerrain.world_id)
		if sd is Dictionary and sd.has(key) and sd[key].get("spawn_gate") is Dictionary:
			var g: Dictionary = sd[key]["spawn_gate"]
			tile = Vector2i(randi_range(int(g["x1"]), int(g["x2"])), randi_range(int(g["y1"]), int(g["y2"])))
	grid_x = tile.x
	grid_y = tile.y
	waypoints.clear()
	global_position = MuWorld.grid_to_world(grid_x, grid_y)
	current_hp = max_hp
	current_mp = max_mp
	current_ag = max_ag
	current_sd = max_sd
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
	sync_to_session()
	emit_signal("ag_changed", current_ag, max_ag)
	emit_signal("sd_changed", current_sd, max_sd)
	emit_signal("position_changed", grid_x, grid_y)
	_dead = false
	_action_lock = 0.0
	if model:
		model.set_safe_zone(is_in_safe_zone())
		model.play_idle(is_in_safe_zone())

## Dựng lại model MU theo char_class + equipment (gọi lại sau khi đổi đồ)
func rebuild_model() -> void:
	if model == null:
		model = MuCharModelRes.new()
		model.name = "MuModel"
		visual_root.add_child(model)
	if _build_body():
		# ẩn hình tạm (CSG) khi đã có model thật
		for c in visual_root.get_children():
			if c != model and c is Node3D:
				c.visible = false
		model.set_safe_zone(is_in_safe_zone())
		model.play_idle(is_in_safe_zone())
		_update_helper_fx()
	else:
		push_warning("[MuPlayer] Chưa có model Player (assets/mu/Player/player.glb) — chạy tools/CHUYEN_DOI_MODEL_MU.bat")

## Nhẫn biến hình (ChangeRingManager / TransformationRing trong Source): nhân vật đổi thành quái hoặc model riêng.
##  13:10 theo cấp nhẫn: Budge Dragon, Giant, Skeleton Warrior, Poison Bull, Thunder Lich, Death Cow.
##  "monster" = số hiệu quái trong Monsters.json ; "skin" = model đè lên bộ xương nhân vật.
const TRANSFORM_RING_LEVEL_MONSTERS := [2, 7, 14, 8, 9, 41]
const TRANSFORM_RINGS := {
	39: {"skin": "res://assets/mu/Item/trans_skeleton.glb"},   # Nhẫn Bộ Xương Elite
	122: {"skin": "res://assets/mu/Item/trans_skeleton.glb"},  # Nhẫn Bộ Xương
	40: {"skin": "res://assets/mu/Skill/jack.glb"},           # Nhẫn Jack O'Lantern
	41: {"skin": "res://assets/mu/Skill/santa.glb"},          # Nhẫn Giáng Sinh (Santa)
	42: {"skin": "res://assets/mu/Skill/youngza.glb"},        # Nhẫn GM
	68: {"monster": 467},   # Nhẫn Người Tuyết
	76: {"skin": "res://assets/mu/Item/panda.glb"},           # Nhẫn Gấu Trúc
}

## Thông tin biến hình đang có ({} nếu không đeo nhẫn biến hình)
func transform_spec() -> Dictionary:
	for slot in ["ring_right", "ring_left"]:
		var it = equipment.get(slot)
		if not (it is Dictionary) or int(it.get("group", 0)) != 13:
			continue
		var n := int(it.get("number", 0))
		if n == 10:
			var lv := clampi(int(it.get("level", 0)), 0, TRANSFORM_RING_LEVEL_MONSTERS.size() - 1)
			return {"monster": TRANSFORM_RING_LEVEL_MONSTERS[lv]}
		if TRANSFORM_RINGS.has(n):
			return TRANSFORM_RINGS[n]
	return {}

func _build_body() -> bool:
	var spec := transform_spec()
	if spec.has("monster") and model.build_monster(int(spec["monster"])):
		return true
	if spec.has("skin"):
		var eq := equipment.duplicate()
		eq["_skin"] = spec["skin"]
		if model.build_player(char_class, eq):
			return true
	return model.build_player(char_class, equipment)

func set_class(cls: int) -> void:
	char_class = clampi(cls, 0, 6)
	rebuild_model()

const MuHelperFxRes = preload("res://src/entities/MuHelperFx.gd")
const MuDarkRavenRes = preload("res://src/entities/MuDarkRaven.gd")
var dark_raven: Node3D = null
var _raven_key := ""

## Quạ Tinh (13:5) ở tay trái (hoặc ô helper của save cũ) -> MuDarkRaven bay theo chủ
func _update_raven() -> void:
	var it: Dictionary = {}
	for slot in ["left", "helper"]:
		var e = equipment.get(slot)
		if e is Dictionary and int(e.get("group", -1)) == 13 and int(e.get("number", -1)) == 5:
			it = e
			break
	var key := "" if it.is_empty() else "raven:%d" % int(it.get("level", 0))
	if key == _raven_key and (key == "" or is_instance_valid(dark_raven)):
		return
	_raven_key = key
	var old_cmd := 0
	if is_instance_valid(dark_raven):
		old_cmd = int(dark_raven.command)
		dark_raven.queue_free()
	dark_raven = null
	if key != "":
		dark_raven = MuDarkRavenRes.new()
		dark_raven.name = "DarkRaven"
		dark_raven.setup(self, int(it.get("level", 0)))
		dark_raven.command = old_cmd
		get_parent().add_child.call_deferred(dark_raven)
	var hud = get_tree().get_first_node_in_group("HUD") if is_inside_tree() else null
	if hud and hud.has_method("on_raven_command_changed"):
		hud.on_raven_command_changed.call_deferred()

var _helper_fx: Node3D = null
var _helper_key := ""

## Dựng / gỡ thú cưỡi hoặc thú đi theo theo ô "helper" (nhóm 13). Thú cưỡi: nâng người lên và đổi action sang cưỡi.
func _update_helper_fx() -> void:
	_update_raven()
	var it: Dictionary = equipment.get("helper", {}) if equipment.get("helper") is Dictionary else {}
	var key := "%d:%d:%d" % [int(it.get("group", 0)), int(it.get("number", 0)), int(it.get("excellent_flags", 0))] if not it.is_empty() else ""
	if key != _helper_key or (key != "" and not is_instance_valid(_helper_fx)):
		if is_instance_valid(_helper_fx):
			_helper_fx.queue_free()
		_helper_fx = null
		_helper_key = key
		if key != "" and MuHelperFxRes.is_visual_helper(it):
			_helper_fx = MuHelperFxRes.new()
			_helper_fx.name = "HelperFx"
			add_child(_helper_fx)
			_helper_fx.setup(self, it)
	update_max_hp_mp()
	var mi: Dictionary = MuHelperFxRes.mount_of(it) if key != "" else {}
	_ride_info = mi
	var safe := is_in_safe_zone()
	if model != null:
		if not mi.is_empty() and not safe:
			model.position.y = float(mi.get("lift", 0.0))
			var hn := int(it.get("number", 0))
			model.ride_kind = "fenrir" if hn == 37 else ("darkhorse" if hn == 4 else ("unidino" if hn == 2 or hn == 3 else ""))
		else:
			model.position.y = 0.0
			model.ride_kind = ""

var _ride_info: Dictionary = {}

## slot: helm/armor/pants/gloves/boots/right/left/wings ; number < 0 -> tháo
func equip(slot: String, group: int, number: int, item_level: int = 0, excellent: bool = false) -> void:
	if number < 0:
		equipment.erase(slot)
	else:
		equipment[slot] = {"group": group, "number": number, "level": item_level, "excellent": excellent}
	rebuild_model()
	sync_to_session()

func is_in_safe_zone() -> bool:
	return (MuTerrain.attribute_at(grid_x, grid_y) & 1) != 0

func _lock_action(seconds: float) -> void:
	_action_lock = seconds

## CharacterMoveSpeed (ZzzCharacter.cpp): đơn vị MU / tick (25 tick/s, 100 đơn vị = 1 ô)
##   đi bộ 12, chạy 15 (sau 40 tick đi liên tục ngoài thành), có cánh 15 (Dragon/Storm 16)
func current_move_speed() -> float:
	# CharacterMoveSpeed (ZzzCharacter.cpp): trong thành mọi người / thú đều đi bộ tốc độ 12.
	# Ngoài thành: Sói Tinh đi bộ trước, c->Run < 10: 15 ; < 20: 16 ; từ 20 tick: 17 (19 nếu có cờ Excellent) ;
	# Chiến Mã luôn 17 ; Uniria / Dinorant / có cánh: 15 (cánh Rồng / Bão 16).
	var sp := 12.0
	var safe := is_in_safe_zone()
	var hn := int(equipment["helper"].get("number", 0)) if equipment.get("helper") is Dictionary else -1
	if not safe and hn == 37:
		if _run_ticks < FENRIR_RUN_DELAY / 2.0:
			sp = 15.0
		elif _run_ticks < FENRIR_RUN_DELAY:
			sp = 16.0
		else:
			sp = 19.0 if int(equipment["helper"].get("excellent_flags", 0)) > 0 else 17.0
	elif not safe and hn == 4:
		sp = 17.0
	elif not safe and (equipment.has("wings") or hn == 2 or hn == 3):
		var wn := int(equipment["wings"].get("number", 0)) if equipment.get("wings") is Dictionary else -1
		sp = 16.0 if wn == 5 or wn == 36 else 15.0
	elif is_running():
		sp = 15.0
	return sp * 25.0 / 100.0

## Số tick đi liên tục trước khi Sói Tinh chuyển từ đi bộ sang chạy (FENRIR_RUN_DELAY trong _define.h)
const FENRIR_RUN_DELAY := 20.0

## Đang cưỡi thú và đang ở dạng "chạy" (true) hay "đi bộ" (false). Theo Source:
##   Sói Tinh: đi bộ cho tới khi đi liên tục đủ 20 tick (~0.8 s) ngoài thành rồi mới chạy ; trong thành luôn đi bộ.
##   Chiến Mã / Uniria / Dinorant: ngoài thành luôn chạy (Run = 40), trong thành đi bộ.
func ride_running() -> bool:
	if is_in_safe_zone():
		return false
	var hn := int(equipment["helper"].get("number", 0)) if equipment.get("helper") is Dictionary else -1
	if hn == 37:
		return _run_ticks >= FENRIR_RUN_DELAY
	return true

func is_running() -> bool:
	return _run_ticks >= 40.0 and not is_in_safe_zone()

func _update_animation(delta: float) -> void:
	if model == null or model.anim == null:
		return
	if _action_lock > 0.0:
		_action_lock -= delta
		if _action_lock > 0.0 and not model.is_action_finished():
			return
		_action_lock = 0.0
		_was_moving = not is_moving
	var safe := is_in_safe_zone()
	if model != null:
		model.set_safe_zone(safe)
	# GOBoid.cpp (MoveMount) & ZzzCharacter.cpp (RenderCharacter / SetPlayerStop / SetPlayerWalk):
	# Trong thành (SafeZone), cấm cưỡi thú: thú cưỡi tự động ẩn đi, nhân vật đứng/đi bộ bằng chân
	# và cất vũ khí sau lưng. Chỉ khi bước ra khỏi thành (vùng chiến đấu) mới cưỡi thú.
	if not _ride_info.is_empty() and not safe:
		if model != null:
			model.position.y = float(_ride_info.get("lift", 0.0))
			var it: Dictionary = equipment.get("helper", {}) if equipment.get("helper") is Dictionary else {}
			var hn := int(it.get("number", 0))
			model.ride_kind = "fenrir" if hn == 37 else ("darkhorse" if hn == 4 else ("unidino" if hn == 2 or hn == 3 else ""))
		if not is_moving:
			model.play_action(int(_ride_info["p_idle"]))
		elif ride_running():
			model.play_action(int(_ride_info["p_move"]))
		else:
			model.play_action(int(_ride_info.get("p_walk", _ride_info["p_move"])))
		_was_moving = is_moving
		return

	# Trong thành (SafeZone) HOẶC không trang bị thú cưỡi:
	if model != null:
		model.position.y = 0.0
		model.ride_kind = ""
	if is_moving:
		model.play_move(is_running(), safe)
	else:
		model.play_idle(safe)
	_was_moving = is_moving

## Thêm kinh nghiệm và kiểm tra Thăng Cấp (Level Up)
func add_exp(amount: int) -> void:
	if equipment.has("helper") and int(equipment["helper"].get("number", 0)) == 80: # Panda Pet
		amount = int(amount * 1.5) # +50% EXP!
	current_exp += amount
	print("[MuPlayer] Nhận +%d EXP! (Hiện tại: %d/%d)" % [amount, current_exp, max_exp])
	while current_exp >= max_exp:
		current_exp -= max_exp
		level += 1
		max_exp = int(max_exp * 1.45)
		# Tăng chỉ số khi lên cấp chuẩn MU
		var pts = 5
		if char_class == 3 or char_class == 4: # MG / DL
			pts = 7
		elif has_marlon_stat_bonus and level >= 220: # Marlon quest bonus
			pts = 6
		stat_points += pts
		update_max_hp_mp()
		current_hp = max_hp
		current_mp = max_mp
		current_ag = max_ag
		current_sd = max_sd
		
		# Phát hiệu ứng ánh sáng Level Up rực rỡ
		var lvl_effect = LevelUpEffect.new()
		lvl_effect.global_position = global_position
		get_parent().add_child(lvl_effect)
		print("[MuPlayer] *** CHÚC MỪNG BẠN ĐÃ LÊN CẤP %d! ***" % level)

	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
	sync_to_session()
	emit_signal("ag_changed", current_ag, max_ag)
	emit_signal("sd_changed", current_sd, max_sd)
	emit_signal("exp_changed", current_exp, max_exp, level)

func add_stat_point(stat_name: String, amount: int = 1) -> bool:
	if stat_points <= 0 or amount <= 0:
		return false
	var actual_add = mini(stat_points, amount)
	stat_points -= actual_add
	match stat_name:
		"str":
			stat_str += actual_add
		"agi":
			stat_agi += actual_add
			_update_attack_speed()
		"vit":
			stat_vit += actual_add
		"ene":
			stat_ene += actual_add
		"cmd", "command":
			stat_cmd += actual_add
	update_max_hp_mp()
	sync_to_session()
	return true

func update_max_hp_mp() -> void:
	max_hp = 110 + level * 20 + maxi(0, stat_vit - 25) * 3
	max_mp = 40 + level * 15 + maxi(0, stat_ene - 10) * 2
	max_ag = int(50 + level * 1.5 + stat_str * 0.2 + stat_agi * 0.25 + stat_vit * 0.3 + stat_ene * 0.15)
	max_sd = int(stat_str * 1.2 + stat_agi * 1.0 + stat_vit * 1.0 + stat_ene * 1.0 + level * 2)
	# Thú đeo: Thiên Thần / Thần Hộ Mệnh +50 sinh lực tối đa ; Fenrir Illusion + cấp / 2 sinh lực và mana
	if equipment.get("helper") is Dictionary:
		var hh: Dictionary = equipment["helper"]
		var hnum := int(hh.get("number", 0))
		if hnum == 0 or hnum == 65:
			max_hp += 50
		elif hnum == 37 and int(hh.get("excellent_flags", 0)) == 4:
			max_hp += level / 2
			max_mp += level / 2
	current_hp = mini(current_hp, max_hp)
	current_mp = mini(current_mp, max_mp)

## Trả về tên hiển thị chuẩn xác của Class theo Cấp bậc (Class Tier)
func get_class_display_name() -> String:
	const CLASS_NAMES = {
		0: ["Dark Wizard", "Soul Master", "Grand Master"],
		1: ["Dark Knight", "Blade Knight", "Blade Master"],
		2: ["Fairy Elf", "Muse Elf", "High Elf"],
		3: ["Magic Gladiator", "Magic Gladiator", "Duel Master"],
		4: ["Dark Lord", "Dark Lord", "Lord Emperor"],
		5: ["Summoner", "Bloody Summoner", "Dimension Master"],
		6: ["Rage Fighter", "Rage Fighter", "Fist Master"]
	}
	var tier = clampi(class_tier - 1, 0, 2)
	var names = CLASS_NAMES.get(char_class, ["Chiến Binh", "Hiệp Sĩ", "Đại Hiệp Sĩ"])
	return names[tier]

## Kiểm tra người chơi có sở hữu vật phẩm (nhóm, số) trong túi đồ
func has_item(group: int, number: int) -> bool:
	for it in inventory:
		if it is Dictionary and int(it.get("group", -1)) == group and int(it.get("number", -1)) == number:
			return true
	return false

## Đếm số lượng vật phẩm (nhóm, số) trong túi đồ
func count_item(group: int, number: int) -> int:
	var c := 0
	for it in inventory:
		if it is Dictionary and int(it.get("group", -1)) == group and int(it.get("number", -1)) == number:
			c += 1
	return c

## Xóa một số lượng vật phẩm (nhóm, số) khỏi túi đồ
func remove_item_by_id(group: int, number: int, count: int = 1) -> bool:
	var removed := 0
	var to_remove := []
	for it in inventory:
		if it is Dictionary and int(it.get("group", -1)) == group and int(it.get("number", -1)) == number:
			to_remove.append(it)
			removed += 1
			if removed >= count:
				break
	for it in to_remove:
		inv_remove(it)
	return removed >= count

## Thêm vật phẩm vào túi đồ
func give_item(group: int, number: int, item_lvl: int = 0, exc: bool = false, skill: bool = false, luck: bool = false, opt: int = 0) -> bool:
	var it = {
		"group": group,
		"number": number,
		"level": item_lvl,
		"excellent": exc,
		"skill": skill,
		"luck": luck,
		"opt": opt,
		"dur": 255
	}
	return inv_add(it)

## Thăng cấp bậc lớp nhân vật (Class Tier 1 -> Tier 2 -> Tier 3)
func promote_class_tier(target_tier: int) -> void:
	if target_tier <= class_tier:
		return
	class_tier = target_tier
	var bonus_points = 20 if target_tier == 2 else 30
	stat_points += bonus_points
	update_max_hp_mp()
	current_hp = max_hp
	current_mp = max_mp

	# Hiệu ứng thăng hoa Level Up
	var fx = LevelUpEffect.new()
	fx.global_position = global_position
	get_parent().add_child(fx)

	if MuAudioManager:
		MuAudioManager.play_sound_file("sKnightSkill1.wav")

	var new_name = get_class_display_name()
	print("[MuPlayer] *** CHÚC MỪNG BẠN ĐÃ THĂNG CHỨC THÀNH %s! (Nhận +%d Điểm Tiềm Năng) ***" % [new_name, bonus_points])

## Sửa chữa toàn bộ trang bị đang mặc và trong túi đồ về độ bền 100%
func repair_all_items() -> Dictionary:
	var repaired_count := 0
	var total_cost := 0

	# Quét trang bị đang mặc
	for slot in equipment:
		var it = equipment[slot]
		if it is Dictionary and it.has("dur"):
			var cur_dur = int(it.get("dur", 255))
			var max_dur = 255
			if cur_dur < max_dur:
				var cost = (max_dur - cur_dur) * 10
				total_cost += cost
				it["dur"] = max_dur
				repaired_count += 1

	# Quét túi đồ
	for it in inventory:
		if it is Dictionary and it.has("dur"):
			var cur_dur = int(it.get("dur", 255))
			var max_dur = 255
			if cur_dur < max_dur:
				var cost = (max_dur - cur_dur) * 10
				total_cost += cost
				it["dur"] = max_dur
				repaired_count += 1

	if total_cost > 0:
		add_zen(-total_cost)
		inventory_changed.emit()

	return {"count": repaired_count, "cost": total_cost}
	current_ag = mini(current_ag, max_ag)
	current_sd = mini(current_sd, max_sd)
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
	sync_to_session()
	emit_signal("ag_changed", current_ag, max_ag)
	emit_signal("sd_changed", current_sd, max_sd)

func set_level(new_lvl: int, give_points: bool = true) -> void:
	new_lvl = clampi(new_lvl, 1, 400)
	var diff = new_lvl - level
	level = new_lvl
	if give_points and diff > 0:
		var pts = 7 if (char_class == 3 or char_class == 4) else 5
		stat_points += diff * pts
	update_max_hp_mp()
	current_hp = max_hp
	current_mp = max_mp
	current_ag = max_ag
	current_sd = max_sd
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
	sync_to_session()
	emit_signal("ag_changed", current_ag, max_ag)
	emit_signal("sd_changed", current_sd, max_sd)
	emit_signal("exp_changed", current_exp, max_exp, level)
	var fx = LevelUpEffect.new()
	fx.global_position = global_position
	if get_parent():
		get_parent().add_child(fx)

func set_resets(new_resets: int, points_per_reset: int = 500) -> void:
	new_resets = maxi(0, new_resets)
	var diff = new_resets - resets
	resets = new_resets
	if diff > 0 and points_per_reset > 0:
		stat_points += diff * points_per_reset
	emit_signal("exp_changed", current_exp, max_exp, level)
	emit_signal("resets_changed", resets)

func perform_reset(points_per_reset: int = 500, reset_to_level: int = 1, reset_stats: bool = false) -> void:
	resets += 1
	level = clampi(reset_to_level, 1, 400)
	current_exp = 0
	max_exp = 200
	if reset_stats:
		reset_stat_points()
	stat_points += points_per_reset
	update_max_hp_mp()
	current_hp = max_hp
	current_mp = max_mp
	emit_signal("exp_changed", current_exp, max_exp, level)
	emit_signal("resets_changed", resets)
	var fx = LevelUpEffect.new()
	fx.global_position = global_position
	if get_parent():
		get_parent().add_child(fx)

func gm_add_points(amount: int) -> void:
	stat_points += amount

func reset_stat_points() -> void:
	var cinfo: Dictionary = MuAccountSession.CLASS_INFO.get(char_class, {})
	var base_str: int = int(cinfo.get("str", 28))
	var base_agi: int = int(cinfo.get("agi", 20))
	var base_vit: int = int(cinfo.get("vit", 25))
	var base_ene: int = int(cinfo.get("ene", 10))
	var base_cmd: int = int(cinfo.get("cmd", 25 if char_class == 4 else 0))
	var refunded := maxi(0, stat_str - base_str) + maxi(0, stat_agi - base_agi) + maxi(0, stat_vit - base_vit) + maxi(0, stat_ene - base_ene) + maxi(0, stat_cmd - base_cmd)
	stat_points += refunded
	stat_str = base_str
	stat_agi = base_agi
	stat_vit = base_vit
	stat_ene = base_ene
	stat_cmd = base_cmd
	max_hp = 110 + level * 20
	max_mp = 40 + level * 15
	current_hp = max_hp
	current_mp = max_mp
	_update_attack_speed()
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
	sync_to_session()
	sync_to_session()

func toggle_god_mode() -> bool:
	infinite_hp_mp = not infinite_hp_mp
	if infinite_hp_mp:
		current_hp = max_hp
		current_mp = max_mp
		emit_signal("hp_changed", current_hp, max_hp)
		emit_signal("mana_changed", current_mp, max_mp)
	return infinite_hp_mp

## Sử dụng bình máu (Health Potion)
func use_hp_potion() -> void:
	if current_hp < max_hp:
		current_hp = min(max_hp, current_hp + 40)
		emit_signal("hp_changed", current_hp, max_hp)
		if MuAudioManager:
			MuAudioManager.play_potion_drink()
		print("[MuPlayer] Sử dụng Bình Máu! HP hiện tại: %d/%d" % [current_hp, max_hp])

## Sử dụng bình mana (Mana Potion)
func use_mp_potion() -> void:
	if current_mp < max_mp:
		current_mp = min(max_mp, current_mp + 40)
		emit_signal("mana_changed", current_mp, max_mp)
		if MuAudioManager:
			MuAudioManager.play_potion_drink()
		print("[MuPlayer] Sử dụng Bình Mana! MP hiện tại: %d/%d" % [current_mp, max_mp])

## Thi triển kỹ năng Cầu Lửa Tầm Xa (Fireball Ranged Skill)
func cast_fireball(target: MuMonster = null) -> void:
	if is_in_safe_zone():
		return
	var target_to_hit = target if target else target_monster
	if not is_instance_valid(target_to_hit) or target_to_hit.is_dead:
		# Tự tìm con quái vật gần nhất trong bán kính 9m
		target_to_hit = _find_nearest_monster(9.0)
		if not target_to_hit:
			print("[MuPlayer] Không tìm thấy mục tiêu trong tầm bắn!")
			return

	var mana_cost = 8
	if not infinite_hp_mp:
		if current_mp < mana_cost:
			print("[MuPlayer] Không đủ Mana để bắn Cầu Lửa!")
			return
		current_mp -= mana_cost
		emit_signal("mana_changed", current_mp, max_mp)
	else:
		current_mp = max_mp

	if MuAudioManager:
		MuAudioManager.play_fireball_cast(global_position)

	# Xoay mặt về mục tiêu
	var dir = (target_to_hit.global_position - global_position)
	dir.y = 0.0
	rotation.y = atan2(dir.x, dir.z)
	if model:
		model.play_skill(MuCharModelRes.P_SKILL_HAND1)
		_lock_action(0.9)

	# Tạo đạn cầu lửa bay
	var fb = FireballProjectile.new()
	fb.global_position = global_position + Vector3(0, 1.2, 0)
	fb.setup(target_to_hit, randi_range(35, 60), self)
	get_parent().add_child(fb)

func _find_nearest_monster(radius: float) -> MuMonster:
	var parent_node = get_parent()
	if not parent_node:
		return null
	var nearest: MuMonster = null
	var min_dist = radius
	for child in parent_node.get_children():
		if child is MuMonster and not child.is_dead:
			var d = global_position.distance_to(child.global_position)
			if d < min_dist:
				min_dist = d
				nearest = child
	return nearest

## Thi triển kỹ năng Xoay Kiếm (Twisting Slash AoE)
func cast_twisting_slash() -> void:
	if is_in_safe_zone():
		return
	var mana_cost = 12
	if not infinite_hp_mp:
		if current_mp < mana_cost:
			print("[MuPlayer] Không đủ Mana để thi triển Twisting Slash!")
			return
		current_mp -= mana_cost
		emit_signal("mana_changed", current_mp, max_mp)
	else:
		current_mp = max_mp

	if model:
		model.play_skill(MuCharModelRes.P_SKILL_WHEEL, 0.30)
		_lock_action(1.0)

	_spawn_twisting_slash_fx()

	var is_combo := check_combo(41)

	# Gây sát thương toàn bộ quái vật trong bán kính 3.5m
	var aoe_radius = 3.5
	var parent_node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is MuMonster and not child.is_dead:
				var dist = global_position.distance_to(child.global_position)
				if dist <= aoe_radius:
					var dmg = randi_range(40, 75)
					var roll = randf()
					var dmg_type = DamageNumber3D.DamageType.NORMAL
					if is_combo:
						var combo_bonus := int((stat_str + stat_agi + stat_ene) / 2.0)
						dmg = int(dmg * 1.5) + combo_bonus
						dmg_type = DamageNumber3D.DamageType.COMBO
						if MuAudioManager:
							MuAudioManager.play_combo(child.global_position)
						var fx = ComboEffect3D.new()
						get_parent().add_child(fx)
						fx.setup(child.global_position)
					elif roll < 0.2:
						dmg = int(dmg * 1.5)
						dmg_type = DamageNumber3D.DamageType.EXCELLENT
					elif roll < 0.4:
						dmg = int(dmg * 1.25)
						dmg_type = DamageNumber3D.DamageType.CRITICAL
					child.take_damage(dmg, dmg_type)
					if child.is_dead:
						reward_kill(child)

## Hiệu ứng Twisting Slash gốc (MODEL_SKILL_WHEEL1/2) + SOUND_SKILL_SWORD4 (sKnightSkill4.wav)
func _spawn_twisting_slash_fx() -> void:
	if MuAudioManager:
		MuAudioManager.play_sound_file("sKnightSkill4.wav", 0.0, 1.0, global_position)
	var slash = TwistingSlashEffect.new()
	slash.setup(self)
	get_parent().add_child(slash)

func _update_attack_speed() -> void:
	# MU Online gốc: Tốc độ tấn công (AttackSpeed) tăng theo Nhanh Nhẹn (Agility)
	# Agi 20 -> cooldown ~ 0.52s (~ 2 hit/s)
	# Agi 100 -> cooldown ~ 0.40s (~ 2.5 hit/s)
	# Agi 500 -> cooldown ~ 0.15s (~ 6.6 hit/s)
	attack_cooldown = clampf(0.55 - float(stat_agi) * 0.0008, 0.15, 0.65)

## Kiểm tra xem kỹ năng có đang hồi chiêu (Cooldown) không (chuẩn CSkillManager::CheckSkillDelay)
func check_skill_delay(skill_num: int) -> bool:
	if skill_delays.has(skill_num) and skill_delays[skill_num] > 0.0:
		return false
	return true

## Kích hoạt bộ đếm hồi chiêu cho kỹ năng theo Delay gốc (SkillAttribute[Skill].Delay)
func trigger_skill_delay(skill_num: int) -> void:
	var sk := MuCatalogRes.skill(skill_num)
	var cd := float(sk.get("cooldown", 0.0))
	if cd > 0.0:
		skill_delays[skill_num] = cd
		skill_max_delays[skill_num] = cd

## Lấy tỉ lệ hồi chiêu còn lại (0.0 -> 1.0) cho UI vẽ bóng mờ xoay vòng (ComputeSkillCooldownFraction)
func get_skill_cooldown_fraction(skill_num: int) -> float:
	if not skill_delays.has(skill_num):
		return 0.0
	var cur := float(skill_delays.get(skill_num, 0.0))
	if cur <= 0.0:
		return 0.0
	var max_cd := float(skill_max_delays.get(skill_num, 1.0))
	return clampf(cur / maxf(0.001, max_cd), 0.0, 1.0)

## Lấy số giây hồi chiêu còn lại của kỹ năng
func get_skill_cooldown_remaining(skill_num: int) -> float:
	return maxf(0.0, float(skill_delays.get(skill_num, 0.0)))

func _init_skills() -> void:
	if learned_skills.is_empty() and not _skills_cleared_by_user:
		# Tự động nạp toàn bộ bộ kỹ năng của lớp nhân vật hiện tại
		learn_all_skills(false)
		return

	available_skills.clear()

	# 1. Đòn đánh vật lý cơ bản (Normal Attack - Skill 0)
	available_skills.append({
		"id": "attack",
		"skill": 0,
		"name": "Đánh Thường",
		"icon_path": "res://assets/textures/ui/skills/skill_0.png",
		"mana_cost": 0,
		"cooldown": 0.0,
		"desc": "Đòn đánh cận chiến cơ bản, không tiêu tốn Mana"
	})

	# 2. Toàn bộ các kỹ năng đã học (Skills của lớp nhân vật)
	for num in learned_skills:
		if num == 0 or num >= 300:
			continue
		available_skills.append(_learned_skill_entry(int(num)))

	# 3. Chọn skill mặc định phù hợp với lớp nhân vật nếu skill hiện tại chưa có
	var valid_ids: Array = []
	for s in available_skills:
		valid_ids.append(str(s.get("id", "")))

	if not valid_ids.has(active_skill_id) or active_skill_id == "twisting":
		var preferred_map := {
			0: "sk_4",   # DW: Cầu Lửa (Fireball)
			1: "sk_41",  # DK: Xoay Kiếm (Twisting Slash)
			2: "sk_24",  # Elf: Tam Tiễn (Triple Shot)
			3: "sk_55",  # MG: Chém Lửa (Fire Slash)
			4: "sk_61",  # DL: Hỏa Long (Fireburst)
			5: "sk_215", # SUM: Tia Sét Lan (Chain Lightning)
			6: "sk_260", # RF: Cú Đấm Hủy Diệt (Killing Blow)
		}
		var preferred: String = preferred_map.get(char_class, "sk_41")
		if valid_ids.has(preferred):
			active_skill_id = preferred
		elif available_skills.size() > 1:
			active_skill_id = str(available_skills[1]["id"])
		elif available_skills.size() > 0:
			active_skill_id = str(available_skills[0]["id"])

	emit_signal("skills_updated")
	emit_signal("active_skill_changed", active_skill_id)

func get_available_skills() -> Array[Dictionary]:
	return available_skills

func set_active_skill(skill_id: String) -> void:
	var mapped_id := skill_id
	match skill_id:
		"twisting":
			mapped_id = "sk_41"
		"fireball":
			mapped_id = "sk_4"
		"teleport":
			mapped_id = "sk_6"
		"buff":
			mapped_id = "sk_48"
	active_skill_id = mapped_id
	emit_signal("active_skill_changed", active_skill_id)

func get_active_skill() -> Dictionary:
	for sk in available_skills:
		if str(sk.get("id", "")) == active_skill_id:
			return sk
	if available_skills.size() > 0:
		return available_skills[0]
	return {}

func cast_active_skill() -> void:
	if active_skill_id == "attack" or active_skill_id == "sk_0":
		attack_nearest()
		return
	if active_skill_id.begins_with("sk_"):
		var num := active_skill_id.substr(3).to_int()
		cast_learned_skill(num)
		return
	match active_skill_id:
		"twisting":
			cast_learned_skill(41)
		"fireball":
			cast_learned_skill(4)
		"teleport":
			cast_learned_skill(6)
		"buff":
			cast_learned_skill(48)
		_:
			attack_nearest()

# ============================================================ skill học từ orb / scroll (skills.json)
## Số skill (SkillNumber của OpenMU) đã học
var learned_skills: Array[int] = []
var _skills_cleared_by_user: bool = false

func _say(text: String) -> void:
	var tree := get_tree()
	var chat = tree.get_first_node_in_group("ChatWindow") if tree else null
	if chat and chat.has_method("add_system_message"):
		chat.add_system_message(text)
	else:
		print("[MuPlayer] ", text)

## Chuột phải orb / scroll / parchment: kiểm tra lớp, cấp, chỉ số như MU (CanLearnSkill), học rồi mất món đồ
func learn_skill_from_item(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	var req := MuCatalogRes.skill_item(g, n)
	var num := int(req.get("skill", -1))
	var sk := MuCatalogRes.skill(num)
	if sk.is_empty():
		return false
	var nm := str(sk.get("name", "skill"))
	var classes: Dictionary = req.get("classes", {})
	if not classes.is_empty() and not classes.has(str(char_class)):
		_say("[color=red]Lớp nhân vật này không học được %s.[/color]" % nm)
		return false
	if num in learned_skills:
		_say("[color=orange]Đã học %s rồi.[/color]" % nm)
		return false
	var fails: Array[String] = []
	if level < int(req.get("level", 0)):
		fails.append("cấp %d" % int(req["level"]))
	if stat_ene < int(req.get("energy", 0)):
		fails.append("Năng lượng %d" % int(req["energy"]))
	if stat_str < int(req.get("strength", 0)):
		fails.append("Sức mạnh %d" % int(req["strength"]))
	if stat_agi < int(req.get("agility", 0)):
		fails.append("Nhanh nhẹn %d" % int(req["agility"]))
	if not fails.is_empty():
		_say("[color=red]Chưa đủ điều kiện học %s: cần %s.[/color]" % [nm, ", ".join(fails)])
		return false
	learned_skills.append(num)
	inv_remove(it)
	_init_skills()
	set_active_skill("sk_%d" % num)
	_say("[color=lime]Đã học kỹ năng %s![/color]" % nm)
	if MuAudioManager:
		MuAudioManager.play_sound_file("sKnightSkill1.wav")
	var fx = LevelUpEffect.new()
	fx.global_position = global_position
	get_parent().add_child(fx)
	return true

## GM: Học toàn bộ kỹ năng (theo class hoặc tất cả class) để kiểm tra source/hiệu ứng
func learn_all_skills(include_all_classes: bool = false) -> int:
	_skills_cleared_by_user = false
	MuCatalogRes.ensure_loaded()
	var all_sk := MuCatalogRes.get_all_skills()
	var added := 0
	var keys = all_sk.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var num := int(k)
		# Bỏ qua toàn bộ Master Skill Tree passives / strengtheners (>= 300)
		if num >= 300:
			continue
		var sk: Dictionary = all_sk[k]
		if str(sk.get("type", "")) == "PassiveBoost":
			continue
		var classes: Array = sk.get("classes", [])
		var matches_class := false
		for c in classes:
			if int(c) == char_class:
				matches_class = true
				break
		if not include_all_classes:
			if not matches_class:
				continue
		else:
			if classes.is_empty():
				continue
		if not num in learned_skills:
			learned_skills.append(num)
			added += 1
	if added > 0 or not learned_skills.is_empty():
		_init_skills()
		emit_signal("skills_updated")
		if MuAudioManager:
			MuAudioManager.play_sound_file("sKnightSkill1.wav")
	return added

## Học một kỹ năng theo số SkillNumber trực tiếp
func learn_skill_number(num: int) -> bool:
	if num <= 0 or num >= 300:
		return false
	if num in learned_skills:
		return false
	_skills_cleared_by_user = false
	learned_skills.append(num)
	_init_skills()
	emit_signal("skills_updated")
	if MuAudioManager:
		MuAudioManager.play_sound_file("sKnightSkill1.wav")
	return true

## GM: Đặt lại danh sách kỹ năng về rỗng (chỉ còn đánh thường, để hiển thị trạng thái chưa học màu xám)
func clear_learned_skills() -> void:
	_skills_cleared_by_user = true
	learned_skills.clear()
	available_skills.clear()
	available_skills.append({
		"id": "attack",
		"skill": 0,
		"name": "Đánh Thường",
		"icon_path": "res://assets/textures/ui/skills/skill_0.png",
		"mana_cost": 0,
		"cooldown": 0.0,
		"desc": "Đòn đánh cận chiến cơ bản, không tiêu tốn Mana"
	})
	active_skill_id = "attack"
	emit_signal("skills_updated")
	emit_signal("active_skill_changed", active_skill_id)

## Loại hiệu ứng chung của skill: "buff", "teleport", "area", "magic", "melee"
static func skill_kind(sk: Dictionary) -> String:
	var key := str(sk.get("key", ""))
	var typ := str(sk.get("type", ""))
	if key.begins_with("Teleport"):
		return "teleport"
	if typ in ["Buff", "Regeneration", "SummonMonster"] or str(sk.get("damage_type", "")) == "None" and typ != "DirectHit":
		return "buff"
	if typ.begins_with("AreaSkill") or typ == "Nova":
		return "area"
	if str(sk.get("damage_type", "")) in ["Wizardry", "Curse", "Fenrir"]:
		return "magic"
	return "melee"

func _learned_skill_entry(num: int) -> Dictionary:
	var sk := MuCatalogRes.skill(num)
	var kind := skill_kind(sk)
	var icon_file := MuCatalogRes.get_skill_icon_path(num)
	var vn_name := MuCatalogRes.get_skill_vietnamese_name(num, str(sk.get("name", "Skill %d" % num)))
	var cd := float(sk.get("cooldown", 0.0))

	return {
		"id": "sk_%d" % num,
		"skill": num,
		"name": vn_name,
		"icon_path": icon_file,
		"mana_cost": int(sk.get("mana", 0)),
		"cooldown": cd,
		"desc": "%s (%s)" % [vn_name, kind],
	}

## Quản lý chuỗi liên hoàn đòn (Combo Skill) của Chiến Binh (Blade Knight)
## Chuẩn gốc Webzen Season 6 / OpenMU SkillsInitializer.cs:
## Bước 1: Kỹ năng Vũ Khí (Falling Slash 19, Lunge 20, Uppercut 21, Cyclone 22, Slash 23)
## Bước 2: Kỹ năng Class đợt 1 (Twisting Slash 41, Rageful Blow 42, Death Stab 43, Strike of Destruction 232)
## Bước 3: Kỹ năng Class đợt 2 (BẮT BUỘC KHÁC Bước 2) -> Nổ COMBO bộc phá!
func check_combo(skill_id: int) -> bool:
	if not (has_combo_skill or quest_marlon_step >= 3 or char_class == 1):
		return false
	# Nhóm 1: Skill vũ khí (Cyclone, Slash, Falling Slash, Lunge, Uppercut)
	var is_weapon_sk = skill_id in [19, 20, 21, 22, 23]
	# Nhóm 2 & 3: Skill chiêu thức BK (Twisting Slash, Death Stab, Rageful Blow, Strike of Destruction)
	var is_bk_sk = skill_id in [41, 42, 43, 232]

	if combo_step == 0:
		if is_weapon_sk:
			combo_step = 1
			combo_timer = 3.0
			combo_last_skill = skill_id
			_say("[color=#FFD700]★ Combo [Bước 1/3]: Đòn Vũ Khí thành công! Tiếp tục chiêu thức Class...[/color]")
		return false
	elif combo_step == 1:
		if is_bk_sk:
			combo_step = 2
			combo_timer = 3.0
			combo_last_skill = skill_id
			_say("[color=#FF8800]★ Combo [Bước 2/3]: Chiêu thức 1 thành công! Dùng chiêu thức KHÁC để nổ Combo...[/color]")
		elif is_weapon_sk:
			combo_step = 1
			combo_timer = 3.0
			combo_last_skill = skill_id
			_say("[color=#FFD700]★ Combo [Bước 1/3]: Đã làm mới đòn Vũ Khí.[/color]")
		else:
			combo_step = 0
			combo_timer = 0.0
			combo_last_skill = -1
		return false
	elif combo_step == 2:
		if is_bk_sk:
			if skill_id != combo_last_skill:
				# Chuẩn xác 100% Webzen/OpenMU: Chiêu thức bước 3 phải khác chiêu thức bước 2!
				combo_step = 0
				combo_timer = 0.0
				combo_last_skill = -1
				var combo_bonus := int((stat_str + stat_agi + stat_ene) / 2.0)
				_say("[color=#00FFFF]★ [COMBO BỘC PHÁ THÀNH CÔNG] Sát thương Nộ nổ cực đại: +%d Dame! ★[/color]" % combo_bonus)
				return true
			else:
				# Dùng chiêu trùng với bước 2 -> reset combo theo luật MU
				combo_step = 0
				combo_timer = 0.0
				combo_last_skill = -1
				_say("[color=#FF5555]★ Combo bị ngắt: Bước 3 phải dùng chiêu thức khác với Bước 2! Chuỗi combo đã reset.[/color]")
				return false
		elif is_weapon_sk:
			combo_step = 1
			combo_timer = 3.0
			combo_last_skill = skill_id
			_say("[color=#FFD700]★ Combo [Bước 1/3]: Đã chuyển lại đòn Vũ Khí.[/color]")
		else:
			combo_step = 0
			combo_timer = 0.0
			combo_last_skill = -1
	return false

## Tự động xuất chuỗi Combo 3 đòn liên hoàn (chuẩn MU Helper): Cyclone -> Twisting Slash -> Death Stab
func trigger_auto_combo_strike() -> void:
	if not (has_combo_skill or quest_marlon_step >= 3 or char_class == 1):
		_say("[color=red]Chưa mở khóa Combo Skill! Hãy gặp Marlon (Lorencia 130, 126) hoặc dùng GM Window.[/color]")
		return
	var m = target_monster if is_instance_valid(target_monster) and not target_monster.is_dead else _find_nearest_monster(7.0)
	if not m:
		_say("[color=orange]Không tìm thấy quái vật trong tầm để xuất Combo![/color]")
		return
	target_monster = m

	_say("[color=#00FFCC]⚡ [MU Helper Combo] Bắt đầu chuỗi Combo bộc phá 3 bước...[/color]")
	# Đòn 1: Cyclone (22)
	cast_learned_skill(22)

	# Đòn 2 sau 0.35s: Twisting Slash (41)
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(m) and not m.is_dead:
			cast_learned_skill(41)
	)

	# Đòn 3 sau 0.70s: Death Stab (43) -> KÍCH HOẠT NỔ COMBO!
	get_tree().create_timer(0.70).timeout.connect(func():
		if is_instance_valid(m) and not m.is_dead:
			cast_learned_skill(43)
	)

## Dùng skill đã học: sát thương / mana / tầm theo skills.json, hiệu ứng chung theo loại
func cast_learned_skill(num: int) -> void:
	if is_in_safe_zone():
		return
	var sk := MuCatalogRes.skill(num)
	if sk.is_empty() or _dead:
		return

	# 1. Kiểm tra Cooldown riêng của kỹ năng (chuẩn CSkillManager::CheckSkillDelay từ source gốc)
	if not check_skill_delay(num):
		return

	var kind := skill_kind(sk)

	# 2. Với các kỹ năng tấn công: tuân theo nhịp tốc độ đánh (attack_timer theo Agility)
	if kind != "buff" and kind != "teleport":
		if attack_timer > 0.0:
			return

	if kind == "teleport":
		cast_teleport()
		trigger_skill_delay(num)
		return
	var mana := int(sk.get("mana", 0))
	if not infinite_hp_mp:
		if current_mp < mana:
			_say("[color=red]Không đủ Mana (%d) để dùng %s.[/color]" % [mana, sk.get("name", "")])
			return
	var reach := maxf(2.0, float(sk.get("distance", 2)) + 0.5)
	var target: MuMonster = target_monster if is_instance_valid(target_monster) and not target_monster.is_dead else null
	if kind != "buff" and (target == null or global_position.distance_to(target.global_position) > reach + 1.0):
		target = _find_nearest_monster(reach + 1.0)
	if kind in ["magic", "melee"] and target == null:
		_say("[color=orange]Không có mục tiêu trong tầm %s.[/color]" % sk.get("name", ""))
		return
	if not infinite_hp_mp:
		current_mp -= mana
		emit_signal("mana_changed", current_mp, max_mp)
	else:
		current_mp = max_mp
	if target != null:
		var dir := target.global_position - global_position
		dir.y = 0.0
		if dir.length() > 0.01:
			rotation.y = atan2(dir.x, dir.z)

	# Đặt nhịp tấn công theo Agility và kích hoạt Cooldown riêng của kỹ năng (nếu có Delay)
	if kind != "buff":
		attack_timer = attack_cooldown
		_lock_action(attack_cooldown)
	trigger_skill_delay(num)

	var is_combo := check_combo(num)

	# hiệu ứng gốc theo assets/mu/skill_fx.json (tools/mu_skill_fx.py); skill chưa có dữ liệu dùng bản cũ bên dưới
	if MuSkillFx.has_skill(num):
		if kind == "buff":
			MuSkillFx.play(self, num, self)
			_apply_buff_skill(sk)
			return
		var delay := MuSkillFx.play(self, num, target)
		var victims: Array = []
		if kind == "area":
			victims = _area_victims(sk, target)
		elif target != null:
			victims.append(target)
		_hit_later(maxf(delay, 0.0), victims, sk, is_combo)
		return
	match kind:
		"buff":
			_cast_buff_skill(sk)
		"area":
			_cast_area_skill(sk, target, is_combo)
		"magic":
			if model:
				model.play_skill(MuCharModelRes.P_SKILL_HAND1)
				_lock_action(0.9)
			if MuAudioManager:
				MuAudioManager.play_fireball_cast(global_position)
			var fb = FireballProjectile.new()
			fb.global_position = global_position + Vector3(0, 1.2, 0)
			fb.setup(target, _skill_damage(sk), self)
			get_parent().add_child(fb)
		_:
			if model:
				model.play_skill(MuCharModelRes.P_SKILL_WEAPON1, 0.4)
				_lock_action(0.7)
			if MuAudioManager:
				MuAudioManager.play_weapon_swing(global_position)
			_hit_monster(target, _skill_damage(sk), is_combo)

## Sát thương skill: vật lý = đòn thường + damage của skill ; phép = Năng lượng / 4 + damage * 2 ; ±20%
func _skill_damage(sk: Dictionary) -> int:
	var base := float(sk.get("damage", 0))
	var num := int(sk.get("skill", sk.get("number", 0)))
	var dmg: float
	if num == 40 or str(sk.get("key", "")) == "Nova":
		# Sát thương Gồng Nộ Nova chuẩn OpenMU (FixDamageCalcsPlugInSeason6.cs:291 & NovaDamageTable stage 12)
		dmg = stat_ene * 2.2 + 880.0 + stat_str / 2.0
	elif str(sk.get("damage_type", "")) in ["Wizardry", "Curse"]:
		dmg = stat_ene / 4.0 + base * 2.0 + 20.0
	else:
		dmg = randf_range(30.0, 55.0) + stat_str / 6.0 + base
	# Gia tăng sát thương từ Thú Cưỡi & Thần Thú (Satan, Demon, Dinorant, Fenrir)
	if equipment.has("helper"):
		var hn := int(equipment["helper"].get("number", 0))
		if hn == 1: # Tiểu Quỷ Satan (+30%)
			dmg *= 1.3
		elif hn == 64: # Quỷ Vương Demon (+40%)
			dmg *= 1.4
		elif hn == 3: # Quái Điểu Dinorant (+15%)
			dmg *= 1.15
		elif hn == 37: # Sói Tinh: Destroy +10% ; Illusion + cấp / 12 sát thương vật lý (Pets.cs của OpenMU)
			var ff := int(equipment["helper"].get("excellent_flags", 0))
			if ff == 1:
				dmg *= 1.1
			elif ff == 4:
				dmg += float(level / 12)
		elif hn == 123: # Pet Skeleton (+20%)
			dmg *= 1.2
	dmg += float(shadow_buff_atk)
	return maxi(1, int(dmg * randf_range(0.8, 1.2)))

func _hit_monster(m: MuMonster, dmg: int, is_combo: bool = false) -> void:
	if m == null or m.is_dead:
		return
	var t := DamageNumber3D.DamageType.NORMAL
	var roll := randf()
	if is_combo:
		var combo_bonus := int((stat_str + stat_agi + stat_ene) / 2.0)
		dmg = int(dmg * 1.5) + combo_bonus
		t = DamageNumber3D.DamageType.COMBO
		if MuAudioManager:
			MuAudioManager.play_combo(m.global_position)
		var fx = ComboEffect3D.new()
		get_parent().add_child(fx)
		fx.setup(m.global_position)
	elif roll < 0.15:
		dmg = int(dmg * 1.5)
		t = DamageNumber3D.DamageType.EXCELLENT
	elif roll < 0.35:
		dmg = int(dmg * 1.25)
		t = DamageNumber3D.DamageType.CRITICAL
	if not is_combo and MuAudioManager:
		MuAudioManager.play_melee_hit(m.global_position)
	m.take_damage(dmg, t)
	if m.is_dead:
		reward_kill(m)

## Quái trong vùng của skill vùng: quanh mục tiêu (phép) hoặc quanh mình (vật lý)
func _area_victims(sk: Dictionary, target: MuMonster) -> Array:
	var magic := str(sk.get("damage_type", "")) in ["Wizardry", "Curse"]
	var center := global_position
	if magic and target != null:
		center = target.global_position
	var radius := clampf(float(maxi(int(sk.get("range", 0)), 2)) + 0.5, 2.5, 5.0)
	var out: Array = []
	for child in get_parent().get_children():
		if child is MuMonster and not child.is_dead and center.distance_to(child.global_position) <= radius:
			out.append(child)
	return out

## Gây sát thương khi hiệu ứng tới nơi (đạn bay / tia sét ...)
func _hit_later(delay: float, victims: Array, sk: Dictionary, is_combo: bool = false) -> void:
	if victims.is_empty():
		return
	if delay <= 0.01:
		for m in victims:
			_hit_monster(m, _skill_damage(sk), is_combo)
		return
	get_tree().create_timer(delay).timeout.connect(func():
		for m in victims:
			if is_instance_valid(m) and not m.is_dead:
				_hit_monster(m, _skill_damage(sk), is_combo))

## Skill vùng: quanh mục tiêu (phép) hoặc quanh mình (vật lý), bán kính theo tầm của skill
func _cast_area_skill(sk: Dictionary, target: MuMonster, is_combo: bool = false) -> void:
	var magic := str(sk.get("damage_type", "")) in ["Wizardry", "Curse"]
	var center := global_position
	if magic and target != null:
		center = target.global_position
	var radius := clampf(float(maxi(int(sk.get("range", 0)), 2)) + 0.5, 2.5, 5.0)
	if model:
		model.play_skill(MuCharModelRes.P_SKILL_HAND2 if magic else MuCharModelRes.P_SKILL_WHEEL, 0.3)
		_lock_action(1.0)
	if str(sk.get("key", "")).begins_with("TwistingSlash"):
		_spawn_twisting_slash_fx()
	else:
		if MuAudioManager:
			if magic:
				MuAudioManager.play_fireball_cast(global_position)
			else:
				MuAudioManager.play_twisting_slash(global_position)
		var fx = AreaRingEffect.new()
		get_parent().add_child(fx)
		fx.global_position = center
	for child in get_parent().get_children():
		if child is MuMonster and not child.is_dead and center.distance_to(child.global_position) <= radius:
			_hit_monster(child, _skill_damage(sk), is_combo)

## Skill buff / hồi máu: hồi máu theo Năng lượng, hiệu ứng sáng quanh người
func _cast_buff_skill(sk: Dictionary) -> void:
	if model and model.anim:
		model.play_skill(MuCharModelRes.P_SKILL_WEAPON1, 0.4)
		_lock_action(0.8)
	if MuAudioManager:
		MuAudioManager.play_sound_file("sKnightSkill1.wav")
	_apply_buff_skill(sk)
	var fx = LevelUpEffect.new()
	fx.global_position = global_position
	get_parent().add_child(fx)

## Tác dụng của buff (hiện chỉ hồi máu)
func _apply_buff_skill(sk: Dictionary) -> void:
	var key := str(sk.get("key", ""))
	if key.contains("Heal") or key.contains("Recovery") or key.contains("SwellLife") or key.contains("Life"):
		current_hp = mini(max_hp, current_hp + 30 + stat_ene / 5)
		emit_signal("hp_changed", current_hp, max_hp)

## Thi triển kỹ năng Dịch chuyển tức thời (Teleport)
func cast_teleport() -> void:
	var mana_cost = 15
	if not infinite_hp_mp:
		if current_mp < mana_cost:
			print("[MuPlayer] Không đủ Mana để Dịch chuyển!")
			return
		current_mp -= mana_cost
		emit_signal("mana_changed", current_mp, max_mp)
	else:
		current_mp = max_mp

	var tp_start = TeleportEffect.new()
	tp_start.global_position = global_position
	get_parent().add_child(tp_start)

	if MuAudioManager:
		MuAudioManager.play_sound_file("sMagic.wav")

	if model and model.anim:
		model.play_skill(MuCharModelRes.P_SKILL_TELEPORT, 0.4)
		_lock_action(0.6)

	var forward_dir = Vector3(sin(rotation.y), 0, cos(rotation.y)).normalized()
	var target_pos = global_position + forward_dir * 4.0
	var target_grid = MuWorld.world_to_grid(target_pos)
	var world = get_parent().get_node_or_null("MuWorld")
	if world and world.astar.has_point(world._get_point_id(target_grid.x, target_grid.y)):
		grid_x = target_grid.x
		grid_y = target_grid.y
		global_position = MuWorld.grid_to_world(grid_x, grid_y)
		waypoints.clear()
	else:
		global_position = target_pos
		var g = MuWorld.world_to_grid(global_position)
		grid_x = g.x
		grid_y = g.y
		waypoints.clear()

	var tp_end = TeleportEffect.new()
	tp_end.global_position = global_position
	get_parent().add_child(tp_end)

## Thi triển kỹ năng Gồng Máu (Greater Fortitude)
func cast_greater_fortitude() -> void:
	var mana_cost = 20
	if not infinite_hp_mp:
		if current_mp < mana_cost:
			print("[MuPlayer] Không đủ Mana để Gồng Máu!")
			return
		current_mp -= mana_cost
		emit_signal("mana_changed", current_mp, max_mp)
	else:
		current_mp = max_mp

	current_hp = min(max_hp, current_hp + 50)
	emit_signal("hp_changed", current_hp, max_hp)

	if MuAudioManager:
		MuAudioManager.play_sound_file("sKnightSkill1.wav")

	if model and model.anim:
		model.play_skill(MuCharModelRes.P_SKILL_WEAPON1, 0.4)
		_lock_action(0.8)

	var lvl = LevelUpEffect.new()
	lvl.global_position = global_position
	get_parent().add_child(lvl)

## Tấn công quái vật gần nhất hoặc vung vũ khí
func attack_nearest() -> void:
	if is_in_safe_zone():
		return
	if not is_instance_valid(target_monster) or target_monster.is_dead:
		target_monster = _find_nearest_monster(4.0)

	if is_instance_valid(target_monster) and not target_monster.is_dead:
		var dist = global_position.distance_to(target_monster.global_position)
		if dist <= attack_range:
			_perform_attack()
		else:
			set_attack_target(target_monster)
	else:
		_perform_attack_swing()

## Báo cho kênh nhiều người chơi để người khác thấy mình ra đòn
func _notify_multiplayer_attack() -> void:
	var mp = get_tree().get_first_node_in_group("MuMultiplayer")
	if mp:
		mp.send_attack(Vector2i(grid_x, grid_y), global_position, target_monster)

func _perform_attack_swing() -> void:
	if is_in_safe_zone():
		return
	attack_timer = attack_cooldown
	if MuAudioManager:
		MuAudioManager.play_weapon_swing(global_position)
	if model and model.anim:
		model.play_attack(stat_agi)
		_notify_multiplayer_attack()
		_lock_action(attack_cooldown)
	else:
		var tween = create_tween()
		var forward_dir = transform.basis.z.normalized()
		tween.tween_property(visual_root, "position", forward_dir * 0.25, 0.1)
		tween.tween_property(visual_root, "position", Vector3.ZERO, 0.15)

## Tự động tìm và khóa mục tiêu quái gần nhất
func acquire_nearest_target() -> MuMonster:
	var m = _find_nearest_monster(10.0)
	if m:
		target_monster = m
		var dir = (m.global_position - global_position)
		dir.y = 0.0
		rotation.y = atan2(dir.x, dir.z)
		print("[MuPlayer] Khóa mục tiêu: %s" % m.monster_name)
	return m

func _unhandled_key_input(_event: InputEvent) -> void:
	pass

## Thu thập hướng di chuyển từ Bàn Phím (WASD / Mũi Tên), Cần Điều Khiển Ảo (Virtual Joystick) và Tay Cầm Gamepad
func _get_movement_input() -> Vector2:
	# Không di chuyển bằng phím nếu người chơi đang nhập text trong giao diện (Chat, Tên, v.v.)
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return Vector2.ZERO

	var input_vec := Vector2.ZERO

	# 1. Bàn phím: WASD hoặc Phím mũi tên (Arrow Keys)
	# Trục màn hình 2D: Lên (W/Up) -> y=+1, Xuống (S/Down) -> y=-1, Trái (A/Left) -> x=-1, Phải (D/Right) -> x=+1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0

	if input_vec.length_squared() > 0.01:
		return input_vec.normalized()

	# 2. Cần điều khiển ảo (Virtual Joystick)
	if not virtual_joystick or not is_instance_valid(virtual_joystick):
		var hud_joy = get_node_or_null("../MuHud/MobileControls/VirtualJoystick")
		if hud_joy:
			virtual_joystick = hud_joy

	if virtual_joystick and is_instance_valid(virtual_joystick) and virtual_joystick.has_method("get_direction"):
		var joy_dir: Vector2 = virtual_joystick.get_direction()
		if joy_dir.length_squared() > 0.01:
			# Kéo Joystick lên màn hình thì joy_dir.y < 0 -> đổi dấu -joy_dir.y để hướng lên là +1
			return Vector2(joy_dir.x, -joy_dir.y).normalized()

	# 3. Gamepad / Tay cầm chơi game (Analog Stick & D-Pad)
	var joy_axis_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_axis_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(joy_axis_x) < 0.2: joy_axis_x = 0.0
	if abs(joy_axis_y) < 0.2: joy_axis_y = 0.0

	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): joy_axis_y -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): joy_axis_y += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): joy_axis_x -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): joy_axis_x += 1.0

	var pad_vec := Vector2(joy_axis_x, joy_axis_y)
	if pad_vec.length_squared() > 0.04:
		return Vector2(pad_vec.x, -pad_vec.y).normalized()

	return Vector2.ZERO

## Xử lý di chuyển liên tục mượt mà theo 8 hướng trong không gian MU
func _handle_continuous_movement(move_input: Vector2, _delta: float) -> void:
	# Hủy mục tiêu đánh quái cũ khi người chơi chủ động điều khiển
	target_monster = null
	
	if not _manual_move_active:
		_manual_move_active = true
		waypoints.clear()

	# Chuyển hướng 2D màn hình sang hướng không gian 3D thế giới dựa trên Camera
	var cam = get_viewport().get_camera_3d()
	var right := Vector3(1, 0, 0)
	var fwd := Vector3(0, 0, -1)
	if cam:
		right = cam.global_transform.basis.x
		fwd = -cam.global_transform.basis.z
	right.y = 0.0
	fwd.y = 0.0
	right = right.normalized()
	fwd = fwd.normalized()

	var world_dir: Vector3 = (right * move_input.x + fwd * move_input.y).normalized()

	# Chuyển đổi sang hệ toạ độ ô Grid của MU Online:
	# Godot +x = MU +x ; Godot -z = MU +y
	var mu_dx = world_dir.x
	var mu_dy = -world_dir.z
	var mu_dir = Vector2(mu_dx, mu_dy).normalized()

	# Khi chỉ còn <= 1 waypoint, tính toán và thêm ô kế tiếp để nhân vật chạy liên tục không bị gián đoạn
	if waypoints.size() <= 1:
		var from_tile: Vector2i = waypoints[0] if waypoints.size() > 0 else Vector2i(grid_x, grid_y)
		var step_x := 0
		var step_y := 0
		if abs(mu_dir.x) > 0.38:
			step_x = 1 if mu_dir.x > 0 else -1
		if abs(mu_dir.y) > 0.38:
			step_y = 1 if mu_dir.y > 0 else -1

		if step_x != 0 or step_y != 0:
			var world = get_parent().get_node_or_null("MuWorld")
			var check_walkable = func(tx: int, ty: int) -> bool:
				if not world:
					return true
				if world.has_method("is_walkable"):
					return world.is_walkable(tx, ty)
				elif world.has_method("is_tile_walkable"):
					return world.is_tile_walkable(tx, ty)
				return true

			var next_tile = from_tile + Vector2i(step_x, step_y)
			if check_walkable.call(next_tile.x, next_tile.y):
				if waypoints.is_empty() or waypoints[waypoints.size() - 1] != next_tile:
					waypoints.append(next_tile)
			elif step_x != 0 and step_y != 0:
				# Wall-sliding: Nếu đi chéo bị kẹt tường, lướt theo cạnh ngang hoặc dọc
				var alt_x = from_tile + Vector2i(step_x, 0)
				var alt_y = from_tile + Vector2i(0, step_y)
				if check_walkable.call(alt_x.x, alt_x.y):
					if waypoints.is_empty() or waypoints[waypoints.size() - 1] != alt_x:
						waypoints.append(alt_x)
				elif check_walkable.call(alt_y.x, alt_y.y):
					if waypoints.is_empty() or waypoints[waypoints.size() - 1] != alt_y:
						waypoints.append(alt_y)

func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= 5.0:
		_auto_save_timer = 0.0
		sync_to_session()
	if infinite_hp_mp:
		if current_hp < max_hp:
			current_hp = max_hp
			emit_signal("hp_changed", current_hp, max_hp)
		if current_mp < max_mp:
			current_mp = max_mp
			emit_signal("mana_changed", current_mp, max_mp)
	if _dead:
		_update_animation(delta)
		return
	if attack_timer > 0.0:
		attack_timer -= delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0
			combo_last_skill = -1

	# Đếm lùi thời gian hồi chiêu kỹ năng (chuẩn CSkillManager::CalcSkillDelay)
	if not skill_delays.is_empty():
		var finished_skills: Array = []
		for sk_num in skill_delays.keys():
			skill_delays[sk_num] -= delta
			if skill_delays[sk_num] <= 0.0:
				finished_skills.append(sk_num)
		for sk_num in finished_skills:
			skill_delays.erase(sk_num)

	# Xử lý input di chuyển từ Bàn phím (WASD / Mũi tên) và Cần điều khiển ảo (Joystick)
	var move_input := _get_movement_input()
	if move_input.length_squared() > 0.01:
		_handle_continuous_movement(move_input, delta)
	elif _manual_move_active:
		_manual_move_active = false

	# Xử lý mục tiêu tấn công
	if is_instance_valid(target_monster) and not target_monster.is_dead:
		var dist_to_target = global_position.distance_to(target_monster.global_position)
		if dist_to_target <= attack_range:
			# Đã trong tầm đánh, dừng di chuyển và tấn công
			waypoints.clear()
			is_moving = false
			
			# Xoay mặt về phía quái vật
			var dir = (target_monster.global_position - global_position)
			dir.y = 0.0
			if dir.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 15.0 * delta)

			if attack_timer <= 0.0:
				_perform_attack()
		else:
			# Chưa vào tầm đánh, nếu không có đường đi thì tự động tìm đường tới gần
			if waypoints.size() == 0 and not is_moving:
				_pathfind_to_monster()
	else:
		target_monster = null

	# Xử lý di chuyển: đi hết "ngân sách" quãng đường của khung hình qua các ô liên tiếp (không giật / không dịch ô)
	if waypoints.size() > 0:
		is_moving = true
		if is_in_safe_zone():
			_run_ticks = 0.0
		else:
			_run_ticks = minf(_run_ticks + delta * 25.0, 40.0)
		var budget: float = current_move_speed() * delta
		var look_dir := Vector3.ZERO
		while budget > 0.0 and waypoints.size() > 0:
			var next_tile: Vector2i = waypoints[0]
			var target_world_pos: Vector3 = MuWorld.grid_to_world(next_tile.x, next_tile.y)
			var dir: Vector3 = target_world_pos - global_position
			dir.y = 0.0
			var dist := dir.length()
			if dist > 0.001:
				look_dir = dir
			if dist <= budget:
				global_position.x = target_world_pos.x
				global_position.z = target_world_pos.z
				budget -= dist
				grid_x = next_tile.x
				grid_y = next_tile.y
				waypoints.remove_at(0)
				emit_signal("position_changed", grid_x, grid_y)
			else:
				global_position += dir / dist * budget
				var cur_g := MuWorld.world_to_grid(global_position)
				if cur_g.x != grid_x or cur_g.y != grid_y:
					grid_x = cur_g.x
					grid_y = cur_g.y
					emit_signal("position_changed", grid_x, grid_y)
				budget = 0.0
		if waypoints.size() == 0:
			is_moving = false
		global_position.y = MuWorld.ground_height(global_position)
		if look_dir.length() > 0.001:
			rotation.y = lerp_angle(rotation.y, atan2(look_dir.x, look_dir.z), clampf(15.0 * delta, 0.0, 1.0))
	else:
		is_moving = false
		_run_ticks = 0.0
	_update_animation(delta)

func _perform_attack() -> void:
	if is_in_safe_zone():
		return
	attack_timer = attack_cooldown
	
	if MuAudioManager:
		MuAudioManager.play_weapon_swing(global_position)

	# Action đánh của MU theo loại vũ khí (SetPlayerAttack)
	if model and model.anim:
		model.play_attack(stat_agi)
		_notify_multiplayer_attack()
		_lock_action(attack_cooldown)
	else:
		var tween = create_tween()
		var forward_dir = transform.basis.z.normalized()
		tween.tween_property(visual_root, "position", forward_dir * 0.25, 0.1)
		tween.tween_property(visual_root, "position", Vector3.ZERO, 0.15)

	# Tính toán sát thương MU
	var dmg_roll = randf()
	var base_dmg = randi_range(30, 55)
	var dmg_type = DamageNumber3D.DamageType.NORMAL
	
	if dmg_roll < 0.15: # 15% Excellent Damage
		base_dmg = int(base_dmg * 1.5)
		dmg_type = DamageNumber3D.DamageType.EXCELLENT
	elif dmg_roll < 0.35: # 20% Critical Damage
		base_dmg = int(base_dmg * 1.25)
		dmg_type = DamageNumber3D.DamageType.CRITICAL

	if MuAudioManager and is_instance_valid(target_monster):
		MuAudioManager.play_melee_hit(target_monster.global_position)

	target_monster.take_damage(base_dmg, dmg_type)
	if target_monster.is_dead:
		reward_kill(target_monster)
		target_monster = null

func _pathfind_to_monster() -> void:
	var world = get_parent().get_node_or_null("MuWorld")
	if world and is_instance_valid(target_monster):
		var my_tile := MuWorld.world_to_grid(global_position)
		var monster_tile = Vector2i(target_monster.grid_x, target_monster.grid_y)
		var path = world.find_path_grid(my_tile, monster_tile)
		if path.size() > 1:
			path.remove_at(path.size() - 1) # Dừng trước 1 ô, không dẫm lên quái
			move_to_path(path)

## Chọn mục tiêu tấn công
func set_attack_target(monster: MuMonster) -> void:
	if is_in_safe_zone():
		return
	target_monster = monster
	if is_instance_valid(target_monster):
		var dist = global_position.distance_to(target_monster.global_position)
		if dist > attack_range:
			_pathfind_to_monster()

## Đặt lộ trình di chuyển theo chuỗi ô Grid (sẽ hủy mục tiêu tấn công nếu người chơi chủ động click đi nơi khác)
func move_to_path(new_path: Array[Vector2i]) -> void:
	if new_path.is_empty():
		return
	var cur_tile := MuWorld.world_to_grid(global_position)
	grid_x = cur_tile.x
	grid_y = cur_tile.y
	# Bỏ ô đầu nếu chính là ô nhân vật đang đứng
	if new_path.size() > 0 and new_path[0] == cur_tile:
		new_path.remove_at(0)
	# Nếu đang di chuyển và đã tiến gần tới ô kế tiếp hơn ô xuất phát
	if new_path.size() > 1:
		var p0: Vector3 = MuWorld.grid_to_world(new_path[0].x, new_path[0].y)
		var p1: Vector3 = MuWorld.grid_to_world(new_path[1].x, new_path[1].y)
		var here := Vector3(global_position.x, 0.0, global_position.z)
		p0.y = 0.0
		p1.y = 0.0
		if here.distance_to(p1) < p0.distance_to(p1):
			new_path.remove_at(0)
	waypoints = new_path
	is_moving = waypoints.size() > 0

## Hủy đánh khi người chơi click đất
func clear_target() -> void:
	target_monster = null

func sync_server_position(x: int, y: int) -> void:
	grid_x = x
	grid_y = y
	waypoints.clear()
	global_position = MuWorld.grid_to_world(x, y)
	emit_signal("position_changed", grid_x, grid_y)

## Dịch chuyển tức thời tới ô (dùng cho lệnh /move)
func teleport_to(tile: Vector2i) -> void:
	target_monster = null
	is_moving = false
	sync_server_position(tile.x, tile.y)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("_update_camera_transform"):
		cam._update_camera_transform(true)

## Nhận Lời Chúc Phúc từ Binh Sĩ Bóng Ma (Shadow Phantom Soldier)
func apply_shadow_phantom_buff(atk: int, def: int, duration: float = 1800.0) -> void:
	shadow_buff_atk = atk
	shadow_buff_def = def
	shadow_buff_timer = duration
	if MuAudioManager:
		MuAudioManager.play_sound_file("sMagic.wav")
	var elf_fx_res = load("res://src/effects/ElfFx.gd")
	if elf_fx_res:
		var fx1 = elf_fx_res.new()
		fx1.skill_num = 27 # DEFENSE
		fx1.caster = self
		fx1.target = self
		get_parent().add_child(fx1)

		var fx2 = elf_fx_res.new()
		fx2.skill_num = 28 # ATTACK
		fx2.caster = self
		fx2.target = self
		get_parent().add_child(fx2)
