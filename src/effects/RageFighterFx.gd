extends MuFx
class_name RageFighterFx

## Hiệu ứng skill Rage Fighter port tay từ client gốc.
## Nguồn: GameLogic/Social/MonkSystem.cpp (SetRageSkillAni, RageCreateEffect), Engine/Object/ZzzCharacter.cpp (Charge),
##        Behaviors/MoveHandlers.cpp (MODEL_WOLF_HEAD_EFFECT, BITMAP_SBUMB, MODEL_DOWN_ATTACK_DUMMY_R, BITMAP_SWORDEFF,
##        BITMAP_SWORD_EFFECT_MONO, MODEL_SHOCKWAVE_GROUND01, BITMAP_EVENT_CLOUD, MODEL_WINDFOCE, MODEL_DRAGON_KICK_DUMMY,
##        BITMAP_LAVA), bin/Data/Effects/EffectTypes.json
## Các hiệu ứng gốc chạy theo khung animation của người dùng ; ở đây quy về tick (khung ≈ tick * 0.5).

const KILLING_BLOW := 260
const BEAST_UPPERCUT := 261
const CHAIN_DRIVE := 262
const DARKSIDE := 263
const DRAGON_ROAR := 264
const DRAGON_KICK := 265      # Dragon Slasher
const ATT_UP := 266           # Ignore Defense
const HP_UP := 267            # Increase Health
const DEF_UP := 268           # Increase Block
const CHARGE := 269
const PHOENIX_SHOT := 270

const SKILLS := [KILLING_BLOW, BEAST_UPPERCUT, CHAIN_DRIVE, DARKSIDE, DRAGON_ROAR, DRAGON_KICK, ATT_UP, HP_UP, DEF_UP,
	CHARGE, PHOENIX_SHOT]

var _movers: Array = []

func _start() -> void:
	match skill_num:
		KILLING_BLOW: _killing_blow()
		BEAST_UPPERCUT: _beast_uppercut()
		CHAIN_DRIVE: _chain_drive()
		DARKSIDE: _darkside()
		DRAGON_ROAR: _dragon_roar()
		DRAGON_KICK: _dragon_kick()
		ATT_UP: _ourforces(0, Color(0.2, 0.4, 1.0), Color(0.6, 0.65, 1.0), Color(0.65, 0.8, 1.0), Color(0.5, 0.55, 1.0), Color(0.5, 0.55, 0.9))
		HP_UP: _ourforces(1, Color(0.5, 0.28, 1.0), Color(1.0, 0.35, 1.0), Color(0.8, 0.4, 1.0), Color(0.85, 0.2, 1.0), Color(0.78, 0.2, 1.0))
		DEF_UP: _ourforces(2, Color(1.0, 0.15, 0.0), Color(1.0, 0.1, 0.0), Color(1.0, 0.3, 0.2), Color(1.0, 0.2, 0.0), Color(1.0, 0.15, 0.0))
		CHARGE: _charge()
		PHOENIX_SHOT: _phoenix_shot()

func _mu_tick(_t: int) -> void:
	for s in _movers.duplicate():
		(s["tick"] as Callable).call(s)

func bone_pos(bone: int) -> Vector3:
	var m = caster.get("model") if is_instance_valid(caster) else null
	if m != null and m.get("skeleton") != null:
		var sk := m.skeleton as Skeleton3D
		var b := sk.find_bone("b%03d" % bone)
		if b >= 0:
			return sk.global_transform * sk.get_bone_global_pose(b).origin
	return caster_pos() + Vector3(0, 1.2, 0)

func set_alpha(o: Dictionary, a: float) -> void:
	for gi in MuModelRes.find_all(o["node"], "GeometryInstance3D", []):
		(gi as GeometryInstance3D).transparency = 1.0 - clampf(a, 0.0, 1.0)

