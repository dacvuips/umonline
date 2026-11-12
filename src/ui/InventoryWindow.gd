extends Control
class_name InventoryWindow

## Túi đồ của nhân vật giống CNewUIMyInventory (MU Season 6):
##   ô trang bị (mũ, áo, quần, găng, giày, vũ khí trái/phải, cánh) + lưới 8x8 + Zen
## Nhặt / đặt đồ bằng chuột trái như MU ; chuột phải: dùng thuốc hoặc mặc nhanh.
## Khi đang mở cửa hàng NPC: cầm đồ thả vào rương NPC = bán.

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuItemGridRes = preload("res://src/ui/MuItemGrid.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const MuJewelUseRes = preload("res://src/mu/MuJewelUse.gd")

const S := 1.5
const W := 190.0
const H := 429.0
# Ô trang bị (đơn vị MU, góc trên-trái, kích thước) theo CNewUIMyInventory
const EQUIP := {
	"helper": [15, 44, 46, 46, "newui_item_fairy"],
	"helm": [75, 44, 46, 46, "newui_item_cap"],
	"wings": [120, 44, 61, 46, "newui_item_wing"],
	"right": [15, 87, 46, 66, "newui_item_weapon(r)"],
	"armor": [75, 87, 46, 66, "newui_item_upper"],
	"left": [135, 87, 46, 66, "newui_item_weapon(l)"],
	"gloves": [15, 150, 46, 46, "newui_item_gloves"],
	"pants": [75, 150, 46, 46, "newui_item_lower"],
	"boots": [135, 150, 46, 46, "newui_item_boots"],
	"amulet": [54, 87, 28, 28, "newui_item_necklace"],
	"ring_right": [54, 150, 28, 28, "newui_item_ring"],
	"ring_left": [114, 150, 28, 28, "newui_item_ring"],
}

var player: MuPlayer = null
var grid = null
var _zen_label: Label
var _slots: Dictionary = {}
var _ui = null
var _icon_layer: Control = null
var _hover_slot := ""
var user_has_dragged: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 5.0

func _ready() -> void:
	visible = false
	for c in get_children():
		c.queue_free()
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = W * S
	offset_bottom = H * S
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S
	MuUiSkinRes.build_frame(self, "Inventory")
	_setup_drag_header()
	# Nút đóng cửa sổ ở góc trên phải (ẩn hình ảnh nhưng vẫn nhận click đóng)
	MuUiSkinRes.close_button(self, W, func(): visible = false, true)
	for slot in EQUIP:
		var d: Array = EQUIP[slot]
		var b := Control.new()
		b.position = Vector2(d[0], d[1]) * S
		b.size = Vector2(d[2], d[3]) * S
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.gui_input.connect(_on_slot_input.bind(slot))
		b.mouse_entered.connect(_on_slot_hover.bind(slot, true))
		b.mouse_exited.connect(_on_slot_hover.bind(slot, false))
		b.draw.connect(_draw_slot.bind(b, slot))
		add_child(b)
		_slots[slot] = b
	grid = MuItemGridRes.new()
	grid.setup(8, 8, 20.0 * S)
	grid.position = Vector2(15, 208) * S
	grid.cell_clicked.connect(_on_cell)
	grid.released_at.connect(_on_grid_released)
	grid.hover_changed.connect(_on_hover)
	add_child(grid)
	# ảnh đồ trang bị vẽ trên một lớp riêng phía trên mọi khung ô -> đồ to tràn ra ngoài khung không bị ô bên cạnh đè
	_icon_layer = Control.new()
	_icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_layer.size = size
	_icon_layer.draw.connect(_draw_equip_icons)
	add_child(_icon_layer)

	# Thanh hiển thị Zen (y = 364 * S)
	var money := TextureRect.new()
	money.texture = MuUiSkinRes.tex("newui_item_money")
	money.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money.position = Vector2(11, 364) * S
	money.size = Vector2(170, 26) * S
	money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(money)
	_zen_label = MuUiSkinRes.font_label("0", 13, Color(1, 0.9, 0.55))
	_zen_label.position = Vector2(40, 369) * S
	_zen_label.size = Vector2(135, 16) * S
	_zen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_zen_label)

	# 4 nút chân bảng Inventory (y = 391 * S) chuẩn Season 6
	_setup_bottom_buttons()

	_place()
	get_viewport().size_changed.connect(_place)

func _setup_drag_header() -> void:
	var drag_bar := Control.new()
	drag_bar.name = "DragHeader"
	drag_bar.position = Vector2.ZERO
	drag_bar.size = Vector2(W - 30.0, 42.0) * S
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_bar.gui_input.connect(_on_drag_header_input)
	add_child(drag_bar)
	move_child(drag_bar, 0)

