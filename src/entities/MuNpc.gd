extends CharacterBody3D
class_name MuNpc

# nạp trực tiếp (không phụ thuộc bộ nhớ đệm class_name của editor)
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const MuWorldRes = preload("res://src/world/MuWorld.gd")

## Đại diện cho NPC trong MU Online (Lumen the Barmaid, Potion Merchant, Vault Keeper...)
## Tương thích hệ toạ độ Grid 256x256, hỗ trợ click mở Shop hoặc Đối thoại

signal npc_interacted(npc: MuNpc)

@export var npc_name: String = "Lumen the Barmaid"
@export var npc_title: String = "Cô gái Quán Rượu Lorencia"
@export var grid_x: int = 126
@export var grid_y: int = 120
## Số hiệu NPC trong Monsters.json (255 Lumen, 251 Hanzo, 254 Pasi, 240 Safety Guardian ...). -1 = tìm theo tên
@export var npc_id: int = -1
## Hướng nhìn (độ, quanh trục đứng) — NPC MU đứng yên quay mặt cố định
@export var facing_deg: float = 0.0
var model = null

func _ready() -> void:
	global_position = MuWorld.grid_to_world(grid_x, grid_y)
	_setup_visual()
	_setup_label()
	_setup_collision()

func _setup_visual() -> void:
	rotation.y = deg_to_rad(facing_deg)
	var m := MuCharModelRes.new()
	m.name = "MuModel"
	add_child(m)
	if m.build_monster(npc_id, npc_name):
		model = m
		model.play_idle()
		return
	m.queue_free()
	# Chưa có model -> hình tạm
	var root = Node3D.new()
	root.name = "NpcVisual"

	var body = CSGCylinder3D.new()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.radius = 0.35
	body.height = 1.7
	body.position = Vector3(0, 0.85, 0)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.3, 0.4) # Váy đỏ quán rượu
	body.material_override = mat
	root.add_child(body)

	var head = CSGSphere3D.new()
	head.radius = 0.25
	head.position = Vector3(0, 1.8, 0)
	root.add_child(head)

	add_child(root)

func _setup_label() -> void:
	var lbl = Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.text = "%s\n[%s]" % [npc_name, npc_title]
	lbl.font_size = 22
	lbl.outline_size = 6
	lbl.outline_modulate = Color.BLACK
	lbl.modulate = Color(1.0, 0.85, 0.3) # Vàng danh dự NPC
	lbl.position = Vector3(0, 2.4, 0)
	add_child(lbl)

func _setup_collision() -> void:
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 2.2
	col.shape = shape
	col.position = Vector3(0, 1.1, 0)
	add_child(col)

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		interact()
	elif event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		interact()

var _pending_open := false

## MU: bấm NPC -> nhân vật đi tới cạnh NPC rồi mới mở cửa sổ (cửa hàng / hội thoại)
func interact() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.global_position.distance_to(global_position) > 2.6:
		var world = player.get_parent().get_node_or_null("MuWorld")
		if world and world.has_method("find_path_grid"):
			var cur_tile: Vector2i = MuWorld.world_to_grid(player.global_position)
			var path: Array[Vector2i] = world.find_path_grid(cur_tile, Vector2i(grid_x, grid_y))
			if path.size() > 1:
				path.remove_at(path.size() - 1)   # dừng cạnh NPC, không đứng đè lên
				player.clear_target()
				player.move_to_path(path)
				_pending_open = true
				return
			elif path.size() == 1:
				player.clear_target()
				player.move_to_path(path)
				_pending_open = true
				return
	_open()

func _open() -> void:
	_pending_open = false
	print("[MuNpc] Người chơi đối thoại với: ", npc_name)
	emit_signal("npc_interacted", self)
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("open_npc_shop"):
		hud.open_npc_shop(self)

func _process(_d: float) -> void:
	if not _pending_open:
		return
	var player = get_tree().get_first_node_in_group("Player")
	if player == null:
		_pending_open = false
		return
	if player.global_position.distance_to(global_position) <= 2.6:
		_open()
	elif not player.is_moving and player.waypoints.is_empty():
		_pending_open = false


func _exit_tree() -> void:
	if model and model.has_method('cleanup_materials'):
		model.cleanup_materials()
	if has_node('NpcVisual'):
		for c in get_node('NpcVisual').get_children():
			if c is GeometryInstance3D:
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				c.material_override = null
