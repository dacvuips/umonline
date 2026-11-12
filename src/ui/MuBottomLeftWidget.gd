extends Control
class_name MuBottomLeftWidget

## Cụm Phím Tiện Ích Dưới Trái: 4 Ô Vật Phẩm Nhanh (Quick Slots) & Cần Điều Khiển (Virtual Joystick)
## Theo đúng yêu cầu thiết kế:
## - 4 ô khung kính mờ bán trong suốt (như khung chat), viền kim loại mảnh bo góc
## - KHÔNG TỰ ĐỘNG GẮN: Ban đầu để trống hoàn toàn, người chơi tự kéo thả (hoặc cầm trên chuột thả vào)
## - Khi đã gán: Hiển thị hình ảnh bình máu / mana / thuốc thật của MU Online và số lượng thực tế trong túi
## - Chạm / Click trái: Sử dụng 1 bình, trừ số lượng trong túi đồ
## - Click phải: Gỡ gán khỏi ô phím tắt (trở lại ô trống)
## - Cần điều khiển ảo (Virtual Joystick) 360 độ siêu nhạy, hoa văn vàng đồng thanh lịch

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")

@export var player: MuPlayer = null

# Lưu cấu hình 4 ô phím tắt (không tự gán, người chơi tự kéo thả vào)
static var saved_quick_slots: Array[Dictionary] = [{}, {}, {}, {}]
var assigned_slots: Array[Dictionary] = [{}, {}, {}, {}]

# Danh sách 4 ô UI
var slots: Array[Dictionary] = []

var joystick_control: Control
var joystick_base_pos: Vector2
var joystick_handle_pos: Vector2 = Vector2.ZERO
var joystick_radius: float = 75.0
var handle_radius: float = 26.0
var is_joystick_dragging: bool = false
var joystick_touch_id: int = -1
var joystick_direction: Vector2 = Vector2.ZERO

