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
signal active_skill_changed(skill_id: String)
signal skills_updated()

@export var move_speed: float = 4.5
@export var character_name: String = "Hero"
@export var attack_range: float = 2.2 # Cự ly đánh cận chiến
@export var attack_cooldown: float = 0.65 # Tốc độ đánh ~ 1.5 hit / giây
@export var max_hp: int = 150
@export var current_hp: int = 150
@export var max_mp: int = 100
@export var current_mp: int = 100

## Danh sách kỹ năng hiện có của nhân vật (Available Skills)
var available_skills: Array[Dictionary] = []
var active_skill_id: String = "twisting"

var level: int = 1
var current_exp: int = 0
var max_exp: int = 200

# Chỉ số nhân vật MU Online (Character Stats)
var stat_str: int = 28
var stat_agi: int = 20
var stat_vit: int = 25
var stat_ene: int = 10
var stat_points: int = 15

var grid_x: int = 140
var grid_y: int = 119
var is_moving: bool = false
var waypoints: Array[Vector2i] = []
var virtual_joystick: Node = null
var _manual_move_active: bool = false
var infinite_hp_mp: bool = false

# Túi đồ & Tiền
var zen: int = 10000
var inventory_items: Array[String] = []
## Túi đồ 8x8 của MU: mỗi món là Dictionary MuItems (group, number, level, ..., x, y)
var inventory: Array = []
const INV_COLS := 8
const INV_ROWS := 8
signal inventory_changed

# Chiến đấu
var target_monster: MuMonster = null
var attack_timer: float = 0.0

@onready var visual_root: Node3D = $VisualRoot if has_node("VisualRoot") else self

# ---------------------------------------------------------------- model MU
## Lớp: 0 Dark Wizard, 1 Dark Knight, 2 Fairy Elf, 3 Magic Gladiator, 4 Dark Lord, 5 Summoner, 6 Rage Fighter
@export_range(0, 6) var char_class: int = 1
## Đồ đang mặc: slot -> {"group", "number", "level", "excellent"} (xem MuCharModelRes.build_player)
@export var equipment: Dictionary = {
	"helm": {"group": 7, "number": 1, "level": 11},
	"armor": {"group": 8, "number": 1, "level": 11},
	"pants": {"group": 9, "number": 1, "level": 11},
	"gloves": {"group": 10, "number": 1, "level": 11},
	"boots": {"group": 11, "number": 1, "level": 11},
	"right": {"group": 0, "number": 5, "level": 9},
}
var model = null
var _was_moving := false
var _action_lock := 0.0
var _run_ticks := 0.0     # c->Run của MU: số tick đã đi liên tục (>= 40 thì chạy)   # thời gian còn lại của action đánh / skill / bị đánh (không bị idle/walk đè)

func _ready() -> void:
	process_priority = -10   # di chuyển trước camera: không lệch khung hình
	add_to_group("Player")
	if MuTerrain.pending_spawn.x >= 0:
		grid_x = MuTerrain.pending_spawn.x
		grid_y = MuTerrain.pending_spawn.y
		MuTerrain.pending_spawn = Vector2i(-1, -1)
	global_position = MuWorld.grid_to_world(grid_x, grid_y)
	rebuild_model()
	_init_skills()
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
	emit_signal("exp_changed", current_exp, max_exp, level)

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
		emit_signal("hp_changed", current_hp, max_hp)
		return
	damage = maxi(maxi(1, damage / 10), damage - defense_value())
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
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
	emit_signal("position_changed", grid_x, grid_y)
	_dead = false
	_action_lock = 0.0
	if model:
		model.play_idle(is_in_safe_zone())

## Dựng lại model MU theo char_class + equipment (gọi lại sau khi đổi đồ)
func rebuild_model() -> void:
	if model == null:
		model = MuCharModelRes.new()
		model.name = "MuModel"
		visual_root.add_child(model)
	if model.build_player(char_class, equipment):
		# ẩn hình tạm (CSG) khi đã có model thật
		for c in visual_root.get_children():
			if c != model and c is Node3D:
				c.visible = false
		model.play_idle(is_in_safe_zone())
	else:
		push_warning("[MuPlayer] Chưa có model Player (assets/mu/Player/player.glb) — chạy tools/CHUYEN_DOI_MODEL_MU.bat")

