extends RefCounted


## Hiệu ứng của công trình bản đồ — port từ ZzzObject.cpp (MoveObject / UpdateObjectVisual) của client gốc.
## Số world ở đây = số thư mục WorldN của MuGodot = WD_xxx + 1 (World1 = Lorencia = WD_0LORENCIA).
##
## Mỗi mục theo loại vật thể (o->Type):
##   blend  : {mesh:[chỉ số mesh], su, sv (vòng/giây), flicker:[min,max], sine:[amp, base, freq rad/s, phase_by_angle]}
##            mesh bỏ trống = áp cho mesh đã tự phát sáng theo tên texture
##   stream : {mesh, su, sv}  -> StreamMesh: mesh thường nhưng texture trôi
##   speed  : hệ số tốc độ animation (Velocity)
##   hidden : true -> HiddenMesh = -2 (không vẽ model, chỉ còn hiệu ứng)
##   sprites: [{bone, tex, scale, color, rot(độ/s), sine:[amp,base,freq], flicker, offset (đơn vị MU)}]
##   fires  : [[x, y, z]] -> CreateFire(0, o, x, y, z) (đơn vị MU, quay theo góc vật thể)
##   smoke  : {color, rate, size, rise, burst:[chu kỳ s, thời lượng s]} -> CreateParticle(BITMAP_SMOKE...)
##   particles: "bubble" | "cloud" | "sand" | "spark"

const SPRITE_SHADER := preload("res://src/shaders/mu_sprite.gdshader")
const FIRE_TEX := "res://assets/lorencia/fire01.png"

const C_BLUE := Color(0.4, 0.7, 1.0)
const C_ORANGE := Color(0.6, 0.3, 0.1)
const C_WHITE := Color(1, 1, 1)

