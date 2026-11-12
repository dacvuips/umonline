extends Node3D
class_name MuSkyDragon

## Rồng Bay Trên Bầu Trời (Sky Dragon Boid - Chuẩn Game Gốc Webzen MU Online)
## Tương thích 100% logic GOBoid.cpp (MODEL_DRAGON_ / SubType 0: Rồng Đỏ, SubType 1: Rồng Vàng):
## - Mô hình Object56/Dragon.glb & Dragon2.glb với xương Skeleton3D và animation vỗ cánh 'a000'
## - Quỹ đạo bay lượn trên không trung qua đỉnh đầu người chơi (Altitude 14-22m trên mặt đất)
## - Chuyển động lượn sóng nhấp nhô theo hình sin: y += -abs(sin(timer)) * wave_height
## - Hướng đầu: Đầu rồng ở trục +Z (Bone 34-37 Head, Bone 41 attack01), đuôi ở trục -Z (Bone 28 Tail)
## - Rồng Đỏ: Giữ trọn texture vảy & sừng gốc Webzen (drr_01, drr_02, drr_03), thở lửa từ mõm (GOBoid.cpp line 1318)
## - Rồng Vàng: Phủ hiệu ứng mạ vàng ánh kim hoàng kim chói loá (Metallic Chrome Golden FX - GOBoid.cpp line 1714)
## - Đổ bóng râm (Terrain Shadow) in trên mặt đất địa hình lướt theo rồng
## - Tiếng rồng gầm gừ uy phong (mBullAttack1.wav) vang vọng 3D từ bầu trời

enum DragonType { RED_DRAGON, GOLDEN_DRAGON }

@export var dragon_type: DragonType = DragonType.RED_DRAGON
@export var fly_speed: float = 14.0
@export var base_altitude: float = 4.8
@export var wave_height: float = 1.0
@export var wave_speed: float = 1.8

var _start_pos: Vector3 = Vector3.ZERO
var _target_dir: Vector3 = Vector3(0, 0, 1)
var _timer: float = 0.0
var _anim_player: AnimationPlayer = null
var _audio_player: AudioStreamPlayer3D = null
var _shadow_mesh: MeshInstance3D = null
var _has_roared: bool = false
var _flight_distance_traveled: float = 0.0
var _max_flight_distance: float = 240.0 # Khoảng cách tối đa trước khi tự huỷ

const DRAGON_MODEL_PATH := "res://assets/mu/object56/dragon.glb"
const DRAGON2_MODEL_PATH := "res://assets/mu/object56/dragon2.glb"
const SOUND_ROAR_PATH := "res://assets/mu/Sound/mBullAttack1.wav"

func _ready() -> void:
	name = "SkyDragon_%s" % ("Gold" if dragon_type == DragonType.GOLDEN_DRAGON else "Red")
	_setup_model()
	_setup_audio()
	_setup_shadow()
	_setup_particles()
	_timer = randf_range(0.0, TAU)

func setup_flight(p_start_pos: Vector3, p_target_pos: Vector3, p_type: DragonType = DragonType.RED_DRAGON) -> void:
	dragon_type = p_type
	_start_pos = p_start_pos
	position = p_start_pos

	var flat_dir := Vector3(p_target_pos.x - p_start_pos.x, 0.0, p_target_pos.z - p_start_pos.z)
	if flat_dir.length_squared() > 0.01:
		_target_dir = flat_dir.normalized()
	else:
		_target_dir = Vector3(0, 0, 1)

	# Hướng đầu con rồng về phía mục tiêu bay
	# Trong dragon.glb chuẩn MU Online: Đầu rồng ở trục +Z (Bone 34-37 Head, Bone 41 attack01), đuôi ở trục -Z (Bone 28 Tail).
	# Do đó góc quay mặt chuẩn khớp với toàn bộ entity MU trong Godot là atan2(_target_dir.x, _target_dir.z).
	rotation.y = atan2(_target_dir.x, _target_dir.z)

