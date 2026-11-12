extends MeshInstance3D
class_name MuCloth

## Vải vật lý của MU — port nguyên CPhysicsCloth / CPhysicsVertex / CPhysicsColSphere (Engine/Physics/PhysicsManager.cpp).
## Áo choàng Dark Lord / Rage Fighter KHÔNG phải model tĩnh: game gốc dựng một lưới hạt (iNumHor x iNumVer) treo vào
## một xương, mỗi khung chạy Move2(0.005, 5): lực gió + trọng lực + lò xo, đẩy ra khỏi các cầu va chạm quanh thân,
## giữ độ dài mắt lưới; rồi vẽ lưới bằng texture KHÔNG chiếu sáng (màu đỉnh = cloak.light = 1,1,1).
## Mô phỏng chạy trong toạ độ thế giới MU (đơn vị MU, trục z hướng lên): mu = (x, -z, y) * 100 của Godot.

# ---- cờ PCT_* (PhysicsManager.h)
const PCT_FLAT := 0x0
const PCT_CURVED := 0x1
const PCT_STICKED := 0x2
const PCT_MASK_SHAPE := 0x3
const PCT_SHORT_SHOULDER := 0x4
const PCT_CYLINDER := 0x8
const PCT_MASK_SHAPE_EXT := 0xC
const PCT_COTTON := 0x0
const PCT_RUBBER := 0x100
const PCT_RUBBER2 := 0x200
const PCT_MASK_ELASTIC := 0x300
const PCT_HEAVY := 0x400
const PCT_MASK_WEIGHT := 0xC00
const PCT_MASK_BLIT := 0x0
const PCT_MASK_ALPHA := 0x1000
const PCT_MASK_BLEND := 0x2000
const PCT_MASK_DRAW := 0x3000
const PCT_ELASTIC_RAGE_L := 0x8000
const PCT_ELASTIC_RAGE_R := 0xC000
const PCT_MASK_ELASTIC_EXT := 0xE000
const PCT_MASK_LIGHT := 0x40000000

const PLS_LOOSEDISTANCE := 0x1
const PLS_SPRING := 0x2
const PLS_STRICTDISTANCE := 0x4

const RATE_SHORT_SHOULDER := 0.6
const GRAVITY := 9.8
const MASS := 0.0025
const INV_MASS := 400.0
const REFERENCE_FPS := 25.0

## Gió chung (CPhysicsManager::s_fWind): đi ngẫu nhiên trong [-0.2, 1], cập nhật mỗi khung
static var s_wind := 0.0
static var _wind_frame := -1

var model: Node3D            # MuCharacterModel sở hữu
var bone := 19
var fx := 0.0
var fy := 0.0
var fz := 0.0
var nh := 2
var nv := 2
var width := 1.0
var height := 1.0
var ctype := 0
var wind_min := 1
var wind_max := 1
var tex_front: Texture2D
var light := Color(1, 1, 1)

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _force := PackedVector3Array()
var _otm := PackedVector3Array()
var _otm_n := PackedInt32Array()
var _fixed := PackedByteArray()
var _links: Array = []        # [v1, v2, dmin, dmax, style]
var _cols: Array = []         # [Vector3 local_mu, radius, bone, Vector3 center]
var _unit_w := 1.0
var _unit_h := 1.0
var _wind := 0.0
var _vwind := Vector3.ZERO
var _imesh: ImmediateMesh
var _ready_sim := false

static func g2m(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.z, v.y) * 100.0

static func m2g(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y) / 100.0

## Tỉ lệ thân hình so với trong game (màn chọn nhân vật thu model còn 0.58): kích thước vải của game gốc là
## đơn vị thế giới tuyệt đối ứng với nhân vật cỡ thường, nên mô phỏng chạy trong hệ đơn vị đã chia cho tỉ lệ này.
var _k := 1.0

func _to_sim(v: Vector3) -> Vector3:
	return g2m(v) / _k

func _to_world(v: Vector3) -> Vector3:
	return m2g(v) * _k

