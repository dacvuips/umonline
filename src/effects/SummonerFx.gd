extends MuFx
class_name SummonerFx

## Hiệu ứng skill Summoner port tay từ client gốc.
## Nguồn: Engine/Object/ZzzCharacter.cpp (AT_SKILL_ALICE_* lúc ra đòn), GameLogic/Skills/SummonSystem.cpp
##        (CreateSummonObject: Sahamutt / Neil / Lagul), Network/Server/WSclient.cpp (ReceiveChainMagic),
##        Behaviors/MoveHandlers.cpp (MODEL_ALICE_*, MODEL_CHAIN_LIGHTNING, MODEL_SUMMONER_SUMMON_*, BITMAP_MAGIC_ZIN,
##        MODEL_LIGHTNING_SHOCK), bin/Data/Effects/EffectTypes.json (LifeTime / Scale khởi tạo)

const DRAIN_LIFE := 214
const CHAIN_LIGHTNING := 215
const THORNS := 217          # Damage Reflection
const BERSERKER := 218
const SLEEP := 219
const BLIND := 220
const WEAKNESS := 221
const ENERVATION := 222      # Innovation
const SUMMON_EXPLOSION := 223
const SUMMON_REQUIEM := 224
const SUMMON_POLLUTION := 225
const LIGHTNING_SHOCK := 230

const SKILLS := [DRAIN_LIFE, CHAIN_LIGHTNING, THORNS, BERSERKER, SLEEP, BLIND, WEAKNESS, ENERVATION,
	SUMMON_EXPLOSION, SUMMON_REQUIEM, SUMMON_POLLUTION, LIGHTNING_SHOCK]

var _movers: Array = []

func _start() -> void:
	match skill_num:
		DRAIN_LIFE: _drain_life()
		CHAIN_LIGHTNING: _chain_lightning()
		THORNS: _buff_skill(Color(0.8, 0.5, 0.2), 2, true)
		BERSERKER: _buff_skill(Color(1.0, 0.1, 0.2), 0, false)
		SLEEP: _buff_skill(Color(0.8, 0.3, 0.9), 0, true)
		BLIND: _buff_skill(Color(1, 1, 1), 1, true)
		WEAKNESS: _magic_zin(Color(2.0, 0.1, 0.1), Color(2.0, 0.4, 0.3), Color(1.4, 0.2, 0.2))
		ENERVATION: _magic_zin(Color(0.25, 1.0, 0.7), Color(0.25, 1.0, 0.7), Color(0.25, 1.0, 0.7))
		SUMMON_EXPLOSION: _sahamutt()
		SUMMON_REQUIEM: _neil()
		SUMMON_POLLUTION: _lagul()
		LIGHTNING_SHOCK: _lightning_shock()

func _mu_tick(_t: int) -> void:
	for s in _movers.duplicate():
		(s["tick"] as Callable).call(s)

func bone_pos(who: Node3D, bone: int, fallback_h := 1.2) -> Vector3:
	var m = who.get("model") if is_instance_valid(who) else null
	if m != null and m.get("skeleton") != null:
		var sk := m.skeleton as Skeleton3D
		var b := sk.find_bone("b%03d" % bone)
		if b >= 0:
			return sk.global_transform * sk.get_bone_global_pose(b).origin
	return (who.global_position if is_instance_valid(who) else caster_pos()) + Vector3(0, fallback_h, 0)

func set_alpha(o: Dictionary, a: float) -> void:
	for gi in MuModelRes.find_all(o["node"], "GeometryInstance3D", []):
		(gi as GeometryInstance3D).transparency = 1.0 - clampf(a, 0.0, 1.0)

func play_action(o: Dictionary, action: int, speed: float) -> void:
	var ap := MuModelRes.find_first(o["node"], "AnimationPlayer") as AnimationPlayer
	if ap:
		MuModelRes.play(ap, action, speed, false, true)

func decal(bitmap: String, pos: Vector3, size: float, color: Color, life: float, rspeed := 0.0) -> Dictionary:
	var d := particle(bitmap, pos + Vector3(0, 0.05, 0), {"size": size, "life": life, "color": color,
		"rspeed": rspeed, "fade": false})
	if not d.is_empty():
		d["flat"] = true
	return d