var loaded_textures: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(265, 300)
	size = Vector2(265, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preload_textures()
	
	# Đồng bộ cấu hình đã gán trước đó (nếu có, mặc định là trống)
	assigned_slots.clear()
	for i in range(4):
		if i < saved_quick_slots.size():
			assigned_slots.append(saved_quick_slots[i].duplicate())
		else:
			assigned_slots.append({})
			
	_build_ui()
	if player:
		setup(player)

func _preload_textures() -> void:
	var paths = [
		"res://assets/mu/icons/14_001.png",
		"res://assets/mu/icons/14_002.png",
		"res://assets/mu/icons/14_003.png",
		"res://assets/mu/icons/14_004.png",
		"res://assets/mu/icons/14_005.png",
		"res://assets/mu/icons/14_006.png",
		"res://assets/mu/icons/14_008.png",
		"res://assets/mu/icons/14_009.png",
		"res://assets/mu/icons/14_010.png",
		"res://assets/mu/icons/14_035.png",
		"res://assets/textures/ui/mobile_skills/potion_hp.png",
		"res://assets/textures/ui/mobile_skills/potion_mp.png"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			loaded_textures[p] = load(p)

func _get_texture(path: String) -> Texture2D:
	if loaded_textures.has(path):
		return loaded_textures[path]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			loaded_textures[path] = tex
			return tex
	return null

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player:
		player.virtual_joystick = self
		if player.has_signal("inventory_changed") and not player.inventory_changed.is_connected(update_item_counts):
			player.inventory_changed.connect(update_item_counts)
	update_item_counts()

func _build_ui() -> void:
	# 1. Hàng 4 ô Phím Nhanh (Quick Slots Row)
	# Đẩy cao lên trên và dịch sang phải xíu để thẳng hàng với Joystick
	var slot_size = 52.0
	var separation = 8.0
	var total_slots_width = 4.0 * slot_size + 3.0 * separation # 232px
	var start_x = (size.x - total_slots_width) * 0.5 + 8.0

	var slots_row = HBoxContainer.new()
	slots_row.name = "QuickSlotsRow"
	slots_row.position = Vector2(start_x, 6)
	slots_row.add_theme_constant_override("separation", int(separation))
	add_child(slots_row)

	# Viền kim loại mảnh bán trong suốt thanh thoát
	var frame_border = Color(0.72, 0.76, 0.70, 0.75)

	slots.clear()
	for i in range(4):
		var slot_dict = _create_slot_box(slot_size, frame_border, i)
		slots.append(slot_dict)
		slots_row.add_child(slot_dict["container"])

	# 2. Cần điều khiển ảo (Virtual Joystick) bên dưới
	# Đẩy cao lên và lệch sang phải xíu cho ngón tay cái thao tác thoải mái
	var joy_w = 200.0
	var joy_h = 180.0
	joystick_control = Control.new()
	joystick_control.name = "JoystickControl"
	joystick_control.position = Vector2((size.x - joy_w) * 0.5 + 12.0, 98.0)
	joystick_control.custom_minimum_size = Vector2(joy_w, joy_h)
	joystick_control.size = Vector2(joy_w, joy_h)
	joystick_control.mouse_filter = Control.MOUSE_FILTER_PASS
	joystick_control.draw.connect(_on_draw_joystick)
	joystick_control.gui_input.connect(_on_joystick_gui_input)
	add_child(joystick_control)
	joystick_base_pos = Vector2(joy_w * 0.5, 90.0)

	update_item_counts()

func _create_slot_box(slot_size: float, border_color: Color, slot_index: int) -> Dictionary:
	# Dùng Panel trực tiếp với StyleBoxFlat bán trong suốt giống khung nhập tin chat
	var container = Panel.new()
	container.custom_minimum_size = Vector2(slot_size, slot_size)
	container.size = Vector2(slot_size, slot_size)
	container.mouse_filter = Control.MOUSE_FILTER_PASS

	var sb = StyleBoxFlat.new()
	# Nền sẫm hơi trong suốt giống khung nhập tin chat (~45% alpha)
	sb.bg_color = Color(0.06, 0.08, 0.10, 0.45)
	# Viền mảnh 1.5px
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border_color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 1
	container.add_theme_stylebox_override("panel", sb)

	# 1. TextureRect hiển thị bình máu / bình mana thật của MU
	var trect = TextureRect.new()
	var pad = 4.0
	trect.position = Vector2(pad, pad)
	trect.size = Vector2(slot_size - pad * 2.0, slot_size - pad * 2.0)
	trect.custom_minimum_size = trect.size
	trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trect.visible = false
	container.add_child(trect)

	# 2. Chữ cái phím tắt Q, W, E, R màu trắng mờ ở góc trái phía trên (NẰM TRÊN trect nên không bị che)
	var key_names = ["Q", "W", "E", "R"]
	var lbl_key = Label.new()
	lbl_key.name = "KeyLabel"
	lbl_key.text = key_names[slot_index] if slot_index < key_names.size() else ""
	lbl_key.position = Vector2(4, 2)
	lbl_key.size = Vector2(16, 14)
	lbl_key.add_theme_font_size_override("font_size", 11)
	lbl_key.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55)) # Trắng mờ
	lbl_key.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl_key.add_theme_constant_override("outline_size", 2)
	lbl_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl_key)

	# 3. Label số lượng góc dưới phải (chỉ hiện khi có item)
	var lbl = Label.new()
	lbl.position = Vector2(4, slot_size - 18)
	lbl.size = Vector2(slot_size - 8, 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)

	# 4. Nút bấm tương tác chạm / kéo thả / click
	var btn = Button.new()
	btn.position = Vector2.ZERO
	btn.size = Vector2(slot_size, slot_size)
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(event: InputEvent): _on_slot_gui_input(event, slot_index))
	btn.mouse_entered.connect(func(): _on_slot_mouse_entered(slot_index))
	btn.mouse_exited.connect(func(): _on_slot_mouse_exited(slot_index))
	container.add_child(btn)

	return {"container": container, "trect": trect, "label": lbl, "key_label": lbl_key, "btn": btn}

