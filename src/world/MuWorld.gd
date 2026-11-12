extends Node3D
class_name MuWorld

## Quản lý thế giới, mặt đất (Terrain), Hệ thống Grid 256x256 và Tìm đường (Pathfinding)
## Tương thích 100% bản đồ Lorencia / Devias / Noria của MU Online

const MuDropItemRes = preload("res://src/entities/MuDropItem.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")

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
	MuAudioManager.set_world(MuTerrain.world_id)

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
	# Bloom riêng cho lớp cộng sáng của model (chrome / glow / Bright) như client gốc
	if get_node_or_null("MuModelBloom") == null:
		var mb: Node = load("res://src/world/MuModelBloom.gd").new()
		mb.name = "MuModelBloom"
		add_child(mb)

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
	var tree := get_tree()
	if not tree:
		return
	var item_ui = tree.get_first_node_in_group("MuItemUi")
	if item_ui and not item_ui.held.is_empty():
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var is_click = event.pressed
				var is_drag_release = (not event.pressed and Time.get_ticks_msec() - item_ui.held_time > 150)
				if is_click or is_drag_release:
					_handle_drop_item(event.position)
					get_viewport().set_input_as_handled()
					return
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				item_ui.cancel_held(player_node)
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventScreenTouch and event.pressed:
			_handle_drop_item(event.position)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_hold_move = true
			_hold_timer = 0.25
			_handle_ground_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Chuột phải: Thi triển Kỹ Năng Đang Chọn (Active Skill) chuẩn 100% MU Game Gốc!
			if player_node:
				player_node.cast_active_skill()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_ground_click(event.position)

func raycast_ground(screen_pos: Vector2) -> Dictionary:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return {"hit": false, "pos": Vector3.ZERO}

	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var normal: Vector3 = camera.project_ray_normal(screen_pos)

	var prev: Vector3 = from
	var t := 0.0
	while t < 120.0:
		t += 0.2
		var p: Vector3 = from + normal * t
		if p.y <= ground_height(p):
			var a: Vector3 = prev
			var b: Vector3 = p
			for _i in 8:
				var m: Vector3 = (a + b) * 0.5
				if m.y <= ground_height(m):
					b = m
				else:
					a = m
			return {"hit": true, "pos": b}
		prev = p
	return {"hit": false, "pos": Vector3.ZERO}

func _handle_ground_click(screen_pos: Vector2) -> void:
	if not player_node:
		return
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("cancel_follow"):
		hud.cancel_follow()

	var res := raycast_ground(screen_pos)
	if res.get("hit", false):
		var hit_pos: Vector3 = res.get("pos", Vector3.ZERO)
		var target_tile = world_to_grid(hit_pos)
		
		# Giới hạn trong kích thước bản đồ
		target_tile.x = clamp(target_tile.x, 0, grid_width - 1)
		target_tile.y = clamp(target_tile.y, 0, grid_height - 1)
		
		var current_tile = Vector2i(player_node.grid_x, player_node.grid_y)
		player_node.clear_target()
		var path = find_path_grid(current_tile, target_tile)
		if path.size() > 0:
			player_node.move_to_path(path)
			# Điểm đích như client gốc (MODEL_MOVE_TARGETPOSITION_EFFECT): vòng phép + sao 4 cánh + tia sáng
			MoveTargetFx.show_at(self, hit_pos)
			print("[MuWorld] Di chuyển tới: (%d, %d), tổng bước: %d" % [target_tile.x, target_tile.y, path.size()])

