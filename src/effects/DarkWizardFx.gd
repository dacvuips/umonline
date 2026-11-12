extends MuFx
class_name DarkWizardFx

## Hiệu ứng skill Dark Wizard port tay từ client gốc.
## Nguồn: Engine/Object/ZzzCharacter.cpp (lúc ra đòn), Render/Effects/ZzzEffect.cpp (CreateEffect / MoveEffect),
##        Render/Effects/Behaviors/MoveHandlers.cpp, Render/Effects/ZzzEffectJoint.cpp
## Số skill = AT_SKILL_* (skill nâng cấp dùng skill gốc qua "base" trong skill_fx.json).

const POISON := 1
const METEO := 2
const LIGHTNING := 3
const FIREBALL := 4
const FLAME := 5
const ICE := 7
const STORM := 8
const EVIL_SPIRIT := 9
const HELL_FIRE := 10
const POWERWAVE := 11
const FLASH := 12
const BLAST := 13
const INFERNO := 14
const ENERGYBALL := 17
const DECAY := 38
const ICE_STORM := 39
const NOVA := 40
const FLAME_OF_EVIL := 50
const MONSTER_SKILL := 150
const DEVIL_FIRE_BEAM := 151

const SKILLS := [POISON, METEO, LIGHTNING, FIREBALL, FLAME, ICE, STORM, EVIL_SPIRIT, HELL_FIRE,
	POWERWAVE, FLASH, BLAST, INFERNO, ENERGYBALL, DECAY, ICE_STORM, NOVA, FLAME_OF_EVIL, MONSTER_SKILL, DEVIL_FIRE_BEAM]

var _spirits: Array = []
var _hand := Vector3.ZERO

func _start() -> void:
	match skill_num:
		POISON: _poison()
		METEO: _meteo()
		LIGHTNING: _min_ticks = 8; impact_delay = 0.1
		FIREBALL: _fireball()
		FLAME: _flame_start()
		ICE: _ice()
		STORM: _storm()
		EVIL_SPIRIT: _evil_spirit()
		HELL_FIRE: _hell_fire()
		POWERWAVE: _power_wave()
		FLASH: _flash()
		BLAST: _blast()
		INFERNO: _inferno()
		ENERGYBALL: _energy_ball()
		DECAY: _decay()
		ICE_STORM: _ice_storm()
		NOVA: _nova_start()
		FLAME_OF_EVIL: _flame_of_evil()
		MONSTER_SKILL: _monster_skill()
		DEVIL_FIRE_BEAM: _devil_fire_beam()

func _mu_tick(t: int) -> void:
	match skill_num:
		LIGHTNING: _lightning_tick(t)
		FLAME: _flame_tick(t)
		EVIL_SPIRIT: _evil_spirit_tick(t)
		NOVA: _nova_tick(t)
		STORM: _storm_tick(t)
		DEVIL_FIRE_BEAM: _devil_fire_tick(t)

# ------------------------------------------------------------------ dùng chung

## MODEL_STONE1/2: mảnh đá văng (SubType 0) — bay lên, rơi xuống, nảy trên đất
func stones(pos: Vector3, n: int, up := 1.0) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.02, 0.08)
		var o := model("Skill/Stone0%d" % (1 + rnd(2)), pos + Vector3(0, 0.1, 0), {
			"blend_mesh": -1, "scale": randf_range(0.5, 1.0), "life": 30 + rnd(10),
			"ang": Vector3(rnd(360), rnd(360), rnd(360))})
		o["vel"] = Vector3(sin(a) * sp, randf_range(0.08, 0.2) * up, cos(a) * sp)
		o["spin"] = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
		o["update"] = _stone_update

func _stone_update(o: Dictionary, dt: float) -> void:
	var v: Vector3 = o["vel"]
	v.y -= 0.03 * dt
	var p: Vector3 = o["pos"] + v * dt
	var g := ground(p)
	if p.y < g:
		p.y = g
		v = Vector3(v.x * 0.5, -v.y * 0.3, v.z * 0.5)
	o["vel"] = v
	o["pos"] = p
	o["ang"] = (o["ang"] as Vector3) + (o["spin"] as Vector3) * dt

## BITMAP_EXPLOTION: nổ (texture 4x4 khung)
func explosion(pos: Vector3, size := 2.5, color := Color(1, 1, 1)) -> void:
	particle("BITMAP_EXPLOTION", pos + Vector3(0, 0.8, 0), {"size": size, "life": 16, "sheet": Vector2i(4, 4),
		"fade": false, "color": color})

## BITMAP_SMOKE: khói bốc lên
func smoke(pos: Vector3, color := Color(0.6, 0.6, 0.6), size := 0.8, life := 30.0) -> void:
	particle("BITMAP_SMOKE", pos, {"size": size, "grow": 1.03, "life": life, "color": color,
		"vel": Vector3(randf_range(-0.01, 0.01), randf_range(0.01, 0.03), randf_range(-0.01, 0.01)),
		"rspeed": randf_range(-4, 4)})

## Vị trí tay phải (xương b033) của người dùng — gốc tia sét
func hand_pos() -> Vector3:
	var m = caster.get("model") if is_instance_valid(caster) else null
	if m != null and m.get("skeleton") != null:
		var sk := m.skeleton as Skeleton3D
		var b := sk.find_bone("b%03d" % MuCharModelRes.BONE_RIGHT_HAND)
		if b >= 0:
			return sk.global_transform * sk.get_bone_global_pose(b).origin
	return caster_pos() + Vector3(0, 1.3, 0)

