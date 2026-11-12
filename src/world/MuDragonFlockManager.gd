extends Node3D
class_name MuDragonFlockManager

## Trình Quản Lý Binh Đoàn Rồng Bầu Trời & Mưa Cầu Lửa (Sky Dragon Flock & Meteor Manager)
## Tương thích 100% logic GOBoid.cpp (MODEL_DRAGON_ / MODEL_FIRE SubType 3 / EnableEvent != 0):
## - Tự động theo dõi lịch trình sự kiện Red Dragon Invasion & Golden Dragon Invasion
## - Bầy rồng bay sải cánh trên không trung theo hướng bay kinh điển từ chéo góc phải trên qua góc trái dưới màn hình
## - Mưa cầu lửa (Meteor Fireball) dội từ góc phải trên bầu trời rơi xuống đất quanh nhân vật kèm âm thanh eMeteorite.wav & eExplosion.wav
## - Triệu hồi bầy rồng chiến đấu trên mặt đất tại Lorencia
## - Hỗ trợ GM test kích hoạt khẩn cấp tức thì

const MuSkyDragonRes = preload("res://src/world/MuSkyDragon.gd")

@export var player: MuPlayer = null
@export var spawn_interval_min: float = 5.0
@export var spawn_interval_max: float = 9.0
@export var enable_sky_meteors: bool = false # Đã tắt hiệu ứng cầu lửa theo yêu cầu

var _is_invasion_active: bool = false
var _active_event_id: String = ""
var _spawn_timer: float = 0.0
var _meteor_timer: float = 0.0
var _check_event_timer: float = 0.0
var _ground_dragons: Array = []

static var instance: MuDragonFlockManager = null

## Lớp Cầu Lửa Rơi Tự Do Từ Bầu Trời (Chuẩn GOBoid.cpp MODEL_FIRE SubType 3)
class MuSkyMeteor extends Node3D:
	const METEOR_MODEL_PATH := "res://assets/mu/Skill/Fire01.glb"
	const SOUND_METEOR_PATH := "res://assets/mu/Sound/eMeteorite.wav"
	const SOUND_EXPLODE_PATH := "res://assets/mu/Sound/eExplosion.wav"

	var velocity: Vector3 = Vector3.ZERO
	var life_time: float = 5.0
	var _exploded: bool = false

	func setup(p_start: Vector3, p_velocity: Vector3) -> void:
		position = p_start
		velocity = p_velocity
		_setup_visual()
		_play_sound(SOUND_METEOR_PATH, 16.0)

	func _setup_visual() -> void:
		# Mô hình cầu lửa Fire01.glb (MODEL_FIRE)
		if ResourceLoader.exists(METEOR_MODEL_PATH):
			var ps: PackedScene = load(METEOR_MODEL_PATH)
			if ps:
				var m := ps.instantiate() as Node3D
				m.scale = Vector3(0.55, 0.55, 0.55)
				add_child(m)

		# Ánh sáng lửa rực rỡ chiếu rọi bầu trời
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.2)
		light.light_energy = 2.5
		light.omni_range = 8.0
		add_child(light)

		# Đuôi tàn lửa bốc cháy cuồn cuộn
		var trail := CPUParticles3D.new()
		trail.amount = 24
		trail.lifetime = 0.5
		trail.explosiveness = 0.0
		trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		trail.emission_sphere_radius = 0.35
		trail.direction = -velocity.normalized()
		trail.spread = 18.0
		trail.initial_velocity_min = 2.0
		trail.initial_velocity_max = 4.0
		trail.color = Color(1.0, 0.65, 0.15, 0.95)
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.85, 0.25, 0.95))
		grad.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
		trail.color_ramp = grad
		add_child(trail)

	func _process(delta: float) -> void:
		if _exploded:
			return

		position += velocity * delta
		life_time -= delta

		var ground_y := MuTerrain.height_at(position.x, -position.z)
		if position.y <= ground_y or life_time <= 0.0:
			_explode(ground_y)

	func _explode(ground_y: float) -> void:
		_exploded = true
		position.y = ground_y + 0.1
		_play_sound(SOUND_EXPLODE_PATH, 20.0)

		# Hiệu ứng nổ va chạm mặt đất (BITMAP_EXPLOTION)
		var exp_p := CPUParticles3D.new()
		exp_p.top_level = true
		exp_p.global_position = position
		exp_p.amount = 26
		exp_p.lifetime = 0.65
		exp_p.one_shot = true
		exp_p.explosiveness = 0.95
		exp_p.direction = Vector3(0, 1, 0)
		exp_p.spread = 75.0
		exp_p.initial_velocity_min = 3.5
		exp_p.initial_velocity_max = 7.0
		exp_p.gravity = Vector3(0, -9.8, 0)
		exp_p.color = Color(1.0, 0.6, 0.15, 0.95)
		var eg := Gradient.new()
		eg.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
		eg.set_color(1, Color(0.6, 0.05, 0.0, 0.0))
		exp_p.color_ramp = eg
		get_parent().add_child(exp_p)
		exp_p.emitting = true

		var tree := get_tree()
		if tree:
			tree.create_timer(1.0).timeout.connect(func():
				if is_instance_valid(exp_p): exp_p.queue_free()
				if is_instance_valid(self): queue_free()
			)
		else:
			queue_free()

	func _play_sound(sound_path: String, max_dist: float) -> void:
		if ResourceLoader.exists(sound_path):
			var a := AudioStreamPlayer3D.new()
			a.stream = load(sound_path)
			a.unit_size = 12.0
			a.max_distance = max_dist
			a.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			a.bus = "Master"
			add_child(a)
			a.play()
			a.finished.connect(a.queue_free)

