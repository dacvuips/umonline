extends CanvasLayer
class_name MuHud

## Giao diện người dùng (HUD) cho MU Online Godot Client
## Chuẩn phong cách Mobile MU Origin:
## - Góc trên trái: Avatar Hiệp Sĩ, 3 thanh Máu (HP) / Mana (MP) / Thể Lực (AG), 3 nút tiện ích & MU Helper
## - Góc trên phải: Hàng nút chức năng Thư, Guild, Cửa hàng, Cài đặt, Túi (kèm nút thu gọn) & Bản Đồ Mini
## - Góc dưới trái: 4 Ô Vật Phẩm Nhanh (Bình Máu đỏ, Bình Mana xanh, Nút +, Ô 34) & Cần Điều Khiển Ảo (Joystick)
## - Góc dưới phải: Nút Đánh (ATK) to tròn ở tâm, 3 Kỹ Năng vòng cung, Khóa mục tiêu, Đổi chế độ, Đổi trang 1/2, Bong bóng Chat
## - Đáy màn hình: Khung Chat bán trong suốt chính giữa và Thanh Trạng Thái (EXP, Wifi, Pin, Level)

@export var player_node: MuPlayer

@onready var joystick_container: Control = $MobileControls/VirtualJoystick if has_node("MobileControls/VirtualJoystick") else null
@onready var mobile_skill_panel: Control = $MobileControls/MobileSkillPanel if has_node("MobileControls/MobileSkillPanel") else null
@onready var notification_label: Label = null

@onready var inventory_window: InventoryWindow = $InventoryWindow if has_node("InventoryWindow") else null
@onready var shop_window: ShopWindow = $ShopWindow if has_node("ShopWindow") else null
@onready var vault_window: VaultWindow = $VaultWindow if has_node("VaultWindow") else null
const VaultWindowRes = preload("res://src/ui/VaultWindow.gd")
@onready var chat_window: ChatWindow = $ChatWindow if has_node("ChatWindow") else null
@onready var stats_window: CharacterStatsWindow = $CharacterStatsWindow if has_node("CharacterStatsWindow") else null
@onready var classic_hud_bar: MuClassicHudBar = $MuClassicHudBar if has_node("MuClassicHudBar") else null
@onready var top_map_widget_legacy: Control = $TopMapWidget if has_node("TopMapWidget") else null

const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const MuMoveWindowRes = preload("res://src/ui/MuMoveWindow.gd")
const MuSkillWindowRes = preload("res://src/ui/MuSkillWindow.gd")
const ChaosMixWindowRes = preload("res://src/ui/ChaosMixWindow.gd")
const DevilSquareWindowRes = preload("res://src/ui/DevilSquareWindow.gd")
const MuChaosMixRes = preload("res://src/mu/MuChaosMix.gd")
const MuBigMapWindowRes = preload("res://src/ui/MuBigMapWindow.gd")
const MuNoticeBannerRes = preload("res://src/ui/MuNoticeBanner.gd")
const MuEventManagerRes = preload("res://src/events/MuEventManager.gd")
const MuEventScheduleWindowRes = preload("res://src/ui/MuEventScheduleWindow.gd")
const NpcDialogueWindowRes = preload("res://src/ui/NpcDialogueWindow.gd")
const MuMarketWindowRes = preload("res://src/ui/MuMarketWindow.gd")
const MuDragonEventWidgetRes = preload("res://src/ui/MuDragonEventWidget.gd")

# Các widget UI Mobile Origin mới
const MuPlayerStatusWidgetRes = preload("res://src/ui/MuPlayerStatusWidget.gd")
const MuTopMenuWidgetRes = preload("res://src/ui/MuTopMenuWidget.gd")
const MuMiniMapWidgetRes = preload("res://src/ui/MuMiniMapWidget.gd")
const MuTargetInfoWidgetRes = preload("res://src/ui/MuTargetInfoWidget.gd")
const MuBottomLeftWidgetRes = preload("res://src/ui/MuBottomLeftWidget.gd")
const MuBottomRightCombatWidgetRes = preload("res://src/ui/MuBottomRightCombatWidget.gd")
const MuMobileStatusFooterRes = preload("res://src/ui/MuMobileStatusFooter.gd")

var player_status_widget: Control = null
var top_menu_widget: Control = null
var side_menu_widget: Control = null
var _help_panel: Control = null
var minimap_widget: Control = null
var target_info_widget: Control = null
var bottom_left_widget: Control = null
var bottom_right_combat_widget: Control = null
var mobile_status_footer: Control = null

var chaos_mix_window = null
var devil_square_window = null
var move_window = null
var item_picker_window = null
var gm_window = null
var skill_window = null
var big_map_window = null
var option_window = null
var notice_banner = null
var event_manager = null
var event_schedule_window = null
var npc_dialogue_window = null
var market_window = null
var dragon_event_widget = null

const TradeWindowRes = preload("res://src/ui/TradeWindow.gd")
const PlayerEquipWindowRes = preload("res://src/ui/PlayerEquipWindow.gd")
var trade_window = null
var equip_view_window = null
var _pending_trade: MuOtherPlayer = null
var _incoming_cooldown := 90.0
var _guild_ask_cooldown := 20.0

func _ready() -> void:
	add_to_group("HUD")

	# 1. Khởi tạo các Modal Windows cơ bản
	var item_ui := MuItemUiRes.new()
	item_ui.name = "MuItemUi"
	item_ui.z_index = 100
	add_child(item_ui)

	move_window = MuMoveWindowRes.new()
	move_window.name = "MoveWindow"
	move_window.z_index = 30
	add_child(move_window)
	if player_node:
		move_window.setup(player_node)

	var item_picker_script = load("res://src/ui/MuItemPickerWindow.gd")
	if item_picker_script:
		var inst = item_picker_script.new()
		if inst is Node:
			item_picker_window = inst
			item_picker_window.name = "ItemPickerWindow"
			item_picker_window.z_index = 30
			add_child(item_picker_window)
			if player_node and item_picker_window.has_method("setup"):
				item_picker_window.setup(player_node)

	var gm_script = load("res://src/ui/MuGmWindow.gd")
	if gm_script:
		var inst = gm_script.new()
		if inst is Node:
			gm_window = inst
			gm_window.name = "GmWindow"
			gm_window.z_index = 30
			add_child(gm_window)
			if player_node and gm_window.has_method("setup"):
				gm_window.setup(player_node)
			gm_window.visible = false

	var skill_script = load("res://src/ui/MuSkillWindow.gd")
	if skill_script:
		var inst = skill_script.new()
		if inst is Node:
			skill_window = inst
			skill_window.name = "SkillWindow"
			skill_window.z_index = 30
			add_child(skill_window)
			if player_node and skill_window.has_method("setup"):
				skill_window.setup(player_node)

	big_map_window = MuBigMapWindowRes.new()
	big_map_window.name = "BigMapWindow"
	big_map_window.z_index = 35
	add_child(big_map_window)
	if player_node:
		big_map_window.setup(player_node)

	market_window = MuMarketWindowRes.new()
	market_window.name = "MarketWindow"
	market_window.z_index = 35
	add_child(market_window)
	if player_node:
		market_window.setup(player_node)

	var opt_script = load("res://src/ui/MuOptionWindow.gd")
	if opt_script:
		var inst = opt_script.new()
		if inst is Node:
			option_window = inst
			option_window.name = "OptionWindow"
			option_window.z_index = 35
			add_child(option_window)

	_setup_helper()

	npc_dialogue_window = NpcDialogueWindowRes.new()
	npc_dialogue_window.name = "NpcDialogueWindow"
	npc_dialogue_window.z_index = 35
	add_child(npc_dialogue_window)
	npc_dialogue_window.action_triggered.connect(_on_npc_dialogue_action)

	# Ẩn thanh HUD PC cũ & top map cũ để chuyển hoàn toàn sang UI Mobile Origin
	if classic_hud_bar:
		classic_hud_bar.visible = false
	if top_map_widget_legacy:
		top_map_widget_legacy.visible = false
	if joystick_container:
		joystick_container.visible = false
	if mobile_skill_panel:
		mobile_skill_panel.visible = false

	# 2. Xây dựng Cụm Giao Diện Mobile MU Origin Mới
	_build_mobile_origin_hud()

	# Cài đặt dữ liệu các cửa sổ
	if inventory_window and player_node:
		inventory_window.setup(player_node)
	if chat_window and player_node:
		chat_window.setup(player_node)
		_reposition_chat_window()
	if stats_window and player_node:
		stats_window.setup(player_node)
	if not vault_window:
		vault_window = VaultWindowRes.new()
		vault_window.name = "VaultWindow"
		vault_window.z_index = 30
		add_child(vault_window)
	if vault_window and player_node:
		vault_window.setup(player_node)

	if player_node:
		player_node.monster_defeated.connect(_on_monster_defeated)

	# Khởi tạo Hệ Thống Quản Lý Sự Kiện & Banner Thông Báo Toàn Server
	notice_banner = MuNoticeBannerRes.new()
	add_child(notice_banner)

	event_manager = MuEventManagerRes.new()
	add_child(event_manager)

	event_schedule_window = MuEventScheduleWindowRes.new()
	event_schedule_window.z_index = 30
	add_child(event_schedule_window)
	if player_node:
		event_schedule_window.player = player_node

	get_viewport().size_changed.connect(arrange_dock_windows)

	# Giao dịch giữa 2 người chơi (CTrade) + xem trang bị người chơi khác
	trade_window = TradeWindowRes.new()
	trade_window.name = "TradeWindow"
	add_child(trade_window)
	equip_view_window = PlayerEquipWindowRes.new()
	equip_view_window.name = "PlayerEquipWindow"
	add_child(equip_view_window)
	_build_social()
	raven_bar = RavenCommandBarRes.new()
	raven_bar.name = "RavenCommandBar"
	raven_bar.z_index = 5
	add_child(raven_bar)
	if player_node:
		raven_bar.setup(player_node)
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_on_other_player_tick)
	add_child(t)

	move_child(item_ui, get_child_count() - 1)

