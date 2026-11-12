extends Node3D

## Vật thể của bản đồ WorldN (assets/mu/maps/WorldN/objects.json, tools/mu_maps.py):
##   - vật thể tĩnh   -> MultiMesh gom theo (model, ô 32x32)
##   - vật thể có xương + animation -> instance riêng, chạy action 0 lặp (Velocity 0.16 = 4 key/giây)
##   - mái nhà (Roofs) -> instance riêng với mu_object_fade.gdshader, tự động mờ biến mất khi vào nhà
##   - cửa ra vào (Doors) -> instance riêng, tự động xoay / trượt mở kèm âm thanh khi người chơi tới gần
## Màu = texture * ánh sáng địa hình tại gốc vật thể (BodyLight / RequestTerrainLight) — shader mu_object.

const OBJECT_SHADER := preload("res://src/shaders/mu_object.gdshader")
const BLEND_SHADER := preload("res://src/shaders/mu_object_blend.gdshader")
const HIDDEN_SHADER := preload("res://src/shaders/mu_hidden.gdshader")
const FADE_SHADER := preload("res://src/shaders/mu_object_fade.gdshader")
const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuObjectFxRes = preload("res://src/world/MuObjectFx.gd")
const MuChunkStreamerRes = preload("res://src/world/MuChunkStreamer.gd")

# ==================== ĐẶC TÍNH CÁC MAP (GỐC ZzzObject.cpp) ====================

## Vật thể ẩn (HiddenMesh = -2): vùng kích hoạt / va chạm, không render
## Khối ẩn / boundary triggers / điểm ngồi (HiddenMesh = -2 trong client gốc, không vẽ model)
const HIDDEN_TYPES_BY_WORLD: Dictionary = {
	1: [130, 131, 132, 133], # Lorencia: đèn vô hình, pose box
	2: [51, 52, 60],          # Dungeon: bẫy, pose box
	3: [91, 100],             # Devias: pose box, trigger
	4: [38],                  # Noria: điểm ngồi ghế/gốc cây (Pose Box / Object39)
	5: [24, 25],              # Lost Tower
	7: [38],                  # Stadium
	8: [22, 39],              # Atlans: pose box
	9: [60, 64, 70, 76, 83],  # Tarkan: hiệu ứng khói/cát
	11: [0, 1, 2, 3, 4, 5],   # Icarus / Heaven: mây
}
const DEVIAS_HIDDEN_TYPES := [91, 100]
const LORENCIA_HIDDEN_TYPES := [130, 131, 132, 133]

## Mái nhà (Roofs): mờ dần biến mất khi người chơi vào trong nhà
const DEVIAS_ROOF_TYPES := [81, 82, 96, 98, 99]
const LORENCIA_ROOF_TYPES := [125, 126]

## Cửa ra vào tương tác (Doors): xoay/trượt mở khi đứng gần (< 2.5m) kèm tiếng mở cửa
const DEVIAS_DOOR_TYPES := [20, 65, 86, 88]

## Mesh phát sáng / BlendMesh (vẽ cộng màu blend_add không bóng)
const DEVIAS_BLEND_MESH := {
	19: [0],     # Object20: aurora (cực quang bầu trời)
	54: [1],     # Object55: ngọn nến
	56: [1],     # Object57: ngọn nến
	78: [3],     # Object79: luồng ánh sáng cửa hầm (light_02)
	92: [0],     # Object93: băng sáng
	93: [0],     # Object94: băng sáng
}

const NORIA_BLEND_MESH := {
	1: [1],      # Object02
	9: [3],      # Object10
	17: [0],     # Object18
	18: [2],     # Object19
	19: [0],     # Object20
	37: [0],     # Object38
	39: [1],     # Object40
	41: [0],     # Object42
}

const LORENCIA_BLEND_MESH := {
	117: [4],
	118: [8],
	119: [2],
	122: [4],
	105: [3],
	52: [1],
	98: [2],
	90: [1],
	150: [1],
}

# ==================== BIẾN TRẠNG THÁI ====================

var world_id := 0
var _scene_cache: Dictionary = {}
var _static_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
var _light: Texture2D

var _roof_entries: Array[Dictionary] = []
var _door_entries: Array[Dictionary] = []
## Hạt phun theo nhịp (khói Tarkan, bong bóng Atlans...) — MuObjectFxRes.update_timed
var _timed_fx: Array = []
var _n_fx := 0

