extends "res://src/world/MuWorld.gd"
class_name MuLorenciaWorld

## Bản đồ Lorencia dựng lại từ dữ liệu GỐC của client MU (E:\MuMain\Client\Data):
##  - Địa hình: World1/TerrainHeight.OZB + EncTerrain1.map + TerrainLight.OZJ (xem MuTerrain.gd)
##  - Công trình: World1/EncTerrain1.obj (2870 vật thể: loại, vị trí, góc xoay 3 trục, tỉ lệ)
##  - Mô hình: Object1/*.bmd -> assets/lorencia/models/*.glb (đã áp ma trận xương, giữ animation)
##  - Hiệu ứng theo ZzzObject.cpp (WD_0LORENCIA): BlendMesh phát sáng, trôi UV, lửa đuốc, cây lay theo gió...

const MODELS_DIR := "res://assets/lorencia/models/"
const OBJECTS_JSON := "res://assets/lorencia/lorencia_objects.json"
const FIRES_JSON := "res://assets/lorencia/lorencia_fires.json"
const CHUNK := 32 # gom vật thể tĩnh theo ô 32x32 vào MultiMesh để giảm draw call

# --- Thông số lấy từ CreateObject()/MoveObject() của ZzzObject.cpp cho Lorencia ---
const MODEL_TREE01 := 0
const MODEL_TREASURE_CHEST := 59
const MODEL_STREET_LIGHT := 90
const MODEL_SIGN01 := 96
const MODEL_CANDLE := 150
# o->BlendMesh (chỉ số texture của mesh phát sáng) + hiệu ứng đi kèm
const BLEND_MESH := {
	117: {"mesh": 4, "flicker": [0.4, 0.7]},  # House03 (cửa sổ sáng chập chờn)
	118: {"mesh": 8, "scroll": 1.0},           # House04 (BlendMeshTexCoordV)
	119: {"mesh": 2, "scroll": 1.0},           # House05
	122: {"mesh": 4, "flicker": [0.4, 0.7]},  # HouseWall02
	105: {"mesh": 3, "scroll": 1.0},           # Waterspout (vòi nước)
	52: {"mesh": 1, "flicker": [0.4, 0.9]},   # Bonfire
	98: {"mesh": 2},                           # Carriage01
	90: {"mesh": 1},                           # StreetLight
	150: {"mesh": 1},                          # Candle
}
# MoveObject(): HouseWall05/06 (mái nhà) mờ đi khi HeroTile == 4 (nhân vật đứng trên sàn trong nhà)
const ROOF_TYPES := [125, 126]
const ROOF_HERO_TILE := 4
# o->HiddenMesh = -2 (không vẽ mô hình, chỉ có hiệu ứng)
const HIDDEN_TYPES := [130, 131, 132, 133]

var _object_shader: Shader = preload("res://src/shaders/mu_object.gdshader")
var _blend_shader: Shader = preload("res://src/shaders/mu_object_blend.gdshader")
var _fade_shader: Shader = preload("res://src/shaders/mu_object_fade.gdshader")
var _roof_materials: Array[ShaderMaterial] = []
var _roof_nodes: Array[Node3D] = []
var _roof_alpha: float = 1.0

var _scene_cache: Dictionary = {}
var _static_mesh_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _terrain_light_tex: Texture2D = null
var _fire_material: StandardMaterial3D = null

# Danh sách NPC Lorencia
var lorencia_npcs = [
	{"name": "Lumen the Barmaid", "id": 255, "title": "Cô Gái Quán Rượu", "x": 123, "y": 134, "role": "bar"},
	{"name": "Han the Blacksmith", "id": 251, "title": "Thợ Rèn Vũ Khí", "x": 116, "y": 141, "role": "blacksmith"},
	{"name": "Pasi the Mage", "id": 254, "title": "Pháp Sư Phép Thuật", "x": 118, "y": 113, "role": "mage"},
	{"name": "Alex the Merchant", "id": 230, "title": "Thương Nhân Giáp Trụ", "x": 115, "y": 130, "role": "armorer"},
	{"name": "Vault Keeper", "id": 240, "title": "Thủ Kho Lorencia", "x": 146, "y": 110, "role": "vault"},
	{"name": "Lorencia Guard East", "id": 249, "title": "Lính Gác Cổng Đông", "x": 152, "y": 123, "role": "guard"},
	{"name": "Lorencia Guard West", "id": 249, "title": "Lính Gác Cổng Tây", "x": 97, "y": 129, "role": "guard"},
	{"name": "Lorencia Guard South", "id": 247, "title": "Lính Gác Cổng Nam", "x": 132, "y": 85, "role": "guard"},
	{"name": "Lorencia Guard North", "id": 247, "title": "Lính Gác Cổng Bắc", "x": 121, "y": 149, "role": "guard"},
	{"name": "Wandering Merchant", "id": 250, "title": "Thương Nhân Lang Thang", "x": 183, "y": 137, "role": "potion"}
]