# ------------------------------------------------------------------ 1 Poison
## ZzzCharacter: CreateEffect(MODEL_POISON, to) + 10 x CreateParticle(BITMAP_SMOKE, Light (0.4,0.6,1), 1)
## Move_MODEL_POISON: BlendMeshLight = Alpha = LifeTime * 0.1
func _poison() -> void:
	var p := target_pos()
	var o := model("Skill/Poison01", p, {"life": 20, "ang": Vector3(0, 0, caster_yaw())})
	o["update"] = func(ob, _dt): ob["light"] = minf(1.0, float(ob["life"]) * 0.1)
	for i in 10:
		smoke(p + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.2), randf_range(-0.3, 0.3)), Color(0.4, 0.6, 1.0), 1.0, 30)
	impact_delay = 0.2

# ------------------------------------------------------------------ 2 Meteorite
## MODEL_FIRE SubType 0: rơi từ (+130..162, 0, +400), Direction (0,0,-50) xoay Angle (0,20,0),
## Scale 1..1.7, BlendMesh 1 (lửa cộng sáng), chạm đất: BITMAP_EXPLOTION + 6 đá
func _meteo() -> void:
	var p := target_pos() + mu(Vector3(130 + rnd(32), 0, 400))
	var o := model("Skill/Fire01", p, {"ang": Vector3(0, 20, 0), "dir": Vector3(0, 0, -50),
		"scale": float(rnd(8) + 10) * 0.1, "life": 40, "blend_mesh": 1})
	o["update"] = _fall_update
	o["on_end"] = func(ob):
		explosion(ob["pos"])
		stones(ob["pos"], 6)
	impact_delay = 0.33

func _fall_update(o: Dictionary, _dt: float) -> void:
	o["light"] = float(rnd(4) + 4) * 0.1 + 0.6
	var q: Vector3 = o["pos"]
	if q.y < ground(q):
		q.y = ground(q)
		o["pos"] = q
		o["dead"] = true

# ------------------------------------------------------------------ 4 Fire Ball
## MODEL_FIRE SubType 1: cao +120, Direction (0,-50,0) theo hướng tới mục tiêu, LifeTime 60,
## Scale 0.8..1.1 ; hết đời / trúng: 2 đá (EffectDestructor)
func _fireball() -> void:
	var from := caster_pos() + mu(Vector3(0, 0, 120))
	var to := target_pos() + Vector3(0, 1.2, 0)
	var o := model("Skill/Fire01", from, {"ang": Vector3(0, 0, yaw_to(from, to)), "dir": Vector3(0, -50, 0),
		"scale": float(rnd(4) + 8) * 0.1, "life": 60, "blend_mesh": 1})
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	o["life"] = minf(60.0, dist / 0.5)
	o["update"] = func(ob, _dt): ob["light"] = float(rnd(4) + 4) * 0.1 + 0.6
	o["on_end"] = func(ob):
		stones(ob["pos"], 2)
		particle("BITMAP_LIGHT", ob["pos"], {"size": 1.5, "life": 6, "color": Color(1, 0.5, 0.2)})
	impact_delay = dist / 12.5

# ------------------------------------------------------------------ 5 Flame
## BITMAP_FLAME SubType 0 (LifeTime 40) tại ô mục tiêu: mỗi tick 6 ngọn lửa (BITMAP_FLAME) trong ±25,
## đá văng (MODEL_STONE)
var _flame_pos := Vector3.ZERO
func _flame_start() -> void:
	_flame_pos = target_pos()
	_flame_pos.y = ground(_flame_pos)
	_min_ticks = 40
	impact_delay = 0.2

func _flame_tick(t: int) -> void:
	if t >= 40:
		return
	for j in 6:
		var p := _flame_pos + mu(Vector3(rnd(50) - 25, rnd(50) - 25, 0))
		particle("BITMAP_FLAME", p + Vector3(0, 0.2, 0), {"size": randf_range(0.6, 0.9), "grow": 0.96,
			"life": 12 + rnd(6), "vel": Vector3(0, randf_range(0.03, 0.06), 0), "rot": 0})
	if t % 6 == 0:
		stones(_flame_pos, 1, 0.6)

# ------------------------------------------------------------------ 7 Ice
## MODEL_ICE (Scale 0.8, LifeTime 50, BlendMesh 0) + 5 x MODEL_ICE_SMALL (văng ra, Gravity 8..23, giảm dần)
func _ice() -> void:
	var p := target_pos()
	var o := model("Skill/Ice01", p, {"scale": 0.8, "life": 50, "blend_mesh": 0, "ang": Vector3(0, 0, caster_yaw())})
	o["update"] = func(ob, _dt):
		if rnd(2) == 0 and float(ob["age"]) > 5:
			smoke(ob["pos"] + mu(Vector3(rnd(64) - 32, rnd(64) - 32, rnd(128) + 32)), Color(0.7, 0.8, 1.0), 0.7, 20)
		ob["light"] = minf(1.0, float(ob["life"]) * 0.1)
	for i in 5:
		var s := model("Skill/Ice02", p + mu(Vector3(0, 0, 50)), {"scale": float(rnd(4) + 8) * 0.1,
			"life": rnd(16) + 32, "blend_mesh": 0, "light": 0.3, "ang": Vector3(0, 0, rnd(360))})
		var v := rot(Vector3(0, float(rnd(256) + 64) * 0.1, 0), Vector3(0, 0, rnd(360)))
		v.y = float(rnd(16) + 8) / 100.0
		s["vel"] = v
		s["spin"] = Vector3(rnd(20) - 10, rnd(20) - 10, 0)
		s["update"] = _stone_update
	impact_delay = 0.2