func _body_scale() -> float:
	var sc := model.global_transform.basis.get_scale().x
	var base := 1.0
	var cls := int(model.get("char_class")) if model.get("char_class") != null else -1
	var table = model.get_script().get_script_constant_map().get("CLASS_SCALE") if model.get_script() else null
	if table is Array and cls >= 0 and cls < table.size():
		base = float(table[cls])
	return maxf(0.05, sc / base)

## CPhysicsCloth::Create
func setup(p_model: Node3D, p_bone: int, x: float, y: float, z: float, p_nh: int, p_nv: int, w: float, h: float,
		tex: Texture2D, p_type: int) -> void:
	model = p_model
	bone = p_bone
	fx = x
	fy = y
	fz = z
	nh = p_nh
	nv = p_nv
	width = w
	height = h
	tex_front = tex
	ctype = p_type

func set_wind_min_max(mn: int, mx: int) -> void:
	wind_min = mn
	wind_max = mx

func add_collision_sphere(x: float, y: float, z: float, r: float, p_bone: int) -> void:
	_cols.append([Vector3(x, y, z), r, p_bone, Vector3.ZERO])

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY   # đỉnh vải đã ở toạ độ thế giới
	process_priority = 200   # sau khi animation đã đặt tư thế xương
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	material_override = _make_material()
	_add_cloth_shadow()

## Bóng của tấm vải (AddClothesShadowTriangles của client gốc): cùng lưới vải, vẽ bằng shader bóng thân
const _BODY_SHADOW_SHADER = preload("res://src/shaders/mu_body_shadow.gdshader")
var _cloth_shadow_mat: ShaderMaterial = null
var _shadow_mi: MeshInstance3D = null

func _add_cloth_shadow() -> void:
	# vải cộng sáng (hào quang) không đổ bóng
	if material_override is ShaderMaterial:
		return
	if _cloth_shadow_mat == null:
		_cloth_shadow_mat = ShaderMaterial.new()
		_cloth_shadow_mat.shader = _BODY_SHADOW_SHADER
	_shadow_mi = MeshInstance3D.new()
	_shadow_mi.name = "ClothShadow"
	_shadow_mi.top_level = true
	_shadow_mi.mesh = _imesh
	_shadow_mi.material_override = _cloth_shadow_mat
	_shadow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow_mi)

