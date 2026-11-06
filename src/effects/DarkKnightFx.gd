extends MuFx
class_name DarkKnightFx

## Hiệu ứng skill Dark Knight port tay từ client gốc.
## Nguồn: Engine/Object/ZzzCharacter.cpp (CreateWeaponBlur, AttackStage Death Stab / Impale, ra đòn),
##        Network/Server/WSclient.cpp (hành động + âm thanh skill kiếm),
##        Render/Effects/Behaviors/MoveHandlers.cpp (Move_MODEL_SKILL_FURY_STRIKE, Move_MODEL_BLOW_OF_DESTRUCTION),
##        Render/Effects/ZzzEffectBlurSpark.cpp (vệt chém), ZzzEffectJoint.cpp (MODEL_SPEARSKILL)
## Twisting Slash (41) nằm riêng trong TwistingSlashEffect.gd.

const FALLING_SLASH := 19
const LUNGE := 20
const UPPERCUT := 21
const CYCLONE := 22
const SLASH := 23
const RAGEFUL_BLOW := 42
const DEATHSTAB := 43
const IMPALE := 47
const SWELL_LIFE := 48
const STRIKE_OF_DESTRUCTION := 232

const SKILLS := [FALLING_SLASH, LUNGE, UPPERCUT, CYCLONE, SLASH, RAGEFUL_BLOW, DEATHSTAB, IMPALE,
	SWELL_LIFE, STRIKE_OF_DESTRUCTION]

var _front := Vector3.ZERO     # StartPosition của Rageful Blow / Strike of Destruction
var _spirits: Array = []

func _start() -> void:
	match skill_num:
		FALLING_SLASH, LUNGE, UPPERCUT, CYCLONE, SLASH:
			# CreateWeaponBlur: PLAYER_ATTACK_SKILL_SWORD1..5 -> BlurType 1, BlurMapping 2 (motion_blur_r)
			weapon_blur(3, 14)
			_min_ticks = 16
			impact_delay = 0.3
		RAGEFUL_BLOW:
			weapon_blur(2, 9)
			_min_ticks = 12
			impact_delay = 0.45
		DEATHSTAB:
			_min_ticks = 14
			impact_delay = 0.45
		IMPALE:
			_min_ticks = 16
			impact_delay = 0.55
		SWELL_LIFE:
			_swell_life()
		STRIKE_OF_DESTRUCTION:
			weapon_blur(2, 8)
			_min_ticks = 24
			impact_delay = 0.7

func _mu_tick(t: int) -> void:
	match skill_num:
		RAGEFUL_BLOW: _rageful_tick(t)
		DEATHSTAB: _deathstab_tick(t)
		IMPALE: _impale_tick(t)
		SWELL_LIFE: _swell_tick(t)
		STRIKE_OF_DESTRUCTION: _strike_tick(t)

# ------------------------------------------------------------------ vũ khí

func weapon_node() -> Node3D:
	var m = caster.get("model") if is_instance_valid(caster) else null
	if m == null:
		return null
	var nodes: Dictionary = m.get("_weapon_nodes") if m.get("_weapon_nodes") != null else {}
	var d: Dictionary = nodes.get("right", nodes.get("left", {}))
	var n = d.get("node")
	return n if is_instance_valid(n) else null

## Điểm trên vũ khí theo toạ độ MU của xương tay (Vector(0,-20,0) chuôi, Vector(0,-120,0) mũi)
func weapon_point(v: Vector3) -> Vector3:
	var w := weapon_node()
	if w == null:
		return caster_pos() + Vector3(0, 1.2, 0) + rot(v, Vector3(0, 0, caster_yaw()))
	return w.global_transform * mu(v)

## Vệt chém CreateBlur(p (0,-20,0), p2 (0,-120,0), Light 1, BlurMapping 2) từ tick a tới tick b
func weapon_blur(a: float, b: float) -> void:
	if weapon_node() == null:
		return
	blur("BITMAP_BLUR+2", func(): return [weapon_point(Vector3(0, -20, 0)), weapon_point(Vector3(0, -120, 0))],
		a, b, Color(1, 1, 1), 16)

