extends MuFx
class_name MagicGladiatorFx

## Hiệu ứng skill riêng của Magic Gladiator port tay từ client gốc (các skill phép / kiếm dùng chung
## nằm trong DarkWizardFx.gd và DarkKnightFx.gd).
## Nguồn: Engine/Object/ZzzCharacter.cpp (AttackStage Fire Slash / Power Slash / Spiral Slash, ra đòn
##        Flame Strike / Gigantic Storm / Death Cannon), Render/Effects/ZzzEffectJoint.cpp (BITMAP_JOINT_FORCE),
##        Behaviors/MoveHandlers.cpp (BITMAP_SWORD_FORCE, MODEL_MAGIC2, BITMAP_JOINT_THUNDER, MODEL_EFFECT_FLAME_STRIKE),
##        bin/Data/Effects/EffectTypes.json (khởi tạo BITMAP_JOINT_THUNDER: LifeTime 20, StartPosition +800)

const FIRE_SLASH := 55
const POWER_SLASH := 56
const SPIRAL_SLASH := 57
const MANA_RAYS := 73          # AT_SKILL_DEATH_CANNON
const FLAME_STRIKE := 236
const GIGANTIC_STORM := 237

const SKILLS := [FIRE_SLASH, POWER_SLASH, SPIRAL_SLASH, MANA_RAYS, FLAME_STRIKE, GIGANTIC_STORM]

var _arcs: Array = []
var _movers: Array = []

func _start() -> void:
	match skill_num:
		FIRE_SLASH:
			_min_ticks = 24
			impact_delay = 0.3
		POWER_SLASH: _power_slash()
		SPIRAL_SLASH:
			_min_ticks = 30
			impact_delay = 0.4
		MANA_RAYS: _mana_rays()
		FLAME_STRIKE: _flame_strike()
		GIGANTIC_STORM: _gigantic_storm()

func _mu_tick(t: int) -> void:
	match skill_num:
		FIRE_SLASH: _fire_slash_tick(t)
		SPIRAL_SLASH: _spiral_tick(t)
	_move_movers()

func hand_pos() -> Vector3:
	var m = caster.get("model") if is_instance_valid(caster) else null
	if m != null and m.get("skeleton") != null:
		var sk := m.skeleton as Skeleton3D
		var b := sk.find_bone("b%03d" % MuCharModelRes.BONE_RIGHT_HAND)
		if b >= 0:
			return sk.global_transform * sk.get_bone_global_pose(b).origin
	return caster_pos() + Vector3(0, 1.3, 0)

# ------------------------------------------------------------------ 55 Fire Slash
## tick 1..2: BITMAP_GATHERING SubType 1 tại tay (tia sét nhỏ + tia lửa hút vào, sprite BITMAP_SHINY+1) ;
## tick 3: BITMAP_SWORD_FORCE -> BITMAP_JOINT_FORCE SubType 0 (Scale 150, LifeTime 20, MaxTails 18,
##         texture motion_blur_r2): vệt bán nguyệt bán kính 180 quanh người ở cao 100, bắt đầu từ hướng nhìn +75°,
##         mỗi tick vẽ thêm 8 đoạn, mỗi đoạn quay -11°
func _fire_slash_tick(t: int) -> void:
	if t <= 2:
		var h := hand_pos()
		sprite("BITMAP_SHINY+1", h, float(rnd(8) + 8) * 0.2, Color(1, 1, 1), rnd(360))
		for j in 3:
			var from := h + rot(Vector3(0, 120, 0), Vector3(rnd(360), 0, rnd(360)))
			if t % 2 == 0:
				bolt("BITMAP_JOINT_THUNDER", from, h, 0.1, Color(0.6, 0.6, 1.0), 2, 0.08, 0.2)
			else:
				particle("BITMAP_SPARK+1", from, {"size": 0.15, "life": 5, "vel": (h - from) / 5.0})
	if t == 3:
		var c := caster_pos() + mu(Vector3(0, 0, 100))
		var r := ribbon("BITMAP_JOINT_FORCE", c, {"width": 1.5, "max_tails": 18, "life": 20,
			"color": Color(1.0, 0.8, 0.6), "uv_tile": 1.0})
		r["pts"] = []
		_arcs.append({"r": r, "c": c, "dir": caster_yaw() + 45.0 + 30.0, "n": 0})
	for a in _arcs:
		var r: Dictionary = a["r"]
		if not _ribbons.has(r):
			continue
		for j in 8:
			if int(a["n"]) >= 18:
				break
			var p: Vector3 = (a["c"] as Vector3) + rot(Vector3(0, -180, 0), Vector3(0, 0, float(a["dir"])))
			(r["pts"] as Array).insert(0, p)
			r["head"] = p
			a["dir"] = float(a["dir"]) - 11.0
			a["n"] = int(a["n"]) + 1
			if rnd(2) == 0:
				particle("BITMAP_FIRE", p, {"size": 0.5, "life": 10, "sheet": Vector2i(4, 1), "color": Color(1, 0.6, 0.3)})
		r["fixed"] = true

