extends Node3D
class_name TeleportEffect

## Hiệu ứng Dịch Chuyển (Gate / Town Portal Teleport) trong MU Online

func _ready() -> void:
	# Vòng xoáy ánh sáng
	var ring = CSGTorus3D.new()
	ring.inner_radius = 1.2
	ring.outer_radius = 1.5
	ring.position = Vector3(0, 0.1, 0)
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.6, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 1.0)
	mat.emission_energy_multiplier = 4.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = mat
	add_child(ring)

	# Cột năng lượng xoáy
	var cyl = CSGCylinder3D.new()
	cyl.radius = 0.8
	cyl.height = 3.5
	cyl.position = Vector3(0, 1.75, 0)
	cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl.material_override = mat
	add_child(cyl)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(ring, "rotation:y", TAU * 3.0, 0.6)
	tween.tween_property(cyl, "scale:y", 1.8, 0.6)
	
	var fade = create_tween()
	fade.tween_interval(0.3)
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	fade.tween_callback(queue_free)

func _exit_tree() -> void:
	for c in get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.material_override = null
