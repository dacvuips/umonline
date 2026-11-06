extends MuFx
class_name DarkLordFx

## Hiệu ứng skill Dark Lord port tay từ client gốc.
## Nguồn: Engine/Object/ZzzCharacter.cpp (ra đòn: Force / Fire Burst / Critical / Party Teleport /
##        Electric Spike / Fire Scream / Space Split), Network/Server/WSclient.cpp (Chaotic Diseier),
##        Render/Effects/ZzzEffect.cpp + Behaviors/MoveHandlers.cpp (MODEL_WAVES, MODEL_PIERCING2, MODEL_PIER_PART,
##        MODEL_DARKLORD_SKILL, MODEL_DARK_SCREAM*, MODEL_CIRCLE*), bin/Data/Effects/EffectTypes.json
## Earthshake cần ngựa Dark Horse (hiệu ứng nằm trong model ngựa) nên chưa port.

const FORCE := 60
const FIREBURST := 61
const PARTY_TELEPORT := 63
const ADD_CRITICAL := 64
const THUNDER_STRIKE := 65    # Electric Spike
const FORCE_WAVE := 66
const SPACE_SPLIT := 74       # Fire Blast
const FIRE_SCREAM := 78
const CHAOTIC_DISEIER := 238

const SKILLS := [FORCE, FIREBURST, PARTY_TELEPORT, ADD_CRITICAL, THUNDER_STRIKE, FORCE_WAVE, SPACE_SPLIT,
	FIRE_SCREAM, CHAOTIC_DISEIER]

var _movers: Array = []

func _start() -> void:
	match skill_num:
		FORCE, FORCE_WAVE: _force()
		FIREBURST: _fireburst()
		PARTY_TELEPORT: _party_teleport()
		ADD_CRITICAL: _add_critical()
		THUNDER_STRIKE: _thunder_strike()
		SPACE_SPLIT: _space_split()
		FIRE_SCREAM: _fire_scream()
		CHAOTIC_DISEIER: _chaotic()

func _mu_tick(_t: int) -> void:
	for s in _movers.duplicate():
		(s["tick"] as Callable).call(s)

func weapon_pos(hand: String) -> Vector3:
	var m = caster.get("model") if is_instance_valid(caster) else null
	if m != null:
		var nodes: Dictionary = m.get("_weapon_nodes") if m.get("_weapon_nodes") != null else {}
		var d: Dictionary = nodes.get(hand, {})
		if is_instance_valid(d.get("node")):
			return (d["node"] as Node3D).global_position
	return caster_pos() + Vector3(0, 1.2, 0)

# ------------------------------------------------------------------ 60 / 66 Force, Force Wave
## 2 x MODEL_WAVES SubType 1 (m_Waves, BlendMesh -2, LifeTime 15, Scale 0.1..0.6 lớn dần (gia tốc 0.07, tối đa 2),
##   Angle (90,0,hướng), cao +130, lệch ±50, sáng giảm /1.5 mỗi tick) ;
## MODEL_PIERCING2 (m_Piercing, LifeTime 10, Scale 2, BlendMesh -2, Direction (0,-60,0) giảm 12/tick, cao +130):
##   mỗi tick (LifeTime > 5) để lại MODEL_WAVES SubType 2 (Scale = LifeTime*0.05, gia tốc 0.01, tối đa 1.5)
func _force() -> void:
	var yaw := yaw_to(caster_pos(), target_pos())
	for k in 2:
		var p := caster_pos() + mu(Vector3(rnd(100) - 50, rnd(100) - 50, 130))
		_wave(p, yaw, 0.1 + rnd(50) / 100.0, 0.01, 0.07, 2.0, 1.5, 15)
	var pc := model("Skill/m_Piercing", caster_pos() + mu(Vector3(0, 0, 130)), {"ang": Vector3(0, 0, yaw),
		"dir": Vector3(0, -60, 0), "scale": 2.0, "life": 10, "blend_mesh": -2})
	pc["update"] = func(ob, dt):
		var d: Vector3 = ob["dir"]
		d.y = minf(0.0, d.y + 12.0 * dt)
		ob["dir"] = d
		if fmod(float(ob["age"]), 1.0) < dt and float(ob["life"]) > 5.0:
			ob["light"] = float(ob["light"]) / 1.6
			_wave(ob["pos"] - mu(Vector3(0, 0, 50)), yaw, float(ob["life"]) * 0.05, 0.01, 0.01, 1.5, 1.5, 15)
	impact_delay = 0.25

