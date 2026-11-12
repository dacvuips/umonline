extends CharacterBody3D
class_name MuMonster

# nạp trực tiếp (không phụ thuộc bộ nhớ đệm class_name của editor)
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuWorldRes = preload("res://src/world/MuWorld.gd")
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuDropGeneratorRes = preload("res://src/mu/MuDropGenerator.gd")
const MonsterAttackFxRes = preload("res://src/effects/MonsterAttackFx.gd")
const MuSkillFxRes = preload("res://src/effects/MuSkillFx.gd")

## Đòn đánh riêng biệt của quái vật (client gốc ZzzCharacter.cpp: AttackEffect)
const ORIGINAL_ATTACK := {
	35: MonsterAttackFxRes.GORGON_FIRE_RING,    # Death Gorgon
	37: MonsterAttackFxRes.DEVIL_LASER,         # Devil
	54: MonsterAttackFxRes.ARROW_BOMB_1,        # Golden Soldier
	57: MonsterAttackFxRes.ARROW_BOMB_3,        # Iron Wheel
	151: MonsterAttackFxRes.ARROW_BOMB_1,       # Soldier
	494: MonsterAttackFxRes.DEVIL_LASER,        # Golden Devil
	511: MonsterAttackFxRes.DEVIL_LASER,        # Devil Lord
}

## Đại diện cho Quái vật trong MU Online (Bull Fighter, Hound, Skeleton, Yeti...)
## Tương thích Animation GLB và thanh máu trên đầu theo phong cách Season 6

signal monster_clicked(monster: MuMonster)
signal hp_changed(current_hp: int, max_hp: int)

## Số hiệu quái trong Monsters.json của MU (0 Bull Fighter, 20 Elite Yeti ...). -1 = tìm theo monster_name
@export var monster_id: int = -1
@export var monster_name: String = "Bull Fighter"
@export var max_hp: int = 120
@export var current_hp: int = 120
@export var grid_x: int = 130
@export var grid_y: int = 128
@export var move_speed: float = 2.5

## Chết (bộ sinh quái hẹn giờ hồi sinh)
signal died(monster: MuMonster)

## Chỉ số theo server OpenMU (assets/mu/monster_stats.json, tools/mu_gamedata.py)
var is_boss: bool = false
var is_golden: bool = false
var level: int = 1
var dmg_min: int = 5
var dmg_max: int = 10
var defense: int = 0
var attack_delay: float = 1.6     # giây giữa 2 đòn
var view_range: int = 5           # ô: thấy người chơi thì đuổi
var attack_range: int = 1         # ô: đứng cách bấy nhiêu ô thì đánh
var attack_skill: String = ""       # tên skill từ monster_stats.json (Meteorite, Lightning, PowerWave...)
var attack_skill_id: int = -1       # ID kỹ năng tương ứng trong skills.json
var move_range: int = 3           # ô: đi lang thang quanh chỗ sinh
var respawn_delay: float = 10.0   # giây
## AI: false = đứng yên như quái đặt tay cũ
var ai_enabled: bool = true
var home := Vector2i(-1, -1)
var _attack_timer := 0.0
var _think_timer := randf_range(0.5, 2.0)
var _chasing := false

var waypoints: Array[Vector2i] = []
var is_dead: bool = false
var model = null
var _action_lock := 0.0
var _idle_sound_timer := randf_range(3.0, 10.0)
var _target_ring: Node3D = null

@onready var anim_player: AnimationPlayer = _find_animation_player()
@onready var hp_label: Label3D = $HealthLabel if has_node("HealthLabel") else null

func _ready() -> void:
	global_position = MuWorld.grid_to_world(grid_x, grid_y)
	if home.x < 0:
		home = Vector2i(grid_x, grid_y)
	_apply_stats()
	_setup_collision()
	_setup_overhead_ui()
	_setup_mu_model()
	play_action("action00") # Idle