# ------------------------------------------------------------------ 8 Twister
## MODEL_STORM SubType 0: LifeTime 59, Direction (0,-10,0) (trôi tới trước), bám mặt đất,
## BlendMeshLight = LifeTime*0.1, cuộn UV ; mỗi tick khói, 50% tia sét từ (±200, 0, 700) xuống lốc
func _storm() -> void:
	var p := caster_pos()
	var o := model("Skill/Storm01", p, {"ang": Vector3(0, 0, caster_yaw()), "dir": Vector3(0, -10, 0),
		"life": 59, "blend_mesh": 0})
	o["update"] = func(ob, _dt):
		var q: Vector3 = ob["pos"]
		q.y = ground(q)
		ob["pos"] = q
		ob["light"] = minf(1.0, float(ob["life"]) * 0.1)
		ob["uv"] = -float(ob["life"]) * 0.1
	o["tick"] = 0
	_storm_obj = o
	_min_ticks = 59
	impact_delay = 0.5

var _storm_obj: Dictionary = {}
func _storm_tick(_t: int) -> void:
	if _storm_obj.is_empty() or not _objs.has(_storm_obj):
		return
	var p: Vector3 = _storm_obj["pos"]
	smoke(p + Vector3(0, 0.3, 0), Color(0.5, 0.5, 0.5), 1.0, 25)
	for sx in [-200, 200]:
		if rnd(2) == 0:
			bolt("BITMAP_JOINT_THUNDER", p + mu(Vector3(sx, 0, 700)), p, 0.1, Color(1, 1, 1), 2, 0.25)
	if rnd(4) == 0:
		stones(p, 1, 0.8)

# ------------------------------------------------------------------ 9 Evil Spirit
## 4 hướng (0/90/180/270) x 2 tia BITMAP_JOINT_SPIRIT SubType 0 (Scale 80 và 20), Velocity 70, LifeTime 49,
## MaxTails 6, vẽ ALPHA_BLEND_MINUS ; MoveHumming về chính người dùng (+80) quay 10°/tick + lắc ngẫu nhiên,
## giữ độ cao 100..400 trên mặt đất ; tia Scale 80 để lại MODEL_LASER mỗi tick
func _evil_spirit() -> void:
	var p := caster_pos() + mu(Vector3(0, 0, 100))
	for i in 4:
		for sc in [80.0, 20.0]:
			var r := ribbon("BITMAP_JOINT_SPIRIT", p, {"width": sc / 100.0, "max_tails": 6, "life": 49,
				"blend": "sub", "color": Color(0.35, 0.35, 0.3) if sc == 80.0 else Color(0.5, 0.5, 0.45), "fade": false})
			_spirits.append({"r": r, "pos": p, "ang": Vector3(0, 0, i * 90.0), "d0": 0.0, "d2": 0.0, "scale": sc})
	_min_ticks = 49
	impact_delay = 0.4

func _evil_spirit_tick(_t: int) -> void:
	var home := caster_pos() + mu(Vector3(0, 0, 80))
	for s in _spirits:
		if not _ribbons.has(s["r"]):
			continue
		var pos: Vector3 = s["pos"]
		var ang: Vector3 = s["ang"]
		# MoveHumming(Position, Angle, TargetPosition, 10)
		ang.z = _turn(ang.z, yaw_to(pos, home), 10.0)
		var horiz := Vector2(home.x - pos.x, home.z - pos.z).length()
		ang.x = _turn(ang.x, -rad_to_deg(atan2(home.y - pos.y, horiz)), 10.0)
		s["d0"] = float(s["d0"]) + float(rnd(32) - 16) * 0.2
		s["d2"] = float(s["d2"]) + float(rnd(32) - 16) * 0.8
		ang.x += float(s["d0"])
		ang.z += float(s["d2"])
		s["d0"] = float(s["d0"]) * 0.6
		s["d2"] = float(s["d2"]) * 0.8
		var g := ground(pos)
		if pos.y < g + 1.0:
			s["d0"] = 0.0
			ang.x = -5.0
		if pos.y > g + 4.0:
			s["d0"] = 0.0
			ang.x = 5.0
		pos += rot(Vector3(0, -70, 0), ang)
		s["pos"] = pos
		s["ang"] = ang
		var r: Dictionary = s["r"]
		r["head"] = pos
		ribbon_push(r)
		if float(s["scale"]) == 80.0:
			var l := model("Skill/Laser01", pos, {"ang": ang, "life": 4, "blend_mesh": -2, "light": 0.8})
			l["update"] = func(ob, _dt): ob["light"] = float(ob["life"]) * 0.2

## TurnAngle2: quay a về phía b tối đa `turn` độ
static func _turn(a: float, b: float, turn: float) -> float:
	var d := wrapf(b - a, -180.0, 180.0)
	return a + clampf(d, -turn, turn)

