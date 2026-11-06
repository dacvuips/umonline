extends Node3D

## Vật thể của bản đồ WorldN (assets/mu/maps/WorldN/objects.json, tools/mu_maps.py):
##   - vật thể tĩnh   -> MultiMesh gom theo (model, ô 32x32)  (giống cách làm Lorencia)
##   - vật thể có xương + animation -> instance riêng, chạy action 0 lặp (Velocity 0.16 = 4 key/giây)
## Màu = texture * ánh sáng địa hình tại gốc vật thể (BodyLight / RequestTerrainLight) — shader mu_object.

const CHUNK := 32
const OBJECT_SHADER := preload("res://src/shaders/mu_object.gdshader")
const BLEND_SHADER := preload("res://src/shaders/mu_object_blend.gdshader")
const HIDDEN_SHADER := preload("res://src/shaders/mu_hidden.gdshader")
const MuModelRes = preload("res://src/mu/MuModel.gd")

var world_id := 0
var _scene_cache: Dictionary = {}
var _static_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
var _light: Texture2D

func build(n: int) -> void:
	world_id = n
	var path := "res://assets/mu/maps/World%d/objects.json" % n
	if not FileAccess.file_exists(path):
		push_warning("[MuMapObjects] Chưa có " + path)
		return
	var raw_str := FileAccess.get_file_as_string(path)
	if raw_str.contains("NaN") or raw_str.contains("nan") or raw_str.contains("Infinity"):
		raw_str = raw_str.replace("NaN", "0.0").replace("nan", "0.0").replace("Infinity", "0.0")
	var data = JSON.parse_string(raw_str)
	if not (data is Dictionary):
		push_error("[MuMapObjects] Lỗi parse JSON: " + path)
		return
	_light = MuTerrain.light_texture()
	var static_root := Node3D.new()
	static_root.name = "Static"
	add_child(static_root)
	var anim_root := Node3D.new()
	anim_root.name = "Animated"
	add_child(anim_root)
	var batches := {}
	var anim_flag := {}
	var n_anim := 0
	var missing := {}
	for o in data.get("objects", []):
		var model: String = o["m"]
		var res_path := "res://assets/mu/%s.glb" % model
		if not _scene_cache.has(res_path):
			_scene_cache[res_path] = load(res_path) if ResourceLoader.exists(res_path) else null
		if _scene_cache[res_path] == null:
			missing[model] = true
			continue
		var b: Array = o["b"]
		var org: Array = o["o"]
		var xf := Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
			Vector3(org[0], org[1], org[2]))
		if not anim_flag.has(res_path):
			anim_flag[res_path] = _is_animated(res_path)
		if anim_flag[res_path]:
			_spawn_animated(anim_root, res_path, xf)
			n_anim += 1
		else:
			var key := "%s#%d_%d" % [res_path, int(org[0]) / CHUNK, int(-org[2]) / CHUNK]
			if not batches.has(key):
				batches[key] = []
			batches[key].append(xf)
	var n_static := 0
	for key in batches:
		var res_path: String = key.split("#")[0]
		var info := _static_mesh(res_path)
		if info.is_empty():
			continue
		var xfs: Array = batches[key]
		for part in info:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i] * part[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			static_root.add_child(mmi)
		n_static += xfs.size()
	print("[MuMapObjects] World%d: %d tĩnh, %d chuyển động, thiếu %d model" % [n, n_static, n_anim, missing.size()])
	if not missing.is_empty():
		push_warning("[MuMapObjects] Thiếu model: %s (chạy MU Tools > Chuyển bản đồ)" % ", ".join(PackedStringArray(missing.keys().slice(0, 12))))

func _is_animated(res_path: String) -> bool:
	var inst: Node = (_scene_cache[res_path] as PackedScene).instantiate()
	var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
	var ok := ap != null and ap.get_animation_list().size() > 0
	inst.free()
	return ok

static func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null

static func _find_all(n: Node, cls: String, out: Array) -> Array:
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		_find_all(c, cls, out)
	return out

static func _local_xform(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func _material(src: Material) -> Material:
	var tex: Texture2D = null
	var alpha := false
	var bm := src as BaseMaterial3D
	if bm:
		tex = bm.albedo_texture
		alpha = bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var kind: String = MuModelRes.mesh_script(MuModelRes.tex_stem(src))
	var key := "%d|%s|%s" % [tex.get_instance_id() if tex else 0, str(alpha), kind]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	if kind == "hide":
		m.shader = HIDDEN_SHADER
		_mat_cache[key] = m
		return m
	if kind == "bright":
		# texture hậu tố _R: cộng màu, không ánh sáng (giống BlendMesh của Lorencia)
		m.shader = BLEND_SHADER
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("scroll_v", 0.0)
		m.set_shader_parameter("flicker_min", 1.0)
		m.set_shader_parameter("flicker_max", 1.0)
		m.set_shader_parameter("flicker_seed", 0.0)
		_mat_cache[key] = m
		return m
	m.shader = OBJECT_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("terrain_light", _light)
	m.set_shader_parameter("alpha_cut", 0.25 if alpha else -1.0)
	_mat_cache[key] = m
	return m

## [[mesh đã thay vật liệu, transform cục bộ], ...]
func _static_mesh(res_path: String) -> Array:
	if _static_cache.has(res_path):
		return _static_cache[res_path]
	var out := []
	var inst: Node = (_scene_cache[res_path] as PackedScene).instantiate()
	for mi in _find_all(inst, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if not (m.mesh is ArrayMesh):
			continue
		var mesh := (m.mesh as ArrayMesh).duplicate() as ArrayMesh
		for si in mesh.get_surface_count():
			mesh.surface_set_material(si, _material(m.mesh.surface_get_material(si)))
		out.append([mesh, _local_xform(m, inst)])
	inst.free()
	_static_cache[res_path] = out
	return out

func _spawn_animated(parent: Node3D, res_path: String, xf: Transform3D) -> void:
	var inst := (_scene_cache[res_path] as PackedScene).instantiate() as Node3D
	inst.transform = xf
	parent.add_child(inst)
	for mi in _find_all(inst, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in m.mesh.get_surface_count():
			m.set_surface_override_material(si, _material(m.mesh.surface_get_material(si)))
	var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
	if ap:
		var names := ap.get_animation_list()
		var first := "a000" if ap.has_animation("a000") else names[0]
		ap.get_animation(first).loop_mode = Animation.LOOP_LINEAR
		ap.play(first)
		ap.seek(randf() * ap.get_animation(first).length, true)
