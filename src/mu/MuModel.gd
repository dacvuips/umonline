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
## Độ sáng chung của nhân vật, quái, NPC và các lớp phát sáng của đồ. 1 = như client gốc: shader đã tính
## đúng trong không gian gamma (trước đây đổi sang linear làm tối nên phải nhân bù 1.4 .. 1.7).
const BRIGHTNESS := 1.0
## Độ sáng thân model (mu_character*.gdshader), 1 = như client gốc.
const BODY_BRIGHTNESS := 1.0
## Độ sáng thân đồ theo cấp
const LEVEL_BODY_BRIGHT_7 := 1.1    # +7, +8
const LEVEL_BODY_BRIGHT_9 := 1   # +9 .. +15
## Độ sáng lớp phủ phát sáng theo cấp của đồ MẶC TRÊN NGƯỜI / ngoài thế giới
## (mu_item_glow.gdshader). Ảnh đồ trong túi / rương dùng bộ riêng: MuItemIcon.ICON_GLOW_GAIN_*
const GLOW_GAIN_7 := 0.45  # +7 .. +10
const GLOW_GAIN_11 := 0.85  # +11, +12
const GLOW_GAIN_13 := 1  # +13 .. +15
const HIDDEN_SHADER := preload("res://src/shaders/mu_hidden.gdshader")
## Visual layer 20: mesh của model MU (nhân vật, quái, NPC, đồ, thú) — nguồn bloom của MuModelBloom
const BLOOM_LAYER_MASK := 1 << 19
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
## Hệ số nhân thêm vào BRIGHTNESS cho vật liệu đang dựng (quái / NPC đặt > 1 trong build_monster)
static var brightness_scale: float = 1.0

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

## Texture hiệu ứng (chrome / shiny...). Bản web tải nội dung theo gói: texture có thể CHƯA có lúc gọi lần đầu
## (vd. màn chọn nhân vật chỉ có gói tier 1) -> KHÔNG nhớ kết quả null, và khi gói mới nạp xong thì làm mới vật liệu cũ
## (nếu không, đồ trong game mất lớp bóng loáng kim loại vì vật liệu cũ giữ texture null mãi mãi).
static var _content_hooked := false

## Mảng số từ JSON (float) -> int. Trong Godot `1 in [1.0]` là FALSE nên các điều kiện "mesh số N" luôn sai nếu không đổi.
static func ints(a: Array) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

static func fx(name: String) -> Texture2D:
	var t = _fx.get(name)
	if t != null:
		return t
	var p := "res://assets/mu/fx/%s.jpg" % name
	if ResourceLoader.exists(p):
		t = load(p)
		_fx[name] = t
		return t
	_hook_content()
	return null

static func _hook_content() -> void:
	if _content_hooked:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var mc: Node = tree.root.get_node_or_null("MuContent") if tree and tree.root else null
	if mc == null or not mc.has_signal("tier_ready"):
		return
	_content_hooked = true
	mc.connect("tier_ready", func(_t): flush_content_caches())

## Gói nội dung mới vừa nạp: bỏ vật liệu / ảnh đồ đã dựng khi còn thiếu texture
static func flush_content_caches() -> void:
	_mats.clear()
	for k in _fx.keys():
		if _fx[k] == null:
			_fx.erase(k)
	var icon_script = load("res://src/ui/MuItemIcon.gd")
	if icon_script != null:
		var c = icon_script.get("_cache")
		if c is Dictionary:
			c.clear()

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
	if sep >= 0:
		return nm.substr(sep + 2)
	var bm := src as BaseMaterial3D
	if bm and bm.albedo_texture and bm.albedo_texture.resource_path != "":
		return bm.albedo_texture.resource_path.get_file().get_basename()
	return nm

