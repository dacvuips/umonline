extends MuFx
class_name ElfFx

## Hiệu ứng skill Elf port tay từ client gốc.
## Nguồn: Render/Effects/ZzzEffectMagicSkill.cpp (CreateArrow / CreateArrows), Render/Effects/ZzzEffect.cpp
##        (CreateHealing, MODEL_ARROW, BITMAP_MAGIC+1, BITMAP_GATHERING, MODEL_ARROW_IMPACT, MODEL_INFINITY_ARROW,
##        MODEL_MULTI_SHOT*), Engine/Object/ZzzCharacter.cpp, Network/Server/WSclient.cpp (Ice Arrow, Multi Shot)

const TRIPLE_SHOT := 24
const HEALING := 26
const DEFENSE := 27
const ATTACK := 28
const SUMMONS := [30, 31, 32, 33, 34, 35, 36]
const DEEPIMPACT := 46      # Starfall
const ICE_ARROW := 51
const PENETRATION := 52
const INFINITY_ARROW := 77
const MULTI_SHOT := 235

const SKILLS := [TRIPLE_SHOT, HEALING, DEFENSE, ATTACK, 30, 31, 32, 33, 34, 35, 36, DEEPIMPACT, ICE_ARROW,
	PENETRATION, INFINITY_ARROW, MULTI_SHOT]

## Màu tia BITMAP_JOINT_HEALING theo SubType của CreateHealing (1 hồi máu, 2 phòng thủ, 3 tấn công / triệu hồi)
const HEAL_COLOR := {1: Color(0.9, 1.0, 0.9), 2: Color(0.5, 0.7, 1.0), 3: Color(1.0, 0.5, 0.3)}

var _heal_sub := 0
var _heal_at: Node3D = null
var _joints: Array = []

func _start() -> void:
	match skill_num:
		TRIPLE_SHOT:
			for a in [0.0, 15.0, -15.0]:
				arrow(a, 0)
			impact_delay = 0.25
		HEALING: _magic_circle(1, target if is_instance_valid(target) else caster)
		DEFENSE: _magic_circle(2, target if is_instance_valid(target) else caster)
		ATTACK: _magic_circle(3, target if is_instance_valid(target) else caster)
		DEEPIMPACT: _deep_impact()
		ICE_ARROW:
			arrow(0.0, 0)
			_ice_on_target()
		PENETRATION:
			_gathering()
			_min_ticks = 6
			impact_delay = 0.4
		INFINITY_ARROW: _infinity_arrow()
		MULTI_SHOT: _multi_shot()
		_:
			if skill_num in SUMMONS:
				_magic_circle(3, caster)

func _mu_tick(t: int) -> void:
	if _heal_sub > 0 and t < 20:
		_healing_tick()
	_move_joints()
	if skill_num == PENETRATION and t == 4:
		arrow(0.0, 2)

# ------------------------------------------------------------------ mũi tên

## MODEL_ARROW (Skill/Arrow01, BlendMesh 1, LifeTime 30): xuất phát (-10,-60,135) theo hướng nhìn, bay thẳng ;
## mỗi tick để lại BITMAP_FIRE (Light (0.8,0.5,0.2)) ; SubType 2 (Penetration) bay xuyên qua mục tiêu
func arrow(yaw_off: float, sub: int, speed := 60.0) -> Dictionary:
	var to := target_pos() + Vector3(0, 1.2, 0)
	var start_yaw := yaw_to(caster_pos(), to) + yaw_off
	var a := Vector3(0, 0, start_yaw)
	var p := caster_pos() + rot(Vector3(-10, -60, 135), a)
	var o := model("Skill/Arrow01", p, {"ang": a, "dir": Vector3(0, -speed, 0), "life": 30, "blend_mesh": 1})
	var dist := Vector2(to.x - p.x, to.z - p.z).length()
	if sub != 2 and yaw_off == 0.0:
		o["life"] = minf(30.0, dist / (speed / 100.0))
	o["update"] = func(ob, dt):
		if fmod(float(ob["age"]), 1.0) < dt:
			particle("BITMAP_FIRE", ob["pos"], {"size": 0.35, "life": 8, "sheet": Vector2i(4, 1),
				"color": Color(0.8, 0.5, 0.2), "fade": true, "rot": rnd(360)})
	impact_delay = maxf(impact_delay, dist / (speed * 25.0 / 100.0))
	return o

# ------------------------------------------------------------------ Heal / Greater Defense / Greater Damage
## BITMAP_MAGIC+1 SubType 1/2/3 (LifeTime 20) tại mục tiêu: vòng phép dưới chân ;
## mỗi tick CreateHealing: 3 tia BITMAP_JOINT_HEALING (Scale 5, LifeTime 12, MaxTails 2) từ điểm cách 200
## (ngẩng 0..90°, cao +120) bay vào người ; Greater Defense thêm 5 vòng MODEL_SPEARSKILL SubType 4
## (texture flareBlue, xanh lá (.4,.8,.2)) xoay quanh người
func _magic_circle(sub: int, who: Node3D) -> void:
	_heal_sub = sub
	_heal_at = who
	var g := who.global_position + Vector3(0, 0.05, 0)
	var col: Color = HEAL_COLOR.get(sub, Color(1, 1, 1))
	var m := particle("BITMAP_MAGIC+1", g, {"size": 2.6, "life": 20, "color": col, "rspeed": 6, "fade": true})
	if not m.is_empty():
		m["flat"] = true
	if sub == 2:
		for j in 5:
			var r := ribbon("BITMAP_FLARE_BLUE", g, {"width": 0.25, "max_tails": 20, "life": 50,
				"color": Color(0.4, 0.8, 0.2)})
			_joints.append({"r": r, "kind": "orbit", "who": who, "phase": j * 72.0, "h": 0.3 + j * 0.3})
	_min_ticks = 22
	impact_delay = 0.1

