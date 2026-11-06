extends Label3D
class_name ChatBubble

## Bóng thoại (Chat Bubble) hiển thị lời nói trên đầu nhân vật trong MU Online

func setup(message: String, start_pos: Vector3, duration: float = 4.0) -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 26
	outline_size = 6
	outline_modulate = Color.BLACK
	modulate = Color(1.0, 1.0, 1.0)
	text = message
	global_position = start_pos + Vector3(0, 2.6, 0)

	var tween = create_tween()
	tween.tween_interval(duration - 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
