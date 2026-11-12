extends Node3D
class_name MuFx

## Bộ hàm dùng chung cho hiệu ứng skill PORT TAY từ client gốc (ZzzEffect*.cpp, MoveHandlers.cpp).
## Mô phỏng hệ đối tượng hiệu ứng của MU, chạy theo tick 25/s:
##   model()    CreateEffect(MODEL_*)   : model .glb, bay theo Direction xoay theo Angle (MoveParticle),
##                                        BlendMesh cộng sáng, BlendMeshLight, BlendMeshTexCoordU
##   particle() CreateParticle(BITMAP_*) : billboard có vận tốc, trọng lực, lớn dần, mờ dần, xoay
##   sprite()   CreateSprite(BITMAP_*)   : billboard sống 1 tick (Width = cỡ texture * Scale đơn vị MU)
##   ribbon()   CreateJoint(BITMAP_*)    : vệt có đuôi (MaxTails) bám theo một đầu di chuyển
##   bolt()     tia sét zigzag từ A tới B (BITMAP_JOINT_THUNDER)
## Đơn vị: 100 đơn vị MU = 1 m ; trục MU (x, y, z) -> Godot (x, z, -y) ; góc MU tính bằng độ.
## Lớp con override _start() và _mu_tick(t: int).

const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const TICK := 1.0 / 25.0

var caster: Node3D = null
var target: Node3D = null
var skill_num := 0

var _t := 0.0          # số tick đã trôi qua
var _acc := 0.0
var _tick_no := 0
var _min_ticks := 1    # sống ít nhất bao nhiêu tick (lớp con đặt)
var _objs: Array = []  # model
var _parts: Array = [] # particle / sprite
var _ribbons: Array = []
var _blurs: Array = []

static var _quad: QuadMesh = null
static var _mats: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _bitmaps: Dictionary = {}

func setup_skill(p_caster: Node3D, p_target: Node3D, num: int) -> void:
	caster = p_caster
	target = p_target
	skill_num = num

## Thời điểm (giây) gây sát thương — MuSkillFx đọc sau khi add_child
var impact_delay := 0.35

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_start()

func _start() -> void:
	pass

func _mu_tick(_tick: int) -> void:
	pass

func _process(delta: float) -> void:
	var dt := delta / TICK
	_t += dt
	_acc += dt
	while _acc >= 1.0:
		_acc -= 1.0
		_mu_tick(_tick_no)
		_tick_no += 1
	_update_objs(dt)
	_update_parts(dt)
	_update_ribbons(dt)
	_update_blurs(dt)
	if _tick_no >= _min_ticks and _objs.is_empty() and _parts.is_empty() and _ribbons.is_empty() and _blurs.is_empty():
		queue_free()

# ================================================================== toạ độ

static func mu(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y) / 100.0

static func basis(a: Vector3) -> Basis:
	return MuCharModelRes._mu_matrix_to_transform([a.x, a.y, a.z], Vector3.ZERO).basis

## VectorRotate(v, AngleMatrix(a)) đổi sang Godot (m)
static func rot(v: Vector3, a: Vector3) -> Vector3:
	return basis(a) * mu(v)

static func ground(p: Vector3) -> float:
	return MuTerrain.height_at(p.x, -p.z)

func caster_pos() -> Vector3:
	return caster.global_position if is_instance_valid(caster) else Vector3.ZERO

func target_pos() -> Vector3:
	if is_instance_valid(target):
		return target.global_position
	return caster_pos() + rot(Vector3(0, -300, 0), Vector3(0, 0, caster_yaw()))

## Angle[2] của người dùng (độ, MU)
func caster_yaw() -> float:
	return rad_to_deg(caster.rotation.y) if is_instance_valid(caster) else 0.0

## Góc nhìn từ a tới b theo kiểu MU (CreateAngle2D): yaw độ
static func yaw_to(a: Vector3, b: Vector3) -> float:
	var d := b - a
	return rad_to_deg(atan2(d.x, d.z))

static func rnd(n: int) -> int:
	return randi() % maxi(n, 1)

# ================================================================== texture / vật liệu

