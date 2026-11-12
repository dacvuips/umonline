extends MuFx
class_name DarkLordFx

## Hiệu ứng skill Dark Lord port tay từ client gốc.
## Nguồn: Engine/Object/ZzzCharacter.cpp (ra đòn: Force / Fire Burst / Critical / Party Teleport /
##        Electric Spike / Fire Scream / Space Split), Network/Server/WSclient.cpp (Chaotic Diseier),
##        Render/Effects/ZzzEffect.cpp + Behaviors/MoveHandlers.cpp (MODEL_WAVES, MODEL_PIERCING2, MODEL_PIER_PART,
##        MODEL_DARKLORD_SKILL, MODEL_DARK_SCREAM*, MODEL_CIRCLE*), bin/Data/Effects/EffectTypes.json
## Earthshake (62): hiệu ứng gốc nằm trong con ngựa Dark Horse (GOBoid.cpp UpdateDarkHorseSkill) — port thành hiệu ứng
## mặt đất quanh người dùng (không cần model ngựa).

const FORCE := 60
const FIREBURST := 61
const PARTY_TELEPORT := 63
const ADD_CRITICAL := 64
const THUNDER_STRIKE := 65    # Electric Spike
const FORCE_WAVE := 66
const SPACE_SPLIT := 74       # Fire Blast
const FIRE_SCREAM := 78
const EARTHSHAKE := 62
const CHAOTIC_DISEIER := 238

const SKILLS := [EARTHSHAKE, FORCE, FIREBURST, PARTY_TELEPORT, ADD_CRITICAL, THUNDER_STRIKE, FORCE_WAVE, SPACE_SPLIT,
	FIRE_SCREAM, CHAOTIC_DISEIER]

var _movers: Array = []

func _start() -> void:
	match skill_num:
		EARTHSHAKE: _earthshake()
		FORCE, FORCE_WAVE: _force()
		FIREBURST: _fireburst()
		PARTY_TELEPORT: _party_teleport()
		ADD_CRITICAL: _add_critical()
		THUNDER_STRIKE: _thunder_strike()
		SPACE_SPLIT: _space_split()
		FIRE_SCREAM: _fire_scream()
		CHAOTIC_DISEIER: _chaotic()

func _mu_tick(t: int) -> void:
	if skill_num == EARTHSHAKE:
		_earth_tick(t)
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

# ------------------------------------------------------------------ 62 Earthshake
## GOBoid.cpp UpdateDarkHorseSkill (ngựa Dark Horse, action 3, đếm WeaponLevel mỗi tick):
##   - BITMAP_SHOCK_WAVE tại ngựa (HorseEffectInterval)
##   - WeaponLevel == 19: MODEL_SKILL_FURY_STRIKE (CreateEffect tự gán SubType = rand % 100 -> chính là hiệu ứng
##     Rageful Blow: tick 9 nổ + vết nứt EarthQuake03/01/02 TRƯỚC MẶT (-25, -80, 0), tick 10 các nhánh nứt toả ra)
##   - WeaponLevel đặt lại -3 ; khung hình ngựa 8..9.5 (~tick 24..28): mỗi WeaponLevel lẻ một vòng 6 MODEL_GROUND_STONE
##     (+0 / +1, model trồi lên có animation, Scale 1.2..1.5 / 1.0..1.3, LifeTime 40) bán kính 150 * (WeaponLevel / 2),
##     kèm rung màn hình
func _earthshake() -> void:
	_earth_center = caster_pos()
	_earth_center.y = ground(_earth_center) + 0.1
	# WSclient.cpp: SetAction(PLAYER_ATTACK_DARKHORSE) (PlaySpeed 0.3) -> ngựa (MuHelperFx) chồm lên bằng action 3
	var m = caster.get("model") if is_instance_valid(caster) else null
	if m != null and str(m.get("ride_kind")) == "darkhorse" and m.has_method("play_action"):
		m.play_action(PLAYER_ATTACK_DARKHORSE, 0.3, false, true)
		if caster.has_method("_lock_action"):
			caster._lock_action(1.4)
	_shock_wave()
	_min_ticks = 75
	impact_delay = 0.8