func _handle_drop_item(screen_pos: Vector2) -> void:
	var tree := get_tree()
	if not tree:
		return
	var item_ui = tree.get_first_node_in_group("MuItemUi")
	if item_ui == null or item_ui.held.is_empty() or player_node == null:
		return
	if item_ui.has_method("is_confirm_open") and item_ui.is_confirm_open():
		return
	# Đang giao dịch: không vứt đồ ra đất — trả đồ đang cầm về túi
	var trade = tree.get_first_node_in_group("MuTradeWindow")
	if trade and trade.is_trading():
		item_ui.cancel_held(player_node)
		return

	var it: Dictionary = item_ui.held
	# Rương / hộp / trái tim: vứt ra đất là MỞ, rớt đồ hoặc Zen ngẫu nhiên (OpenMU ItemBoxDroppedPlugIn)
	if MuBoxDrop.is_box(it):
		_open_box_on_ground(item_ui, it)
		return

	if MuItemsRes.is_valuable(it):
		# Client gốc (InventoryActionController::TryDropItem + IsHighValueItem): đồ ép cao / excellent / ancient
		# KHÔNG được vứt ra đất — báo lỗi hệ thống và trả đồ về túi, không có hộp xác nhận hay phím tắt bỏ qua.
		var chat = tree.get_first_node_in_group("ChatWindow")
		if chat and chat.has_method("add_system_message"):
			chat.add_system_message("Bạn không được phép vứt vật phẩm đắt giá này.")
		item_ui.cancel_held(player_node)
	else:
		var dropped_it: Dictionary = item_ui.drop_held()
		_do_drop_item(dropped_it, screen_pos)

## Mở hộp tại chỗ người chơi đứng: hộp biến mất, các món / Zen rơi ra xung quanh như vật phẩm rơi từ quái
func _open_box_on_ground(item_ui: Node, it: Dictionary) -> void:
	var tree := get_tree()
	var chat = tree.get_first_node_in_group("ChatWindow") if tree else null
	var lvl: int = int(player_node.level) if player_node else 1
	var res: Dictionary = MuBoxDrop.open(it, lvl)
	if not bool(res.get("ok", false)):
		if chat and chat.has_method("add_system_message") and str(res.get("message", "")) != "":
			chat.add_system_message(str(res["message"]))
		item_ui.cancel_held(player_node)
		return

	item_ui.drop_held()   # hộp bị tiêu hao
	var center: Vector3 = player_node.global_position
	var parent_node = get_parent()
	if parent_node == null:
		parent_node = self
	var drops: Array = res.get("drops", [])
	for i in drops.size():
		_spawn_box_loot(parent_node, drops[i] as Dictionary, center, i)
	_box_effect(parent_node, str(res.get("effect", "")), center)
	if player_node.model:
		player_node.model.play_skill(MuCharModelRes.P_SKILL_HAND1, 1.5)
		player_node._lock_action(0.35)
	if chat and chat.has_method("add_system_message"):
		chat.add_system_message("Bạn đã mở %s." % MuItemsRes.display_name(it))
	if player_node:
		player_node.inventory_changed.emit()

func _spawn_box_loot(parent_node: Node, loot: Dictionary, center: Vector3, index: int) -> void:
	var drop = MuDropItemRes.new()
	var ang := randf_range(0.0, TAU)
	var dist := randf_range(0.5, 1.2) if index > 0 or loot.get("type", "") == "item" else randf_range(0.4, 0.9)
	var target := center + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
	target.y = ground_height(target)
	var spawn := center + Vector3(0.0, 1.2, 0.0)
	drop.setup_drop(target, spawn)
	drop.pickup_delay = 1.5   # đồ rơi ngay dưới chân người chơi: chờ chạm đất rồi mới tự nhặt
	if str(loot.get("type", "")) == "zen":
		drop.category = MuDropItemRes.ItemCategory.ZEN
		drop.item_name = "Zen"
		drop.amount = int(loot.get("amount", 0))
	else:
		var d: Dictionary = loot.get("item_dict", {})
		drop.item_dict = d
		if MuItemsRes.is_jewel(d):
			drop.category = MuDropItemRes.ItemCategory.BLESS
		elif MuItemsRes.is_potion(d):
			drop.category = MuDropItemRes.ItemCategory.POTION
		else:
			drop.category = MuDropItemRes.ItemCategory.EQUIPMENT
		drop.amount = int(d.get("count", 1))
	drop.position = spawn
	parent_node.add_child(drop)