# ------------------------------------------------------------------ 56 Power Slash
## 5 x MODEL_MAGIC2 SubType 2 (mesh 0 ẩn) toả quạt -40..+40° (cách 20°), bay tới trước 60/tick, LifeTime 20 ;
## mỗi tick: khói (Scale 1.2..1.7), 2 sprite BITMAP_SHINY+1 (1.5), BITMAP_LIGHT (3.5) ở cao +50
func _power_slash() -> void:
	var yaw := caster_yaw()
	for i in 5:
		var a := Vector3(0, 0, yaw - 40.0 + i * 20.0)
		var o := model("Skill/Magic02", caster_pos(), {"ang": a, "dir": Vector3(0, -60, 0), "life": 20, "blend_mesh": 0})
		_hide_mesh(o, 0)
		o["update"] = func(ob, dt):
			ob["light"] = minf(1.5, float(ob["life"]) * 0.1)
			ob["uv"] = -float(ob["life"]) * 0.2
			if fmod(float(ob["age"]), 1.0) >= dt:
				return
			var q: Vector3 = ob["pos"] + mu(Vector3(0, 0, 50))
			sprite("BITMAP_SHINY+1", q, 1.5, Color(1, 1, 1), rnd(360))
			sprite("BITMAP_SHINY+1", q, 1.5, Color(1, 1, 1), rnd(360))
			sprite("BITMAP_LIGHT", q, 3.5, Color(0.3, 0.6, 1.0), rnd(360))
			particle("BITMAP_SMOKE", ob["pos"] + Vector3(0, 0.2, 0), {"size": float(rnd(32) + 80) * 0.015, "grow": 1.03,
				"life": 15, "color": Color(0.5, 0.5, 0.6), "vel": Vector3(0, 0.015, 0)})
	impact_delay = 0.3

func _hide_mesh(o: Dictionary, idx: int) -> void:
	var i := 0
	for n in MuModelRes.find_all(o["node"], "MeshInstance3D", []):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if i == idx:
				var m := StandardMaterial3D.new()
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color = Color(0, 0, 0, 0)
				mi.set_surface_override_material(s, m)
			i += 1

# ------------------------------------------------------------------ 57 Spiral Slash
## BITMAP_FLARE SubType 23 (Scale 40): khung 2.3..2.6 hai vệt, khung > 5 thêm ba vệt ; mỗi vệt xoắn tới trước,
## để lại sprite BITMAP_SHINY+1, BITMAP_LIGHT (xanh (.5,.5,1)), cuối đời nổ nhỏ BITMAP_EXPLOTION (0.6)
func _spiral_tick(t: int) -> void:
	if t == 3:
		for k in [2, 3]:
			_spiral(k)
	if t == 8:
		for k in [0, 1, 4]:
			_spiral(k)

func _spiral(k: int) -> void:
	var start := caster_pos() + mu(Vector3(0, 0, 100))
	var r := ribbon("BITMAP_FLARE", start, {"width": 0.4, "max_tails": 10, "life": 18, "color": Color(0.5, 0.5, 1.0)})
	_movers.append({"r": r, "kind": "spiral", "start": start, "yaw": caster_yaw(), "phase": k * 72.0, "age": 0.0})

func _move_movers() -> void:
	for s in _movers:
		var r: Dictionary = s["r"]
		if not _ribbons.has(r):
			continue
		s["age"] = float(s["age"]) + 1.0
		var age: float = s["age"]
		var p := Vector3.ZERO
		match s["kind"]:
			"spiral":
				var ph := deg_to_rad(float(s["phase"]) + age * 40.0)
				var fwd := age * 30.0
				p = (s["start"] as Vector3) + rot(Vector3(sin(ph) * 60.0, -fwd, cos(ph) * 60.0), Vector3(0, 0, float(s["yaw"])))
				var l := Color(0.5, 0.5, 1.0)
				sprite("BITMAP_SHINY+1", p, float(rnd(2) + 8) * 0.1, l, rnd(360))
				sprite("BITMAP_LIGHT", p, float(rnd(2) + 8) * 0.18, l, rnd(360))
				if age >= 17.0:
					particle("BITMAP_EXPLOTION", p, {"size": 256.0 * 0.6 / 100.0, "life": 12, "sheet": Vector2i(4, 4), "fade": false})
			"ray":
				# BITMAP_JOINT_FORCE SubType 4: Velocity 8 tăng dần (Direction[2] += 15.5 / 0.5), MaxTails 13
				var v := float(s["vel"])
				var acc := float(s["acc"])
				v += acc
				acc += 15.5 if float(r["life"]) >= 15.0 else 0.5
				s["vel"] = v
				s["acc"] = acc
				p = (s["pos"] as Vector3) + rot(Vector3(0, -v * 0.15, 0), Vector3(0, 0, float(s["yaw"])))
				s["pos"] = p
				var lt := Color(0.1, 0.6, 1.0)
				sprite("BITMAP_LIGHT", p, 1.6, lt)
				sprite("BITMAP_SHINY+1", p, 1.5, lt, _t * 10.0)
				particle("BITMAP_FLARE_BLUE", p, {"size": 0.5, "life": 6, "color": lt})
		r["head"] = p
		ribbon_push(r)