func _setup_model() -> void:
	var path := DRAGON2_MODEL_PATH if (dragon_type == DragonType.GOLDEN_DRAGON and ResourceLoader.exists(DRAGON2_MODEL_PATH)) else DRAGON_MODEL_PATH
	var ps: PackedScene = load(path)
	if not ps:
		ps = load(DRAGON_MODEL_PATH)
	if not ps:
		return

	var model_inst := ps.instantiate() as Node3D
	add_child(model_inst)

	# Tinh chỉnh scale chuẩn theo MU Online
	var sc := randf_range(1.15, 1.35)
	if dragon_type == DragonType.GOLDEN_DRAGON:
		sc *= 1.4
	model_inst.scale = Vector3(sc, sc, sc)

	# Tìm MeshInstance3D để tinh chỉnh vật liệu (Rồng Đỏ hoặc Rồng Vàng Hoàng Kim)
	var mi := _find_mesh(model_inst)
	if mi and mi.mesh:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # Dùng shadow mesh riêng dưới đất
		for s in mi.mesh.get_surface_count():
			var orig_mat = mi.mesh.surface_get_material(s)
			if dragon_type == DragonType.GOLDEN_DRAGON:
				# Vật liệu Rồng Vàng: Ánh kim hoàng kim phản chiếu chrome rực rỡ (GOBoid.cpp line 1714: RENDER_METAL)
				var gold_mat := StandardMaterial3D.new()
				gold_mat.albedo_color = Color(1.0, 0.86, 0.22)
				gold_mat.metallic = 0.95
				gold_mat.roughness = 0.16
				gold_mat.emission_enabled = true
				gold_mat.emission = Color(0.45, 0.36, 0.08)
				gold_mat.emission_energy_multiplier = 1.3
				mi.set_surface_override_material(s, gold_mat)
			else:
				# Vật liệu Rồng Đỏ chuẩn game gốc Webzen MU (GOBoid.cpp line 1442 & 1714):
				# Sử dụng nguyên bản texture của quái vật (drr_01, drr_02, drr_03),
				# KHÔNG đè màu đỏ đơn sắc (albedo flat red) làm mất chi tiết vảy da & cánh!
				var red_mat := StandardMaterial3D.new()
				if orig_mat is StandardMaterial3D and orig_mat.albedo_texture:
					red_mat.albedo_texture = orig_mat.albedo_texture
				red_mat.albedo_color = Color(1.0, 1.0, 1.0)
				red_mat.roughness = 0.8
				red_mat.metallic = 0.05
				mi.set_surface_override_material(s, red_mat)

	# Hiệu ứng thở lửa trong miệng rồng (GOBoid.cpp line 1318-1323: mouth bone flame particle)
	if dragon_type == DragonType.RED_DRAGON:
		var mouth_p := CPUParticles3D.new()
		mouth_p.name = "DragonMouthFlameFX"
		mouth_p.amount = 14
		mouth_p.lifetime = 0.45
		mouth_p.local_coords = true
		mouth_p.position = Vector3(0.0, 1.6, 3.8) # Vị trí mõm rồng (+Z)
		mouth_p.direction = Vector3(0.0, -0.15, 1.0) # Phun ra phía trước đầu (+Z)
		mouth_p.spread = 22.0
		mouth_p.initial_velocity_min = 2.0
		mouth_p.initial_velocity_max = 4.5
		mouth_p.gravity = Vector3(0, 0.5, 0)
		mouth_p.scale_amount_min = 0.4
		mouth_p.scale_amount_max = 0.9
		mouth_p.color = Color(1.0, 0.55, 0.15, 0.95)
		var mg := Gradient.new()
		mg.set_color(0, Color(1.0, 0.8, 0.2, 0.95))
		mg.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
		mouth_p.color_ramp = mg
		model_inst.add_child(mouth_p)

	# Animation vỗ cánh
	_anim_player = _find_anim_player(model_inst)
	if _anim_player:
		if _anim_player.has_animation("a000"):
			var anim = _anim_player.get_animation("a000")
			anim.loop_mode = Animation.LOOP_LINEAR
			_anim_player.speed_scale = randf_range(1.6, 2.2)
			_anim_player.play("a000")

