extends Node3D
class_name MuTerrain

## Địa hình Lorencia dựng từ dữ liệu gốc của client MU (Data/World1):
##   TerrainHeight.OZB  -> chiều cao (byte * 1.5 đơn vị MU)
##   EncTerrain1.map    -> 2 lớp tile + alpha mỗi đỉnh
##   TerrainLight.OZJ   -> ánh sáng tĩnh (đã nhân N·Sun + 0.5 như CreateTerrainLight)
##   EncTerrain1.att    -> thuộc tính ô (an toàn / không đi được / ...)
## Hệ toạ độ: 1 ô MU (100 đơn vị) = 1 mét Godot.  Ô (x, y) của MU -> Godot (x, h, -y)

const TERRAIN_SIZE := 256
const HEIGHT_SCALE := 1.5 / 100.0
const DIR := "res://assets/lorencia/terrain/"

# Toạ độ V của từng loại cỏ trong grass_atlas (TileGrass01/02/03.OZT) và chiều cao (Bitmap.Height * 2 đơn vị MU)
const GRASS_V_OFFSET := [0.0, 0.25, 0.5]
const GRASS_V_SIZE := [0.25, 0.25, 0.5]
const GRASS_HEIGHT := [1.28, 1.28, 2.56]
const GRASS_CHUNK := 32

@export var grass_enabled: bool = true
@export var grass_visibility_range: float = 42.0

## Bản đồ đang dùng: 1 = Lorencia (bộ dữ liệu riêng assets/lorencia), khác = assets/mu/maps/WorldN/terrain.mumap
static var world_id: int = 1
## Ô xuất hiện sau khi đổi bản đồ (-1 = giữ vị trí trong scene)
static var pending_spawn: Vector2i = Vector2i(-1, -1)
static var _generic := false
static var _loaded_world := -1
static var _hf: PackedFloat32Array = PackedFloat32Array()   # độ cao (mét) mỗi đỉnh
static var _layer2: PackedByteArray = PackedByteArray()
static var _flags := 0
static var _water_speed := 0.05
static var _tile_imgs: Array = []
static var _tile_scale := PackedFloat32Array()
static var _grass_imgs: Array = []
static var _grass_h := PackedFloat32Array()
static var _light_tex: Texture2D = null
static var _heights: PackedByteArray = PackedByteArray()
static var _alpha: PackedByteArray = PackedByteArray()
static var _attrib: PackedByteArray = PackedByteArray()
static var _layer1: PackedByteArray = PackedByteArray()
static var _light_img: Image = null

var _terrain_shader: Shader = preload("res://src/shaders/mu_terrain.gdshader")
var _grass_shader: Shader = preload("res://src/shaders/mu_grass.gdshader")

static func map_path(n: int) -> String:
	return "res://assets/mu/maps/World%d/terrain.mumap" % n

static func has_map(n: int) -> bool:
	if n == 1:
		return true
	return FileAccess.file_exists(map_path(n))

static func is_generic() -> bool:
	ensure_loaded()
	return _generic

## Đổi bản đồ (dữ liệu tĩnh được nạp lại ở lần truy cập sau). Gọi trước khi reload scene.
static func change_world(n: int, spawn: Vector2i = Vector2i(-1, -1)) -> void:
	world_id = n
	pending_spawn = spawn
	_loaded_world = -1
	_hf = PackedFloat32Array()
	_heights = PackedByteArray()
	_alpha = PackedByteArray()
	_attrib = PackedByteArray()
	_layer1 = PackedByteArray()
	_layer2 = PackedByteArray()
	_light_img = null
	_light_tex = null
	_tile_imgs = []
	_grass_imgs = []
	var mm = load("res://src/mu/MuModel.gd")
	if mm:
		mm.reset_cache()

## Ánh sáng địa hình 256x256 (cho shader vật thể / nhân vật)
static func light_texture() -> Texture2D:
	ensure_loaded()
	if _light_tex == null and _light_img != null:
		_light_tex = ImageTexture.create_from_image(_light_img)
	return _light_tex

static func ensure_loaded() -> void:
	if _loaded_world == world_id and _hf.size() == TERRAIN_SIZE * TERRAIN_SIZE:
		return
	_loaded_world = world_id
	if world_id != 1 and FileAccess.file_exists(map_path(world_id)):
		_generic = true
		_load_mumap(map_path(world_id))
		return
	if world_id != 1:
		push_warning("[MuTerrain] Chưa có bản đồ World%d — dùng Lorencia. Chạy MU Tools > Chuyển bản đồ." % world_id)
		world_id = 1
		_loaded_world = 1
	_generic = false
	_load_lorencia()