# ------------------------------------------------------------------ dùng chung

func stones(pos: Vector3, n: int, up := 1.0) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.02, 0.08)
		var o := model("Skill/Stone0%d" % (1 + rnd(2)), pos + Vector3(0, 0.1, 0), {
			"blend_mesh": -1, "scale": randf_range(0.5, 1.0), "life": 30 + rnd(10),
			"ang": Vector3(rnd(360), rnd(360), rnd(360))})
		o["vel"] = Vector3(sin(a) * sp, randf_range(0.08, 0.2) * up, cos(a) * sp)
		o["spin"] = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
		o["update"] = func(ob, dt):
			var v: Vector3 = ob["vel"]
			v.y -= 0.03 * dt
			var p: Vector3 = ob["pos"] + v * dt
			if p.y < ground(p):
				p.y = ground(p)
				v = Vector3(v.x * 0.5, -v.y * 0.3, v.z * 0.5)
			ob["vel"] = v
			ob["pos"] = p
			ob["ang"] = (ob["ang"] as Vector3) + (ob["spin"] as Vector3) * dt

## BITMAP_JOINT_SPARK SubType 0: tia lửa vệt (Scale 2, Velocity 6..25, LifeTime 8..15)
func joint_sparks(pos: Vector3, base_ang: Vector3, n: int) -> void:
	for j in n:
		var a := base_ang + Vector3(float(rnd(60) - 60), 0, float(rnd(30) + 90))
		var p := pos + mu(Vector3(rnd(20) - 10, rnd(20) - 10, 0))
		var dir := rot(Vector3(0, -1, 0), a) * 100.0
		var r := ribbon("BITMAP_JOINT_SPARK", p, {"width": 0.04, "max_tails": 2, "life": rnd(8) + 8, "fade": false})
		_spirits.append({"r": r, "pos": p, "vel": dir.normalized() * float(rnd(20) + 6) / 100.0})

func _move_free_joints() -> void:
	for s in _spirits:
		if not _ribbons.has(s["r"]) or not s.has("vel"):
			continue
		s["pos"] = (s["pos"] as Vector3) + (s["vel"] as Vector3)
		(s["r"] as Dictionary)["head"] = s["pos"]
		ribbon_push(s["r"])

# ------------------------------------------------------------------ 42 Rageful Blow
## MODEL_SKILL_FURY_STRIKE (LifeTime 20): tick 9 (LifeTime 11): StartPosition = trước mặt (-25,-80,0) trên đất,
## BITMAP_EXPLOTION Scale 0.5, 8 tia lửa, MODEL_WAVE (flashing), EarthQuake03/01/02 (Scale 1.5),
## 5 x EarthQuake04+05 vòng bán kính 100..250 (Scale 0.4..0.9) ;
## tick 10 (LifeTime 10): 4 lượt x 5 nhánh nứt EarthQuake07+08 (Scale 1) toả ra theo đường gấp khúc
func _rageful_tick(t: int) -> void:
	_move_free_joints()
	var yaw := caster_yaw()
	if t == 9:
		_front = caster_pos() + rot(Vector3(-25, -80, 0), Vector3(0, 0, yaw))
		_front.y = ground(_front) + 0.25
		particle("BITMAP_EXPLOTION", _front, {"size": 256.0 * 0.5 / 100.0, "life": 16, "sheet": Vector2i(4, 4), "fade": false})
		joint_sparks(_front, Vector3(0, 0, yaw), 8)
		var w := model("Skill/flashing", _front, {"scale": 0.5, "life": 20, "blend_mesh": -2})
		w["update"] = func(ob, dt):
			ob["scale"] = float(ob["scale"]) + (1.2 if float(ob["scale"]) <= 2.0 else 0.1) * dt
			ob["light"] = float(ob["life"]) / 30.0
		var c := _front - Vector3(0, 0.27, 0)
		for k in [3, 1, 2]:
			_quake(k, c, Vector3.ZERO, 1.5, 35)
		var sub := rnd(100)
		for i in 5:
			var p := c + rot(Vector3(0, rnd(150) + 100, 0), Vector3(0, 0, sub + i * 72.0))
			p.y = ground(p) + 0.03
			var sc := float(rnd(50) + 40) / 100.0
			var a := Vector3(0, 0, 45.0 + rnd(30) - 15)
			_quake(4, p, a, sc, 35)
			_quake(5, p, a, sc, 35)
	elif t == 10:
		var pos: Array = []
		var ang: Array = []
		for j in 5:
			pos.append(_front)
			ang.append(0.0)
		var count := 0
		for j in 4:
			var step := Vector3(0, rnd(15) + 85.0, 0)
			if j >= 3:
				count = randi()
			for i in 5:
				var rr := (rnd(30) + 50) if count % 2 == 0 else -(rnd(30) + 50)
				ang[i] = float(ang[i]) + rr
				var a := Vector3(0, 0, float(ang[i]) + i * (rnd(10) + 62))
				var p: Vector3 = pos[i] + rot(step, a)
				p.y = ground(p) + 0.03
				pos[i] = p
				a.z += 270.0
				_quake(7, p, a, 1.0, 40)
				_quake(8, p, a, 1.0, 40)
			count += 1