static func tex(bitmap: String) -> Texture2D:
	if _tex_cache.has(bitmap):
		return _tex_cache[bitmap]
	if _bitmaps.is_empty():
		_bitmaps = MuSkillFx.data().get("bitmaps", {})
	var stem := str(_bitmaps.get(bitmap, bitmap))
	var t: Texture2D = null
	for p in ["res://assets/mu/fx/skill/%s.jpg", "res://assets/mu/fx/skill/%s.png", "res://assets/mu/fx/%s.jpg"]:
		if ResourceLoader.exists(p % stem):
			t = load(p % stem)
			break
	if t == null:
		# Chưa thấy texture: thử lại vài lần (gói có thể vừa nạp xong) rồi mới nhớ là thiếu.
		_tex_miss[bitmap] = int(_tex_miss.get(bitmap, 0)) + 1
		if int(_tex_miss[bitmap]) == 1:
			push_warning("MuFx: thiếu texture hiệu ứng '%s' (%s)" % [bitmap, stem])
		if int(_tex_miss[bitmap]) < 4:
			return null
	_tex_cache[bitmap] = t
	return t

static var _tex_miss := {}

## blend: "add" (cộng sáng), "sub" (RENDER_TYPE_ALPHA_BLEND_MINUS: làm tối), "alpha"
static func mat(bitmap: String, blend := "add") -> StandardMaterial3D:
	var key := bitmap + "|" + blend
	if _mats.has(key):
		return _mats[key]
	var _t := tex(bitmap)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = {"add": BaseMaterial3D.BLEND_MODE_ADD, "sub": BaseMaterial3D.BLEND_MODE_SUB}.get(blend, BaseMaterial3D.BLEND_MODE_MIX)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _t
	if _t == null:
		# Không có texture thì quad cộng sáng thành ô trắng mờ -> ẩn hẳn, không lưu cache để lần sau thử lại.
		m.albedo_color = Color(1, 1, 1, 0)
		return m
	_mats[key] = m
	return m

# ================================================================== model (CreateEffect MODEL_*)

## opts: ang (Vector3 độ MU), dir (Vector3 đơn vị MU/tick theo khung Angle), scale, life (tick),
##       blend_mesh (-2 tất cả cộng sáng, -1 không, n = mesh thứ n, -3 tự chọn theo texture), light (BlendMeshLight),
##       color, anim_speed, gravity (đơn vị MU/tick, cộng vào độ cao mỗi tick)
func model(glb: String, pos: Vector3, opts: Dictionary = {}) -> Dictionary:
	var node := MuModelRes.instantiate("res://assets/mu/%s.glb" % glb)
	var o := {"node": node, "pos": pos, "ang": opts.get("ang", Vector3.ZERO), "dir": opts.get("dir", Vector3.ZERO),
		"scale": float(opts.get("scale", 1.0)), "life": float(opts.get("life", 20)), "light": float(opts.get("light", 1.0)),
		"color": opts.get("color", Color(1, 1, 1)), "uv": 0.0, "gravity": float(opts.get("gravity", 0.0)),
		"mats": [], "age": 0.0}
	if node == null:
		o["node"] = Node3D.new()
		add_child(o["node"])
	else:
		add_child(node)
		_model_materials(o, int(opts.get("blend_mesh", -2)), int(opts.get("hide_mesh", -1)))
		var ap := MuModelRes.find_first(node, "AnimationPlayer") as AnimationPlayer
		if ap and ap.get_animation_list().size() > 0:
			var a := ap.get_animation_list()[0]
			ap.play(a)
			ap.speed_scale = float(opts.get("anim_speed", 1.0))
	_objs.append(o)
	_place(o)
	return o

func _model_materials(o: Dictionary, blend_mesh: int, hide_mesh: int = -1) -> void:
	var i := 0
	for n in MuModelRes.find_all(o["node"], "MeshInstance3D", []):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var additive := blend_mesh == -2 or blend_mesh == i
			if blend_mesh == -3:
				# tự chọn: texture jpg (không alpha) hoặc hậu tố _R -> cộng sáng ; tga/png (có alpha) -> trộn alpha
				var path := src.albedo_texture.resource_path.to_lower() if src and src.albedo_texture else ""
				additive = path.ends_with(".jpg") or MuModelRes.mesh_script(MuModelRes.tex_stem(src)) == "bright"
			if i == hide_mesh:
				# HiddenMesh của MU: mesh này không vẽ
				var hm := StandardMaterial3D.new()
				hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				hm.albedo_color = Color(1, 1, 1, 0)
				hm.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(s, hm)
				i += 1
				continue
			var m := StandardMaterial3D.new()
			m.albedo_texture = src.albedo_texture if src else null
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			if additive:
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				o["mats"].append(m)
			else:
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if blend_mesh == -3 else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				if blend_mesh == -3:
					m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
					o["mats"].append(m)
			mi.set_surface_override_material(s, m)
			i += 1