static func _load_lorencia() -> void:
	var misc_tex: Texture2D = load(DIR + "terrain_misc.png")
	var layers_tex: Texture2D = load(DIR + "terrain_layers.png")
	var light_tex: Texture2D = load(DIR + "terrain_light.png")
	if misc_tex == null or layers_tex == null or light_tex == null:
		push_error("[MuTerrain] Thiếu dữ liệu địa hình trong " + DIR)
		return
	var misc: Image = misc_tex.get_image()
	if misc.is_compressed():
		misc.decompress()
	misc.convert(Image.FORMAT_RGB8)
	var layers: Image = layers_tex.get_image()
	if layers.is_compressed():
		layers.decompress()
	layers.convert(Image.FORMAT_RGB8)
	_light_img = light_tex.get_image()
	if _light_img.is_compressed():
		_light_img.decompress()
	_light_img.convert(Image.FORMAT_RGB8)
	_light_tex = light_tex

	var md := misc.get_data()
	var ld := layers.get_data()
	var n := TERRAIN_SIZE * TERRAIN_SIZE
	_heights.resize(n)
	_hf.resize(n)
	_alpha.resize(n)
	_attrib.resize(n)
	_layer1.resize(n)
	_layer2.resize(n)
	for i in n:
		_heights[i] = md[i * 3]
		_hf[i] = md[i * 3] * HEIGHT_SCALE
		_alpha[i] = md[i * 3 + 1]
		_attrib[i] = md[i * 3 + 2]
		_layer1[i] = ld[i * 3]
		_layer2[i] = ld[i * 3 + 1]

## Đọc terrain.mumap (tools/mu_maps.py)
static func _load_mumap(path: String) -> void:
	var data := FileAccess.get_file_as_bytes(path)
	var n := TERRAIN_SIZE * TERRAIN_SIZE
	if data.size() < 32 + n * 9:
		push_error("[MuTerrain] File hỏng: " + path)
		return
	var sp := StreamPeerBuffer.new()
	sp.data_array = data
	sp.seek(8)
	sp.get_u32()            # số world
	_flags = sp.get_u32()
	_water_speed = sp.get_float()
	sp.get_float()
	sp.get_float()
	sp.get_float()
	var p := sp.get_position()
	_hf = data.slice(p, p + n * 4).to_float32_array()
	for i in n:
		_hf[i] *= 0.01
	p += n * 4
	_layer1 = data.slice(p, p + n)
	p += n
	_layer2 = data.slice(p, p + n)
	p += n
	_alpha = data.slice(p, p + n)
	p += n
	_attrib.resize(n)
	for i in n:
		_attrib[i] = data[p + i * 2]
	p += n * 2
	var lum := data.slice(p, p + n)
	p += n
	sp.seek(p)
	var light := _read_image(sp)
	_light_img = Image.create(TERRAIN_SIZE, TERRAIN_SIZE, false, Image.FORMAT_RGB8)
	var src := PackedByteArray()
	if light:
		if light.get_width() != TERRAIN_SIZE or light.get_height() != TERRAIN_SIZE:
			light.resize(TERRAIN_SIZE, TERRAIN_SIZE, Image.INTERPOLATE_BILINEAR)
		light.convert(Image.FORMAT_RGB8)
		src = light.get_data()
	var out := PackedByteArray()
	out.resize(n * 3)
	for i in n:
		var l := lum[i] / 255.0
		for c in 3:
			var v := (src[i * 3 + c] if not src.is_empty() else 255) * l
			out[i * 3 + c] = clampi(int(v + 0.5), 0, 255)
	_light_img.set_data(TERRAIN_SIZE, TERRAIN_SIZE, false, Image.FORMAT_RGB8, out)
	_light_tex = null
	# texture tile (30) và cỏ (3)
	_tile_imgs = []
	_tile_scale = PackedFloat32Array()
	var cnt := sp.get_u32()
	for i in cnt:
		var img := _read_image(sp)
		_tile_scale.append(64.0 / img.get_width() if img else 0.25)
		_tile_imgs.append(img)
	_grass_imgs = []
	_grass_h = PackedFloat32Array()
	var gc := sp.get_u32()
	for i in gc:
		var img := _read_image(sp)
		_grass_h.append(img.get_height() * 2.0 / 100.0 if img else 0.0)
		_grass_imgs.append(img)
	# _heights (byte) chỉ dùng cho Lorencia; bản đồ khác dùng _hf
	_heights = PackedByteArray()
	_heights.resize(n)