static var TABLE: Dictionary = {
	# ---------------- World2 = Dungeon (WD_1DUNGEON)
	2: {
		22: {"stream": {"mesh": 1, "sv": 1.0}},
		23: {"stream": {"mesh": 1, "sv": 1.0}},
		24: {"stream": {"mesh": 1, "sv": 1.0}},
		41: {"fires": [[0.0, -30.0, 240.0]]},
		42: {"fires": [[0.0, 0.0, 190.0]]},
		39: {"hidden": true}, 40: {"hidden": true}, 51: {"hidden": true},
		52: {"hidden": true, "particles": "stones"},
	},
	# ---------------- World3 = Devias (WD_2DEVIAS)
	3: {
		78: {"blend": {"mesh": [3], "flicker": [0.4, 0.7]}},
		30: {"fires": [[0.0, 0.0, 160.0]], "smoke": {"color": Color(0.5, 0.5, 0.5, 0.45), "rate": 6, "size": 1.0, "rise": 1.2, "offset": [0.0, 0.0, 160.0]}},
		66: {"fires": [[0.0, 0.0, 50.0]]},
	},
	# ---------------- World4 = Noria (WD_3NORIA)
	4: {
		1: {"sprites": [
			{"bone": 2, "tex": "flare01", "scale": 0.5, "color": C_BLUE, "flicker": 0.3},
			{"bone": 4, "tex": "flare01", "scale": 0.5, "color": C_BLUE, "flicker": 0.3},
			{"bone": 6, "tex": "flare01", "scale": 0.5, "color": C_BLUE, "flicker": 0.3}]},
		9: {"sprites": [{"bone": 1, "tex": "flare01", "scale": 1.5, "color": C_BLUE, "flicker": 0.3}]},
		35: {"sprites": [{"bone": 3, "tex": "flare01", "scale": 1.5, "color": C_BLUE, "flicker": 0.3}]},
		17: {"sprites": [
			{"bone": 4, "tex": "flare01", "scale": 1.0, "color": C_BLUE, "flicker": 0.3},
			{"bone": 7, "tex": "flare01", "scale": 1.0, "color": C_BLUE, "flicker": 0.3},
			{"bone": 10, "tex": "flare01", "scale": 1.0, "color": C_BLUE, "flicker": 0.3},
			{"bone": 13, "tex": "flare01", "scale": 1.0, "color": C_BLUE, "flicker": 0.3}]},
		18: {"blend": {"mesh": [2], "sv": -1.0}},
		39: {"blend": {"mesh": [1]}, "sprites": [
			{"bone": 57, "tex": "lightning2", "scale": 1.0, "color": Color(0.4, 0.8, 1.0), "rot": 100.0, "flicker": 0.3},
			{"bone": 57, "tex": "lightning2", "scale": 1.0, "color": Color(0.4, 0.8, 1.0), "rot": -100.0, "flicker": 0.3},
			{"bone": 61, "tex": "flare01", "scale": 1.0, "color": C_WHITE},
			{"bone": 62, "tex": "flare01", "scale": 1.0, "color": C_WHITE},
			{"bone": 63, "tex": "flare01", "scale": 1.0, "color": C_WHITE},
			{"bone": 64, "tex": "flare01", "scale": 1.0, "color": C_WHITE},
			{"bone": 65, "tex": "flare01", "scale": 1.0, "color": C_WHITE}],
			"spark_bone": 58},
		41: {"blend": {"mesh": [0], "sv": -0.5}},
		42: {"stream": {"mesh": 0, "su": 2.0}},
		43: {"stream": {"mesh": 0, "su": -2.0}},
	},
	# ---------------- World5 = Lost Tower (WD_4LOSTTOWER)
	5: {
		3: {"blend": {"su": 1.0}},
		4: {"blend": {"su": 1.0}},
		18: {"blend": {"mesh": [1]}},
		19: {"blend": {"mesh": [4], "su": 1.0}, "sprites": [
			{"bone": 15, "tex": "Magic_Ground2", "scale": 0.3, "color": Color(1.0, 0.2, 0.0), "rot": 100.0, "flicker": 0.3},
			{"bone": 15, "tex": "Magic_Ground2", "scale": 0.3, "color": Color(1.0, 0.2, 0.0), "rot": -100.0, "flicker": 0.3},
			{"bone": 19, "tex": "Magic_Ground2", "scale": 0.3, "color": Color(1.0, 0.2, 0.0), "rot": 100.0, "flicker": 0.3},
			{"bone": 19, "tex": "Magic_Ground2", "scale": 0.3, "color": Color(1.0, 0.2, 0.0), "rot": -100.0, "flicker": 0.3},
			{"bone": 21, "tex": "Magic_Ground2", "scale": 1.5, "color": Color(1.0, 0.2, 0.0), "rot": 100.0, "flicker": 0.3},
			{"bone": 21, "tex": "Magic_Ground2", "scale": 1.5, "color": Color(1.0, 0.2, 0.0), "rot": -100.0, "flicker": 0.3}]},
		20: {"blend": {"mesh": [4], "su": 1.0}, "sprites": [
			{"bone": 15, "tex": "lightning2", "scale": 0.3, "color": Color(0.4, 0.8, 1.0), "rot": 100.0, "flicker": 0.3},
			{"bone": 15, "tex": "lightning2", "scale": 0.3, "color": Color(0.4, 0.8, 1.0), "rot": -100.0, "flicker": 0.3},
			{"bone": 19, "tex": "lightning2", "scale": 0.3, "color": Color(0.4, 0.8, 1.0), "rot": 100.0, "flicker": 0.3},
			{"bone": 19, "tex": "lightning2", "scale": 0.3, "color": Color(0.4, 0.8, 1.0), "rot": -100.0, "flicker": 0.3},
			{"bone": 21, "tex": "lightning2", "scale": 1.5, "color": Color(0.4, 0.8, 1.0), "rot": 100.0, "flicker": 0.3},
			{"bone": 21, "tex": "lightning2", "scale": 1.5, "color": Color(0.4, 0.8, 1.0), "rot": -100.0, "flicker": 0.3}]},
		23: {"blend": {"mesh": [1]}},
		24: {"hidden": true, "particles": "flame"},
		25: {"hidden": true},
		40: {"sprites": [
			{"bone": -1, "offset": [0.0, 0.0, 260.0], "tex": "lightning2", "scale": 2.5, "color": C_WHITE, "rot": 100.0, "flicker": 0.3},
			{"bone": -1, "offset": [0.0, 0.0, 260.0], "tex": "lightning2", "scale": 2.5, "color": C_WHITE, "rot": -100.0, "flicker": 0.3}]},
		# case 40 của Lost Tower rơi xuống case WD_6STADIUM (không có break) -> loại 9 cũng có đèn cam
		9: {"sprites": [{"bone": 1, "tex": "flare01", "scale": 5.0, "color": C_ORANGE, "flicker": 0.3, "scale_pulse": 1.0}]},
	},
	# ---------------- World6 = WD_5UNKNOWN (Arena)
	6: {
		2: {"blend": {"mesh": [0]}},
		3: {"blend": {"mesh": [0], "flicker": [0.6, 0.9]}},
	},
	# ---------------- World7 = Stadium (WD_6STADIUM)
	7: {
		21: {"blend": {"mesh": [3], "sv": 1.0}},
		9: {"sprites": [{"bone": 1, "tex": "flare01", "scale": 5.0, "color": C_ORANGE, "flicker": 0.3, "scale_pulse": 1.0}]},
	},
	# ---------------- World8 = Atlans (WD_7ATLANSE)
	8: {
		22: {"hidden": true, "particles": "bubble"},
		23: {"blend": {"mesh": [0], "sine": [0.3, 0.5, 2.0]}},
		32: {"blend": {"mesh": [1], "sine": [0.5, 0.5, 4.0]}},
		34: {"blend": {"mesh": [1], "sine": [0.5, 0.5, 4.0]}},
		38: {"blend": {"mesh": [0]}},
		40: {"blend": {"mesh": [0], "sine": [0.3, 0.5, 4.0]}, "speed": 0.05 / 0.16},
	},
	# ---------------- World9 = Tarkan (WD_8TARKAN)
	9: {
		2: {"blend": {"mesh": [0], "su": 1.0}},
		4: {"blend": {"mesh": [0], "sv": 0.1, "sine": [0.35, 0.65, 2.0]}},
		7: {"blend": {"mesh": [0], "sine": [0.35, 0.65, 2.0, 0.2]}},
		8: {"speed": 4.0},
		11: {"blend": {"sv": 0.2}},
		12: {"blend": {"su": 0.05, "sv": 0.05}},
		13: {"blend": {"sv": 0.2}},
		60: {"hidden": true, "particles": "sand_cloud"},
		61: {"blend": {"mesh": [1], "sv": 1.0}},
		63: {"hidden": true, "sprites": [{"bone": 2, "tex": "Impack03", "scale": 1.5, "color": Color(0.59, 1.0, 1.0), "sine": [0.3, 0.7, 2.0], "scale_pulse": 1.0}]},
		64: {"hidden": true, "sprites": [{"bone": 2, "tex": "Impack03", "scale": 1.5, "color": Color(1.0, 0.32, 0.32), "sine": [0.3, 0.7, 2.0], "scale_pulse": 1.0}]},
		65: {"blend": {"mesh": [1], "sv": 1.0}},
		66: {"blend": {"mesh": [1], "sv": 1.0}},
		70: {"hidden": true, "smoke": {"color": Color(0.75, 0.65, 0.5, 0.35), "rate": 5, "size": 1.6, "rise": 0.4}},
		72: {"blend": {"mesh": [0], "sv": 0.2}},
		73: {"blend": {"sv": 0.2}},
		75: {"blend": {"sv": 0.2}},
		76: {"hidden": true, "smoke": {"color": Color(0.75, 0.65, 0.5, 0.4), "rate": 14, "size": 1.4, "rise": 1.5, "burst": [5.0, 0.5]}},
		79: {"blend": {"sv": 0.2}},
		82: {"blend": {"mesh": [0]}},
		83: {"hidden": true, "smoke": {"color": Color(0.8, 0.7, 0.55, 0.45), "rate": 18, "size": 1.8, "rise": 1.0, "burst": [10.0, 0.5]}},
	},
	# ---------------- World11 = Icarus / Heaven (WD_10HEAVEN): mây
	11: {
		0: {"hidden": true, "particles": "cloud"}, 1: {"hidden": true, "particles": "cloud"},
		2: {"hidden": true, "particles": "cloud"}, 3: {"hidden": true, "particles": "cloud"},
		4: {"hidden": true, "particles": "cloud"}, 5: {"hidden": true, "particles": "cloud"},
		10: {"sprites": [{"bone": 3, "tex": "flare01", "scale": 1.0, "color": C_WHITE, "flicker": 0.3}]},
	},
	# ---------------- World94 = IGCN Season 9 màn chọn nhân vật: hộp đánh dấu chỉ dùng để phát hiệu ứng
	#   cha01..05 (Object14..18): chỗ đứng 5 nhân vật ; 별똥별 (Object40/41): sao băng ; 연기박스 (Object55..57): khói
	94: {
		13: {"hidden": true}, 14: {"hidden": true}, 15: {"hidden": true}, 16: {"hidden": true}, 17: {"hidden": true},
		5: {"hidden": true}, 39: {"hidden": true}, 40: {"hidden": true}, 57: {"hidden": true}, 69: {"hidden": true},
		54: {"hidden": true, "smoke": {"color": Color(0.55, 0.45, 0.85, 0.22), "rate": 3, "size": 3.0, "rise": 0.25}},
		55: {"hidden": true, "smoke": {"color": Color(0.45, 0.55, 0.9, 0.2), "rate": 3, "size": 3.0, "rise": 0.25}},
		56: {"hidden": true, "smoke": {"color": Color(0.7, 0.6, 0.95, 0.18), "rate": 2, "size": 2.5, "rise": 0.2}},
	},
	# ---------------- World95 = IGCN Season 9 màn đăng nhập: 안개박스 (Object39) sương biển, 연기박스 (Object55) khói
	95: {
		38: {"hidden": true, "smoke": {"color": Color(0.75, 0.75, 0.85, 0.16), "rate": 2, "size": 6.0, "rise": 0.15}},
		54: {"hidden": true, "smoke": {"color": Color(0.7, 0.7, 0.75, 0.22), "rate": 3, "size": 2.5, "rise": 0.6}},
		80: {"hidden": true}, 55: {"hidden": true}, 56: {"hidden": true},
	},
}