# --- Xử lý Kéo Thả và Tương Tác Ô Phím Tắt ---
func _on_slot_mouse_entered(slot_idx: int) -> void:
	var ui = MuItemUiRes.get_ui(get_tree())
	if ui and not ui.held.is_empty():
		_set_slot_border_highlight(slot_idx, true)

func _on_slot_mouse_exited(slot_idx: int) -> void:
	_set_slot_border_highlight(slot_idx, false)

func _set_slot_border_highlight(slot_idx: int, highlight: bool) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	var container: Panel = slots[slot_idx]["container"]
	var sb = container.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var nsb = sb.duplicate() as StyleBoxFlat
		if highlight:
			nsb.border_color = Color(0.4, 0.85, 1.0, 0.95)
			nsb.border_width_left = 2
			nsb.border_width_top = 2
			nsb.border_width_right = 2
			nsb.border_width_bottom = 2
		else:
			nsb.border_color = Color(0.72, 0.76, 0.70, 0.75)
			nsb.border_width_left = 1
			nsb.border_width_top = 1
			nsb.border_width_right = 1
			nsb.border_width_bottom = 1
		container.add_theme_stylebox_override("panel", nsb)

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	var mb = event as InputEventMouseButton
	if not mb or not mb.pressed:
		return

	var ui = MuItemUiRes.get_ui(get_tree())

	if mb.button_index == MOUSE_BUTTON_LEFT:
		# TRƯỜNG HỢP 1: Đang cầm một món đồ trên chuột -> KÉO THẢ VÀO Ô!
		if ui and not ui.held.is_empty():
			var it: Dictionary = ui.held
			var g = int(it.get("group", -1))
			var n = int(it.get("number", -1))

			# Chỉ cho phép gán các loại Bình Máu, Mana hoặc Thuốc tiêu hao (nhóm 14)
			if g == 14:
				assigned_slots[slot_idx] = {"group": g, "number": n}
				saved_quick_slots[slot_idx] = {"group": g, "number": n}

				# Trả vật phẩm đang cầm trên chuột về lại túi đồ
				var dropped: Dictionary = ui.drop_held()
				if player:
					player.inv_add(dropped)

				if MuAudioManager:
					MuAudioManager.play_item_pickup()

				_set_slot_border_highlight(slot_idx, false)
				update_item_counts()

				var it_name = MuItemsRes.display_name(it) if MuItemsRes else "Vật phẩm"
				_notify("Đã gán %s vào ô phím tắt %d!" % [it_name, slot_idx + 1])
				accept_event()
				return
			else:
				_notify("Chỉ có thể gán các loại Bình Máu, Mana hoặc Thuốc tiêu hao (nhóm 14)!")
				accept_event()
				return

		# TRƯỜNG HỢP 2: Không cầm đồ -> SỬ DỤNG VẬT PHẨM ĐÃ GÁN!
		var assigned: Dictionary = assigned_slots[slot_idx]
		if not assigned.is_empty():
			_use_assigned_slot(slot_idx)
			accept_event()
			return
		else:
			_notify("Ô phím tắt %d đang trống. Mở túi đồ (I), nhấp lấy thuốc rồi thả vào đây!" % (slot_idx + 1))
			accept_event()
			return

	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		# Chuột phải: GỠ GÁN KHỎI Ô PHÍM TẮT (Trở lại ô trống)
		var assigned: Dictionary = assigned_slots[slot_idx]
		if not assigned.is_empty():
			assigned_slots[slot_idx] = {}
			saved_quick_slots[slot_idx] = {}
			if MuAudioManager:
				MuAudioManager.play_ui_click()
			update_item_counts()
			_notify("Đã gỡ phím tắt khỏi ô %d (để trống)" % (slot_idx + 1))
			accept_event()
			return

