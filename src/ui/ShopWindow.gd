extends Control
class_name ShopWindow

## Cửa hàng NPC giống CNewUINPCShop của MU: rương hàng của NPC 8 x 15 ô (hàng lấy từ server OpenMU,
## assets/mu/shops.json — tools/mu_toolkit.py server). Mở cùng túi đồ của nhân vật.
##   - chuột trái vào món hàng: MUA -> đồ nhảy vào ô trống đầu tiên trong túi đồ, trừ Zen
##   - cầm đồ từ túi đồ rồi bấm vào rương NPC: BÁN (giá = giá mua / 3)

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuItemGridRes = preload("res://src/ui/MuItemGrid.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const SHOPS := "res://assets/mu/shops.json"

const S := 1.5
const W := 190.0
const H := 429.0

static var _shops: Dictionary = {}

var player: MuPlayer = null
var npc: Node3D = null
var body: Control
var grid = null
var _title: Label
var _info: Label

func _ready() -> void:
	visible = false
	add_to_group("MuShopWindow")
	for c in get_children():
		c.queue_free()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S
	mouse_filter = Control.MOUSE_FILTER_STOP
	body = Control.new()
	body.custom_minimum_size = Vector2(W, H) * S
	body.size = Vector2(W, H) * S
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.gui_input.connect(_on_body_input)
	add_child(body)
	_title = MuUiSkinRes.build_frame(body, "Cửa Hàng")
	MuUiSkinRes.close_button(body, W, close)
	grid = MuItemGridRes.new()
	grid.setup(8, 15, 20.0 * S)
	grid.position = Vector2(15, 50) * S
	grid.cell_clicked.connect(_on_cell)
	grid.hover_changed.connect(_on_hover)
	body.add_child(grid)
	_info = MuUiSkinRes.font_label("Bấm vào món hàng để mua. Cầm đồ thả vào đây để bán.", 11, Color(0.85, 0.8, 0.7))
	_info.position = Vector2(12, 360) * S
	_info.size = Vector2(166, 40) * S
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_info)
	_place()
	get_viewport().size_changed.connect(_place)

func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(vs.x - 2 * W * S, maxf(0.0, (vs.y - H * S) * 0.5))

static func shop_items(npc_id: int) -> Array:
	if _shops.is_empty() and FileAccess.file_exists(SHOPS):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SHOPS))
		if d is Dictionary:
			_shops = d
	var e = _shops.get(str(npc_id), {})
	return e.get("items", []) if e is Dictionary else []

static func has_shop(npc_id: int) -> bool:
	return not shop_items(npc_id).is_empty()

func _ui():
	return MuItemUiRes.get_ui(get_tree())

## Mở cửa hàng của NPC (npc_id = số trong Monsters.json)
func open_shop(p_player: MuPlayer, npc_name: String = "", npc_id: int = -1, p_npc: Node3D = null) -> void:
	player = p_player
	npc = p_npc
	var list := []
	for e in shop_items(npc_id):
		list.append(MuItemsRes.from_shop(e))
	grid.set_items(list)
	_title.text = npc_name if npc_name != "" else "Cửa Hàng"
	if list.is_empty():
		_info.text = "Chưa có danh sách hàng (chạy MU Tools > Chuyển TẤT CẢ để lấy dữ liệu cửa hàng từ server OpenMU)."
	else:
		_info.text = "Bấm vào món hàng để mua. Cầm đồ thả vào đây để bán."
	_place()
	visible = true
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.inventory_window:
		hud.inventory_window.visible = true
		hud.inventory_window.update_display()

func close() -> void:
	visible = false
	var ui = _ui()
	if ui:
		ui.hide_tip()

func _process(_d: float) -> void:
	# đi xa NPC thì đóng cửa hàng như MU
	if visible and player and npc and is_instance_valid(npc):
		if player.global_position.distance_to(npc.global_position) > 6.0:
			close()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if visible and k and k.pressed and k.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _msg(text: String, col: Color) -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(text, col)

func _on_cell(c: int, r: int, button: int) -> void:
	var ui = _ui()
	if ui and not ui.held.is_empty():
		_sell_held()
		return
	if button != MOUSE_BUTTON_LEFT or player == null:
		return
	var it: Dictionary = grid.item_at(c, r)
	if it.is_empty():
		return
	var price: int = MuItemsRes.buy_price(it)
	if player.zen < price:
		_msg("Không đủ Zen! Cần %s Zen" % MuItemsRes.format_zen(price), Color(1, 0.3, 0.2))
		return
	var copy := it.duplicate()
	if not player.inv_add(copy):
		_msg("Túi đồ đã đầy!", Color(1, 0.3, 0.2))
		return
	player.add_zen(-price)
	if MuAudioManager:
		MuAudioManager.play_item_pickup()
	_msg("Đã mua: %s (-%s Zen)" % [MuItemsRes.display_name(it), MuItemsRes.format_zen(price)], Color(0.3, 1, 0.4))

func _on_body_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var ui = _ui()
		if ui and not ui.held.is_empty():
			_sell_held()
	accept_event()

func _sell_held() -> void:
	var ui = _ui()
	if ui == null or player == null:
		return
	var it: Dictionary = ui.drop_held()
	var price: int = MuItemsRes.sell_price(it)
	player.add_zen(price)
	if MuAudioManager:
		MuAudioManager.play_coin_pickup()
	_msg("Đã bán: %s (+%s Zen)" % [MuItemsRes.display_name(it), MuItemsRes.format_zen(price)], Color(1, 0.85, 0.3))

func _on_hover(it: Dictionary) -> void:
	var ui = _ui()
	if ui == null:
		return
	if it.is_empty():
		ui.hide_tip()
	else:
		ui.show_tip(MuItemsRes.tooltip(it, "Giá mua", MuItemsRes.buy_price(it)))