# ------------------------------------------------------------------ 214 Drain Life
## MODEL_ALICE_DRAIN_LIFE (LifeTime 70): mỗi tick 0..2 hạt BITMAP_LIGHT+2 đỏ (1,0.2,0.2) Scale 1.8 trên thân người dùng ;
## từ LifeTime 60 thêm trên thân mục tiêu ; đầu đời một dòng sinh lực đỏ chảy từ mục tiêu về người dùng
func _drain_life() -> void:
	_movers.append({"life": 70, "tick": _drain_tick})
	_min_ticks = 70
	impact_delay = 0.3

func _drain_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		return
	var r := rnd(10)
	var cnt := 0 if r == 0 else (1 if r <= 7 else 2)
	var red := Color(1.0, 0.2, 0.2)
	for i in cnt:
		var p := caster_pos() + mu(Vector3(rnd(80) - 40, rnd(60) - 30, 80 + rnd(180) - 100))
		particle("BITMAP_LIGHT+2", p, {"size": 0.64 * 1.8 * 0.5, "life": 15, "color": red, "vel": Vector3(0, 0.01, 0)})
		if int(s["life"]) <= 60 and is_instance_valid(target):
			var q := target.global_position + mu(Vector3(rnd(80) - 40, rnd(60) - 30, 80 + rnd(180) - 100))
			particle("BITMAP_LIGHT+2", q, {"size": 0.64 * 1.8 * 0.5, "life": 15, "color": red, "vel": Vector3(0, 0.01, 0)})
	if int(s["life"]) >= 52 and is_instance_valid(target):
		var a := target.global_position + Vector3(0, 1.0, 0)
		var b := caster_pos() + Vector3(0, 1.0, 0)
		for k in 2:
			var from := a + Vector3(randf_range(-0.3, 0.3), randf_range(-0.4, 0.4), randf_range(-0.3, 0.3))
			particle("BITMAP_LIGHT+2", from, {"size": 0.35, "life": 12, "color": red, "vel": (b - from) / 12.0})

# ------------------------------------------------------------------ 215 Chain Lightning
## MODEL_CHAIN_LIGHTNING (LifeTime 20) SubType 0 từ xương tay 37 và 28 của người dùng, SubType 1, 2 nối tiếp
## sang mục tiêu kế ; mỗi tick 4 tia BITMAP_JOINT_THUNDER (Scale 50 và 10, xanh (0.4,0.4,1))
func _chain_lightning() -> void:
	var chain: Array = []
	if is_instance_valid(target):
		chain.append(target)
		var last: Node3D = target
		for k in 2:
			var best: Node3D = null
			var bd := 4.0
			for c in caster.get_parent().get_children():
				if c is MuMonster and not c.is_dead and not chain.has(c):
					var d := (c as Node3D).global_position.distance_to(last.global_position)
					if d < bd:
						bd = d
						best = c
			if best == null:
				break
			chain.append(best)
			last = best
	_movers.append({"life": 20, "chain": chain, "tick": _chain_tick})
	_min_ticks = 20
	impact_delay = 0.2