func _healing_tick() -> void:
	if not is_instance_valid(_heal_at):
		return
	var c := _heal_at.global_position
	var col: Color = HEAL_COLOR.get(_heal_sub, Color(1, 1, 1))
	for j in 3:
		var a := Vector3(rnd(90), 0, rnd(360))
		var from := c - rot(Vector3(0, -200, 0), a) + mu(Vector3(0, 0, 120))
		var r := ribbon("BITMAP_JOINT_HEALING", from, {"width": 0.15, "max_tails": 3, "life": 12, "color": col})
		_joints.append({"r": r, "kind": "home", "pos": from, "to": c + Vector3(0, 1.0, 0)})

func _move_joints() -> void:
	for s in _joints:
		if not _ribbons.has(s["r"]):
			continue
		var r: Dictionary = s["r"]
		match s["kind"]:
			"home":
				var p: Vector3 = s["pos"]
				p = p.lerp(s["to"], 0.25)
				s["pos"] = p
				r["head"] = p
			"orbit":
				var who: Node3D = s["who"]
				if not is_instance_valid(who):
					continue
				s["phase"] = float(s["phase"]) + 25.0
				var ph := deg_to_rad(float(s["phase"]))
				r["head"] = who.global_position + Vector3(cos(ph) * 0.7, float(s["h"]) + sin(ph * 0.5) * 0.2, sin(ph) * 0.7)
			"line":
				s["pos"] = (s["pos"] as Vector3) + (s["vel"] as Vector3)
				r["head"] = s["pos"]
		ribbon_push(r)

# ------------------------------------------------------------------ 46 Starfall (Deep Impact)
## MODEL_ARROW_IMPACT (Skill/ArrowImpact, Scale 1.8, BlendMesh -2, Light (0.3,0.8,1), LifeTime 20):
## xuất phát (-10,-80,200), Direction (0,-30,0) tăng 8/tick, Angle[0] -30 giảm 5/tick (vút cong lên) ;
## kéo vệt BITMAP_FLASH ; cuối đời: 2 cột sáng BITMAP_FLASH từ cao 1200 phía trên mục tiêu đâm xuống
func _deep_impact() -> void:
	var to := target_pos()
	var a := Vector3(-30, 0, yaw_to(caster_pos(), to))
	var p := caster_pos() + rot(Vector3(-10, -80, 200), Vector3(0, 0, a.z))
	var o := model("Skill/ArrowImpact", p, {"ang": a, "dir": Vector3(0, -30, 0), "scale": 1.8, "life": 20,
		"blend_mesh": -2, "color": Color(0.3, 0.8, 1.0)})
	var tr := ribbon("BITMAP_FLASH", p, {"width": 0.4, "max_tails": 8, "life": 24, "color": Color(0.3, 0.8, 1.0)})
	o["trail"] = tr
	o["update"] = func(ob, dt):
		var an: Vector3 = ob["ang"]
		an.x -= 5.0 * dt
		ob["ang"] = an
		var d: Vector3 = ob["dir"]
		d.y -= 8.0 * dt
		ob["dir"] = d
		var rr: Dictionary = ob["trail"]
		rr["head"] = ob["pos"]
		if fmod(float(ob["age"]), 1.0) < dt:
			ribbon_push(rr)
	o["on_end"] = func(_ob):
		var c := target_pos()
		for k in 2:
			var top := c + mu(Vector3(rnd(100) - 50, rnd(100) - 50, 1200))
			bolt("BITMAP_FLASH", top, c, 1.0, Color(0.5, 0.8, 1.0), 10, 0.1, 2.0)
		particle("BITMAP_LIGHT", c + Vector3(0, 0.5, 0), {"size": 3.0, "life": 12, "color": Color(0.4, 0.7, 1.0)})
		particle("BITMAP_SHINY+4", c + Vector3(0, 0.3, 0), {"size": 1.5, "grow": 1.1, "life": 12, "color": Color(0.5, 0.8, 1.0)})
	impact_delay = 0.8

