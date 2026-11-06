extends Area3D
class_name MuDropItem

## Vật phẩm rơi trên đất trong MU Online (Zen, Jewel of Bless, Soul, Chaos...)
## Hỗ trợ xoay lấp lánh và nhặt đồ (Auto-pickup khi lại gần hoặc Click)

signal item_picked_up(item: MuDropItem)

enum ItemCategory {
	ZEN,
	BLESS,
	SOUL,
	CHAOS,
	EQUIPMENT
}

@export var item_name: String = "Zen"
@export var category: ItemCategory = ItemCategory.ZEN
@export var amount: int = 500

var is_picked: bool = false
var _base_y: float = 0.2
var _time_offset: float = 0.0
var _item_mat: StandardMaterial3D = null

func _ready() -> void:
	_time_offset = randf_range(0.0, 10.0)
	_setup_visual()
	_setup_label()
	_setup_collision()
	
	# Phát âm thanh rơi vật phẩm của MU
	if MuAudioManager:
		if category in [ItemCategory.BLESS, ItemCategory.SOUL, ItemCategory.CHAOS]:
			MuAudioManager.play_jewel_drop(global_position)
		elif category == ItemCategory.ZEN:
			MuAudioManager.play_coin_drop(global_position)
		else:
			MuAudioManager.play_item_drop(global_position)

	# Xử lý khi người chơi bước vào vùng nhặt
	body_entered.connect(_on_body_entered)

func _setup_visual() -> void:
	var mesh_node = CSGBox3D.new()
	mesh_node.name = "ItemMesh"
	
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	
	match category:
		ItemCategory.ZEN:
			mesh_node.size = Vector3(0.35, 0.15, 0.25) # Thỏi vàng
			mat.albedo_color = Color(1.0, 0.85, 0.2)
			mat.emission = Color(0.9, 0.7, 0.1)
			mat.emission_energy_multiplier = 2.0
		ItemCategory.BLESS:
			mesh_node.size = Vector3(0.3, 0.45, 0.3) # Viên ngọc Ước Nguyện
			mat.albedo_color = Color(0.9, 0.2, 0.7) # Màu tím hồng Bless
			mat.emission = Color(0.8, 0.1, 0.6)
			mat.emission_energy_multiplier = 3.0
		ItemCategory.SOUL:
			mesh_node.size = Vector3(0.3, 0.45, 0.3)
			mat.albedo_color = Color(0.2, 0.5, 1.0) # Màu xanh lam Soul
			mat.emission = Color(0.1, 0.4, 0.9)
			mat.emission_energy_multiplier = 3.0
		ItemCategory.CHAOS:
			mesh_node.size = Vector3(0.35, 0.35, 0.35)
			mat.albedo_color = Color(0.3, 0.9, 0.4) # Màu xanh lục Chaos
			mat.emission = Color(0.2, 0.8, 0.3)
			mat.emission_energy_multiplier = 3.0

	_item_mat = mat
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node.material_override = mat
	mesh_node.position = Vector3(0, _base_y, 0)
	add_child(mesh_node)

func _exit_tree() -> void:
	if has_node("ItemMesh"):
		var mesh_node = get_node("ItemMesh") as GeometryInstance3D
		if mesh_node:
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_node.material_override = null

func _setup_label() -> void:
	var lbl = Label3D.new()
	lbl.name = "ItemLabel"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 22
	lbl.outline_size = 5
	lbl.outline_modulate = Color.BLACK
	lbl.position = Vector3(0, 0.6, 0)
	
	if category == ItemCategory.ZEN:
		lbl.text = "Zen (%d)" % amount
		lbl.modulate = Color(1.0, 0.9, 0.4)
	elif category == ItemCategory.BLESS:
		lbl.text = "Jewel of Bless"
		lbl.modulate = Color(1.0, 0.4, 0.9)
	elif category == ItemCategory.SOUL:
		lbl.text = "Jewel of Soul"
		lbl.modulate = Color(0.4, 0.8, 1.0)
	elif category == ItemCategory.CHAOS:
		lbl.text = "Jewel of Chaos"
		lbl.modulate = Color(0.4, 1.0, 0.5)

	add_child(lbl)

func _setup_collision() -> void:
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.2 # Bán kính tự động nhặt
	col.shape = sphere
	col.position = Vector3(0, 0.3, 0)
	add_child(col)

func _process(delta: float) -> void:
	if is_picked:
		return
	var t = Time.get_ticks_msec() * 0.001 + _time_offset
	var mesh = get_node_or_null("ItemMesh")
	if mesh:
		# 1. Chuyển động xoay tròn đều đặc trưng của MU Online
		mesh.rotate_y(3.2 * delta)
		# 2. Chuyển động nhấp nhô bay lơ lửng bồng bềnh
		mesh.position.y = _base_y + sin(t * 3.6) * 0.08
	
	# 3. Hào quang lấp lánh dao động theo nhịp thở
	if _item_mat:
		_item_mat.emission_energy_multiplier = 2.4 + sin(t * 4.5) * 1.0

func _on_body_entered(body: Node3D) -> void:
	if body is MuPlayer and not is_picked:
		pickup(body)

func pickup(player: MuPlayer) -> void:
	is_picked = true
	emit_signal("item_picked_up", self)
	
	var hud = get_tree().get_first_node_in_group("HUD")
	if not hud:
		var hud_node = get_parent().get_node_or_null("MuHud")
		if hud_node is MuHud:
			hud = hud_node

	if category == ItemCategory.ZEN:
		player.zen += amount
		if MuAudioManager:
			MuAudioManager.play_coin_pickup()
		print("[MuDropItem] Nhặt được %d Zen! Tổng Zen: %d" % [amount, player.zen])
		if hud:
			hud.show_pickup_notification("+%d Zen" % amount, Color(1.0, 0.9, 0.3))
	else:
		player.inventory_items.append(item_name)
		if MuAudioManager:
			MuAudioManager.play_item_pickup()
		print("[MuDropItem] Nhặt được %s!" % item_name)
		if hud:
			var note_color = Color(1.0, 0.4, 0.9) if category == ItemCategory.BLESS else Color(0.4, 0.8, 1.0)
			hud.show_pickup_notification("Nhặt được: " + item_name, note_color)
	
	# Hiệu ứng bay vào người chơi
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", global_position.y + 0.8, 0.2)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player = get_tree().get_first_node_in_group("Player")
		if player and not is_picked:
			pickup(player)