# ------------------------------------------------------------------ 10 Hellfire
## MODEL_CIRCLE (LifeTime 45, BlendMesh 0, BlendMeshLight = LifeTime*0.1) +
## MODEL_CIRCLE_LIGHT (sáng dần 10 tick rồi tắt dần, cuộn UV, đá văng trong bán kính 300)
func _hell_fire() -> void:
	var p := caster_pos()
	var a := Vector3(0, 0, caster_yaw())
	var c := model("Skill/Circle01", p, {"ang": a, "life": 45, "blend_mesh": 0})
	c["update"] = func(ob, _dt): ob["light"] = minf(1.0, float(ob["life"]) * 0.1)
	var l := model("Skill/Circle02", p, {"ang": a, "life": 40, "blend_mesh": -2, "light": 0.0})
	l["update"] = func(ob, _dt):
		var lt := float(ob["life"])
		ob["light"] = (40.0 - lt) * 0.1 if lt >= 30.0 else lt * 0.1
		ob["uv"] = -lt * 0.01
		if rnd(4) == 0:
			var q := p + rot(Vector3(0, rnd(300), 0), Vector3(0, 0, rnd(360)))
			stones(q, 1, 0.7)
	impact_delay = 0.3

# ------------------------------------------------------------------ 11 Power Wave
## MODEL_MAGIC2: LifeTime 20, Direction (0,-60,0) bay thẳng, BlendMeshLight = LifeTime*0.1,
## TexCoordU = -LifeTime*0.2 ; mỗi tick 4 khói BITMAP_SMOKE SubType 3
func _power_wave() -> void:
	var from := caster_pos()
	var to := target_pos()
	var o := model("Skill/Magic02", from, {"ang": Vector3(0, 0, yaw_to(from, to)), "dir": Vector3(0, -60, 0),
		"life": 20, "blend_mesh": 0})
	o["update"] = func(ob, _dt):
		ob["light"] = minf(1.5, float(ob["life"]) * 0.1)
		ob["uv"] = -float(ob["life"]) * 0.2
		if rnd(2) == 0:
			smoke(ob["pos"] + Vector3(0, 0.3, 0), Color(0.4, 0.4, 0.5), 0.6, 15)
	impact_delay = from.distance_to(to) / 15.0

# ------------------------------------------------------------------ 12 Aqua Beam (Flash)
## BITMAP_BOSS_LASER: CalcAddPosition(-20,-90,100) ; 20 sprite BITMAP_SPARK+1 Scale 16 cách nhau 50
## theo hướng nhìn, Light (0.5, 0.7, 1), LifeTime 20
func _flash() -> void:
	var a := Vector3(0, 0, caster_yaw())
	var start := caster_pos() + rot(Vector3(-20, -90, 100), a)
	var step := rot(Vector3(0, -50, 0), a)
	for j in 20:
		var p := start + step * j
		particle("BITMAP_SPARK+1", p, {"size": 32.0 * 16.0 / 100.0 * 0.6, "life": 20,
			"color": Color(0.5, 0.7, 1.0) * 0.6, "rot": rnd(360)})
	impact_delay = 0.2

# ------------------------------------------------------------------ 13 Cometfall (Blast)
## 2 x MODEL_SKILL_BLAST: bắt đầu (+200..300, -50..50, +300..800), Direction (0,0,-50..-100) xoay (0,20,0),
## kéo vệt BITMAP_JOINT_ENERGY SubType 5 ; chạm đất: 6 đá, BITMAP_SHINY+4, BITMAP_EXPLOTION
func _blast() -> void:
	var base := target_pos()
	base.y = ground(base)
	for i in 2:
		var p := base + mu(Vector3(rnd(100) + 200, rnd(100) - 50, rnd(500) + 300))
		var o := model("Skill/Blast01", p, {"ang": Vector3(0, 20, 0), "dir": Vector3(0, 0, -50 - rnd(50)),
			"scale": float(rnd(8) + 10) * 0.1, "life": 30, "blend_mesh": 0})
		var r := ribbon("BITMAP_JOINT_ENERGY", p, {"width": 1.0, "max_tails": 12, "life": 40,
			"color": Color(0.5, 0.6, 1.0)})
		o["trail"] = r
		o["update"] = func(ob, _dt):
			var rr: Dictionary = ob["trail"]
			rr["head"] = ob["pos"]
			if fmod(float(ob["age"]), 1.0) < _dt:
				ribbon_push(rr)
			_fall_update(ob, _dt)
		o["on_end"] = func(ob):
			var q: Vector3 = ob["pos"]
			stones(q, 6)
			particle("BITMAP_SHINY+4", q + Vector3(0, 0.8, 0), {"size": 2.0, "grow": 1.08, "life": 12})
			explosion(q)
			(ob["trail"] as Dictionary)["life"] = 8.0
	impact_delay = 0.4