static func _read_image(sp: StreamPeerBuffer) -> Image:
	var kind := sp.get_u8()
	var ln := sp.get_u32()
	if ln == 0:
		return null
	var res := sp.get_data(ln)
	if res[0] != OK:
		return null
	var buf: PackedByteArray = res[1]
	var img := Image.new()
	var err := img.load_jpg_from_buffer(buf) if kind == 1 else img.load_png_from_buffer(buf)
	if err != OK:
		return null
	return img

## Chiều cao địa hình (mét) tại toạ độ ô liên tục (x, y) của MU — nội suy song tuyến như RequestTerrainHeight
static func height_at(x: float, y: float) -> float:
	ensure_loaded()
	if _hf.is_empty():
		return 0.0
	x = clampf(x, 0.0, 254.999)
	y = clampf(y, 0.0, 254.999)
	var xi := int(x)
	var yi := int(y)
	var fx := x - xi
	var fy := y - yi
	var h00 := _hf[yi * TERRAIN_SIZE + xi]
	var h10 := _hf[yi * TERRAIN_SIZE + xi + 1]
	var h01 := _hf[(yi + 1) * TERRAIN_SIZE + xi]
	var h11 := _hf[(yi + 1) * TERRAIN_SIZE + xi + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fy)

static func attribute_at(x: int, y: int) -> int:
	ensure_loaded()
	if x < 0 or y < 0 or x >= TERRAIN_SIZE or y >= TERRAIN_SIZE or _attrib.is_empty():
		return 0
	return _attrib[y * TERRAIN_SIZE + x]

## TerrainMappingLayer1 tại ô (x, y) — HeroTile của MU
static func layer1_at(x: int, y: int) -> int:
	ensure_loaded()
	if x < 0 or y < 0 or x >= TERRAIN_SIZE or y >= TERRAIN_SIZE or _layer1.is_empty():
		return -1
	return _layer1[y * TERRAIN_SIZE + x]

static func is_water(x: int, y: int) -> bool:
	ensure_loaded()
	if x < 0 or y < 0 or x >= TERRAIN_SIZE or y >= TERRAIN_SIZE or _layer1.is_empty():
		return false
	return _layer1[y * TERRAIN_SIZE + x] == 5

static func _light_at(x: int, y: int) -> Color:
	return _light_img.get_pixel(clampi(x, 0, 255), clampi(y, 0, 255))

func _ready() -> void:
	ensure_loaded()
	if _hf.is_empty():
		return
	if _generic:
		_build_terrain_generic()
		if grass_enabled and (_flags & 2) != 0:
			_build_grass_generic()
		return
	_build_terrain()
	if grass_enabled:
		_build_grass()