## Blood Castle 1..7 (World12..18) + Blood Castle Master (World53) dùng chung bảng
static var BLOOD_CASTLE: Dictionary = {
	11: {"sprites": [
		{"bone": 1, "tex": "flare01", "scale": 0.5, "color": Color(1.0, 0.5, 0.0), "sine": [0.5, 0.5, 1.0, 0.35]},
		{"bone": 2, "tex": "flare01", "scale": 0.5, "color": Color(1.0, 0.5, 0.0), "sine": [0.5, 0.5, 1.0, 0.35]},
		{"bone": 4, "tex": "flare01", "scale": 0.5, "color": Color(1.0, 0.5, 0.0), "sine": [0.5, 0.5, 1.0, 0.35]},
		{"bone": 6, "tex": "flare01", "scale": 0.5, "color": Color(1.0, 0.5, 0.0), "sine": [0.5, 0.5, 1.0, 0.35]},
		{"bone": 9, "tex": "flare01", "scale": 0.5, "color": Color(1.0, 0.5, 0.0), "sine": [0.5, 0.5, 1.0, 0.35]},
		{"bone": 10, "tex": "flare01", "scale": 0.5, "color": Color(1.0, 0.5, 0.0), "sine": [0.5, 0.5, 1.0, 0.35]},
		{"bone": 11, "tex": "flare01", "scale": 0.5, "color": Color(1.0, 0.5, 0.0), "sine": [0.5, 0.5, 1.0, 0.35]}]},
	13: {"sprites": [{"bone": 3, "tex": "Flare", "scale": 1.2, "color": C_WHITE, "sine": [0.3, 0.7, 1.0], "scale_pulse": 0.6}]},
	37: {"smoke": {"color": Color(0.7, 0.7, 0.7, 0.35), "rate": 6, "size": 1.5, "rise": 0.6}},
}