# ------------------------------------------------------------------ 14 Inferno
## CreateInferno: 8 vụ nổ (CreateBomb) vòng bán kính 220 + đá ; MODEL_SKILL_INFERNO (Scale 0.9,
## LifeTime 15, Light 0.8, BlendMesh -2, BlendMeshLight = LifeTime/20)
func _inferno() -> void:
	var p := caster_pos()
	for j in 8:
		var q := p + rot(Vector3(0, -220, 0), Vector3(0, 0, j * 45.0))
		q.y = ground(q)
		explosion(q, 2.2)
		particle("BITMAP_LIGHT", q + Vector3(0, 0.5, 0), {"size": 2.5, "life": 12, "color": Color(1, 0.5, 0.2)})
		stones(q, 2)
	var o := model("Skill/Inferno01", p, {"scale": 0.9, "life": 15, "blend_mesh": -2,
		"color": Color(0.8, 0.8, 0.8), "ang": Vector3(0, 0, caster_yaw())})
	o["update"] = func(ob, _dt): ob["light"] = float(ob["life"]) / 20.0 * 1.5
	impact_delay = 0.3

# ------------------------------------------------------------------ 17 Energy Ball
## BITMAP_ENERGY: quả cầu năng lượng bay tới mục tiêu, mỗi tick BITMAP_ENERGY + BITMAP_SPARK+1 (Scale 4),
## sáng = LifeTime*0.2 ; hết đời: BITMAP_SPARK+1 SubType 1 Scale 6
func _energy_ball() -> void:
	var from := caster_pos() + Vector3(0, 1.2, 0)
	var to := target_pos() + Vector3(0, 1.0, 0)
	var dist := from.distance_to(to)
	var o := model("Skill/Laser01", from, {"life": maxf(4.0, dist / 0.4), "light": 0.0})
	(o["node"] as Node3D).visible = false
	o["to"] = to
	o["from"] = from
	o["dur"] = float(o["life"])
	o["update"] = func(ob, _dt):
		var k := clampf(float(ob["age"]) / float(ob["dur"]), 0.0, 1.0)
		var dst: Vector3 = target.global_position + Vector3(0, 1.0, 0) if is_instance_valid(target) else ob["to"]
		ob["pos"] = (ob["from"] as Vector3).lerp(dst, k)
		var l := minf(1.0, float(ob["life"]) * 0.2)
		sprite("BITMAP_ENERGY", ob["pos"], 1.0, Color(l, l, l), rnd(360))
		sprite("BITMAP_SPARK+1", ob["pos"], 4.0, Color(0.4, 0.6, 1.0) * l)
	o["on_end"] = func(ob):
		for i in 6:
			particle("BITMAP_SPARK+1", ob["pos"], {"size": 32.0 * 6.0 / 100.0 * randf_range(0.3, 0.6), "life": 10,
				"vel": Vector3(randf_range(-0.05, 0.05), randf_range(0, 0.06), randf_range(-0.05, 0.05)),
				"color": Color(0.5, 0.7, 1.0)})
	impact_delay = float(o["life"]) * TICK

# ------------------------------------------------------------------ 38 Decay
## 2 x MODEL_FIRE SubType 6 (mesh ẩn): rơi từ (+200..300, -50..50, +500..800), Direction (0,0,-50..-100),
## mỗi tick sprite BITMAP_LIGHT (0.5,0.5,1) Scale 3 + BITMAP_SHINY+1 Scale 3/4 ; vệt khói ;
## chạm đất: MODEL_SKILL_INFERNO SubType 2 (vòng xanh lớn dần) + 15 khói xanh + 6 đá + nổ
func _decay() -> void:
	var base := target_pos()
	base.y = ground(base)
	for i in 2:
		var p := base + mu(Vector3(rnd(100) + 200, rnd(100) - 50, rnd(300) + 500))
		var o := model("Skill/Fire01", p, {"dir": Vector3(0, 0, -50 - rnd(50)), "life": 40, "light": 0.0,
			"scale": float(rnd(8) + 15) * 0.1})
		(o["node"] as Node3D).visible = false
		var r := ribbon("BITMAP_SMOKE", p, {"width": 1.0, "max_tails": 8, "life": 40, "color": Color(0.3, 0.6, 0.3)})
		o["trail"] = r
		o["update"] = func(ob, dt):
			var q: Vector3 = ob["pos"]
			sprite("BITMAP_LIGHT", q, 3.0, Color(0.5, 0.5, 1.0))
			sprite("BITMAP_SHINY+1", q, 3.0, Color(1, 1, 1), rnd(360))
			sprite("BITMAP_SHINY+1", q, 4.0, Color(0.6, 1.0, 0.4), rnd(360))
			var rr: Dictionary = ob["trail"]
			rr["head"] = q
			if fmod(float(ob["age"]), 1.0) < dt:
				ribbon_push(rr)
			if q.y < ground(q):
				q.y = ground(q)
				ob["pos"] = q
				ob["dead"] = true
		o["on_end"] = func(ob):
			var q: Vector3 = ob["pos"]
			var ring := model("Skill/Inferno01", q, {"scale": 0.3, "life": 12, "blend_mesh": -2,
				"color": Color(0.0, 0.5, 0.0)})
			ring["update"] = func(rb, d2):
				rb["scale"] = float(rb["scale"]) + 0.04 * d2
				rb["light"] = float(rb["life"]) / 12.0 * 2.0
			for k in 15:
				smoke(q + mu(Vector3(rnd(160) - 80, rnd(160) - 100, 50)), Color(0.1, 0.5, 0.1), randf_range(1.2, 1.8), 30)
			stones(q, 6)
			explosion(q, 2.0, Color(0.6, 1.0, 0.5))
			(ob["trail"] as Dictionary)["life"] = 8.0
	impact_delay = 0.5

