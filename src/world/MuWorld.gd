extends Node3D
class_name MuWorld

## Quản lý thế giới, mặt đất (Terrain), Hệ thống Grid 256x256 và Tìm đường (Pathfinding)
## Tương thích 100% bản đồ Lorencia / Devias / Noria của MU Online

@export var map_collision_path: String = "res://assets/maps/lorencia_collision.json"
@export var player_node: MuPlayer

var astar: AStar2D = AStar2D.new()
var grid_width: int = 256
var grid_height: int = 256
var map_grid: Array = []

## ---- Hệ toạ độ chuẩn MU <-> Godot ----
## Ô (x, y) của MU nằm tại Godot (x + 0.5, chiều cao địa hình, -(y + 0.5)); 1 ô = 1 mét.
## (Phép đổi trục MU(x, y, z-lên) -> Godot(x, z, -y) là phép QUAY, không lật gương,
##  nên bản đồ hiển thị đúng chiều như client gốc.)
static func grid_to_world(gx: float, gy: float) -> Vector3:
	return Vector3(gx + 0.5, MuTerrain.height_at(gx + 0.5, gy + 0.5), -(gy + 0.5))

static func world_to_grid(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(-p.z))

static func ground_height(p: Vector3) -> float:
	return MuTerrain.height_at(p.x, -p.z)

## Bản đồ đang chạy (quái tìm đường / chọn ô sinh)
static var current: MuWorld = null

func _ready() -> void:
	current = self
	_setup_bloom()
	load_map_data()
	build_navigation_graph()
	_connect_monsters()
	_setup_monster_spawner()

## Quái theo vùng của server (spawns.json + monster_stats.json); bỏ quái đặt tay trong scene
func _setup_monster_spawner() -> void:
	var sp = load("res://src/world/MuMonsterSpawner.gd").new()
	sp.name = "MonsterSpawner"
	if not sp.setup(self, MuTerrain.world_id):
		sp.free()
		return
	for node in get_parent().get_children():
		if node is MuMonster:
			node.queue_free()
	add_child(sp)

func _exit_tree() -> void:
	if current == self:
		current = null

## Ô đi được (không tường / nước sâu)
func is_walkable(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return false
	return astar.has_point(_get_point_id(x, y))

## Alias hỗ trợ cả is_tile_walkable
func is_tile_walkable(x: int, y: int) -> bool:
	return is_walkable(x, y)

## Ô vùng an toàn (thành): quái không vào, không đánh người đứng trong đó
static func is_safe_tile(x: int, y: int) -> bool:
	return (MuTerrain.attribute_at(x, y) & 1) != 0

## Bloom của client gốc (Data/Render/Look.json: bloom.strength 1.0, hoà kiểu "screen" trong
## post_composite.frag.hlsl): chỉ phần rất sáng (lớp cộng sáng, hiệu ứng) mới loá ra xung quanh.
func _setup_bloom() -> void:
	var we := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we == null or we.environment == null:
		return
	var env := we.environment
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 1.0
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.85
	for i in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)

func _connect_monsters() -> void:
	# Tự động kết nối sự kiện click của quái vật với Player
	for node in get_parent().get_children():
		if node is MuMonster:
			node.monster_clicked.connect(_on_monster_clicked)

func _on_monster_clicked(monster: MuMonster) -> void:
	if player_node:
		print("[MuWorld] Người chơi chọn tấn công quái vật: ", monster.monster_name)
		player_node.set_attack_target(monster)