func _build_mobile_origin_hud() -> void:
	# A. Góc trên trái: Thông tin nhân vật, HP, MP, AG, Helper
	player_status_widget = MuPlayerStatusWidgetRes.new()
	player_status_widget.name = "MuPlayerStatusWidget"
	player_status_widget.position = Vector2(10, 8)
	player_status_widget.z_index = 4
	add_child(player_status_widget)
	if player_node:
		player_status_widget.setup(player_node)

	# B. Góc trên phải: Mini Map (sát lề phải)
	minimap_widget = MuMiniMapWidgetRes.new()
	minimap_widget.name = "MuMiniMapWidget"
	minimap_widget.anchors_preset = Control.PRESET_TOP_RIGHT
	minimap_widget.anchor_left = 1.0
	minimap_widget.anchor_right = 1.0
	minimap_widget.anchor_top = 0.0
	minimap_widget.anchor_bottom = 0.0
	minimap_widget.offset_left = -134
	minimap_widget.offset_right = -10
	minimap_widget.offset_top = 8
	minimap_widget.offset_bottom = 165
	minimap_widget.z_index = 4
	add_child(minimap_widget)
	if player_node:
		minimap_widget.setup(player_node)

	# B2. Góc trên phải: Khung hiển thị Tên & Máu Quái vật được Target (ngay dưới Mini Map)
	target_info_widget = MuTargetInfoWidgetRes.new()
	target_info_widget.name = "MuTargetInfoWidget"
	target_info_widget.anchors_preset = Control.PRESET_TOP_RIGHT
	target_info_widget.anchor_left = 1.0
	target_info_widget.anchor_right = 1.0
	target_info_widget.anchor_top = 0.0
	target_info_widget.anchor_bottom = 0.0
	target_info_widget.offset_left = -134
	target_info_widget.offset_right = -10
	target_info_widget.offset_top = 172
	target_info_widget.offset_bottom = 218
	target_info_widget.z_index = 4
	add_child(target_info_widget)
	if player_node:
		target_info_widget.setup(player_node)

	# B3. Góc trên phải: Widget Sự Kiện Rồng Đỏ / Hoàng Kim (ngay dưới Target Info)
	# dragon_event_widget = MuDragonEventWidgetRes.new()
	# dragon_event_widget.name = "MuDragonEventWidget"
	# dragon_event_widget.z_index = 45
	# add_child(dragon_event_widget)

	# C. Góc trên: Hàng Nút Menu Nằm Ngang (Chỉ số C, Kỹ năng K, Túi I, Chợ P, Sự kiện H, Hướng dẫn ?, Cài đặt Setting)
	top_menu_widget = MuTopMenuWidgetRes.new()
	top_menu_widget.name = "MuTopMenuWidget"
	top_menu_widget.anchors_preset = Control.PRESET_TOP_RIGHT
	top_menu_widget.anchor_left = 1.0
	top_menu_widget.anchor_right = 1.0
	top_menu_widget.anchor_top = 0.0
	top_menu_widget.anchor_bottom = 0.0
	top_menu_widget.offset_left = -880
	top_menu_widget.offset_right = -146
	top_menu_widget.offset_top = 8
	top_menu_widget.offset_bottom = 76
	top_menu_widget.z_index = 5
	add_child(top_menu_widget)
	if top_menu_widget.has_signal("button_pressed"):
		top_menu_widget.button_pressed.connect(_on_side_menu_pressed)
	_setup_auto_button()

	# D. Góc dưới trái: 4 Ô Vật Phẩm Nhanh + Cần Điều Khiển (Virtual Joystick)
	bottom_left_widget = MuBottomLeftWidgetRes.new()
	bottom_left_widget.name = "MuBottomLeftWidget"
	bottom_left_widget.anchors_preset = Control.PRESET_BOTTOM_LEFT
	bottom_left_widget.anchor_left = 0.0
	bottom_left_widget.anchor_right = 0.0
	bottom_left_widget.anchor_top = 1.0
	bottom_left_widget.anchor_bottom = 1.0
	bottom_left_widget.offset_left = 22
	bottom_left_widget.offset_top = -320
	bottom_left_widget.offset_right = 287
	bottom_left_widget.offset_bottom = -20
	bottom_left_widget.z_index = 4
	add_child(bottom_left_widget)
	if player_node:
		bottom_left_widget.setup(player_node)

	# E. Góc dưới phải: Nút ATK Chính, Kỹ Năng vòng cung, Khóa mục tiêu...
	bottom_right_combat_widget = MuBottomRightCombatWidgetRes.new()
	bottom_right_combat_widget.name = "MuBottomRightCombatWidget"
	bottom_right_combat_widget.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	bottom_right_combat_widget.anchor_left = 1.0
	bottom_right_combat_widget.anchor_right = 1.0
	bottom_right_combat_widget.anchor_top = 1.0
	bottom_right_combat_widget.anchor_bottom = 1.0
	bottom_right_combat_widget.offset_left = -355
	bottom_right_combat_widget.offset_top = -365
	bottom_right_combat_widget.offset_right = -5
	bottom_right_combat_widget.offset_bottom = -5
	bottom_right_combat_widget.z_index = 4
	add_child(bottom_right_combat_widget)
	if player_node:
		bottom_right_combat_widget.setup(player_node)

	# F. Đáy màn hình: Thanh Trạng Thái (EXP, Wifi, Pin, Level)
	mobile_status_footer = MuMobileStatusFooterRes.new()
	mobile_status_footer.name = "MuMobileStatusFooter"
	mobile_status_footer.z_index = 2
	add_child(mobile_status_footer)
	if player_node:
		mobile_status_footer.setup(player_node)