# ------------------------------------------------------------------ 39 Ice Storm
## 10 x MODEL_BLIZZARD SubType 0: bắt đầu (±150 +100, ±150, +600 + rnd50*i), Gravity -30..-60 tăng dần,
## trôi -x 10/tick, sáng dần ; mỗi tick khói + BITMAP_ENERGY/BITMAP_FIRE+2 + sprite BITMAP_SHINY+1, BITMAP_LIGHT ;
## chạm đất: khói xanh (0.24,0.28,0.8), MODEL_BLIZZARD SubType 1 (mảng băng, tắt dần /1.1)
func _ice_storm() -> void:
	var base := target_pos()
	base.y = ground(base)
	for i in 10:
		var p := base + mu(Vector3(rnd(300) - 150 + 100, rnd(300) - 150, 600 + rnd(50) * i))
		var o := model("Skill/blizzard", p, {"scale": 0.5, "life": rnd(15) + 15 + i, "blend_mesh": -2, "light": 0.0})
		o["grav"] = -20.0 - float(rnd(30) + 10)
		o["start"] = p
		o["update"] = func(ob, dt):
			var st: Vector3 = ob["start"]
			st += mu(Vector3(-10, 0, 0)) * dt
			ob["start"] = st
			var q: Vector3 = ob["pos"]
			q.x = st.x + mu(Vector3(sin(randf() * 10.0) * 10.0, 0, 0)).x
			q.z = st.z
			q.y += float(ob["grav"]) / 100.0 * dt
			ob["grav"] = float(ob["grav"]) - float(rnd(5)) * dt
			ob["pos"] = q
			ob["light"] = minf(1.5, float(ob["light"]) + 0.1 * dt)
			sprite("BITMAP_SHINY+1", q, float(rnd(4) + 4) * 0.2, Color(0.8, 0.9, 1.0), rnd(360))
			sprite("BITMAP_LIGHT", q, 1.0, Color(0.6, 0.7, 1.0))
			if rnd(3) == 0:
				smoke(q, Color(0.5, 0.6, 0.8), 0.8, 15)
			if q.y < ground(q):
				ob["dead"] = true
		o["on_end"] = func(ob):
			var q: Vector3 = ob["pos"]
			q.y = ground(q)
			smoke(q + Vector3(0, 0.5, 0), Color(0.24, 0.28, 0.8), randf_range(1.5, 2.2), 25)
			var g := model("Skill/blizzard", q, {"scale": 0.5, "life": 20, "blend_mesh": -2, "light": 1.0})
			g["update"] = func(gb, d2): gb["light"] = float(gb["light"]) * pow(1.0 / 1.1, d2)
	impact_delay = 0.5

# ------------------------------------------------------------------ 40 Nova
## MODEL_CIRCLE SubType 1 (mesh ẩn, LifeTime 45): lúc đầu mỗi tick 36 tia BITMAP_JOINT_SPIRIT SubType 6
## (Scale 60, Velocity 50, LifeTime 20, MaxTails 5, xanh (0.3,0.3,1)) toả tròn, góc ngẩng -10
var _nova_rays: Array = []
func _nova_start() -> void:
	_min_ticks = 45
	impact_delay = 0.3

func _nova_tick(t: int) -> void:
	var c := caster_pos() + mu(Vector3(0, 0, 100))
	if t < 6 and t % 2 == 0:
		for i in 36:
			var a := Vector3(-10, 0, i * (10.0 + rnd(10)))
			var r := ribbon("BITMAP_JOINT_SPIRIT", c, {"width": 0.6, "max_tails": 5, "life": 20,
				"color": Color(0.3, 0.3, 1.0)})
			_nova_rays.append({"r": r, "pos": c, "ang": a})
	for s in _nova_rays:
		if not _ribbons.has(s["r"]):
			continue
		s["pos"] = (s["pos"] as Vector3) + rot(Vector3(0, -50, 0), s["ang"])
		var r: Dictionary = s["r"]
		r["head"] = s["pos"]
		ribbon_push(r)

# ------------------------------------------------------------------ 3 Lightning
## Người chơi (ZzzCharacter default): mỗi tick từ xương tay cầm vũ khí: 2 BITMAP_JOINT_THUNDER
## (Scale 50 và 10, LifeTime 2) tới mục tiêu + BITMAP_ENERGY tại tay
func _lightning_tick(t: int) -> void:
	if t >= 8:
		return
	var a := hand_pos()
	var b := target_pos() + Vector3(0, 0.9, 0)
	bolt("BITMAP_JOINT_THUNDER", a, b, 0.5, Color(0.6, 0.7, 1.0), 2, 0.35, 0.4)
	bolt("BITMAP_JOINT_THUNDER", a, b, 0.1, Color(1, 1, 1), 2, 0.35, 0.4)
	particle("BITMAP_ENERGY", a, {"size": 0.6, "life": 4, "color": Color(0.6, 0.7, 1.0)})