## TextureScriptParsing::parsingTScriptA của MU: hậu tố sau dấu "_" ĐẦU TIÊN của tên texture
##   R = Bright (cộng màu, không ánh sáng) ; H = ẩn ; S = stream ; N = không blend ; DC/DT = bóng
## Trả về "hide" | "bright" | "stream" | "none" | ""
static func mesh_script(stem: String) -> String:
	var low := stem.to_lower()
	if low == "hide" or low.ends_with("_hide"):
		return "hide"     # texture hide.jpg -> BITMAP_HIDE: không vẽ
	# Cánh và hiệu ứng có nền đen cần vẽ cộng sáng (EnableAlphaBlend / blend_add) như MU gốc
	if low in ["newingel", "elfin_wing", "elfw2_06", "elfw_06", "alicewing_01", "fairy2", "condolswing", "ju01", "ju01_r", "neww_r", "ndw_r", "elfwing3d_r", "cherrywing_r", "snowmanwing_r", "amuletelfwing_r", "amuletspititwing_r"]:
		return "bright"
	if low.ends_with("_r") or low.ends_with("_bright") or low.ends_with("_add") or low.contains("_r_"):
		return "bright"
	var u := stem.find("_")
	if u < 0:
		return ""
	var tok := stem.substr(u, 5)
	var res := {}
	var i := 1
	while i < tok.length():
		var ch := tok[i].to_upper()
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
				if i + 1 < tok.length() and (tok[i + 1].to_upper() == "C" or tok[i + 1].to_upper() == "T"):
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

## Kiểm tra texture có phải da thịt, khuôn mặt hoặc tóc của nhân vật hay không (tương đương MarkSkinAndHair trong source gốc).
## Trong source gốc, khi vẽ đồ vật (inventory / ground), cờ HideSkin = true làm ẩn các mesh này.
static func is_skin_or_hair(stem: String) -> bool:
	var low := stem.to_lower()
	# Không ẩn nếu là phần mũ bảo hiểm hoặc giáp
	if "helmet" in low or "_helm" in low:
		return false
	# Không ẩn các phần giáp/quần/găng/giày của RF/Summoner có đuôi _upper, _lower, _glove, _boot
	if "_upper" in low or "_lower" in low or "_glove" in low or "_boot" in low:
		return false
	# 1. Texture da nhân vật trong MU gốc (Webzen C++: fileName starts with "ski" hoặc "level")
	# VD: skin_barbarian_01, skin_warrior_01, skin_wizard_01, skin_special_01,
	#     level_man01, level_man02, level_man022, level_man033, LevelClass107, LevelClass207, skinClass...
	if low.begins_with("skin") or low.begins_with("level"):
		return true
	# 2. Texture tóc nhân vật trong MU gốc (bắt đầu bằng "hair" hoặc chứa "hair")
	# VD: hair_R, guard_hair, cobraset_hair, RFighter_Hair, ...headhair...
	if low.begins_with("hair") or "hair" in low:
		return true
	# 3. Texture mặt/đầu nhân vật gắn trong các model mũ (Season 4+)
	# VD: darknight_face, richface, DK_face, Item3002_Head, Item6001_head, head_n
	if "face" in low:
		return true
	if "head_n" in low or (low.ends_with("_head") and "item" in low):
		return true
	return false

## Ánh xạ texture thay thế khi vẽ đồ trong ô / rớt đất (HideSkin = true trong Webzen C++: ItemRenderStyles.cpp)
## Đối với các set Summoner và Seraphim/Succubus, model 3D là thân nhân vật kèm giáp.
## Khi vẽ đồ vật, MU thay texture sang file chuyên dụng có kênh alpha để làm trong suốt phần da thịt nhân vật.
static func inven_texture_path(g: int, n: int) -> String:
	if g == 8: # Áo (Armor)
		match n:
			39: return "res://assets/mu/Player/inven_tex/InvenArmorMale40.png"
			40: return "res://assets/mu/Player/inven_tex/InvenArmorMale41.png"
			41: return "res://assets/mu/Player/inven_tex/InvenArmorMale42.png"
			42: return "res://assets/mu/Player/inven_tex/InvenArmorMale43.png"
			43: return "res://assets/mu/Player/inven_tex/InvenArmorMale44.png"
			44: return "res://assets/mu/Player/inven_tex/InvenArmorMale45.png"
			50: return "res://assets/mu/Player/inven_tex/Item312_Armoritem.png"
			53: return "res://assets/mu/Player/inven_tex/SkinClass706_upperitem.png"
			65: return "res://assets/mu/Player/inven_tex/InvenArmorMale40_luck.png"
			70: return "res://assets/mu/Player/inven_tex/InvenArmorMale41_luck.png"
	elif g == 9: # Quần (Pants)
		match n:
			39: return "res://assets/mu/Player/inven_tex/InvenPantsMale40.png"
			40: return "res://assets/mu/Player/inven_tex/InvenPantsMale41.png"
			41: return "res://assets/mu/Player/inven_tex/InvenPantsMale42.png"
			42: return "res://assets/mu/Player/inven_tex/InvenPantsMale43.png"
			43: return "res://assets/mu/Player/inven_tex/InvenPantsMale44.png"
			44: return "res://assets/mu/Player/inven_tex/InvenPantsMale45.png"
			# 49 (Seraphim Pants) KHÔNG có renderStyle trong source gốc -> vẽ texture thường (Item302_Pant)
			50: return "res://assets/mu/Player/inven_tex/Item312_Pantitem.png"
			53: return "res://assets/mu/Player/inven_tex/SkinClass706_loweritem.png"
			65: return "res://assets/mu/Player/inven_tex/InvenPantsMale40_luck.png"
			70: return "res://assets/mu/Player/inven_tex/InvenPantsMale41_luck.png"
	return ""

