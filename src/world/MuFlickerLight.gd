extends OmniLight3D
class_name MuFlickerLight

## Tạo hiệu ứng ánh lửa bập bùng sống động cho đèn đuốc, đống lửa, đèn đường Lorencia

@export var base_energy: float = 2.2
@export var flicker_intensity: float = 0.4
@export var flicker_speed: float = 10.0

var _time_offset: float = 0.0

func _ready() -> void:
	_time_offset = randf_range(0.0, 100.0)

func _process(delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.001 * flicker_speed + _time_offset
	# Kết hợp 2 hàm sóng sin tần số khác nhau và một chút nhiễu ngẫu nhiên
	var wave = sin(t) * 0.5 + sin(t * 2.3) * 0.3 + (randf() - 0.5) * 0.2
	light_energy = base_energy + wave * flicker_intensity