func _ready() -> void:
	name = "MuDragonFlockManager"
	instance = self
	add_to_group("DragonFlockManager")
	_spawn_timer = randf_range(1.5, 3.5)
	_meteor_timer = randf_range(0.8, 1.6)

	# Kết nối với MuEventManager nếu đã sẵn sàng
	var mgr := get_tree().get_first_node_in_group("MuEventManager") if get_tree() else null
	if mgr and mgr.has_signal("event_state_changed"):
		if not mgr.event_state_changed.is_connected(_on_event_state_changed):
			mgr.event_state_changed.connect(_on_event_state_changed)

func _process(delta: float) -> void:
	# 1. Định kỳ 1.0 giây kiểm tra trạng thái sự kiện từ MuEventManager
	_check_event_timer += delta
	if _check_event_timer >= 1.0:
		_check_event_timer = 0.0
		_sync_with_event_manager()

	# 2. Nếu sự kiện đang diễn ra, đếm ngược để spawn đợt rồng và mưa cầu lửa
	if _is_invasion_active:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)
			_spawn_dragon_wave()

		# Mưa cầu lửa dội từ bầu trời chuẩn GOBoid.cpp line 1366-1380
		if enable_sky_meteors:
			_meteor_timer -= delta
			if _meteor_timer <= 0.0:
				_meteor_timer = randf_range(1.0, 2.2)
				_spawn_sky_meteor()

func _sync_with_event_manager() -> void:
	var mgr := get_tree().get_first_node_in_group("MuEventManager") if get_tree() else null
	if not mgr:
		return

	var is_red_active: bool = false
	var is_gold_active: bool = false

	if mgr.has_method("is_event_active"):
		is_red_active = mgr.is_event_active("red_dragon")
		is_gold_active = mgr.is_event_active("golden_invasion")
	else:
		# Fallback kiểm tra qua status list
		var list: Array = mgr.get_all_events_status() if mgr.has_method("get_all_events_status") else []
		for ev in list:
			if ev.get("id") == "red_dragon" and ev.get("state") in ["open", "running"]:
				is_red_active = true
			elif ev.get("id") == "golden_invasion" and ev.get("state") in ["open", "running"]:
				is_gold_active = true

	if is_red_active or is_gold_active:
		if not _is_invasion_active:
			_is_invasion_active = true
			_active_event_id = "golden_invasion" if is_gold_active else "red_dragon"
			_spawn_timer = 1.0 # Bắt đầu ngay sau 1s
			_meteor_timer = 0.5
			_spawn_ground_dragons(_active_event_id)
			print("[MuDragonFlockManager] Binh đoàn Rồng bầu trời & Rồng chiến đấu mặt đất đã xuất kích!")
	else:
		if _is_invasion_active:
			_is_invasion_active = false
			_active_event_id = ""
			_despawn_ground_dragons()
			print("[MuDragonFlockManager] Sự kiện Rồng kết thúc, thu hồi rồng bầu trời & rồng mặt đất.")

