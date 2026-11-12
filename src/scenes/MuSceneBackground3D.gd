extends SubViewportContainer
class_name MuSceneBackground3D

## Nền 3D động cho màn Đăng nhập / Chọn máy chủ / Chọn & Tạo nhân vật,
## dựng lại đúng như client gốc từ dữ liệu Data/WorldN (assets/mu/maps/WorldN):
##   - World95 (IGCN Season 9 "Battle Core"): biển, đoàn chiến thuyền — màn đăng nhập
##   - World94 (IGCN Season 9): vách núi, bầu trời sao — màn chọn / tạo nhân vật
##     Camera tĩnh lấy từ Data/World9x/Camera_Angle_Position.bmd (văn bản mã hoá như BMD v14)
##   - World74 / World75 (Season 6): login bay theo CWScript74.cws / sân thờ chọn nhân vật
## Địa hình + vật thể (tàu bập bềnh, nước, mây...) dựng bằng MuTerrain / MuMapObjects.
## Camera tái hiện CCameraMove::UpdateTourWayPoint + DefaultCamera (Source/src/source/Camera).

const LOGIN_WORLD := 95
const CHARACTER_WORLD := 94
const S6_LOGIN_WORLD := 74
const S6_CHARACTER_WORLD := 75
const MapObjectsScript = preload("res://src/world/MuMapObjects.gd")

@export var world: int = LOGIN_WORLD

## Camera_Angle_Position.bmd: [CAMERA POSITION] (đơn vị MU), [CAMERA ANGLE], [CAMERA FOV] (FOV dọc)
const STATIC_CAMERAS := {
	95: {"pos": Vector3(24475.796875, 7581.581055, 1834.539917), "angle": Vector3(-84.5, 0.0, -45.0), "fov": 35.0},
	94: {"pos": Vector3(15215.088867, 12186.536133, 495.500061), "angle": Vector3(-84.5, 0.0, -80.0), "fov": 35.0},
}

## Ánh sáng cảnh Season 9 (đo so với ảnh chụp client IGCN): client không dùng bóng bake trong TerrainLight
## (ở World95 nó có vệt bóng quanh tàu bên phải mà ảnh gốc không có) -> ánh sáng phẳng.
## Vật thể: 0.82 * 0.8 + 0.35 = 1.0 (mu_object) ; mặt đất / mặt biển: texture * 0.82 * 0.4 = 0.33.
const FLAT_LIGHT := Color(0.82, 0.82, 0.82)
const FLAT_TERRAIN_SCALE := 0.4

## Waypoint của Data/World74/CWScript74.cws (x, y, z, delay, accel, distance_level) — đơn vị MU
const LOGIN_WAYPOINTS := [
	[24200.0, 2500.0, 169.5, 0, 18.0, 8.0],
	[21000.0, 2500.0, 169.5, 0, 17.0, 8.0],
	[18400.0, 2500.0, 169.5, 0, 15.0, 8.0],
	[18700.0, 3100.0, 169.5, 0, 20.0, 8.0],
	[18600.0, 5200.0, 169.5, 0, 17.0, 8.0],
	[19400.0, 5200.0, 169.5, 0, 17.0, 7.0],
	[20300.0, 5200.0, 169.5, 0, 25.0, 7.0],
	[24300.0, 5200.0, 169.5, 0, 25.0, 8.0],
	[24600.0, 4400.0, 169.5, 0, 18.0, 8.0],
	[24500.0, 2900.0, 169.5, 0, 18.0, 8.0],
]

# CameraMove.cpp / DefaultCamera.cpp / CameraConfig.h
const TOUR_BLEND_DISTANCE := 300.0
const TOUR_MAX_ROTATE := 1.0
const TOUR_CAMERA_Z := -300.0
const TOUR_BASE_DISTANCE := 1100.0
const TOUR_ANGLE_FRUSTUM := -112.5
const LOGIN_OFFSET := Vector3(-300.0, 650.0, 950.0)   # LoginSceneCameraDefaults
const LOGIN_PITCH := 40.0
const LOGIN_YAW := -5.0
const LOGIN_HFOV := 90.0
## Camera gốc: pos (9758.93, 18913.11, 645.5), angle (-81.5, 0, -75). Giờ nâng lên một chút (nhìn xuống ~24° thay vì ~17°),
## xoay quanh điểm chân nhân vật (9081, 19095, 426), cùng khoảng cách, nên các bục vẫn đúng chỗ nhân vật 3D đứng.
## Camera nhân vật trong CharacterSelectScene.tscn (Camera3D) được xoay cùng một góc — chỉnh thì chỉnh cả hai.
const CHAR_POS := Vector3(9788.2, 18905.2, 848.2)   # CharacterSceneCamera (nhìn xuống ~30°, xa hơn gốc 15%)
const CHAR_ANGLE := Vector3(-68.9, 0.0, -75.0)
const CHAR_HFOV := 40.0

