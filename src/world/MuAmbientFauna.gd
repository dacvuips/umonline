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

func _ready() -> void:
	_angle = randf_range(0.0, TAU)
	_dir_sign = 1.0 if randf() > 0.5 else -1.0
	match fauna_type:
		FaunaType.BIRD:
			move_speed = randf_range(2.8, 4.2)
			_fly_height = randf_range(2.5, 4.5)
		FaunaType.FISH:
			move_speed = randf_range(0.3, 0.6)
		_:
			move_speed = randf_range(1.0, 1.8)

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
		_:
			_angle += move_speed * delta * 0.8
			position = Vector3(center_pos.x + cos(_angle) * patrol_radius, ground + 0.6 + sin(Time.get_ticks_msec() * 0.008) * 0.4, center_pos.z + sin(_angle) * patrol_radius)

func _move_towards(target: Vector3, delta: float, turn: float) -> void:
	var dir := target - position
	position = position.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
	if Vector2(dir.x, dir.z).length() > 0.001:
		# Mô hình MU nhìn về -Y (MU) = +Z (Godot)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * turn, 0.0, 1.0))