func decal(bitmap: String, pos: Vector3, size: float, color: Color, life: float, rspeed := 0.0) -> Dictionary:
	var d := particle(bitmap, pos + Vector3(0, 0.05, 0), {"size": size, "life": life, "color": color,
		"rspeed": rspeed, "fade": false})
	if not d.is_empty():
		d["flat"] = true
	return d

## CreateBomb: nổ + đá văng tại p
func bomb(p: Vector3, size := 2.2) -> void:
	particle("BITMAP_EXPLOTION", p + Vector3(0, 0.8, 0), {"size": size, "life": 20, "sheet": Vector2i(4, 4), "fade": false})
	for i in 4:
		var a := randf() * TAU
		var o := model("Skill/Stone0%d" % (1 + rnd(2)), p + Vector3(0, 0.1, 0), {"blend_mesh": -1,
			"scale": randf_range(0.5, 1.0), "life": 30, "ang": Vector3(rnd(360), rnd(360), rnd(360))})
		o["vel"] = Vector3(sin(a) * 0.06, randf_range(0.1, 0.2), cos(a) * 0.06)
		o["update"] = func(ob, dt):
			var v: Vector3 = ob["vel"]
			v.y -= 0.03 * float(dt)
			var q: Vector3 = ob["pos"] + v * float(dt)
			if q.y < ground(q):
				q.y = ground(q)
				v = Vector3(v.x * 0.5, -v.y * 0.3, v.z * 0.5)
			ob["vel"] = v
			ob["pos"] = q

# ------------------------------------------------------------------ 260 Killing Blow
## MODEL_WOLF_HEAD_EFFECT SubType 0 tại xương 27 (Scale 1, sáng = LifeTime/20) ; mỗi tick (LifeTime >= 3) đầu sói
## SubType 1 (Scale 1.2..1.6, Direction (0,-50,0), LifeTime 2..3) và SubType 2 (Scale 0.8..1.0, Direction (0,-40,0),
## LifeTime 3..5, lệch ±5°) lao tới, 3 vệt BITMAP_PIN_LIGHT xanh (0.2,0.3,1) ;
## BITMAP_SBUMB (LifeTime 20, Scale 2.1) tại mục tiêu: từ LifeTime < 17 mỗi tick một vệt đấm (Scale 1.5..1.7)
func _killing_blow() -> void:
	var yaw := yaw_to(caster_pos(), target_pos())
	_movers.append({"life": 15, "yaw": yaw, "tick": _wolf_tick})
	_movers.append({"life": 20, "tick": _sbumb_tick})
	_min_ticks = 20
	impact_delay = 0.3

func _wolf_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) < 3:
		_movers.erase(s)
		return
	var p := bone_pos(27)
	var yaw := float(s["yaw"])
	for spec in [[1.2 + rnd(5) * 0.1, -50.0, 2 + rnd(2), 0.0], [0.8 + rnd(3) * 0.1, -40.0, 3 + rnd(3), float(rnd(10) - 5)]]:
		var o := model("Effect/wolf_head_effect", p, {"ang": Vector3(0, 0, yaw + float(spec[3])), "scale": spec[0],
			"dir": Vector3(0, spec[1], 0), "life": spec[2], "blend_mesh": -2, "color": Color(0.5, 0.6, 1.0)})
		o["update"] = func(ob, _dt): ob["light"] = float(ob["life"]) / 3.0
	for i in 3:
		var q := p + mu(Vector3(0, rnd(20) - 10, rnd(28) + 6))
		particle("BITMAP_PIN_LIGHT", q, {"size": 0.5, "life": 6, "color": Color(0.2, 0.3, 1.0),
			"vel": rot(Vector3(0, -30, 0), Vector3(0, 0, yaw))})