static var _hidden_mat: ShaderMaterial = null

## Vật liệu MU cho 1 surface (cache theo texture + kiểu + tint)
static func char_material(src: Material, tint: Color = Color(1, 1, 1), spec: float = 0.0, override_tex: Texture2D = null) -> ShaderMaterial:
	var tex: Texture2D = override_tex
	var alpha := override_tex != null
	if tex == null:
		var bm := src as BaseMaterial3D
		if bm:
			tex = bm.albedo_texture
			alpha = bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var kind := mesh_script(tex_stem(src)) if override_tex == null else ""
	if kind == "hide":
		if _hidden_mat == null:
			_hidden_mat = ShaderMaterial.new()
			_hidden_mat.shader = HIDDEN_SHADER
		return _hidden_mat
	var key := "%d|%s|%s|%s|%.2f|%.2f|%.2f" % [tex.get_instance_id() if tex else 0, str(alpha), kind, "%.3f,%.3f,%.3f,%.2f" % [tint.r, tint.g, tint.b, tint.a], fixed_light, spec, brightness_scale]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	if kind == "bright":
		m.shader = CHAR_ADD_SHADER
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("intensity", 1.0)
		m.set_shader_parameter("light", Vector3(tint.r, tint.g, tint.b))
		_mats[key] = m
		return m
	m.shader = CHAR_ALPHA_SHADER if alpha else CHAR_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("terrain_light", terrain_light())
	m.set_shader_parameter("alpha_cut", 0.02 if override_tex != null else (0.25 if alpha else -1.0))
	# tint > 1 (đồ +7 trở lên): phần vượt 1 nhân thẳng vào màu đồ (body_boost), không qua đoạn nén sáng (knee)
	var boost := maxf(maxf(tint.r, tint.g), maxf(tint.b, 1.0))
	m.set_shader_parameter("body_tint", Vector3(tint.r, tint.g, tint.b) / boost)
	# quái / NPC (brightness_scale > 1): tăng cả sau bước nén sáng (knee), nếu không chỗ sáng gần như không đổi
	m.set_shader_parameter("body_boost", boost * (1.0 + (brightness_scale - 1.0) * 0.6))
	m.set_shader_parameter("tint_pulse", 1.0 if tint.a < 0.99 else 0.0)
	m.set_shader_parameter("fixed_light", fixed_light)
	m.set_shader_parameter("specular", spec)
	m.set_shader_parameter("brightness", BODY_BRIGHTNESS * brightness_scale)
	_mats[key] = m
	return m

