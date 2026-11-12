extends Label3D
class_name ChatBubble

## Bóng thoại (Chat Bubble) hiển thị lời nói trên đầu nhân vật trong MU Online

const HEAD_OFFSET := Vector3(0, 1.7, 0)
const MOUNT_HEAD_OFFSET := Vector3(0, 2.15, 0)

## Bóng thoại đặt tại vị trí thế giới (không đi theo nhân vật)
func setup(message: String, start_pos: Vector3, duration: float = 4.0, is_mounted: bool = false) -> void:
	_style(message)
	var offset = MOUNT_HEAD_OFFSET if is_mounted else HEAD_OFFSET
	global_position = start_pos + offset
	_fade_out(duration)

## Bóng thoại gắn làm con của nhân vật (đi theo nhân vật): gọi sau add_child
func show_chat(message: String, duration: float = 4.0) -> void:
	_style(message)
	var offset := HEAD_OFFSET
	var p = get_parent()
	if p:
		var is_mounted: bool = false
		if "model" in p and p.model and "ride_kind" in p.model and p.model.ride_kind != "":
			is_mounted = true
		elif "_ride_info" in p and p._ride_info is Dictionary and not p._ride_info.is_empty():
			is_mounted = true
		if is_mounted:
			offset = MOUNT_HEAD_OFFSET
	position = offset
	_fade_out(duration)

func _style(message: String) -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 26
	outline_size = 6
	outline_modulate = Color.BLACK
	modulate = Color(1.0, 1.0, 1.0)
	text = message

func _fade_out(duration: float) -> void:
	var tween = create_tween()
	tween.tween_interval(maxf(duration - 0.6, 0.0))
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
