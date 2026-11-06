extends RefCounted


## Kiểu vẽ riêng của một số đồ (Data/Items/Models "renderStyle" -> Render/Items/ItemRenderStyles.cpp).
## Mỗi mục: [chỉ số mesh, kiểu, {tham số}]
##   "tex"    : vẽ texture như thường (có ánh sáng)
##   "add"    : vẽ CỘNG (RENDER_BRIGHT), "light" = BodyLight, "pulse" = nhấp nháy sin, "flame" = lật 4 khung texture lửa
##   "chrome" : lớp chrome cộng (RENDER_CHROME | BRIGHT), "scroll" = tốc độ trượt
##   "hide"   : không vẽ
##   mesh -1  : mọi mesh ; "tex" trong "add" = dùng texture hiệu ứng (Data/Effect) thay texture của mesh
##   "light_mul" của "tex": nhân thêm BodyLight
## Mesh không được liệt kê -> vẽ "tex".
const STYLES := {
	# kiếm lửa: thân + chuôi bình thường, mesh 1 là lưỡi đỏ (Vector(1,0,0.2)) cộng + chrome, 3-4 cộng, mesh 5 là ngọn lửa 4 khung
	"flamberge": [[0, "tex"], [2, "tex"], [1, "add", {"light": [1.0, 0.0, 0.2]}], [1, "chrome"], [3, "add"], [4, "add"], [5, "flame"]],
	"swordBreaker": [[0, "tex"], [1, "tex"], [1, "chrome"]],
	"knightBlade": [[0, "tex"], [2, "add", {"pulse": 1.0}], [1, "add"], [3, "chrome", {"scroll": [0.1, 0.5]}]],
	"darkReignBlade": [[0, "add", {"scroll": [0.5, 0.5]}], [1, "add", {"scroll": [0.0, 0.5]}]],
	"lordScepter": [[0, "tex"], [1, "chrome", {"pulse": 0.3}]],
	# Blood Bone: thân sáng 0.9, rồi lớp Chrome01 CỘNG màu (0.9, 0.1, 0.1) trượt theo UV (V = -t*0.0005/ms)
	"bloodBone": [[-1, "tex", {"light_mul": 0.9}], [-1, "add", {"tex": "Chrome01", "light": [0.9, 0.1, 0.1], "scroll": [0.0, -0.5]}]],
	"textured": [],
	"texturedAllMeshes": [],
}

static func has_style(name: String) -> bool:
	return STYLES.has(name)

static func passes_for(name: String, mesh: int) -> Array:
	var out: Array = []
	for e in STYLES.get(name, []):
		if int(e[0]) == mesh or int(e[0]) == -1:
			out.append(e)
	return out

# =====================================================================================================
# KIỂU VẼ CHUYỂN TỰ ĐỘNG TỪ SOURCE GỐC (tools/mu_styles.py -> assets/mu/item_styles.json)
# Mỗi pass = 1 lệnh b->RenderMesh / b->RenderBody; ở đây dựng 1 shader cho mỗi pass theo đúng BMD::RenderMesh:
#   ResolveMaterial: BlendMesh (mesh == blendMesh / texture _R): CỘNG, màu = light * blendMeshLight, UV + (u, v)
#                    Chrome (RENDER_CHROME..): toạ độ theo pháp tuyến, texture Chrome01/Chrome02/Shiny01 (hoặc texture riêng)
#                    Texture: RENDER_BRIGHT = cộng, RENDER_DARK = trừ, còn lại thường (có ánh sáng)
# =====================================================================================================
const STYLE_JSON := "res://assets/mu/item_styles.json"
static var _json: Dictionary = {}
static var _json_loaded := false
static var _shaders: Dictionary = {}

static func json_styles() -> Dictionary:
	if not _json_loaded:
		_json_loaded = true
		if FileAccess.file_exists(STYLE_JSON):
			var d = JSON.parse_string(FileAccess.get_file_as_string(STYLE_JSON))
			if d is Dictionary:
				_json = d
	return _json

static func has_json_style(name: String) -> bool:
	var s = json_styles().get(name)
	return s is Dictionary and not (s.get("passes", []) as Array).is_empty()

static func _style_tex(name: String) -> Texture2D:
	for p in ["res://assets/mu/fx/styles/%s.png" % name, "res://assets/mu/fx/styles/%s.jpg" % name,
			"res://assets/mu/fx/%s.jpg" % name, "res://assets/mu/fx/%s.png" % name]:
		if ResourceLoader.exists(p):
			return load(p)
	return null