func build(n: int) -> void:
	world_id = n
	_roof_entries.clear()
	_door_entries.clear()
	_timed_fx.clear()
	_n_fx = 0

	var path := "res://assets/mu/maps/World%d/objects.json" % MuTerrain.files_world(n)   # nhiều map dùng chung thư mục
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

	# Vật thể chuyển động / có hiệu ứng và vật thể tĩnh: nạp theo vùng quanh người chơi
	var streamer = MuChunkStreamerRes.new()
	streamer.name = "Streamed"
	streamer.on_unload = _on_chunk_unload
	add_child(streamer)

	var roof_root := Node3D.new()
	roof_root.name = "Roofs"
	add_child(roof_root)

	var door_root := Node3D.new()
	door_root.name = "Doors"
	add_child(door_root)

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

		var obj_type := int(o.get("t", -1))
		var b: Array = o["b"]
		var org: Array = o["o"]
		var xf := Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
			Vector3(org[0], org[1], org[2]))
		# Hiệu ứng của vật thể theo ZzzObject.cpp (đèn, lửa, khói, mây, UV trôi...)
		var fx_e: Dictionary = MuObjectFxRes.entry(world_id, obj_type)

		# 1. Khối ẩn / boundary triggers / pose box (HiddenMesh = -2): không vẽ model,
		#    nhưng vẫn giữ hiệu ứng gắn với nó (khói, mây, đèn) nếu có
		var hidden_list: Array = HIDDEN_TYPES_BY_WORLD.get(world_id, [])
		if obj_type in hidden_list or fx_e.get("hidden", false):
			if MuObjectFxRes.needs_instance(fx_e):
				streamer.register(streamer.chunk_of_pos(xf.origin), _spawn_animated.bind(res_path, xf, obj_type, fx_e, true))
			continue

		# 2. Xử lý Mái nhà -> spawn riêng để fade khi người chơi vào trong nhà
		if (world_id == 3 and obj_type in DEVIAS_ROOF_TYPES) or (world_id == 1 and obj_type in LORENCIA_ROOF_TYPES):
			_spawn_roof(roof_root, res_path, xf, obj_type)
			continue

		# 3. Xử lý Cửa tương tác -> mở khi người chơi đến gần kèm âm thanh
		if world_id == 3 and obj_type in DEVIAS_DOOR_TYPES:
			_spawn_door(door_root, res_path, xf, obj_type)
			continue

		# 4. Vật thể hoạt ảnh (skeletal animation) hoặc có hiệu ứng gắn theo xương
		if not anim_flag.has(res_path):
			anim_flag[res_path] = _is_animated(res_path)
		if anim_flag[res_path] or MuObjectFxRes.needs_instance(fx_e):
			streamer.register(streamer.chunk_of_pos(xf.origin), _spawn_animated.bind(res_path, xf, obj_type, fx_e))
			n_anim += 1
		else:
			# 5. Gom MultiMesh theo chunk -> model + loại vật thể
			var ck: Vector2i = streamer.chunk_of_pos(xf.origin)
			if not batches.has(ck):
				batches[ck] = {}
			var key := "%s#%d" % [res_path, obj_type]
			if not batches[ck].has(key):
				batches[ck][key] = []
			batches[ck][key].append(xf)

	var n_static := 0
	for ck in batches:
		for key in batches[ck]:
			n_static += batches[ck][key].size()
		streamer.register(ck, _build_static_group.bind(batches[ck]))

	print("[MuMapObjects] World%d: %d tĩnh, %d chuyển động, %d có hiệu ứng, %d mái nhà, %d cửa, thiếu %d model" % [
		n, n_static, n_anim, _n_fx, _roof_entries.size(), _door_entries.size(), missing.size()
	])
	if not missing.is_empty():
		push_warning("[MuMapObjects] Thiếu model: %s (chạy MU Tools > Chuyển bản đồ)" % ", ".join(PackedStringArray(missing.keys().slice(0, 12))))

## Bỏ các hạt hẹn giờ thuộc chunk sắp bị gỡ
func _on_chunk_unload(_k: Vector2i, r: Node3D) -> void:
	_timed_fx = _timed_fx.filter(func(n): return is_instance_valid(n) and not r.is_ancestor_of(n))

