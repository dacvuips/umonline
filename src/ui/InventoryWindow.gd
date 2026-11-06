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

func _ready() -> void:
	visible = false
	for c in get_children():
		c.queue_free()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	MuUiSkinRes.build_frame(self, "Túi Đồ")
	MuUiSkinRes.close_button(self, W, func(): visible = false)
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
	grid.hover_changed.connect(_on_hover)
	add_child(grid)
	# ảnh đồ trang bị vẽ trên một lớp riêng phía trên mọi khung ô -> đồ to tràn ra ngoài khung không bị ô bên cạnh đè
	_icon_layer = Control.new()
	_icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_layer.size = size
	_icon_layer.draw.connect(_draw_equip_icons)
	add_child(_icon_layer)
	var money := TextureRect.new()
	money.texture = MuUiSkinRes.tex("newui_item_money")
	money.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money.position = Vector2(11, 376) * S
	money.size = Vector2(170, 26) * S
	money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(money)
	_zen_label = MuUiSkinRes.font_label("0", 13, Color(1, 0.9, 0.55))
	_zen_label.position = Vector2(40, 382) * S
	_zen_label.size = Vector2(135, 16) * S
	_zen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_zen_label)
	_place()
	get_viewport().size_changed.connect(_place)

func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(vs.x - W * S, maxf(0.0, (vs.y - H * S) * 0.5))

func _get_ui():
	if _ui == null or not is_instance_valid(_ui):
		_ui = MuItemUiRes.get_ui(get_tree())
		if _ui == null:
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
		var it: Dictionary = grid.item_at(c, r)
		if it.is_empty() or not ui.held.is_empty():
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
		if player.inv_place(ui.held, c, r):
			ui.drop_held()
	update_display()

func _on_hover(it: Dictionary) -> void:
	var ui = _get_ui()
	if it.is_empty():
		ui.hide_tip()
		return
	var shop = get_tree().get_first_node_in_group("MuShopWindow")
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
	update_display()

func _on_slot_input(event: InputEvent, slot: String) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or player == null:
		return
	var ui = _get_ui()
	var cur: Dictionary = player.equipment.get(slot, {})
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		# chuột phải: tháo vào túi
		if not cur.is_empty() and player.inv_add(cur):
			player.equipment.erase(slot)
			player.rebuild_model()
			update_display()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if ui.held.is_empty():
		if cur.is_empty():
			return
		player.equipment.erase(slot)
		player.rebuild_model()
		ui.hold(cur, "equip")
		ui.hide_tip()
	else:
		if not MuItemsRes.can_equip_in_slot(ui.held, slot):
			return
		var it: Dictionary = ui.drop_held()
		player.equipment[slot] = it
		if not cur.is_empty():
			ui.hold(cur, "equip")
		player.rebuild_model()
	update_display()

var _hover_slot := ""
var _icon_layer: Control = null

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
	var icon: Texture2D = MuItemIconRes.live_icon(get_tree(), cur) if slot == _hover_slot else MuItemIconRes.icon(get_tree(), cur)
	if icon:
		# MU: đồ trong ô trang bị cùng tỉ lệ với túi đồ (20 x 20 mỗi ô) — không phóng to cho đầy
		var sz: Vector2i = MuItemsRes.size_of(cur)
		var isz := Vector2(sz) * 20.0 * S
		# RenderItem3D với hộp = ô trang bị: gốc model đặt tại anchor của Ô TRANG BỊ (cùng tỉ lệ thế giới)
		var an: Vector2 = MuItemIconRes.anchor_of(int(cur.get("group", 0)), int(cur.get("number", 0)))
		layer.draw_texture_rect(icon, MuItemIconRes.overflow_rect(Rect2(rc.position + rc.size * an - isz * an, isz), sz), false)

func _gui_input(event: InputEvent) -> void:
	accept_event()