func _chain_tick(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		return
	var light := Color(0.4, 0.4, 1.0)
	var src: Array = [bone_pos(caster, 37), bone_pos(caster, 28)]
	var prev: Node3D = caster
	for i in (s["chain"] as Array).size():
		var t: Node3D = s["chain"][i]
		if not is_instance_valid(t):
			break
		var to := t.global_position + Vector3(0, 0.9, 0)
		var froms: Array = src if i == 0 else [prev.global_position + Vector3(0, 0.9, 0)]
		for f in froms:
			bolt("BITMAP_JOINT_THUNDER", f, to, 0.5, light, 2, 0.3, 0.4)
			bolt("BITMAP_JOINT_THUNDER", f, to, 0.1, Color(0.8, 0.8, 1.0), 2, 0.3, 0.4)
		prev = t

# ------------------------------------------------------------------ 217..220 Thorns / Berserker / Sleep / Blind
## BITMAP_MAGIC+1 SubType 11 dưới chân người dùng (màu theo skill) ;
## MODEL_ALICE_BUFFSKILL_EFFECT (elshildring, Scale 0.1, LifeTime 34) + EFFECT2 (elshildring2, Scale 0.15, LifeTime 35)
## ở cao +100 trên mục tiêu (Berserker: chính mình), lớn dần 0.035/tick, xoay ±8°/tick, hiện dần 0.05/tick rồi tắt
## sau LifeTime 20 ; mỗi tick 2 sprite BITMAP_LIGHT Scale 5 cùng màu
func _buff_skill(light: Color, sub: int, on_target: bool) -> void:
	decal("BITMAP_MAGIC+1", caster_pos(), 2.6, light, 20, 6)
	var who: Node3D = target if on_target and is_instance_valid(target) else caster
	var sub_col := {0: Color(0.8, 0.1, 0.9), 1: Color(1, 1, 1), 2: Color(0.8, 0.5, 0.2)}
	if skill_num == BERSERKER:
		sub_col[0] = light
	for spec in [["Effect/elshildring", 0.1, 34, 8.0], ["Effect/elshildring2", 0.15, 35, -8.0]]:
		var o := model(spec[0], who.global_position + mu(Vector3(0, 0, 100)), {"scale": spec[1], "life": spec[2],
			"blend_mesh": -2, "light": 0.0, "color": light})
		o["alpha"] = 0.0
		var spin: float = spec[3]
		var main: bool = spec[0] == "Effect/elshildring"
		var col: Color = sub_col[sub]
		o["update"] = func(ob, dt):
			if is_instance_valid(who):
				ob["pos"] = who.global_position + mu(Vector3(0, 0, 100))
			var al := float(ob["alpha"])
			al = al + 0.05 * dt if float(ob["life"]) > 20.0 else al - 0.05 * dt
			ob["alpha"] = al
			if al < 0.0:
				ob["dead"] = true
			ob["light"] = maxf(0.0, al)
			var a: Vector3 = ob["ang"]
			a.z += spin * dt
			ob["ang"] = a
			ob["scale"] = float(ob["scale"]) + 0.035 * dt
			if main and fmod(float(ob["age"]), 1.0) < dt:
				sprite("BITMAP_LIGHT", ob["pos"], 5.0 * 0.5, col * maxf(0.0, al))
	impact_delay = 0.1

# ------------------------------------------------------------------ 221 Weakness / 222 Innovation (Enervation)
## BITMAP_MAGIC_ZIN (mzine_typer2, vẽ trên mặt đất): SubType 1 Scale 7 (sáng tối đa 0.7, /2.5), SubType 0 Scale 2
## (x2), 3 x SubType 2 Scale 1 / 0.2 / 0.1 lớn dần 0.1/tick tới 3.5 ; hiện dần 0.05/tick, tắt dần sau LifeTime 20 ;
## Suhwanzin2 / 22 / 222 (Scale 0.6, LifeTime 40) ; BITMAP_SHINY+6 và BITMAP_PIN_LIGHT bay lên trong vùng 500
func _magic_zin(c_big: Color, c_mid: Color, c_spark: Color) -> void:
	var p := caster_pos()
	_zin(p, 1, 7.0, 40, c_big)
	_zin(p, 0, 2.0, 50, c_mid)
	for sc in [1.0, 0.2, 0.1]:
		_zin(p, 2, sc, 30, c_mid)
	for name in ["Effect/Suhwanzin2", "Effect/Suhwanzin22", "Effect/Suhwanzin222"]:
		var o := model(name, p, {"scale": 0.6, "life": 40, "blend_mesh": -2, "light": 0.0, "color": c_mid * 0.5,
			"ang": Vector3(0, 0, caster_yaw())})
		o["update"] = func(ob, _dt):
			var lt := float(ob["life"])
			ob["light"] = minf(1.0, (40.0 - lt) / 10.0) if lt > 20.0 else lt / 20.0
	_movers.append({"life": 40, "p": p, "c": c_spark, "tick": _zin_sparks})
	_min_ticks = 50
	impact_delay = 0.4

func _zin(p: Vector3, sub: int, scale: float, life: float, c: Color) -> void:
	var d := decal("BITMAP_MAGIC_ZIN", p, scale * 1.2, c, life)
	if d.is_empty():
		return
	d["alpha"] = 0.0
	d["zsub"] = sub
	d["base"] = c
	_movers.append({"d": d, "tick": _zin_tick})

func _zin_tick(s: Dictionary) -> void:
	var d: Dictionary = s["d"]
	if not _parts.has(d):
		_movers.erase(s)
		return
	var sub := int(d["zsub"])
	var al := float(d["alpha"])
	var lt := float(d["life"])
	if sub == 1:
		al = al - 0.03 if lt < 20.0 else (al + 0.06 if al < 0.7 else al)
	else:
		al = al - 0.05 if lt < 20.0 else (al + 0.05 if al < 1.0 else al)
		if sub == 2 and float(d["size"]) < 3.5 * 1.2:
			d["size"] = float(d["size"]) + 0.1 * 1.2
	d["alpha"] = al
	var mult := 2.0 if sub == 0 else (1.0 / 2.5 if sub == 1 else 1.0)
	var b: Color = d["base"]
	d["color"] = Color(b.r * al * mult, b.g * al * mult, b.b * al * mult)

func _zin_sparks(s: Dictionary) -> void:
	s["life"] = int(s["life"]) - 1
	if int(s["life"]) <= 0:
		_movers.erase(s)
		return
	if rnd(2) == 0:
		for bm in ["BITMAP_SHINY+6", "BITMAP_PIN_LIGHT"]:
			var q: Vector3 = (s["p"] as Vector3) + mu(Vector3(rnd(500) - 250, rnd(500) - 250, 150 - rnd(100)))
			particle(bm, q, {"size": 0.5, "life": 20, "color": s["c"], "vel": Vector3(0, 0.03, 0)})

# ------------------------------------------------------------------ 223 Explosion (Sahamutt)
## MODEL_SUMMONER_SUMMON_SAHAMUTT (LifeTime 80, Scale 0.35, Velocity 0.5): xuất hiện lệch 150..450 quanh người dùng,
## hiện dần, quay về ô mục tiêu ; hành động 1: khung 4..10 lao tới (Distance/13 mỗi tick), khung 11+ mờ nhanh ;
## LifeTime < 20 về hành động 0 và tắt dần
func _sahamutt() -> void:
	var p := caster_pos() + mu(Vector3((rnd(300) + 150) * (1 if rnd(2) == 0 else -1), (rnd(300) + 150) * (1 if rnd(2) == 0 else -1), 0))
	p.y = ground(p)
	var to := target_pos()
	to.y = ground(to)
	var o := model("Skill/summon_sahamutt", p, {"scale": 0.35, "life": 80, "blend_mesh": -1,
		"ang": Vector3(0, 0, yaw_to(p, to))})
	o["alpha"] = 0.0
	o["to"] = to
	o["dist"] = Vector2(to.x - p.x, to.z - p.z).length()
	o["act"] = 0
	o["frame"] = 0.0
	set_alpha(o, 0.0)
	o["update"] = func(ob, dt):
		var al := float(ob["alpha"])
		if float(ob["life"]) < 20.0:
			al -= 0.05 * dt
		elif int(ob["act"]) == 0 and al < 0.3:
			al += 0.05 * dt
		else:
			if int(ob["act"]) == 0:
				ob["act"] = 1
				play_action(ob, 1, 0.5)
			ob["frame"] = minf(12.0, float(ob["frame"]) + 0.5 * dt)
			var fr := float(ob["frame"])
			if fr >= 11.0:
				al = maxf(0.0, al - 0.3 * dt)
			elif fr < 3.0 and al < 0.7:
				al += 0.05 * dt
			if fr > 4.0 and fr < 12.0:
				var step := float(ob["dist"]) / (13.0 if fr < 10.0 else 45.0)
				ob["pos"] = (ob["pos"] as Vector3) + rot(Vector3(0, -step * 100.0, 0), ob["ang"]) * dt
				var q: Vector3 = ob["pos"]
				q.y = ground(q)
				ob["pos"] = q
			if fr >= 10.0 and not ob.has("boom"):
				ob["boom"] = true
				var t: Vector3 = ob["to"]
				particle("BITMAP_EXPLOTION", t + Vector3(0, 0.8, 0), {"size": 2.5, "life": 20, "sheet": Vector2i(4, 4), "fade": false})
				for k in 6:
					particle("BITMAP_FIRE", t + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.8, 0.8)),
						{"size": 0.9, "life": 16, "sheet": Vector2i(4, 1), "vel": Vector3(0, 0.03, 0)})
		ob["alpha"] = al
		set_alpha(ob, al)
	impact_delay = 1.0