# ------------------------------------------------------------------ 51 Ice Arrow
## mục tiêu bị đóng băng: MODEL_ICE SubType 1 và 2 (Scale 0.8, Angle[0] -20, LifeTime 20, BlendMesh 0,
## BlendMeshLight 0.5, 3 khói) quay ngược nhau 180°
func _ice_on_target() -> void:
	if not is_instance_valid(target):
		return
	var c := target.global_position
	var yaw := rad_to_deg(target.rotation.y)
	for k in 2:
		var o := model("Skill/Ice01", c, {"ang": Vector3(-20, 0, yaw + k * 180.0), "scale": 0.8, "life": 40,
			"blend_mesh": 0, "light": 0.5})
		o["update"] = func(ob, _dt):
			if is_instance_valid(target):
				ob["pos"] = target.global_position
			ob["light"] = 0.5 * minf(1.0, float(ob["life"]) / 8.0)
	for k in 3:
		particle("BITMAP_SMOKE", c + mu(Vector3(rnd(64) - 32, rnd(64) - 32, rnd(128) + 32)),
			{"size": 0.8, "grow": 1.03, "life": 25, "color": Color(0.7, 0.8, 1.0), "vel": Vector3(0, 0.01, 0)})

# ------------------------------------------------------------------ 52 Penetration
## BITMAP_GATHERING SubType 0 (LifeTime 10): trước mặt 100, cao 150 ; mỗi tick sprite BITMAP_SHINY+1 và
## hạt BITMAP_SPARK+1 hút vào từ bán kính 120 ; rồi bắn MODEL_ARROW SubType 2 xuyên thấu
func _gathering() -> void:
	var a := Vector3(0, 0, caster_yaw())
	var c := caster_pos() + rot(Vector3(0, -100, 150), a)
	var o := model("Skill/Arrow01", c, {"life": 10, "light": 0.0})
	(o["node"] as Node3D).visible = false
	o["update"] = func(ob, dt):
		if fmod(float(ob["age"]), 1.0) >= dt:
			return
		for j in 3:
			sprite("BITMAP_SHINY+1", c, float(rnd(8) + 8) * 0.3, Color(1, 1, 1), rnd(360))
			var from := c + rot(Vector3(0, 120, 0), Vector3(rnd(360), 0, rnd(360)))
			particle("BITMAP_SPARK+1", from, {"size": 32.0 * float(rnd(50) + 10) / 100.0 / 100.0 * 6.0,
				"life": 6, "vel": (c - from) / 6.0})

# ------------------------------------------------------------------ 77 Infinity Arrow
## MODEL_INFINITY_ARROW SubType 1 (arrowsre01, Scale 1, Light 1 giảm 0.98/tick) + MODEL_INFINITY_ARROW1..4
## (arrowsre02..05, Scale mặc định 0.9, Light giảm 0.95/tick) đặt tại chân người dùng, LifeTime 40 ;
## texture jpg không alpha (SwordEffor2, macardk) -> vẽ cộng sáng
func _infinity_arrow() -> void:
	var y := caster_yaw()
	var parts := ["Skill/arrowsre01", "Skill/arrowsre02", "Skill/arrowsre03", "Skill/arrowsre04", "Skill/arrowsre05"]
	for i in parts.size():
		var decay := 0.98 if i == 0 else 0.95
		var o := model(parts[i], caster_pos(), {"ang": Vector3(0, 0, y), "life": 40, "blend_mesh": -2,
			"scale": 1.0 if i == 0 else 0.9})
		o["update"] = func(ob, _dt):
			ob["pos"] = caster_pos()
			ob["ang"] = Vector3(0, 0, caster_yaw())
			ob["light"] = pow(decay, float(ob["age"]))
	impact_delay = 0.2

# ------------------------------------------------------------------ 235 Multi Shot
## MODEL_MULTI_SHOT3 x2 (+20), MODEL_MULTI_SHOT1 x2 (tại chỗ), MODEL_MULTI_SHOT2 x2 (+20): vòng sáng lớn dần
## (Scale += 0.25 / 0.2 / 0.3 mỗi tick, BlendMeshLight = LifeTime/18), Light (0.8,0.9,1.6) ;
## MODEL_BLADE_SKILL (bladetonedo) trước mặt (0,-120,145) ; 5 mũi tên toả quạt
func _multi_shot() -> void:
	var a := Vector3(0, 0, yaw_to(caster_pos(), target_pos()))
	var light := Color(0.8, 0.9, 1.6)
	for spec in [["Effect/multishot03", Vector3(0, 20, 0), 12, 0.25], ["Effect/multishot01", Vector3.ZERO, 16, 0.2],
			["Effect/multishot02", Vector3(0, 20, 0), 13, 0.3]]:
		for k in 2:
			var o := model(spec[0], caster_pos() + rot(spec[1], a), {"ang": a, "scale": 0.0, "life": spec[2],
				"blend_mesh": -2, "color": light})
			var grow: float = spec[3]
			o["update"] = func(ob, dt):
				ob["scale"] = float(ob["scale"]) + grow * dt
				ob["light"] = float(ob["life"]) / 18.0
	var b := model("Effect/bladetonedo", caster_pos() + rot(Vector3(0, -120, 145), a), {"ang": a, "life": 20,
		"blend_mesh": -2, "color": light})
	b["update"] = func(ob, _dt): ob["light"] = minf(1.0, float(ob["life"]) / 10.0)
	for off in [-20.0, -10.0, 0.0, 10.0, 20.0]:
		arrow(off, 0)
	impact_delay = 0.3