# ------------------------------------------------------------------ 50 Flame of Evil
func _flame_of_evil() -> void:
	var p := target_pos()
	p.y = ground(p)
	explosion(p, 3.2, Color(1.0, 0.3, 0.8))
	for i in 8:
		particle("BITMAP_FLAME", p + mu(Vector3(rnd(40) - 20, rnd(40) - 20, 0)), {
			"size": randf_range(0.8, 1.3), "grow": 0.95, "life": 16 + rnd(8),
			"vel": Vector3(0, randf_range(0.04, 0.08), 0), "color": Color(0.9, 0.2, 0.7)
		})
	stones(p, 3, 1.0)
	if MuAudioManager:
		MuAudioManager.play_sound_file("sHellFire.wav", 1.0, 1.0, p)
	impact_delay = 0.3

# ------------------------------------------------------------------ 150 Monster Skill (Boss / Elite mob special attack)
func _monster_skill() -> void:
	var from := caster_pos()
	var to := target_pos()
	to.y = ground(to)
	var dist := from.distance_to(to)
	if dist > 2.0:
		bolt("BITMAP_JOINT_THUNDER", from + Vector3(0, 1.2, 0), to + Vector3(0, 1.0, 0), 0.35, Color(1.0, 0.5, 0.2), 3, 0.35, 0.4)
	explosion(to, 4.0, Color(1.0, 0.45, 0.15))
	stones(to, 8, 1.6)
	smoke(to + Vector3(0, 0.4, 0), Color(0.8, 0.4, 0.2), 1.5, 30)
	for i in 6:
		particle("BITMAP_SPARK+1", to + Vector3(0, 0.6, 0), {
			"size": randf_range(0.6, 1.2), "life": 18,
			"vel": Vector3(randf_range(-0.06, 0.06), randf_range(0.02, 0.08), randf_range(-0.06, 0.06)),
			"color": Color(1.0, 0.7, 0.2)
		})
	if MuAudioManager:
		MuAudioManager.play_sound_file("eMonsterBoom1.wav", 2.0, randf_range(0.9, 1.1), to)
	impact_delay = 0.35

# ------------------------------------------------------------------ 151 Devil Fire Beam (Quái Devil Lost Tower / Golden Devil)
## Port chính xác từ ZzzCharacter.cpp (MONSTER_DEVIL) & ZzzEffectJoint.cpp (BITMAP_JOINT_LASER+1, 50.f):
## Luồng tia lửa cuồn cuộn dạng khối 3D (cross-plane), nở rộng dần (cone), UV cuộn nhanh về phía mục tiêu,
## kết hợp lõi plasma vàng trắng và chùm hạt nổ lửa BITMAP_FIRE (Fire01.jpg 4 frame).

var _devil_fire_active := false
var _devil_mesh_outer: ImmediateMesh = null
var _devil_node_outer: MeshInstance3D = null
var _devil_mesh_inner: ImmediateMesh = null
var _devil_node_inner: MeshInstance3D = null

func _process(delta: float) -> void:
	super._process(delta)
	if skill_num == DEVIL_FIRE_BEAM and _devil_fire_active:
		_devil_update_mesh()

func _exit_tree() -> void:
	_devil_cleanup()

func _devil_mouth_pos() -> Vector3:
	var m = caster.get("model") if is_instance_valid(caster) else null
	if m != null and m.get("skeleton") != null:
		var sk := m.skeleton as Skeleton3D
		for bname in ["b006", "b016", "b025", "b001", "b002"]:
			var b := sk.find_bone(bname)
			if b >= 0:
				var pos := sk.global_transform * sk.get_bone_global_pose(b).origin
				if pos.y > caster_pos().y + 0.6:
					return pos
	return caster_pos() + Vector3(0, 1.35, 0)

func _target_chest_pos() -> Vector3:
	return target_pos() + Vector3(0, 1.1, 0)

func _devil_fire_beam() -> void:
	_min_ticks = 16
	impact_delay = 0.25
	_devil_fire_active = true
	
	_devil_mesh_outer = ImmediateMesh.new()
	_devil_node_outer = MeshInstance3D.new()
	_devil_node_outer.mesh = _devil_mesh_outer
	_devil_node_outer.material_override = mat("BITMAP_JOINT_LASER+1", "add")
	_devil_node_outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_devil_node_outer)
	
	_devil_mesh_inner = ImmediateMesh.new()
	_devil_node_inner = MeshInstance3D.new()
	_devil_node_inner.mesh = _devil_mesh_inner
	_devil_node_inner.material_override = mat("BITMAP_JOINT_LASER+1", "add")
	_devil_node_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_devil_node_inner)
	
	if MuAudioManager:
		MuAudioManager.play_sound_file("sEvil.wav", 1.8, randf_range(0.95, 1.05), caster_pos())
		MuAudioManager.play_sound_file("sFlame.wav", 1.3, randf_range(0.95, 1.05), caster_pos())