## Chỉ số của server (MonsterDefinition): máu, sát thương, phòng thủ, tầm nhìn / đánh, tốc độ, hồi sinh
func _apply_stats() -> void:
	var id := monster_id
	if id < 0:
		var mon := MuCatalogRes.find_monster(-1, monster_name.split("#")[0].strip_edges())
		id = int(mon.get("number", -1))
	var st: Dictionary = MuCatalogRes.monster_stats(id) if id >= 0 else {}
	if st.is_empty():
		return
	if monster_id < 0:
		monster_id = id
	level = int(st.get("level", level))
	max_hp = maxi(1, int(st.get("hp", max_hp)))
	current_hp = max_hp
	dmg_min = int(st.get("dmg_min", dmg_min))
	dmg_max = maxi(dmg_min, int(st.get("dmg_max", dmg_max)))
	defense = int(st.get("def", defense))
	attack_delay = maxf(0.4, float(st.get("attack_delay", 1600)) / 1000.0)
	view_range = int(st.get("view_range", view_range))
	attack_range = maxi(1, int(st.get("attack_range", attack_range)))
	attack_skill = str(st.get("attack_skill", ""))
	if attack_skill != "":
		attack_skill_id = MuCatalogRes.find_skill_by_name(attack_skill)
	move_range = int(st.get("move_range", move_range))
	respawn_delay = maxf(1.0, float(st.get("respawn", respawn_delay)))
	# MoveDelay = ms mỗi ô
	move_speed = clampf(1000.0 / maxf(100.0, float(st.get("move_delay", 400))), 1.0, 6.0)

## Kinh nghiệm khi giết (công thức của MU: (cấp + 25) * cấp / 3, giảm khi người chơi cao cấp hơn nhiều)
func exp_reward(player_level: int) -> int:
	var e := float(level + 25) * float(level) / 3.0
	if player_level > level + 10:
		e *= float(level + 10) / float(maxi(1, player_level))
	return maxi(1, int(e))

## Model MU thật (assets/mu/Monster/...) theo số hiệu / tên ; giữ model cũ nếu chưa chuyển đổi
func _setup_mu_model() -> void:
	var nm := monster_name
	var hash_pos := nm.find("#")
	if hash_pos > 0:
		nm = nm.substr(0, hash_pos).strip_edges()
	var m := MuCharModelRes.new()
	m.name = "MuModel"
	add_child(m)
	if m.build_monster(monster_id, nm):
		model = m
		for c in get_children():
			if c != m and c is Node3D and not (c is CollisionShape3D) and not (c is Label3D):
				MuModelRes.cleanup_geometry(c)
				c.queue_free()
		anim_player = null
		if hp_label:
			hp_label.position.y = 2.2 * m.scale.y
		model.play_idle()
	else:
		MuModelRes.cleanup_geometry(m)
		m.queue_free()

func _find_animation_player() -> AnimationPlayer:
	# Tìm AnimationPlayer trong node con
	for child in get_children():
		if child is AnimationPlayer:
			return child
		for sub_child in child.get_children():
			if sub_child is AnimationPlayer:
				return sub_child
	return null

func _setup_collision() -> void:
	# Đảm bảo có CollisionShape3D để bắt click chuột / tap cảm ứng
	if not has_node("CollisionShape3D"):
		var col = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = 0.6
		shape.height = 2.0
		col.shape = shape
		col.position = Vector3(0, 1.0, 0)
		add_child(col)

func _setup_overhead_ui() -> void:
	# Bỏ hiển thị tên quái vật lơ lửng trên đầu
	if hp_label:
		hp_label.visible = false

func _update_hp_display() -> void:
	if hp_label:
		hp_label.visible = false

## Tên hiển thị sạch sẽ (loại bỏ hậu tố #1, #2 từ scene editor)
func get_display_name() -> String:
	return monster_name.split("#")[0].strip_edges()

## Bật / tắt vòng tròn chọn mục tiêu 3D dưới chân quái khi được player target
func set_targeted(targeted: bool) -> void:
	if targeted and not is_dead:
		if not _target_ring:
			_target_ring = _create_target_ring()
		if _target_ring:
			_target_ring.visible = true
	else:
		if _target_ring:
			_target_ring.visible = false