# ------------------------------------------------------------------ 224 Requiem (Neil)
## MODEL_SUMMONER_SUMMON_NEIL (LifeTime 80, Velocity 0.35, cao +10) trước mặt 100 ; hiện dần 0.04/tick ;
## khung > 8: dao nelleff_nife01..03 tại mục tiêu ; khung > 10: vết nell_nifegrund01..03 tại mục tiêu và trước Neil
func _neil() -> void:
	var a := Vector3(0, 0, caster_yaw())
	var p := caster_pos() + rot(Vector3(0, -100, 10), a)
	var o := model("Skill/summon_neil", p, {"ang": Vector3(0, 0, yaw_to(p, target_pos())), "life": 80, "blend_mesh": -1,
		"anim_speed": 0.35})
	o["alpha"] = 0.0
	o["frame"] = 0.0
	o["stage"] = 0
	set_alpha(o, 0.0)
	o["update"] = func(ob, dt):
		var al := float(ob["alpha"])
		al = al - 0.05 * dt if float(ob["life"]) < 20.0 else minf(0.7, al + 0.04 * dt)
		ob["alpha"] = al
		set_alpha(ob, al)
		ob["frame"] = float(ob["frame"]) + 0.35 * dt
		var t := target_pos()
		if float(ob["frame"]) > 8.0 and int(ob["stage"]) == 0:
			ob["stage"] = 1
			for n in ["Skill/nelleff_nife01", "Skill/nelleff_nife02", "Skill/nelleff_nife03"]:
				var k := model(n, t, {"ang": ob["ang"], "life": 30, "blend_mesh": -3})
				k["update"] = func(kb, _d2): set_alpha(kb, minf(1.0, float(kb["life"]) / 10.0))
		if float(ob["frame"]) > 10.0 and int(ob["stage"]) == 1:
			ob["stage"] = 2
			var front: Vector3 = (ob["pos"] as Vector3) + rot(Vector3(0, -60, 0), ob["ang"])
			for spot in [front, t]:
				for n in ["Skill/nell_nifegrund01", "Skill/nell_nifegrund02", "Skill/nell_nifegrund03"]:
					var g := model(n, spot, {"ang": ob["ang"], "life": 40, "blend_mesh": -3})
					g["update"] = func(gb, _d2): set_alpha(gb, minf(1.0, float(gb["life"]) / 10.0))
				if spot == front:
					break
	impact_delay = 1.2

