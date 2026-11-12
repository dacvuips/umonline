extends Node3D
class_name MuAmbientFauna

## Chim bay lượn trên Lorencia (MODEL_BIRD01) và cá bơi dưới sông (MODEL_FISH01)
## Mô hình & animation vỗ cánh / quẫy đuôi lấy từ Object1/Bird01.bmd, Fish01.bmd

enum FaunaType { BIRD, BUTTERFLY, FISH }

@export var fauna_type: FaunaType = FaunaType.BIRD
@export var center_pos: Vector3 = Vector3(140, 0, -119)
@export var patrol_radius: float = 6.0
@export var move_speed: float = 2.0

var _angle: float = 0.0
var _dir_sign: float = 1.0
var _fly_height: float = 3.0

var _audio_player: AudioStreamPlayer3D = null
var _chirp_timer: float = 0.0
var _splash_timer: float = 0.0

func _ready() -> void:
	_angle = randf_range(0.0, TAU)
	_dir_sign = 1.0 if randf() > 0.5 else -1.0
	match fauna_type:
		FaunaType.BIRD:
			move_speed = randf_range(2.8, 4.2)
			_fly_height = randf_range(2.5, 4.5)
		FaunaType.FISH:
			move_speed = randf_range(0.3, 0.6)
			_splash_timer = randf_range(5.0, 15.0)
			_setup_audio_player(18.0, 2.0)
		_:
			move_speed = randf_range(1.0, 1.8)

func _setup_audio_player(max_dist: float, unit_sz: float) -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "FaunaAudio"
	_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_audio_player.unit_size = unit_sz
	_audio_player.max_distance = max_dist
	_audio_player.max_db = 1.0
	_audio_player.bus = "Master"
	add_child(_audio_player)

func _process(delta: float) -> void:
	var ground := MuTerrain.height_at(center_pos.x, -center_pos.z)
	match fauna_type:
		FaunaType.BIRD:
			_angle += _dir_sign * (move_speed / patrol_radius) * delta
			var target := Vector3(center_pos.x + cos(_angle) * patrol_radius,
				ground + _fly_height + sin(_angle * 2.5) * 0.5,
				center_pos.z + sin(_angle) * patrol_radius)
			_move_towards(target, delta, 4.0)
			rotation.z = sin(Time.get_ticks_msec() * 0.005) * 0.15

		FaunaType.FISH:
			_angle += _dir_sign * (move_speed / patrol_radius) * delta
			var target := Vector3(center_pos.x + cos(_angle) * patrol_radius,
				ground - 0.05,
				center_pos.z + sin(_angle) * patrol_radius)
			_move_towards(target, delta, 2.0)

			# Tiếng quẫy nước nhẹ ngẫu nhiên
			_splash_timer -= delta
			if _splash_timer <= 0.0:
				_splash_timer = randf_range(12.0, 25.0)
				_play_fish_splash()

		_:
			_angle += move_speed * delta * 0.8
			position = Vector3(center_pos.x + cos(_angle) * patrol_radius, ground + 0.6 + sin(Time.get_ticks_msec() * 0.008) * 0.4, center_pos.z + sin(_angle) * patrol_radius)

func _play_bird_chirp() -> void:
	return

func _play_fish_splash() -> void:
	if not _audio_player or _is_far_from_listener(20.0):
		return
	var stream = MuAudioManager.get_instance().load_wav("pSwim.wav")
	if stream:
		_audio_player.stream = stream
		_audio_player.volume_db = randf_range(-14.0, -9.0)
		_audio_player.pitch_scale = randf_range(0.9, 1.2)
		_audio_player.play()

func _is_far_from_listener(max_range: float) -> bool:
	var cam = get_viewport().get_camera_3d() if get_viewport() else null
	if cam:
		return global_position.distance_squared_to(cam.global_position) > (max_range * max_range)
	return false

func _move_towards(target: Vector3, delta: float, turn: float) -> void:
	var dir := target - position
	position = position.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
	if Vector2(dir.x, dir.z).length() > 0.001:
		# Mô hình MU nhìn về -Y (MU) = +Z (Godot)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * turn, 0.0, 1.0))