## MODEL_SKILL_FURY_STRIKE + k = Skill/EarthQuake0k (BlendMesh 0), tắt dần cuối đời
func _quake(k: int, pos: Vector3, a: Vector3, scale: float, life: float) -> void:
	var o := model("Skill/EarthQuake0%d" % k, pos, {"ang": a, "scale": scale, "life": life, "blend_mesh": 0})
	o["update"] = func(ob, _dt): ob["light"] = minf(1.0, float(ob["life"]) / 10.0)

# ------------------------------------------------------------------ 43 Death Stab
## tick 2..8: 3 tia MODEL_SPEARSKILL SubType 2 (texture BITMAP_FLARE_FORCE, đỏ (1,.3,.3), MaxTails 5, LifeTime 20,
##            Scale = LifeTime*3) từ điểm xa 14 m phía trước (±3 m) hội tụ về mũi kiếm (+3 m phía trước) ;
## tick 6..12: "cái nón" MODEL_SPEAR SubType 1 tại vũ khí + (100 + (t-8)*10) phía trước ;
## mục tiêu bị giật điện (m_byHurtByDeathstab) 35 tick
func _deathstab_tick(t: int) -> void:
	var yaw := caster_yaw()
	var a := Vector3(0, 0, yaw)
	var sword := weapon_point(Vector3.ZERO) + rot(Vector3(0, -300, 0), a)
	if t >= 2 and t <= 8:
		for j in 3:
			var far := caster_pos() + mu(Vector3(0, 0, 120)) + rot(Vector3(0, -1400, 0), a)
			far += Vector3(randf_range(-3, 3), randf_range(-1.5, 1.5), randf_range(-3, 3))
			var r := ribbon("BITMAP_FLARE_FORCE", far, {"width": 0.6, "max_tails": 5, "life": 20,
				"color": Color(1.0, 0.3, 0.3), "fade": false})
			_spirits.append({"r": r, "from": far, "to": sword, "age": 0.0})
	for s in _spirits:
		if not _ribbons.has(s["r"]) or not s.has("from"):
			continue
		s["age"] = float(s["age"]) + 1.0
		var life := 20.0 - float(s["age"])
		var k1 := clampf((life - 10.0) / 10.0, 0.0, 1.0)
		var screw := Vector3(sin(float(s["age"]) * 0.7), cos(float(s["age"]) * 0.5), cos(float(s["age"]) * 0.7)) * 0.6
		var p: Vector3 = (s["to"] as Vector3).lerp((s["from"] as Vector3) + screw, k1)
		var r: Dictionary = s["r"]
		r["head"] = p
		r["width"] = maxf(0.05, life * 3.0 / 100.0)
		ribbon_push(r)
	if t >= 6 and t <= 12:
		var p := weapon_point(Vector3.ZERO) + rot(Vector3(0, -(100.0 + (t - 8) * 10.0), 0), a)
		for k in 2:
			particle("BITMAP_FLARE_FORCE", p, {"size": randf_range(0.8, 1.3), "life": 8, "color": Color(1.0, 0.5, 0.4),
				"rot": rnd(360)})
		sprite("BITMAP_SHINY+1", p, 2.0, Color(1, 0.8, 0.8), rnd(360))
	if t >= 10 and t <= 13 and is_instance_valid(target):
		var c := target.global_position + Vector3(0, 1.0, 0)
		for k in 2:
			var q := c + Vector3(randf_range(-0.5, 0.5), randf_range(-0.8, 0.8), randf_range(-0.5, 0.5))
			bolt("BITMAP_JOINT_THUNDER", c, q, 0.2, Color(0.6, 0.6, 1.0), 3, 0.15, 0.2)