# ------------------------------------------------------------------ 225 Pollution (Lagul)
## MODEL_SUMMONER_SUMMON_LAGUL tại ô mục tiêu (LifeTime 160): Lagul hiện dần 16 tick đầu, tắt dần 30 tick cuối ;
## mỗi vài tick khói BITMAP_SMOKE Scale 3.5 trong vùng 500, mây BITMAP_CLOUD tím (0.6,0.1,1) ;
## 2 tia BITMAP_JOINT_SPIRIT (Scale 100 / 20) xoáy quanh
func _lagul() -> void:
	var p := target_pos()
	p.y = ground(p)
	var o := model("Skill/summon_lagul", p, {"life": 160, "blend_mesh": -1, "ang": Vector3(0, 0, caster_yaw())})
	set_alpha(o, 0.0)
	o["update"] = func(ob, dt):
		var lt := float(ob["life"])
		var al := 1.0
		if lt < 30.0:
			al = lt / 40.0
		elif lt > 144.0:
			al = (160.0 - lt) / 20.0
		set_alpha(ob, al)
		if fmod(float(ob["age"]), 1.0) < dt and rnd(4) == 0:
			var q := p + mu(Vector3(rnd(500) - 250, rnd(500) - 250, 0))
			particle("BITMAP_SMOKE", q + Vector3(0, 0.4, 0), {"size": 2.2, "grow": 1.02, "life": 30, "color": Color(0.5, 0.4, 0.6),
				"vel": Vector3(0, 0.01, 0)})
			var c := p + mu(Vector3(rnd(400) - 200, rnd(400) - 200, 50))
			particle("BITMAP_CLOUD", c, {"size": 2.0, "life": 30, "color": Color(0.6, 0.1, 1.0), "rspeed": 3})
	for sc in [100.0, 20.0]:
		var r := ribbon("BITMAP_JOINT_SPIRIT", p + Vector3(0, 1, 0), {"width": sc / 100.0, "max_tails": 8, "life": 60,
			"color": Color(0.6, 0.3, 0.9)})
		_movers.append({"r": r, "c": p, "ph": rnd(360), "tick": _lagul_spirit})
	_min_ticks = 160
	impact_delay = 0.8

