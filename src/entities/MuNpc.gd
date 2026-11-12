extends CharacterBody3D
class_name MuNpc

# nạp trực tiếp (không phụ thuộc bộ nhớ đệm class_name của editor)
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const MuWorldRes = preload("res://src/world/MuWorld.gd")
const NpcDialogueWindowRes = preload("res://src/ui/NpcDialogueWindow.gd")
const ShopWindowRes = preload("res://src/ui/ShopWindow.gd")
const ChatBubbleRes = preload("res://src/ui/ChatBubble.gd")

## Đại diện cho NPC trong MU Online (Lumen the Barmaid, Potion Merchant, Vault Keeper...)
## Tương thích hệ toạ độ Grid 256x256, hỗ trợ click mở Cửa Sổ Hội Thoại & Chức năng

signal npc_interacted(npc: MuNpc)

@export var npc_name: String = "Lumen the Barmaid"
@export var npc_title: String = "Cô gái Quán Rượu Lorencia"
@export var grid_x: int = 126
@export var grid_y: int = 120
## Số hiệu NPC trong Monsters.json (255 Lumen, 251 Hanzo, 254 Pasi, 240 Safety Guardian ...). -1 = tìm theo tên
@export var npc_id: int = -1
## Hướng nhìn (độ, quanh trục đứng) — NPC MU đứng yên quay mặt cố định
@export var facing_deg: float = 0.0
@export var role: String = ""
var model = null

func _ready() -> void:
	if npc_id <= 0:
		var found_id = NpcDialogueWindow.find_npc_id_by_name(npc_name)
		if found_id > 0:
			npc_id = found_id

	# Tự động nạp thông tin chuẩn từ npc_data.json nếu có
	if npc_id > 0:
		var info = NpcDialogueWindow.get_npc_info(npc_id)
		if not info.is_empty():
			if info.has("name") and not str(info["name"]).is_empty():
				npc_name = str(info["name"])
			if info.has("title") and not str(info["title"]).is_empty():
				npc_title = str(info["title"])
			if info.has("role") and not str(info["role"]).is_empty() and role.is_empty():
				role = str(info["role"])

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
	if npc_title.is_empty():
		lbl.text = npc_name
	else:
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
	var tree := get_tree()
	if tree:
		var item_ui = tree.get_first_node_in_group("MuItemUi")
		if item_ui and not item_ui.held.is_empty():
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		interact()
	elif event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		interact()

var _pending_open := false

## MU: bấm NPC -> nhân vật đi tới cạnh NPC rồi mới mở cửa sổ (cửa hàng / hội thoại)
func interact() -> void:
	var tree := get_tree()
	var player = tree.get_first_node_in_group("Player") if tree else null
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

## Hiển thị bong bóng chat trên đầu NPC
func say_bubble(text: String, duration: float = 3.5) -> void:
	var bubble = ChatBubbleRes.new()
	add_child(bubble)
	bubble.show_chat(text, duration)

## Kiểm tra NPC có chức năng bán đồ / vật phẩm cho người chơi hay không
func is_shop_npc() -> bool:
	var check_id := npc_id
	if check_id <= 0:
		check_id = NpcDialogueWindowRes.find_npc_id_by_name(npc_name)
	if check_id > 0:
		if ShopWindowRes.has_shop(check_id):
			return true
		var info = NpcDialogueWindowRes.get_npc_info(check_id)
		if info.get("has_shop", false) == true:
			return true
		for opt in info.get("options", []):
			if opt is Dictionary and opt.get("action") == "shop":
				return true
	if role in ["shop", "blacksmith", "bar", "mage", "armorer", "potion"]:
		if check_id > 0:
			return ShopWindowRes.has_shop(check_id)
		return true
	return false

func _open() -> void:
	_pending_open = false
	print("[MuNpc] Người chơi đối thoại với: ", npc_name, " (ID: ", npc_id, ")")
	emit_signal("npc_interacted", self)

	# Lời chào trên đầu NPC tùy theo chức năng
	var greeting = "Xin chào chiến binh!"
	match role:
		"vault": greeting = "Hòm đồ an toàn tuyệt đối!"
		"blacksmith": greeting = "Chào bạn! Cần rèn vũ khí à?"
		"bar": greeting = "Uống một ly giải khát nhé!"
		"mage": greeting = "Ma thuật huyền bí ngự trị nơi đây!"
		"chaos_box": greeting = "Kekeke! Muốn ép đồ gì nào?"
		"buff": greeting = "Lời chúc phúc ở cùng bạn!"
		"devil_square": greeting = "Quảng Trường Quỷ vẫy gọi dũng sĩ!"
		"blood_castle": greeting = "Thiên Sứ đang chờ giải cứu!"
		"lahap": greeting = "Cần nén hay tách ngọc nào?"
		"quest": greeting = "Ta có nhiệm vụ quan trọng cho ngươi!"
		"guild": greeting = "Đoàn kết tạo nên sức mạnh!"
		"guard": greeting = "Hãy cẩn thận bên ngoài cổng thành!"
		"shop": greeting = "Chào mừng ghé thăm cửa hàng!"

	say_bubble(greeting, 3.5)

	var tree := get_tree()
	var hud = tree.get_first_node_in_group("HUD") if tree else null
	if not hud:
		return

	# Cập nhật: Tất cả NPC có tác dụng để người chơi mua đồ / mua vật phẩm
	# Khi click vào hiển thị luôn rương các vật phẩm của NPC và túi của mình,
	# không cần bật ra hội thoại xong cho người chơi chọn tiếp và rời khỏi.
	if is_shop_npc():
		if hud.has_method("open_npc_shop"):
			hud.open_npc_shop(self)
			return

	# Thủ Kho (Vault Keeper): bấm vào là mở thẳng rương, không qua hội thoại
	if role == "vault" and hud.has_method("open_vault"):
		hud.open_vault(self)
		return

	# Mở Cửa Sổ Đối Thoại NPC chuẩn MU Online cho các NPC nhiệm vụ / tính năng khác
	if hud.has_method("open_npc_dialogue"):
		hud.open_npc_dialogue(self)
	else:
		# Dự phòng nếu HUD chưa có dialogue window
		match role:
			"vault":
				if hud.has_method("open_vault"):
					hud.open_vault(self)
			"chaos_box":
				if hud.has_method("open_chaos_mix"):
					hud.open_chaos_mix(self)
			"devil_square":
				if hud.has_method("open_devil_square"):
					hud.open_devil_square(self)
			"lahap":
				if hud.has_method("open_jewel_bundle"):
					hud.open_jewel_bundle(self)
			_:
				if hud.has_method("open_npc_shop"):
					hud.open_npc_shop(self)

func _process(_d: float) -> void:
	if not _pending_open:
		return
	var tree := get_tree()
	var player = tree.get_first_node_in_group("Player") if tree else null
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