func _sbumb_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		return
	if int(s["life"]) < 17:
		var t := target_pos() + mu(Vector3(rnd(80) - 40, rnd(80) - 40, rnd(120) + 30))
		var sc := (1.5 + rnd(10) * 0.02) * 2.1
		particle("BITMAP_SBUMB", t, {"size": 64.0 * sc / 100.0, "life": 8, "sheet": Vector2i(4, 1), "fade": false,
			"rot": rnd(360)})

# ------------------------------------------------------------------ 261 Beast Uppercut
## MODEL_DOWN_ATTACK_DUMMY_R (down_left_punch, chạy cùng animation): khung >= 3 CreateBomb3 tại mục tiêu ;
## mỗi tick cột BITMAP_FORCEPILLAR từ xương 0 của nắm đấm và sprite BITMAP_FLARE (0.47,0.36,0.24) Scale 5
func _beast_uppercut() -> void:
	var a := Vector3(0, 0, yaw_to(caster_pos(), target_pos()))
	var o := model("Effect/down_left_punch", caster_pos(), {"ang": a, "life": 14, "blend_mesh": -3, "anim_speed": 1.0})
	o["update"] = func(ob, dt):
		ob["pos"] = caster_pos()
		if fmod(float(ob["age"]), 1.0) < float(dt):
			var f := caster_pos() + rot(Vector3(0, -80, 120), ob["ang"])
			sprite("BITMAP_FLARE", f, 5.0 * 0.4, Color(0.47, 0.36, 0.24))
			particle("BITMAP_FORCEPILLAR", f, {"size": 0.8, "life": 6, "color": Color(0.8, 0.6, 0.4)})
		if float(ob["age"]) >= 6.0 and not ob.has("boom"):
			ob["boom"] = true
			var t := target_pos()
			t.y = ground(t)
			for k in 3:
				bomb(t + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), 2.0 * 0.9)
	impact_delay = 0.3

# ------------------------------------------------------------------ 262 Chain Drive
## BITMAP_SWORDEFF: vệt "!SwordEff" (Scale 100) giữa xương tay 5 -> 4 suốt động tác ; khung > 6: MODEL_SHOCKWAVE01
## xanh (0.4,0.5,1) phía sau-bên (-180,100,0), đầu sói wolf_head_effect2, BITMAP_DAMAGE1 (Scale 1.4) tại mục tiêu
func _chain_drive() -> void:
	blur("BITMAP_SWORDEFF", func(): return [bone_pos(5), bone_pos(4)], 1, 22, Color(0.7, 0.8, 1.0), 16)
	_movers.append({"t": 0, "tick": _chain_drive_tick})
	_min_ticks = 26
	impact_delay = 0.5

func _chain_drive_tick(s: Dictionary) -> void:
	s["t"] = int(s["t"]) + 1
	var t := int(s["t"])
	var a := Vector3(0, 0, caster_yaw())
	if t == 12 or t == 22:
		var sw := model("Effect/shockwave01", caster_pos() + rot(Vector3(-180, 100, 0), a) * 0.5 + Vector3(0, 1.0, 0),
			{"ang": Vector3(60, 0, a.z - 180), "life": 12, "blend_mesh": -2, "color": Color(0.4, 0.5, 1.0)})
		sw["update"] = func(ob, dt):
			ob["scale"] = float(ob["scale"]) * pow(1.15, float(dt))
			ob["light"] = float(ob["life"]) / 12.0
		var w := model("Effect/wolf_head_effect2", caster_pos() + Vector3(0, 1.1, 0), {"ang": a, "dir": Vector3(0, -40, 0),
			"life": 6, "blend_mesh": -2, "color": Color(0.5, 0.6, 1.0)})
		w["update"] = func(ob, _dt): ob["light"] = float(ob["life"]) / 6.0
		particle("BITMAP_DAMAGE1", target_pos() + Vector3(0, 1.0, 0), {"size": 64.0 * 1.4 / 100.0 * 2.0, "life": 10,
			"color": Color(0.4, 0.5, 1.0)})
	if t >= 26:
		_movers.erase(s)

