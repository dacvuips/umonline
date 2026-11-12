extends Control
class_name MuEventScheduleWindow

## Bảng Lịch Trình Sự Kiện MU Online (Event Schedule Window)
## Hiển thị toàn bộ lịch trình, trạng thái mở cổng, thời gian đếm ngược chính xác theo giờ game gốc
## Hỗ trợ kéo thả (Draggable), nút đóng chuẩn Season 6 và chức năng kích hoạt test nhanh sự kiện

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuEventManagerRes = preload("res://src/events/MuEventManager.gd")

const S := 1.2
const W := 380.0
const H := 460.0

var player: MuPlayer = null
var user_has_dragged: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 5.0

var lbl_clock: Label
var scroll_container: ScrollContainer
var cards_vbox: VBoxContainer
var _card_nodes: Dictionary = {}
var _refresh_timer: float = 0.0

func _ready() -> void:
	visible = false
	add_to_group("MuEventScheduleWindow")
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S

	# 1. Khung NewUI nguyên bản của MU Online
	MuUiSkinRes.build_frame(self, "Lịch Trình Sự Kiện", W, H, "newui_item_back01")

	# 2. Vùng header kéo thả cửa sổ
	_setup_drag_header()

	# 3. Nút đóng cửa sổ ở góc trên phải (ẩn hình ảnh chữ X nhưng vẫn nhận click đóng)
	MuUiSkinRes.close_button(self, W, close, true)

	# 4. Đồng hồ Server thời gian thực
	lbl_clock = MuUiSkinRes.font_label("🕒 Giờ Máy Chủ: 00:00:00", 12, Color(0.4, 0.95, 1.0))
	lbl_clock.position = Vector2(15, 38) * S
	lbl_clock.size = Vector2(W - 30, 20) * S
	lbl_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl_clock)

	# 5. Khung cuộn danh sách các sự kiện
	_setup_scroll_list()

	_place()
	get_viewport().size_changed.connect(_place)

func _setup_drag_header() -> void:
	var drag_bar := Control.new()
	drag_bar.name = "DragHeader"
	drag_bar.position = Vector2.ZERO
	drag_bar.size = Vector2(W - 30.0, 38.0) * S
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_bar.gui_input.connect(_on_drag_header_input)
	add_child(drag_bar)
	move_child(drag_bar, 0)

func _on_drag_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			user_has_dragged = false
			_place()
			return
		_is_dragging = event.pressed
		_drag_start_pos = get_global_mouse_position()
		_drag_offset = get_global_mouse_position() - global_position
		if event.pressed:
			move_to_front()
	elif event is InputEventMouseMotion and _is_dragging:
		if not user_has_dragged:
			if (get_global_mouse_position() - _drag_start_pos).length() < DRAG_THRESHOLD:
				return
			user_has_dragged = true
		var vs := get_viewport_rect().size
		var np = get_global_mouse_position() - _drag_offset
		global_position = Vector2(clampf(np.x, 0.0, vs.x - size.x), clampf(np.y, 0.0, vs.y - size.y))

func _place() -> void:
	if user_has_dragged:
		return
	var vs := get_viewport_rect().size
	position = Vector2(floorf((vs.x - size.x) * 0.5), floorf((vs.y - size.y) * 0.5))

func _setup_scroll_list() -> void:
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(12, 62) * S
	scroll_container.size = Vector2(W - 24, H - 76) * S
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll_container)

	cards_vbox = VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", int(8 * S))
	scroll_container.add_child(cards_vbox)

func _process(delta: float) -> void:
	if not visible:
		return

	_refresh_timer += delta
	if _refresh_timer >= 1.0:
		_refresh_timer = 0.0
		_update_ui()

func open_window(p_player: MuPlayer = null) -> void:
	if p_player:
		player = p_player
	_place()
	visible = true
	move_to_front()
	_update_ui(true)
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func close() -> void:
	visible = false
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func toggle_window(p_player: MuPlayer = null) -> void:
	if visible:
		close()
	else:
		open_window(p_player)

## Cập nhật toàn bộ danh sách thẻ sự kiện
func _update_ui(force_rebuild: bool = false) -> void:
	var dt := Time.get_datetime_dict_from_system()
	if lbl_clock:
		lbl_clock.text = "🕒 Giờ Máy Chủ: %02d:%02d:%02d  (Thời Gian Thực Webzen)" % [int(dt.hour), int(dt.minute), int(dt.second)]

	var mgr = MuEventManager.instance
	if not mgr:
		return

	var events_list: Array[Dictionary] = mgr.get_all_events_status()

	if force_rebuild or cards_vbox.get_child_count() != events_list.size():
		for c in cards_vbox.get_children():
			c.queue_free()
		_card_nodes.clear()

		for ev in events_list:
			_build_card_node(ev)
	else:
		# Cập nhật nội dung động mà không giật scroll
		for ev in events_list:
			var eid: String = ev["id"]
			if _card_nodes.has(eid):
				_update_card_node(_card_nodes[eid], ev)