func _create_target_ring() -> Node3D:
	var ring = MeshInstance3D.new()
	ring.name = "TargetRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 0.8
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.25, 0.15, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	
	ring.position = Vector3(0, 0.05, 0)
	add_child(ring)
	return ring

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _target_ring and _target_ring.visible:
		_target_ring.rotate_y(2.0 * delta)
	if _action_lock > 0.0:
		_action_lock -= delta
		if _action_lock <= 0.0:
			play_action("action01" if waypoints.size() > 0 else "action00")

	# Tiếng kêu tự nhiên của quái vật khi nhàn rỗi / di chuyển
	_idle_sound_timer -= delta
	if _idle_sound_timer <= 0.0:
		_idle_sound_timer = randf_range(7.0, 16.0)
		if MuAudioManager:
			MuAudioManager.play_monster_sound(monster_id, monster_name, "idle", global_position)

	if ai_enabled:
		_think(delta)

	if waypoints.size() > 0:
		var next_tile = waypoints[0]
		var target_pos = MuWorld.grid_to_world(next_tile.x, next_tile.y)
		var dir = (target_pos - global_position)
		dir.y = 0.0
		var dist = dir.length()

		if dist < 0.1:
			global_position = target_pos
			grid_x = next_tile.x
			grid_y = next_tile.y
			waypoints.remove_at(0)
			if waypoints.size() == 0:
				play_action("action00")
		else:
			play_action("action01")
			var move_step = dir.normalized() * move_speed * delta
			if move_step.length() > dist:
				global_position = target_pos
			else:
				global_position += move_step
			global_position.y = MuWorld.ground_height(global_position)

			var look_angle = atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, look_angle, 10.0 * delta)

## AI của quái (gần giống MonsterAI của MU / OpenMU BasicMonsterIntelligence):
##  - người chơi trong tầm nhìn (view_range ô) và không đứng trong thành -> đuổi theo, tới tầm đánh thì đánh
##  - không thì thỉnh thoảng đi lang thang trong move_range ô quanh chỗ sinh
func _think(delta: float) -> void:
	_attack_timer -= delta
	_think_timer -= delta
	var player := _target_player()
	var me := Vector2i(grid_x, grid_y)
	if player != null:
		var pt := Vector2i(player.grid_x, player.grid_y)
		var d := maxi(absi(pt.x - me.x), absi(pt.y - me.y))
		var leash := maxi(absi(pt.x - home.x), absi(pt.y - home.y))
		if d <= attack_range:
			# đứng lại, quay mặt, đánh theo AttackDelay
			waypoints.clear()
			var dir := player.global_position - global_position
			dir.y = 0.0
			if dir.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(10.0 * delta, 0.0, 1.0))
			if _attack_timer <= 0.0:
				_attack_timer = attack_delay
				_attack(player)
			_chasing = true
			return
		if d <= view_range or (_chasing and leash <= view_range + move_range + 4):
			_chasing = true
			if _think_timer <= 0.0:
				_think_timer = 0.4
				_path_to(pt, attack_range)
			return
	_chasing = false
	if _think_timer <= 0.0 and waypoints.is_empty():
		_think_timer = randf_range(3.0, 7.0)
		if move_range > 0 and randf() < 0.6:
			var t := home + Vector2i(randi_range(-move_range, move_range), randi_range(-move_range, move_range))
			var w = MuWorld.current
			if w != null and w.is_walkable(t.x, t.y) and not MuWorld.is_safe_tile(t.x, t.y):
				_path_to(t, 0)

## Người chơi còn sống, không trong thành, cùng bản đồ
func _target_player() -> MuPlayer:
	var tree := get_tree()
	if not tree:
		return null
	var p = tree.get_first_node_in_group("Player")
	if p == null or not (p is MuPlayer):
		return null
	if p.current_hp <= 0 or p.is_in_safe_zone():
		return null
	return p

## Tìm đường tới ô `target`, dừng cách đích `stop` ô; không bước vào ô an toàn
func _path_to(target: Vector2i, stop: int) -> void:
	var w = MuWorld.current
	if w == null:
		return
	var path: Array[Vector2i] = w.find_path_grid(Vector2i(grid_x, grid_y), target)
	if path.size() > 0 and path[0] == Vector2i(grid_x, grid_y):
		path.remove_at(0)
	while stop > 0 and path.size() > 0 and maxi(absi(path[-1].x - target.x), absi(path[-1].y - target.y)) < stop:
		path.remove_at(path.size() - 1)
	var keep: Array[Vector2i] = []
	for p in path:
		if MuWorld.is_safe_tile(p.x, p.y):
			break
		keep.append(p)
		if keep.size() >= 12:
			break
	waypoints = keep

## Đòn đánh của quái: sát thương [dmg_min, dmg_max] trừ phòng thủ của người chơi
func _attack(player: MuPlayer) -> void:
	play_action("action02" if randf() < 0.5 else "action03")
	if model and model.has_node("MonsterFx"):
		var mfx = model.get_node("MonsterFx")
		if mfx.has_method("on_attack"):
			mfx.on_attack()

	var impact_time := 0.35
	if ORIGINAL_ATTACK.has(monster_id):
		var d := MonsterAttackFxRes.play(self, ORIGINAL_ATTACK[monster_id], player)
		if d > 0.0:
			impact_time = d
	elif attack_skill_id > 0:
		var d := MuSkillFxRes.play(self, attack_skill_id, player)
		if d > 0.0:
			impact_time = d

	var dmg := randi_range(dmg_min, dmg_max)
	get_tree().create_timer(impact_time).timeout.connect(func():
		if is_instance_valid(self) and not is_dead and is_instance_valid(player):
			player.take_damage(dmg, self))