func load_map_data() -> void:
	# Bản đồ khác Lorencia: lấy thuộc tính ô trực tiếp từ terrain.mumap (EncTerrainN.att)
	if MuTerrain.world_id != 1:
		grid_width = 256
		grid_height = 256
		map_grid = []
		for y in 256:
			var row := []
			row.resize(256)
			for x in 256:
				row[x] = MuTerrain.attribute_at(x, y)
			map_grid.append(row)
		print("[MuWorld] World%d: đã tải thuộc tính ô" % MuTerrain.world_id)
		return
	if not FileAccess.file_exists(map_collision_path):
		print("[MuWorld] Không tìm thấy file thuộc tính map tại: ", map_collision_path)
		return

	var file = FileAccess.open(map_collision_path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result == OK:
		var data = json.get_data()
		grid_width = data.get("width", 256)
		grid_height = data.get("height", 256)
		map_grid = data.get("grid", [])
		print("[MuWorld] Đã tải dữ liệu bản đồ: %dx%d tiles thành công!" % [grid_width, grid_height])
	else:
		print("[MuWorld] Lỗi parse JSON map: ", json.get_error_message())

## Xây dựng đồ thị AStar từ ma trận ô lưới 256x256
func build_navigation_graph() -> void:
	astar.clear()
	astar.reserve_space(grid_width * grid_height)

	# 1. Thêm các điểm nút (Points)
	for y in range(grid_height):
		for x in range(grid_width):
			var idx = _get_point_id(x, y)
			var is_walkable = true
			if map_grid.size() > y and map_grid[y].size() > x:
				var attr = int(map_grid[y][x])
				# Thuộc tính bit: 0x08 (tường/blocked), 0x04 (nước/chướng ngại sâu)
				if (attr & 0x08) != 0 or (attr & 0x04) != 0:
					is_walkable = false

			if is_walkable:
				astar.add_point(idx, Vector2(x, y))

	# 2. Nối liên kết 8 hướng giữa các ô lân cận
	for y in range(grid_height):
		for x in range(grid_width):
			var curr_id = _get_point_id(x, y)
			if not astar.has_point(curr_id):
				continue

			# 8 hướng lân cận: ngang, dọc, chéo
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
						var neighbor_id = _get_point_id(nx, ny)
						if astar.has_point(neighbor_id):
							var weight = 1.0 if (dx == 0 or dy == 0) else 1.414 # Đường chéo
							astar.connect_points(curr_id, neighbor_id, true)

	print("[MuWorld] Xây dựng đồ thị tìm đường AStar hoàn tất! Tổng điểm đi lại được: ", astar.get_point_count())

func _get_point_id(x: int, y: int) -> int:
	return y * grid_width + x

## Tìm đường đi từ điểm A tới điểm B
func find_path_grid(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	var start_id = astar.get_closest_point(Vector2(from_pos.x, from_pos.y))
	var end_id = astar.get_closest_point(Vector2(to_pos.x, to_pos.y))
	
	var point_path = astar.get_point_path(start_id, end_id)
	var result: Array[Vector2i] = []
	for p in point_path:
		result.append(Vector2i(int(p.x), int(p.y)))
	return result

## Bắt sự kiện Tap-to-move (Mobile) hoặc Click-to-move (Web/Desktop)
## Giữ chuột trái: nhân vật đi theo con trỏ liên tục như MU (MouseLButtonPush)
var _hold_move := false
var _hold_timer := 0.0

func _process(delta: float) -> void:
	if not _hold_move:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hold_move = false
		return
	_hold_timer -= delta
	if _hold_timer <= 0.0:
		_hold_timer = 0.2
		if player_node and is_instance_valid(player_node.target_monster):
			return
		_handle_ground_click(get_viewport().get_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hold_move = true
		_hold_timer = 0.25
		_handle_ground_click(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_ground_click(event.position)

func _handle_ground_click(screen_pos: Vector2) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera or not player_node:
		return

	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var normal: Vector3 = camera.project_ray_normal(screen_pos)

	# Dò tia theo địa hình có độ cao (giống CollisionDetectLineToFace của MU)
	var hit_found := false
	var hit_pos := Vector3.ZERO
	var prev: Vector3 = from
	var t := 0.0
	while t < 120.0:
		t += 0.2
		var p: Vector3 = from + normal * t
		if p.y <= ground_height(p):
			# tinh chỉnh bằng chia đôi
			var a: Vector3 = prev
			var b: Vector3 = p
			for _i in 8:
				var m: Vector3 = (a + b) * 0.5
				if m.y <= ground_height(m):
					b = m
				else:
					a = m
			hit_pos = b
			hit_found = true
			break
		prev = p
	if hit_found:
		var target_tile = world_to_grid(hit_pos)
		
		# Giới hạn trong kích thước bản đồ
		target_tile.x = clamp(target_tile.x, 0, grid_width - 1)
		target_tile.y = clamp(target_tile.y, 0, grid_height - 1)
		
		var current_tile = Vector2i(player_node.grid_x, player_node.grid_y)
		player_node.clear_target()
		var path = find_path_grid(current_tile, target_tile)
		if path.size() > 0:
			player_node.move_to_path(path)
			print("[MuWorld] Di chuyển tới: (%d, %d), tổng bước: %d" % [target_tile.x, target_tile.y, path.size()])