static func entry(world: int, obj_type: int) -> Dictionary:
	if (world >= 12 and world <= 18) or world == 53:
		return BLOOD_CASTLE.get(obj_type, {})
	var w: Dictionary = TABLE.get(world, {})
	return w.get(obj_type, {})

static func hidden_types(world: int) -> Array:
	var out := []
	var w: Dictionary = BLOOD_CASTLE if ((world >= 12 and world <= 18) or world == 53) else TABLE.get(world, {})
	for t in w:
		if (w[t] as Dictionary).get("hidden", false):
			out.append(t)
	return out

## Mục có cần spawn riêng (để gắn hiệu ứng theo xương / hạt) thay vì gom MultiMesh
static func needs_instance(e: Dictionary) -> bool:
	return e.has("sprites") or e.has("fires") or e.has("smoke") or e.has("particles") or e.has("speed") or e.has("spark_bone")

# ============================================================ tạo hiệu ứng

static var _tex_cache: Dictionary = {}

static func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var t: Texture2D = null
	for p in ["res://assets/mu/fx/skill/%s.jpg" % name, "res://assets/mu/fx/skill/%s.png" % name, "res://assets/mu/fx/%s.jpg" % name]:
		if ResourceLoader.exists(p):
			t = load(p)
			break
	_tex_cache[name] = t
	return t