const MapObjectsScript = preload("res://src/world/MuMapObjects.gd")

func _ready() -> void:
	MuTerrain.ensure_loaded()
	if MuTerrain.world_id != 1:
		_ready_other_map()
		return
	_terrain_light_tex = load(MuTerrain.DIR + "terrain_light.png")
	var terrain := MuTerrain.new()
	terrain.name = "LorenciaTerrain"
	add_child(terrain)
	super._ready()
	_spawn_lorencia_structures()
	_spawn_all_lorencia_npcs()
	_spawn_ambient_fauna()

## Bản đồ khác Lorencia (assets/mu/maps/WorldN): địa hình + vật thể dựng chung, bỏ quái/NPC của Lorencia trong scene
func _ready_other_map() -> void:
	var terrain := MuTerrain.new()
	terrain.name = "Terrain_World%d" % MuTerrain.world_id
	add_child(terrain)
	var objs = MapObjectsScript.new()
	objs.name = "MapObjects"
	add_child(objs)
	objs.build(MuTerrain.world_id)
	for node in get_parent().get_children():
		if node is MuMonster or node is MuNpc:
			node.queue_free()
	super._ready()
	_spawn_server_npcs(MuTerrain.world_id)

# ------------------------------------------------------------------ Mái nhà (Alpha -> AlphaTarget)
func _process(delta: float) -> void:
	super._process(delta)
	if _roof_materials.is_empty() or player_node == null:
		return
	var tile := MuTerrain.layer1_at(player_node.grid_x, player_node.grid_y)
	var target := 0.0 if tile == ROOF_HERO_TILE else 1.0
	if is_equal_approx(_roof_alpha, target):
		return
	# Alpha() của MU tiến dần tới AlphaTarget ~0.1 mỗi tick 25fps
	_roof_alpha = move_toward(_roof_alpha, target, delta * 2.5)
	for m in _roof_materials:
		m.set_shader_parameter("fade", _roof_alpha)
	for n in _roof_nodes:
		n.visible = _roof_alpha > 0.01

# ------------------------------------------------------------------ NPC
## NPC của bản đồ theo server OpenMU (assets/mu/spawns.json): đúng ô đứng + hướng nhìn của MU
func _spawn_server_npcs(world: int) -> bool:
	var p := "res://assets/mu/spawns.json"
	if not FileAccess.file_exists(p):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary) or not d.has(str(world)):
		return false
	var parent_scene = get_parent()
	var used := {}
	for e in d[str(world)].get("npcs", []):
		var id := int(e.get("id", -1))
		var mon: Dictionary = load("res://src/mu/MuCatalog.gd").find_monster(id)
		var nm = mon.get("name", {})
		var en: String = str(nm.get("en", "NPC %d" % id)) if nm is Dictionary else str(nm)
		var npc = MuNpc.new()
		var key := "%s_%d_%d" % [en.replace(" ", ""), int(e["x"]), int(e["y"])]
		if used.has(key):
			continue
		used[key] = true
		npc.name = key
		npc.npc_name = en
		npc.npc_title = "Cửa hàng" if ShopWindow.has_shop(id) else ""
		npc.npc_id = id
		var dv: Array = e.get("dir", [0, 0])
		npc.facing_deg = rad_to_deg(atan2(float(dv[0]), -float(dv[1]))) if (int(dv[0]) != 0 or int(dv[1]) != 0) else 45.0
		npc.grid_x = int(e["x"])
		npc.grid_y = int(e["y"])
		npc.position = MuWorld.grid_to_world(npc.grid_x, npc.grid_y)
		parent_scene.add_child.call_deferred(npc)
	return true

