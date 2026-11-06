extends Control
class_name MuVirtualJoystick

## Cần điều khiển ảo 360 độ (Touch Virtual Joystick) cho Mobile (Android/iOS) và PC
## Hỗ trợ kéo di chuyển liên tục 8 hướng trong không gian 3D của MU

signal joystick_moved(direction: Vector2)
signal joystick_released()

@export var max_radius: float = 60.0
@export var deadzone: float = 0.15
@export var base_color: Color = Color(0.12, 0.14, 0.18, 0.55)
@export var ring_color: Color = Color(0.85, 0.75, 0.35, 0.7)
@export var handle_color: Color = Color(0.95, 0.85, 0.35, 0.9)

var is_dragging: bool = false
var touch_id: int = -1
var handle_pos: Vector2 = Vector2.ZERO
var current_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(max_radius * 2.2, max_radius * 2.2)
	queue_redraw()

func _process(_delta: float) -> void:
	if is_dragging and current_direction.length() > deadzone:
		emit_signal("joystick_moved", current_direction)

## Lấy vector hướng hiện tại của Joystick (khoảng -1.0 tới 1.0)
func get_direction() -> Vector2:
	if is_dragging and current_direction.length() > deadzone:
		return current_direction
	return Vector2.ZERO

func _gui_input(event: InputEvent) -> void:
	# Nhận diện điểm chạm ngón tay bắt đầu trên Joystick (Mobile)
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			is_dragging = true
			_update_handle_from_global(event.position + global_position)
			accept_event()
		elif not event.pressed and event.index == touch_id:
			_reset_joystick()
			accept_event()

	# Nhận diện click chuột trái bắt đầu trên Joystick (PC / Web)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				touch_id = -1
				is_dragging = true
				_update_handle_from_global(event.position + global_position)
				accept_event()
			elif is_dragging and touch_id == -1:
				_reset_joystick()
				accept_event()

## Bắt sự kiện kéo toàn màn hình để không bị đứt đoạn khi ngón tay hoặc chuột trượt ra ngoài phạm vi Joystick
func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventScreenDrag and event.index == touch_id:
		_update_handle_from_global(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == touch_id and not event.pressed:
		_reset_joystick()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and touch_id == -1:
		_update_handle_from_global(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and touch_id == -1:
		_reset_joystick()
		get_viewport().set_input_as_handled()

func _update_handle_from_global(global_pos: Vector2) -> void:
	var center = global_position + size * 0.5
	var diff = global_pos - center
	var dist = diff.length()
	if dist > max_radius:
		diff = diff.normalized() * max_radius
	handle_pos = diff
	queue_redraw()
	
	# Tính toán vector hướng chuẩn hoá (-1.0 đến 1.0)
	var raw_dir = diff / max_radius
	if raw_dir.length() > deadzone:
		current_direction = raw_dir
		emit_signal("joystick_moved", current_direction)
	else:
		current_direction = Vector2.ZERO

func _reset_joystick() -> void:
	is_dragging = false
	touch_id = -1
	handle_pos = Vector2.ZERO
	current_direction = Vector2.ZERO
	queue_redraw()
	emit_signal("joystick_released")

func _draw() -> void:
	var center = size * 0.5
	# Vòng tròn đáy (Base)
	draw_circle(center, max_radius, base_color)
	draw_arc(center, max_radius, 0, TAU, 48, ring_color, 2.5)
	# Vòng tròn tâm chỉ định deadzone
	draw_circle(center, max_radius * 0.25, Color(0.25, 0.25, 0.3, 0.45))
	
	# Núm gạt (Thumb Handle)
	var handle_radius = max_radius * 0.38
	var h_color = handle_color if is_dragging else Color(0.7, 0.65, 0.45, 0.75)
	draw_circle(center + handle_pos, handle_radius, h_color)
	draw_arc(center + handle_pos, handle_radius, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 2.0)