## Vị trí MU (x, y, z-lên, đơn vị cm) -> Godot (x, z, -y, mét)
static func mu_offset(v: Array) -> Vector3:
	return Vector3(v[0], v[2], -v[1]) * 0.01

## CreateSprite: quad billboard cộng màu. scale MU 1.0 ~ texture 64px ~ 0.64 m
static func make_sprite(d: Dictionary, phase: float = 0.0) -> MeshInstance3D:
	var t := tex(str(d.get("tex", "flare01")))
	if t == null:
		return null
	# RenderSprite: Width = texture.Width * Scale, Height = texture.Height * Scale (đơn vị MU, 100 = 1 m)
	var q := QuadMesh.new()
	var k := float(d.get("scale", 1.0)) * 0.01
	q.size = Vector2(t.get_width(), t.get_height()) * k
	var sz := maxf(q.size.x, q.size.y)
	var m := ShaderMaterial.new()
	# SubType 1 của CreateSprite = Blend::Subtract (làm tối, vd. bóng đen quanh quái Shadow)
	m.shader = _sub_shader() if str(d.get("blend", "add")) == "sub" else SPRITE_SHADER
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("color", d.get("color", Color(1, 1, 1)))
	m.set_shader_parameter("rot_speed", float(d.get("rot", 0.0)))
	m.set_shader_parameter("flicker", float(d.get("flicker", 0.0)))
	m.set_shader_parameter("seed", phase)
	m.set_shader_parameter("scale_pulse", float(d.get("scale_pulse", 0.0)))
	if d.has("sine"):
		var s: Array = d["sine"]
		m.set_shader_parameter("sine_amp", float(s[0]))
		m.set_shader_parameter("sine_base", float(s[1]))
		m.set_shader_parameter("sine_freq", float(s[2]))
		m.set_shader_parameter("sine_phase", phase * float(s[3]) if s.size() > 3 else 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# quad billboard dựng trong vertex shader: nới AABB để không bị cull sai
	mi.extra_cull_margin = sz * 2.0
	mi.visibility_range_end = 45.0 if sz < 0.5 else 70.0
	return mi

static var _sprite_sub: Shader = null

## Bản trừ màu của mu_sprite.gdshader (render_mode là hằng lúc biên dịch nên tạo shader riêng)
static func _sub_shader() -> Shader:
	if _sprite_sub == null:
		_sprite_sub = Shader.new()
		_sprite_sub.code = SPRITE_SHADER.code.replace("blend_add", "blend_sub")
	return _sprite_sub

static func _add_mat(t: Texture2D, billboard_particles := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = t
	if billboard_particles:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m

static func _mix_mat(t: Texture2D) -> StandardMaterial3D:
	var m := _add_mat(t)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	return m

static var _fire_mat: StandardMaterial3D = null

## CreateFire(0, ...): hạt lửa Fire01 (4 khung), cùng thông số với lửa đuốc Lorencia
static func make_fire() -> CPUParticles3D:
	if _fire_mat == null:
		_fire_mat = _add_mat(load(FIRE_TEX) if ResourceLoader.exists(FIRE_TEX) else tex("Fire01"))
		_fire_mat.particles_anim_h_frames = 4
		_fire_mat.particles_anim_v_frames = 1
		_fire_mat.particles_anim_loop = false
		_fire_mat.vertex_color_is_srgb = true
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.96
	p.preprocess = 1.0
	p.randomness = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = _fire_mat
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.06, 0.06, 0.06)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.75))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.35))
	p.scale_amount_curve = curve
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	p.color = Color(0.85, 0.51, 0.34)
	var cv := Gradient.new()
	cv.set_color(0, Color(0.6, 0.36, 0.24))
	cv.set_color(1, Color(1.1, 0.66, 0.44))
	p.color_initial_ramp = cv
	p.visibility_range_end = 55.0
	return p