func _spawn_all_lorencia_npcs() -> void:
	if FileAccess.file_exists("res://assets/mu/spawns.json"):
		for node in get_parent().get_children():
			if node is MuNpc:
				node.queue_free()   # NPC đặt tay trong scene -> thay bằng NPC đúng vị trí của server
		if _spawn_server_npcs(1):
			return
	var parent_scene = get_parent()
	for data in lorencia_npcs:
		var existing = parent_scene.get_node_or_null(data["name"].replace(" ", ""))
		if existing:
			continue
		var npc = MuNpc.new()
		npc.name = data["name"].replace(" ", "")
		npc.npc_name = data["name"]
		npc.npc_title = data["title"]
		npc.npc_id = int(data.get("id", -1))
		npc.facing_deg = 45.0
		npc.grid_x = data["x"]
		npc.grid_y = data["y"]
		npc.position = MuWorld.grid_to_world(data["x"], data["y"])
		parent_scene.add_child.call_deferred(npc)

# ------------------------------------------------------------------ Mô hình & vật liệu
func _get_scene(model: String) -> PackedScene:
	if _scene_cache.has(model):
		return _scene_cache[model]
	var path := MODELS_DIR + model + ".glb"
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path)
	else:
		push_warning("[MuLorenciaWorld] Thiếu mô hình: " + path)
	_scene_cache[model] = ps
	return ps

static func _find_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var r := _find_mesh_instance(c)
		if r:
			return r
	return null

static func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null

## Tên vật liệu trong .glb: "mu<chỉ số texture>__<tên texture>"
static func _material_tex_index(mat: Material) -> int:
	if mat == null:
		return -1
	var nm := mat.resource_name
	if nm.begins_with("mu"):
		var sep := nm.find("__")
		if sep > 2:
			return nm.substr(2, sep - 2).to_int()
	return -1

func _make_material(src: Material, obj_type: int) -> Material:
	var tex: Texture2D = null
	var alpha := false
	var bm := src as BaseMaterial3D
	if bm:
		tex = bm.albedo_texture
		alpha = bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var tex_idx := _material_tex_index(src)
	var blend: Dictionary = BLEND_MESH.get(obj_type, {})
	var is_blend: bool = not blend.is_empty() and blend.get("mesh", -99) == tex_idx
	var is_roof: bool = not is_blend and obj_type in ROOF_TYPES
	var mode := "o"
	if is_blend:
		mode = "b%d" % obj_type
	elif is_roof:
		mode = "roof"
	var key := "%s|%s|%s" % [str(tex.get_instance_id() if tex else 0), mode, str(alpha)]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := ShaderMaterial.new()
	if is_blend:
		m.shader = _blend_shader
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("scroll_v", blend.get("scroll", 0.0))
		var fl: Array = blend.get("flicker", [1.0, 1.0])
		m.set_shader_parameter("flicker_min", fl[0])
		m.set_shader_parameter("flicker_max", fl[1])
		m.set_shader_parameter("flicker_seed", float(obj_type))
	elif is_roof:
		m.shader = _fade_shader
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("terrain_light", _terrain_light_tex)
		m.set_shader_parameter("alpha_cut", 0.25 if alpha else -1.0)
		m.set_shader_parameter("fade", 1.0)
		_roof_materials.append(m)
	else:
		m.shader = _object_shader
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("terrain_light", _terrain_light_tex)
		m.set_shader_parameter("alpha_cut", 0.25 if alpha else -1.0)
	_material_cache[key] = m
	return m

## Mesh tĩnh (đã thay vật liệu) cho MultiMesh, cache theo (model, loại vật thể)
func _get_static_mesh(model: String, obj_type: int) -> Array:
	var key := "%s#%d" % [model, obj_type]
	if _static_mesh_cache.has(key):
		return _static_mesh_cache[key]
	var result := []
	var ps := _get_scene(model)
	if ps:
		var inst := ps.instantiate()
		var mi := _find_mesh_instance(inst)
		if mi and mi.mesh is ArrayMesh:
			var mesh := (mi.mesh as ArrayMesh).duplicate() as ArrayMesh
			for si in mesh.get_surface_count():
				mesh.surface_set_material(si, _make_material(mi.mesh.surface_get_material(si), obj_type))
			result = [mesh, _local_xform(mi, inst)]
		inst.free()
	_static_mesh_cache[key] = result
	return result