func _devil_fire_tick(t: int) -> void:
	if t >= 16:
		_devil_cleanup()
		return
	
	var a := _devil_mouth_pos()
	var b := _target_chest_pos()
	var dir := (b - a).normalized()
	
	# Hạt lửa bốc lên tại miệng / tay quái (BITMAP_FIRE dùng spritesheet 4 frame)
	particle("BITMAP_FIRE", a + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)), {
		"size": randf_range(0.8, 1.4), "life": 8, "grow": 1.03,
		"sheet": Vector2i(4, 1), "frames": 4,
		"color": Color(1.0, 0.75, 0.25),
		"vel": dir * randf_range(0.04, 0.08)
	})
	
	# Quả cầu lửa nổ tung và lửa cuồn cuộn khi va chạm vào người chơi
	for i in 2:
		var hit_offset := Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.45), randf_range(-0.35, 0.35))
		particle("BITMAP_FIRE", b + hit_offset, {
			"size": randf_range(1.6, 2.5), "life": 12 + rnd(4), "grow": 1.05,
			"sheet": Vector2i(4, 1), "frames": 4,
			"color": Color(1.0, randf_range(0.55, 0.75), 0.15),
			"vel": Vector3(randf_range(-0.04, 0.04), randf_range(0.02, 0.06), randf_range(-0.04, 0.04))
		})
	
	# Tia lửa tóe ra xung quanh
	particle("BITMAP_SPARK+1", b + Vector3(0, 0.2, 0), {
		"size": randf_range(0.5, 0.9), "life": 14,
		"color": Color(1.0, 0.85, 0.35),
		"vel": Vector3(randf_range(-0.08, 0.08), randf_range(0.02, 0.09), randf_range(-0.08, 0.08))
	})
	
	if t % 5 == 0:
		stones(b, 2, 0.8)

func _devil_update_mesh() -> void:
	if not _devil_fire_active:
		return
	if not is_instance_valid(_devil_mesh_outer) or not is_instance_valid(_devil_mesh_inner):
		return
	var a := _devil_mouth_pos()
	var b := _target_chest_pos()
	var dist := a.distance_to(b)
	if dist < 0.2:
		return
	
	var dir := (b - a).normalized()
	var ref_up := Vector3.UP
	if absf(dir.dot(ref_up)) > 0.95:
		ref_up = Vector3.RIGHT
	var right := dir.cross(ref_up).normalized()
	var up := right.cross(dir).normalized()
	var segs := clampi(int(dist * 6.0), 14, 30)
	
	# Luồng lửa ngoài: nở rộng từ 0.5m tới 1.6m, màu vàng cam đậm
	_draw_fire_ribbon(_devil_mesh_outer, a, b, dir, right, up, segs, 0.5, 1.6, Color(1.0, 0.55, 0.12, 0.9), 0.0, 1.0)
	# Lõi plasma trong: nở từ 0.28m tới 0.9m, màu vàng trắng sáng chói
	_draw_fire_ribbon(_devil_mesh_inner, a, b, dir, right, up, segs, 0.28, 0.9, Color(1.0, 0.95, 0.55, 1.0), 1.5, 1.3)

func _draw_fire_ribbon(im: ImmediateMesh, a: Vector3, b: Vector3, dir: Vector3, right: Vector3, up: Vector3, segs: int, w_start: float, w_end: float, col: Color, phase_shift: float, speed_mult: float) -> void:
	im.clear_surfaces()
	var cam_pos := _cam()
	var dist := a.distance_to(b)
	
	var pts: Array[Vector3] = []
	var widths: Array[float] = []
	var u_coords: Array[float] = []
	
	for i in segs + 1:
		var frac := float(i) / float(segs)
		var base_p := a.lerp(b, frac)
		var envelope := sin(frac * PI)
		var wave_r := sin(frac * PI * 2.5 - _t * 10.0 * speed_mult + phase_shift) * 0.16 * envelope
		var wave_u := cos(frac * PI * 3.2 - _t * 8.0 * speed_mult + phase_shift) * 0.14 * envelope
		var p := base_p + right * wave_r + up * wave_u
		pts.append(p)
		widths.append(lerpf(w_start, w_end, pow(frac, 0.8)))
		u_coords.append(frac * (dist * 1.5) - _t * 6.0 * speed_mult)
	
	# Mặt 1: Billboard hướng về Camera
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var p := pts[i]
		var w := widths[i] * 0.5
		var u := u_coords[i]
		var seg_dir := (pts[mini(i + 1, segs)] - pts[maxi(i - 1, 0)]).normalized()
		if seg_dir.length_squared() < 0.001:
			seg_dir = dir
		var to_cam := (cam_pos - p).normalized()
		var side := seg_dir.cross(to_cam).normalized() * w
		
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(u, 0.0))
		im.surface_add_vertex(p - side)
		im.surface_set_uv(Vector2(u, 1.0))
		im.surface_add_vertex(p + side)
	im.surface_end()
	
	# Mặt 2: Mặt phẳng vuông góc (Cross-plane tạo hiệu ứng khối 3D như client gốc)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var p := pts[i]
		var w := widths[i] * 0.5
		var u := u_coords[i]
		var seg_dir := (pts[mini(i + 1, segs)] - pts[maxi(i - 1, 0)]).normalized()
		if seg_dir.length_squared() < 0.001:
			seg_dir = dir
		var to_cam := (cam_pos - p).normalized()
		var side := seg_dir.cross(to_cam).normalized()
		var norm_up := seg_dir.cross(side).normalized() * w
		
		im.surface_set_color(col * 0.85)
		im.surface_set_uv(Vector2(u, 0.0))
		im.surface_add_vertex(p - norm_up)
		im.surface_set_uv(Vector2(u, 1.0))
		im.surface_add_vertex(p + norm_up)
	im.surface_end()

func _devil_cleanup() -> void:
	_devil_fire_active = false
	if is_instance_valid(_devil_node_outer):
		_devil_node_outer.queue_free()
		_devil_node_outer = null
	if is_instance_valid(_devil_node_inner):
		_devil_node_inner.queue_free()
		_devil_node_inner = null