var viewport: SubViewport
var camera: Camera3D
var _prev_world := 1
var _prev_spawn := Vector2i(-1, -1)

# Trạng thái tour (m_CurrentCameraPos, m_vTourCameraPos, ...)
var _target := 0
var _cur := Vector2.ZERO
var _tour := Vector3.ZERO
var _angle := 0.0
var _target_angle := 0.0
var _dist_level := 8.0
var _wp: Array = []


## Gắn nền 3D vào màn hình UI, ngay trên các node ảnh nền tĩnh (giữ làm dự phòng khi thiếu dữ liệu bản đồ).
static func attach(screen: Control, map_world: int, above: Array = ["Background", "BackgroundFallback", "VideoBackground"]) -> MuSceneBackground3D:
	var bg := MuSceneBackground3D.new()
	bg.name = "SceneBackground3D"
	bg.world = map_world
	var idx := 0
	for n in above:
		var node := screen.get_node_or_null(NodePath(n))
		if node:
			idx = maxi(idx, node.get_index() + 1)
	screen.add_child(bg)
	screen.move_child(bg, idx)
	return bg


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	_build_world()


func _exit_tree() -> void:
	# Trả lại bản đồ đang chọn cho game chính (MuTerrain dùng dữ liệu tĩnh)
	if MuTerrain.world_id == world:
		MuTerrain.change_world(_prev_world, _prev_spawn)


