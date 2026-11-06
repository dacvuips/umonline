extends RefCounted
class_name MuModel

## Tiện ích dùng chung cho model MU đã chuyển sang .glb (tools/mu_convert_all.py):
##  - nạp & cache PackedScene
##  - thay vật liệu glTF bằng shader MU (mu_character.gdshader: ánh sáng địa hình + Luminosity theo normal)
##  - chạy animation theo số action MU ("a%03d"), tốc độ theo PlaySpeed (glb = 4 key/giây = PlaySpeed 0.16)

const CHAR_SHADER := preload("res://src/shaders/mu_character.gdshader")
const GLOW_SHADER := preload("res://src/shaders/mu_item_glow.gdshader")
const CHAR_ALPHA_SHADER := preload("res://src/shaders/mu_character_alpha.gdshader")
const CHAR_ADD_SHADER := preload("res://src/shaders/mu_character_add.gdshader")
const ItemStylesRes = preload("res://src/mu/MuItemStyles.gd")
## Độ sáng chung của nhân vật, quái, NPC và các lớp phát sáng của đồ (nâng sáng tươi rõ, không bị tối).
const BRIGHTNESS := 1.7
## Độ sáng thân đồ theo cấp
const LEVEL_BODY_BRIGHT_7 := 1.15    # +7, +8
const LEVEL_BODY_BRIGHT_9 := 1.45   # +9 .. +15
const HIDDEN_SHADER := preload("res://src/shaders/mu_hidden.gdshader")
const BASE_PLAY_SPEED := 0.16
const MuTerrainRes = preload("res://src/world/MuTerrain.gd")

static var _scenes: Dictionary = {}
static var _locked: Dictionary = {}
static var _anim_locks: Dictionary = {}
static var _mats: Dictionary = {}
static var _terrain_light: Texture2D = null
static var _fx: Dictionary = {}
## >= 0: ánh sáng cố định (Model Viewer) thay cho ánh sáng địa hình
static var fixed_light: float = -1.0

static func scene(path: String) -> PackedScene:
	if path == "":
		return null
	if _scenes.has(path):
		return _scenes[path]
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	else:
		push_warning("[MuModel] Chưa có model: %s (chạy tools/CHUYEN_DOI_MODEL_MU.bat)" % path)
	_scenes[path] = ps
	return ps

static func instantiate(path: String) -> Node3D:
	var ps := scene(path)
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if inst != null and not _locked.has(path):
		_locked[path] = true
		_lock_root_positions(path, inst)
	return inst

## Action_t::LockPositions (BMD::Animation): action giữ chân tại chỗ khoá vị trí NGANG của xương gốc
## bằng khung 0, chỉ giữ chuyển động lên xuống. Bản glb không mang cờ này (assets/mu/anim_locks.json,
## tools/mu_anim_locks.py) -> không khoá thì animation đi / chạy tự trượt thân người về trước rồi bật lại.
## Animation dùng chung giữa các bản sao của cùng file nên chỉ sửa một lần cho mỗi file.
## BMD::PlayAnimation: action lặp có LockPositions quay vòng ở khung NumKeys-1 (khung cuối = khung đầu),
## không nội suy khung cuối -> khung đầu. Bản glb thêm đoạn nối đó (khung 0 lặp lại ở cuối, 1/4 giây)
## nên mỗi chu kỳ bước bị đứng hình một nhịp: cắt bỏ đoạn cuối, giữ giá trị tại điểm cắt.
static func _trim_loop_seam(anim: Animation) -> void:
	var new_len := anim.length - 0.25
	if new_len <= 0.0:
		return
	for t in anim.get_track_count():
		var ty := anim.track_get_type(t)
		if ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_SCALE_3D:
			continue
		var n := anim.track_get_key_count(t)
		if n < 2 or anim.track_get_key_time(t, n - 1) <= new_len + 0.001:
			continue
		var v
		match ty:
			Animation.TYPE_POSITION_3D: v = anim.position_track_interpolate(t, new_len)
			Animation.TYPE_ROTATION_3D: v = anim.rotation_track_interpolate(t, new_len)
			_: v = anim.scale_track_interpolate(t, new_len)
		for k in range(n - 1, -1, -1):
			if anim.track_get_key_time(t, k) > new_len + 0.001:
				anim.track_remove_key(t, k)
		if anim.track_find_key(t, new_len, Animation.FIND_MODE_APPROX) < 0:
			anim.track_insert_key(t, new_len, v)
	anim.length = new_len