func _build_card_node(ev: Dictionary) -> void:
	var eid: String = ev["id"]
	var card := PanelContainer.new()
	card.name = "Card_" + eid
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	sb.border_color = Color(0.45, 0.38, 0.25, 0.8)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	# 1. Hàng tiêu đề & Trạng thái
	var row_top := HBoxContainer.new()
	row_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(row_top)

	var title_lbl := Label.new()
	title_lbl.text = "%s %s" % [ev["icon"], ev["short_name"]]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_top.add_child(title_lbl)

	var badge_lbl := Label.new()
	badge_lbl.name = "BadgeLabel"
	badge_lbl.add_theme_font_size_override("font_size", 12)
	row_top.add_child(badge_lbl)

	# 2. Hàng mô tả yêu cầu
	var req_lbl := Label.new()
	req_lbl.name = "ReqLabel"
	req_lbl.text = "🎟️ %s\n📍 NPC: %s (%s)" % [ev["item_req"], ev["npc"], ev["level_req"]]
	req_lbl.add_theme_font_size_override("font_size", 10)
	req_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(req_lbl)

	# 3. Hàng nút chức năng (Tham Gia / Test)
	var row_btn := HBoxContainer.new()
	row_btn.add_theme_constant_override("separation", 6)
	vb.add_child(row_btn)

	# Nút tham gia / mở cửa sổ
	var btn_action := Button.new()
	btn_action.name = "BtnAction"
	btn_action.custom_minimum_size = Vector2(100, 24)
	btn_action.add_theme_font_size_override("font_size", 11)
	if eid == "devil_square":
		btn_action.text = "😈 Vào Devil Square"
		btn_action.pressed.connect(func(): _on_enter_devil_square())
	else:
		btn_action.text = "📍 Vị Trí / NPC"
		btn_action.pressed.connect(func(): _on_teleport_or_info(ev))
	row_btn.add_child(btn_action)

	# Nút kích hoạt nhanh GM (Test Event)
	var btn_test := Button.new()
	btn_test.text = "⚡ Kích Hoạt Test"
	btn_test.custom_minimum_size = Vector2(90, 24)
	btn_test.add_theme_font_size_override("font_size", 11)
	btn_test.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	btn_test.tooltip_text = "Lệnh GM: Mở cổng sự kiện ngay lập tức để test thông báo hệ thống"
	btn_test.pressed.connect(func():
		var mgr = MuEventManager.instance
		if mgr:
			mgr.force_start_event(eid, 300)
			_update_ui(true)
	)
	row_btn.add_child(btn_test)

	cards_vbox.add_child(card)
	_card_nodes[eid] = card
	_update_card_node(card, ev)

func _update_card_node(card: PanelContainer, ev: Dictionary) -> void:
	var badge: Label = card.find_child("BadgeLabel", true, false)
	var req: Label = card.find_child("ReqLabel", true, false)
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel")

	var state: String = ev.get("state", "waiting")
	var time_str: String = ev.get("time_str", "00:00")
	var next_time: String = ev.get("next_time_str", "")

	if badge:
		if state == "open":
			badge.text = "🟢 ĐANG MỞ [%s]" % time_str
			badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			if sb: sb.border_color = Color(0.2, 0.9, 0.4, 0.9)
		elif state == "running":
			badge.text = "🟡 DIỄN RA [%s]" % time_str
			badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
			if sb: sb.border_color = Color(0.9, 0.7, 0.2, 0.8)
		else:
			badge.text = "⚪ Chờ: %s (Mở: %s)" % [time_str, next_time]
			badge.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
			if sb: sb.border_color = Color(0.35, 0.32, 0.25, 0.7)

func _on_enter_devil_square() -> void:
	close()
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.devil_square_window:
		hud.devil_square_window.open_window(player, null)

func _on_teleport_or_info(ev: Dictionary) -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	var s_name: String = ev["short_name"]
	var npc: String = ev["npc"]
	var chat = get_tree().get_first_node_in_group("ChatWindow") if get_tree() else null
	if chat and chat.has_method("add_system_message"):
		chat.add_system_message("[color=gold][Sự Kiện %s][/color] Hãy đến gặp [color=cyan]%s[/color] để tham gia." % [s_name, npc])
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("%s: Hãy đến %s" % [s_name, npc], Color(1.0, 0.85, 0.3))
