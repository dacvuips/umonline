extends Node3D
class_name AreaRingEffect

## Vòng sáng chung cho các skill vùng chưa port hiệu ứng gốc (Hellfire, Inferno, ...)

func _ready() -> void:

	var ring = CSGTorus3D.new()
	ring.inner_radius = 2.0
	ring.outer_radius = 2.4
	ring.ring_sides = 24
	ring.sides = 12
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _create_slash_material()
	ring.position = Vector3(0, 0.8, 0)
	add_child(ring)

	var tween = create_tween().set_parallel(true)
	# Xoay tít 360 độ cực nhanh
	tween.tween_property(ring, "rotation:y", TAU * 2.0, 0.4)
	# Phóng to nhẹ và mờ dần
	tween.tween_property(ring, "scale", Vector3(1.4, 1.4, 1.4), 0.4)
	
	var mat_tween = create_tween()
	mat_tween.tween_interval(0.2)
	mat_tween.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.2)
	mat_tween.tween_callback(queue_free)

func _exit_tree() -> void:
	for c in get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.material_override = null

func _create_slash_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.8, 1.0, 0.85) # Ánh sáng xanh băng/kiếm khí MU
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.7, 1.0)
	mat.emission_energy_multiplier = 3.0
	return mat