func _wave(p: Vector3, yaw: float, scale: float, grav: float, acc: float, cap: float, decay: float, life: float) -> void:
	var w := model("Skill/m_waves", p, {"ang": Vector3(90, 0, yaw), "scale": scale, "life": life, "blend_mesh": -2})
	w["g"] = grav
	w["update"] = func(ob, dt):
		ob["scale"] = minf(cap, float(ob["scale"]) + float(ob["g"]) * dt)
		ob["g"] = float(ob["g"]) + acc * dt
		ob["light"] = float(ob["light"]) * pow(1.0 / decay, dt)

# ------------------------------------------------------------------ 61 Fire Burst
## 3 x MODEL_PIER_PART SubType 0 (mesh 1 ẩn, Scale 1.2, Direction (0,-26,0), Velocity 10 tăng 0.4) xuất phát
## hướng +90 / 0 / -90 rồi MoveHumming về mục tiêu ; mỗi bước để lại PIER_PART SubType 1 (Scale 0.5, lửa BITMAP_FIRE+1) ;
## MODEL_DARKLORD_SKILL SubType 0/1 (Light (1,0.6,0.3)) tại tay
func _fireburst() -> void:
	var yaw := caster_yaw()
	var start := caster_pos() + rot(Vector3(40, 0, 110), Vector3(0, 0, yaw))
	for off in [90.0, 0.0, -90.0]:
		var s := {"pos": start, "ang": Vector3(0, 0, yaw + off), "vel": 10.0, "grav": 2.0, "life": 20,
			"tick": _fireburst_tick}
		_movers.append(s)
	for sub in [0, 1]:
		_darklord_skill(start, sub)
	_min_ticks = 20
	impact_delay = 0.5

func _fireburst_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		particle("BITMAP_EXPLOTION", s["pos"], {"size": 1.2, "life": 12, "sheet": Vector2i(4, 4), "fade": false,
			"color": Color(1, 0.7, 0.4)})
		return
	var to := target_pos() + Vector3(0, 0.9, 0)
	for i in range(1, int(float(s["grav"]))):
		var ang: Vector3 = s["ang"]
		var pos: Vector3 = s["pos"]
		ang.z = _turn(ang.z, yaw_to(pos, to), float(s["vel"]))
		var horiz := Vector2(to.x - pos.x, to.z - pos.z).length()
		ang.x = _turn(ang.x, -rad_to_deg(atan2(to.y - pos.y, horiz)), float(s["vel"]))
		s["vel"] = float(s["vel"]) + 0.4
		pos += rot(Vector3(0, -26, 0), ang)
		s["pos"] = pos
		s["ang"] = ang
		var tr := model("Skill/PierPart", pos, {"ang": ang, "scale": 0.5, "life": 8, "blend_mesh": -2})
		tr["update"] = func(ob, _dt): ob["light"] = minf(1.0, float(ob["life"]) / 5.0)
		particle("BITMAP_FIRE+1", pos, {"size": 0.6, "life": 8, "rot": rnd(360)})
		if pos.distance_to(to) < 0.4:
			s["life"] = 1
			break
	s["grav"] = float(s["grav"]) + 0.1

## MODEL_DARKLORD_SKILL: LifeTime 10, Scale 0.2, Angle (45, ±45, 0), Light (1, 0.6, 0.3)
func _darklord_skill(p: Vector3, sub: int) -> void:
	var a := 45.0 - 90.0 * sub
	var o := model("Skill/DarkLordSkill", p, {"ang": Vector3(45, a, caster_yaw()), "scale": 0.2, "life": 10,
		"blend_mesh": -2, "color": Color(1.0, 0.6, 0.3), "anim_speed": 0.4})
	o["update"] = func(ob, _dt): ob["light"] = minf(1.5, float(ob["life"]) / 4.0)

func _turn(a: float, b: float, turn: float) -> float:
	return a + clampf(wrapf(b - a, -180.0, 180.0), -turn, turn)

# ------------------------------------------------------------------ 64 Increase Critical Damage
## MODEL_DARKLORD_SKILL SubType 0 tại vũ khí tay phải, SubType 1 tại tay trái (không phải khiên)
func _add_critical() -> void:
	_darklord_skill(weapon_pos("right"), 0)
	_darklord_skill(weapon_pos("left") if weapon_pos("left") != weapon_pos("right") else weapon_pos("right"), 1)
	impact_delay = 0.1