func _reposition_chat_window() -> void:
	if not chat_window:
		return
	chat_window.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	chat_window.anchor_left = 0.5
	chat_window.anchor_right = 0.5
	chat_window.anchor_top = 1.0
	chat_window.anchor_bottom = 1.0
	chat_window.offset_left = -205
	chat_window.offset_right = 205
	chat_window.offset_top = -180
	chat_window.offset_bottom = -24
	chat_window.z_index = 3

var _top_modal_z: int = 30

func _bring_modal_to_front(win: Control) -> void:
	if win and is_instance_valid(win):
		_top_modal_z += 1
		if _top_modal_z > 65:
			_top_modal_z = 31
		win.z_index = _top_modal_z
		win.move_to_front()
		var item_ui = get_node_or_null("MuItemUi")
		if item_ui:
			item_ui.z_index = 100
			move_child(item_ui, get_child_count() - 1)

func arrange_dock_windows() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var w: float = 190.0 * 1.5
	var h: float = 429.0 * 1.5
	var default_y: float = floorf(maxf(0.0, (vs.y - h) * 0.5))

	var inv_vis: bool = inventory_window != null and inventory_window.visible
	var stats_vis: bool = stats_window != null and stats_window.visible

	if inv_vis and stats_vis:
		# Khi mở cả 2 bảng thì được sắp xếp như hình:
		# Inventory bên TRÁI, Character Stats bên PHẢI, Y bằng chằn chặn tuyệt đối
		var target_y: float = default_y
		if stats_window and stats_window.user_has_dragged and not (inventory_window and inventory_window.user_has_dragged):
			target_y = stats_window.position.y
		elif inventory_window and inventory_window.user_has_dragged and not (stats_window and stats_window.user_has_dragged):
			target_y = inventory_window.position.y

		if stats_window and not stats_window.user_has_dragged:
			stats_window.position = Vector2(vs.x - w, target_y)
		if inventory_window and not inventory_window.user_has_dragged:
			inventory_window.position = Vector2(vs.x - 2.0 * w, target_y)
	elif stats_vis:
		if stats_window and not stats_window.user_has_dragged:
			stats_window.position = Vector2(vs.x - w, default_y)
	elif inv_vis:
		if inventory_window and not inventory_window.user_has_dragged:
			inventory_window.position = Vector2(vs.x - w, default_y)

func toggle_character_stats() -> void:
	if stats_window:
		stats_window.visible = not stats_window.visible
		arrange_dock_windows()
		if stats_window.visible:
			_bring_modal_to_front(stats_window)
			stats_window.update_stats()
			if MuAudioManager:
				MuAudioManager.play_ui_window()

func toggle_inventory() -> void:
	if inventory_window:
		inventory_window.visible = not inventory_window.visible
		arrange_dock_windows()
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

func toggle_gm_panel() -> void:
	if gm_window:
		gm_window.toggle()
		if gm_window.visible:
			_bring_modal_to_front(gm_window)
		if MuAudioManager:
			MuAudioManager.play_ui_window()

func toggle_settings() -> void:
	if not option_window:
		var opt_script = load("res://src/ui/MuOptionWindow.gd")
		if opt_script:
			var inst = opt_script.new()
			if inst is Node:
				option_window = inst
				option_window.name = "OptionWindow"
				option_window.z_index = 35
				add_child(option_window)
	if option_window:
		option_window.toggle()
		if option_window.visible:
			_bring_modal_to_front(option_window)

func toggle_joystick() -> void:
	if bottom_left_widget:
		bottom_left_widget.visible = not bottom_left_widget.visible

func toggle_mobile_skills() -> void:
	if bottom_right_combat_widget:
		bottom_right_combat_widget.visible = not bottom_right_combat_widget.visible

func open_vault(npc: MuNpc = null) -> void:
	if not vault_window:
		vault_window = VaultWindowRes.new()
		vault_window.name = "VaultWindow"
		vault_window.z_index = 30
		add_child(vault_window)
		if player_node:
			vault_window.setup(player_node)
	_bring_modal_to_front(vault_window)
	if inventory_window:
		_bring_modal_to_front(inventory_window)
	var keeper_name = npc.npc_name if npc else "Thủ Kho"
	vault_window.open_vault(player_node, keeper_name, npc)

func toggle_vault() -> void:
	if not vault_window:
		open_vault()
		return
	if vault_window.visible:
		vault_window.close()
	else:
		open_vault()

func open_chaos_mix(npc: MuNpc = null) -> void:
	if not player_node:
		return
	if player_node.level < MuChaosMixRes.MIX_LEVEL:
		var t := "Chỉ nhân vật từ cấp %d trở lên mới trộn Chaos được." % MuChaosMixRes.MIX_LEVEL
		show_pickup_notification(t, Color(1.0, 0.4, 0.3))
		if chat_window and chat_window.has_method("add_system_message"):
			chat_window.add_system_message("[color=#FF8866]%s[/color]" % t)
		return
	if not chaos_mix_window:
		chaos_mix_window = ChaosMixWindowRes.new()
		chaos_mix_window.name = "ChaosMixWindow"
		chaos_mix_window.z_index = 30
		add_child(chaos_mix_window)
	if shop_window and shop_window.visible and shop_window.has_method("close"):
		shop_window.close()
	if vault_window and vault_window.visible:
		vault_window.close()
	_bring_modal_to_front(chaos_mix_window)
	chaos_mix_window.open_mix(player_node, npc)
	if inventory_window:
		_bring_modal_to_front(inventory_window)

## NPC Lahap / Jeweler Raul: gộp - tách ngọc
var jewel_bundle_window: Control = null

func open_jewel_bundle(npc: MuNpc = null) -> void:
	if not player_node:
		return
	if jewel_bundle_window == null:
		jewel_bundle_window = load("res://src/ui/JewelBundleWindow.gd").new()
		jewel_bundle_window.name = "JewelBundleWindow"
		jewel_bundle_window.z_index = 30
		add_child(jewel_bundle_window)
	if shop_window and shop_window.visible and shop_window.has_method("close"):
		shop_window.close()
	jewel_bundle_window.open_window(player_node, npc)
	_bring_modal_to_front(jewel_bundle_window)
	if inventory_window:
		inventory_window.visible = true
		inventory_window.update_display()
		_bring_modal_to_front(inventory_window)

func open_npc_dialogue(npc: MuNpc) -> void:
	if not player_node:
		return
	if not npc_dialogue_window:
		npc_dialogue_window = NpcDialogueWindowRes.new()
		npc_dialogue_window.name = "NpcDialogueWindow"
		npc_dialogue_window.z_index = 35
		add_child(npc_dialogue_window)
		npc_dialogue_window.action_triggered.connect(_on_npc_dialogue_action)
	_bring_modal_to_front(npc_dialogue_window)
	npc_dialogue_window.open_dialogue(player_node, npc)

