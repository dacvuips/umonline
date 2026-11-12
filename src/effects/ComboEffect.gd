extends MuFx
class_name ComboEffect

## Hiệu ứng COMBO (MODEL_COMBO) chuẩn mã nguồn gốc MU Online:
## Nguồn Client:
##   - WSclient.cpp: case AT_SKILL_COMBO: CreateEffect(MODEL_COMBO, so->Position, so->Angle, so->Light); PlayBuffer(SOUND_COMBO);
##   - ZzzEffect.cpp (dòng 2616): MODEL_COMBO: LifeTime 20, Gravity 0.1, BlendMesh -2, BlendMeshLight 1.0, 60 tia sáng BITMAP_LIGHT
##   - MoveHandlers.cpp (dòng 5304): Move_MODEL_COMBO: Scale += Gravity * FPS_FACTOR, Gravity += 0.1 * FPS_FACTOR, BlendMeshLight *= (1/1.4)
## Nguồn Server (OpenMU):
##   - SkillsInitializer.cs / ComboStateMachine.cs: Step 1 (Vũ khí 19..23) -> Step 2 (Class 41,42,43,232) -> Step 3 (Class khác Step 2)
##   - Sát thương Combo: Stats.ComboBonus = (Strength + Agility + Energy) / 2

var _origin := Vector3.ZERO
var _combo_obj: Dictionary = {}
var _gravity: float = 0.1
var _light: float = 1.0

func setup_combo(p_caster: Node3D, p_target: Node3D = null, custom_pos: Vector3 = Vector3.ZERO) -> void:
	caster = p_caster
	target = p_target
	if custom_pos != Vector3.ZERO:
		_origin = custom_pos
	elif p_target != null and is_instance_valid(p_target):
		_origin = p_target.global_position
	elif p_caster != null and is_instance_valid(p_caster):
		_origin = p_caster.global_position
	else:
		_origin = Vector3.ZERO

	_origin.y = ground(_origin) + 0.45
	global_position = _origin

	# 1. Âm thanh bộc phá Combo gốc: eCombo.wav
	if MuAudioManager:
		MuAudioManager.play_combo(_origin)

	# 2. Tạo 3D Model MODEL_COMBO (combo.glb với combo3.jpg additive blend)
	_combo_obj = model("Skill/combo", _origin, {
		"scale": 0.5,
		"life": 22.0,
		"blend_mesh": -2,
		"light": 1.0,
		"color": Color(0.4, 0.85, 1.0)
	})

	_gravity = 0.12
	_light = 1.0
	_combo_obj["update"] = func(ob: Dictionary, dt: float) -> void:
		var factor: float = dt * 25.0
		ob["scale"] = float(ob["scale"]) + _gravity * factor
		_gravity += 0.04 * factor
		_light *= pow(1.0 / 1.35, factor)
		ob["light"] = _light

	# 3. Sinh 60 tia sáng bùng nổ toả tròn 360 độ (BITMAP_LIGHT trong ZzzEffect.cpp:2627)
	for i in 48:
		var ang := randf() * TAU
		var spd := randf_range(0.06, 0.18)
		var p_pos := _origin + Vector3(randf_range(-0.15, 0.15), randf_range(0.05, 0.4), randf_range(-0.15, 0.15))
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

	# 4. Tia sáng cột trụ bộc phát thẳng đứng (Shockwave Blast)
	particle("BITMAP_LIGHT", _origin + Vector3(0, 0.8, 0), {
		"size": 2.2,
		"life": 16.0,
		"color": Color(0.6, 0.95, 1.0),
		"grow": 1.25
	})