func _on_event_state_changed(event_id: String, new_state: String, _data: Dictionary) -> void:
	if event_id in ["red_dragon", "golden_invasion"]:
		if new_state in ["open", "running"]:
			_is_invasion_active = true
			_active_event_id = event_id
			_spawn_timer = 1.0
			_meteor_timer = 0.5
			_spawn_ground_dragons(event_id)
		elif new_state == "ended":
			_is_invasion_active = false
			_active_event_id = ""
			_despawn_ground_dragons()
			_sync_with_event_manager()

## Sinh một đợt rồng bay qua đầu người chơi (Flyover Wave)
## Hướng bay chuẩn Webzen MU Online (GOBoid.cpp line 1450-1460):
## Camera nhìn chéo góc (-X, -Z). Rồng bay từ góc phải trên qua góc trái dưới màn hình:
## Xuất phát ở (+X, -Z) và bay xuyên qua (-X, +Z) trên đỉnh đầu người chơi.
func _spawn_dragon_wave() -> void:
	var target_p := _get_player_pos()

	# Tọa độ xuất phát: Góc trên bên phải màn hình (+X, -Z)
	var spawn_offset_start := Vector3(randf_range(16.0, 26.0), 0.0, -randf_range(46.0, 58.0))
	# Tọa độ đích: Góc dưới bên trái màn hình (-X, +Z)
	var spawn_offset_end := Vector3(-randf_range(16.0, 26.0), 0.0, randf_range(46.0, 58.0))

	var start_pos := target_p + spawn_offset_start
	start_pos.y += randf_range(4.5, 5.5)
	var end_pos := target_p + spawn_offset_end
	end_pos.y += randf_range(4.5, 5.5)

	# Xác định loại rồng:
	# Sự kiện Red Dragon: Chủ đạo là Rồng Đỏ, thỉnh thoảng có Rồng Vàng chỉ huy
	# Sự kiện Golden Invasion: Chủ đạo là Rồng Vàng, thỉnh thoảng có Rồng Đỏ bay cùng
	var is_golden: bool = false
	if _active_event_id == "golden_invasion":
		is_golden = (randf() > 0.25)
	else:
		is_golden = (randf() > 0.65) # Rồng Đỏ có tỷ lệ Rồng Vàng bay kèm

	# Con thứ nhất (Leader)
	_spawn_single_dragon(start_pos, end_pos, MuSkyDragonRes.DragonType.GOLDEN_DRAGON if is_golden else MuSkyDragonRes.DragonType.RED_DRAGON)

	# 50% cơ hội sinh thêm con thứ hai bay cùng bầy (Formation flight)
	if randf() > 0.4:
		var wingman_offset := Vector3(randf_range(6.0, 12.0), randf_range(-1.5, 2.0), randf_range(-10.0, -5.0))
		var second_type = MuSkyDragonRes.DragonType.RED_DRAGON if is_golden else MuSkyDragonRes.DragonType.GOLDEN_DRAGON
		var tree := get_tree()
		if tree:
			tree.create_timer(randf_range(0.6, 1.4)).timeout.connect(func():
				if is_instance_valid(self):
					_spawn_single_dragon(start_pos + wingman_offset, end_pos + wingman_offset, second_type)
			)
		else:
			_spawn_single_dragon(start_pos + wingman_offset, end_pos + wingman_offset, second_type)

## Sinh một quả cầu lửa (Meteor Fireball) dội từ bầu trời xuống đất quanh người chơi
func _spawn_sky_meteor() -> void:
	if not enable_sky_meteors:
		return
	var target_p := _get_player_pos()
	# Xuất phát từ góc trên bên phải bầu trời (+X, -Z, +Y cao trên mây)
	var spawn_pos := Vector3(
		target_p.x + randf_range(2.0, 18.0),
		target_p.y + randf_range(16.0, 24.0),
		target_p.z - randf_range(18.0, 36.0)
	)
	# Bay chéo xuống góc dưới bên trái màn hình (-X, -Y rơi xuống, +Z tiến về góc trái)
	var vel := Vector3(
		randf_range(-3.5, -1.2),
		randf_range(-10.0, -14.0),
		randf_range(9.0, 14.0)
	)
	var meteor := MuSkyMeteor.new()
	add_child(meteor)
	meteor.setup(spawn_pos, vel)