func _lagul_spirit(s: Dictionary) -> void:
	var r: Dictionary = s["r"]
	if not _ribbons.has(r):
		_movers.erase(s)
		return
	s["ph"] = float(s["ph"]) + 20.0
	var ph := deg_to_rad(float(s["ph"]))
	r["head"] = (s["c"] as Vector3) + Vector3(cos(ph) * 1.5, 1.0 + sin(ph * 0.7) * 0.5, sin(ph) * 1.5)
	ribbon_push(r)

# ------------------------------------------------------------------ 230 Lightning Shock
## MODEL_LIGHTNING_SHOCK SubType 0 (LifeTime 20, cao +280): quả cầu đỏ (sprite BITMAP_SHINY+1, BITMAP_MAGIC,
## BITMAP_PIN_LIGHT, 11 đốm BITMAP_LIGHT) ; khung > 6 lao xuống phía trước Direction (0,-20,-75-v) tăng tốc ;
## chạm đất: SubType 1 — 2 BITMAP_DAMAGE_01_MONO, 5 vòng BITMAP_MAGIC bán kính 150, 3 knight_plancrack_a
func _lightning_shock() -> void:
	var a := Vector3(0, 0, caster_yaw())
	var o := model("Skill/Stone01", caster_pos() + mu(Vector3(0, 0, 280)), {"ang": a, "life": 40, "light": 0.0})
	(o["node"] as Node3D).visible = false
	o["v"] = 0.0
	o["g"] = 1.0
	o["update"] = func(ob, dt):
		if float(ob["age"]) > 6.0:
			ob["dir"] = Vector3(0, -20, -75 - float(ob["v"]))
			ob["g"] = float(ob["g"]) + 0.1 * dt
			ob["v"] = float(ob["v"]) + float(ob["g"]) * dt
		if fmod(float(ob["age"]), 1.0) < dt:
			var q: Vector3 = ob["pos"]
			sprite("BITMAP_SHINY+1", q, 4.0 * 0.8, Color(1, 0.4, 0.4), _t * 8.0)
			sprite("BITMAP_MAGIC", q, 0.8, Color(1, 0.2, 0.2), _t * 8.0)
			sprite("BITMAP_PIN_LIGHT", q, 1.6, Color(1, 0.4, 0.4), rnd(360))
			for i in 5:
				sprite("BITMAP_LIGHT", q + mu(Vector3(rnd(70) - 35, rnd(70) - 35, rnd(70) - 35)), 1.1, Color(1, 0.2, 0.1))
		var q2: Vector3 = ob["pos"]
		if q2.y < ground(q2):
			q2.y = ground(q2)
			ob["pos"] = q2
			ob["dead"] = true
	o["on_end"] = func(ob):
		var q: Vector3 = ob["pos"]
		particle("BITMAP_DAMAGE_01_MONO", q + Vector3(0, 0.5, 0), {"size": 2.5, "life": 12, "color": Color(1, 0.8, 0.5)})
		particle("BITMAP_DAMAGE_01_MONO", q + Vector3(0, 0.5, 0), {"size": 2.0, "life": 12, "color": Color(1, 0, 0)})
		for i in 5:
			var r := q + rot(Vector3(0, 150, 0), Vector3(0, 0, caster_yaw() + i * 72.0))
			decal("BITMAP_MAGIC", r, 1.2, Color(1, 0.2, 0.05), 20, 10)
		for i in 3:
			# RenderObject với Light (1,0.4,0.2): texture grandmark2/lines2 là jpg nền đen -> vết nứt phát sáng
			var c := model("Effect/knight_plancrack_a", q, {"ang": Vector3(0, 0, rnd(360)), "life": 20,
				"scale": rnd(4) * 0.1 + 1.0, "blend_mesh": -2, "color": Color(1.0, 0.4, 0.2)})
			c["update"] = func(cb, _d2): cb["light"] = minf(1.0, float(cb["life"]) / 8.0)
	impact_delay = 0.6