func _place(o: Dictionary) -> void:
	var node := o["node"] as Node3D
	node.global_transform = Transform3D(basis(o["ang"]).scaled(Vector3.ONE * float(o["scale"])), o["pos"])
	var c: Color = o["color"]
	var l := clampf(float(o["light"]), 0.0, 4.0)
	for m in o["mats"]:
		(m as StandardMaterial3D).albedo_color = Color(c.r * l, c.g * l, c.b * l, 1.0)
		(m as StandardMaterial3D).uv1_offset = Vector3(float(o["uv"]), 0, 0)

func _update_objs(dt: float) -> void:
	for o in _objs.duplicate():
		o["life"] -= dt
		o["age"] += dt
		if o["life"] <= 0.0 or o.get("dead", false):
			kill_obj(o)
			continue
		var d: Vector3 = o["dir"]
		if d != Vector3.ZERO:
			o["pos"] += rot(d, o["ang"]) * dt
		if float(o["gravity"]) != 0.0:
			o["pos"] += Vector3(0, float(o["gravity"]) / 100.0 * dt, 0)
		if o.has("update"):
			(o["update"] as Callable).call(o, dt)
		_place(o)

func kill_obj(o: Dictionary) -> void:
	if o.has("on_end") and not o.get("ended", false):
		o["ended"] = true
		(o["on_end"] as Callable).call(o)
	var node := o["node"] as Node3D
	if is_instance_valid(node):
		MuModelRes.cleanup_geometry(node)
		node.queue_free()
	_objs.erase(o)

# ================================================================== hạt / sprite

func _quad_mi(bitmap: String, blend: String) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = mat(bitmap, blend)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## opts: vel (m/tick), grav (m/tick², âm = rơi), life (tick), size (m), grow (nhân mỗi tick),
##       color, fade (true: mờ dần), rot (độ), rspeed (độ/tick), blend, floor (dừng ở mặt đất),
##       sheet (Vector2i cột x hàng: texture nhiều khung, chạy hết các khung trong đời hạt),
##       frames (số khung thật nếu ít hơn cột x hàng)
func particle(bitmap: String, pos: Vector3, opts: Dictionary = {}) -> Dictionary:
	if tex(bitmap) == null:
		return {}
	var p := {"mi": _quad_mi(bitmap, str(opts.get("blend", "add"))), "pos": pos,
		"vel": opts.get("vel", Vector3.ZERO), "grav": float(opts.get("grav", 0.0)),
		"life": float(opts.get("life", 20)), "max": float(opts.get("life", 20)),
		"size": float(opts.get("size", 0.5)), "grow": float(opts.get("grow", 1.0)),
		"color": opts.get("color", Color(1, 1, 1)), "fade": bool(opts.get("fade", true)),
		"rot": float(opts.get("rot", randf() * 360.0)), "rspeed": float(opts.get("rspeed", 0.0)),
		"floor": bool(opts.get("floor", false)), "drag": float(opts.get("drag", 1.0)),
		"sheet": opts.get("sheet", Vector2i.ZERO),
		# số khung thật của texture nhiều khung: Explotion01 chỉ có 10 ô (Frame = (20 - LifeTime) / 2),
		# 6 ô cuối của lưới 4x4 là nền trắng
		"frames": int(opts.get("frames", 10 if bitmap == "BITMAP_EXPLOTION" else 0))}
	_parts.append(p)
	_draw_part(p)
	return p

## CreateSprite: Width = cỡ texture (px) * Scale đơn vị MU ; sống 1 tick
func sprite(bitmap: String, pos: Vector3, scale: float, color := Color(1, 1, 1), rot_deg := 0.0) -> void:
	var t := tex(bitmap)
	if t == null:
		return
	particle(bitmap, pos, {"size": float(t.get_width()) * scale / 100.0, "life": 1.0, "color": color,
		"fade": false, "rot": rot_deg})

func _update_parts(dt: float) -> void:
	for p in _parts.duplicate():
		p["life"] -= dt
		if p["life"] <= 0.0:
			(p["mi"] as Node).queue_free()
			_parts.erase(p)
			continue
		var v: Vector3 = p["vel"]
		v.y += float(p["grav"]) * dt
		if float(p["drag"]) != 1.0:
			v *= pow(float(p["drag"]), dt)
		p["vel"] = v
		var np: Vector3 = p["pos"] + v * dt
		if p["floor"]:
			var g := ground(np)
			if np.y < g:
				np.y = g
				p["vel"] = Vector3.ZERO
		p["pos"] = np
		if float(p["grow"]) != 1.0:
			p["size"] = float(p["size"]) * pow(float(p["grow"]), dt)
		p["rot"] = float(p["rot"]) + float(p["rspeed"]) * dt
		_draw_part(p)