func _build_world() -> void:
	_prev_world = MuTerrain.world_id
	_prev_spawn = MuTerrain.pending_spawn
	if not MuTerrain.has_map(world):
		push_warning("[MuSceneBackground3D] Thiếu assets/mu/maps/World%d — chạy MU Tools > Chuyển bản đồ" % world)
		queue_free()   # để lộ ảnh nền tĩnh bên dưới
		return
	MuTerrain.change_world(world)
	MuTerrain.ensure_loaded()
	if STATIC_CAMERAS.has(world):
		MuTerrain.override_light(FLAT_LIGHT)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.73, 0.7)
	env.ambient_light_energy = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.6
	sun.shadow_enabled = false
	viewport.add_child(sun)

	var terrain := MuTerrain.new()
	terrain.name = "Terrain_World%d" % world
	terrain.grass_enabled = world != S6_LOGIN_WORLD
	viewport.add_child(terrain)
	if STATIC_CAMERAS.has(world):
		var tm := terrain.get_node_or_null("TerrainMesh") as MeshInstance3D
		if tm and tm.mesh and tm.mesh.surface_get_material(0) is ShaderMaterial:
			(tm.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("light_scale", FLAT_TERRAIN_SCALE)

	var objs = MapObjectsScript.new()
	objs.name = "MapObjects"
	viewport.add_child(objs)
	objs.build(world)
	# Camera cảnh tĩnh nhìn ra xa: nạp toàn bộ vật thể (tàu xa, nền) thay vì chỉ vùng 48 ô quanh camera
	var streamer := objs.get_node_or_null("Streamed")
	if streamer:
		streamer.load_radius = 100000.0
		streamer.unload_radius = 200000.0
		streamer.build_budget_ms = 1000.0

	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 400.0
	viewport.add_child(camera)
	camera.make_current()

	if STATIC_CAMERAS.has(world):
		var c: Dictionary = STATIC_CAMERAS[world]
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = c["fov"]
		_apply_mu_camera(c["pos"], c["angle"])
	elif world == S6_LOGIN_WORLD:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = LOGIN_HFOV
		_start_tour()
		_update_tour(0.0)
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = CHAR_HFOV
		_apply_mu_camera(CHAR_POS, CHAR_ANGLE)


func _process(delta: float) -> void:
	if world == S6_LOGIN_WORLD and not _wp.is_empty():
		_update_tour(delta)


# ------------------------------------------------------------------ Tour (CCameraMove)
func _start_tour() -> void:
	_wp = LOGIN_WAYPOINTS
	_target = 0
	var start: Array = _wp[_wp.size() - 1]
	var tgt: Array = _wp[0]
	# SetTourMode(TRUE, FALSE, 0): bắt đầu ở waypoint cuối, hướng về waypoint 0; offset login áp dụng lúc khởi tạo
	_cur = Vector2(start[0], start[1]) + Vector2(LOGIN_OFFSET.x, LOGIN_OFFSET.y)
	_tour = Vector3(start[0], start[1], start[2]) + LOGIN_OFFSET
	var dir := Vector2(tgt[0] - start[0], tgt[1] - start[1]).normalized()
	_angle = _create_angle(dir)
	_target_angle = _angle
	_dist_level = start[5]


static func _create_angle(d: Vector2) -> float:
	# CreateAngle(0, 0, d.x, -d.y) = atan2(dx, dy) độ, chuẩn hoá [0, 360)
	return fposmod(rad_to_deg(atan2(d.x, d.y)), 360.0)


static func _signed_delta(from: float, to: float) -> float:
	var d := fposmod(to, 360.0) - fposmod(from, 360.0)
	if d > 180.0:
		d -= 360.0
	elif d < -180.0:
		d += 360.0
	return d


func _update_tour(delta: float) -> void:
	var factor := delta * 25.0   # FPS_ANIMATION_FACTOR (client gốc chạy 25 khung/giây)
	var n := _wp.size()
	for _guard in n + 1:
		var tgt: Array = _wp[_target]
		var origin_i := _target - 1 if _target > 0 else n - 1
		var org: Array = _wp[origin_i]
		var acc := clampf(float(tgt[4]) * factor, 0.0, 100.0)
		var tp := Vector2(tgt[0], tgt[1])
		var op := Vector2(org[0], org[1])
		var to_t := tp - _cur
		var to_o := op - _cur
		var dt := to_t.length()
		var do_ := to_o.length()
		var fwd := to_t.normalized()
		var tour_dir := fwd
		if dt <= TOUR_BLEND_DISTANCE:
			var nx: Array = _wp[(_target + 1) % n]
			var seg := Vector2(nx[0], nx[1]) - tp
			if seg.length() > 0.0001:
				var r := dt / TOUR_BLEND_DISTANCE * 0.5 + 0.5
				tour_dir = (seg.normalized() * (1.0 - r) + fwd * r).normalized()
		elif do_ <= TOUR_BLEND_DISTANCE:
			var pv: Array = _wp[origin_i - 1 if origin_i > 0 else n - 1]
			var seg2 := op - Vector2(pv[0], pv[1])
			if seg2.length() > 0.0001:
				var r2 := do_ / TOUR_BLEND_DISTANCE * 0.5 + 0.5
				tour_dir = (seg2.normalized() * (1.0 - r2) + fwd * r2).normalized()
		if factor > 0.0 and dt <= acc:
			_target = (_target + 1) % n
			continue
		if dt > 5.0 and do_ > 5.0:
			_target_angle = _create_angle(tour_dir)
		var ad := _signed_delta(_angle, _target_angle)
		var step := clampf(absf(ad) / 30.0, 0.0, TOUR_MAX_ROTATE) * factor
		if absf(ad) <= step:
			_angle = fposmod(_target_angle, 360.0)
		else:
			_angle = fposmod(_angle + step * signf(ad), 360.0)
		_cur += fwd * acc
		_tour.x += tour_dir.x * acc
		_tour.y += tour_dir.y * acc
		_tour.z = TOUR_CAMERA_Z
		var tot := dt + do_
		_dist_level = (float(org[5]) * dt + float(tgt[5]) * do_) / tot if tot > 0.0001 else float(tgt[5])
		break

	var pivot := _tour + LOGIN_OFFSET   # GetCurrentCameraPos + ApplyLoginSceneOffset
	var ang := Vector3(TOUR_ANGLE_FRUSTUM + LOGIN_PITCH, 0.0, _angle + LOGIN_YAW)
	var dist := TOUR_BASE_DISTANCE * _dist_level * 0.1
	_apply_mu_camera(pivot + _irotate(Vector3(0, -dist, 0), ang), ang)


# ------------------------------------------------------------------ Toán camera MU -> Godot
## VectorIRotate(v, AngleMatrix(angle)) — ma trận Quake (Rz * Ry * Rx), nhân chuyển vị
static func _irotate(v: Vector3, a: Vector3) -> Vector3:
	var y := deg_to_rad(a.z)
	var p := deg_to_rad(a.y)
	var r := deg_to_rad(a.x)
	var sy := sin(y); var cy := cos(y)
	var sp := sin(p); var cp := cos(p)
	var sr := sin(r); var cr := cos(r)
	var m0 := Vector3(cp * cy, sr * sp * cy - cr * sy, cr * sp * cy + sr * sy)
	var m1 := Vector3(cp * sy, sr * sp * sy + cr * cy, cr * sp * sy - sr * cy)
	var m2 := Vector3(-sp, sr * cp, cr * cp)
	return m0 * v.x + m1 * v.y + m2 * v.z


## MU (x, y, z-lên, đơn vị cm) -> Godot (x, z, -y) mét
static func _to_godot(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, -p.y) * 0.01


static func _dir_to_godot(d: Vector3) -> Vector3:
	return Vector3(d.x, d.z, -d.y)


## Camera MU: glRotatef(a0, X) ; glRotatef(a2, Z) ; glTranslatef(-pos)
func _apply_mu_camera(pos: Vector3, a: Vector3) -> void:
	var rot := Basis(Vector3(0, 0, 1), deg_to_rad(-a.z)) * Basis(Vector3(1, 0, 0), deg_to_rad(-a.x))
	var b := Basis(_dir_to_godot(rot.x), _dir_to_godot(rot.y), _dir_to_godot(rot.z))
	camera.global_transform = Transform3D(b.orthonormalized(), _to_godot(pos))