func _on_drag_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			user_has_dragged = false
			_notify_arrange()
			return
		_is_dragging = event.pressed
		_drag_start_pos = get_global_mouse_position()
		_drag_offset = get_global_mouse_position() - global_position
		if event.pressed:
			_bring_to_front()
	elif event is InputEventMouseMotion and _is_dragging:
		if not user_has_dragged:
			if (get_global_mouse_position() - _drag_start_pos).length() < DRAG_THRESHOLD:
				return
			user_has_dragged = true
		var vs := get_viewport_rect().size
		var np = get_global_mouse_position() - _drag_offset
		global_position = Vector2(clampf(np.x, 0.0, vs.x - size.x), clampf(np.y, 0.0, vs.y - size.y))

func _bring_to_front() -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.has_method("_bring_modal_to_front"):
		hud._bring_modal_to_front(self)
	else:
		move_to_front()

func _notify_arrange() -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.has_method("arrange_dock_windows"):
		hud.arrange_dock_windows()
	else:
		var vs := get_viewport_rect().size
		position = Vector2(vs.x - W * S, floorf(maxf(0.0, (vs.y - H * S) * 0.5)))

func _setup_bottom_buttons() -> void:
	var btn_exit = MuUiSkinRes.make_btn_2state("newui_exit_00", 36, 29, func(): visible = false)
	btn_exit.position = Vector2(13, 391) * S
	btn_exit.size = Vector2(36, 29) * S
	btn_exit.tooltip_text = "Đóng túi đồ (I/V)"
	add_child(btn_exit)

	var btn_repair = MuUiSkinRes.make_btn_2state("newui_repair_00", 36, 29, _on_repair_clicked)
	btn_repair.position = Vector2(50, 391) * S
	btn_repair.size = Vector2(36, 29) * S
	btn_repair.tooltip_text = "Sửa chữa trang bị (Repair)"
	add_child(btn_repair)

	var btn_myshop = MuUiSkinRes.make_btn_2state("newui_Bt_openshop", 36, 29, _on_myshop_clicked)
	btn_myshop.position = Vector2(87, 391) * S
	btn_myshop.size = Vector2(36, 29) * S
	btn_myshop.tooltip_text = "Cửa Hàng Cá Nhân (Personal Shop - P)"
	add_child(btn_myshop)

	var btn_expand = MuUiSkinRes.make_btn_2state("newui_expansion_btn", 36, 29, _on_expand_clicked)
	btn_expand.position = Vector2(124, 391) * S
	btn_expand.size = Vector2(36, 29) * S
	btn_expand.tooltip_text = "Mở rộng túi đồ (Inventory Extension)"
	add_child(btn_expand)

func _on_repair_clicked() -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Đã phục hồi độ bền toàn bộ trang bị", Color(0.4, 1.0, 0.4))
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_myshop_clicked() -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Cửa Hàng Cá Nhân - Nhấn phím P", Color(1.0, 0.85, 0.4))
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_expand_clicked() -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Túi đồ mở rộng (Inventory Extension)", Color(0.4, 0.8, 1.0))
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _place() -> void:
	if user_has_dragged:
		return
	_notify_arrange()

func _get_ui():
	if _ui == null or not is_instance_valid(_ui):
		var tree := get_tree()
		if tree:
			_ui = MuItemUiRes.get_ui(tree)
		if _ui == null and is_inside_tree() and get_parent():
			_ui = MuItemUiRes.new()
			_ui.name = "MuItemUi"
			get_parent().add_child(_ui)
	return _ui

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if not player.inventory_changed.is_connected(update_display):
		player.inventory_changed.connect(update_display)
	_get_ui()
	update_display()

# phím I / V do MuClassicHudBar xử lý (hud.toggle_inventory)

func update_display() -> void:
	if player == null or grid == null:
		return
	grid.set_items(player.inventory)
	_zen_label.text = MuItemsRes.format_zen(player.zen)
	for b in _slots.values():
		b.queue_redraw()

func _process(_d: float) -> void:
	if not visible or grid == null:
		return
	if _hover_slot != "" and _slots.has(_hover_slot):
		MuItemIconRes.spin(_d)
		_slots[_hover_slot].queue_redraw()
	var ui = _get_ui()
	if ui.held.is_empty():
		grid.preview_size = Vector2i.ZERO
	else:
		grid.preview_size = MuItemsRes.size_of(ui.held)
		var hc: Vector2i = grid.hover_cell
		grid.preview_ok = player != null and player.inv_fits(hc.x, hc.y, grid.preview_size.x, grid.preview_size.y)