# ------------------------------------------------------------------ 263 Dark Side
## BITMAP_EVENT_CLOUD SubType 1 (clouds2, vẽ trên đất, Scale 1 nhân 1.08/tick tối đa 5, sáng giảm 0.9/tick, xoay) màu
## (1,0.6,0.6) ; BITMAP_MAGIC SubType 14 (1,0.4,0) ; MODEL_WINDFOCE SubType 2 (wind_foce, LifeTime 70) (1,0.5,0.2) ;
## sau đó các đòn ảnh (dummy) lao vào mục tiêu
func _darkside() -> void:
	var p := caster_pos()
	var c := decal("BITMAP_EVENT_CLOUD", p, 1.0, Color(1.0, 0.6, 0.6), 30, -6)
	if not c.is_empty():
		_movers.append({"d": c, "max": 5.0, "tick": _cloud_tick})
	decal("BITMAP_MAGIC", p, 2.0, Color(1.0, 0.4, 0.0), 20, 8)
	_wind(p, 2, Color(1.0, 0.5, 0.2), 70)
	_movers.append({"t": 0, "tick": _darkside_hits})
	_min_ticks = 40
	impact_delay = 0.6

func _darkside_hits(s: Dictionary) -> void:
	s["t"] = int(s["t"]) + 1
	var t := int(s["t"])
	if t >= 10 and t <= 24 and t % 3 == 1:
		var to := target_pos() + Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6))
		var from := to + rot(Vector3(0, 250, 50), Vector3(0, 0, rnd(360)))
		bolt("BITMAP_FLARE_FORCE", from, to, 0.5, Color(1.0, 0.4, 0.2), 4, 0.0, 3.0)
		particle("BITMAP_DAMAGE1", to, {"size": 1.2, "life": 8, "color": Color(1.0, 0.5, 0.3)})
	if t > 24:
		_movers.erase(s)

func _cloud_tick(s: Dictionary) -> void:
	var d: Dictionary = s["d"]
	if not _parts.has(d):
		_movers.erase(s)
		return
	d["size"] = minf(float(s["max"]), float(d["size"]) * 1.08)
	d["color"] = (d["color"] as Color) * 0.9

## MODEL_WINDFOCE: xoay theo thời gian ; SubType 0/4/5 Scale +0.1/tick tối đa 3, Alpha * 0.92, sáng * 0.9
func _wind(p: Vector3, sub: int, c: Color, life: float) -> void:
	var o := model("Effect/wind_foce", p, {"life": life, "blend_mesh": -2, "color": c})
	o["update"] = func(ob, dt):
		var a: Vector3 = ob["ang"]
		a.z -= 18.0 * float(dt)
		ob["ang"] = a
		if sub != 2:
			ob["scale"] = minf(3.0, float(ob["scale"]) + 0.1 * float(dt))
		ob["light"] = float(ob["light"]) * pow(0.92 if sub != 2 else 0.97, float(dt))

# ------------------------------------------------------------------ 264 Dragon Roar
## BITMAP_LAVA: khung 2..8 lửa nham từ xương tay 36 và 28 ; khung > 5: MODEL_BLOW_OF_DESTRUCTION SubType 2
## (knight_plancrack_dragon, Scale 0.8, quay hướng mục tiêu) và MODEL_VOLCANO_OF_MONK tại mục tiêu
func _dragon_roar() -> void:
	_movers.append({"t": 0, "tick": _roar_tick})
	_min_ticks = 40
	impact_delay = 0.6