func _on_npc_dialogue_action(action: String, npc: Node3D) -> void:
	var mu_npc: MuNpc = npc as MuNpc
	if not player_node:
		return

	match action:
		"shop":
			if mu_npc:
				open_npc_shop(mu_npc)
		"vault":
			open_vault(mu_npc)
		"chaos_box":
			open_chaos_mix(mu_npc)
		"devil_square":
			open_devil_square(mu_npc)
		"lahap":
			open_jewel_bundle(mu_npc)
		"buff":
			if player_node.level <= 220:
				var atk_bonus = int(player_node.level / 5) + 30
				var def_bonus = int(player_node.level / 5) + 20
				player_node.apply_shadow_phantom_buff(atk_bonus, def_bonus)
				show_pickup_notification("★ [Shadow Phantom Soldier] Lời chúc phúc đã được ban tặng! (+%d Tấn công, +%d Phòng thủ trong 30p)" % [atk_bonus, def_bonus], Color(0.4, 1.0, 0.8))
				if chat_window and chat_window.has_method("add_system_message"):
					chat_window.add_system_message("[color=#55FFAA]★ [Shadow Phantom Soldier] Ban lời chúc phúc: +%d Sát thương, +%d Phòng thủ![/color]" % [atk_bonus, def_bonus])
			else:
				show_pickup_notification("[Shadow Phantom Soldier] Bạn đã vượt cấp 220, hãy tự tin bước đi trên đôi chân của mình!", Color(1.0, 0.85, 0.4))

		# --- NHIỆM VỤ NỮ TU SEVINA (CHUYỂN CHỨC CẤP 2) ---
		"quest_sevina_accept":
			player_node.quest_sevina_step = 1
			show_pickup_notification("★ [Nhiệm Vụ Sevina] Đã nhận Bước 1: Hãy tìm 'Cuốn Sách Đế Vương' tại Lost Tower!", Color(0.4, 1.0, 0.5))
		"quest_sevina_help_scroll":
			player_node.give_item(14, 23)
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận 'Cuốn Sách Đế Vương' (Scroll of the Emperor)!", Color(0.4, 0.9, 1.0))
		"quest_sevina_submit_step1":
			if player_node.has_item(14, 23):
				player_node.remove_item_by_id(14, 23, 1)
				player_node.stat_points += 10
				player_node.add_zen(20000)
				player_node.quest_sevina_step = 2
				show_pickup_notification("★ [Thành Công] Đã nộp Cuốn Sách Đế Vương! (+10 Điểm Tiềm Năng, +20.000 Zen). Bước 2 bắt đầu!", Color(0.3, 1.0, 0.5))
				if chat_window and chat_window.has_method("add_system_message"):
					chat_window.add_system_message("[color=#55FFAA]★ [Sevina] Nộp thành công Cuốn Sách Đế Vương! Nhận 10 Điểm Tiềm Năng.[/color]")
			else:
				show_pickup_notification("Bạn không có 'Cuốn Sách Đế Vương' trong túi đồ!", Color(1.0, 0.4, 0.4))
		"quest_sevina_help_treasure":
			var tid = 24
			if player_node.char_class == 0: tid = 26
			elif player_node.char_class == 2: tid = 25
			elif player_node.char_class == 5: tid = 68
			player_node.give_item(14, tid)
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận Bảo Vật Tộc Hệ!", Color(0.4, 0.9, 1.0))
		"quest_sevina_submit_step2":
			var tid = 24
			if player_node.char_class == 0: tid = 26
			elif player_node.char_class == 2: tid = 25
			elif player_node.char_class == 5: tid = 68
			if player_node.has_item(14, tid):
				player_node.remove_item_by_id(14, tid, 1)
				player_node.quest_sevina_step = 3
				player_node.promote_class_tier(2)
				var new_cls = player_node.get_class_display_name()
				show_pickup_notification("★ [CHÚC MỪNG] THĂNG CHỨC THÀNH CÔNG: %s! (+20 Điểm Tiềm Năng)" % new_cls, Color(1.0, 0.85, 0.2))
				if chat_window and chat_window.has_method("add_system_message"):
					chat_window.add_system_message("[color=#FFD700]★ [Hệ Thống] Người chơi %s đã thăng chức thành %s![/color]" % [player_node.character_name, new_cls])
			else:
				show_pickup_notification("Bạn chưa sở hữu Bảo Vật Tộc Hệ trong túi đồ!", Color(1.0, 0.4, 0.4))

		# --- NHIỆM VỤ HIỆP SĨ MARLON (COMBO & BONUS STATS) ---
		"quest_marlon_accept":
			player_node.quest_marlon_step = 1
			show_pickup_notification("★ [Nhiệm Vụ Marlon] Hãy tìm 'Chiếc Nhẫn Vinh Quang' (Ring of Honor) tại Tarkan!", Color(0.4, 1.0, 0.5))
		"quest_marlon_help_ring":
			player_node.give_item(14, 22)
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận 'Chiếc Nhẫn Vinh Quang' (Ring of Honor)!", Color(0.4, 0.9, 1.0))
		"quest_marlon_submit_step1":
			if player_node.has_item(14, 22):
				player_node.remove_item_by_id(14, 22, 1)
				player_node.has_marlon_stat_bonus = true
				var bonus_pts = maxi(0, player_node.level - 219)
				player_node.stat_points += bonus_pts
				if player_node.char_class == 1: # DK/BK
					player_node.quest_marlon_step = 2
					show_pickup_notification("★ [Marlon] Đã nộp Nhẫn Vinh Quang! Nhận +%d Điểm Tiềm Năng bổ sung. Bước 2: Tìm 'Viên Đá Bóng Tối'!" % bonus_pts, Color(0.3, 1.0, 0.5))
				else:
					player_node.quest_marlon_step = 3
					show_pickup_notification("★ [Marlon] Hoàn thành xuất sắc nhiệm vụ! Nhận +%d Điểm Tiềm Năng bổ sung." % bonus_pts, Color(1.0, 0.85, 0.2))
			else:
				show_pickup_notification("Bạn không có 'Chiếc Nhẫn Vinh Quang' trong túi đồ!", Color(1.0, 0.4, 0.4))
		"quest_marlon_help_stone":
			player_node.give_item(14, 25)
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận 'Viên Đá Bóng Tối' (Dark Stone)!", Color(0.4, 0.9, 1.0))
		"quest_marlon_submit_step2":
			if player_node.has_item(14, 25):
				player_node.remove_item_by_id(14, 25, 1)
				player_node.has_combo_skill = true
				player_node.quest_marlon_step = 3
				show_pickup_notification("★ [CHÚC MỪNG] ĐÃ KHAI MỞ TUYỆT KỸ COMBO LIÊN HOÀN CỦA BLADE KNIGHT!", Color(1.0, 0.85, 0.2))
				if chat_window and chat_window.has_method("add_system_message"):
					chat_window.add_system_message("[color=#FF8800]★ [Kỹ Năng] Đã mở khóa Combo Skill! Chuỗi chiêu thức Cyclone + Twisting Slash kích hoạt sát thương bộc phát x2.5![/color]")
			else:
				show_pickup_notification("Bạn không có 'Viên Đá Bóng Tối' trong túi đồ!", Color(1.0, 0.4, 0.4))

		# --- NHIỆM VỤ ĐẠI GIÁO SĨ DEVIN (CHUYỂN CHỨC CẤP 3 MASTER CLASS) ---
		"quest_devin_accept":
			player_node.quest_devin_step = 1
			show_pickup_notification("★ [Priest Devin] Hãy tìm Ngọn Lửa Hiệp Sĩ, Sừng Quỷ và Lông Phượng Hoàng!", Color(0.4, 1.0, 0.5))
		"quest_devin_help_items":
			player_node.give_item(14, 65)
			player_node.give_item(14, 67)
			player_node.give_item(14, 68)
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận 3 Bảo Vật Thử Thách Cấp 3!", Color(0.4, 0.9, 1.0))
		"quest_devin_submit":
			if player_node.has_item(14, 65) and player_node.has_item(14, 67) and player_node.has_item(14, 68):
				player_node.remove_item_by_id(14, 65, 1)
				player_node.remove_item_by_id(14, 67, 1)
				player_node.remove_item_by_id(14, 68, 1)
				player_node.quest_devin_step = 2
				player_node.promote_class_tier(3)
				var new_cls = player_node.get_class_display_name()
				show_pickup_notification("★ [ĐẠI HUYỀN THOẠI] THĂNG CHỨC THÀNH CÔNG: %s (MASTER CLASS)! (+30 Điểm Tiềm Năng)" % new_cls, Color(1.0, 0.85, 0.2))
				if chat_window and chat_window.has_method("add_system_message"):
					chat_window.add_system_message("[color=#FF55FF]★ [Thông Báo Toàn Lục Địa] Chiến binh %s đã trở thành %s tối thượng![/color]" % [player_node.character_name, new_cls])
			else:
				show_pickup_notification("Bạn chưa thu thập đủ cả 3 Bảo Vật Thử Thách!", Color(1.0, 0.4, 0.4))

		# --- THỢ RÈN SỬA CHỮA TOÀN BỘ TRANG BỊ ---
		"repair_all":
			var rep = player_node.repair_all_items()
			if rep.count > 0:
				show_pickup_notification("★ Đã sửa chữa %d món trang bị! Chi phí: %s Zen." % [rep.count, MuItems.format_zen(rep.cost)], Color(0.4, 1.0, 0.5))
			else:
				show_pickup_notification("Toàn bộ trang bị của bạn đều còn nguyên độ bền tối đa!", Color(1.0, 0.9, 0.4))

		# --- TINH CHẾ ĐÁ TẠO HÓA (ELPIS) ---
		"refinery_help_gem":
			for i in 5:
				player_node.give_item(14, 41)
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận 5 Viên Đá Quý Thô (Gemstone)!", Color(0.4, 0.9, 1.0))
		"refinery_execute":
			if player_node.has_item(14, 41):
				player_node.remove_item_by_id(14, 41, 1)
				if randf() <= 0.80:
					player_node.give_item(14, 42)
					show_pickup_notification("★ [Thành Công] Tinh chế thành công 1 Viên Đá Tạo Hóa (Jewel of Harmony)!", Color(1.0, 0.85, 0.2))
					if MuAudioManager:
						MuAudioManager.play_sound_file("sKnightSkill1.wav")
				else:
					show_pickup_notification("Tinh chế thất bại! Đá thô đã tan biến thành cát bụi.", Color(1.0, 0.4, 0.4))
			else:
				show_pickup_notification("Bạn không có Đá Quý Thô (Gemstone) trong túi!", Color(1.0, 0.4, 0.4))
		"refinery_execute_all":
			var gems = player_node.count_item(14, 41)
			if gems <= 0:
				show_pickup_notification("Bạn không có Đá Quý Thô (Gemstone) trong túi!", Color(1.0, 0.4, 0.4))
				return
			player_node.remove_item_by_id(14, 41, gems)
			var success := 0
			for i in gems:
				if randf() <= 0.80:
					player_node.give_item(14, 42)
					success += 1
			show_pickup_notification("★ [Tinh Chế Xong] Tinh chế %d viên Gemstone -> Nhận được %d Đá Tạo Hóa (Jewel of Harmony)!" % [gems, success], Color(1.0, 0.85, 0.2))

		# --- ĐỔI ĐÁ RENA LẤY QUÀ (GOLDEN ARCHER) ---
		"exchange_rena_help":
			for i in 5:
				player_node.give_item(14, 21)
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận 5 Viên Đá Rena!", Color(0.4, 0.9, 1.0))
		"exchange_rena_execute":
			if player_node.count_item(14, 21) >= 5:
				player_node.remove_item_by_id(14, 21, 5)
				player_node.add_zen(100000)
				var jewel_types = [
					{"g": 12, "n": 15, "name": "Ngọc Chaos"},
					{"g": 14, "n": 13, "name": "Ngọc Bless"},
					{"g": 14, "n": 14, "name": "Ngọc Soul"},
					{"g": 14, "n": 16, "name": "Ngọc Life"}
				]
				var pick = jewel_types.pick_random()
				player_node.give_item(pick.g, pick.n)
				show_pickup_notification("★ [Cung Thủ Hoàng Kim] Đổi 5 Rena nhận 100.000 Zen và 1 %s!" % pick.name, Color(0.4, 1.0, 0.5))
			else:
				show_pickup_notification("Cần đủ 5 viên Rena (hiện có: %d/5)!" % player_node.count_item(14, 21), Color(1.0, 0.4, 0.4))

		# --- THỬ VẬN MAY (MOSS THE MERCHANT) ---
		"moss_gamble_execute":
			var cost = 500000
			if player_node.zen < cost:
				show_pickup_notification("Không đủ Zen! Cần %s Zen để thử vận may." % MuItems.format_zen(cost), Color(1.0, 0.4, 0.4))
				return
			player_node.add_zen(-cost)
			var w_group = 0 # Kiếm
			var w_num = randi_range(0, 16)
			if player_node.char_class == 0: # DW
				w_group = 5
				w_num = randi_range(0, 12)
			elif player_node.char_class == 2: # Elf
				w_group = 4
				w_num = randi_range(0, 15)
			elif player_node.char_class == 4: # DL
				w_group = 2
				w_num = randi_range(0, 12)

			var is_exc = (randf() <= 0.35)
			var has_skill = (randf() <= 0.70)
			var has_luck = (randf() <= 0.50)
			var lvl = randi_range(0, 9)
			player_node.give_item(w_group, w_num, lvl, is_exc, has_skill, has_luck)
			var res_text = "Vũ Khí +%d" % lvl
			if is_exc: res_text = "[Hoàn Hảo (Excellent)] " + res_text
			show_pickup_notification("★ [Moss] Vận may mỉm cười! Nhận được: %s!" % res_text, Color(1.0, 0.85, 0.2))

		# --- THÀNH LẬP BANG HỘI (GUILD MASTER) ---
		"guild_create_execute":
			var g_cost = 1000000
			if player_node.level < 100:
				show_pickup_notification("Bạn cần đạt cấp độ 100 trở lên để lập bang!", Color(1.0, 0.4, 0.4))
				return
			if player_node.zen < g_cost:
				show_pickup_notification("Không đủ Zen! Cần 1.000.000 Zen để thành lập bang hội.", Color(1.0, 0.4, 0.4))
				return
			player_node.add_zen(-g_cost)
			player_node.guild_name = "LegionOfMU"
			show_pickup_notification("★ [CHÚC MỪNG] THÀNH LẬP BANG HỘI THÀNH CÔNG: [ %s ]!" % player_node.guild_name, Color(1.0, 0.85, 0.2))
			if chat_window and chat_window.has_method("add_system_message"):
				chat_window.add_system_message("[color=#FFD700]★ [Bang Hội] Người chơi %s đã thành lập bang hội %s![/color]" % [player_node.character_name, player_node.guild_name])

		# --- HUẤN LUYỆN VIÊN THÚ NUÔI (PET TRAINER) ---
		"pet_help_materials":
			player_node.give_item(13, 31) # Crest of Monarch
			player_node.give_item(13, 14) # Loch's Feather / Raven Spirit
			for i in 5: player_node.give_item(12, 15) # Chaos
			for i in 5: player_node.give_item(14, 13) # Bless
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận Linh Hồn Chiến Mã, Quạ Tinh và Ngọc ép thú!", Color(0.4, 0.9, 1.0))
		"pet_craft_horse":
			player_node.give_item(13, 4) # Dark Horse
			show_pickup_notification("★ [Pet Trainer] Hồi sinh thành công Chiến Mã Chúa Tể (Dark Horse)!", Color(1.0, 0.85, 0.2))
		"pet_craft_raven":
			player_node.give_item(13, 5) # Dark Raven
			show_pickup_notification("★ [Pet Trainer] Hồi sinh thành công Quạ Tinh Chúa Tể (Dark Raven)!", Color(1.0, 0.85, 0.2))
		"pet_heal_all":
			show_pickup_notification("★ [Pet Trainer] Toàn bộ chiến thú và thú cưỡi đã được hồi phục 100% sinh lực!", Color(0.4, 1.0, 0.5))

		# --- DỊCH CHUYỂN BLOOD CASTLE (WORLD 12) ---
		"blood_castle_help_cloak":
			player_node.give_item(13, 18)
			show_pickup_notification("★ [Hỗ Trợ] Đã nhận Áo Choàng Tàng Hình (Invisibility Cloak)!", Color(0.4, 0.9, 1.0))
		"blood_castle_enter":
			if player_node.has_item(13, 18):
				player_node.remove_item_by_id(13, 18, 1)
				show_pickup_notification("★ Cánh cổng Lâu Đài Máu mở ra! Dịch chuyển đến Blood Castle...", Color(1.0, 0.4, 0.4))
				MuTerrain.change_world(12, Vector2i(15, 14))
				get_tree().call_deferred("reload_current_scene")
			else:
				show_pickup_notification("Bạn cần có 'Áo Choàng Tàng Hình' (Invisibility Cloak) để bước vào Lâu Đài Máu!", Color(1.0, 0.4, 0.4))

		# --- DỊCH CHUYỂN ĐẤU TRƯỜNG VULCANUS ---
		"duel_arena_enter":
			show_pickup_notification("★ Dịch chuyển đến Đấu Trường Quyết Đấu Vulcanus...", Color(1.0, 0.6, 0.2))
			MuTerrain.change_world(80, Vector2i(130, 125))
			get_tree().call_deferred("reload_current_scene")

		_:
			if mu_npc and ShopWindow.has_shop(mu_npc.npc_id):
				open_npc_shop(mu_npc)