func set_class(cls: int) -> void:
	char_class = clampi(cls, 0, 6)
	rebuild_model()

## slot: helm/armor/pants/gloves/boots/right/left/wings ; number < 0 -> tháo
func equip(slot: String, group: int, number: int, item_level: int = 0, excellent: bool = false) -> void:
	if number < 0:
		equipment.erase(slot)
	else:
		equipment[slot] = {"group": group, "number": number, "level": item_level, "excellent": excellent}
	rebuild_model()

func is_in_safe_zone() -> bool:
	return (MuTerrain.attribute_at(grid_x, grid_y) & 1) != 0

func _lock_action(seconds: float) -> void:
	_action_lock = seconds

## CharacterMoveSpeed (ZzzCharacter.cpp): đơn vị MU / tick (25 tick/s, 100 đơn vị = 1 ô)
##   đi bộ 12, chạy 15 (sau 40 tick đi liên tục ngoài thành), có cánh 15 (Dragon/Storm 16)
func current_move_speed() -> float:
	var sp := 12.0
	var safe := is_in_safe_zone()
	if equipment.has("wings") and not safe:
		var wn := int(equipment["wings"].get("number", 0))
		sp = 16.0 if wn == 5 or wn == 36 else 15.0
	elif equipment.has("helper") and not safe:
		var hn := int(equipment["helper"].get("number", 0))
		if hn in [2, 3, 4, 37]:
			sp = 15.0
	elif is_running():
		sp = 15.0
	return sp * 25.0 / 100.0

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
	if is_moving:
		model.play_move(is_running(), safe)
	else:
		model.play_idle(safe)
	_was_moving = is_moving

## Thêm kinh nghiệm và kiểm tra Thăng Cấp (Level Up)
func add_exp(amount: int) -> void:
	current_exp += amount
	print("[MuPlayer] Nhận +%d EXP! (Hiện tại: %d/%d)" % [amount, current_exp, max_exp])
	while current_exp >= max_exp:
		current_exp -= max_exp
		level += 1
		max_exp = int(max_exp * 1.45)
		# Tăng chỉ số khi lên cấp
		stat_points += 5
		max_hp += 20
		max_mp += 15
		current_hp = max_hp
		current_mp = max_mp
		
		# Phát hiệu ứng ánh sáng Level Up rực rỡ
		var lvl_effect = LevelUpEffect.new()
		lvl_effect.global_position = global_position
		get_parent().add_child(lvl_effect)
		print("[MuPlayer] *** CHÚC MỪNG BẠN ĐÃ LÊN CẤP %d! ***" % level)

	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)
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
			attack_cooldown = max(0.15, attack_cooldown - 0.005 * actual_add)
		"vit":
			stat_vit += actual_add
			max_hp += 3 * actual_add
			current_hp = min(max_hp, current_hp + 3 * actual_add)
			emit_signal("hp_changed", current_hp, max_hp)
		"ene":
			stat_ene += actual_add
			max_mp += 2 * actual_add
			current_mp = min(max_mp, current_mp + 2 * actual_add)
			emit_signal("mana_changed", current_mp, max_mp)
	return true

func gm_add_points(amount: int) -> void:
	stat_points += amount

func reset_stat_points() -> void:
	var base_str := 28
	var base_agi := 20
	var base_vit := 25
	var base_ene := 10
	var refunded := maxi(0, stat_str - base_str) + maxi(0, stat_agi - base_agi) + maxi(0, stat_vit - base_vit) + maxi(0, stat_ene - base_ene)
	stat_points += refunded
	stat_str = base_str
	stat_agi = base_agi
	stat_vit = base_vit
	stat_ene = base_ene
	max_hp = 110 + level * 20
	max_mp = 40 + level * 15
	current_hp = max_hp
	current_mp = max_mp
	attack_cooldown = 0.5
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("mana_changed", current_mp, max_mp)

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
					if roll < 0.2:
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