func _roar_tick(s: Dictionary) -> void:
	s["t"] = int(s["t"]) + 1
	var t := int(s["t"])
	if t >= 4 and t <= 16:
		for b in [36, 28]:
			particle("BITMAP_LAVA", bone_pos(b), {"size": 0.6, "life": 10, "sheet": Vector2i(2, 1), "color": Color(1, 0.6, 0.3),
				"vel": Vector3(randf_range(-0.01, 0.01), 0.02, randf_range(-0.01, 0.01))})
	if t == 11:
		var a := Vector3(0, 0, yaw_to(caster_pos(), target_pos()) + rnd(40) + 140)
		var p := caster_pos() + rot(Vector3(0, -55, 0), Vector3(0, 0, yaw_to(caster_pos(), target_pos())))
		var crack := model("Effect/knight_plancrack_dragon", p, {"ang": a, "scale": 0.8, "life": 40, "blend_mesh": -3})
		crack["update"] = func(ob, _dt): set_alpha(ob, minf(1.0, float(ob["life"]) / 10.0))
		particle("BITMAP_LIGHT_RED", p + Vector3(0, 0.3, 0), {"size": 1.9, "life": 15})
		var v := model("Effect/volcano_of_monk", target_pos(), {"life": 40, "blend_mesh": -3})
		v["update"] = func(ob, _dt): set_alpha(ob, minf(1.0, float(ob["life"]) / 10.0))
		for k in 6:
			particle("BITMAP_LAVA", target_pos() + Vector3(randf_range(-0.8, 0.8), 0.2, randf_range(-0.8, 0.8)),
				{"size": 0.9, "life": 20, "sheet": Vector2i(2, 1), "vel": Vector3(0, randf_range(0.04, 0.1), 0), "grav": -0.004})
	if t > 20:
		_movers.erase(s)

# ------------------------------------------------------------------ 265 Dragon Slasher (Dragon Kick)
## MODEL_DRAGON_KICK_DUMMY: khung 4..5 vệt gió BITMAP_GROUND_WIND (Scale 150) dọc chân ; MODEL_MULTI_SHOT3 x2 (+20),
## MULTI_SHOT1 x3, MULTI_SHOT2 x2 (+20) hướng về mục tiêu, Light (0.8,0.9,1.6)
func _dragon_kick() -> void:
	var a := Vector3(0, 0, yaw_to(caster_pos(), target_pos()))
	_multi_shot(a)
	_movers.append({"t": 0, "a": a, "tick": _kick_tick})
	_min_ticks = 20
	impact_delay = 0.4

func _kick_tick(s: Dictionary) -> void:
	s["t"] = int(s["t"]) + 1
	var t := int(s["t"])
	if t >= 8 and t <= 10:
		var a: Vector3 = s["a"]
		var from := caster_pos() + Vector3(0, 0.6, 0)
		var to := from + rot(Vector3(0, -350, 0), a)
		bolt("BITMAP_GROUND_WIND", from, to, 1.5, Color(0.7, 0.7, 1.0), 8, 0.05, 1.0)
	if t > 10:
		_movers.erase(s)

func _multi_shot(a: Vector3) -> void:
	var light := Color(0.8, 0.9, 1.6)
	for spec in [["Effect/multishot03", Vector3(0, 20, 0), 12, 0.25, 2], ["Effect/multishot01", Vector3.ZERO, 16, 0.2, 3],
			["Effect/multishot02", Vector3(0, 20, 0), 13, 0.3, 2]]:
		for k in int(spec[4]):
			var o := model(spec[0], caster_pos() + rot(spec[1], a), {"ang": a, "scale": 0.0, "life": spec[2],
				"blend_mesh": -2, "color": light})
			var grow: float = spec[3]
			o["update"] = func(ob, dt):
				ob["scale"] = float(ob["scale"]) + grow * float(dt)
				ob["light"] = float(ob["life"]) / 18.0

