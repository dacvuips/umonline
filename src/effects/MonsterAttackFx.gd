extends "res://src/effects/DarkWizardFx.gd"


## Đòn đánh riêng của quái port tay từ AttackEffect() (Engine/Object/ZzzCharacter.cpp) — những đòn
## không trùng với skill nào của người chơi. Gọi qua MonsterAttackFx.play(caster, kind, target).

const DEVIL_LASER := 9001       # MONSTER_DEVIL: 4 x CreateJoint(BITMAP_JOINT_LASER+1, SubType 0) / tick
const GORGON_FIRE_RING := 9002  # MONSTER_DEATH_GORGON (AT_SKILL_BOSS): 18 x MODEL_FIRE SubType 1 toả tròn
const ARROW_BOMB_3 := 9003     # MONSTER_IRON_WHEEL: 3 x MODEL_ARROW_BOMB (0°, +20°, -20°)
const ARROW_BOMB_1 := 9004     # MONSTER_SOLDIER / GOLDEN_SOLDIER: 1 x MODEL_ARROW_BOMB
const KINDS := [DEVIL_LASER, GORGON_FIRE_RING, ARROW_BOMB_3, ARROW_BOMB_1]

## Số tick 25fps mà AttackEffect còn sinh tia trong một đòn (khung ra đòn của animation tấn công)
const DEVIL_TICKS := 12

static func play(p_caster: Node3D, kind: int, p_target: Node3D) -> float:
	if p_caster == null or p_caster.get_parent() == null:
		return -1.0
	var fx = load("res://src/effects/MonsterAttackFx.gd").new()
	fx.setup_skill(p_caster, p_target, kind)
	p_caster.get_parent().add_child(fx)
	return fx.impact_delay

func _start() -> void:
	match skill_num:
		DEVIL_LASER:
			# PlayBuffer(SOUND_EVIL) ở tick đầu
			if MuAudioManager:
				MuAudioManager.play_sound_file("sEvil.wav", 0.0, 1.0, caster_pos())
			_min_ticks = DEVIL_TICKS
			impact_delay = 0.25
		GORGON_FIRE_RING:
			_gorgon_ring()
		ARROW_BOMB_3:
			for a in [0.0, 20.0, -20.0]:
				_arrow_bomb(a)
		ARROW_BOMB_1:
			_arrow_bomb(0.0)
		_:
			super._start()

func _mu_tick(t: int) -> void:
	if skill_num == DEVIL_LASER:
		if t < DEVIL_TICKS:
			_devil_tick()
		return
	super._mu_tick(t)

## Vị trí xương LinkBone của 2 tay quái (Models.json linkBones; Devil = 16, 25)
func _link_bone_pos(hand: int) -> Vector3:
	var m = caster.get("model") if is_instance_valid(caster) else null
	if m != null and m.get("skeleton") != null:
		var sk := m.skeleton as Skeleton3D
		var bones := [16, 25]
		var b := sk.find_bone("b%03d" % bones[hand])
		if b >= 0:
			return sk.global_transform * sk.get_bone_global_pose(b).origin
	return caster_pos() + Vector3(0.3 if hand == 0 else -0.3, 1.4, 0)

## BITMAP_JOINT_LASER+1 SubType 0: texture JointLaser02 (Scale 60 = rộng 0.6 m), sống 2 tick,
## 50 đoạn đuôi bám theo mục tiêu (MoveHumming 25°) với hướng lệch ngẫu nhiên -> tia lửa uốn lượn ;
## gần mục tiêu sinh BITMAP_FIRE. Mỗi tick: 2 tia từ mỗi tay + 1 hạt lửa ở tay.
func _devil_tick() -> void:
	var to := target_pos() + Vector3(0, 0.8, 0)
	for i in 4:
		var hand := 0 if i < 2 else 1
		var from := _link_bone_pos(hand)
		var r := bolt("BITMAP_JOINT_LASER+1", from, to, 0.45, Color(0.4, 0.4, 0.4), 2.0, 0.0, 0.4)
		r["pts"] = _laser_path(from, to)
		if i % 2 == 1:
			continue
		# CreateParticle(BITMAP_FIRE, SubType 0): Scale 1.28..1.92 giảm 0.04 / tick, bay lên (như lửa đuốc)
		particle("BITMAP_FIRE", from, {"size": float(rnd(64) + 128) * 0.01 * 0.3, "life": 24,
			"sheet": Vector2i(4, 1), "grow": 0.97, "vel": Vector3(0, 0.04, 0), "color": Color(1, 1, 1)})
	if rnd(2) == 0:
		particle("BITMAP_FIRE", to + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)),
			{"size": 0.45, "life": 24, "sheet": Vector2i(4, 1), "grow": 0.97, "vel": Vector3(0, 0.04, 0)})