## DropEffect của hộp (Fireworks / FanfareSound / Swirl / ChristmasFireworks): chùm tia sáng vàng bắn lên từ người chơi
func _box_effect(parent_node: Node, effect: String, center: Vector3) -> void:
	if effect == "":
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 60 if effect != "Swirl" else 36
	p.lifetime = 1.1
	p.direction = Vector3.UP
	p.spread = 55.0 if effect != "Swirl" else 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.8, 0.3) if effect != "ChristmasFireworks" else Color(1.0, 0.4, 0.4)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = m
	p.mesh = q
	parent_node.add_child(p)
	p.global_position = center + Vector3(0, 0.6, 0)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func _do_drop_item(it: Dictionary, screen_pos: Vector2) -> void:
	if it.is_empty() or player_node == null:
		return
	
	var drop_pos := Vector3.ZERO
	var res := raycast_ground(screen_pos)
	var p_pos: Vector3 = player_node.global_position
	
	if res.get("hit", false):
		var hit_pos: Vector3 = res.get("pos", Vector3.ZERO)
		var diff := hit_pos - p_pos
		diff.y = 0.0
		# Nếu click quá xa (ngoài 2.5m), vứt về hướng đó cách người chơi 1.8m
		if diff.length() > 2.5:
			drop_pos = p_pos + diff.normalized() * 1.8
		else:
			drop_pos = hit_pos
	else:
		var fwd: Vector3 = -player_node.transform.basis.z.normalized()
		if fwd.is_zero_approx():
			fwd = Vector3(0, 0, 1)
		drop_pos = p_pos + fwd * 1.2
	
	drop_pos.y = ground_height(drop_pos)
	
	var drop = MuDropItemRes.new()
	drop.item_dict = it
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	if MuItemsRes.is_jewel(it):
		if g == 14 and n == 13:
			drop.category = MuDropItemRes.ItemCategory.BLESS
		elif g == 14 and n == 14:
			drop.category = MuDropItemRes.ItemCategory.SOUL
		elif g == 12 and n == 15:
			drop.category = MuDropItemRes.ItemCategory.CHAOS
		else:
			drop.category = MuDropItemRes.ItemCategory.BLESS
	elif MuItemsRes.is_potion(it):
		drop.category = MuDropItemRes.ItemCategory.POTION
	else:
		drop.category = MuDropItemRes.ItemCategory.EQUIPMENT
	drop.amount = int(it.get("count", 1))
	drop.pickup_delay = 2.0 # 2 giây tránh tự nhặt lại ngay lập tức
	
	# Động tác vứt tay của nhân vật & quay mặt về hướng ném
	var throw_dir := (drop_pos - p_pos)
	throw_dir.y = 0.0
	if not throw_dir.is_zero_approx():
		player_node.rotation.y = atan2(throw_dir.x, throw_dir.z)
	if player_node.model:
		player_node.model.play_skill(MuCharModelRes.P_SKILL_HAND1, 1.5)
		player_node._lock_action(0.35)
	
	# Vị trí xuất phát của vật phẩm: từ tay / ngực người chơi ném ra
	var start_pos: Vector3 = p_pos + Vector3(0.0, 1.1, 0.0)
	if not throw_dir.is_zero_approx():
		start_pos += throw_dir.normalized() * 0.4
	
	drop.setup_drop(drop_pos, start_pos)
	
	var parent_node = get_parent()
	if parent_node == null:
		parent_node = self
	
	drop.position = start_pos
	parent_node.add_child(drop)
	
	var disp_name := MuItemsRes.display_name(it)
	var tree := get_tree()
	var hud = tree.get_first_node_in_group("HUD") if tree else null
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Đã vứt: " + disp_name, Color(1.0, 0.8, 0.5))
	print("[MuWorld] Đã vứt %s ra đất tại %s" % [disp_name, str(drop_pos)])
	
	if player_node:
		player_node.inventory_changed.emit()
