extends CanvasLayer
class_name MuHud

## Giao diện người dùng (HUD) cho MU Online Godot Client
## Tự động co giãn (Responsive) trên Web, Mobile (điện thoại/tablet) và PC

@export var player_node: MuPlayer

@onready var joystick_container: Control = $MobileControls/VirtualJoystick if has_node("MobileControls/VirtualJoystick") else null
@onready var mobile_skill_panel: Control = $MobileControls/MobileSkillPanel if has_node("MobileControls/MobileSkillPanel") else null
@onready var notification_label: Label = null

@onready var inventory_window: InventoryWindow = $InventoryWindow if has_node("InventoryWindow") else null
@onready var shop_window: ShopWindow = $ShopWindow if has_node("ShopWindow") else null
@onready var chat_window: ChatWindow = $ChatWindow if has_node("ChatWindow") else null
@onready var stats_window: CharacterStatsWindow = $CharacterStatsWindow if has_node("CharacterStatsWindow") else null
@onready var classic_hud_bar: MuClassicHudBar = $MuClassicHudBar if has_node("MuClassicHudBar") else null

const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const MuMoveWindowRes = preload("res://src/ui/MuMoveWindow.gd")
const MuSkillWindowRes = preload("res://src/ui/MuSkillWindow.gd")
var move_window = null
var item_picker_window = null
var skill_window = null

func _ready() -> void:
	add_to_group("HUD")
	# lớp đồ đang cầm + mô tả đồ (trên cùng), bảng dịch chuyển (M), bảng lấy đồ (B)
	var item_ui := MuItemUiRes.new()
	item_ui.name = "MuItemUi"
	item_ui.z_index = 100
	add_child(item_ui)
	move_window = MuMoveWindowRes.new()
	move_window.name = "MoveWindow"
	move_window.z_index = 10
	add_child(move_window)
	if player_node:
		move_window.setup(player_node)

	var item_picker_script = load("res://src/ui/MuItemPickerWindow.gd")
	if item_picker_script:
		item_picker_window = item_picker_script.new()
		item_picker_window.name = "ItemPickerWindow"
		item_picker_window.z_index = 10
		add_child(item_picker_window)
		if player_node:
			item_picker_window.setup(player_node)

	var skill_script = load("res://src/ui/MuSkillWindow.gd")
	if skill_script:
		skill_window = skill_script.new()
		skill_window.name = "SkillWindow"
		skill_window.z_index = 10
		add_child(skill_window)
		if player_node:
			skill_window.setup(player_node)

	# Nút mở Kho Đồ GM trên màn hình
	var btn_gm := Button.new()
	btn_gm.text = "🎁 Kho Đồ GM (B)"
	btn_gm.position = Vector2(220, 10)
	btn_gm.size = Vector2(130, 26)
	btn_gm.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	btn_gm.pressed.connect(toggle_item_picker)
	add_child(btn_gm)

	# Nút bật / tắt Cần điều khiển ảo (Joystick)
	var btn_joy := Button.new()
	btn_joy.text = "🕹️ Cần điều khiển"
	btn_joy.position = Vector2(360, 10)
	btn_joy.size = Vector2(135, 26)
	btn_joy.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	btn_joy.pressed.connect(toggle_joystick)
	add_child(btn_joy)

	# Nút bật / tắt Phím Kỹ Năng Mobile bên phải
	var btn_skill_ctrl := Button.new()
	btn_skill_ctrl.text = "⚔️ Phím Kỹ Năng"
	btn_skill_ctrl.position = Vector2(505, 10)
	btn_skill_ctrl.size = Vector2(140, 26)
	btn_skill_ctrl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	btn_skill_ctrl.pressed.connect(toggle_mobile_skills)
	add_child(btn_skill_ctrl)

	# Nút mở Bảng Kỹ Năng (Modal)
	var btn_skill_list := Button.new()
	btn_skill_list.text = "⚡ Kỹ Năng (K)"
	btn_skill_list.position = Vector2(655, 10)
	btn_skill_list.size = Vector2(120, 26)
	btn_skill_list.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	btn_skill_list.pressed.connect(toggle_skill_window)
	add_child(btn_skill_list)

	move_child(item_ui, get_child_count() - 1)

	if classic_hud_bar and player_node:
		classic_hud_bar.setup(player_node)

	if inventory_window and player_node:
		inventory_window.setup(player_node)
	if chat_window and player_node:
		chat_window.setup(player_node)
	if stats_window and player_node:
		stats_window.setup(player_node)

	if joystick_container:
		# Hiển thị mặc định để người chơi dùng chuột / cảm ứng trên cả PC và Mobile
		joystick_container.visible = true
		if player_node:
			player_node.virtual_joystick = joystick_container

	if mobile_skill_panel and player_node:
		mobile_skill_panel.setup(player_node)
		mobile_skill_panel.visible = true

	if player_node:
		player_node.monster_defeated.connect(_on_monster_defeated)