## Hạt chung: khói / bong bóng / mây / cát
static func make_particles(t: Texture2D, col: Color, amount: int, life: float, size: float,
		vel: Vector3, spread: float, box: Vector3, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _add_mat(t) if additive else _mix_mat(t)
	p.mesh = q
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.preprocess = life
	p.randomness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = vel.length() * 0.5
	p.initial_velocity_max = vel.length()
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = sc
	p.angle_min = 0.0
	p.angle_max = 360.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0), col, Color(col.r, col.g, col.b, 0.0)])
	p.color_ramp = g
	p.visibility_range_end = 60.0
	return p

## Gắn toàn bộ hiệu ứng của 1 vật thể. inst = model đã spawn (có thể ẩn mesh), xf = transform của vật thể.
## Trả về các node cần cập nhật theo thời gian (smoke burst) — rỗng nếu không cần.
static func attach(inst: Node3D, e: Dictionary, phase: float) -> Array:
	var timed := []
	var skel := MuModelFind.skeleton(inst)
	# Đèn / sprite theo xương
	for d in e.get("sprites", []):
		var s := make_sprite(d, phase)
		if s == null:
			continue
		var bone := int(d.get("bone", -1))
		var parent: Node3D = inst
		if bone >= 0 and skel and skel.find_bone("b%03d" % bone) >= 0:
			parent = MuModelFind.bone_attachment(skel, bone)
		parent.add_child(s)
		if d.has("offset"):
			s.position = mu_offset(d["offset"])
	# Lửa (CreateFire): offset theo góc vật thể, không theo tỉ lệ
	for f in e.get("fires", []):
		var fire := make_fire()
		inst.add_child(fire)
		fire.position = mu_offset(f) / _avg_scale(inst)
		fire.scale = Vector3.ONE / _avg_scale(inst)
	# Khói
	if e.has("smoke"):
		var sd: Dictionary = e["smoke"]
		var sm := make_particles(tex("smoke01"), sd.get("color", Color(0.6, 0.6, 0.6, 0.4)),
			int(sd.get("rate", 6)), 2.0, float(sd.get("size", 1.0)),
			Vector3(0, float(sd.get("rise", 0.8)), 0), 25.0, Vector3(0.3, 0.1, 0.3), false)
		_add_local(inst, sm, mu_offset(sd.get("offset", [0.0, 0.0, 30.0])))
		if sd.has("burst"):
			sm.emitting = false
			sm.set_meta("burst", sd["burst"])
			sm.set_meta("burst_phase", phase)
			timed.append(sm)
	# Hạt đặc biệt
	match str(e.get("particles", "")):
		"bubble":
			var b := make_particles(tex("Shiny01"), Color(0.6, 0.85, 1.0, 0.8), 6, 2.5, 0.18,
				Vector3(0, 0.9, 0), 10.0, Vector3(0.15, 0.05, 0.15))
			b.scale_amount_curve = null
			_add_local(inst, b, Vector3.ZERO)
			b.set_meta("burst", [1.0, 0.5])
			b.set_meta("burst_phase", phase)
			timed.append(b)
		"cloud":
			var c := make_particles(tex("clouds"), Color(0.35, 0.35, 0.4, 0.5), 6, 12.0, 9.0,
				Vector3(0.25, 0.02, 0.0), 180.0, Vector3(4.0, 0.6, 4.0))
			c.scale_amount_curve = null
			_add_local(inst, c, Vector3.ZERO)
			c.visibility_range_end = 160.0
		"sand_cloud":
			var sc := make_particles(tex("smoke01"), Color(0.7, 0.62, 0.48, 0.3), 12, 4.0, 2.5,
				Vector3(0.3, 0.1, 0.0), 120.0, Vector3(1.2, 0.3, 1.2), false)
			_add_local(inst, sc, Vector3.ZERO)
		"flame":
			var fl := make_fire()
			fl.amount = 4
			_add_local(inst, fl, Vector3.ZERO)
		"stones":
			pass # đá rơi trong hầm Dungeon: chưa có model hiệu ứng MODEL_DUNGEON_STONE01
	# Tia lửa định kỳ (Noria 39: CreateJoint(BITMAP_JOINT_SPARK) + CreateParticle(BITMAP_SPARK))
	if e.has("spark_bone") and skel and skel.find_bone("b%03d" % int(e["spark_bone"])) >= 0:
		var sp := make_particles(tex("Spark02"), Color(1, 1, 1, 1), 8, 0.6, 0.12,
			Vector3(0, 1.5, 0), 60.0, Vector3(0.02, 0.02, 0.02))
		sp.gravity = Vector3(0, -3.0, 0)
		sp.scale_amount_curve = null
		MuModelFind.bone_attachment(skel, int(e["spark_bone"])).add_child(sp)
		sp.set_meta("burst", [0.32 * 8.0, 0.15])
		sp.set_meta("burst_phase", phase)
		timed.append(sp)
	return timed