static func MuModelBrightness() -> float:
	return float(load("res://src/mu/MuModel.gd").BRIGHTNESS)

static func _fx(name: String) -> Texture2D:
	var p := "res://assets/mu/fx/%s.jpg" % name
	return load(p) if ResourceLoader.exists(p) else null

static func _chrome_mode(flags: Array) -> int:
	# GetSkinningTextureCoordinates: thứ tự kiểm tra của client gốc
	for e in [["RENDER_CHROME2", 2], ["RENDER_CHROME3", 3], ["RENDER_CHROME4", 4], ["RENDER_CHROME5", 5],
			["RENDER_CHROME6", 6], ["RENDER_CHROME7", 7], ["RENDER_OIL", 8], ["RENDER_CHROME", 1], ["RENDER_METAL", 9]]:
		if e[0] in flags:
			return e[1]
	return 0

## Vật liệu (chuỗi pass) cho surface `s` theo kiểu `name`.
## Trả về null nếu không có kiểu JSON; [] nếu kiểu không vẽ mesh này.
static func json_materials(name: String, s: int, src: Material, tint: Color, fixed: float, bright_mesh: bool, terrain: Texture2D) -> Variant:
	if not has_json_style(name):
		return null
	var out: Array = []
	var bm := src as BaseMaterial3D
	var own: Texture2D = bm.albedo_texture if bm else null
	var own_alpha: bool = bm != null and bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	for p in json_styles()[name]["passes"]:
		var mesh := int(p.get("mesh", -1))
		if mesh >= 0 and mesh != s:
			continue
		if mesh < 0 and int(p.get("hidden", -1)) == s:
			continue
		var flags: Array = p.get("flags", [])
		var cm := _chrome_mode(flags)
		var is_blend := s == int(p.get("blend_mesh", -1)) or bright_mesh
		var tex: Texture2D = own
		if p.get("texture") != null:
			tex = _style_tex(str(p["texture"]))
		elif cm in [2, 3, 4, 5]:
			tex = _fx("Chrome02")
		elif cm == 1 or cm == 6 or cm == 7:
			tex = _fx("Chrome01")
		elif cm == 9:
			tex = own if own != null else _fx("Shiny01")
			if own != null:
				cm = 0
		if tex == null:
			continue
		# kiểu trộn (ResolveMaterial)
		var blend := "mix"
		if "RENDER_DARK" in flags:
			blend = "sub"
		elif "RENDER_LIGHTMAP" in flags:
			blend = "mul"
		elif is_blend or "RENDER_BRIGHT" in flags or cm in [3, 4, 5, 7]:
			blend = "add"
		var lit := cm == 0 and not is_blend and blend == "mix" and int(p.get("stream", -1)) != s
		var wave := (is_blend or int(p.get("stream", -1)) == s) and cm == 0
		var clamp_tex := cm in [2, 3, 4, 5, 9]
		var code := _shader_code(p, cm, blend, lit, wave, is_blend, own_alpha and blend == "mix", clamp_tex)
		var sh: Shader = _shaders.get(code)
		if sh == null:
			sh = Shader.new()
			sh.code = code
			_shaders[code] = sh
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("terrain_light", terrain)
		m.set_shader_parameter("fixed_light", fixed)
		m.set_shader_parameter("body_tint", Vector3(tint.r, tint.g, tint.b))
		m.set_shader_parameter("tint_pulse", 1.0 if tint.a < 0.99 else 0.0)
		m.set_shader_parameter("brightness", MuModelBrightness())
		out.append(m)
	return out