# ------------------------------------------------------------------ 266..268 Ignore Defense / Increase Health / Block
## BITMAP_SWORD_EFFECT_MONO (LifeTime 15): hạt kiếm sáng quanh người ; tick 1: MODEL_SHOCKWAVE01 ;
## 3 x MODEL_SHOCKWAVE_GROUND01 (Scale 1 / 0.85 / 0.7, nhân 1.2/tick, sáng * 0.8, LifeTime 20) ;
## 3 x BITMAP_EVENT_CLOUD (Scale 1 nhân 1.08 tối đa 3, sáng * 0.9, LifeTime 30) ;
## MODEL_WINDFOCE SubType 0/4/5 ; BITMAP_MAGIC SubType 13 (vòng phép dưới chân)
func _ourforces(sub: int, c_mono: Color, c_wave: Color, c_cloud: Color, c_wind: Color, c_magic: Color) -> void:
	var p := caster_pos()
	_movers.append({"life": 15, "c": c_mono, "tick": _mono_tick})
	for i in 3:
		var w := model("Effect/shockwave_ground01", p + Vector3(0, 0.03, 0), {"scale": 1.0 - i * 0.15, "life": 20,
			"blend_mesh": -2, "color": c_wave})
		w["update"] = func(ob, dt):
			ob["scale"] = float(ob["scale"]) * pow(1.2, float(dt)) if float(ob["scale"]) < 6.0 else float(ob["scale"])
			ob["light"] = float(ob["light"]) * pow(0.8, float(dt))
		var c := decal("BITMAP_EVENT_CLOUD", p, 1.0, c_cloud, 30, -6)
		if not c.is_empty():
			_movers.append({"d": c, "max": 3.0, "tick": _cloud_tick})
	_wind(p, [0, 4, 5][sub], c_wind, 50)
	decal("BITMAP_MAGIC", p, 2.2, c_magic, 25, 8)
	_min_ticks = 30
	impact_delay = 0.1

func _mono_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		return
	if int(s["life"]) % 3 != 0:
		var q := caster_pos() + Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 1.8), randf_range(-0.5, 0.5))
		particle("BITMAP_SWORD_EFFECT_MONO", q, {"size": 0.6, "life": 10, "color": s["c"], "vel": Vector3(0, 0.03, 0)})

# ------------------------------------------------------------------ 269 Charge
## ZzzCharacter AT_SKILL_RUSH/OCCUPY: mỗi tick 4 tia BITMAP_JOINT_SPARK + lửa BITMAP_FIRE (Scale 1.5) dưới chân ;
## MODEL_MULTI_SHOT1/2/3 (CMonkSystem::RageCreateEffect AT_SKILL_OCCUPY)
func _charge() -> void:
	_multi_shot(Vector3(0, 0, caster_yaw()))
	_movers.append({"life": 10, "tick": _charge_tick})
	_min_ticks = 14
	impact_delay = 0.3

func _charge_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		return
	var p := caster_pos() + mu(Vector3(rnd(30) - 15, rnd(30) - 15, 20))
	for i in 4:
		var a := Vector3(float(rnd(60) + 60 + 90), 0, caster_yaw())
		var d := rot(Vector3(0, -1, 0), a) * float(rnd(20) + 6) / 100.0
		bolt("BITMAP_JOINT_SPARK", p, p + d * 2.0, 0.04, Color(1, 1, 1), 6, 0.0, 1.0)
		particle("BITMAP_FIRE", p, {"size": 0.5, "life": 10, "sheet": Vector2i(4, 1), "vel": Vector3(0, 0.03, 0)})

# ------------------------------------------------------------------ 270 Phoenix Shot
## MODEL_PHOENIX_SHOT (phoenix_shot_effect) tại mục tiêu, hướng từ người dùng
func _phoenix_shot() -> void:
	var t := target_pos()
	var o := model("Effect/phoenix_shot_effect", t, {"ang": Vector3(0, 0, yaw_to(caster_pos(), t)), "life": 30,
		"blend_mesh": -3})
	o["update"] = func(ob, _dt): set_alpha(ob, minf(1.0, float(ob["life"]) / 8.0))
	particle("BITMAP_LIGHT_RED", t + Vector3(0, 1.0, 0), {"size": 3.0, "life": 16})
	impact_delay = 0.4