## Bật / tắt các hạt theo chu kỳ (khói phun theo nhịp WorldTime % chu kỳ của MU)
static func update_timed(nodes: Array, t: float) -> void:
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var b: Array = n.get_meta("burst")
		var period: float = b[0]
		var dur: float = b[1]
		var phase: float = float(n.get_meta("burst_phase", 0.0)) * 0.37
		var k := fmod(t + phase * period, period)
		(n as CPUParticles3D).emitting = k > period - dur

## Gắn hạt vào vật thể, bù tỉ lệ của vật thể (hạt phát trong toạ độ thế giới: local_coords = false)
static func _add_local(inst: Node3D, n: Node3D, offset: Vector3) -> void:
	var k := _avg_scale(inst)
	inst.add_child(n)
	n.position = offset / k
	n.scale = Vector3.ONE / k

static func _avg_scale(n: Node3D) -> float:
	var s := n.scale
	return maxf(0.01, (absf(s.x) + absf(s.y) + absf(s.z)) / 3.0)


## Tiện ích tìm Skeleton3D / gắn BoneAttachment3D (xương của BMD đặt tên b000, b001...)
class MuModelFind:
	static func skeleton(n: Node) -> Skeleton3D:
		if n is Skeleton3D:
			return n
		for c in n.get_children():
			var r := skeleton(c)
			if r:
				return r
		return null

	static func bone_attachment(skel: Skeleton3D, bone: int) -> BoneAttachment3D:
		var nm := "FxBone%03d" % bone
		var ex := skel.get_node_or_null(nm)
		if ex:
			return ex
		var ba := BoneAttachment3D.new()
		ba.name = nm
		skel.add_child(ba)
		ba.bone_name = "b%03d" % bone
		return ba