func _spawn_single_dragon(p_start: Vector3, p_target: Vector3, p_type: MuSkyDragon.DragonType) -> MuSkyDragon:
	var dragon := MuSkyDragonRes.new()
	add_child(dragon)
	dragon.setup_flight(p_start, p_target, p_type)
	return dragon

func _get_player_pos() -> Vector3:
	if player and is_instance_valid(player):
		return player.global_position
	var p = get_tree().get_first_node_in_group("Player") if get_tree() else null
	if p and is_instance_valid(p):
		return p.global_position
	# Mặc định trung tâm Lorencia
	return Vector3(140.0, 0.0, -119.0)

## Hàm gọi test tức thì từ GM Panel hoặc Debug (kích hoạt ngay bầy rồng)
func trigger_test_flyover() -> void:
	_is_invasion_active = true
	_active_event_id = "red_dragon"
	_spawn_dragon_wave()
	if enable_sky_meteors:
		_spawn_sky_meteor()
		var tree := get_tree()
		if tree:
			tree.create_timer(0.4).timeout.connect(func():
				if is_instance_valid(self): _spawn_sky_meteor()
			)
			tree.create_timer(0.9).timeout.connect(func():
				if is_instance_valid(self): _spawn_sky_meteor()
			)
	_spawn_ground_dragons("red_dragon")
	print("[MuDragonFlockManager] Đã kích hoạt bay thử nghiệm bầy rồng qua đầu!")

func _spawn_ground_dragons(event_id: String) -> void:
	_despawn_ground_dragons()

	var is_gold := (event_id == "golden_invasion")
	# Vị trí các con rồng xuất hiện ngoài thành Lorencia (rải đều 4 cổng thành)
	var spots: Array[Vector2i] = [
		Vector2i(140, 80),   # Phía Bắc (khu vực bãi săn bờ sông)
		Vector2i(175, 115),  # Cổng Đông Lorencia
		Vector2i(95, 125),   # Cổng Tây Lorencia
		Vector2i(135, 175),  # Cổng Nam Lorencia
		Vector2i(155, 75),   # Đồng cỏ Đông Bắc
		Vector2i(120, 65),   # Rìa rừng Tây Bắc
	]

	var mon_script = load("res://src/entities/MuMonster.gd")
	if not mon_script:
		return

	# Lấy World node để kết nối click và add_child
	var w = get_tree().get_first_node_in_group("World") if get_tree() else null
	if not w and get_parent():
		w = get_parent()

	var parent_node = w.get_parent() if (w and w.get_parent()) else (w if w else self)

	for i in spots.size():
		var tile = spots[i]
		var mon_id := 42
		var mon_name := "Red Dragon"
		if is_gold:
			if i % 2 == 0:
				mon_id = 79
				mon_name = "Golden Derkon"
			else:
				mon_id = 43
				mon_name = "Golden Budge Dragon"

		var m = mon_script.new()
		m.monster_id = mon_id
		m.monster_name = mon_name
		m.grid_x = tile.x
		m.grid_y = tile.y
		m.home = tile
		m.name = "EventDragon_%d_%d" % [tile.x, tile.y]
		m.add_to_group("EventDragon")
		m.add_to_group("Monster")

		m.died.connect(func(dead):
			_ground_dragons.erase(dead)
		)

		if w and w.has_method("_on_monster_clicked"):
			m.monster_clicked.connect(w._on_monster_clicked)

		_ground_dragons.append(m)
		parent_node.add_child(m)

	print("[MuDragonFlockManager] Đã triệu hồi %d Rồng Chiến Đấu trên mặt đất tại Lorencia!" % _ground_dragons.size())

func _despawn_ground_dragons() -> void:
	for d in _ground_dragons:
		if is_instance_valid(d):
			d.queue_free()
	_ground_dragons.clear()

func get_active_ground_dragons() -> Array:
	var alive := []
	for d in _ground_dragons:
		if is_instance_valid(d) and not d.is_dead:
			alive.append(d)
	return alive
