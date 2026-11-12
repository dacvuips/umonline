extends Label3D
class_name DamageNumber3D

## Hiển thị số sát thương bay lên (Floating Damage) đặc trưng của MU Online
## Màu sắc: Vàng cam (Thường), Xanh lá (Excellent), Xanh dương (Critical), Xám (Miss)

enum DamageType {
	NORMAL,
	EXCELLENT,
	CRITICAL,
	MISS,
	COMBO
}

func setup(damage_value: int, type: DamageType = DamageType.NORMAL, start_pos: Vector3 = Vector3.ZERO) -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 36
	outline_size = 8
	outline_modulate = Color.BLACK
	global_position = start_pos + Vector3(0, 1.8, 0)
	
	match type:
		DamageType.NORMAL:
			text = str(damage_value)
			modulate = Color(1.0, 0.75, 0.15) # Vàng cam MU
		DamageType.EXCELLENT:
			text = str(damage_value) + "!"
			modulate = Color(0.15, 1.0, 0.3) # Xanh lá cây Excellent MU
			font_size = 44
		DamageType.CRITICAL:
			text = str(damage_value)
			modulate = Color(0.2, 0.7, 1.0) # Xanh dương Critical MU
			font_size = 40
		DamageType.MISS:
			text = "MISS"
			modulate = Color(0.7, 0.7, 0.7)
		DamageType.COMBO:
			text = "★ COMBO " + str(damage_value) + "! ★"
			modulate = Color(0.3, 0.9, 1.0) # Xanh băng sáng rực rỡ đặc trưng Combo MU
			outline_modulate = Color(0.1, 0.1, 0.4)
			font_size = 48

	# Hiệu ứng Tween bay lên và mờ dần
	var tween = create_tween().set_parallel(true)
	var target_y = global_position.y + 1.2
	# Nhảy lên hơi ngẫu nhiên sang trái/phải một chút
	var offset_x = randf_range(-0.3, 0.3)
	
	tween.tween_property(self, "global_position:y", target_y, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:x", global_position.x + offset_x, 0.85)
	
	# Fade out mờ dần ở 0.35s cuối
	var alpha_tween = create_tween()
	alpha_tween.tween_interval(0.4)
	alpha_tween.tween_property(self, "modulate:a", 0.0, 0.45)
	alpha_tween.tween_callback(queue_free)