static func _lock_root_positions(path: String, inst: Node) -> void:
	if _anim_locks.is_empty():
		var f := FileAccess.open("res://assets/mu/anim_locks.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			_anim_locks = d if d is Dictionary else {"": []}
		else:
			_anim_locks = {"": []}
	var key := path.trim_prefix("res://assets/mu/").get_basename().to_lower()
	var locked = _anim_locks.get(key)
	if not locked is Array or (locked as Array).is_empty():
		return
	var ap := find_first(inst, "AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	for a in locked:
		var name := "a%03d" % int(a)
		if not ap.has_animation(name):
			continue
		var anim := ap.get_animation(name)
		_trim_loop_seam(anim)
		for t in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
				continue
			if str(anim.track_get_path(t).get_concatenated_subnames()) != "b000":
				continue
			var n := anim.track_get_key_count(t)
			if n == 0:
				continue
			var p0: Vector3 = anim.track_get_key_value(t, 0)
			for k in n:
				var v: Vector3 = anim.track_get_key_value(t, k)
				anim.track_set_key_value(t, k, Vector3(p0.x, v.y, p0.z))

static func terrain_light() -> Texture2D:
	if _terrain_light == null:
		_terrain_light = MuTerrainRes.light_texture()
	return _terrain_light

## Gọi khi đổi bản đồ: vật liệu cũ giữ ánh sáng địa hình của bản đồ trước
static func reset_cache() -> void:
	_terrain_light = null
	_mats.clear()

static func fx(name: String) -> Texture2D:
	if not _fx.has(name):
		var p := "res://assets/mu/fx/%s.jpg" % name
		_fx[name] = load(p) if ResourceLoader.exists(p) else null
	return _fx[name]

static func find_all(n: Node, type_name: String, out: Array) -> Array:
	if n.is_class(type_name):
		out.append(n)
	for c in n.get_children():
		find_all(c, type_name, out)
	return out

static func find_first(n: Node, type_name: String) -> Node:
	if n.is_class(type_name):
		return n
	for c in n.get_children():
		var r := find_first(c, type_name)
		if r:
			return r
	return null

## Tên texture gốc của surface (vật liệu glb tên "mu<idx>__<tên texture>")
static func tex_stem(src: Material) -> String:
	if src == null:
		return ""
	var nm := src.resource_name
	var sep := nm.find("__")
	return nm.substr(sep + 2) if sep >= 0 else nm

## TextureScriptParsing::parsingTScriptA của MU: hậu tố sau dấu "_" ĐẦU TIÊN của tên texture
##   R = Bright (cộng màu, không ánh sáng) ; H = ẩn ; S = stream ; N = không blend ; DC/DT = bóng
## Trả về "hide" | "bright" | "stream" | "none" | ""
static func mesh_script(stem: String) -> String:
	if stem.to_lower() == "hide":
		return "hide"     # texture hide.jpg -> BITMAP_HIDE: không vẽ
	var u := stem.find("_")
	if u < 0:
		return ""
	var tok := stem.substr(u, 5)
	var res := {}
	var i := 1
	while i < tok.length():
		var ch := tok[i]
		match ch:
			"R":
				res["bright"] = true
			"H":
				res["hide"] = true
			"S":
				res["stream"] = true
			"N":
				res["none"] = true
			"D":
				if i + 1 < tok.length() and (tok[i + 1] == "C" or tok[i + 1] == "T"):
					i += 1
				else:
					return ""
			_:
				return ""
		i += 1
	if res.has("hide"):
		return "hide"
	if res.has("bright"):
		return "bright"
	if res.has("stream"):
		return "stream"
	if res.has("none"):
		return "none"
	return ""

static var _hidden_mat: ShaderMaterial = null

## Vật liệu MU cho 1 surface (cache theo texture + kiểu + tint)
static func char_material(src: Material, tint: Color = Color(1, 1, 1), spec: float = 0.0) -> ShaderMaterial:
	var tex: Texture2D = null
	var alpha := false
	var bm := src as BaseMaterial3D
	if bm:
		tex = bm.albedo_texture
		alpha = bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var kind := mesh_script(tex_stem(src))
	if kind == "hide":
		if _hidden_mat == null:
			_hidden_mat = ShaderMaterial.new()
			_hidden_mat.shader = HIDDEN_SHADER
		return _hidden_mat
	var key := "%d|%s|%s|%s|%.2f|%.2f" % [tex.get_instance_id() if tex else 0, str(alpha), kind, "%.3f,%.3f,%.3f,%.2f" % [tint.r, tint.g, tint.b, tint.a], fixed_light, spec]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	if kind == "bright":
		m.shader = CHAR_ADD_SHADER
		m.set_shader_parameter("albedo_tex", tex)
		_mats[key] = m
		return m
	m.shader = CHAR_ALPHA_SHADER if alpha else CHAR_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("terrain_light", terrain_light())
	m.set_shader_parameter("alpha_cut", 0.25 if alpha else -1.0)
	# tint > 1 (đồ +7 trở lên): phần vượt 1 nhân thẳng vào màu đồ (body_boost), không qua đoạn nén sáng (knee)
	var boost := maxf(maxf(tint.r, tint.g), maxf(tint.b, 1.0))
	m.set_shader_parameter("body_tint", Vector3(tint.r, tint.g, tint.b) / boost)
	m.set_shader_parameter("body_boost", boost)
	m.set_shader_parameter("tint_pulse", 1.0 if tint.a < 0.99 else 0.0)
	m.set_shader_parameter("fixed_light", fixed_light)
	m.set_shader_parameter("specular", spec)
	m.set_shader_parameter("brightness", BRIGHTNESS)
	_mats[key] = m
	return m

## Thay toàn bộ vật liệu trong cây node.
## glow = {"level","excellent","color","shine", "style": renderStyle, "meshes": [..], "hidden": mesh}
static func apply_materials(root: Node, tint: Color = Color(1, 1, 1), glow: Dictionary = {}) -> void:
	var lvl := int(glow.get("level", 0))
	var want_glow := lvl >= 7 or bool(glow.get("excellent", false)) or bool(glow.get("ancient", false))
	var style := str(glow.get("style", ""))
	var only: Array = glow.get("meshes", []) if glow.get("meshes") is Array else []
	var hidden_mesh := int(glow.get("hidden", -1))
	var spec := float(glow.get("specular", 0.0))
	for mi in find_all(root, "MeshInstance3D", []):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var chain: Array = []
			# kiểu vẽ chuyển tự động từ source gốc (assets/mu/item_styles.json)
			var jm = ItemStylesRes.json_materials(style, s, src, tint, fixed_light,
				mesh_script(tex_stem(src)) == "bright", terrain_light()) if style != "" else null
			if jm != null and mesh_script(tex_stem(src)) == "hide":
				jm = []
			var styled: Array = ItemStylesRes.passes_for(style, s) if style != "" and jm == null else []
			if jm != null:
				chain.append_array(jm)
				if chain.is_empty():
					chain.append(_hidden())
			elif styled.is_empty():
				chain.append(char_material(src, tint, spec))
			else:
				for e in styled:
					var m := _style_pass(src, tint, e)
					if m != null:
						chain.append(m)
			if chain.is_empty():
				chain.append(char_material(src, tint, spec))
			# lớp chrome / excellent không vẽ lên mesh ẩn / mesh sáng (ResolveMaterial: NoneBlendMesh, Bright)
			var first: ShaderMaterial = chain[0]
			if want_glow and first.shader != HIDDEN_SHADER and first.shader != CHAR_ADD_SHADER \
					and (only.is_empty() or s in only) and s != hidden_mesh:
				chain.append(glow_material(src, glow))
			if chain.size() > 1:
				for i in chain.size():
					chain[i] = (chain[i] as ShaderMaterial).duplicate()
				for i in range(chain.size() - 1):
					(chain[i] as ShaderMaterial).next_pass = chain[i + 1]
			mi.set_surface_override_material(s, chain[0])

## Gỡ sạch material override và tắt cast_shadow trên toàn bộ GeometryInstance3D
## Tránh lỗi GLES3 "material_casts_shadows: Parameter 'material' is null" khi node bị queue_free()
static func cleanup_geometry(root: Node) -> void:
	if root == null:
		return
	for gi in find_all(root, "GeometryInstance3D", []):
		var g := gi as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.material_override = null
		if g is MeshInstance3D and g.mesh != null:
			for s in g.mesh.get_surface_count():
				g.set_surface_override_material(s, null)

## 1 lớp của kiểu vẽ riêng (MuItemStyles)
static func _style_pass(src: Material, tint: Color, e: Array) -> ShaderMaterial:
	var kind := str(e[1])
	var par: Dictionary = e[2] if e.size() > 2 else {}
	var bm := src as BaseMaterial3D
	var tex: Texture2D = bm.albedo_texture if bm else null
	if kind == "hide":
		return _hidden()
	if kind == "tex":
		var k := float(par.get("light_mul", 1.0))
		return char_material(src, Color(tint.r * k, tint.g * k, tint.b * k, tint.a))
	var m := ShaderMaterial.new()
	if kind == "add":
		m.shader = CHAR_ADD_SHADER
		m.set_shader_parameter("albedo_tex", fx(str(par["tex"])) if par.has("tex") else tex)
		var l: Array = par.get("light", [1.0, 1.0, 1.0])
		m.set_shader_parameter("light", Vector3(l[0], l[1], l[2]))
		var sc: Array = par.get("scroll", [0.0, 0.0])
		m.set_shader_parameter("uv_scroll", Vector2(sc[0], sc[1]))
		m.set_shader_parameter("pulse", float(par.get("pulse", 0.0)))
		m.set_shader_parameter("flame", 1.0 if e[1] == "flame" else 0.0)
		return m
	if kind == "flame":
		m.shader = CHAR_ADD_SHADER
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("flame", 1.0)
		return m
	if kind == "chrome":
		return glow_material(src, {"level": 7, "color": Color(1, 1, 1), "shine": Color(1, 1, 1)})
	return char_material(src, tint)

static func _hidden() -> ShaderMaterial:
	if _hidden_mat == null:
		_hidden_mat = ShaderMaterial.new()
		_hidden_mat.shader = HIDDEN_SHADER
	return _hidden_mat

## Lớp phát sáng: glow = {"level": int, "excellent": bool, "color": Color, "shine": Color}
static func glow_material(src: Material, glow: Dictionary) -> ShaderMaterial:
	var g := ShaderMaterial.new()
	g.shader = GLOW_SHADER
	var bm := src as BaseMaterial3D
	if bm:
		g.set_shader_parameter("albedo_tex", bm.albedo_texture)
		g.set_shader_parameter("alpha_cut", 0.25 if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else -1.0)
	g.set_shader_parameter("chrome_tex", fx("Chrome01"))
	g.set_shader_parameter("chrome2_tex", fx("Chrome02"))
	g.set_shader_parameter("chrome3_tex", fx("Chrome02"))   # ResolveMaterial: CHROME3 dùng BITMAP_CHROME2
	g.set_shader_parameter("terrain_light", terrain_light())
	g.set_shader_parameter("fixed_light", fixed_light)
	g.set_shader_parameter("brightness", BRIGHTNESS)
	g.set_shader_parameter("shiny_tex", fx("Shiny01"))
	g.set_shader_parameter("level", int(glow.get("level", 0)))
	g.set_shader_parameter("excellent", bool(glow.get("excellent", false)))
	var c: Color = glow.get("color", Color(1, 0.5, 0))
	var sc: Color = glow.get("shine", Color(1, 1, 1))
	g.set_shader_parameter("glow_color", Vector3(c.r, c.g, c.b))
	g.set_shader_parameter("shine_color", Vector3(sc.r, sc.g, sc.b))
	g.set_shader_parameter("ancient", bool(glow.get("ancient", false)))
	var ac: Color = glow.get("ancient_color", Color(0.0, 0.5, 1.0))
	g.set_shader_parameter("ancient_color", Vector3(ac.r, ac.g, ac.b))
	return g

## BodyLight theo cấp đồ (RenderPartObjectEffect, ZzzObject.cpp):
##   +0..2: 1 ; +3..4: (1, .6, .6) * g_Luminosity ; +5..6: (.5, .7, 1) * g_Luminosity ; +7..8: .8 ; +9..15: .9
## alpha < 1 = có nhấp nháy theo g_Luminosity (shader tự tính sin(t*4)*0.15+0.6)
static func level_tint(level: int) -> Color:
	if level >= 16:
		return Color(1, 1, 1)
	# MU gốc làm tối thân đồ (+7..8: 0.8, +9..15: 0.9); ở đây tăng sáng thân đồ cho đồ cấp cao nổi hơn
	if level >= 9:
		return Color(LEVEL_BODY_BRIGHT_9, LEVEL_BODY_BRIGHT_9, LEVEL_BODY_BRIGHT_9)
	if level >= 7:
		return Color(LEVEL_BODY_BRIGHT_7, LEVEL_BODY_BRIGHT_7, LEVEL_BODY_BRIGHT_7)
	if level >= 5:
		return Color(0.5, 0.7, 1.0, 0.5)
	if level >= 3:
		return Color(1.0, 0.6, 0.6, 0.5)
	return Color(1, 1, 1)

## Chạy action MU. loop: lặp lại ; speed: PlaySpeed của MU
static func play(ap: AnimationPlayer, action: int, play_speed: float = BASE_PLAY_SPEED, loop: bool = true, restart: bool = false) -> bool:
	if ap == null:
		return false
	var name := "a%03d" % action
	if not ap.has_animation(name):
		return false
	var anim := ap.get_animation(name)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	ap.speed_scale = play_speed / BASE_PLAY_SPEED
	if restart or ap.current_animation != name:
		ap.play(name, 0.08)
		if restart:
			ap.seek(0.0, true)
	return true