# ------------------------------------------------------------------ 73 Mana Rays (Death Cannon)
## BITMAP_JOINT_FORCE SubType 4 từ cao 130 theo hướng nhìn (texture Hole.jpg, LifeTime 20, MaxTails 13),
## tăng tốc dần ; mỗi tick vệt BITMAP_FLARE_BLUE, sprite BITMAP_LIGHT 1.6 + BITMAP_SHINY+1 1.5 màu (0.1,0.6,1)
func _mana_rays() -> void:
	var p := caster_pos() + mu(Vector3(0, 0, 130))
	var r := ribbon("BITMAP_HOLE", p, {"width": 0.4, "max_tails": 13, "life": 20, "color": Color(0.4, 0.7, 1.0), "uv_tile": 2.0})
	_movers.append({"r": r, "kind": "ray", "pos": p, "yaw": yaw_to(caster_pos(), target_pos()), "vel": 8.0, "acc": 1.0, "age": 0.0})
	_min_ticks = 20
	impact_delay = 0.4

# ------------------------------------------------------------------ 236 Flame Strike
## MODEL_EFFECT_FLAME_STRIKE (Effect/FlameStrike): theo tay (xương 33) của người dùng, chạy cùng animation,
## RENDER_BRIGHT, hiện dần 0.1/tick rồi tắt dần sau LifeTime 20 ; mesh 1 lật 4 khung texture lửa ;
## vệt lửa từ xương 9->6 và 8->5 trong khung 5..13
func _flame_strike() -> void:
	var a := Vector3(0, 0, caster_yaw())
	var o := model("Effect/FlameStrike", hand_pos(), {"ang": a, "life": 35, "blend_mesh": -2, "light": 0.0})
	o["update"] = func(ob, dt):
		ob["pos"] = caster_pos()
		ob["ang"] = Vector3(0, 0, caster_yaw())
		var al := float(ob.get("alpha", 0.0))
		al = al - 0.1 * dt if float(ob["life"]) < 20.0 else minf(1.0, al + 0.1 * dt)
		ob["alpha"] = al
		ob["light"] = maxf(0.0, al) * 1.2
		if al < 0.05 and float(ob["life"]) < 20.0:
			ob["dead"] = true
	impact_delay = 0.4

# ------------------------------------------------------------------ 237 Gigantic Storm
## 5 x BITMAP_JOINT_THUNDER (effect) vòng bán kính 200 quanh người, LifeTime 20, gốc sét cao 800 ;
## mỗi tick 50%: sét (Scale 10..50) từ gốc ±50 xuống điểm ±50 ; vòng BITMAP_MAGIC+1 (0.45,0.45,0.7) ;
## khói xanh tím Scale 2.8 ; đá văng
func _gigantic_storm() -> void:
	var base := caster_pos()
	for i in 5:
		var p := base + rot(Vector3(0, 200, 0), Vector3(0, 0, caster_yaw() + i * 72.0))
		p.y = ground(p)
		var o := model("Skill/Stone01", p, {"life": 20, "light": 0.0})
		(o["node"] as Node3D).visible = false
		o["update"] = func(ob, dt):
			if fmod(float(ob["age"]), 1.0) >= dt:
				return
			var q: Vector3 = ob["pos"]
			var top := q + mu(Vector3(rnd(100) - 50, rnd(100) - 50, 800))
			var bot := q + mu(Vector3(rnd(100) - 50, rnd(100) - 50, 0))
			var light := Color(0.45, 0.45, 0.7)
			if rnd(2) == 0:
				bolt("BITMAP_JOINT_THUNDER", top, bot, float(rnd(400) + 100) / 1000.0, Color(0.7, 0.7, 1.0), 3, 0.5, 0.8)
			if float(ob["life"]) > 10.0 and rnd(2) == 0:
				var m := particle("BITMAP_MAGIC+1", bot + Vector3(0, 0.05, 0), {"size": 1.6, "life": 10, "color": light})
				if not m.is_empty():
					m["flat"] = true
			if rnd(4) == 0:
				particle("BITMAP_SMOKE", bot + Vector3(0, 0.3, 0), {"size": 1.6, "grow": 1.03, "life": 20, "color": light,
					"vel": Vector3(0, 0.02, 0)})
	impact_delay = 0.4
