extends MuFx
class_name ComboEffect3D

## Hiệu ứng Combo của Dark Knight / Blade Knight (eCombo.wav + MODEL_COMBO)
## Nguồn chuẩn Client gốc:
##   - WSclient.cpp: case AT_SKILL_COMBO: CreateEffect(MODEL_COMBO), PlayBuffer(SOUND_COMBO)
##   - ZzzEffect.cpp:2616 (MODEL_COMBO: LifeTime 20, Gravity 0.1, BlendMesh -2, BlendMeshLight 1.0, 60 tia BITMAP_LIGHT)
##   - MoveHandlers.cpp:5304 (Move_MODEL_COMBO: Scale += Gravity, Gravity += 0.1, BlendMeshLight *= 1/1.4)

func setup(pos: Vector3) -> void:
	global_position = pos
	var base_y := ground(pos) + 0.35
	global_position.y = base_y

	# 1. Âm thanh bộc phá Combo gốc: eCombo.wav
	if MuAudioManager:
		MuAudioManager.play_combo(global_position)

	# 2. 3D Model MODEL_COMBO (combo.glb với combo3.jpg additive blend -2)
	var combo_obj := model("Skill/combo", global_position, {
		"scale": 0.5,
		"life": 24.0,
		"blend_mesh": -2,
		"light": 1.0,
		"color": Color(0.35, 0.85, 1.0)
	})

	var grav: float = 0.12
	var light_val: float = 1.0
	combo_obj["update"] = func(ob: Dictionary, dt: float) -> void:
		var factor: float = dt * 25.0
		ob["scale"] = float(ob["scale"]) + grav * factor
		grav += 0.05 * factor
		light_val *= pow(1.0 / 1.35, factor)
		ob["light"] = light_val

	# 3. 48-60 tia sáng bùng nổ toả tròn 360 độ (BITMAP_LIGHT trong ZzzEffect.cpp:2627)
	for i in 48:
		var ang := randf() * TAU
		var spd := randf_range(0.06, 0.18)
		var p_pos := global_position + Vector3(randf_range(-0.15, 0.15), randf_range(0.05, 0.4), randf_range(-0.15, 0.15))
		var vel := Vector3(cos(ang) * spd, randf_range(0.02, 0.10), sin(ang) * spd)
		var sz := randf_range(0.45, 0.85)
		var col := Color(0.3, 0.9, 1.0) if randf() < 0.75 else Color(0.9, 0.95, 1.0)
		particle("BITMAP_LIGHT", p_pos, {
			"vel": vel,
			"drag": 0.92,
			"size": sz,
			"grow": 1.05,
			"life": randf_range(14.0, 22.0),
			"color": col
		})

	# 4. Tia sáng cột sóng chấn động bộc phát thẳng đứng
	particle("BITMAP_LIGHT", global_position + Vector3(0, 0.6, 0), {
		"size": 2.6,
		"life": 16.0,
		"color": Color(0.6, 0.95, 1.0),
		"grow": 1.25
	})