# ------------------------------------------------------------------ 47 Impale
## tick 4: MODEL__SPEAR tại vũ khí (3 tia BITMAP_JOINT_HEALING hội tụ) ; tick 8: 2 x MODEL_SPEAR trước mặt 50, cao 110 ;
## tick 13..14: 3 x MODEL_SPEARSKILL (RidingSpear01, Scale 1.5, LifeTime 20, Light .3, Direction 5 tới trước)
##              tại 145 phía trước, cao 110, lệch ngẫu nhiên ±30
func _impale_tick(t: int) -> void:
	var a := Vector3(0, 0, caster_yaw())
	if t == 4:
		var w := weapon_point(Vector3.ZERO)
		for j in 3:
			var from := w - rot(Vector3(0, -100, 0), Vector3(rnd(90), 0, rnd(360)))
			bolt("BITMAP_JOINT_HEALING", from, w, 0.05, Color(1, 1, 0.5), 6, 0.0, 0.5)
		particle("BITMAP_LIGHT", w, {"size": 1.0, "life": 8, "color": Color(1, 1, 0.5)})
	if t == 8:
		var p := caster_pos() + rot(Vector3(0, -50, 110), a)
		particle("BITMAP_FLARE+1", p, {"size": 1.6, "life": 10, "color": Color(1, 1, 1)})
		sprite("BITMAP_SHINY+1", p, 2.5, Color(1, 1, 1), rnd(360))
	if t == 13 or t == 14:
		for i in 3:
			var p := caster_pos() + rot(Vector3(0, -145, 110), a)
			p += mu(Vector3(rnd(60) - 30, rnd(60) - 30, rnd(60) - 30))
			var o := model("Skill/RidingSpear01", p, {"ang": a, "scale": 1.5, "life": 20, "blend_mesh": -2,
				"light": 0.3, "dir": Vector3(0, -5, 0)})
			o["update"] = func(ob, _dt): ob["light"] = 0.3 * minf(1.0, float(ob["life"]) / 6.0) * 3.0

# ------------------------------------------------------------------ 48 Swell Life
## 36 tia BITMAP_JOINT_SPIRIT SubType 2 (Velocity 50, LifeTime 20, MaxTails 3, Light .5, ALPHA_BLEND) toả tròn
## ngẩng -10 từ cao 100 ; 2 vòng phép BITMAP_MAGIC+1 SubType 4 dưới chân
func _swell_life() -> void:
	var c := caster_pos() + mu(Vector3(0, 0, 100))
	for i in 36:
		var r := ribbon("BITMAP_JOINT_SPIRIT", c, {"width": 0.6, "max_tails": 3, "life": 20,
			"color": Color(0.5, 0.5, 0.5)})
		_spirits.append({"r": r, "pos": c, "ang": Vector3(-10, 0, i * 10.0)})
	var g := caster_pos() + Vector3(0, 0.05, 0)
	var m := particle("BITMAP_MAGIC+1", g, {"size": 3.0, "life": 30, "color": Color(1.0, 0.8, 0.4), "rspeed": 3})
	if not m.is_empty():
		m["flat"] = true
	_min_ticks = 30
	impact_delay = 0.2