static func _local_xform(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

# ------------------------------------------------------------------ Công trình
func _spawn_lorencia_structures() -> void:
	if not FileAccess.file_exists(OBJECTS_JSON):
		push_error("[MuLorenciaWorld] Không tìm thấy " + OBJECTS_JSON)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(OBJECTS_JSON)) != OK:
		push_error("[MuLorenciaWorld] Lỗi đọc " + OBJECTS_JSON)
		return
	var objs: Array = json.get_data()

	var root := Node3D.new()
	root.name = "LorenciaStructures"
	add_child(root)
	var static_root := Node3D.new()
	static_root.name = "Static"
	root.add_child(static_root)
	var anim_root := Node3D.new()
	anim_root.name = "Animated"
	root.add_child(anim_root)
	var fx_root := Node3D.new()
	fx_root.name = "Effects"
	root.add_child(fx_root)

	_spawn_all_fires(fx_root)

	var animated_models := {}
	var batches := {} # key "model#type#chunk" -> Array[Transform3D]
	var n_anim := 0

	for o in objs:
		var t: int = int(o["t"])
		var model: String = o["m"]
		var b: Array = o["b"]
		var org: Array = o["o"]
		var xf := Transform3D(
			Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
			Vector3(org[0], org[1], org[2]))

		if t in HIDDEN_TYPES:
			continue

		if not animated_models.has(model):
			animated_models[model] = _is_animated_model(model)
		var velocity := _object_velocity(t, float(o.get("s", 1.0)))
		if animated_models[model] and velocity > 0.0:
			_spawn_animated(anim_root, model, t, xf, velocity)
			n_anim += 1
		else:
			var cx := int(org[0]) / CHUNK
			var cy := int(-org[2]) / CHUNK
			var key := "%s#%d#%d_%d" % [model, t, cx, cy]
			if not batches.has(key):
				batches[key] = []
			batches[key].append(xf)

	var n_static := 0
	for key in batches:
		var parts: PackedStringArray = key.split("#")
		var mesh_info := _get_static_mesh(parts[0], int(parts[1]))
		if mesh_info.is_empty():
			continue
		var xforms: Array = batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_info[0]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i] * mesh_info[1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("#", "_")
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		static_root.add_child(mmi)
		if int(parts[1]) in ROOF_TYPES:
			_roof_nodes.append(mmi)
		n_static += xforms.size()
	print("[MuLorenciaWorld] Lorencia: %d vật thể tĩnh (MultiMesh), %d vật thể chuyển động" % [n_static, n_anim])

func _is_animated_model(model: String) -> bool:
	var ps := _get_scene(model)
	if ps == null:
		return false
	var inst := ps.instantiate()
	var ap := _find_anim_player(inst)
	var res := ap != null and ap.has_animation("idle")
	inst.free()
	return res

## Tốc độ animation (o->Velocity, khung hình / tick 25fps) theo CreateObject() của Lorencia
func _object_velocity(t: int, scale_v: float) -> float:
	if t == MODEL_TREE01 or t == MODEL_TREE01 + 1:
		return 1.0 / maxf(scale_v, 0.01) * 0.4
	if t == MODEL_STREET_LIGHT or t == MODEL_CANDLE or t == MODEL_SIGN01 or t == MODEL_SIGN01 + 1:
		return 0.3
	if t == MODEL_TREASURE_CHEST:
		return 0.0
	return 0.16

func _spawn_animated(parent: Node3D, model: String, t: int, xf: Transform3D, velocity: float) -> void:
	var ps := _get_scene(model)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	inst.transform = xf
	parent.add_child(inst)
	var mi := _find_mesh_instance(inst)
	if mi and mi.mesh:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 60.0
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, _make_material(mi.mesh.surface_get_material(s), t))
	var ap := _find_anim_player(inst)
	if ap and ap.has_animation("idle"):
		var anim := ap.get_animation("idle")
		anim.loop_mode = Animation.LOOP_LINEAR
		# glb xuất ở 4 khung/giây (= Velocity 0.16 * 25 tick/giây)
		ap.speed_scale = velocity / 0.16
		ap.play("idle")

