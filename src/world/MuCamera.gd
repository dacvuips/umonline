extends Camera3D
class_name MuCamera

## Camera Isometric đặc trưng của MU Online, hỗ trợ:
##  - Zoom linh hoạt: Từ tầm nhìn rộng (18.0) tới cận cảnh khuôn mặt (1.2m) thấy rõ chi tiết mặt, mũ, mắt, trang bị
##  - Nâng tiêu điểm và góc nhìn mượt mà: Khi zoom sát, góc nhìn hạ từ -48.5° xuống -75° (ngang mặt) và tiêu điểm chuyển từ chân lên mặt nhân vật
##  - Xoay 360° quanh nhân vật: Giữ chuột giữa (hoặc Alt + chuột trái) kéo để ngắm nhân vật từ mọi góc độ
##  - Reset nhanh: Phím F11, Home hoặc nhấp đúp chuột giữa để quay lại góc camera MU gốc

@export var target_node: Node3D = null
@export var follow_speed: float = 12.0
@export var distance: float = 13.0 # 1300 đơn vị MU mặc định
@export var min_distance: float = 1.2 # Cho phép zoom sát 1.2m (thấy rõ từng chi tiết mặt)
@export var max_distance: float = 18.0 # Tầm nhìn xa

const PITCH_DEG := -48.5
const YAW_DEG := -45.0
const HEIGHT_OFFSET := 1.5 # CAMERA_DISTANCE_HEIGHT_OFFSET = 150
const CLOSE_PITCH_DEG := -75.0 # Góc nhìn cận cảnh mặt (15° so với phương ngang)
const HEAD_HEIGHT := 1.45 # Chiều cao khuôn mặt nhân vật chuẩn MU (m)
const ZOOM_TRANSITION_START := 10.0 # Bắt đầu hạ góc và nâng tiêu điểm vào mặt khi distance < 10.0

var yaw_deg: float = YAW_DEG
var pitch_deg: float = PITCH_DEG
var _is_orbiting: bool = false
var _orbit_start_mouse: Vector2 = Vector2.ZERO

# Touch pinch zoom tracking (Mobile / Web)
var _touches: Dictionary = {}
var _touch_start_dist: float = 0.0
var _touch_start_cam_dist: float = 13.0

func _ready() -> void:
	process_priority = 100
	current = true
	fov = 30.5
	near = 0.1 # Rút ngắn near plane để không bao giờ cắt xén mặt/mũ khi zoom sát
	far = 60.0
	_update_camera_transform(true)

func _build_basis_for(p_pitch: float, p_yaw: float) -> Basis:
	var a0 := deg_to_rad(p_pitch)
	var a2 := deg_to_rad(p_yaw)
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
	return Basis(right, up, -fwd)

func _get_camera_offset() -> Vector3:
	var k: float = clampf((ZOOM_TRANSITION_START - distance) / (ZOOM_TRANSITION_START - min_distance), 0.0, 1.0) if distance < ZOOM_TRANSITION_START else 0.0
	pitch_deg = lerp(PITCH_DEG, CLOSE_PITCH_DEG, k)
	var target_y: float = HEAD_HEIGHT * k
	
	var a0: float = deg_to_rad(pitch_deg)
	var s0: float = sin(a0)
	var c0: float = cos(a0)
	
	var a2: float = deg_to_rad(yaw_deg)
	var s2: float = sin(a2)
	var c2: float = cos(a2)
	var offset_dir := Vector2(-s2, c2) # Godot x = MU x ; Godot z = -MU y
	
	var legacy_h: float = distance
	var close_h: float = distance * (-s0)
	var horiz: float = lerp(legacy_h, close_h, k)
	
	var slope: float = c0 / (-s0)
	var vert: float = horiz * slope
	
	return Vector3(offset_dir.x * horiz, target_y + vert, offset_dir.y * horiz)

func _process(_delta: float) -> void:
	if target_node:
		var target_pos: Vector3 = target_node.global_position if target_node.is_inside_tree() else target_node.position
		var desired: Vector3 = target_pos + _get_camera_offset()
		if is_inside_tree():
			global_position = desired # bám sát nhân vật không trễ -> không rung lắc
		else:
			position = desired
		transform.basis = _build_basis_for(pitch_deg, yaw_deg)

func _update_camera_transform(immediate: bool = false) -> void:
	var offset: Vector3 = _get_camera_offset()
	transform.basis = _build_basis_for(pitch_deg, yaw_deg)
	if target_node:
		var target_pos: Vector3 = target_node.global_position if target_node.is_inside_tree() else target_node.position
		if is_inside_tree():
			global_position = target_pos + offset
		else:
			position = target_pos + offset

## Cuộn chuột để zoom, giữ chuột giữa (hoặc Alt+chuột trái) để xoay, F11/Home để reset
func _unhandled_input(event: InputEvent) -> void:
	# 1. Mouse Wheel Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var step := 0.25 if distance <= 3.0 else (0.5 if distance <= 6.0 else 1.0)
			distance = clampf(distance - step, min_distance, max_distance)
			_update_camera_transform()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var step := 0.25 if distance <= 3.0 else (0.5 if distance <= 6.0 else 1.0)
			distance = clampf(distance + step, min_distance, max_distance)
			_update_camera_transform()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_orbiting = event.pressed
			if event.pressed:
				_orbit_start_mouse = event.position
			if event.double_click:
				reset_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.alt_pressed:
			_is_orbiting = event.pressed
			if event.pressed:
				_orbit_start_mouse = event.position
				get_viewport().set_input_as_handled()

	# 2. Xoay camera khi giữ chuột giữa hoặc Alt + chuột trái
	elif event is InputEventMouseMotion and _is_orbiting:
		yaw_deg += event.relative.x * 0.4
		_update_camera_transform()
		get_viewport().set_input_as_handled()

	# 3. Mobile Multi-touch Pinch to Zoom
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 2:
				var pts = _touches.values()
				_touch_start_dist = pts[0].distance_to(pts[1])
				_touch_start_cam_dist = distance
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			_touches[event.index] = event.position
		if _touches.size() == 2:
			var pts = _touches.values()
			var cur_dist: float = pts[0].distance_to(pts[1])
			if _touch_start_dist > 10.0 and cur_dist > 10.0:
				var ratio: float = _touch_start_dist / cur_dist
				distance = clampf(_touch_start_cam_dist * ratio, min_distance, max_distance)
				_update_camera_transform()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11 or event.keycode == KEY_HOME:
			reset_camera()

## Quay về góc nhìn chuẩn của MU Online
func reset_camera() -> void:
	distance = 13.0
	yaw_deg = YAW_DEG
	pitch_deg = PITCH_DEG
	_update_camera_transform(true)