## Gán vật phẩm vào ô (hỗ trợ gọi từ drag and drop trực tiếp)
func assign_slot(slot_idx: int, item_data: Dictionary) -> void:
	if slot_idx < 0 or slot_idx >= assigned_slots.size():
		return
	var g = int(item_data.get("group", -1))
	var n = int(item_data.get("number", -1))
	if g == 14:
		assigned_slots[slot_idx] = {"group": g, "number": n}
		saved_quick_slots[slot_idx] = {"group": g, "number": n}
		update_item_counts()
		if MuAudioManager:
			MuAudioManager.play_item_pickup()

## Cập nhật trạng thái hiển thị của 4 ô vật phẩm theo đúng inventory thực tế
func update_item_counts() -> void:
	if slots.size() < 4:
		return

	for i in range(4):
		var assigned: Dictionary = assigned_slots[i] if i < assigned_slots.size() else {}
		var slot = slots[i]
		var trect: TextureRect = slot["trect"]
		var lbl: Label = slot["label"]
		var btn: Button = slot["btn"]

		# NẾU CHƯA GẮN VẬT PHẨM: ĐỂ TRỐNG HOÀN TOÀN!
		if assigned.is_empty():
			trect.texture = null
			trect.visible = false
			lbl.text = ""
			btn.tooltip_text = "Ô phím tắt %d (Trống - Kéo thả thuốc từ túi đồ vào)" % (i + 1)
			continue

		var g = int(assigned.get("group", -1))
		var n = int(assigned.get("number", -1))

		# Đếm tổng số lượng món đồ này trong inventory
		var total_count = 0
		if player and ("inventory" in player):
			for it in player.inventory:
				if it is Dictionary and int(it.get("group", -1)) == g and int(it.get("number", -1)) == n:
					total_count += int(it.get("dur", it.get("count", 1)))

		# Khi sử dụng hết (số lượng <= 0) hoặc không còn trong túi đồ: BỊ MẤT ITEM ĐÓ (trở lại ô trống)
		if total_count <= 0:
			assigned_slots[i] = {}
			saved_quick_slots[i] = {}
			trect.texture = null
			trect.visible = false
			lbl.text = ""
			btn.tooltip_text = "Ô phím tắt %d (Trống - Kéo thả thuốc từ túi đồ vào)" % (i + 1)
			continue

		# Hiển thị icon thật của món đồ từ assets/mu/icons/%02d_%03d.png
		var icon_path = "res://assets/mu/icons/%02d_%03d.png" % [g, n]
		var tex = _get_texture(icon_path)
		if not tex:
			if g == 14 and n in [1, 2, 3]:
				tex = _get_texture("res://assets/textures/ui/mobile_skills/potion_hp.png")
			elif g == 14 and n in [4, 5, 6]:
				tex = _get_texture("res://assets/textures/ui/mobile_skills/potion_mp.png")

		trect.texture = tex
		trect.visible = (tex != null)
		trect.modulate = Color(1, 1, 1, 1)

		# Hiện số lượng
		lbl.text = str(total_count)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.tooltip_text = "Phím tắt ô %d - Số lượng: %d (Chuột phải để gỡ)" % [i + 1, total_count]