func _draw_part(p: Dictionary) -> void:
	var mi := p["mi"] as MeshInstance3D
	var k := clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0) if p["fade"] else 1.0
	var c: Color = p["color"]
	if p.get("flat", false):
		var r := deg_to_rad(float(p["rot"]))
		var sz := float(p["size"])
		mi.global_transform = Transform3D(Basis(Vector3(cos(r), 0, -sin(r)) * sz, Vector3(sin(r), 0, cos(r)) * sz, Vector3(0, 1, 0)), p["pos"])
	else:
		_face(mi, p["pos"], float(p["size"]), float(p["rot"]))
	_tint(mi, Color(c.r * k, c.g * k, c.b * k, 1.0))
	var sh: Vector2i = p["sheet"]
	if sh.x > 0 and sh.y > 0:
		var m := mi.material_override as StandardMaterial3D
		var n := sh.x * sh.y
		if int(p["frames"]) > 0:
			n = mini(n, int(p["frames"]))
		var f := clampi(int((1.0 - float(p["life"]) / float(p["max"])) * n), 0, n - 1)
		# thu vào 0.005 mỗi cạnh như DrawSprite gốc để không lẹm sang ô bên cạnh
		var cw := 1.0 / sh.x
		var ch := 1.0 / sh.y
		m.uv1_scale = Vector3(cw - 0.01, ch - 0.01, 1)
		m.uv1_offset = Vector3(float(f % sh.x) * cw + 0.005, float(f / sh.x) * ch + 0.005, 0)

## màu riêng từng quad (Light của hạt): mỗi quad một bản sao vật liệu
func _tint(mi: MeshInstance3D, c: Color) -> void:
	mi.set_meta("tint", c)
	var base := mi.material_override as StandardMaterial3D
	if base == null:
		return
	if not mi.has_meta("own_mat"):
		var m := base.duplicate() as StandardMaterial3D
		m.vertex_color_use_as_albedo = false
		mi.material_override = m
		mi.set_meta("own_mat", true)
	(mi.material_override as StandardMaterial3D).albedo_color = c

func _cam() -> Vector3:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	return cam.global_position if cam else Vector3(0, 100, 0)

func _face(mi: MeshInstance3D, pos: Vector3, size: float, rot_deg: float) -> void:
	var to_cam := (_cam() - pos).normalized()
	var right := Vector3.UP.cross(to_cam)
	if right.length() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := to_cam.cross(right).normalized()
	var r := deg_to_rad(rot_deg)
	var rr := right * cos(r) + up * sin(r)
	var uu := up * cos(r) - right * sin(r)
	mi.global_transform = Transform3D(Basis(rr * size, uu * size, to_cam), pos)

# ================================================================== vệt có đuôi (joint)

## opts: width (m), color, blend, max_tails, life (tick), uv_tile (lặp texture theo chiều dài)
func ribbon(bitmap: String, head: Vector3, opts: Dictionary = {}) -> Dictionary:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := mat(bitmap, str(opts.get("blend", "add"))).duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var r := {"mi": mi, "im": im, "pts": [head], "head": head, "width": float(opts.get("width", 0.3)),
		"color": opts.get("color", Color(1, 1, 1)), "max_tails": int(opts.get("max_tails", 6)),
		"life": float(opts.get("life", 20)), "max": float(opts.get("life", 20)),
		"fade": bool(opts.get("fade", true)), "uv_tile": float(opts.get("uv_tile", 1.0)),
		"fixed": bool(opts.get("fixed", false)),
		"taper": bool(opts.get("taper", true))}
	_ribbons.append(r)
	return r

## Gọi mỗi tick: ghi vị trí đầu vào đuôi (CreateTail)
func ribbon_push(r: Dictionary) -> void:
	var pts: Array = r["pts"]
	pts.insert(0, r["head"])
	while pts.size() > int(r["max_tails"]) + 1:
		pts.pop_back()