const ADD_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	vec4 t = texture(tex, UV);
	vec3 c = t.rgb * COLOR.rgb * (t.a * COLOR.a);
	float a = clamp(max(max(c.r, c.g), c.b), 0.0, 1.0);
	if (a < 0.02) {
		discard;
	}
	ALPHA = a;
	ALBEDO = c / max(a, 0.001);
}
"""
static var _add_shader: Shader = null

func _make_material() -> Material:
	var draw := ctype & PCT_MASK_DRAW
	if (ctype & PCT_MASK_LIGHT) != 0 or draw == PCT_MASK_BLEND:
		# Vải cộng sáng: alpha = độ sáng (StandardMaterial3D ADD có alpha = 1 ở phần đen -> khung đen đặc
		# trên nền trong suốt của màn chọn nhân vật)
		if _add_shader == null:
			_add_shader = Shader.new()
			_add_shader.code = ADD_SHADER_CODE
		var sm := ShaderMaterial.new()
		sm.shader = _add_shader
		sm.set_shader_parameter("tex", tex_front)
		return sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex_front
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if draw == PCT_MASK_ALPHA:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.25
	return m

# ------------------------------------------------------------------ xương
func _bone_xform(b: int) -> Transform3D:
	var sk: Skeleton3D = model.skeleton
	if sk == null:
		return Transform3D.IDENTITY
	var bi := sk.find_bone("b%03d" % b)
	if bi < 0:
		return sk.global_transform
	return sk.global_transform * sk.get_bone_global_pose(bi)

## Điểm trong hệ toạ độ xương MU -> toạ độ thế giới MU (TransformPosition(BoneTransform[bone], p, out, true))
func _bone_point(b: int, p: Vector3) -> Vector3:
	return _to_sim(_bone_xform(b) * _to_world(p))

func _init_sim() -> void:
	var nvert := nh * nv
	_pos.resize(nvert)
	_vel.resize(nvert)
	_force.resize(nvert)
	_otm.resize(nvert)
	_otm_n.resize(nvert)
	_fixed.resize(nvert)
	_vel.fill(Vector3.ZERO)
	_force.fill(Vector3.ZERO)
	_otm.fill(Vector3.ZERO)
	_otm_n.fill(0)
	_fixed.fill(0)
	_links.clear()
	_unit_w = width / float(nh - 1)
	_unit_h = height / float(nv - 1)
	_k = _body_scale()
	# Matrix = AngleMatrix(owner->Angle) + vị trí xương
	var origin := _to_sim(_bone_xform(bone).origin)
	var basis := model.global_transform.basis.orthonormalized()
	var cyl := (ctype & PCT_MASK_SHAPE_EXT) == PCT_CYLINDER
	for j in nv:
		var w := width
		var uw := _unit_w
		if (ctype & PCT_MASK_SHAPE_EXT) == PCT_SHORT_SHOULDER:
			w *= RATE_SHORT_SHOULDER + (1.0 - RATE_SHORT_SHOULDER) * float(j) / float(nv - 1)
			uw = w / float(nh - 1)
		for i in nh:
			var v := Vector3.ZERO
			if cyl:
				v = Vector3(uw * i, sin(float(i) / float(nh - 1) * PI) * 100.0 - 30.0, _unit_h * j)
			else:
				v = Vector3(uw * i - 0.5 * w, 20.0, -_unit_h * j)
			match ctype & PCT_MASK_SHAPE:
				PCT_CURVED:
					var mv := 2.0 * absf(float(i) / float(nh - 1) - 0.5)
					v.y -= 10.0 * mv * mv
				PCT_STICKED:
					v.y = 0.0
			_pos[nh * j + i] = origin + _to_sim(basis * _to_world(v))
	# mắt lưới (Create)
	var ver_style := 0
	var cross_style := 0
	if (ctype & PCT_MASK_ELASTIC) != PCT_RUBBER:
		ver_style |= PLS_STRICTDISTANCE
		cross_style |= PLS_LOOSEDISTANCE
	for j in nv:
		for i in nh:
			var a := nh * j + i
			if j < nv - 1:
				var d := _pos[a].distance_to(_pos[a + nh])
				_links.append([a, a + nh, d * 0.8, d, PLS_SPRING | ver_style])
			if i < nh - 1:
				var d2 := _pos[a].distance_to(_pos[a + 1])
				_links.append([a, a + 1, d2 * 0.8, d2, PLS_SPRING | PLS_LOOSEDISTANCE])
				if j < nv - 1:
					var d3 := _pos[a].distance_to(_pos[a + 1 + nh])
					_links.append([a, a + 1 + nh, d3 * 0.8, d3, cross_style])
				if j > 1:
					var d4 := _pos[a].distance_to(_pos[a + 1 - nh])
					_links.append([a, a + 1 - nh, d4 * 0.8, d4, cross_style])
	_set_fixed_vertices()
	_ready_sim = true

## SetFixedVertices: hàng trên cùng bám theo xương
func _set_fixed_vertices() -> void:
	var cyl := (ctype & PCT_MASK_SHAPE_EXT) == PCT_CYLINDER
	var w := width
	var uw := _unit_w
	if (ctype & PCT_MASK_SHAPE_EXT) == PCT_SHORT_SHOULDER:
		w *= RATE_SHORT_SHOULDER
		uw = w / float(nh - 1)
	var bx := _bone_xform(bone)
	for i in nh:
		var v := Vector3(uw * i - 0.5 * w + fx, fy, fz)
		if cyl:
			v.y = sin(float(i) / float(nh - 1) * PI) * 130.0 - 110.0
		if (ctype & PCT_MASK_SHAPE) == PCT_CURVED:
			var mv := 2.0 * absf(float(i) / float(nh - 1) - 0.5)
			v.y -= 10.0 * mv * mv
		var sw := Vector3(v.z, -v.y, v.x)
		_pos[i] = _to_sim(bx * _to_world(sw))
		_vel[i] = Vector3.ZERO
		_fixed[i] = 1

# ------------------------------------------------------------------ mô phỏng (Move2 / Move / MoveVertices / PreventFromStretching)
func _process(delta: float) -> void:
	if model == null or not is_instance_valid(model) or model.skeleton == null:
		return
	visible = model.is_visible_in_tree()
	if not visible:
		return
	if not _ready_sim or absf(_body_scale() - _k) > 0.02:
		_init_sim()
	var f := clampf(REFERENCE_FPS * delta, 0.0, 1.0)   # FPS_ANIMATION_FACTOR
	# CPhysicsManager::Move: gió chung đi ngẫu nhiên, mỗi khung một lần
	var fr := Engine.get_process_frames()
	if _wind_frame != fr:
		_wind_frame = fr
		s_wind = clampf(s_wind + (randi() % 200 - 100) * 0.001 * f, -0.2, 1.0)
	for _k in 5:
		if not _move(0.005, f):
			_init_sim()   # vải bị kéo giãn quá mức (dịch chuyển tức thời) -> dựng lại
			break
	_render()

func _move(t: float, f: float) -> bool:
	if (ctype & PCT_MASK_ELASTIC) == PCT_RUBBER2:
		_wind = float(randi() % maxi(1, wind_max) + wind_min) / 100.0
	else:
		_wind = s_wind
	if (ctype & PCT_MASK_SHAPE_EXT) == PCT_CYLINDER:
		_wind = float(randi() % 10 + 25) / 50.0
	_wind *= f
	# gió thổi ngược hướng nhìn của nhân vật
	var fwd := g2m(model.global_transform.basis.z.normalized()) / 100.0
	var back := Vector2(-fwd.x, -fwd.y)
	if back.length() > 0.001:
		back = back.normalized()
	_vwind = Vector3(back.x, back.y, 0.0) * _wind
	_move_vertices(t, f)
	return _prevent_from_stretching()

func _move_vertices(t: float, f: float) -> void:
	# InitForces
	var nvert := nh * nv
	var seed := (int(Time.get_ticks_msec() / 400.0) * 101) % nvert
	for v in nvert:
		if _fixed[v]:
			_force[v] = Vector3.ZERO
			continue
		var key := absi(seed % nh - v % nh) + absi(seed / nh - v / nh)
		var tmp := mini(maxi(0, 5 - key), 4)
		var rnd := 0.0 if tmp == 0 else float(tmp + 2)
		var fo := rnd * _vwind - _vel[v] * 0.01
		match ctype & PCT_MASK_ELASTIC:
			PCT_RUBBER:
				fo.z += rnd * (_wind + 0.1) * f
			PCT_RUBBER2:
				fo.z += rnd * _wind * f
		match ctype & PCT_MASK_ELASTIC_EXT:
			PCT_ELASTIC_RAGE_L:
				fo.x += -(rnd * _wind * 0.8 * f)
			PCT_ELASTIC_RAGE_R:
				fo.x -= -(rnd * _wind * 0.8 * f)
		if (ctype & PCT_MASK_WEIGHT) == PCT_HEAVY:
			fo.z -= GRAVITY * MASS * 180.0 * f
		else:
			fo.z -= GRAVITY * MASS * 100.0 * f
		_force[v] = fo
	# lò xo
	for l in _links:
		if (int(l[4]) & PLS_SPRING) == 0:
			continue
		var a: int = l[0]
		var b: int = l[1]
		var d := _pos[a] - _pos[b]
		var dist := maxf(0.001, d.length())
		var dmax: float = l[3]
		if dist > dmax + 0.01:
			var fv := (dist - dmax) * d / dist * f
			if (ctype & PCT_MASK_ELASTIC) == PCT_RUBBER:
				fv *= 3.0
			if not _fixed[a]:
				_force[a] -= fv
			if not _fixed[b]:
				_force[b] += fv
	_set_fixed_vertices()
	for v in nvert:
		if _fixed[v]:
			continue
		_vel[v] += _force[v] * INV_MASS * t
		_pos[v] += _vel[v] * t

func _one_time(v: int, mv: Vector3) -> void:
	_otm[v] += mv
	_otm_n[v] += 1

func _do_one_time_moves() -> void:
	for v in nh * nv:
		if _fixed[v]:
			_otm[v] = Vector3.ZERO
			_otm_n[v] = 0
		elif _otm_n[v] > 0:
			_pos[v] += _otm[v] / float(_otm_n[v])
			_otm[v] = Vector3.ZERO
			_otm_n[v] = 0

func _prevent_from_stretching() -> bool:
	var nvert := nh * nv
	# cầu va chạm theo xương (đổi trục như SetFixedVertices)
	if not _cols.is_empty():
		for c in _cols:
			var p: Vector3 = c[0]
			c[3] = _bone_point(int(c[2]), Vector3(p.z, -p.y, p.x))
		for c in _cols:
			var center: Vector3 = c[3]
			var r: float = c[1]
			for v in nvert:
				var d := _pos[v] - center
				var ln := d.length()
				if ln < 0.01:
					ln = 0.01
					d = Vector3(ln, 0, 0)
				if ln < r:
					_one_time(v, d * ((r - ln) / ln))
		_do_one_time_moves()
	for l in _links:
		if int(l[4]) & PLS_LOOSEDISTANCE:
			var a: int = l[0]
			var b: int = l[1]
			var d := _pos[a] - _pos[b]
			var dist := maxf(0.001, d.length())
			d *= (dist - float(l[3])) * 0.5 / dist
			_one_time(a, -d)
			_one_time(b, d)
	_do_one_time_moves()
	for l in _links:
		var a2: int = l[0]
		var b2: int = l[1]
		if b2 >= nh and (int(l[4]) & PLS_STRICTDISTANCE):
			# pVertex2->KeepLength(pVertex1, m_fDistance)
			if _fixed[b2]:
				continue
			var d2 := _pos[b2] - _pos[a2]
			var dist2 := maxf(0.001, d2.length())
			var dmin: float = l[2]
			var dmax2: float = l[3]
			if dist2 > dmax2 * 20.0:
				return false
			if dist2 > dmax2:
				_pos[b2] -= d2 * ((dist2 - dmax2) / dist2)
			elif dist2 < dmin:
				_pos[b2] -= d2 * ((dist2 - dmin) / dist2)
	return true

# ------------------------------------------------------------------ vẽ (RenderFace: u = i/(nh-1), v = min(0.99, j/(nv-1)))
func _render() -> void:
	if global_transform != Transform3D.IDENTITY:
		global_transform = Transform3D.IDENTITY
	if _shadow_mi != null and _cloth_shadow_mat != null and model != null and is_instance_valid(model):
		_cloth_shadow_mat.set_shader_parameter("shadow_origin", model.global_position)
	_imesh.clear_surfaces()
	var col := light
	if ctype & PCT_MASK_LIGHT:
		var lum := sin(Time.get_ticks_msec() * 0.001) * 0.1 + 0.4
		col = Color(lum, lum, lum)
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv - 1:
		for i in nh - 1:
			var q := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			for k in [0, 1, 2, 0, 2, 3]:
				var c: Array = q[k]
				_imesh.surface_set_color(col)
				_imesh.surface_set_uv(Vector2(float(c[0]) / float(nh - 1), minf(0.99, float(c[1]) / float(nv - 1))))
				_imesh.surface_add_vertex(_to_world(_pos[nh * int(c[1]) + int(c[0])]))
	_imesh.surface_end()

# ------------------------------------------------------------------ cấu hình áo choàng theo UpdateCloakCloth (ZzzCharacter.cpp)
const TEX_DIR := "res://assets/mu/Item/tex/"

static func _tex(name: String) -> Texture2D:
	for ext in [".png", ".jpg"]:
		var p: String = TEX_DIR + name + ext
		if ResourceLoader.exists(p):
			return load(p)
	return null

static func _body_spheres(c: MuCloth, r_top: float, r_low: float) -> void:
	c.add_collision_sphere(-10.0, -10.0, -10.0, r_top, 17)
	c.add_collision_sphere(10.0, -10.0, -10.0, r_top, 17)
	c.add_collision_sphere(-10.0, -10.0, 20.0, r_low, 17)
	c.add_collision_sphere(10.0, -10.0, 20.0, r_low, 17)

## Các tấm vải cho áo choàng (group, number). Trả về [] nếu món không phải áo choàng vải.
static func build_cape(model: Node3D, group: int, number: int) -> Array:
	var out: Array = []
	var lord := (group == 13 and number == 30) or (group == 12 and number in [30, 130])
	if lord or (group == 12 and number == 40):
		# Dark Lord: pCloth[2] (+ dải đỏ pCloth[4], [5] của Cape of Emperor)
		var emperor := group == 12 and number == 40
		var small := group == 12 and number in [30, 130]
		var c := MuCloth.new()
		var sz := 100.0 if small else 180.0
		var flags := PCT_CURVED | PCT_SHORT_SHOULDER | PCT_MASK_ALPHA | (PCT_HEAVY if emperor else 0)
		c.setup(model, 19, 0.0, 8.0, 10.0, 10, 10, sz, sz, _tex("dl_redwings02" if emperor else "DarkLordRobe"), flags)
		_body_spheres(c, 25.0, 27.0)
		out.append(c)
		if emperor:
			for side in [[30.0, 15.0], [-30.0, 20.0]]:
				var s := MuCloth.new()
				s.setup(model, 19, side[0], side[1], 10.0, 2, 5, 12.0, 200.0, _tex("dl_redwings03"),
					PCT_FLAT | PCT_COTTON | PCT_MASK_ALPHA)
				s.add_collision_sphere(0.0, -15.0, -20.0, 30.0, 2)
				s.add_collision_sphere(0.0, 0.0, 0.0, 35.0, 17)
				out.append(s)
	elif group == 12 and number in [49, 50, 135]:
		# Rage Fighter: pCloth[0] (+ hai dải vai pCloth[1], [2] của Cape of Overrule)
		var overrule := number == 50
		var little := number == 135
		var c2 := MuCloth.new()
		c2.setup(model, 19, 0.0, 15.0, 5.0, 10, 10, 150.0 if little else 180.0, 130.0 if little else 170.0,
			_tex("monke_manto" if overrule else "NCcape"), PCT_CURVED | PCT_SHORT_SHOULDER | PCT_HEAVY | PCT_MASK_ALPHA)
		_body_spheres(c2, 35.0, 37.0)
		out.append(c2)
		if overrule:
			for side in [[25.0, PCT_ELASTIC_RAGE_L, 45.0], [-25.0, PCT_ELASTIC_RAGE_R, 50.0]]:
				var s2 := MuCloth.new()
				s2.setup(model, 19, side[0], 15.0, 2.0, 2, 5, 12.0, 180.0, _tex("monk_manto01"),
					PCT_FLAT | PCT_COTTON | int(side[1]) | PCT_MASK_ALPHA)
				s2.add_collision_sphere(0.0, -15.0, -20.0, 35.0, 2)
				s2.add_collision_sphere(0.0, 0.0, 0.0, float(side[2]), 17)
				out.append(s2)
	return out

## Món nào còn vẽ model gắn xương (phần giáp vai) ngoài tấm vải: chỉ Cape of Emperor / Cape of Overrule.
## Cape of Lord / Small Cape of Lord / Cape of Fighter / Little Warrior's Cloak: game gốc bỏ qua model (chỉ có vải).
static func cape_draws_model(group: int, number: int) -> bool:
	return group == 12 and number in [40, 50]