func _use_assigned_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= assigned_slots.size():
		return
	var assigned: Dictionary = assigned_slots[slot_idx]
	if assigned.is_empty() or not player:
		return

	var g = int(assigned.get("group", -1))
	var n = int(assigned.get("number", -1))

	# Tìm vật phẩm thực tế trong inventory người chơi
	var found_item: Dictionary = {}
	if "inventory" in player:
		for it in player.inventory:
			if it is Dictionary and int(it.get("group", -1)) == g and int(it.get("number", -1)) == n:
				found_item = it
				break

	if found_item.is_empty():
		assigned_slots[slot_idx] = {}
		saved_quick_slots[slot_idx] = {}
		update_item_counts()
		_notify("Đã hết vật phẩm này trong túi đồ!")
		return

	# Sử dụng theo loại
	if g == 14 and n in [0, 1, 2, 3]: # Apple & HP Potions
		player.use_hp_potion()
		_consume_item_from_inv(found_item)
	elif g == 14 and n in [4, 5, 6]: # Mana Potions
		player.use_mp_potion()
		_consume_item_from_inv(found_item)
	elif g == 14 and n == 10: # Town Portal Scroll
		player.grid_x = 140
		player.grid_y = 119
		player.global_position = Vector3(140.5, player.global_position.y, -119.5)
		if player.has_signal("position_changed"):
			player.position_changed.emit(140, 119)
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		_consume_item_from_inv(found_item)
		_notify("Sử dụng Cuộn Giấy Về Thành (Town Portal)")
	else:
		if player.has_method("use_item"):
			player.use_item(found_item)
		else:
			_consume_item_from_inv(found_item)

	update_item_counts()

func _consume_item_from_inv(it: Dictionary) -> void:
	if not player or not ("inventory" in player):
		return
	var dur = int(it.get("dur", it.get("count", 1))) - 1
	if dur <= 0:
		if player.has_method("inv_remove"):
			player.inv_remove(it)
		else:
			player.inventory.erase(it)
			if player.has_signal("inventory_changed"):
				player.inventory_changed.emit()
	else:
		it["dur"] = dur
		if it.has("count"):
			it["count"] = dur
		if player.has_signal("inventory_changed"):
			player.inventory_changed.emit()