# ------------------------------------------------------------------ 63 Summon (Party Teleport)
## MODEL_CIRCLE SubType 2 (Circle01, LifeTime 250, sáng dần 10 tick đầu rồi tắt dần) +
## MODEL_CIRCLE_LIGHT SubType 3 (Circle02, LifeTime 250, sáng tối đa 0.5, cuộn UV, hạt BITMAP_FLARE_BLUE
## trong bán kính 200 và vệt sáng rơi từ cao 600)
func _party_teleport() -> void:
	var p := caster_pos()
	var a := Vector3(0, 0, caster_yaw())
	var c := model("Skill/Circle01", p, {"ang": a, "life": 250, "blend_mesh": 0, "light": 0.0})
	c["update"] = func(ob, _dt):
		var lt := float(ob["life"])
		ob["light"] = minf(1.0, ((250.0 - lt) if lt > 240.0 else lt) * 0.1)
	var l := model("Skill/Circle02", p, {"ang": a, "life": 250, "blend_mesh": -2, "light": 0.0})
	l["update"] = func(ob, dt):
		var lt := float(ob["life"])
		ob["light"] = minf(0.5, ((250.0 - lt) if lt >= 240.0 else lt) * 0.1)
		ob["uv"] = -lt * 0.01
		if lt > 30.0 and fmod(float(ob["age"]), 1.0) < dt and rnd(2) == 0:
			var q := p + rot(Vector3(0, rnd(200), 0), Vector3(0, 0, rnd(360)))
			particle("BITMAP_FLARE_BLUE", q + Vector3(0, 0.2, 0), {"size": 0.8, "life": 20, "vel": Vector3(0, 0.02, 0)})
			if lt > 40.0:
				var top := q + mu(Vector3(0, 0, 600))
				bolt("BITMAP_FLARE_BLUE", top, q, 0.4, Color(0.6, 0.7, 1.0), 6, 0.0, 6.0)
	impact_delay = 0.1

# ------------------------------------------------------------------ 65 Electric Spike (Thunder Strike)
## BITMAP_FLARE_FORCE SubType 0 tại CalcAddPosition(0,-90,-50): 5 joint BITMAP_FLARE_FORCE (Scale 250 ở giữa,
## 100 hai bên) toả quạt về phía trước
func _thunder_strike() -> void:
	var yaw := caster_yaw()
	var a := Vector3(0, 0, yaw)
	var start := caster_pos() + rot(Vector3(0, -90, 50), a)
	var specs := [[0.0, 2.5], [-20.0, 1.0], [20.0, 1.0], [-40.0, 1.0], [40.0, 1.0]]
	for sp in specs:
		var r := ribbon("BITMAP_FLARE_FORCE", start, {"width": float(sp[1]), "max_tails": 14, "life": 24,
			"color": Color(0.7, 0.8, 1.0)})
		_movers.append({"r": r, "pos": start, "ang": Vector3(0, 0, yaw + float(sp[0])), "n": 0, "tick": _spike_tick})
	for k in 3:
		var q := start + rot(Vector3(randf_range(-150, 150), -rnd(600) - 100, 0), a)
		bolt("BITMAP_JOINT_THUNDER", q + mu(Vector3(0, 0, 600)), q, 0.3, Color(0.7, 0.7, 1.0), 6, 0.4, 0.6)
	_min_ticks = 24
	impact_delay = 0.3

func _spike_tick(s: Dictionary) -> void:
	var r: Dictionary = s["r"]
	if not _ribbons.has(r) or int(s["n"]) >= 14:
		_movers.erase(s)
		return
	s["n"] = int(s["n"]) + 1
	s["pos"] = (s["pos"] as Vector3) + rot(Vector3(0, -60, 0), s["ang"])
	r["head"] = s["pos"]
	ribbon_push(r)
	sprite("BITMAP_LIGHT", s["pos"], 1.5, Color(0.4, 0.5, 1.0))

# ------------------------------------------------------------------ 74 Fire Blast (Space Split)
## MODEL_PIER_PART SubType 2 (mesh ẩn, Velocity 50 tăng 2.4, Direction (0,-40,0)) MoveHumming về mục tiêu ;
## mỗi 3 tick một cột BITMAP_JOINT_FORCE SubType 2 (Scale 150, Angle (-90,0,hướng)) dựng đứng
func _space_split() -> void:
	var s := {"pos": caster_pos() - Vector3(0, 0.2, 0), "ang": Vector3(0, 0, caster_yaw()), "vel": 50.0, "life": 20,
		"tick": _space_tick}
	_movers.append(s)
	_min_ticks = 20
	impact_delay = 0.5

func _space_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		return
	var to := target_pos()
	var ang: Vector3 = s["ang"]
	ang.z = _turn(ang.z, yaw_to(s["pos"], to), float(s["vel"]))
	s["vel"] = float(s["vel"]) + 2.4
	var pos: Vector3 = (s["pos"] as Vector3) + rot(Vector3(0, -40, 0), ang)
	pos.y = ground(pos)
	s["pos"] = pos
	s["ang"] = ang
	if int(s["life"]) % 3 == 0:
		var r := ribbon("BITMAP_JOINT_FORCE", pos, {"width": 1.5, "max_tails": 12, "life": 16,
			"color": Color(1.0, 0.6, 0.3), "fixed": true})
		var pts: Array = []
		for i in 12:
			pts.append(pos + Vector3(sin(i * 0.5) * 0.15, i * 0.25, cos(i * 0.5) * 0.15))
		r["pts"] = pts
		var ring := model("Skill/Inferno01", pos, {"scale": 0.2, "life": 5, "blend_mesh": -2, "color": Color(0.8, 0.3, 0.1)})
		ring["update"] = func(ob, dt): ob["scale"] = float(ob["scale"]) + 0.01 * dt