# ------------------------------------------------------------------ lưới túi đồ
func _on_cell(c: int, r: int, button: int) -> void:
	if player == null:
		return
	var ui = _get_ui()
	if button == MOUSE_BUTTON_RIGHT:
		if not ui.held.is_empty():
			ui.cancel_held(player)
			update_display()
			return
		var it: Dictionary = grid.item_at(c, r)
		if it.is_empty():
			return
		var tree := get_tree()
		# Đang giao dịch: chuột phải = chuyển nhanh vào khung giao dịch của mình (CTrade::ProcessMyInvenItemAutoMove)
		var trade = tree.get_first_node_in_group("MuTradeWindow") if tree else null
		if trade and trade.is_trading():
			trade.add_from_inventory(it)
			update_display()
			return
		var mix = tree.get_first_node_in_group("MuChaosMixWindow") if tree else null
		if mix and mix.visible:
			player.inv_remove(it)
			if mix.add_item(it):
				if MuAudioManager:
					MuAudioManager.play_item_pickup()
			else:
				player.inv_add(it)
				mix.show_msg("Máy Chaos đã đầy!", Color(1.0, 0.3, 0.2))
			update_display()
			return
		var vault = tree.get_first_node_in_group("MuVaultWindow") if tree else null
		if vault and vault.visible:
			if vault.is_locked():
				vault.show_msg("Rương đồ đang bị khóa bảo vệ! Vui lòng mở khóa trước.", Color(1.0, 0.4, 0.3))
				return
			player.inv_remove(it)
			if player.vault_add(it):
				if MuAudioManager:
					MuAudioManager.play_item_pickup()
				vault.update_display()
				update_display()
				vault.show_msg("Đã cất %s vào rương!" % MuItemsRes.display_name(it), Color(0.4, 1.0, 0.5))
			else:
				player.inv_add(it)
				vault.show_msg("Rương chứa đồ đã đầy, không thể cất thêm!", Color(1.0, 0.3, 0.2))
			return
		if player.use_item(it):
			return
		var slot: String = MuItemsRes.equip_slot(it)
		if slot != "":
			if slot == "ring":
				if player.equipment.has("ring_right") and not player.equipment.has("ring_left"):
					slot = "ring_left"
				else:
					slot = "ring_right"
			elif slot == "right" and player.equipment.has("right") and not player.equipment.has("left") and int(it.get("group", 0)) <= 5:
				slot = "left"
			player.inv_remove(it)
			_equip(slot, it)
		return
	if ui.held.is_empty():
		var it2: Dictionary = grid.item_at(c, r)
		if it2.is_empty():
			return
		player.inv_remove(it2)
		ui.hold(it2, "inv")
		ui.hide_tip()
	else:
		# đang cầm ngọc và bấm vào 1 món đồ -> đập ngọc vào đồ đó (Bless / Soul / Life)
		var target: Dictionary = grid.item_at(c, r)
		if not target.is_empty() and MuJewelUseRes.is_usable_jewel(ui.held):
			_use_jewel_on(ui, target, false)
			return
		if player.inv_place(ui.held, c, r):
			ui.drop_held()
	update_display()

## Đập ngọc đang cầm vào `target` (đồ trong túi hoặc đồ đang mặc)
func _use_jewel_on(ui, target: Dictionary, equipped: bool) -> void:
	var res: Dictionary = MuJewelUseRes.apply(ui.held, target)
	if not bool(res["handled"]):
		return
	if bool(res["consumed"]):
		ui.drop_held()           # ngọc biến mất
		if MuAudioManager:
			MuAudioManager.play_jewel_drop()   # client gốc: ReceiveModifyItem phát SOUND_JEWEL01 (eGem.wav) dù thành công hay không
		if equipped:
			player.rebuild_model()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(str(res["msg"]), res["color"])
	update_display()

## Kéo thả: đồ / ngọc đang cầm được nhả ở ô túi khác hoặc ô trang bị (đập ngọc vào đồ đang mặc, mặc đồ...)
func _on_grid_released(gpos: Vector2, cell: Vector2i, inside: bool) -> void:
	if player == null:
		return
	var ui = _get_ui()
	if ui.held.is_empty():
		return
	if inside:
		_on_cell(cell.x, cell.y, MOUSE_BUTTON_LEFT)
		return
	var trade = get_tree().get_first_node_in_group("MuTradeWindow")
	if trade and trade.drop_held_at_global(gpos):
		update_display()
		return
	for slot in _slots:
		var b: Control = _slots[slot]
		if b.get_global_rect().has_point(gpos):
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			_on_slot_input(ev, slot)
			return

func _on_hover(it: Dictionary) -> void:
	var ui = _get_ui()
	if it.is_empty():
		ui.hide_tip()
		return
	var tree := get_tree()
	var shop = tree.get_first_node_in_group("MuShopWindow") if tree else null
	if shop and shop.visible:
		ui.show_tip(MuItemsRes.tooltip(it, "Giá bán", MuItemsRes.sell_price(it)))
	else:
		ui.show_tip(MuItemsRes.tooltip(it))