func _init_skills() -> void:
	available_skills = [
		{
			"id": "twisting",
			"name": "Xoay Kiếm",
			"icon_path": "res://assets/textures/ui/btn_skill_twisting.png",
			"mana_cost": 12,
			"cooldown": 0.6,
			"desc": "Tuyệt chiêu Xoay Kiếm (Twisting Slash) sát thương diện rộng"
		},
		{
			"id": "fireball",
			"name": "Cầu Lửa",
			"icon_path": "res://assets/textures/ui/btn_skill_fireball.png",
			"mana_cost": 8,
			"cooldown": 0.5,
			"desc": "Bắn cầu lửa ma pháp tầm xa vào mục tiêu"
		},
		{
			"id": "teleport",
			"name": "Dịch Chuyển",
			"icon_path": "res://assets/textures/ui/mobile_skills/skill_teleport.png",
			"mana_cost": 15,
			"cooldown": 1.5,
			"desc": "Dịch chuyển tức thời né đòn và tiếp cận quái"
		},
		{
			"id": "buff",
			"name": "Gồng Máu",
			"icon_path": "res://assets/textures/ui/mobile_skills/skill_buff.png",
			"mana_cost": 20,
			"cooldown": 4.0,
			"desc": "Gồng năng lượng chiến binh, hồi phục 50 HP"
		},
		{
			"id": "attack",
			"name": "Tấn Công",
			"icon_path": "res://assets/textures/ui/mobile_skills/skill_attack.png",
			"mana_cost": 0,
			"cooldown": 0.4,
			"desc": "Đòn đánh cận chiến cơ bản, không tốn Mana"
		}
	]
	for num in learned_skills:
		available_skills.append(_learned_skill_entry(int(num)))
	emit_signal("skills_updated")

func get_available_skills() -> Array[Dictionary]:
	return available_skills

func set_active_skill(skill_id: String) -> void:
	active_skill_id = skill_id
	emit_signal("active_skill_changed", skill_id)

func get_active_skill() -> Dictionary:
	for sk in available_skills:
		if sk.get("id") == active_skill_id:
			return sk
	if available_skills.size() > 0:
		return available_skills[0]
	return {}

func cast_active_skill() -> void:
	match active_skill_id:
		"twisting":
			cast_twisting_slash()
		"fireball":
			cast_fireball()
		"teleport":
			cast_teleport()
		"buff":
			cast_greater_fortitude()
		"attack":
			attack_nearest()
		_:
			if active_skill_id.begins_with("sk_"):
				cast_learned_skill(active_skill_id.substr(3).to_int())
			else:
				attack_nearest()

# ============================================================ skill học từ orb / scroll (skills.json)
## Số skill (SkillNumber của OpenMU) đã học
var learned_skills: Array[int] = []

func _say(text: String) -> void:
	var chat = get_tree().get_first_node_in_group("ChatWindow")
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
	MuCatalogRes.ensure_loaded()
	var all_sk := MuCatalogRes.get_all_skills()
	var added := 0
	var keys = all_sk.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var num := int(k)
		var sk: Dictionary = all_sk[k]
		if str(sk.get("type", "")) == "PassiveBoost":
			continue
		var classes: Array = sk.get("classes", [])
		if not include_all_classes:
			if not classes.has(char_class):
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