func _setup_audio() -> void:
	if ResourceLoader.exists(SOUND_ROAR_PATH):
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "DragonRoarAudio"
		_audio_player.stream = load(SOUND_ROAR_PATH)
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_audio_player.unit_size = 18.0
		_audio_player.max_distance = 120.0
		_audio_player.max_db = 2.0
		_audio_player.bus = "Master"
		add_child(_audio_player)

func _setup_shadow() -> void:
	# Bóng râm cánh rồng in trên mặt đất địa hình (Ground Shadow)
	_shadow_mesh = MeshInstance3D.new()
	_shadow_mesh.name = "DragonGroundShadow"
	_shadow_mesh.top_level = true # Để không bị xoay/nghiêng theo trục pitch của rồng

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(12.0, 12.0) if dragon_type == DragonType.RED_DRAGON else Vector2(16.0, 16.0)
	_shadow_mesh.mesh = plane_mesh

	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var shadow_tex := load("res://assets/textures/dragon_shadow.png") as Texture2D
	if shadow_tex:
		shadow_mat.albedo_texture = shadow_tex
		shadow_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	else:
		shadow_mat.albedo_color = Color(0.02, 0.01, 0.03, 0.38)
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shadow_mesh.set_surface_override_material(0, shadow_mat)
	add_child(_shadow_mesh)

func _setup_particles() -> void:
	# Hiệu ứng tàn lửa / hào quang bốc ra từ cánh và đuôi rồng
	var particles := CPUParticles3D.new()
	particles.name = "DragonTrailFX"
	particles.amount = 32
	particles.lifetime = 1.2
	particles.speed_scale = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(2.5, 0.8, 2.5)

	# Hạt bay dạt về sau đuôi rồng (-Z trong hệ toạ độ rồng)
	particles.direction = Vector3(0, 0.2, -1.0)
	particles.spread = 25.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.5
	particles.gravity = Vector3(0, -1.5, 0)
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.75

	if dragon_type == DragonType.GOLDEN_DRAGON:
		# Bụi vàng kim hoàng kim óng ánh
		particles.color = Color(1.0, 0.9, 0.2, 0.85)
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.95, 0.4, 0.9))
		grad.set_color(1, Color(1.0, 0.6, 0.0, 0.0))
		particles.color_ramp = grad
	else:
		# Tàn tro và lửa đỏ rực
		particles.color = Color(1.0, 0.3, 0.05, 0.9)
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.45, 0.1, 0.9))
		grad.set_color(1, Color(0.3, 0.05, 0.0, 0.0))
		particles.color_ramp = grad

	add_child(particles)

func _process(delta: float) -> void:
	_timer += delta * wave_speed

	# Di chuyển theo hướng bay thẳng
	var step := _target_dir * (fly_speed * delta)
	position += step
	_flight_distance_traveled += step.length()

	# Tính độ cao địa hình bên dưới vị trí hiện tại của rồng
	var ground_y := MuTerrain.height_at(position.x, -position.z)
	var wave_offset := -absf(sin(_timer)) * wave_height + wave_height * 0.5
	var target_y := ground_y + base_altitude + wave_offset
	position.y = lerp(position.y, target_y, clampf(delta * 3.5, 0.0, 1.0))

	# Giữ hướng bay đầu rồng chuẩn + lượn nhẹ góc nghiêng thân (banking / tilt)
	rotation.y = atan2(_target_dir.x, _target_dir.z)
	rotation.z = sin(_timer * 1.5) * 0.12

	# Cập nhật bóng râm trên mặt đất
	if _shadow_mesh:
		_shadow_mesh.global_position = Vector3(position.x, ground_y + 0.06, position.z)
		_shadow_mesh.rotation.y = rotation.y

	# Tiếng gầm khi bay gần vị trí trung tâm hành trình
	if not _has_roared and _flight_distance_traveled > (_max_flight_distance * 0.3):
		_has_roared = true
		_play_roar()

	# Tự huỷ khi bay quá xa
	if _flight_distance_traveled >= _max_flight_distance:
		queue_free()

func _play_roar() -> void:
	if _audio_player and not _audio_player.playing:
		_audio_player.pitch_scale = randf_range(0.85, 1.1)
		_audio_player.play()

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var m = _find_mesh(c)
		if m: return m
	return null

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var ap = _find_anim_player(c)
		if ap: return ap
	return null