## Tia sét zigzag A -> B: điểm cố định, sống life tick
func bolt(bitmap: String, a: Vector3, b: Vector3, width: float, color: Color, life := 2.0, jitter := 0.3, seg_len := 0.5) -> Dictionary:
	var r := ribbon(bitmap, a, {"width": width, "color": color, "life": life, "fade": false, "fixed": true, "uv_tile": 4.0, "taper": false})
	var n := maxi(2, int(a.distance_to(b) / seg_len))
	var pts: Array = []
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if i > 0 and i < n:
			p += Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), randf_range(-jitter, jitter))
		pts.append(p)
	r["pts"] = pts
	return r

func _update_ribbons(dt: float) -> void:
	var cam := _cam()
	for r in _ribbons.duplicate():
		r["life"] -= dt
		if r["life"] <= 0.0:
			(r["mi"] as Node).queue_free()
			_ribbons.erase(r)
			continue
		var pts: Array = r["pts"].duplicate()
		if not r["fixed"]:
			pts[0] = r["head"]
		var im := r["im"] as ImmediateMesh
		im.clear_surfaces()
		if pts.size() < 2:
			continue
		var k := clampf(float(r["life"]) / float(r["max"]), 0.0, 1.0) if r["fade"] else 1.0
		var c: Color = r["color"]
		var taper: bool = bool(r.get("taper", true))
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := pts.size()
		for i in n:
			var p: Vector3 = pts[i]
			var nb: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			if nb.length() < 0.0001:
				nb = Vector3.UP
			var side := nb.normalized().cross((cam - p).normalized())
			if side.length() < 0.0001:
				side = Vector3.RIGHT
			var t_factor := 1.0 - float(i) / float(maxi(n - 1, 1))
			var w_scale := lerpf(0.12, 1.0, t_factor) if taper else 1.0
			side = side.normalized() * (float(r["width"]) * 0.5 * w_scale)
			var u := float(i) / (n - 1) * float(r["uv_tile"])
			var tail := (t_factor * 0.85 + 0.15) if taper else (1.0 - float(i) / n * 0.6)
			im.surface_set_color(Color(c.r * k * tail, c.g * k * tail, c.b * k * tail, 1.0))
			im.surface_set_uv(Vector2(u, 0))
			im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(u, 1))
			im.surface_add_vertex(p + side)
		im.surface_end()

# ================================================================== vệt chém vũ khí (CreateBlur)

## Vệt chém: dải nối 2 điểm trên vũ khí (p1 gần chuôi, p2 mũi) qua các mẫu gần nhất.
## sampler: Callable() -> [p1, p2] (Godot) ; chạy từ start tới stop (tick), sau đó đuôi rút dần
func blur(bitmap: String, sampler: Callable, start: float, stop: float, color := Color(1, 1, 1), max_samples := 14) -> Dictionary:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := mat(bitmap, "add").duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var b := {"mi": mi, "im": im, "s": sampler, "start": start, "stop": stop, "color": color,
		"max": max_samples, "p1": [], "p2": []}
	_blurs.append(b)
	return b

func _update_blurs(_dt: float) -> void:
	for b in _blurs.duplicate():
		var p1: Array = b["p1"]
		var p2: Array = b["p2"]
		if _t >= float(b["start"]) and _t <= float(b["stop"]):
			var pts: Array = (b["s"] as Callable).call()
			if pts.size() == 2:
				p1.insert(0, pts[0])
				p2.insert(0, pts[1])
		elif _t > float(b["stop"]) and not p1.is_empty():
			p1.pop_back()
			p2.pop_back()
			if not p1.is_empty():
				p1.pop_back()
				p2.pop_back()
		while p1.size() > int(b["max"]):
			p1.pop_back()
			p2.pop_back()
		if _t > float(b["stop"]) and p1.is_empty():
			(b["mi"] as Node).queue_free()
			_blurs.erase(b)
			continue
		var im := b["im"] as ImmediateMesh
		im.clear_surfaces()
		var n := p1.size()
		if n < 2:
			continue
		var c: Color = b["color"]
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n:
			var k := 1.0 - float(i) / (n - 1)
			var u := float(i) / (n - 1)
			im.surface_set_color(Color(c.r * k, c.g * k, c.b * k, 1.0))
			im.surface_set_uv(Vector2(u, 1))
			im.surface_add_vertex(p1[i])
			im.surface_set_uv(Vector2(u, 0))
			im.surface_add_vertex(p2[i])
		im.surface_end()

func _exit_tree() -> void:
	MuModelRes.cleanup_geometry(self)