## Thay toàn bộ vật liệu trong cây node.
## glow = {"level","excellent","color","shine", "style": renderStyle, "meshes": [..], "hidden": mesh}
static func apply_materials(root: Node, tint: Color = Color(1, 1, 1), glow: Dictionary = {}) -> void:
	var lvl := int(glow.get("level", 0))
	var want_glow := lvl >= 7 or bool(glow.get("excellent", false)) or bool(glow.get("ancient", false))
	var style := str(glow.get("style", ""))
	var only: Array = ints(glow.get("meshes", [])) if glow.get("meshes") is Array else []
	var hidden_mesh := int(glow.get("hidden", -1))
	var spec := float(glow.get("specular", 0.0))
	var hide_skin := bool(glow.get("hide_skin", false))
	for mi in find_all(root, "MeshInstance3D", []):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers |= BLOOM_LAYER_MASK   # camera bloom (MuModelBloom) chỉ vẽ layer này
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var stem := tex_stem(src)
			if hide_skin and is_skin_or_hair(stem):
				mi.set_surface_override_material(s, _hidden())
				continue
			var inven_override_tex: Texture2D = null
			if hide_skin and s == 0 and glow.has("group") and glow.has("number"):
				var itp := inven_texture_path(int(glow["group"]), int(glow["number"]))
				if itp != "" and ResourceLoader.exists(itp):
					inven_override_tex = load(itp)
			var chain: Array = []
			# kiểu vẽ chuyển tự động từ source gốc (assets/mu/item_styles.json)
			var jm = null
			if inven_override_tex == null and style != "":
				jm = ItemStylesRes.json_materials(style, s, src, tint, fixed_light,
					mesh_script(tex_stem(src)) == "bright", terrain_light())
			if jm != null and mesh_script(tex_stem(src)) == "hide":
				jm = []
			# itemEffect "Applied": các lớp của hiệu ứng vẽ trước, rồi vẽ món đồ như thường / theo renderStyle
			if jm != null and bool(glow.get("fx_base", false)) and not (jm as Array).is_empty():
				var bs := str(glow.get("base_style", ""))
				var bj = ItemStylesRes.json_materials(bs, s, src, tint, fixed_light,
					mesh_script(tex_stem(src)) == "bright", terrain_light()) if bs != "" else null
				jm = (jm as Array) + (bj if bj != null else [char_material(src, tint, spec, inven_override_tex)])
			var styled: Array = ItemStylesRes.passes_for(style, s) if (style != "" and jm == null and inven_override_tex == null) else []
			if jm != null:
				chain.append_array(jm)
				if chain.is_empty():
					chain.append(_hidden())
			elif styled.is_empty():
				chain.append(char_material(src, tint, spec, inven_override_tex))
			else:
				for e in styled:
					var m := _style_pass(src, tint, e)
					if m != null:
						chain.append(m)
			if chain.is_empty():
				chain.append(char_material(src, tint, spec, inven_override_tex))
			# lớp chrome / excellent không vẽ lên mesh ẩn / mesh sáng (ResolveMaterial: NoneBlendMesh, Bright)
			var first: ShaderMaterial = chain[0]
			if want_glow and first.shader != HIDDEN_SHADER and first.shader != CHAR_ADD_SHADER \
					and (only.is_empty() or s in only) and s != hidden_mesh:
				chain.append(MuModel.glow_material(src, glow, inven_override_tex if s == 0 else null))
			# itemEffect: BlendMeshLight nhấp nháy của mesh sáng (redSpirit, wingsOfSoul, wingsOfDragon)
			var bp: Vector3 = glow.get("blend_pulse", Vector3.ZERO)
			if bp != Vector3.ZERO:
				for i in chain.size():
					if (chain[i] as ShaderMaterial).shader == CHAR_ADD_SHADER:
						chain[i] = (chain[i] as ShaderMaterial).duplicate()
						(chain[i] as ShaderMaterial).set_shader_parameter("sin_pulse", bp)
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
static func glow_material(src: Material, glow: Dictionary, override_tex: Texture2D = null) -> ShaderMaterial:
	var g := ShaderMaterial.new()
	g.shader = GLOW_SHADER
	var bm := src as BaseMaterial3D
	var tex: Texture2D = override_tex if override_tex != null else (bm.albedo_texture if bm else null)
	var has_alpha: bool = override_tex != null or (bm != null and bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
	if tex:
		g.set_shader_parameter("albedo_tex", tex)
		g.set_shader_parameter("alpha_cut", 0.02 if override_tex != null else (0.25 if has_alpha else -1.0))
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
	g.set_shader_parameter("glow_gain_7", GLOW_GAIN_7)
	g.set_shader_parameter("glow_gain_11", GLOW_GAIN_11)
	g.set_shader_parameter("glow_gain_13", GLOW_GAIN_13)
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
