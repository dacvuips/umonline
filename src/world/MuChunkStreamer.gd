extends Node3D

## Nạp / gỡ nội dung bản đồ theo vùng quanh người chơi.
## Bản đồ chia thành ô vùng (chunk) chunk_size x chunk_size ô MU. Mỗi chunk đăng ký một hàm dựng
## builder(root: Node3D). Chỉ khi người chơi tới gần (load_radius) chunk mới được dựng; đi xa hơn
## unload_radius thì gỡ hẳn (queue_free) -> không vẽ, không chạy animation / hạt / _process.
## Toạ độ: 1 ô MU = 1 mét; ô (x, y) -> Godot (x, h, -y).

## Kích thước một chunk (ô MU)
var chunk_size := 16
## Dựng chunk khi khoảng cách từ người chơi tới mép chunk <= load_radius (ô)
var load_radius := 48.0
## Gỡ chunk khi khoảng cách > unload_radius (ô) — lớn hơn load_radius để không nạp/gỡ liên tục ở ranh giới
var unload_radius := 60.0
## Giới hạn thời gian dựng mỗi lần kiểm tra (ms) để không giật khung hình
var build_budget_ms := 4.0
## Chu kỳ kiểm tra (giây)
var check_interval := 0.2
## Gọi khi chunk bị gỡ: on_unload(key: Vector2i, root: Node3D)
var on_unload: Callable = Callable()

var _builders: Dictionary = {}   # Vector2i -> Array[Callable]
var _built: Dictionary = {}      # Vector2i -> Node3D
var _timer := 0.0
var _primed := false

func register(chunk: Vector2i, builder: Callable) -> void:
	if not _builders.has(chunk):
		_builders[chunk] = []
	_builders[chunk].append(builder)

## Chunk chứa ô (x, y) của MU
func chunk_of_tile(x: float, y: float) -> Vector2i:
	return Vector2i(floori(x / chunk_size), floori(y / chunk_size))

## Chunk chứa điểm Godot (x, ?, z)
func chunk_of_pos(p: Vector3) -> Vector2i:
	return chunk_of_tile(p.x, -p.z)

func built_count() -> int:
	return _built.size()

func total_count() -> int:
	return _builders.size()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 and _primed:
		return
	_timer = check_interval
	var have := [false]
	var c := _focus_tile(have)
	if not have[0]:
		return
	_update(c, not _primed)
	_primed = true

## Vị trí người chơi theo ô MU (x, y); dự phòng: camera hiện tại
func _focus_tile(ok: Array) -> Vector2:
	var tree := get_tree()
	if tree == null:
		return Vector2.ZERO
	var p := tree.get_first_node_in_group("Player") as Node3D
	if p != null and p.is_inside_tree():
		ok[0] = true
		return Vector2(p.global_position.x, -p.global_position.z)
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam != null:
		ok[0] = true
		return Vector2(cam.global_position.x, -cam.global_position.z)
	return Vector2.ZERO

func _dist_to_chunk(t: Vector2, k: Vector2i) -> float:
	var x0 := float(k.x * chunk_size)
	var y0 := float(k.y * chunk_size)
	var dx := maxf(maxf(x0 - t.x, 0.0), t.x - (x0 + chunk_size))
	var dy := maxf(maxf(y0 - t.y, 0.0), t.y - (y0 + chunk_size))
	return sqrt(dx * dx + dy * dy)

func _update(t: Vector2, unlimited: bool) -> void:
	# 1. gỡ chunk ở xa
	for k in _built.keys():
		if _dist_to_chunk(t, k) > unload_radius:
			var root: Node3D = _built[k]
			_built.erase(k)
			if on_unload.is_valid():
				on_unload.call(k, root)
			if is_instance_valid(root):
				root.queue_free()
	# 2. dựng chunk ở gần, gần nhất trước
	var want: Array = []
	for k in _builders:
		if _built.has(k):
			continue
		var d := _dist_to_chunk(t, k)
		if d <= load_radius:
			want.append([d, k])
	if want.is_empty():
		return
	want.sort_custom(func(a, b): return a[0] < b[0])
	var start := Time.get_ticks_usec()
	for w in want:
		_build(w[1])
		if not unlimited and (Time.get_ticks_usec() - start) * 0.001 >= build_budget_ms:
			break

func _build(k: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [k.x, k.y]
	add_child(root)
	_built[k] = root
	for b: Callable in _builders[k]:
		if b.is_valid():
			b.call(root)