## GM: Đặt lại danh sách kỹ năng về mặc định
func clear_learned_skills() -> void:
	learned_skills.clear()
	_init_skills()
	active_skill_id = "twisting"
	emit_signal("active_skill_changed", active_skill_id)
	emit_signal("skills_updated")

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
	var icons := {
		"buff": "res://assets/textures/ui/mobile_skills/skill_buff.png",
		"teleport": "res://assets/textures/ui/mobile_skills/skill_teleport.png",
		"area": "res://assets/textures/ui/btn_skill_twisting.png",
		"magic": "res://assets/textures/ui/btn_skill_fireball.png",
		"melee": "res://assets/textures/ui/mobile_skills/skill_attack.png",
	}
	var icon_file := ""
	if num >= 1 and num <= 48:
		var r := (num - 1) / 8
		var c := (num - 1) % 8
		var p := "res://assets/textures/ui/skills_extracted/skill_%d_%d.png" % [r, c]
		if ResourceLoader.exists(p):
			icon_file = p
	if icon_file == "":
		icon_file = icons.get(kind, icons["melee"])

	return {
		"id": "sk_%d" % num,
		"skill": num,
		"name": str(sk.get("name", "Skill %d" % num)),
		"icon_path": icon_file,
		"mana_cost": int(sk.get("mana", 0)),
		"cooldown": 0.6 if kind != "buff" else 2.0,
		"desc": "%s (%s)" % [str(sk.get("name", "")), kind],
	}

## Dùng skill đã học: sát thương / mana / tầm theo skills.json, hiệu ứng chung theo loại
func cast_learned_skill(num: int) -> void:
	if is_in_safe_zone():
		return
	var sk := MuCatalogRes.skill(num)
	if sk.is_empty() or _dead:
		return
	var kind := skill_kind(sk)
	if kind == "teleport":
		cast_teleport()
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
		_hit_later(maxf(delay, 0.0), victims, sk)
		return
	match kind:
		"buff":
			_cast_buff_skill(sk)
		"area":
			_cast_area_skill(sk, target)
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
			_hit_monster(target, _skill_damage(sk))

## Sát thương skill: vật lý = đòn thường + damage của skill ; phép = Năng lượng / 4 + damage * 2 ; ±20%
func _skill_damage(sk: Dictionary) -> int:
	var base := float(sk.get("damage", 0))
	var dmg: float
	if str(sk.get("damage_type", "")) in ["Wizardry", "Curse"]:
		dmg = stat_ene / 4.0 + base * 2.0 + 20.0
	else:
		dmg = randf_range(30.0, 55.0) + stat_str / 6.0 + base
	return maxi(1, int(dmg * randf_range(0.8, 1.2)))

func _hit_monster(m: MuMonster, dmg: int) -> void:
	if m == null or m.is_dead:
		return
	var t := DamageNumber3D.DamageType.NORMAL
	var roll := randf()
	if roll < 0.15:
		dmg = int(dmg * 1.5)
		t = DamageNumber3D.DamageType.EXCELLENT
	elif roll < 0.35:
		dmg = int(dmg * 1.25)
		t = DamageNumber3D.DamageType.CRITICAL
	if MuAudioManager:
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
func _hit_later(delay: float, victims: Array, sk: Dictionary) -> void:
	if victims.is_empty():
		return
	if delay <= 0.01:
		for m in victims:
			_hit_monster(m, _skill_damage(sk))
		return
	get_tree().create_timer(delay).timeout.connect(func():
		for m in victims:
			if is_instance_valid(m) and not m.is_dead:
				_hit_monster(m, _skill_damage(sk)))

## Skill vùng: quanh mục tiêu (phép) hoặc quanh mình (vật lý), bán kính theo tầm của skill
func _cast_area_skill(sk: Dictionary, target: MuMonster) -> void:
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
			_hit_monster(child, _skill_damage(sk))

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

func _perform_attack_swing() -> void:
	if is_in_safe_zone():
		return
	attack_timer = attack_cooldown
	if MuAudioManager:
		MuAudioManager.play_weapon_swing(global_position)
	if model and model.anim:
		model.play_attack(stat_agi)
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

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed:
		if event.keycode == KEY_1:
			cast_twisting_slash()
		elif event.keycode == KEY_2:
			cast_fireball()
		elif event.keycode == KEY_E or event.keycode == KEY_Q:
			use_hp_potion()
		elif event.keycode == KEY_R:
			use_mp_potion()

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
