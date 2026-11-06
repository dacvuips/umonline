extends Node3D
class_name MuSwayingProp

## Tạo chuyển động lắc lư mềm mại cho biển hiệu, cờ, màn vải treo Lorencia

@export var sway_speed: float = 1.8
@export var sway_angle_deg: float = 2.5 # Góc lắc nhẹ độ
@export var sway_axis: Vector3 = Vector3(1, 0, 0) # Trục lắc

var _base_rotation: Vector3
var _time_offset: float = 0.0

func _ready() -> void:
	_base_rotation = rotation
	_time_offset = randf_range(0.0, 50.0)

func _process(delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.001 * sway_speed + _time_offset
	var angle = deg_to_rad(sin(t) * sway_angle_deg)
	rotation = _base_rotation + sway_axis * angle
