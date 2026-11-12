extends Node

## Sinh quái theo vùng của server OpenMU (assets/mu/spawns.json "monsters": {id, x1, y1, x2, y2, count})
## như MonsterSpawnArea: mỗi vùng có `count` chỗ, mỗi chỗ một con; chết thì hồi sinh sau RespawnDelay
## (monster_stats.json). Chỉ dựng model cho chỗ gần người chơi (ACTIVE_RANGE ô), xa thì gỡ đi để nhẹ máy.

const MuMonsterScript = preload("res://src/entities/MuMonster.gd")
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

const ACTIVE_RANGE := 24     # ô: dựng quái trong tầm này quanh người chơi
const DESPAWN_RANGE := 32    # ô: gỡ quái (còn sống) ra xa hơn tầm này
const MAX_SPAWN_PER_TICK := 4
const TICK := 0.25

var _slots: Array = []   # {id, name, tile: Vector2i, node: MuMonster|null, respawn_at: float}
var _t := 0.0
var _tick := 0.0
var _world = null

## Đọc vùng quái của bản đồ; true nếu bản đồ có quái theo server
func setup(world, world_id: int) -> bool:
	_world = world
	var p := "res://assets/mu/spawns.json"
	if not FileAccess.file_exists(p):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary) or not d.has(str(world_id)):
		return false
	var areas = d[str(world_id)].get("monsters", [])
	if not (areas is Array) or areas.is_empty():
		return false
	for a in areas:
		var id := int(a.get("id", -1))
		var mon := MuCatalogRes.find_monster(id)
		if mon.is_empty():
			continue
		var nm = mon.get("name", {})
		var name_en: String = str(nm.get("en", "")) if nm is Dictionary else str(nm)
		for i in maxi(1, int(a.get("count", 1))):
			var tile := _pick_tile(int(a["x1"]), int(a["y1"]), int(a["x2"]), int(a["y2"]))
			if tile.x < 0:
				continue
			_slots.append({"id": id, "name": name_en, "tile": tile, "node": null, "respawn_at": 0.0})
	print("[MuMonsterSpawner] World%d: %d chỗ quái (%d vùng)" % [world_id, _slots.size(), areas.size()])
	return not _slots.is_empty()

## Ô ngẫu nhiên đi được, ngoài thành (nếu ở bản đồ thành), trong vùng
func _pick_tile(x1: int, y1: int, x2: int, y2: int) -> Vector2i:
	var min_x := mini(x1, x2)
	var max_x := maxi(x1, x2)
	var min_y := mini(y1, y2)
	var max_y := maxi(y1, y2)

	# Điểm đơn (single spot spawn)
	if min_x == max_x and min_y == max_y:
		if _world.is_walkable(min_x, min_y):
			return Vector2i(min_x, min_y)
		for r in range(1, 4):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var tx := min_x + dx
					var ty := min_y + dy
					if _world.is_walkable(tx, ty):
						return Vector2i(tx, ty)
		return Vector2i(min_x, min_y)

	# Vùng ngẫu nhiên
	var is_town: bool = (MuTerrain.world_id in [1, 3, 4, 52])
	for _i in 30:
		var t := Vector2i(randi_range(min_x, max_x), randi_range(min_y, max_y))
		if _world.is_walkable(t.x, t.y) and (not is_town or not MuWorld.is_safe_tile(t.x, t.y)):
			return t

	# Quét lưới tìm ô hợp lệ nếu random 30 lần chưa thấy
	var step_x := maxi(1, (max_x - min_x) / 10)
	var step_y := maxi(1, (max_y - min_y) / 10)
	for y in range(min_y, max_y + 1, step_y):
		for x in range(min_x, max_x + 1, step_x):
			if _world.is_walkable(x, y) and (not is_town or not MuWorld.is_safe_tile(x, y)):
				return Vector2i(x, y)

	return Vector2i(min_x, min_y)

func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick > 0.0 or _slots.is_empty():
		return
	_tick = TICK
	var tree := get_tree()
	if not tree:
		return
	var player = tree.get_first_node_in_group("Player")
	if player == null:
		return
	var pt := Vector2i(player.grid_x, player.grid_y)
	var spawned := 0
	for s in _slots:
		var node = s["node"]
		if node != null and not is_instance_valid(node):
			s["node"] = null
			node = null
		if node == null:
			if _t < float(s["respawn_at"]) or spawned >= MAX_SPAWN_PER_TICK:
				continue
			var tile: Vector2i = s["tile"]
			if maxi(absi(tile.x - pt.x), absi(tile.y - pt.y)) <= ACTIVE_RANGE:
				_spawn(s)
				spawned += 1
		elif not node.is_dead:
			var g := Vector2i(node.grid_x, node.grid_y)
			if maxi(absi(g.x - pt.x), absi(g.y - pt.y)) > DESPAWN_RANGE:
				node.queue_free()
				s["node"] = null

func _spawn(s: Dictionary) -> void:
	var m = MuMonsterScript.new()
	var tile: Vector2i = s["tile"]
	m.monster_id = int(s["id"])
	m.monster_name = str(s["name"])
	m.grid_x = tile.x
	m.grid_y = tile.y
	m.home = tile
	m.name = "Mon%d_%d_%d" % [int(s["id"]), tile.x, tile.y]
	m.died.connect(func(dead): _on_died(s, dead))
	if _world and _world.has_method("_on_monster_clicked"):
		m.monster_clicked.connect(_world._on_monster_clicked)
	s["node"] = m
	_world.get_parent().add_child(m)

func _on_died(s: Dictionary, dead) -> void:
	if s["node"] == dead:
		s["node"] = null
	s["respawn_at"] = _t + float(dead.respawn_delay) + 3.0   # + 3 giây xác nằm lại