func play_action(action_name: String) -> void:
	if model:
		if _action_lock > 0.0 and action_name in ["action00", "action01"]:
			return
		match action_name:
			"action00": model.play_idle()
			"action01": model.play_move()
			"action02", "action03":
				model.play_attack()
				_action_lock = 0.8
				if MuAudioManager:
					MuAudioManager.play_monster_sound(monster_id, monster_name, "attack", global_position)
			"action04":
				model.play_shock()
				_action_lock = 0.5
			"action05":
				model.play_die()
				_action_lock = 99.0
		return
	if not anim_player:
		anim_player = _find_animation_player()
	if anim_player and anim_player.has_animation(action_name):
		if anim_player.current_animation != action_name:
			anim_player.play(action_name)
			if action_name in ["action02", "action03"] and MuAudioManager:
				MuAudioManager.play_monster_sound(monster_id, monster_name, "attack", global_position)

## Nhận sát thương và hiển thị Damage Number bay lên
func take_damage(damage: int, damage_type: DamageNumber3D.DamageType = DamageNumber3D.DamageType.NORMAL) -> void:
	if is_dead:
		return

	# phòng thủ của quái (DefenseBase) trừ thẳng, tối thiểu 10% đòn
	damage = maxi(maxi(1, damage / 10), damage - defense)
	current_hp = max(0, current_hp - damage)
	_chasing = true
	_think_timer = 0.0
	_update_hp_display()
	hp_changed.emit(current_hp, max_hp)

	# Tạo số sát thương 3D bay lên
	var dmg_label = DamageNumber3D.new()
	get_parent().add_child(dmg_label)
	dmg_label.setup(damage, damage_type, global_position)

	play_action("action04") # Be Hit
	if MuAudioManager:
		MuAudioManager.play_monster_sound(monster_id, monster_name, "pain", global_position)

	if current_hp <= 0:
		die()

func die() -> void:
	is_dead = true
	set_targeted(false)
	if hp_label:
		hp_label.visible = false
	play_action("action05") # Die
	if MuAudioManager:
		MuAudioManager.play_monster_sound(monster_id, monster_name, "die", global_position)
	_spawn_drop_loot()
	waypoints.clear()
	died.emit(self)
	# Quái vật biến mất sau 3 giây
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _spawn_drop_loot() -> void:
	var parent = get_parent()
	if not parent:
		return

	var drop_count := 1
	if is_boss:
		drop_count = 3
	elif is_golden:
		drop_count = 2

	for i in drop_count:
		var loot := MuDropGeneratorRes.generate_drop(level)
		if loot.get("type", "none") == "none":
			continue
		
		var drop = MuDropItem.new()
		var offset := Vector3.ZERO
		if i > 0:
			var ang := randf_range(0.0, TAU)
			var dist := randf_range(0.6, 1.4)
			offset = Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		var target_pos := global_position + offset
		var spawn_pos := global_position + Vector3(0.0, 0.8, 0.0)
		drop.setup_drop(target_pos, spawn_pos)
		
		var loot_type: String = loot.get("type", "")
		if loot_type == "zen":
			drop.category = MuDropItem.ItemCategory.ZEN
			drop.item_name = "Zen"
			drop.amount = int(loot.get("amount", 100))
		elif loot_type == "item":
			drop.category = loot.get("category", MuDropItem.ItemCategory.EQUIPMENT)
			drop.item_dict = loot.get("item_dict", {})
			drop.amount = int(loot.get("amount", 1))
		
		drop.position = spawn_pos
		parent.add_child(drop)

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	var tree := get_tree()
	if tree:
		var item_ui = tree.get_first_node_in_group("MuItemUi")
		if item_ui and not item_ui.held.is_empty():
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		emit_signal("monster_clicked", self)
	elif event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		emit_signal("monster_clicked", self)

func _exit_tree() -> void:
	if model and model.has_method("cleanup_materials"):
		model.cleanup_materials()
	MuModelRes.cleanup_geometry(self)
