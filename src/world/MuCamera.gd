extends Camera3D
class_name MuCamera

## Camera mặc định của MU (Camera/DefaultCamera.cpp) chuyển sang Godot:
##  - Góc: Angle = (-48.5, 0, -45)
##  - Vị trí: Hero + AngleMatrix(Angle)^T * (0, -Distance, 0), độ cao = HeroZ + Distance - 150
##  - Khoảng cách theo bậc zoom 1000..1700 (mặc định bậc 3 = 1300 đơn vị MU)
##  - hFov 40° ở tỉ lệ 4:3  -> vFov ~ 30.5°
## Hệ trục: MU(x, y, z-lên) -> Godot(x, z, -y), 1 đơn vị Godot = 100 đơn vị MU

@export var target_node: Node3D = null
@export var follow_speed: float = 12.0
@export var distance: float = 13.0 # 1300 đơn vị MU
@export var min_distance: float = 10.0
@export var max_distance: float = 17.0

const PITCH_DEG := -48.5
const YAW_DEG := -45.0
const HEIGHT_OFFSET := 1.5 # CAMERA_DISTANCE_HEIGHT_OFFSET = 150

var _mu_basis: Basis
var _offset_dir: Vector2 # hướng ngang (Godot x, z) từ nhân vật tới camera, nhân với distance

func _ready() -> void:
	process_priority = 100
	current = true
	fov = 30.5
	near = 0.2 # ViewNear = 20
	far = 60.0
	_build_basis()
	_update_camera_transform(true)

func _build_basis() -> void:
	var a0 := deg_to_rad(PITCH_DEG)
	var a2 := deg_to_rad(YAW_DEG)
	var s0 := sin(a0)
	var c0 := cos(a0)
	var s2 := sin(a2)
	var c2 := cos(a2)
	# forward/up trong hệ MU (DefaultCamera::UpdateFrustum với Angle[1] = 0)
	var fwd_mu := Vector3(-(s0 * s2), -(s0 * c2), -c0)
	var up_mu := Vector3(c0 * s2, c0 * c2, -s0)
	var fwd := Vector3(fwd_mu.x, fwd_mu.z, -fwd_mu.y).normalized()
	var up := Vector3(up_mu.x, up_mu.z, -up_mu.y).normalized()
	var right := fwd.cross(up).normalized()
	up = right.cross(fwd).normalized()
	_mu_basis = Basis(right, up, -fwd)
	# DefaultCamera::Update(): CalculateCameraPosition() chạy khi Angle còn là (0, 0, -45),
	# SetCameraAngle() mới đặt pitch -48.5 SAU đó. Vì vậy vị trí = Hero + Rz(-45)^T * (0, -D, 0)
	# = D * (-sin(yaw), -cos(yaw)) = D * (0.707, -0.707) trong hệ MU -> nhân vật nằm giữa màn hình.
	var off_mu := Vector2(-s2, -c2)
	_offset_dir = Vector2(off_mu.x, -off_mu.y) # Godot x = MU x ; Godot z = -MU y

func _process(_delta: float) -> void:
	if target_node:
		var desired := target_node.global_position + _get_camera_offset()
		global_position = desired   # camera MU bám chặt nhân vật (không trễ -> không rung)
		transform.basis = _mu_basis

func _get_camera_offset() -> Vector3:
	return Vector3(_offset_dir.x * distance, distance - HEIGHT_OFFSET, _offset_dir.y * distance)

func _update_camera_transform(immediate: bool = false) -> void:
	transform.basis = _mu_basis
	if not target_node:
		return
	if immediate:
		global_position = target_node.global_position + _get_camera_offset()

## Cuộn chuột để zoom (bậc 100 đơn vị như PLAYER_ZOOM_LADDER)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clamp(distance - 1.0, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clamp(distance + 1.0, min_distance, max_distance)