## Dựng MultiMesh cho các vật thể tĩnh của một chunk ({"res#type": [Transform3D]})
func _build_static_group(r: Node3D, group: Dictionary) -> void:
	for key: String in group:
		var parts: PackedStringArray = key.split("#")
		var info := _static_mesh(parts[0], int(parts[1]))
		if info.is_empty():
			continue
		var xfs: Array = group[key]
		for part in info:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i] * part[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.layers |= MuModel.BLOOM_LAYER_MASK   # che bloom của nhân vật đứng sau vật thể
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			r.add_child(mmi)

func _process(delta: float) -> void:
	if not _timed_fx.is_empty():
		MuObjectFxRes.update_timed(_timed_fx, Time.get_ticks_msec() * 0.001)
	if _roof_entries.is_empty() and _door_entries.is_empty():
		return

	var player: Node3D = null
	var tree := get_tree()
	if tree:
		player = tree.get_first_node_in_group("Player") as Node3D
	if player == null and get_parent() and "player_node" in get_parent():
		player = get_parent().player_node
	if player == null:
		return

	_update_roofs(delta, player)
	_update_doors(delta, player)

# ==================== CẬP NHẬT MÁI NHÀ (FADE KHI VÀO NHÀ) ====================

func _spawn_roof(parent: Node3D, res_path: String, xf: Transform3D, _obj_type: int) -> void:
	var inst := (_scene_cache[res_path] as PackedScene).instantiate() as Node3D
	inst.transform = xf
	parent.add_child(inst)
	var mats: Array[ShaderMaterial] = []
	for mi in _find_all(inst, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(si)
			var sm := ShaderMaterial.new()
			sm.shader = FADE_SHADER
			var bm := src as BaseMaterial3D
			if bm:
				sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
				sm.set_shader_parameter("alpha_cut", 0.25 if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else -1.0)
			sm.set_shader_parameter("terrain_light", _light)
			sm.set_shader_parameter("fade", 1.0)
			m.set_surface_override_material(si, sm)
			mats.append(sm)
	_roof_entries.append({
		"node": inst,
		"materials": mats,
		"pos": Vector3(xf.origin.x, xf.origin.y, xf.origin.z),
		"alpha": 1.0
	})

func _update_roofs(delta: float, player: Node3D) -> void:
	if _roof_entries.is_empty():
		return

	var grid_x := 0
	var grid_y := 0
	if "grid_x" in player and "grid_y" in player:
		grid_x = player.grid_x
		grid_y = player.grid_y
	else:
		grid_x = int(player.global_position.x)
		grid_y = int(-player.global_position.z)

	var tile := MuTerrain.layer1_at(grid_x, grid_y)
	var is_inside := false
	if world_id == 3:
		# Devias: HeroTile == 3 || HeroTile >= 10 (ZzzObject.cpp)
		is_inside = (tile == 3 or tile >= 10)
	elif world_id == 1:
		# Lorencia: HeroTile == 4
		is_inside = (tile == 4)

	var p_pos: Vector3 = player.global_position
	for roof in _roof_entries:
		var target := 1.0
		if is_inside:
			var d: float = (roof["pos"] as Vector3).distance_to(p_pos)
			if d < 25.0:
				target = 0.0

		var cur_alpha: float = roof["alpha"]
		if not is_equal_approx(cur_alpha, target):
			cur_alpha = move_toward(cur_alpha, target, delta * 3.5)
			roof["alpha"] = cur_alpha
			for m in roof["materials"]:
				(m as ShaderMaterial).set_shader_parameter("fade", cur_alpha)
			(roof["node"] as Node3D).visible = cur_alpha > 0.01

# ==================== CẬP NHẬT CỬA TƯƠNG TÁC (XOAY / TRƯỢT & ÂM THANH) ====================

func _spawn_door(parent: Node3D, res_path: String, xf: Transform3D, obj_type: int) -> void:
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

	# Tính góc yaw từ ma trận xoay
	var yaw: float = round(atan2(xf.basis.z.x, xf.basis.x.x) * 180.0 / PI)
	var swing_dir: float = 1.0
	if is_equal_approx(yaw, 0.0) or is_equal_approx(yaw, 90.0):
		swing_dir = -1.0

	var is_sliding: bool = (obj_type == 86)
	var sound_name: String = "aCastleDoor.wav" if is_sliding else "aDoor.wav"

	_door_entries.append({
		"node": inst,
		"type": obj_type,
		"base_xf": xf,
		"pos": Vector3(xf.origin.x, xf.origin.y, xf.origin.z),
		"swing_dir": swing_dir,
		"is_sliding": is_sliding,
		"is_open": false,
		"progress": 0.0,
		"sound_name": sound_name,
	})

func _update_doors(delta: float, player: Node3D) -> void:
	if _door_entries.is_empty():
		return

	var p_pos: Vector3 = player.global_position
	for door in _door_entries:
		var d: float = (door["pos"] as Vector3).distance_to(p_pos)
		var should_open := (d < 2.5)
		var target_progress: float = 1.0 if should_open else 0.0

		if should_open and not door["is_open"]:
			door["is_open"] = true
			_play_door_sound(door["sound_name"], door["pos"], 0.0, 1.0)
		elif not should_open and door["is_open"]:
			door["is_open"] = false
			_play_door_sound(door["sound_name"], door["pos"], -4.0, 0.95)

		var cur_progress: float = door["progress"]
		if not is_equal_approx(cur_progress, target_progress):
			cur_progress = move_toward(cur_progress, target_progress, delta * 3.0)
			door["progress"] = cur_progress
			var node := door["node"] as Node3D
			var base_xf: Transform3D = door["base_xf"]
			if door["is_sliding"]:
				var offset: Vector3 = base_xf.basis * Vector3(cur_progress * 1.5, 0.0, 0.0)
				node.transform.origin = base_xf.origin + offset
			else:
				var angle: float = float(door["swing_dir"]) * deg_to_rad(75.0) * cur_progress
				node.transform.basis = base_xf.basis * Basis(Vector3.UP, angle)

func _play_door_sound(sound_file: String, pos: Vector3, volume_db: float, pitch: float) -> void:
	if ResourceLoader.exists("res://src/audio/MuAudioManager.gd"):
		var audio_mgr = load("res://src/audio/MuAudioManager.gd")
		if audio_mgr and audio_mgr.has_method("play_sound_file"):
			audio_mgr.play_sound_file(sound_file, volume_db, pitch, pos)

# ==================== XỬ LÝ MESH VÀ VẬT LIỆU ====================

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

## fx: tham số hiệu ứng mesh của MuObjectFx — {su, sv, flicker, sine} (blend) hoặc {stream_su, stream_sv}
func _material(src: Material, is_blend: bool = false, fx: Dictionary = {}) -> Material:
	var tex: Texture2D = null
	var alpha := false
	var bm := src as BaseMaterial3D
	if bm:
		tex = bm.albedo_texture
		alpha = bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED

	var stem := MuModelRes.tex_stem(src).to_lower()
	var kind: String = MuModelRes.mesh_script(stem)

	# Luồng sáng cửa hầm (light_02) hoặc cực quang (aurora) luôn vẽ cộng màu (additive blend)
	if stem.begins_with("light_") or stem.begins_with("aurora") or stem.contains("flare"):
		is_blend = true

	var key := "%d|%s|%s|%s|%s" % [tex.get_instance_id() if tex else 0, str(alpha), kind, str(is_blend), str(fx)]
	if _mat_cache.has(key):
		return _mat_cache[key]

	var m := ShaderMaterial.new()
	if kind == "hide":
		m.shader = HIDDEN_SHADER
		_mat_cache[key] = m
		return m

	if is_blend or kind == "bright":
		# BlendMesh cộng màu, không bị đổ bóng địa hình làm đen
		m.shader = BLEND_SHADER
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("scroll_u", float(fx.get("su", 0.0)))
		m.set_shader_parameter("scroll_v", float(fx.get("sv", 0.0)))
		var fl: Array = fx.get("flicker", [1.0, 1.0])
		m.set_shader_parameter("flicker_min", float(fl[0]))
		m.set_shader_parameter("flicker_max", float(fl[1]))
		m.set_shader_parameter("flicker_seed", float(fx.get("seed", 0.0)))
		if fx.has("sine"):
			var sn: Array = fx["sine"]
			m.set_shader_parameter("sine_amp", float(sn[0]))
			m.set_shader_parameter("sine_base", float(sn[1]))
			m.set_shader_parameter("sine_freq", float(sn[2]))
			m.set_shader_parameter("sine_phase", float(fx.get("phase", 0.0)))
		_mat_cache[key] = m
		return m

	m.shader = OBJECT_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("terrain_light", _light)
	m.set_shader_parameter("alpha_cut", 0.25 if alpha else -1.0)
	m.set_shader_parameter("scroll_u", float(fx.get("stream_su", 0.0)))
	m.set_shader_parameter("scroll_v", float(fx.get("stream_sv", 0.0)))
	_mat_cache[key] = m
	return m

## [[mesh đã thay vật liệu, transform cục bộ], ...]
func _static_mesh(res_path: String, obj_type: int) -> Array:
	var cache_key := "%s#%d" % [res_path, obj_type]
	if _static_cache.has(cache_key):
		return _static_cache[cache_key]

	var out := []
	var inst: Node = (_scene_cache[res_path] as PackedScene).instantiate()
	for mi in _find_all(inst, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if not (m.mesh is ArrayMesh):
			continue
		var mesh := (m.mesh as ArrayMesh).duplicate() as ArrayMesh
		for si in mesh.get_surface_count():
			var sm := _surface_fx(obj_type, si, MuObjectFxRes.entry(world_id, obj_type), 0.0)
			mesh.surface_set_material(si, _material(m.mesh.surface_get_material(si), sm[0], sm[1]))
		out.append([mesh, _local_xform(m, inst)])
	inst.free()
	_static_cache[cache_key] = out
	return out

## Mesh blend / stream của 1 surface: [is_blend, tham số shader]
func _surface_fx(obj_type: int, si: int, fx_e: Dictionary, phase: float) -> Array:
	var is_blend := false
	if world_id == 3 and DEVIAS_BLEND_MESH.has(obj_type) and si in DEVIAS_BLEND_MESH[obj_type]:
		is_blend = true
	elif world_id == 1 and LORENCIA_BLEND_MESH.has(obj_type) and si in LORENCIA_BLEND_MESH[obj_type]:
		is_blend = true
	elif world_id == 4 and NORIA_BLEND_MESH.has(obj_type) and si in NORIA_BLEND_MESH[obj_type]:
		is_blend = true
	var params := {}
	if fx_e.has("blend"):
		var bl: Dictionary = fx_e["blend"]
		var meshes: Array = bl.get("mesh", [])
		if si in meshes:
			is_blend = true
		# mesh bỏ trống: tham số áp cho mesh đã phát sáng sẵn (theo tên texture / bảng BLEND_MESH)
		if si in meshes or meshes.is_empty():
			params = bl.duplicate()
			params.erase("mesh")
			if params.has("sine") and (params["sine"] as Array).size() > 3:
				params["phase"] = phase * float(params["sine"][3])
			params["seed"] = float(obj_type)
	if fx_e.has("stream"):
		var st: Dictionary = fx_e["stream"]
		if int(st.get("mesh", -1)) == si:
			params["stream_su"] = float(st.get("su", 0.0))
			params["stream_sv"] = float(st.get("sv", 0.0))
	return [is_blend, params]

func _spawn_animated(parent: Node3D, res_path: String, xf: Transform3D, obj_type: int = -1,
		fx_e: Dictionary = {}, hide_mesh: bool = false) -> void:
	var inst := (_scene_cache[res_path] as PackedScene).instantiate() as Node3D
	inst.transform = xf
	parent.add_child(inst)
	# pha riêng cho từng vật thể (MU dùng o->Angle[2] để lệch nhịp sáng giữa các đèn)
	var phase := fmod(absf(xf.origin.x * 7.31 + xf.origin.z * 3.17), 100.0)
	for mi in _find_all(inst, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if hide_mesh:
			m.visible = false
			continue
		for si in m.mesh.get_surface_count():
			var sm := _surface_fx(obj_type, si, fx_e, phase)
			m.set_surface_override_material(si, _material(m.mesh.surface_get_material(si), sm[0], sm[1]))
	var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
	if ap and ap.get_animation_list().size() > 0:
		var names := ap.get_animation_list()
		var first := "a000" if ap.has_animation("a000") else names[0]
		ap.get_animation(first).loop_mode = Animation.LOOP_LINEAR
		ap.play(first)
		ap.speed_scale = float(fx_e.get("speed", 1.0))
		ap.seek(randf() * ap.get_animation(first).length, true)
	if not fx_e.is_empty():
		var timed: Array = MuObjectFxRes.attach(inst, fx_e, phase)
		_timed_fx.append_array(timed)
		if fx_e.has("sprites") or fx_e.has("fires") or fx_e.has("smoke") or fx_e.has("particles"):
			_n_fx += 1