# ------------------------------------------------------------------ ô trang bị
func _equip(slot: String, it: Dictionary) -> void:
	var old: Dictionary = player.equipment.get(slot, {})
	player.equipment[slot] = it
	if not old.is_empty() and not player.inv_add(old):
		_get_ui().hold(old, "inv")
	player.rebuild_model()
	player.inventory_changed.emit()
	update_display()

func _on_slot_input(event: InputEvent, slot: String) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or player == null:
		return
	var ui = _get_ui()
	var cur: Dictionary = player.equipment.get(slot, {})
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if not ui.held.is_empty():
			ui.cancel_held(player)
			update_display()
			return
		# chuột phải: tháo vào túi
		if not cur.is_empty() and player.inv_add(cur):
			player.equipment.erase(slot)
			player.rebuild_model()
			player.inventory_changed.emit()
			update_display()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if ui.held.is_empty():
		if cur.is_empty():
			return
		player.equipment.erase(slot)
		player.rebuild_model()
		player.inventory_changed.emit()
		ui.hold(cur, "equip:" + slot)
		ui.hide_tip()
	else:
		if not cur.is_empty() and MuJewelUseRes.is_usable_jewel(ui.held):
			_use_jewel_on(ui, cur, true)
			return
		if not MuItemsRes.can_equip_in_slot(ui.held, slot):
			return
		var it: Dictionary = ui.drop_held()
		player.equipment[slot] = it
		if not cur.is_empty():
			ui.hold(cur, "equip:" + slot)
		player.rebuild_model()
		player.inventory_changed.emit()
	update_display()

func _on_slot_hover(slot: String, inside: bool) -> void:
	if inside:
		_hover_slot = slot
	elif _hover_slot == slot:
		_hover_slot = ""
		MuItemIconRes.stop_live()
		if _slots.has(slot):
			_slots[slot].queue_redraw()
	var ui = _get_ui()
	if not inside or player == null:
		ui.hide_tip()
		return
	var cur: Dictionary = player.equipment.get(slot, {})
	if not cur.is_empty():
		var it := MuItemsRes.make(int(cur.get("group", 0)), int(cur.get("number", 0)), int(cur.get("level", 0)), cur)
		ui.show_tip(MuItemsRes.tooltip(it))

func _draw_slot(b: Control, slot: String) -> void:
	var d: Array = EQUIP[slot]
	var rc := Rect2(Vector2.ZERO, b.size)
	var t := MuUiSkinRes.tex(str(d[4]))
	if t:
		b.draw_texture_rect(t, rc, false)
	else:
		b.draw_rect(rc, Color(0.1, 0.08, 0.06, 0.9))
		b.draw_rect(rc, Color(0.4, 0.33, 0.2), false, 1.0)
	if _icon_layer != null:
		_icon_layer.queue_redraw()

func _draw_equip_icons() -> void:
	if player == null:
		return
	for slot in _slots:
		_draw_equip_icon(_icon_layer, _slots[slot], slot)

func _draw_equip_icon(layer: Control, b: Control, slot: String) -> void:
	var rc := Rect2(b.position, b.size)
	var cur: Dictionary = player.equipment.get(slot, {})
	if cur.is_empty():
		return
	# nền cảnh báo độ bền (my_inventory.rcss: .equip-slot-item, lề trái 1, phải 3, dưới 4)
	var dst: int = MuItemsRes.durability_state(cur)
	if dst != 0:
		layer.draw_rect(Rect2(rc.position + Vector2(1, 0) * S, rc.size - Vector2(4, 4) * S), MuItemsRes.durability_tint(dst, 64.0 / 255.0))
	var icon: Texture2D = MuItemIconRes.live_icon(get_tree(), cur) if slot == _hover_slot else MuItemIconRes.icon(get_tree(), cur)
	if icon:
		# MU: đồ trong ô trang bị cùng tỉ lệ với túi đồ (20 x 20 mỗi ô) — không phóng to cho đầy
		var sz: Vector2i = MuItemsRes.size_of(cur)
		var isz := Vector2(sz) * 20.0 * S
		# RenderItem3D với hộp = ô trang bị: gốc model đặt tại anchor của Ô TRANG BỊ (cùng tỉ lệ thế giới)
		var an: Vector2 = MuItemIconRes.anchor_of(int(cur.get("group", 0)), int(cur.get("number", 0)))
		layer.draw_texture_rect(icon, MuItemIconRes.overflow_rect(Rect2(rc.position + rc.size * an - isz * an, isz), sz), false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		if is_inside_tree() and get_tree() != null:
			var ui = _get_ui()
			if ui and not ui.held.is_empty():
				ui.cancel_held(player)
				update_display()

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		_bring_to_front()
		var ui = _get_ui()
		if ui and not ui.held.is_empty():
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				ui.cancel_held(player)
				update_display()
	accept_event()