func _build_terrain() -> void:
	var n := TERRAIN_SIZE
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	uvs.resize(n * n)
	cols.resize(n * n)
	for y in n:
		for x in n:
			var i := y * n + x
			verts[i] = Vector3(x, _heights[i] * HEIGHT_SCALE, -y)
			uvs[i] = Vector2(x, y)
			var c := _light_at(x, y)
			c.a = _alpha[i] / 255.0
			cols[i] = c
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for y in n - 1:
		for x in n - 1:
			var i0 := y * n + x
			var i1 := i0 + 1
			var i2 := i0 + n + 1
			var i3 := i0 + n
			# Tam giác giống RenderQuad3D: (0,1,2) (0,2,3)
			idx[k] = i0
			idx[k + 1] = i1
			idx[k + 2] = i2
			idx[k + 3] = i0
			idx[k + 4] = i2
			idx[k + 5] = i3
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader
	mat.set_shader_parameter("atlas", load(DIR + "terrain_atlas.png"))
	mat.set_shader_parameter("layers", load(DIR + "terrain_layers.png"))
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "LorenciaTerrainMesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_grass() -> void:
	var n := TERRAIN_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = _grass_shader
	mat.set_shader_parameter("grass_atlas", load(DIR + "grass_atlas.png"))

	# TerrainGrassTexture[y] = (rand % 4) / 4  — cố định seed để bản đồ luôn giống nhau
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var row_offset := PackedFloat32Array()
	row_offset.resize(n)
	for i in n:
		row_offset[i] = float(rng.randi() % 4) / 4.0

	var container := Node3D.new()
	container.name = "LorenciaGrass"
	add_child(container)
	var total := 0
	for cy in range(0, n - 1, GRASS_CHUNK):
		for cx in range(0, n - 1, GRASS_CHUNK):
			var verts := PackedVector3Array()
			var uvs := PackedVector2Array()
			var uv2s := PackedVector2Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			for y in range(cy, mini(cy + GRASS_CHUNK, n - 1)):
				for x in range(cx, mini(cx + GRASS_CHUNK, n - 1)):
					var i1 := y * n + x
					var i2 := i1 + 1
					var i3 := i1 + n + 1
					var i4 := i1 + n
					if _alpha[i1] > 0 or _alpha[i2] > 0 or _alpha[i3] > 0 or _alpha[i4] > 0:
						continue
					var layer := _layer1[i1]
					if layer > 2:
						continue
					if (_attrib[i1] & 0x08) != 0:
						continue
					var gh: float = GRASS_HEIGHT[layer]
					var v0: float = GRASS_V_OFFSET[layer] + 0.5 / 256.0
					var v1: float = GRASS_V_OFFSET[layer] + GRASS_V_SIZE[layer] - 0.5 / 256.0
					var su := x * 0.25 + row_offset[y]
					# VectorCopy(TerrainVertex[0], TerrainVertex[3]) của MU chép đỉnh 0 VÀO đỉnh 3:
					# tấm cỏ đứng ở cạnh y của ô, 2 đỉnh trên nâng Height và lệch x -50
					var h0 := _heights[i1] * HEIGHT_SCALE
					var h1 := _heights[i2] * HEIGHT_SCALE
					var base := verts.size()
					verts.append(Vector3(x - 0.5, h0 + gh, -y))
					verts.append(Vector3(x + 0.5, h1 + gh, -y))
					verts.append(Vector3(x + 1, h1, -y))
					verts.append(Vector3(x, h0, -y))
					uvs.append(Vector2(su, v0))
					uvs.append(Vector2(su + 0.25, v0))
					uvs.append(Vector2(su + 0.25, v1))
					uvs.append(Vector2(su, v1))
					uv2s.append(Vector2(x, 0))
					uv2s.append(Vector2(x + 1, 0))
					uv2s.append(Vector2(x + 1, 0))
					uv2s.append(Vector2(x, 0))
					var c1 := _light_at(x, y)
					c1.a = 1.0
					var c2 := _light_at(x + 1, y)
					c2.a = 1.0
					var c3 := _light_at(x + 1, y + 1)
					c3.a = 0.0
					var c4 := _light_at(x, y + 1)
					c4.a = 0.0
					cols.append(c1)
					cols.append(c2)
					cols.append(c3)
					cols.append(c4)
					idx.append(base)
					idx.append(base + 1)
					idx.append(base + 2)
					idx.append(base)
					idx.append(base + 2)
					idx.append(base + 3)
			if verts.is_empty():
				continue
			# đặt gốc ở giữa chunk để visibility range tính đúng khoảng cách
			var center := Vector3(cx + GRASS_CHUNK * 0.5, 0.0, -(cy + GRASS_CHUNK * 0.5))
			for vi in verts.size():
				verts[vi] = verts[vi] - center
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_TEX_UV2] = uv2s
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.name = "Grass_%d_%d" % [cx, cy]
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = grass_visibility_range
			mi.visibility_range_end_margin = 4.0
			mi.position = center
			container.add_child(mi)
			total += verts.size() / 4
	print("[MuTerrain] Cỏ địa hình: %d ô" % total)

# ======================================================================= bản đồ khác (terrain.mumap)
var _terrain_arr_shader: Shader = preload("res://src/shaders/mu_terrain_arr.gdshader")
var _grass_arr_shader: Shader = preload("res://src/shaders/mu_grass_arr.gdshader")

static func _make_array(imgs: Array, w: int, h: int) -> Texture2DArray:
	var list: Array[Image] = []
	for img in imgs:
		var im: Image
		if img == null:
			im = Image.create(w, h, false, Image.FORMAT_RGBA8)
			im.fill(Color(0, 0, 0, 0))
		else:
			im = (img as Image).duplicate()
			im.convert(Image.FORMAT_RGBA8)
			if im.get_width() != w or im.get_height() != h:
				im.resize(w, h, Image.INTERPOLATE_NEAREST)
		list.append(im)
	var arr := Texture2DArray.new()
	arr.create_from_images(list)
	return arr