func open_devil_square(npc: MuNpc = null) -> void:
	if not player_node:
		return
	if not devil_square_window:
		devil_square_window = DevilSquareWindowRes.new()
		devil_square_window.name = "DevilSquareWindow"
		devil_square_window.z_index = 30
		add_child(devil_square_window)
	_bring_modal_to_front(devil_square_window)
	devil_square_window.open_window(player_node, npc)

func open_npc_shop(npc: MuNpc) -> void:
	if not (shop_window and player_node):
		return
	var nid: int = npc.npc_id
	if nid <= 0:
		nid = NpcDialogueWindow.find_npc_id_by_name(npc.npc_name)
		if nid > 0:
			npc.npc_id = nid
	if not ShopWindow.has_shop(nid):
		show_pickup_notification("%s: \"Xin chào, %s!\"" % [npc.npc_name, player_node.character_name], Color(1, 0.9, 0.6))
		return
	if npc_dialogue_window and npc_dialogue_window.visible:
		npc_dialogue_window.close()
	if vault_window and vault_window.visible:
		vault_window.close()
	if chaos_mix_window and chaos_mix_window.visible:
		chaos_mix_window.close()
	if stats_window and stats_window.visible:
		stats_window.visible = false
	_bring_modal_to_front(shop_window)
	if inventory_window:
		inventory_window.visible = true
		inventory_window.update_display()
		_bring_modal_to_front(inventory_window)
	arrange_dock_windows()
	shop_window.open_shop(player_node, npc.npc_name, nid, npc)
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func toggle_move_window() -> void:
	if move_window:
		move_window.toggle()
		if move_window.visible:
			_bring_modal_to_front(move_window)
		if MuAudioManager:
			MuAudioManager.play_ui_window()