static func _shader_code(p: Dictionary, cm: int, blend: String, lit: bool, wave: bool, is_blend: bool, alpha_tex: bool, clamp_tex: bool) -> String:
	var mode := "unshaded, cull_disabled"
	match blend:
		"add":
			mode += ", blend_add, depth_draw_never"
		"sub":
			mode += ", blend_sub, depth_draw_never"
		"mul":
			mode += ", blend_mul, depth_draw_never"
		_:
			mode += ", depth_draw_always" if alpha_tex else ", depth_draw_opaque"
	var wrap := "repeat_disable" if clamp_tex else "repeat_enable"
	var L: Array = p.get("light", ["body.x", "body.y", "body.z"])
	var uvc := "UV"
	match cm:
		1:
			uvc = "vec2(n.z * 0.5 + wave, n.y * 0.5 + wave * 2.0)"
		2:
			uvc = "vec2((n.z + n.x) * 0.8 + wave2 * 2.0, n.y + n.x + wave2 * 3.0)"
		3:
			uvc = "vec2(dot(n, vec3(0.0, -0.1, -0.8)), 1.0 - dot(n, vec3(0.0, -0.1, -0.8)))"
		4:
			uvc = "vec2(dot(n, cl) + n.y * 0.5 + cl.y * 3.0, 1.0 - dot(n, cl) - n.z * 0.5 - wave * 3.0) + vec2(U, V)"
		5:
			uvc = "vec2(dot(n, cl) + n.y * 3.0 + cl.y * 5.0, 1.0 - dot(n, cl) - n.z * 2.5 - wave) + vec2(U, V)"
		6:
			uvc = "vec2((n.z + n.x) * 0.8 + wave2 * 2.0)"
		7:
			uvc = "vec2((n.z + n.x) * 0.8 + T * 0.00006)"
		8:
			uvc = "n.xy * UV + vec2(U, V)"
		9:
			uvc = "vec2(n.z * 0.5 + 0.2, n.y * 0.5 + 0.5)"
		_:
			uvc = "UV + vec2(U, V)" if wave else "UV"
	var col := "vec3(%s, %s, %s)" % [L[0], L[1], L[2]]
	if is_blend:
		col += " * (%s)" % str(p.get("blend_light", "1.0"))
	var a := str(p.get("alpha", "1.0"))
	var lines := PackedStringArray([
		"shader_type spatial;",
		"render_mode %s;" % mode,
		"uniform sampler2D tex : filter_linear_mipmap, %s;" % wrap,
		"uniform sampler2D terrain_light : source_color, filter_linear, repeat_disable;",
		"uniform float fixed_light = -1.0;",
		"uniform vec3 body_tint = vec3(1.0);",
		"uniform float tint_pulse = 0.0;",
		"uniform float brightness = 1.5;",
		"varying vec3 v_body;",
		"varying vec3 v_nmu;",
		"varying vec3 v_lview;",
		"void vertex() {",
		"	vec3 tl;",
		"	if (fixed_light >= 0.0) { tl = vec3(fixed_light); } else {",
		"		vec3 o = NODE_POSITION_WORLD;",
		"		tl = pow(textureLod(terrain_light, vec2(o.x + 0.5, -o.z + 0.5) / 256.0, 0.0).rgb, vec3(1.0 / 2.2)); }",
		"	vec3 bt = body_tint;",
		"	if (tint_pulse > 0.5) { bt *= sin(TIME * 4.0) * 0.15 + 0.6; }",
		"	v_body = tl * bt * brightness;",
		"	vec3 nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);",
		"	v_nmu = vec3(nw.x, -nw.z, nw.y);",
		"	v_lview = (VIEW_MATRIX * vec4(0.0, 0.0, 1.2, 0.0)).xyz;",
		"}",
		"void fragment() {",
		"	float T = TIME * 1000.0;",
		"	vec3 body = v_body;",
		"	vec3 n = normalize(v_nmu);",
		"	float wave = mod(T, 10000.0) * 0.0001;",
		"	float wave2 = mod(T, 5000.0) * 0.00024 - 0.4;",
		"	vec3 cl = vec3(cos(T * 0.001), sin(T * 0.002), 1.0);",
		"	float U = %s;" % str(p.get("u", "0.0")),
		"	float V = %s;" % str(p.get("v", "0.0")),
		"	vec4 t = texture(tex, %s);" % uvc,
		"	vec3 c = t.rgb * max(%s, vec3(0.0));" % col,
	])
	if lit:
		lines.append("	float ld = dot(normalize(NORMAL), v_lview);")
		lines.append("	c *= max(ld + 0.3, 0.15);")
	lines.append("	float al = clamp(%s, 0.0, 1.0);" % a)
	if blend == "mix":
		lines.append("	if (t.a * al <= 0.25 && %s) { discard; }" % ("true" if alpha_tex else "false"))
		lines.append("	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));")
		if alpha_tex:
			lines.append("	ALPHA = t.a * al;")
	elif blend == "mul":
		lines.append("	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));")
	elif blend == "add":
		# MU cộng màu trên bộ đệm 8-bit gamma; Godot cộng trong bộ đệm HDR tuyến tính.
		# Cộng thẳng giá trị gamma (không pow 2.2) cho kết quả gần với client gốc trên nền thường:
		# lớp cộng sáng xám / cam trên nền sáng thành trắng / vàng thay vì chìm hoặc ngả đỏ.
		lines.append("	ALBEDO = clamp(c * al, 0.0, 1.0);")
	else:
		lines.append("	ALBEDO = pow(clamp(c * al, 0.0, 1.0), vec3(2.2));")
	lines.append("}")
	return "\n".join(lines)