const PLAYER_ATTACK_DARKHORSE := 87

var _earth_center := Vector3.ZERO
var _earth_front := Vector3.ZERO
var _fury_t := -1
var _waves: Array = []

## BITMAP_SHOCK_WAVE SubType 0 (ZzzEffect.cpp / Move_BITMAP_SHOCK_WAVE): vòng sóng VẼ PHẲNG TRÊN ĐẤT
## (RenderTerrainAlphaBitmap: rộng Scale ô = Scale mét), Scale 20 giảm 1 mỗi tick -> vòng co dần về tâm rồi tắt
func _shock_wave() -> void:
	var w := particle("BITMAP_SHOCK_WAVE", _earth_center + Vector3(0, 0.06, 0), {"size": 20.0, "life": 20,
		"fade": false, "rot": rnd(360), "color": Color(1.0, 1.0, 1.0)})
	if not w.is_empty():
		w["flat"] = true
		_waves.append(w)

func _earth_tick(t: int) -> void:
	for w in _waves.duplicate():
		w["size"] = maxf(float(w["size"]) - 1.0, 0.01)
		if not _parts.has(w):
			_waves.erase(w)
	# ngựa phát sóng mỗi HorseEffectInterval (10 tick) suốt action chồm lên
	if t == 10 or t == 20:
		_shock_wave()
	if t == 19:
		_fury_t = 0   # MODEL_SKILL_FURY_STRIKE bắt đầu (LifeTime 20)
	if _fury_t >= 0:
		_fury_tick(_fury_t)
		_fury_t += 1
	# WeaponLevel đặt lại -3 ở tick 19 rồi tăng mỗi tick -> WeaponLevel = t - 22 ; ngựa chạy 0.34 khung / tick nên
	# khung 8..9.5 = tick ~24..28 -> WeaponLevel lẻ 3, 5 -> 2 vòng bán kính 150 * (3/2) = 150, 150 * (5/2) = 300 (chia nguyên)
	var wl := t - 22
	if t >= 24 and t <= 28 and wl % 2 == 1:
		var base := float(rnd(360))
		for i in 6:
			var a := base + 60.0 * float(i + 1)
			var p := _earth_center + rot(Vector3(0, 150.0 * float(wl / 2), 0), Vector3(0, 0, a))
			p.y = ground(p)
			var second := rnd(2) == 1
			var sc := (1.0 if second else 1.2) + float(rnd(30)) / 100.0
			# mesh 1 (DhorSS_R, hậu tố _R) vẽ cộng sáng: viền lửa vàng ở chân đá ; animation trồi lên không lặp
			var o := model("Skill/GroundStone2" if second else "Skill/GroundStone", p,
				{"blend_mesh": 1, "scale": sc, "life": 40, "ang": Vector3(0, 0, rnd(360)), "anim_speed": 0.3 * 25.0 / 30.0})
			_no_loop(o)
			# AddTerrainLight (0.79, 0.72, 0.49): đất quanh đá sáng vàng
			var g := particle("BITMAP_LIGHT", p + Vector3(0, 0.05, 0), {"size": 2.6, "life": 40,
				"color": Color(0.79, 0.72, 0.49) * 0.8})
			if not g.is_empty():
				g["flat"] = true
			o["update"] = func(ob, _dt):
				var lt := float(ob["life"])
				# Move_MODEL_GROUND_STONE: LifeTime 32..37 -> khói + mảnh đá (MODEL_STONE1/2) văng ra
				if lt > 32.0 and lt < 37.0 and fmod(float(ob["age"]), 1.0) < _dt:
					var q: Vector3 = (ob["pos"] as Vector3) + mu(Vector3(60, -60, 50))
					particle("BITMAP_SMOKE", q, {"size": 1.2, "life": 20, "color": Color(1.0, 0.8, 0.6),
						"vel": Vector3(0, 0.02, 0), "grow": 1.03})
					_debris(ob["pos"])
				# LifeTime < 8: mờ dần (BlendMeshLight / 2 mỗi tick)
				if lt < 8.0:
					ob["light"] = lt / 8.0