func _build_terrain_generic() -> void:
	var n := TERRAIN_SIZE
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	uvs.resize(n * n)
	cols.resize(n * n)
	for y in n:
		for x in n:
			var i := y * n + x
			verts[i] = Vector3(x, _hf[i], -y)
			uvs[i] = Vector2(x, y)
			var c := _light_at(x, y)
			c.a = _alpha[i] / 255.0
			cols[i] = c
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for y in n - 1:
		for x in n - 1:
			var i0 := y * n + x
			if (_attrib[i0] & 0x08) != 0:
				continue   # TW_NOGROUND: RenderTerrainTile bỏ qua ô này
			idx[k] = i0
			idx[k + 1] = i0 + 1
			idx[k + 2] = i0 + n + 1
			idx[k + 3] = i0
			idx[k + 4] = i0 + n + 1
			idx[k + 5] = i0 + n
			k += 6
	idx.resize(k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# R = layer1, G = layer2, B = cờ 4 góc alpha >= 255
	var ld := PackedByteArray()
	ld.resize(n * n * 3)
	for y in n:
		for x in n:
			var i := y * n + x
			var x1 := mini(x + 1, n - 1)
			var y1 := mini(y + 1, n - 1)
			var full := _alpha[i] >= 255 and _alpha[y * n + x1] >= 255 and _alpha[y1 * n + x1] >= 255 and _alpha[y1 * n + x] >= 255
			ld[i * 3] = _layer1[i]
			ld[i * 3 + 1] = _layer2[i]
			ld[i * 3 + 2] = 255 if full else 0
	var layers_img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, ld)
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_arr_shader
	mat.set_shader_parameter("tiles", _make_array(_tile_imgs, 256, 256))
	mat.set_shader_parameter("layers", ImageTexture.create_from_image(layers_img))
	mat.set_shader_parameter("tile_scale", _tile_scale)
	mat.set_shader_parameter("tile_count", _tile_imgs.size())
	mat.set_shader_parameter("water_speed", _water_speed)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_grass_generic() -> void:
	var n := TERRAIN_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = _grass_arr_shader
	mat.set_shader_parameter("grass", _make_array(_grass_imgs, 256, 128))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var row_offset := PackedFloat32Array()
	row_offset.resize(n)
	for i in n:
		row_offset[i] = float(rng.randi() % 4) / 4.0
	var container := Node3D.new()
	container.name = "Grass"
	add_child(container)
	var total := 0
	for cy in range(0, n - 1, GRASS_CHUNK):
		for cx in range(0, n - 1, GRASS_CHUNK):
			var verts := PackedVector3Array()
			var uvs := PackedVector2Array()
			var uv2s := PackedVector2Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			for y in range(cy, mini(cy + GRASS_CHUNK, n - 1)):
				for x in range(cx, mini(cx + GRASS_CHUNK, n - 1)):
					var i1 := y * n + x
					var i2 := i1 + 1
					if _alpha[i1] > 0 or _alpha[i2] > 0 or _alpha[i1 + n + 1] > 0 or _alpha[i1 + n] > 0:
						continue
					var layer := _layer1[i1]
					if layer > 2 or layer >= _grass_imgs.size() or _grass_imgs[layer] == null:
						continue
					if (_attrib[i1] & 0x08) != 0:
						continue
					var gh: float = _grass_h[layer]
					var su := x * 0.25 + row_offset[y]
					var h0 := _hf[i1]
					var h1 := _hf[i2]
					var base := verts.size()
					verts.append(Vector3(x - 0.5, h0 + gh, -y))
					verts.append(Vector3(x + 0.5, h1 + gh, -y))
					verts.append(Vector3(x + 1, h1, -y))
					verts.append(Vector3(x, h0, -y))
					uvs.append(Vector2(su, 0.004))
					uvs.append(Vector2(su + 0.25, 0.004))
					uvs.append(Vector2(su + 0.25, 0.996))
					uvs.append(Vector2(su, 0.996))
					for xx in [x, x + 1, x + 1, x]:
						uv2s.append(Vector2(xx, layer))
					var c1 := _light_at(x, y)
					c1.a = 1.0
					var c2 := _light_at(x + 1, y)
					c2.a = 1.0
					var c3 := _light_at(x + 1, y + 1)
					c3.a = 0.0
					var c4 := _light_at(x, y + 1)
					c4.a = 0.0
					cols.append(c1)
					cols.append(c2)
					cols.append(c3)
					cols.append(c4)
					idx.append(base)
					idx.append(base + 1)
					idx.append(base + 2)
					idx.append(base)
					idx.append(base + 2)
					idx.append(base + 3)
			if verts.is_empty():
				continue
			var center := Vector3(cx + GRASS_CHUNK * 0.5, 0.0, -(cy + GRASS_CHUNK * 0.5))
			for vi in verts.size():
				verts[vi] = verts[vi] - center
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_TEX_UV2] = uv2s
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.name = "Grass_%d_%d" % [cx, cy]
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = grass_visibility_range
			mi.visibility_range_end_margin = 4.0
			mi.position = center
			container.add_child(mi)
			total += verts.size() / 4
	print("[MuTerrain] World%d: cỏ %d ô" % [world_id, total])