## Đường đi của 1 tia (MoveJoint BITMAP_JOINT_LASER+1): bắt đầu theo hướng ngang ngẫu nhiên
## (Angle = (0, 0, rand%360)), mỗi bước quay về mục tiêu tối đa 25° (MoveHumming) + lệch ngẫu nhiên
## ±128/Scale độ (Direction *= 0.8), tiến 40 đơn vị ; dừng khi cách mục tiêu <= 2 bước hoặc đủ 50 đuôi.
func _laser_path(from: Vector3, to: Vector3) -> Array:
	var pts: Array = [from]
	var p := from
	var yaw := randf() * 360.0
	var pitch := 0.0
	var dyaw := 0.0
	var dpitch := 0.0
	var step := 0.4
	for j in 50:
		var d := to - p
		if d.length() <= step * 2.0:
			break
		var want_yaw := rad_to_deg(atan2(d.x, d.z))
		var want_pitch := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
		yaw = _turn(yaw, want_yaw, 25.0)
		pitch = _turn(pitch, want_pitch, 25.0)
		dyaw = (dyaw + float(rnd(256) - 128) / 60.0) * 0.8
		dpitch = (dpitch + float(rnd(256) - 128) / 60.0) * 0.8
		var y := deg_to_rad(yaw + dyaw)
		var pt := deg_to_rad(pitch + dpitch)
		p += Vector3(sin(y) * cos(pt), sin(pt), cos(y) * cos(pt)) * step
		pts.append(p)
	pts.append(to)
	return pts

## 18 quả lửa (Skill/Fire01) toả đều 20° quanh Death Gorgon, bay ngang như Fire Ball
func _gorgon_ring() -> void:
	var from := caster_pos() + mu(Vector3(0, 0, 120))
	for i in 18:
		var o := model("Skill/Fire01", from, {"ang": Vector3(0, 0, i * 20.0), "dir": Vector3(0, -50, 0),
			"scale": float(rnd(4) + 8) * 0.1, "life": 20, "blend_mesh": 1})
		o["update"] = func(ob, _dt): ob["light"] = float(rnd(4) + 4) * 0.1 + 0.6
		o["on_end"] = func(ob):
			particle("BITMAP_LIGHT", ob["pos"], {"size": 1.5, "life": 6, "color": Color(1, 0.5, 0.2)})
	if MuAudioManager:
		MuAudioManager.play_sound_file("eMeteorite.wav", 0.0, 1.0, from)
	impact_delay = 0.3

## MODEL_ARROW_BOMB (Skill/ArrowBomb01): quả cầu bom.
## Tạo: vị trí quái + (-10, -60, 135) xoay theo hướng, Direction (0, -30, 0), Gravity -10, LifeTime 40.
## Mỗi tick: 2 sprite BITMAP_LIGHT (1, 0.6, 0.4) cỡ 1 và 2 xoay ngược nhau + bong bóng ; MoveJump: rơi
## (Gravity -= 1 / tick), chạm đất nảy lại 0.4 và chậm lại 0.4 ; LifeTime == 1: CreateBomb (nổ + tia lửa).
func _arrow_bomb(yaw_off: float) -> void:
	var to := target_pos()
	var a := Vector3(0, 0, yaw_to(caster_pos(), to) + yaw_off)
	var p := caster_pos() + rot(Vector3(-10, -60, 135), a)
	var o := model("Skill/ArrowBomb01", p, {"ang": a, "life": 40, "blend_mesh": 0})
	o["fwd"] = rot(Vector3(0, -30, 0), a)   # m / tick
	o["grav"] = -10.0                         # đơn vị MU / tick
	o["update"] = func(ob, dt):
		var pos: Vector3 = ob["pos"]
		pos += (ob["fwd"] as Vector3) * dt
		pos.y += float(ob["grav"]) / 100.0 * dt
		ob["grav"] = float(ob["grav"]) - 1.0 * dt
		var g := ground(pos) + 0.25
		if pos.y < g:
			pos.y = g
			ob["grav"] = -float(ob["grav"]) * 0.4
			ob["fwd"] = (ob["fwd"] as Vector3) * 0.4
		ob["pos"] = pos
		var cur_tick := int(ob["age"])
		if cur_tick != int(ob.get("last_tick", -1)):
			ob["last_tick"] = cur_tick
			var r := Time.get_ticks_msec() * 0.1
			sprite("BITMAP_LIGHT", pos, 1.0, Color(1.0, 0.6, 0.4), r)
			sprite("BITMAP_LIGHT", pos, 2.0, Color(1.0, 0.6, 0.4), -r)
	o["on_end"] = func(ob):
		var q: Vector3 = ob["pos"]
		explosion(q, 2.0)
		for i in 12:
			particle("BITMAP_SPARK", q + Vector3(0, 0.8, 0), {"size": 0.12, "life": 20, "grav": -0.004,
				"vel": Vector3(randf_range(-0.08, 0.08), randf_range(0.03, 0.12), randf_range(-0.08, 0.08)),
				"color": Color(1, 0.8, 0.5)})
		if MuAudioManager:
			MuAudioManager.play_sound_file("eMonsterBoom1.wav", 0.0, 1.0, q)
	impact_delay = 1.5