func _bring_modal_to_front(win: Control) -> void:
	if win and is_instance_valid(win):
		win.move_to_front()
		# Luôn giữ MuItemUi (lớp giữ món đồ bốc kéo-thả) ở trên cùng
		var item_ui = get_node_or_null("MuItemUi")
		if item_ui:
			move_child(item_ui, get_child_count() - 1)

func toggle_character_stats() -> void:
	if stats_window:
		stats_window.visible = not stats_window.visible
		if stats_window.visible:
			_bring_modal_to_front(stats_window)
			stats_window.update_stats()
			if MuAudioManager:
				MuAudioManager.play_ui_window()

func toggle_inventory() -> void:
	if inventory_window:
		inventory_window.visible = not inventory_window.visible
		if inventory_window.visible:
			_bring_modal_to_front(inventory_window)
			inventory_window.update_display()
			if MuAudioManager:
				MuAudioManager.play_ui_window()

func toggle_item_picker() -> void:
	if item_picker_window:
		item_picker_window.toggle()
		if item_picker_window.visible:
			_bring_modal_to_front(item_picker_window)
		if MuAudioManager:
			MuAudioManager.play_ui_window()

func toggle_joystick() -> void:
	if joystick_container:
		joystick_container.visible = not joystick_container.visible

func toggle_mobile_skills() -> void:
	if mobile_skill_panel:
		mobile_skill_panel.visible = not mobile_skill_panel.visible

func open_npc_shop(npc: MuNpc) -> void:
	if not (shop_window and player_node):
		return
	if not ShopWindow.has_shop(npc.npc_id):
		show_pickup_notification("%s: \"Xin chào, %s!\"" % [npc.npc_name, player_node.character_name], Color(1, 0.9, 0.6))
		return
	_bring_modal_to_front(shop_window)
	if inventory_window:
		_bring_modal_to_front(inventory_window)
	shop_window.open_shop(player_node, npc.npc_name, npc.npc_id, npc)
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func toggle_move_window() -> void:
	if move_window:
		move_window.toggle()
		if move_window.visible:
			_bring_modal_to_front(move_window)
		if MuAudioManager:
			MuAudioManager.play_ui_window()

func toggle_skill_window() -> void:
	if skill_window:
		skill_window.toggle()
		if skill_window.visible:
			_bring_modal_to_front(skill_window)

func show_pickup_notification(text: String, color: Color = Color.WHITE) -> void:
	if not notification_label:
		notification_label = Label.new()
		notification_label.name = "NotificationLabel"
		notification_label.anchors_preset = Control.PRESET_CENTER_TOP
		notification_label.offset_top = 60
		notification_label.add_theme_font_size_override("font_size", 18)
		notification_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		notification_label.add_theme_color_override("font_outline_color", Color.BLACK)
		notification_label.add_theme_constant_override("outline_size", 4)
		notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(notification_label)

	notification_label.text = text
	notification_label.modulate = color
	notification_label.visible = true

	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(notification_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): notification_label.visible = false; notification_label.modulate.a = 1.0)


func _on_monster_defeated(m_name: String, exp_gained: int) -> void:
	print("[MuHud] Bạn đã tiêu diệt %s! Nhận được +%d EXP!" % [m_name, exp_gained])