func toggle_big_map() -> void:
	if not big_map_window:
		return
	big_map_window.toggle()
	if big_map_window.visible:
		_bring_modal_to_front(big_map_window)

func open_big_map() -> void:
	if not big_map_window:
		return
	big_map_window.open_map()
	_bring_modal_to_front(big_map_window)

func close_big_map() -> void:
	if big_map_window:
		big_map_window.close()

func toggle_market_window() -> void:
	if not market_window:
		return
	market_window.toggle()
	if market_window.visible:
		_bring_modal_to_front(market_window)
		if MuAudioManager:
			MuAudioManager.play_ui_window()

func open_market_window() -> void:
	if not market_window:
		return
	market_window.open_market()
	_bring_modal_to_front(market_window)
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func close_market_window() -> void:
	if market_window:
		market_window.close()

## MU Helper (auto ingame): node logic gắn vào người chơi + cửa sổ cấu hình
const MuHelperRes = preload("res://src/mu/MuHelper.gd")
const MuHelperWindowRes = preload("res://src/ui/MuHelperWindow.gd")
var mu_helper = null
var helper_window = null

func _setup_helper() -> void:
	if not player_node or mu_helper:
		return
	mu_helper = MuHelperRes.new()
	mu_helper.name = "MuHelper"
	player_node.add_child(mu_helper)
	mu_helper.setup(player_node)
	helper_window = MuHelperWindowRes.new()
	helper_window.name = "HelperWindow"
	add_child(helper_window)
	helper_window.setup(mu_helper, player_node)
	mu_helper.state_changed.connect(_style_auto_button)

## Nút "Auto" bên trái minimap, ngay dưới nút Setting: mở UI cấu hình MU Helper
var auto_button: Button = null

func _setup_auto_button() -> void:
	auto_button = Button.new()
	auto_button.name = "AutoButton"
	auto_button.text = "Auto"
	auto_button.focus_mode = Control.FOCUS_NONE
	auto_button.tooltip_text = "MU Helper — mở cài đặt Auto (End). Bật/tắt: Home"
	auto_button.anchor_left = 1.0
	auto_button.anchor_right = 1.0
	auto_button.offset_left = -214
	auto_button.offset_right = -150
	auto_button.offset_top = 80
	auto_button.offset_bottom = 104
	auto_button.z_index = 5
	auto_button.add_theme_font_size_override("font_size", 12)
	auto_button.pressed.connect(toggle_helper_window)
	add_child(auto_button)
	_style_auto_button(false)

func _style_auto_button(on: bool) -> void:
	if not auto_button:
		return
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.35, 0.15, 0.95) if on else Color(0.08, 0.1, 0.14, 0.95)
		if st == "hover":
			sb.bg_color = sb.bg_color.lightened(0.15)
		sb.border_color = Color(0.4, 0.95, 0.5) if on else Color(0.75, 0.6, 0.25)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		auto_button.add_theme_stylebox_override(st, sb)
	auto_button.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65) if on else Color(1.0, 0.85, 0.45))

func toggle_helper() -> void:
	if mu_helper:
		mu_helper.toggle()

func toggle_helper_window() -> void:
	if helper_window:
		helper_window.toggle()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner != null and (focus_owner is LineEdit or focus_owner is TextEdit):
			return

		match event.keycode:
			KEY_C:
				toggle_character_stats()
				get_viewport().set_input_as_handled()
			KEY_I, KEY_V:
				toggle_inventory()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				toggle_big_map()
				get_viewport().set_input_as_handled()
			KEY_M:
				toggle_move_window()
				get_viewport().set_input_as_handled()
			KEY_K:
				toggle_skill_window()
				get_viewport().set_input_as_handled()
			KEY_P:
				toggle_market_window()
				get_viewport().set_input_as_handled()
			KEY_B:
				toggle_item_picker()
				get_viewport().set_input_as_handled()
			KEY_G, KEY_F10:
				toggle_gm_panel()
				get_viewport().set_input_as_handled()
			KEY_O:
				toggle_settings()
				get_viewport().set_input_as_handled()
			KEY_HOME:
				toggle_helper()
				get_viewport().set_input_as_handled()
			KEY_END:
				toggle_helper_window()
				get_viewport().set_input_as_handled()
			KEY_H:
				toggle_event_schedule()
				get_viewport().set_input_as_handled()
			KEY_F:
				toggle_friend_window()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _close_any_open_modal():
					get_viewport().set_input_as_handled()
				else:
					toggle_settings()
					get_viewport().set_input_as_handled()

