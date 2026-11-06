extends Node3D
class_name FireballProjectile

## Đạn phép thuật Cầu Lửa (Fireball) bay tầm xa trong MU Online
## Bay từ nhân vật tới mục tiêu, phát nổ và gây sát thương khi trúng đích

@export var speed: float = 12.0
var target_monster: MuMonster = null
var damage: int = 50
var caster: Node3D = null

func setup(p_target: MuMonster, p_damage: int, p_caster: Node3D) -> void:
	target_monster = p_target
	damage = p_damage
	caster = p_caster

func _ready() -> void:
	# Quả cầu lửa phát sáng
	var sphere = CSGSphere3D.new()
	sphere.radius = 0.35
	sphere.radial_segments = 16
	sphere.rings = 8
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.1) # Màu cam lửa
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 4.0
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sphere.material_override = mat
	add_child(sphere)

func _exit_tree() -> void:
	for c in get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.material_override = null

func _process(delta: float) -> void:
	if not is_instance_valid(target_monster) or target_monster.is_dead:
		_explode()
		return

	var target_pos = target_monster.global_position + Vector3(0, 1.0, 0)
	var dir = (target_pos - global_position)
	var dist = dir.length()
	var step = speed * delta

	if dist <= step:
		global_position = target_pos
		_hit_target()
	else:
		global_position += dir.normalized() * step

func _hit_target() -> void:
	if is_instance_valid(target_monster) and not target_monster.is_dead:
		var roll = randf()
		var dmg_type = DamageNumber3D.DamageType.NORMAL
		var final_dmg = damage
		if roll < 0.2:
			final_dmg = int(damage * 1.5)
			dmg_type = DamageNumber3D.DamageType.EXCELLENT
		elif roll < 0.4:
			final_dmg = int(damage * 1.25)
			dmg_type = DamageNumber3D.DamageType.CRITICAL

		target_monster.take_damage(final_dmg, dmg_type)
		if target_monster.is_dead and caster and caster.has_method("reward_kill"):
			caster.reward_kill(target_monster)
	_explode()

func _explode() -> void:
	if MuAudioManager:
		MuAudioManager.play_fireball_hit(global_position)

	# Hiệu ứng nổ cầu lửa
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(2.0, 2.0, 2.0), 0.15)
	var mat = get_child(0).material_override as StandardMaterial3D
	if mat:
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