## Mảnh đá vụn MODEL_STONE1 / 2 văng ra khỏi chân mỏm đá rồi rơi xuống
func _debris(from: Vector3) -> void:
	var o := model("Skill/Stone0%d" % (1 + rnd(2)), from + Vector3(0, 0.4, 0), {"blend_mesh": -1,
		"scale": randf_range(0.25, 0.45), "life": 30, "ang": Vector3(rnd(360), rnd(360), rnd(360))})
	var a := randf() * TAU
	o["vel"] = Vector3(sin(a) * randf_range(0.03, 0.08), randf_range(0.06, 0.14), cos(a) * randf_range(0.03, 0.08))
	o["update"] = func(ob, dt):
		var v: Vector3 = ob["vel"]
		v.y -= 0.02 * dt
		var q: Vector3 = (ob["pos"] as Vector3) + v * dt
		var gy := ground(q)
		if q.y < gy:
			q.y = gy
			v = Vector3.ZERO
		ob["vel"] = v
		ob["pos"] = q

## Animation của model chạy một lần (Actions[0].Loop = false trong ZzzOpenData.cpp)
func _no_loop(o: Dictionary) -> void:
	var ap := MuModelRes.find_first(o["node"], "AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	for an in ap.get_animation_list():
		var anim := ap.get_animation(an)
		if anim:
			anim.loop_mode = Animation.LOOP_NONE

## MODEL_SKILL_FURY_STRIKE (giống Rageful Blow của Dark Knight): tick 9 nổ + vết nứt trước mặt, tick 10 các nhánh nứt
func _fury_tick(t: int) -> void:
	var yaw := caster_yaw()
	if t == 9:
		_earth_front = caster_pos() + rot(Vector3(-25, -80, 0), Vector3(0, 0, yaw))
		_earth_front.y = ground(_earth_front) + 0.25
		particle("BITMAP_EXPLOTION", _earth_front, {"size": 256.0 * 0.5 / 100.0, "life": 16, "sheet": Vector2i(4, 4), "fade": false})
		var w := model("Skill/flashing", _earth_front, {"scale": 0.5, "life": 20, "blend_mesh": -2})
		w["update"] = func(ob, dt):
			ob["scale"] = float(ob["scale"]) + (1.2 if float(ob["scale"]) <= 2.0 else 0.1) * dt
			ob["light"] = float(ob["life"]) / 30.0
		var c := _earth_front - Vector3(0, 0.27, 0)
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
			pos.append(_earth_front)
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

## Skill/EarthQuake0k (MODEL_SKILL_FURY_STRIKE + k), BlendMesh 0, tắt dần cuối đời
func _quake(k: int, pos: Vector3, a: Vector3, scale: float, life: float) -> void:
	var o := model("Skill/EarthQuake0%d" % k, pos, {"ang": a, "scale": scale, "life": life, "blend_mesh": 0})
	o["update"] = func(ob, _dt): ob["light"] = minf(1.0, float(ob["life"]) / 10.0)

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
		# Đầu mũi (SubType 0): HiddenMesh = 1 -> chỉ vẽ mesh 0, Scale 1.2, vẽ thường (không cộng sáng)
		s["head"] = model("Skill/PierPart", start, {"ang": s["ang"], "scale": 1.2, "life": 40, "blend_mesh": -1, "hide_mesh": 1})
		_movers.append(s)
	for sub in [0, 1]:
		_darklord_skill(start, sub)
	_min_ticks = 20
	impact_delay = 0.5

func _fireburst_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		if s.has("head"):
			kill_obj(s["head"])
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
		if s.has("head") and _objs.has(s["head"]):
			(s["head"] as Dictionary)["pos"] = pos
			(s["head"] as Dictionary)["ang"] = ang
		# Mắt xích (SubType 1): HiddenMesh = 0 -> chỉ vẽ mesh 1, Scale 0.5, sống bằng thời gian còn lại của đầu mũi
		# (cả dây xích còn tới khi đầu mũi biến mất), Alpha = (20 - LifeTime) / 5 lúc tạo
		var born := clampf((20.0 - float(s["life"])) / 5.0, 0.0, 1.0)
		var tr := model("Skill/PierPart", pos, {"ang": ang, "scale": 0.5, "life": float(s["life"]), "blend_mesh": -1, "hide_mesh": 0})
		tr["update"] = func(ob, _dt): ob["light"] = minf(born, float(ob["life"]) / 5.0)
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
## CreateEffect(BITMAP_FLARE_FORCE, SubType 0) tại CalcAddPosition(0,-90,-50) + 150 cao -> 5 joint BITMAP_FLARE_FORCE
## (TexType = BITMAP_JOINT_THUNDER: texture TIA SÉT, Light (1, 0.8, 1), MaxTails 30, LifeTime 20) ; độ sáng đuôi gốc
## = (NumTails - 1 - j) / MaxTails * 2 (sáng gần gấp đôi ở đầu) và UV lặp 2 lần dọc tia (RenderJoint, ZzzEffectJoint.cpp):
##   SubType 0: tia thẳng chính (Scale 250), mỗi tick thêm (MultiUse - 1) đoạn, Velocity -3 giảm 2 mỗi đoạn (tăng tốc)
##   SubType 1..4 (Scale 100): tia XOẮN ỐC quanh trục đi: bán kính 80 co 2.5 mỗi đoạn, góc quay (180 / -180) giảm 20 độ
##   mỗi đoạn ; SubType 3, 4 lệch về phía đối diện ; SubType 1, 2 chờ ngẫu nhiên 2..4 tick rồi mới bắt đầu
func _thunder_strike() -> void:
	var yaw := caster_yaw()
	var a := Vector3(0, 0, yaw)
	var start := caster_pos() + rot(Vector3(0, -90, 0), a) + mu(Vector3(0, 0, 100))
	# [SubType, độ rộng (m), góc quay ban đầu, chờ (tick), lệch đối diện]
	var specs := [[0, 2.5, 0.0, 0, false], [1, 1.0, 180.0, rnd(3) + 2, false], [2, 1.0, -180.0, rnd(3) + 2, false],
		[3, 1.0, 180.0, 0, true], [4, 1.0, -180.0, 0, true]]
	for sp in specs:
		var sub: int = sp[0]
		var radius := 0.0 if sub == 0 else 80.0
		var m := {"sub": sub, "start": start, "ang": a, "vel": -3.0, "multi": 1.0, "radius": radius, "roll": float(sp[2]),
			"delay": int(sp[3]), "opp": bool(sp[4]), "n": 0, "tick": _spike_tick}
		var head := start + _spike_offset(m)
		m["r"] = ribbon("BITMAP_JOINT_THUNDER", head, {"width": float(sp[1]), "max_tails": 30, "life": 20.0 + float(sp[3]),
			"color": Color(1.0, 0.8, 1.0) * 1.7, "fade": true, "uv_tile": 2.0})
		_movers.append(m)
	_min_ticks = 24
	impact_delay = 0.3

func _spike_offset(m: Dictionary) -> Vector3:
	if float(m["radius"]) <= 0.0:
		return Vector3.ZERO
	var o := rot(Vector3(0, 0, float(m["radius"])), Vector3(0, float(m["roll"]), (m["ang"] as Vector3).z))
	return -o if bool(m["opp"]) else o

func _spike_tick(m: Dictionary) -> void:
	var r: Dictionary = m["r"]
	if not _ribbons.has(r) or int(m["n"]) >= 29:
		_movers.erase(m)
		return
	if int(m["delay"]) > 0:
		m["delay"] = int(m["delay"]) - 1
		return
	for i in range(1, int(float(m["multi"]))):
		if int(m["n"]) >= 29:
			break
		m["n"] = int(m["n"]) + 1
		m["start"] = (m["start"] as Vector3) + rot(Vector3(0, float(m["vel"]), 0), m["ang"])
		if int(m["sub"]) > 0:
			m["roll"] = float(m["roll"]) - 20.0
			m["radius"] = float(m["radius"]) - 2.5
		m["vel"] = float(m["vel"]) - 2.0
		r["head"] = (m["start"] as Vector3) + _spike_offset(m)
		ribbon_push(r)
	m["multi"] = float(m["multi"]) + 2.0

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
		# BITMAP_2LINE_GHOST SubType 0 (ZzzEffectJoint.cpp): RENDER_TYPE_ALPHA_BLEND_MINUS (dải TỐI, trừ sáng),
		# Scale = 20 + rand(200)+1 (rộng 0.21..2.2 m), MaxTails 26, LifeTime 67 / 75, Velocity 40..59
		var life := 67 if rnd(2) == 0 else 75
		var r := ribbon("BITMAP_2LINE_GHOST", p, {"width": float(20 + rnd(200) + 1) / 100.0 * 0.6, "max_tails": 26, "life": life,
			"color": Color(0.7, 0.7, 0.7), "fade": true})
		(r["mi"] as MeshInstance3D).material_override = _minus_mat(tex("BITMAP_2LINE_GHOST"), 4.0)
		_movers.append({"r": r, "pos": p, "ang": Vector3(0, 0, caster_yaw()),
			"speed": float(40 + rnd(20)), "t": 0, "tick": _ghost_tick})
	var dark := c + Vector3(0, 1.0, 0)
	for i in 5:
		_dark_blob(dark + Vector3(randf_range(-0.4, 0.4), randf_range(-0.6, 0.6), randf_range(-0.4, 0.4)), 0.6, 24)
	# CreateBomb tại mục tiêu (chỉ người chơi chính)
	particle("BITMAP_EXPLOTION", target_pos() + Vector3(0, 1.0, 0), {"size": 1.5, "life": 12, "sheet": Vector2i(4, 4), "fade": false})
	_min_ticks = 40
	impact_delay = 0.5

## RENDER_TYPE_ALPHA_BLEND_MINUS của MU = glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_COLOR): nền * (1 - màu texture).
## BLEND_MODE_SUB / blend_mul của Godot cho ô vuông đen khi bật glow, nên trộn alpha với màu đen. Cường độ = màu đỉnh (ribbon) * strength.
const MINUS_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform float strength = 1.0;
uniform bool billboard = false;
void vertex() {
	if (billboard) {
		mat4 w = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * w * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}
void fragment() {
	// nền * (1 - k * t) = trộn alpha với màu đen, alpha = k * độ sáng texture (an toàn với glow / HDR, khác blend_mul)
	vec3 t = texture(tex, UV).rgb;
	float k = clamp(COLOR.r * strength, 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = clamp(k * max(max(t.r, t.g), t.b), 0.0, 1.0);
}
"""
static var _minus_shader: Shader = null

func _minus_mat(t: Texture2D, strength: float, billboard := false) -> ShaderMaterial:
	if _minus_shader == null:
		_minus_shader = Shader.new()
		_minus_shader.code = MINUS_SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _minus_shader
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("billboard", billboard)
	return m

## BITMAP_SHINY+6 SubType 3 (Scale 0.5, LifeTime 24, ALPHA_BLEND_MINUS): đốm tối mờ
func _dark_blob(pos: Vector3, size: float, life_ticks: float) -> void:
	var t := tex("BITMAP_SHINY+6")
	if t == null:
		return
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _minus_mat(t, 0.7, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	get_tree().create_timer(life_ticks * TICK).timeout.connect(mi.queue_free)

func _ghost_tick(s: Dictionary) -> void:
	var r: Dictionary = s["r"]
	if not _ribbons.has(r):
		_movers.erase(s)
		return
	# Bản gốc KHÔNG đuổi mục tiêu: hồn bay theo hướng của người dùng (Velocity 40..59 / tick) và chỉ lắc ngang:
	# LifeTime % 16 <= 7 -> +10 độ, còn lại -10 độ mỗi tick (ZzzEffectJoint.cpp) -> đường uốn lượn hình rắn
	var ang: Vector3 = s["ang"]
	s["t"] = int(s["t"]) + 1
	ang.z += 10.0 if int(s["t"]) % 16 <= 7 else -10.0
	var pos: Vector3 = (s["pos"] as Vector3) + rot(Vector3(0, -float(s["speed"]), 0), ang)
	s["pos"] = pos
	s["ang"] = ang
	r["head"] = pos
	ribbon_push(r)