## Chức năng của hàng nút menu chức năng
func _on_side_menu_pressed(id: String) -> void:
	match id:
		"character": toggle_character_stats()
		"skill": toggle_skill_window()
		"inventory": toggle_inventory()
		"market": toggle_market_window()
		"event": toggle_event_schedule()
		"help": toggle_help()
		"settings": toggle_settings()
		"gm": toggle_gm_panel()
		"move": toggle_move_window()
		"party": toggle_party_window()
		"guild": toggle_guild_window()
		"friend": toggle_friend_window()
		"close": _close_any_open_modal()

## Bảng hướng dẫn phím tắt + chức năng các nút
func toggle_help() -> void:
	if _help_panel == null:
		var panel := PanelContainer.new()
		panel.name = "HelpPanel"
		panel.z_index = 35
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.1, 0.96)
		sb.border_color = Color(0.75, 0.62, 0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(14)
		panel.add_theme_stylebox_override("panel", sb)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		panel.add_child(vb)
		var title := Label.new()
		title.text = "HƯỚNG DẪN"
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		vb.add_child(title)
		var lines := [
			"C - Chỉ số nhân vật          I / V - Túi đồ",
			"K - Kỹ năng                  M - Di chuyển / dịch chuyển",
			"Tab - Bản đồ lớn             P - Sàn Giao Dịch Chợ Online",
			"H - Lịch Sự Kiện             B - Lấy vật phẩm (GM)",
			"1-4 - Dùng kỹ năng           Phím ` - Đổi trang kỹ năng",
			"Esc / O - Cài đặt hệ thống   Nhấp chuột - Đi tới / đánh quái",
			"",
			"Hàng nút chức năng góc trên (64px):",
			"  Mũ giáp: Chỉ số (C)        Cuộn giấy: Kỹ năng (K)",
			"  Rương đồ: Túi đồ (I)       Chợ vàng: Sàn Giao Dịch Chợ Online (P)",
			"  Lịch: Sự kiện (H)          Dấu ?: Hướng dẫn",
			"  Bánh răng: Cài đặt hệ thống (Esc / O)",
		]
		for l in lines:
			var lb := Label.new()
			lb.text = l
			lb.add_theme_font_size_override("font_size", 13)
			vb.add_child(lb)
		var close := Button.new()
		close.text = "Đóng"
		close.pressed.connect(func(): panel.visible = false)
		vb.add_child(close)
		add_child(panel)
		_help_panel = panel
		panel.visible = false
	_help_panel.visible = not _help_panel.visible
	if _help_panel.visible:
		var vs: Vector2 = get_viewport().get_visible_rect().size
		_help_panel.position = (vs - _help_panel.get_combined_minimum_size()) * 0.5
		_bring_modal_to_front(_help_panel)
		if MuAudioManager:
			MuAudioManager.play_ui_window()

func _close_any_open_modal() -> bool:
	var closed = false
	if target_info_widget and target_info_widget.has_method("has_player") and target_info_widget.has_player():
		close_player_menu()
		return true
	if trade_window and trade_window.visible:
		# CTrade::UpdateKeyEvent: ESC = SendTradeCancel
		trade_window.cancel_trade()
		return true
	if equip_view_window and equip_view_window.visible:
		equip_view_window.close()
		closed = true
	for w in [party_window, guild_window, friend_window, chat_command_window]:
		if w and w.visible:
			w.close()
			closed = true
	if option_window and option_window.visible:
		option_window.close_window()
		closed = true
	if jewel_bundle_window and jewel_bundle_window.visible:
		jewel_bundle_window.close()
		closed = true
	if _help_panel and _help_panel.visible:
		_help_panel.visible = false
		closed = true
	if big_map_window and big_map_window.visible:
		big_map_window.close()
		closed = true
	if market_window and market_window.visible:
		market_window.close()
		closed = true
	if stats_window and stats_window.visible:
		stats_window.visible = false
		closed = true
	if inventory_window and inventory_window.visible:
		inventory_window.visible = false
		closed = true
	if skill_window and skill_window.visible:
		skill_window.visible = false
		closed = true
	if move_window and move_window.visible:
		move_window.visible = false
		closed = true
	if item_picker_window and item_picker_window.visible:
		item_picker_window.visible = false
		closed = true
	if gm_window and gm_window.visible:
		gm_window.visible = false
		closed = true
	if vault_window and vault_window.visible:
		if vault_window.has_method("close"):
			vault_window.close()
		else:
			vault_window.visible = false
		closed = true
	if shop_window and shop_window.visible:
		if shop_window.has_method("close"):
			shop_window.close()
		else:
			shop_window.visible = false
		closed = true
	if chaos_mix_window and chaos_mix_window.visible:
		chaos_mix_window.visible = false
		closed = true
	if devil_square_window and devil_square_window.visible:
		devil_square_window.visible = false
		closed = true
	if closed:
		arrange_dock_windows()
		if MuAudioManager:
			MuAudioManager.play_ui_window()
	return closed

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
		notification_label.offset_top = 70
		notification_label.add_theme_font_size_override("font_size", 16)
		notification_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		notification_label.add_theme_color_override("font_outline_color", Color.BLACK)
		notification_label.add_theme_constant_override("outline_size", 4)
		notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notification_label.z_index = 85
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

## Hiển thị Banner Thông Báo Vàng Toàn Server (Golden Server Notice)
func show_golden_notice(text: String, duration: float = 5.0) -> void:
	if notice_banner:
		notice_banner.post_notice(text, duration)
	else:
		show_pickup_notification(text, Color(1.0, 0.9, 0.3))

## Mở / Đóng Bảng Lịch Sự Kiện MU Online (Phím H)
func toggle_event_schedule() -> void:
	if event_schedule_window:
		event_schedule_window.toggle_window(player_node)

# ================================================================== Người chơi khác: menu lệnh / giao dịch / xem trang bị
## Chạm / bấm vào người chơi khác -> khung mục tiêu góc phải (chỗ tên + máu quái) đổi sang tên người chơi
## kèm 12 nút lệnh của Command Window gốc (CCommandWindow, phím D) + nút Xem đồ.
func open_player_menu(p: MuOtherPlayer, _screen_pos: Vector2 = Vector2.ZERO) -> void:
	select_player(p)

func select_player(p: MuOtherPlayer) -> void:
	if p == null or not is_instance_valid(p) or target_info_widget == null:
		return
	if player_node:
		player_node.clear_target()
	# đang quyết đấu: chạm vào đối thủ = tấn công
	if social and social.in_duel() and social.duel_enemy == p:
		social.attack_duel_enemy()
	target_info_widget.show_player(p)
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func close_player_menu() -> void:
	if target_info_widget and target_info_widget.has_method("clear_player"):
		target_info_widget.clear_player()

## Thứ tự lệnh như kCommandLabels (CommandWindow.cpp): COMMAND_TRADE .. COMMAND_SPECIAL
func run_player_command(cmd: String, p: MuOtherPlayer) -> void:
	if p == null or not is_instance_valid(p) or player_node == null or social == null:
		return
	match cmd:
		"trade":
			request_trade_with(p)
		"party":
			social.invite_party(p)
		"whisper":
			# CommandWhisper -> g_pChatInputBox->SetWhsprID
			if chat_window and chat_window.has_method("start_whisper"):
				chat_window.start_whisper(p.character_name)
		"guild":
			social.request_join_guild(p)
		"alliance", "rival", "rival_off":
			social.guild_relation(p, cmd)
		"friend":
			social.add_friend(p.character_name)
		"follow":
			# CommandFollow -> g_iFollowCharacter
			_follow_target = p
			_follow_timer = 0.0
			_cmd_msg("Đang đi theo %s." % p.character_name, Color(1, 1, 1))
		"duel":
			social.request_duel(p)
		"special":
			# COMMAND_SPECIAL: đóng Command Window, mở danh sách lệnh chat
			chat_command_window.open_for(p.character_name)
			_bring_modal_to_front(chat_command_window)
		"inspect":
			view_player_equipment(p)

# ---- hệ thống xã hội + cửa sổ
const MuSocialRes = preload("res://src/social/MuSocial.gd")
const RavenCommandBarRes = preload("res://src/ui/RavenCommandBar.gd")
var raven_bar = null

## Gọi khi đeo / tháo Quạ Tinh hoặc lệnh của quạ đổi (về lệnh cơ bản khi mục tiêu chết)
func on_raven_command_changed() -> void:
	if raven_bar:
		raven_bar.refresh()
const PartyWindowRes = preload("res://src/ui/PartyWindow.gd")
const PartyListWidgetRes = preload("res://src/ui/PartyListWidget.gd")
const GuildWindowRes = preload("res://src/ui/GuildWindow.gd")
const FriendWindowRes = preload("res://src/ui/FriendWindow.gd")
const DuelScoreWidgetRes = preload("res://src/ui/DuelScoreWidget.gd")
const ChatCommandWindowRes = preload("res://src/ui/ChatCommandWindow.gd")
var social = null
var party_window = null
var party_list_widget = null
var guild_window = null
var friend_window = null
var duel_score_widget = null
var chat_command_window = null

func _build_social() -> void:
	social = MuSocialRes.new()
	social.name = "MuSocial"
	add_child(social)
	if player_node:
		social.setup(player_node)
	party_window = PartyWindowRes.new()
	add_child(party_window)
	party_window.setup(social)
	party_list_widget = PartyListWidgetRes.new()
	party_list_widget.position = Vector2(10, 150)
	party_list_widget.z_index = 4
	add_child(party_list_widget)
	party_list_widget.setup(social)
	guild_window = GuildWindowRes.new()
	add_child(guild_window)
	guild_window.setup(social)
	friend_window = FriendWindowRes.new()
	add_child(friend_window)
	friend_window.setup(social)
	duel_score_widget = DuelScoreWidgetRes.new()
	duel_score_widget.z_index = 6
	add_child(duel_score_widget)
	duel_score_widget.setup(social)
	chat_command_window = ChatCommandWindowRes.new()
	add_child(chat_command_window)

func toggle_party_window() -> void:
	party_window.toggle()
	if party_window.visible:
		_bring_modal_to_front(party_window)

func toggle_guild_window() -> void:
	guild_window.toggle()
	if guild_window.visible:
		_bring_modal_to_front(guild_window)

func toggle_friend_window() -> void:
	friend_window.toggle()
	if friend_window.visible:
		_bring_modal_to_front(friend_window)

var _follow_target: MuOtherPlayer = null
var _follow_timer := 0.0

func cancel_follow() -> void:
	_follow_target = null
	if social:
		social.duel_attacking = false

func _later(sec: float, cb: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(cb)

func _cmd_msg(text: String, col: Color = Color(1.0, 0.45, 0.35)) -> void:
	if chat_window and chat_window.has_method("add_system_message"):
		chat_window.add_system_message("[color=#%s]%s[/color]" % [col.to_html(false), text])
	show_pickup_notification(text, col)

func view_player_equipment(p: MuOtherPlayer) -> void:
	if equip_view_window == null or p == null or not is_instance_valid(p):
		return
	equip_view_window.open_for(p)
	_bring_modal_to_front(equip_view_window)

## Giao dịch: đối phương phải đứng cạnh Hero (|dx|, |dy| <= 1 như ZzzInterface.cpp) -> đi tới trước rồi mới gửi yêu cầu
func request_trade_with(p: MuOtherPlayer) -> void:
	if player_node == null or p == null or not is_instance_valid(p) or trade_window == null:
		return
	if player_node.level < TradeWindowRes.TRADE_LIMIT_LEVEL:
		trade_window._sys("Bạn có thể dùng lệnh giao dịch từ cấp độ %d." % TradeWindowRes.TRADE_LIMIT_LEVEL, Color(1, 1, 1))
		return
	if trade_window.is_trading():
		return
	if _is_next_to(p):
		trade_window.request_trade(player_node, p)
		return
	var world = MuWorld.current
	if world == null:
		return
	var path: Array[Vector2i] = world.find_path_grid(MuWorld.world_to_grid(player_node.global_position), p.tile())
	if path.size() > 1:
		path.remove_at(path.size() - 1)
	player_node.clear_target()
	player_node.move_to_path(path)
	p.busy = true   # đứng yên chờ
	_pending_trade = p

func _is_next_to(p: MuOtherPlayer) -> bool:
	var h: Vector2i = MuWorld.world_to_grid(player_node.global_position)
	var t: Vector2i = MuWorld.world_to_grid(p.global_position)
	return absi(h.x - t.x) <= 1 and absi(h.y - t.y) <= 1

func _process(delta: float) -> void:
	_update_follow(delta)
	if _pending_trade == null:
		return
	if not is_instance_valid(_pending_trade) or player_node == null:
		_pending_trade = null
		return
	if _is_next_to(_pending_trade):
		var p := _pending_trade
		_pending_trade = null
		p.busy = false
		trade_window.request_trade(player_node, p)
	elif not player_node.is_moving and player_node.waypoints.is_empty():
		_pending_trade.busy = false
		_pending_trade = null

## Lệnh Đi theo (g_iFollowCharacter): cứ 0.4 giây tìm đường tới cạnh người được theo
func _update_follow(delta: float) -> void:
	if _follow_target == null:
		return
	if not is_instance_valid(_follow_target) or player_node == null:
		_follow_target = null
		return
	_follow_timer -= delta
	if _follow_timer > 0.0:
		return
	_follow_timer = 0.4
	if player_node.global_position.distance_to(_follow_target.global_position) <= 2.0:
		return
	var world = MuWorld.current
	if world == null:
		return
	var path: Array[Vector2i] = world.find_path_grid(MuWorld.world_to_grid(player_node.global_position), _follow_target.tile())
	if path.size() > 1:
		path.remove_at(path.size() - 1)
		player_node.move_to_path(path)

## Thỉnh thoảng một người chơi đứng gần sẽ mời Hero giao dịch (hộp thoại "X muốn giao dịch với bạn")
func _on_other_player_tick() -> void:
	_guild_ask_cooldown -= 1.0
	if social and social.is_guild_master() and _guild_ask_cooldown <= 0.0 and player_node:
		for p in get_tree().get_nodes_in_group("OtherPlayer"):
			if p.wants_guild and p.guild_name == "" and not p.busy and p.global_position.distance_to(player_node.global_position) < 8.0:
				_guild_ask_cooldown = 90.0
				MuMsgBox.open(self, [[p.character_name, Color.WHITE, true], ["muốn gia nhập guild của bạn."]],
					social.accept_guild_member.bind(p))
				break
	_incoming_cooldown -= 1.0
	if _incoming_cooldown > 0.0 or player_node == null or trade_window == null or trade_window.is_trading():
		return
	if player_node.level < TradeWindowRes.TRADE_LIMIT_LEVEL or player_node.is_moving:
		return
	for p in get_tree().get_nodes_in_group("OtherPlayer"):
		if p.busy or p.global_position.distance_to(player_node.global_position) > 3.0:
			continue
		if randf() < 0.25 and trade_window.receive_trade_request(player_node, p):
			_incoming_cooldown = randf_range(120.0, 240.0)
			return
