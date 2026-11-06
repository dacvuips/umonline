extends Node3D
class_name MuWings

## Đôi Cánh Huyền Thoại (Legendary Wings) của MU Online
## Hiệu ứng vẫy cánh bồng bềnh và phát quang (Glow Emission) rực rỡ sau lưng nhân vật

@export var wing_color: Color = Color(1.0, 0.35, 0.1) # Màu cánh rồng Dragon Wings đỏ cam
@export var flap_speed: float = 3.5
@export var flap_angle: float = 18.0

var wing_left: CSGPolygon3D
var wing_right: CSGPolygon3D
var time_passed: float = 0.0

func _ready() -> void:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = wing_color
	mat.albedo_color.a = 0.85
	mat.emission_enabled = true
	mat.emission = wing_color
	mat.emission_energy_multiplier = 3.5

	# Dựng hình dáng cánh góc cạnh đặc trưng MU
	var points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(0.4, 0.8),
		Vector2(1.2, 1.4),
		Vector2(1.5, 0.9),
		Vector2(1.8, 1.3),
		Vector2(1.4, 0.2),
		Vector2(0.8, -0.3),
		Vector2(0, -0.2)
	])

	# Cánh trái
	wing_left = CSGPolygon3D.new()
	wing_left.polygon = points
	wing_left.depth = 0.05
	wing_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wing_left.material_override = mat
	wing_left.position = Vector3(-0.15, 1.1, 0.25)
	add_child(wing_left)

	# Cánh phải (đối xứng)
	var points_right = PackedVector2Array()
	for p in points:
		points_right.append(Vector2(-p.x, p.y))

	wing_right = CSGPolygon3D.new()
	wing_right.polygon = points_right
	wing_right.depth = 0.05
	wing_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wing_right.material_override = mat
	wing_right.position = Vector3(0.15, 1.1, 0.25)
	add_child(wing_right)

func _process(delta: float) -> void:
	time_passed += delta * flap_speed
	var flap = sin(time_passed) * deg_to_rad(flap_angle)
	
	if wing_left:
		wing_left.rotation.y = flap
	if wing_right:
		wing_right.rotation.y = -flap


func _exit_tree() -> void:
	if wing_left:
		wing_left.material_override = null
	if wing_right:
		wing_right.material_override = null
