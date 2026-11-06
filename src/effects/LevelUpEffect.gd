extends Node3D
class_name LevelUpEffect

## Hiệu ứng Thăng Cấp (Level Up) rực rỡ đặc trưng của MU Online
## Cột ánh sáng vàng tỏa sáng bao quanh nhân vật và bay vút lên trời

func _ready() -> void:
	if MuAudioManager:
		MuAudioManager.play_level_up()

	# 1. Cột ánh sáng trung tâm
	var pillar = CSGCylinder3D.new()
	pillar.radius = 1.0
	pillar.height = 4.0
	pillar.sides = 16
	pillar.position = Vector3(0, 2.0, 0)
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.9, 0.3, 0.7) # Vàng kim MU
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 4.0
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.material_override = mat
	add_child(pillar)

	# 2. Vòng tròn hào quang mở rộng
	var aura = CSGTorus3D.new()
	aura.inner_radius = 0.8
	aura.outer_radius = 1.2
	aura.position = Vector3(0, 0.2, 0)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.material_override = mat
	add_child(aura)

	# 3. Label "LEVEL UP!"
	var lbl = Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.text = "LEVEL UP!"
	lbl.font_size = 48
	lbl.modulate = Color(1.0, 0.95, 0.2)
	lbl.outline_size = 8
	lbl.outline_modulate = Color.BLACK
	lbl.position = Vector3(0, 2.8, 0)
	add_child(lbl)

	# Tween chuyển động
	var tween = create_tween().set_parallel(true)
	tween.tween_property(pillar, "scale:y", 2.0, 0.8)
	tween.tween_property(aura, "scale", Vector3(2.5, 1.0, 2.5), 0.8)
	tween.tween_property(lbl, "position:y", 3.8, 0.8)

	var fade = create_tween()
	fade.tween_interval(0.4)
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	fade.tween_property(lbl, "modulate:a", 0.0, 0.4)
	fade.tween_callback(queue_free)

func _exit_tree() -> void:
	for c in get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.material_override = null