# ------------------------------------------------------------------ Lửa (CreateFire type 0 -> hạt BITMAP_FIRE)
## Theo ZzzEffectFireLeave.cpp / ZzzEffectParticle.cpp:
##  - texture Effect/Fire01.jpg (256x64, 4 khung ngang), vẽ cộng màu (Blend Glow)
##  - mỗi tick 25fps có 50% sinh 1 hạt, sống 24 tick (0.96 s), khung = (23 - LifeTime) / 6
##  - kích thước = 64 * Scale đơn vị MU, Scale 1.28..1.92 giảm 0.04 / tick
##  - Velocity (0, -(3.2..4.7), 0) xoay theo góc vật thể -> lửa trôi ngang ~1 m/s, Gravity tăng 0.004/tick -> bay lên
##  - màu (L, 0.6L, 0.4L), L = 0.6..1.1 ; vị trí lệch ngẫu nhiên +-8 đơn vị
## Ánh sáng cam mà lửa hắt xuống đất (AddTerrainLight, bán kính 4 ô) đã được bake vào terrain_light.png
func _spawn_all_fires(parent: Node3D) -> void:
	if not FileAccess.file_exists(FIRES_JSON):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(FIRES_JSON)) != OK:
		return
	for f in json.get_data():
		var p: Array = f["p"]
		var d: Array = f["d"]
		_spawn_fire(parent, Vector3(p[0], p[1], p[2]), Vector3(d[0], d[1], d[2]))

func _get_fire_material() -> StandardMaterial3D:
	if _fire_material:
		return _fire_material
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 4
	m.particles_anim_v_frames = 1
	m.particles_anim_loop = false
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = load("res://assets/lorencia/fire01.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_fire_material = m
	return m

func _spawn_fire(parent: Node3D, pos: Vector3, dir: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 8
	p.lifetime = 0.96
	p.preprocess = 1.0
	p.randomness = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = _get_fire_material()
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.06, 0.06, 0.06)
	p.direction = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	p.spread = 0.0
	p.initial_velocity_min = 0.80
	p.initial_velocity_max = 1.18
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
	# Giữ màu ngọn lửa nguyên bản như lúc đầu
	p.color = Color(0.85, 0.51, 0.34)
	var cv := Gradient.new()
	cv.set_color(0, Color(0.6, 0.36, 0.24))
	cv.set_color(1, Color(1.1, 0.66, 0.44))
	p.color_initial_ramp = cv
	p.visibility_range_end = 55.0
	parent.add_child(p)

# ------------------------------------------------------------------ Chim & cá (MODEL_BIRD01 / MODEL_FISH01 của Lorencia)
func _spawn_ambient_fauna() -> void:
	var container := Node3D.new()
	container.name = "LorenciaAmbientFauna"
	add_child(container)

	var bird_scene := _get_scene("Bird01")
	if bird_scene:
		var centers := [Vector2(132, 126), Vector2(118, 140), Vector2(146, 112)]
		for i in 6:
			var c: Vector2 = centers[i % centers.size()]
			var bird = MuAmbientFauna.new()
			bird.name = "AmbientBird_%d" % i
			bird.fauna_type = MuAmbientFauna.FaunaType.BIRD
			bird.center_pos = MuWorld.grid_to_world(c.x + randf_range(-4, 4), c.y + randf_range(-4, 4))
			bird.patrol_radius = randf_range(4.0, 8.0)
			bird.position = bird.center_pos + Vector3(0, 3.0, 0)
			bird.add_child(_make_fauna_model(bird_scene, 40))
			container.add_child(bird)

	var fish_scene := _get_scene("Fish01")
	if fish_scene:
		var water_tiles := []
		for y in range(100, 160):
			for x in range(100, 160):
				if MuTerrain.is_water(x, y):
					water_tiles.append(Vector2(x, y))
		water_tiles.shuffle()
		for i in mini(8, water_tiles.size()):
			var wt: Vector2 = water_tiles[i]
			var fish = MuAmbientFauna.new()
			fish.name = "AmbientFish_%d" % i
			fish.fauna_type = MuAmbientFauna.FaunaType.FISH
			fish.center_pos = MuWorld.grid_to_world(wt.x, wt.y)
			fish.patrol_radius = randf_range(0.8, 1.6)
			fish.position = fish.center_pos
			fish.add_child(_make_fauna_model(fish_scene, 999))
			container.add_child(fish)

func _make_fauna_model(ps: PackedScene, obj_type: int) -> Node3D:
	var inst: Node3D = ps.instantiate()
	var mi := _find_mesh_instance(inst)
	if mi and mi.mesh:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, _make_material(mi.mesh.surface_get_material(s), obj_type))
	var ap := _find_anim_player(inst)
	if ap and ap.has_animation("idle"):
		ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = randf_range(2.0, 3.0)
		ap.play("idle")
	return inst