# ------------------------------------------------------------------ 78 Fire Scream
## 3 cặp MODEL_DARK_SCREAM (darkfirescrem02) + MODEL_DARK_SCREAM_FIRE (darkfirescrem01): giữa, lệch ±80 sang ngang
## với góc ±10 ; Scale 2.3 nhỏ dần (0.04 / 0.14 mỗi tick), Direction (0,-35,0), LifeTime 19, bám mặt đất +3 ;
## mỗi tick lửa BITMAP_FLAME cỡ (Scale - 0.4) * 3.5
func _fire_scream() -> void:
	var yaw := caster_yaw()
	for spec in [[0.0, 0.0], [80.0, 10.0], [-80.0, -10.0]]:
		var a := Vector3(0, 0, yaw + float(spec[1]))
		var p := caster_pos() + rot(Vector3(float(spec[0]), 0, 0), Vector3(0, 0, yaw)) + rot(Vector3(-10, -60, 0), a)
		for kind in [["Skill/darkfirescrem02", 0.04], ["Skill/darkfirescrem01", 0.14]]:
			var o := model(kind[0], p, {"ang": a, "dir": Vector3(0, -35, 0), "scale": 2.3, "life": 19, "blend_mesh": -3})
			var shrink: float = kind[1]
			o["update"] = func(ob, dt):
				var sc: float = float(ob["scale"]) - shrink * float(dt)
				ob["scale"] = sc if sc >= 0.1 else 0.0
				var q: Vector3 = ob["pos"]
				q.y = ground(q) + 0.03
				ob["pos"] = q
				if shrink > 0.1 and fmod(float(ob["age"]), 1.0) < dt and sc > 0.4:
					particle("BITMAP_FLAME", q + Vector3(0, 0.2, 0), {"size": (sc - 0.4) * 3.5 * 0.3, "life": 12,
						"vel": Vector3(0, 0.04, 0), "grow": 0.95})
	impact_delay = 0.35

# ------------------------------------------------------------------ 238 Chaotic Diseier
## 5 x BITMAP_SHINY+6 SubType 3 (Scale 0.5, LifeTime 24, ALPHA_BLEND_MINUS): đốm tối trên các xương người dùng ;
## 8 joint BITMAP_2LINE_GHOST (Scale 20) từ (±120, cao 50..110) quanh người bay ra ; CreateBomb tại mục tiêu
func _chaotic() -> void:
	var c := caster_pos()
	for i in 8:
		var p := c + mu(Vector3(rnd(240) - 119, 0, 49 + rnd(60)))
		var r := ribbon("BITMAP_2LINE_GHOST", p, {"width": 0.5, "max_tails": 10, "life": 22, "color": Color(1, 1, 1)})
		_movers.append({"r": r, "pos": p, "ang": Vector3(-rnd(30), 0, yaw_to(p, target_pos()) + rnd(60) - 30),
			"tick": _ghost_tick})
	var dark := c + Vector3(0, 1.0, 0)
	for i in 5:
		particle("BITMAP_SHINY+6", dark + Vector3(randf_range(-0.4, 0.4), randf_range(-0.6, 0.6), randf_range(-0.4, 0.4)),
			{"size": 0.6, "life": 24, "blend": "sub", "color": Color(0.5, 0.5, 0.5)})
	_min_ticks = 22
	impact_delay = 0.5

func _ghost_tick(s: Dictionary) -> void:
	var r: Dictionary = s["r"]
	if not _ribbons.has(r):
		_movers.erase(s)
		return
	var to := target_pos() + Vector3(0, 1.0, 0)
	var ang: Vector3 = s["ang"]
	ang.z = _turn(ang.z, yaw_to(s["pos"], to), 12.0)
	var pos: Vector3 = (s["pos"] as Vector3) + rot(Vector3(0, -40, 0), ang)
	s["pos"] = pos
	s["ang"] = ang
	r["head"] = pos
	ribbon_push(r)
	if pos.distance_to(to) < 0.5:
		r["life"] = minf(float(r["life"]), 4.0)
		particle("BITMAP_EXPLOTION", to, {"size": 1.5, "life": 12, "sheet": Vector2i(4, 4), "fade": false})
		_movers.erase(s)