func _notify(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(msg, Color(0.7, 0.9, 1.0))
	elif hud and hud.has_method("toggle_inventory"):
		hud.toggle_inventory()

# --- Phím Tắt Bàn Phím: Q, W, E, R ---
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	# Phân biệt rõ: Nếu đang focus vào khung nhập tin chat hoặc bất kỳ ô LineEdit/TextEdit nào -> BỎ QUA HOÀN TOÀN
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner != null and (focus_owner is LineEdit or focus_owner is TextEdit):
		return

	var k = event.keycode
	if k == KEY_Q:
		_trigger_slot_by_key(0)
		get_viewport().set_input_as_handled()
	elif k == KEY_W:
		_trigger_slot_by_key(1)
		get_viewport().set_input_as_handled()
	elif k == KEY_E:
		_trigger_slot_by_key(2)
		get_viewport().set_input_as_handled()
	elif k == KEY_R:
		_trigger_slot_by_key(3)
		get_viewport().set_input_as_handled()

func _trigger_slot_by_key(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= assigned_slots.size():
		return

	_flash_slot_feedback(slot_idx)

	var assigned = assigned_slots[slot_idx]
	if not assigned.is_empty():
		_use_assigned_slot(slot_idx)
	else:
		var key_names = ["Q", "W", "E", "R"]
		var kn = key_names[slot_idx] if slot_idx < key_names.size() else str(slot_idx + 1)
		_notify("Ô phím [%s] đang trống. Mở túi đồ (I) kéo thả thuốc vào để gán!" % kn)

func _flash_slot_feedback(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	var container: Panel = slots[slot_idx]["container"]
	var sb = container.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var flash_sb = sb.duplicate() as StyleBoxFlat
		flash_sb.border_color = Color(1.0, 1.0, 1.0, 0.95)
		container.add_theme_stylebox_override("panel", flash_sb)

		var tree = get_tree()
		if tree:
			var timer = tree.create_timer(0.1)
			timer.timeout.connect(func():
				if is_instance_valid(container):
					container.add_theme_stylebox_override("panel", sb)
			)

# --- Xử lý Cần Điều Khiển (Virtual Joystick) ---
func get_direction() -> Vector2:
	if is_joystick_dragging and joystick_direction.length() > 0.08:
		return joystick_direction
	return Vector2.ZERO

func _on_draw_joystick() -> void:
	var center = joystick_base_pos
	
	# Vòng tròn mảnh bên ngoài (Subtle translucent ring)
	var ring_color = Color(0.82, 0.75, 0.68, 0.28)
	joystick_control.draw_arc(center, joystick_radius, 0.0, TAU, 64, ring_color, 1.5, true)
	
	# 4 Mũi tên hoa văn vàng đồng (Bronze Chevrons) theo 4 hướng
	var chevron_color = Color(0.72, 0.52, 0.36, 0.85)
	var angles = [-PI * 0.5, PI * 0.5, PI, 0.0] # Lên, Xuống, Trái, Phải
	for ang in angles:
		var u = Vector2(cos(ang), sin(ang))
		var v = Vector2(-u.y, u.x)
		var pts = _get_chevron_polygon(center, u, v, joystick_radius)
		joystick_control.draw_colored_polygon(pts, chevron_color)
	
	# Núm kéo (Handle) trong suốt thanh lịch
	var handle_center = center + joystick_handle_pos
	var handle_bg = Color(0.12, 0.13, 0.16, 0.45)
	var handle_outline = Color(0.68, 0.68, 0.74, 0.55)
	joystick_control.draw_circle(handle_center, handle_radius, handle_bg)
	joystick_control.draw_arc(handle_center, handle_radius, 0.0, TAU, 48, handle_outline, 1.5, true)

func _get_chevron_polygon(center: Vector2, u: Vector2, v: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# Đầu mũi tên hướng ra ngoài
	pts.append(center + u * (r - 1.0))
	
	# Cánh trái uốn cong
	var t_steps = [0.35, 0.7, 1.0]
	for t in t_steps:
		var rad = r - 1.0 - t * 13.0
		var tang = t * 10.0
		pts.append(center + u * (rad + t * 1.5) + v * tang)
		
	# Khuyết lõm cong bên trong
	var notch_steps = [0.5, 0.0, -0.5]
	for t in notch_steps:
		var rad = r - 7.5 - abs(t) * 6.5
		var tang = t * 9.5
		pts.append(center + u * rad + v * tang)
		
	# Cánh phải uốn cong trở lại đầu mũi tên
	var return_steps = [1.0, 0.7, 0.35]
	for t in return_steps:
		var rad = r - 1.0 - t * 13.0
		var tang = -t * 10.0
		pts.append(center + u * (rad + t * 1.5) + v * tang)
		
	return pts

func _on_joystick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_id == -1:
			joystick_touch_id = event.index
			is_joystick_dragging = true
			_update_joystick_handle(event.position)
			accept_event()
		elif not event.pressed and event.index == joystick_touch_id:
			_reset_joystick()
			accept_event()
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				joystick_touch_id = -1
				is_joystick_dragging = true
				_update_joystick_handle(event.position)
				accept_event()
			elif is_joystick_dragging and joystick_touch_id == -1:
				_reset_joystick()
				accept_event()

func _input(event: InputEvent) -> void:
	if not is_joystick_dragging:
		return
	if event is InputEventScreenDrag and event.index == joystick_touch_id:
		_update_joystick_handle(event.position - joystick_control.global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == joystick_touch_id and not event.pressed:
		_reset_joystick()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and joystick_touch_id == -1:
		_update_joystick_handle(event.position - joystick_control.global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and joystick_touch_id == -1:
		_reset_joystick()
		get_viewport().set_input_as_handled()

func _update_joystick_handle(pos: Vector2) -> void:
	var diff = pos - joystick_base_pos
	var dist = diff.length()
	if dist > joystick_radius:
		diff = diff.normalized() * joystick_radius
	joystick_handle_pos = diff
	joystick_direction = diff / joystick_radius
	if joystick_control:
		joystick_control.queue_redraw()

func _reset_joystick() -> void:
	is_joystick_dragging = false
	joystick_touch_id = -1
	joystick_handle_pos = Vector2.ZERO
	joystick_direction = Vector2.ZERO
	if joystick_control:
		joystick_control.queue_redraw()