func _swell_tick(_t: int) -> void:
	for s in _spirits:
		if not _ribbons.has(s["r"]) or not s.has("ang"):
			continue
		s["pos"] = (s["pos"] as Vector3) + rot(Vector3(0, -50, 0), s["ang"])
		var r: Dictionary = s["r"]
		r["head"] = s["pos"]
		ribbon_push(r)

# ------------------------------------------------------------------ 232 Strike of Destruction
## MODEL_BLOW_OF_DESTRUCTION SubType 0 trước mặt (-20,-100,0) và SubType 1 tại ô mục tiêu ;
## LifeTime 23 (tick 17): nightwater01 x2 (xanh (0.3,0.3,1)), knight_plancrack_a (Scale 1.2) ;
## vết nứt knight_plancrack_b mỗi 55 đơn vị trên đường tới mục tiêu (xoay ±10..30) ;
## tại mục tiêu: tick 16..25 15 hạt nước BITMAP_WATERFALL_3/5 xanh + khói, đá văng
func _strike_tick(t: int) -> void:
	var a := Vector3(0, 0, caster_yaw())
	var from := caster_pos() + rot(Vector3(-20, -100, 0), a)
	from.y = ground(from)
	var to := target_pos()
	to.y = ground(to)
	if t >= 16 and t <= 25:
		for i in 6:
			var p := to + Vector3(0, 1.5, 0) + mu(Vector3(rnd(300) - 150, rnd(300) - 150, rnd(300) - 150))
			var tex := "BITMAP_WATERFALL_5" if rnd(2) == 0 else "BITMAP_WATERFALL_3"
			particle(tex, p, {"size": 1.6 + rnd(10) * 0.1, "life": 15, "color": Color(0.5, 0.5, 1.0),
				"vel": Vector3(0, -0.02, 0)})
			if rnd(2) == 0:
				smoke_at(p)
	if t == 17:
		var blue := Color(0.3, 0.3, 1.0)
		for sc in [1.0, 1.0]:
			_water(from, a, sc, blue)
		var ca := model("Effect/knight_plancrack_a", from, {"ang": a, "scale": 1.2, "life": 40, "blend_mesh": -2, "color": blue})
		ca["update"] = _crack_fade
		var d := to - from
		d.y = 0
		var n := int(d.length() * 100.0 / 100.0) + 1
		for i in n:
			var p := from + d.normalized() * 0.55 * i
			p.y = ground(p)
			var ang := a + Vector3(0, 0, (rnd(20) + 10) * (1 if i % 2 == 0 else -1))
			var cb := model("Effect/knight_plancrack_b", p, {"ang": ang, "scale": 1.0, "life": 40, "blend_mesh": -2, "color": blue})
			cb["update"] = _crack_fade
		for sc in [2.0, 1.0]:
			_water(to, a, sc, blue)
		for i in 5 + rnd(3):
			var q := to + rot(Vector3(0, rnd(150), 0), Vector3(0, 0, rnd(360)))
			stones(q, 1, 1.2)

func _water(p: Vector3, a: Vector3, sc: float, c: Color) -> void:
	var o := model("Effect/nightwater01", p, {"ang": a, "scale": sc, "life": 30, "blend_mesh": -2, "color": c})
	o["update"] = func(ob, _dt): ob["light"] = minf(1.5, float(ob["life"]) / 10.0)

## vết nứt knight_plancrack (jpg nền đen, vẽ cộng sáng theo Light (0.3,0.3,1)): tắt dần 10 tick cuối
func _crack_fade(o: Dictionary, _dt: float) -> void:
	o["light"] = minf(1.0, float(o["life"]) / 10.0)

func smoke_at(p: Vector3) -> void:
	particle("BITMAP_SMOKE", p, {"size": 0.9, "grow": 1.03, "life": 20, "color": Color(0.7, 0.7, 0.8),
		"vel": Vector3(0, 0.02, 0)})
