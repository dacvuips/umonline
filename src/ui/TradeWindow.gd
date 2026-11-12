extends Control
class_name TradeWindow

## Cửa sổ Giao Dịch giữa 2 người chơi — clone CTrade (UI/Inventory/Trade.cpp) + trade.rml / trade.rcss (legacy) của Source.
## Toạ độ dưới đây là đơn vị MU (640x480) copy thẳng từ trade.rcss, nhân S = 1.5:
##   khung 190x429 (newui_msgbox_back + newui_item_back01/02-L/02-R/03), tiêu đề y = 11
##   dải tên đối phương newui_Account_title (11,37) ; tên (32,43) font to ; guild (16,30) ; "Lv." (134,48) màu theo mốc cấp
##   lưới đồ đối phương 8x4 tại (16,68) ; dải Zen newui_item_money (11,150), chữ Zen y = 158
##   vùng lưu ý (16,177) rộng 166: ô xác nhận của đối phương (146,186) + chữ "Cảnh báo" nhấp nháy + 3 dòng lưu ý
##   vạch chia newui_myquest_Line (1,241) ; dải tên mình (11,243), tên (20,253)
##   lưới đồ của mình 8x4 tại (16,274) ; dải Zen (11,356), chữ y = 364
##   nút y = 390: Thoát newui_exit_00 (13), Zen newui_Bt_money01 (104), Xác nhận newui_Bt_accept (144)
## Luồng (giống server OpenMU): yêu cầu -> đối phương đồng ý -> hai bên đặt đồ / Zen -> cả hai bấm xác nhận -> trao đổi.
## Thay đổi đồ / Zen sau khi đã xác nhận: bỏ xác nhận cả 2 bên, nút xác nhận của mình đỏ & khoá 150 khung (6 giây).
## Đồ của đối phương bị đổi sang bản kém hơn (cấp / dòng thấp hơn món đã thấy) -> gắn nhãn "Cảnh báo" + mũi tên (RenderWarningArrow).

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuItemGridRes = preload("res://src/ui/MuItemGrid.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const MuMsgBoxRes = preload("res://src/ui/MuMsgBox.gd")

const S := 1.5
const W := 190.0
const H := 429.0
const COLS := 8
const ROWS := 4
const TRADE_LIMIT_LEVEL := 6               # TRADELIMITLEVEL (ZzzInterface.h)
const MY_TRADE_WAIT := 150.0 / 25.0        # MyTradeWaitAfterChange: 150 khung tham chiếu 25 fps
const MAX_ZEN := 2000000000

# màu chữ của theme legacy (tokens.ini / base.rcss)
const C_TEXT_INFO := Color("#d2e6ff")
const C_TEXT_SECONDARY := Color("#d8d8d8")
const C_TEXT_HINT := Color("#ffdc96")
const C_WARNING := Color("#d20000")
const LEVEL_BUCKET_COLORS := {10: Color("#ff0000"), 50: Color("#ff9600"), 100: Color("#00c918"),
	200: Color("#d2e6ff"), 300: Color("#ff99ff"), 400: Color("#ff9999")}

var player: MuPlayer = null
var partner: MuOtherPlayer = null

var my_items: Array = []          # đồ mình đặt (x, y trong lưới 8x4)
var your_items: Array = []        # đồ đối phương đặt
var my_gold := 0
var your_gold := 0
var my_confirm := false
var your_confirm := false
var my_wait := 0.0
var trade_alert := false
## Đồ đối phương đã từng thấy (m_aYourInvenBackUp) theo tên đối phương — giữ qua các lần giao dịch
var _your_backup: Dictionary = {}
var _your_id := ""

var _my_grid = null
var _your_grid = null
var _your_name: Label
var _your_guild: Label
var _your_level: Label
var _your_gold_lbl: Label
var _my_name: Label
var _my_gold_lbl: Label
var _warning_lbl: Label
var _your_confirm_box: TextureRect
var _my_confirm_btn: TextureButton
var _badge_layer: Control
var _tex_accept: Texture2D
var _arrow_tex: Texture2D
var _time := 0.0
var _zen_box = null

# kịch bản phía đối phương (thay cho gói tin server)
var _ai_queue: Array = []         # đồ đối phương còn sẽ đặt lên
var _ai_timer := 0.0
var _ai_confirm_timer := -1.0
var _ai_swindled := false
var _closing_timer := -1.0

func _ready() -> void:
	visible = false
	add_to_group("MuTradeWindow")
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30

	MuUiSkinRes.build_frame(self, "Giao Dịch")
	MuUiSkinRes.close_button(self, W, _on_close_pressed)
	_tex_accept = MuUiSkinRes.tex("newui_bt_accept")
	_arrow_tex = MuUiSkinRes.tex("cursorsitdown")

	# --- phần đối phương
	_strip("newui_account_title", Vector2(11, 37), Vector2(171, 26))
	_your_guild = _label("", Vector2(16, 26), Vector2(150, 14), 11, C_TEXT_SECONDARY)
	_your_name = _label("", Vector2(32, 42), Vector2(98, 18), 14, C_TEXT_INFO)
	_your_name.clip_text = true
	_your_level = _label("", Vector2(118, 45), Vector2(64, 14), 11, Color.WHITE)
	_your_grid = MuItemGridRes.new()
	_your_grid.setup(COLS, ROWS, 20.0 * S)
	_your_grid.position = Vector2(16, 68) * S
	_your_grid.hover_changed.connect(_on_hover)
	add_child(_your_grid)
	_strip("newui_item_money", Vector2(11, 150), Vector2(170, 26))
	_your_gold_lbl = _label("0", Vector2(11, 155), Vector2(159, 16), 12, Color("#ffdc96"))
	_your_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# vùng lưu ý + ô xác nhận của đối phương (chỉ hiển thị)
	_your_confirm_box = TextureRect.new()
	_your_confirm_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_your_confirm_box.position = Vector2(146, 186) * S
	_your_confirm_box.size = Vector2(36, 29) * S
	_your_confirm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_your_confirm_box)
	_warning_lbl = _label("Cảnh báo", Vector2(16, 177), Vector2(124, 14), 12, C_WARNING)
	# notice_line1..3 (NoticePleaseCheckOut / TheLevelOfThePlayer / AndTheItemsBeforeTrading)
	var notice_lines := ["Lưu ý! Hãy kiểm tra kỹ", "cấp độ của người chơi", "và vật phẩm trước khi giao dịch."]
	for i in notice_lines.size():
		_label(notice_lines[i], Vector2(16, 191 + i * 13), Vector2(128, 13), 11, C_TEXT_HINT)

	var line := TextureRect.new()
	line.texture = MuUiSkinRes.tex("newui_myquest_line")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.position = Vector2(1, 241) * S
	line.size = Vector2(188, 2) * S
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	# --- phần của mình
	_strip("newui_account_title", Vector2(11, 243), Vector2(171, 26))
	_my_name = _label("", Vector2(20, 249), Vector2(150, 16), 12, C_TEXT_INFO)
	_my_grid = MuItemGridRes.new()
	_my_grid.setup(COLS, ROWS, 20.0 * S)
	_my_grid.position = Vector2(16, 274) * S
	_my_grid.cell_clicked.connect(_on_my_cell)
	_my_grid.released_at.connect(_on_my_grid_released)
	_my_grid.hover_changed.connect(_on_hover)
	add_child(_my_grid)
	_strip("newui_item_money", Vector2(11, 356), Vector2(170, 26))
	_my_gold_lbl = _label("0", Vector2(11, 361), Vector2(159, 16), 12, Color("#ffdc96"))
	_my_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- nút
	var b_exit := MuUiSkinRes.make_btn_2state("newui_exit_00", 36, 29, _on_close_pressed)
	b_exit.position = Vector2(13, 390) * S
	b_exit.size = Vector2(36, 29) * S
	b_exit.tooltip_text = "Đóng"
	add_child(b_exit)
	var b_zen := MuUiSkinRes.make_btn_2state("newui_bt_money01", 36, 29, _on_zen_pressed)
	b_zen.position = Vector2(104, 390) * S
	b_zen.size = Vector2(36, 29) * S
	b_zen.tooltip_text = "Giao dịch Zen"
	add_child(b_zen)
	_my_confirm_btn = TextureButton.new()
	_my_confirm_btn.ignore_texture_size = true
	_my_confirm_btn.stretch_mode = TextureButton.STRETCH_SCALE
	_my_confirm_btn.position = Vector2(144, 390) * S
	_my_confirm_btn.size = Vector2(36, 29) * S
	_my_confirm_btn.focus_mode = Control.FOCUS_NONE
	_my_confirm_btn.pressed.connect(_on_my_confirm_pressed)
	add_child(_my_confirm_btn)

	# nhãn "Cảnh báo" + mũi tên trên đồ bị đổi (vẽ trên cùng)
	_badge_layer = Control.new()
	_badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_layer.position = _your_grid.position
	_badge_layer.size = Vector2(COLS, ROWS) * 20.0 * S
	_badge_layer.draw.connect(_draw_badges)
	add_child(_badge_layer)

	_refresh()
	get_viewport().size_changed.connect(_place)

func _strip(tex_name: String, pos: Vector2, sz: Vector2) -> void:
	var r := TextureRect.new()
	r.texture = MuUiSkinRes.tex(tex_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos * S
	r.size = sz * S
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _label(text: String, pos: Vector2, sz: Vector2, fs: int, col: Color) -> Label:
	var l := MuUiSkinRes.font_label(text, fs, col)
	l.position = pos * S
	l.size = sz * S
	add_child(l)
	return l

## Bên trái túi đồ (túi đồ luôn mở cạnh cửa sổ giao dịch như CNewUISystem::Show(INTERFACE_TRADE))
func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(maxf(0.0, vs.x - 2.0 * W * S), maxf(0.0, (vs.y - H * S) * 0.5))

func _ui():
	return MuItemUiRes.get_ui(get_tree())

func _hud():
	return get_tree().get_first_node_in_group("HUD")

func _sys(text: String, col: Color = Color(1.0, 0.45, 0.35)) -> void:
	var hud = _hud()
	if hud == null:
		return
	if hud.chat_window and hud.chat_window.has_method("add_system_message"):
		hud.chat_window.add_system_message("[color=#%s]%s[/color]" % [col.to_html(false), text])
	hud.show_pickup_notification(text, col)

func is_trading() -> bool:
	return visible and partner != null

# ================================================================== Gửi yêu cầu / nhận kết quả
## Hero gửi yêu cầu giao dịch tới `p` (SendTradeRequest) — gọi khi đã đứng cạnh nhau
func request_trade(p_player: MuPlayer, p: MuOtherPlayer) -> void:
	player = p_player
	if player.level < TRADE_LIMIT_LEVEL:
		_sys("Bạn có thể dùng lệnh giao dịch từ cấp độ %d." % TRADE_LIMIT_LEVEL, Color(1, 1, 1))
		return
	if is_trading():
		_sys("Bạn không thể giao dịch lúc này.")
		return
	_sys("Bạn đã gửi yêu cầu giao dịch tới %s." % p.character_name, Color(1, 1, 1))
	p.busy = true
	# phản hồi của đối phương sau ~1.5 giây (người chơi bấm OK / Cancel trên hộp thoại của họ)
	get_tree().create_timer(1.5).timeout.connect(_on_partner_answer.bind(p))

func _on_partner_answer(p: MuOtherPlayer) -> void:
	if not is_instance_valid(p):
		return
	p.busy = false
	if p.answer_trade_request(player.level):
		_on_trade_result_accepted(p)
	else:
		_sys("Giao dịch đã bị hủy bỏ.")

func _accept_incoming(p: MuOtherPlayer) -> void:
	if is_instance_valid(p):
		_on_trade_result_accepted(p)

func _decline_incoming(p: MuOtherPlayer) -> void:
	if is_instance_valid(p):
		p.busy = false

## Một người chơi khác gửi yêu cầu giao dịch tới Hero (ProcessToReceiveTradeRequest)
func receive_trade_request(p_player: MuPlayer, p: MuOtherPlayer) -> bool:
	player = p_player
	if is_trading() or _impossible_trade_interface():
		return false
	p.busy = true
	var hud = _hud()
	MuMsgBoxRes.open(hud if hud else get_parent(), [[p.character_name, Color.WHITE, true], ["muốn giao dịch với bạn."]],
		_accept_incoming.bind(p), _decline_incoming.bind(p))
	return true

## Cửa sổ đang mở không cho giao dịch (IsImpossibleTradeInterface): cửa hàng, rương, máy Chaos...
func _impossible_trade_interface() -> bool:
	var tree := get_tree()
	for g in ["MuShopWindow", "MuVaultWindow", "MuChaosMixWindow"]:
		var w = tree.get_first_node_in_group(g)
		if w and w.visible:
			return true
	return false

func _on_trade_result_accepted(p: MuOtherPlayer) -> void:
	partner = p
	partner.busy = true
	partner.stop_and_face_hero()
	# ProcessToReceiveTradeResult(Accepted)
	if not trade_alert and _your_id != p.character_name:
		_your_backup.erase(p.character_name)
	trade_alert = false
	_your_id = p.character_name
	my_items.clear()
	your_items.clear()
	my_gold = 0
	your_gold = 0
	my_confirm = false
	your_confirm = false
	my_wait = 0.0
	_ai_swindled = false
	_ai_confirm_timer = -1.0
	_ai_queue = partner.pick_trade_offer()
	_ai_timer = 1.2
	var hud = _hud()
	if hud:
		for g in ["MuShopWindow", "MuVaultWindow"]:
			var w = get_tree().get_first_node_in_group(g)
			if w and w.visible and w.has_method("close"):
				w.close()
		if hud.inventory_window:
			hud.inventory_window.visible = true
			hud.inventory_window.update_display()
			hud.arrange_dock_windows()
	_place()
	visible = true
	if hud:
		hud._bring_modal_to_front(self)
		if hud.inventory_window:
			hud._bring_modal_to_front(hud.inventory_window)
	if MuAudioManager:
		MuAudioManager.play_ui_window()
	_refresh()

# ================================================================== Đóng giao dịch
func _on_close_pressed() -> void:
	var ui = _ui()
	if ui and not ui.held.is_empty():
		return
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	trade_alert = false
	cancel_trade("Giao dịch đã bị hủy bỏ.")

## SendTradeCancel -> ProcessToReceiveTradeExit(Cancelled): trả lại đồ và Zen
func cancel_trade(reason: String = "Giao dịch đã bị hủy bỏ.") -> void:
	if not visible:
		return
	var ui = _ui()
	if ui and not ui.held.is_empty() and player:
		ui.cancel_held(player)
	for it in my_items:
		var n: Dictionary = it.duplicate()
		if not player.inv_add(n):
			player.inventory.append(n)
	player.zen = mini(MAX_ZEN, player.zen + my_gold)
	player.inventory_changed.emit()
	for it in your_items:
		_backup_your_item(it)
	_finish(reason)

func _finish(msg: String) -> void:
	my_items.clear()
	your_items.clear()
	my_gold = 0
	your_gold = 0
	my_confirm = false
	your_confirm = false
	_ai_queue.clear()
	if _zen_box and is_instance_valid(_zen_box):
		_zen_box.dismiss()
	_zen_box = null
	if partner and is_instance_valid(partner):
		partner.busy = false
	partner = null
	visible = false
	var ui = _ui()
	if ui:
		ui.hide_tip()
	if msg != "":
		_sys(msg)
	_refresh()

# ================================================================== Lưới đồ của mình
func _fits(list: Array, x: int, y: int, w: int, h: int, ignore: Dictionary = {}) -> bool:
	if x < 0 or y < 0 or x + w > COLS or y + h > ROWS:
		return false
	for it in list:
		if not ignore.is_empty() and it == ignore:
			continue
		var s: Vector2i = MuItemsRes.size_of(it)
		if x < int(it["x"]) + s.x and int(it["x"]) < x + w and y < int(it["y"]) + s.y and int(it["y"]) < y + h:
			return false
	return true

func _find_free(list: Array, w: int, h: int) -> Vector2i:
	for y in ROWS:
		for x in COLS:
			if _fits(list, x, y, w, h):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

## IsTradeBan: đồ không được giao dịch
func is_trade_ban(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	if g == 13 and n == 20 and int(it.get("level", 0)) == 0:    # Wizard's Ring
		return true
	if g == 14 and n == 11 and int(it.get("level", 0)) == 13:   # Heart of Dark Lord
		return true
	return bool(it.get("no_trade", false)) or bool(it.get("bound", false))

func _place_my_item(it: Dictionary, x: int, y: int) -> bool:
	var s: Vector2i = MuItemsRes.size_of(it)
	if not _fits(my_items, x, y, s.x, s.y):
		return false
	var n: Dictionary = it.duplicate()
	n["x"] = x
	n["y"] = y
	my_items.append(n)
	return true

## ProcessMyInvenItemAutoMove: chuột phải đồ trong túi -> vào khung giao dịch của mình
func add_from_inventory(it: Dictionary) -> bool:
	if not is_trading():
		return false
	if is_trade_ban(it):
		_sys("Vật phẩm này không thể giao dịch.")
		return false
	var s: Vector2i = MuItemsRes.size_of(it)
	var p := _find_free(my_items, s.x, s.y)
	if p.x < 0:
		return false
	player.inv_remove(it)
	_place_my_item(it, p.x, p.y)
	_uncheck_my_confirm()
	_on_my_offer_changed()
	if MuAudioManager:
		MuAudioManager.play_item_pickup()
	return true

func _on_my_cell(c: int, r: int, button: int) -> void:
	if not is_trading():
		return
	var ui = _ui()
	if ui == null:
		return
	if button == MOUSE_BUTTON_RIGHT:
		if not ui.held.is_empty():
			ui.cancel_held(player)
			return
		# ProcessMyTradeItemAutoMoveToInventory
		var it: Dictionary = _my_grid.item_at(c, r)
		if it.is_empty():
			return
		var n: Dictionary = it.duplicate()
		if not player.inv_add(n):
			_sys("Túi đồ đã đầy.")
			return
		my_items.erase(it)
		if my_confirm:
			_alert_trade()
		my_wait = MY_TRADE_WAIT
		_on_my_offer_changed()
		if MuAudioManager:
			MuAudioManager.play_item_pickup()
		_refresh()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if ui.held.is_empty():
		var it2: Dictionary = _my_grid.item_at(c, r)
		if it2.is_empty():
			return
		my_items.erase(it2)
		ui.hold(it2, "trade")
		ui.hide_tip()
		if my_confirm:
			_uncheck_my_confirm()
		my_wait = MY_TRADE_WAIT
		_on_my_offer_changed()
		if MuAudioManager:
			MuAudioManager.play_item_pickup()
	else:
		# SendRequestItemToTrade
		if is_trade_ban(ui.held):
			_sys("Vật phẩm này không thể giao dịch.")
			return
		if not _place_my_item(ui.held, c, r):
			return
		ui.drop_held()
		_uncheck_my_confirm()
		_on_my_offer_changed()
		if MuAudioManager:
			MuAudioManager.play_item_pickup()
	_refresh()

func _on_my_grid_released(gpos: Vector2, cell: Vector2i, inside: bool) -> void:
	if inside:
		_on_my_cell(cell.x, cell.y, MOUSE_BUTTON_LEFT)
		return
	var hud = _hud()
	if hud and hud.inventory_window and hud.inventory_window.visible:
		var g = hud.inventory_window.grid
		if g and g.get_global_rect().has_point(gpos):
			var lp: Vector2 = g.get_global_transform().affine_inverse() * gpos
			var c := Vector2i(floori(lp.x / g.cell), floori(lp.y / g.cell))
			hud.inventory_window._on_cell(c.x, c.y, MOUSE_BUTTON_LEFT)

## Thả đồ đang cầm (kéo từ túi đồ) vào lưới giao dịch của mình theo vị trí màn hình
func drop_held_at_global(gpos: Vector2) -> bool:
	if not is_trading() or not _my_grid.get_global_rect().has_point(gpos):
		return false
	var lp: Vector2 = _my_grid.get_global_transform().affine_inverse() * gpos
	_on_my_cell(floori(lp.x / _my_grid.cell), floori(lp.y / _my_grid.cell), MOUSE_BUTTON_LEFT)
	return true

func _uncheck_my_confirm() -> void:
	my_confirm = false

## AlertTrade: đảo trạng thái xác nhận của mình
func _alert_trade() -> void:
	my_confirm = not my_confirm
	trade_alert = true
	_on_my_confirm_changed()
	_refresh()

func _on_my_confirm_pressed() -> void:
	if not is_trading():
		return
	var ui = _ui()
	if my_wait > 0.0 or (ui and not ui.held.is_empty()):
		return
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	if _has_warning_items() and not my_confirm:
		# kTradeAlertLines: cảnh báo đồ đã bị thay đổi trước khi xác nhận
		MuMsgBoxRes.open(_hud(), [
			["Cấp độ và dòng tuỳ chọn của một số vật phẩm", Color(1, 0.85, 0.3), true],
			["đã bị thay đổi trong lúc giao dịch.", Color(1, 0.85, 0.3), true],
			["Hãy kiểm tra xem vật phẩm có đúng là", Color(1, 0.85, 0.3), true],
			["món đồ bạn muốn giao dịch hay không.", C_WARNING, true]],
			func(): _alert_trade())
	else:
		_alert_trade()

# ================================================================== Zen
func _on_zen_pressed() -> void:
	if not is_trading():
		return
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	if _zen_box and is_instance_valid(_zen_box):
		return
	_zen_box = MuMsgBoxRes.open(_hud(), [["Nhập số Zen bạn muốn giao dịch."]],
		_on_zen_ok, Callable(), {"input": true, "max_length": 10, "numeric": true})

func _on_zen_ok() -> void:
	var box = MuMsgBoxRes.active
	var v := int(box.get_input_text()) if box else 0
	if v == 0:
		if box:
			box.keep_open()
		return
	_send_my_gold(v)

## SendRequestMyGoldInput
func _send_my_gold(v: int) -> void:
	if not is_trading() or v < 0:
		return
	if v > player.zen + my_gold:
		MuMsgBoxRes.open(_hud(), [["Bạn không đủ Zen."]], Callable(), Callable(), {"cancel": false})
		return
	if my_confirm:
		my_confirm = false
	if my_gold > 0:
		my_wait = MY_TRADE_WAIT
	player.zen = player.zen + my_gold - v
	my_gold = v
	player.inventory_changed.emit()
	if MuAudioManager:
		MuAudioManager.play_coin_pickup()
	_on_my_offer_changed()
	_refresh()

# ================================================================== Phía đối phương (gói tin từ server)
## ProcessToReceiveYourItemAdd
func _your_item_add(it: Dictionary) -> void:
	var s: Vector2i = MuItemsRes.size_of(it)
	var p := _find_free(your_items, s.x, s.y)
	if p.x < 0:
		return
	var n: Dictionary = it.duplicate()
	n["x"] = p.x
	n["y"] = p.y
	n["_src"] = it
	your_items.append(n)
	_alert_your_trade_inven()
	if MuAudioManager:
		MuAudioManager.play_item_pickup()
	_refresh()

## ProcessToReceiveYourItemDelete
func _your_item_delete(n: Dictionary) -> void:
	_backup_your_item(n)
	your_items.erase(n)
	_alert_your_trade_inven()
	if MuAudioManager:
		MuAudioManager.play_item_pickup()
	_refresh()

## Đồ đáng giá mới được ghi lại (BackUpYourInven): ngọc, cánh, đồ cấp > 4, đồ excellent...
func _is_backup_worthy(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	return MuItemsRes.is_jewel(it) or MuItemsRes.is_wing(it) or g == 13 \
		or (g < 12 and int(it.get("level", 0)) > 4) or bool(it.get("excellent", false))

## CompareItem: 0 giống hệt, 1 = `a` (đã thấy) tốt hơn `b` (mới), -1 = `b` tốt hơn, 2 = khác loại
func _compare(a: Dictionary, b: Dictionary) -> int:
	if int(a.get("group", -1)) != int(b.get("group", -1)) or int(a.get("number", -1)) != int(b.get("number", -1)):
		return 2
	var keys := ["level", "opt"]
	var flags := ["excellent", "luck", "skill"]
	var worse := false
	var better := false
	for k in keys:
		var d := int(b.get(k, 0)) - int(a.get(k, 0))
		worse = worse or d < 0
		better = better or d > 0
	for k in flags:
		var av := bool(a.get(k, false))
		var bv := bool(b.get(k, false))
		worse = worse or (av and not bv)
		better = better or (bv and not av)
	if worse:
		return 1
	if better:
		return -1
	return 0

func _backup_your_item(it: Dictionary) -> void:
	if not _is_backup_worthy(it) or _your_id == "":
		return
	var list: Array = _your_backup.get(_your_id, [])
	for i in list.size():
		var c := _compare(list[i], it)
		if c == 0:
			return
		if c == -1:
			list[i] = _strip_pos(it)
			_your_backup[_your_id] = list
			return
		if c == 1:
			return
	list.append(_strip_pos(it))
	_your_backup[_your_id] = list

func _strip_pos(it: Dictionary) -> Dictionary:
	var n: Dictionary = it.duplicate()
	n.erase("_src")
	n.erase("_warn")
	return n

## AlertYourTradeInven: đánh dấu đồ đối phương kém hơn bản đã từng thấy
func _alert_your_trade_inven() -> void:
	trade_alert = false
	var list: Array = _your_backup.get(_your_id, [])
	for n in your_items:
		n["_warn"] = false
		for b in list:
			if _compare(b, n) == 1:
				n["_warn"] = true
				trade_alert = true
				break

func _has_warning_items() -> bool:
	for n in your_items:
		if bool(n.get("_warn", false)):
			return true
	return false

## ProcessToReceiveYourConfirm(BothReset): hai bên bỏ xác nhận, nút của mình khoá một lúc
func _both_reset() -> void:
	my_confirm = false
	your_confirm = false
	my_wait = MY_TRADE_WAIT
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	_refresh()

func _on_my_offer_changed() -> void:
	# server: đồ / Zen của mình thay đổi -> đối phương bỏ xác nhận
	if your_confirm:
		your_confirm = false
		if MuAudioManager:
			MuAudioManager.play_ui_click()
	_ai_confirm_timer = -1.0
	_refresh()

func _on_my_confirm_changed() -> void:
	if my_confirm and not your_confirm:
		_ai_confirm_timer = randf_range(1.0, 2.2)
	elif not my_confirm:
		_ai_confirm_timer = -1.0
	_check_both_confirmed()

func _check_both_confirmed() -> void:
	if my_confirm and your_confirm and _closing_timer < 0.0:
		_closing_timer = 0.6   # server xử lý trao đổi

## Hai bên đã xác nhận -> server trao đổi đồ (ProcessToReceiveTradeExit(Completed) + ProcessToReceiveTradeItems)
func _complete_trade() -> void:
	_closing_timer = -1.0
	if not is_trading():
		return
	# túi đồ còn đủ chỗ cho đồ của đối phương?
	var sim: Array = player.inventory.duplicate()
	for n in your_items:
		var s: Vector2i = MuItemsRes.size_of(n)
		var spot := Vector2i(-1, -1)
		for y in MuPlayer.INV_ROWS:
			for x in MuPlayer.INV_COLS:
				if spot.x < 0 and _sim_fits(sim, x, y, s.x, s.y):
					spot = Vector2i(x, y)
		if spot.x < 0:
			cancel_trade("Giao dịch bị hủy do túi đồ của bạn đã đầy.")
			return
		sim.append({"group": n["group"], "number": n["number"], "x": spot.x, "y": spot.y})
	if player.zen + your_gold > MAX_ZEN:
		cancel_trade("Giao dịch đã bị hủy bỏ.")
		return
	var got := []
	for n in your_items:
		var clean := _strip_pos(n)
		if n.has("_src"):
			partner.inv_remove(n["_src"])
		player.inv_add(clean)
		got.append(MuItemsRes.display_name(clean))
	for it in my_items:
		partner.inv_add(_strip_pos(it))
	player.zen += your_gold
	partner.zen = maxi(0, partner.zen - your_gold) + my_gold
	player.inventory_changed.emit()
	if MuAudioManager:
		MuAudioManager.play_coin_pickup()
	var msg := "Giao dịch với %s thành công." % partner.character_name
	_finish("")
	_sys(msg, Color(0.45, 1.0, 0.5))

func _sim_fits(list: Array, x: int, y: int, w: int, h: int) -> bool:
	if x + w > MuPlayer.INV_COLS or y + h > MuPlayer.INV_ROWS:
		return false
	for it in list:
		var s: Vector2i = MuItemsRes.size_of(it)
		if x < int(it["x"]) + s.x and int(it["x"]) < x + w and y < int(it["y"]) + s.y and int(it["y"]) < y + h:
			return false
	return true

# ================================================================== Khung hình
func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if my_wait > 0.0:
		my_wait = maxf(0.0, my_wait - delta)
		_update_confirm_sprites()
	# chữ "Cảnh báo" nhấp nháy: min(255, sin(WorldTime/200)*200 + 275)
	var a := minf(255.0, sin(_time * 1000.0 / 200.0) * 200.0 + 275.0)
	_warning_lbl.modulate.a = a / 255.0
	if _has_warning_items():
		_badge_layer.queue_redraw()

	if partner == null or not is_instance_valid(partner):
		_finish("Giao dịch đã bị hủy bỏ.")
		return
	# đi quá xa -> server huỷ giao dịch
	if player and player.global_position.distance_to(partner.global_position) > 5.0:
		cancel_trade("Giao dịch đã bị hủy bỏ.")
		return

	# preview đặt đồ đang cầm
	var ui = _ui()
	if ui:
		if ui.held.is_empty():
			_my_grid.preview_size = Vector2i.ZERO
		else:
			_my_grid.preview_size = MuItemsRes.size_of(ui.held)
			var hc: Vector2i = _my_grid.hover_cell
			_my_grid.preview_ok = _fits(my_items, hc.x, hc.y, _my_grid.preview_size.x, _my_grid.preview_size.y)

	_ai_step(delta)
	if _closing_timer >= 0.0:
		_closing_timer -= delta
		if _closing_timer < 0.0:
			_complete_trade()

## Hành vi của người chơi bên kia (thay cho gói tin 0x3A/0x3B/0x3C... từ server)
func _ai_step(delta: float) -> void:
	if _ai_timer > 0.0:
		_ai_timer -= delta
		if _ai_timer <= 0.0:
			if not _ai_queue.is_empty():
				_your_item_add(_ai_queue.pop_front())
				_ai_timer = randf_range(0.6, 1.2)
			elif your_gold != partner.trade_offer_zen and partner.trade_offer_zen > 0:
				your_gold = mini(partner.trade_offer_zen, partner.zen)
				if MuAudioManager:
					MuAudioManager.play_coin_pickup()
				_refresh()
	if _ai_confirm_timer > 0.0:
		_ai_confirm_timer -= delta
		if _ai_confirm_timer <= 0.0:
			_ai_confirm_timer = -1.0
			if partner.trade_swindler and not _ai_swindled and _swindle():
				return
			if my_confirm and _ai_queue.is_empty():
				your_confirm = true
				if MuAudioManager:
					MuAudioManager.play_ui_click()
				_refresh()
				_check_both_confirmed()

## Người chơi gian lận: rút món đồ ra rồi đặt lại bản cấp thấp hơn (đúng kịch bản mà cảnh báo CTrade bắt được)
func _swindle() -> bool:
	for n in your_items:
		if int(n.get("level", 0)) > 4 or bool(n.get("excellent", false)):
			_ai_swindled = true
			var src: Dictionary = n.get("_src", {})
			_your_item_delete(n)
			var fake := _strip_pos(n)
			fake["level"] = maxi(0, int(fake.get("level", 0)) - 6)
			fake["opt"] = 0
			fake["luck"] = false
			if not src.is_empty():
				partner.inv_remove(src)
				partner.inv_add(fake)
				fake = partner.inventory[partner.inventory.size() - 1]
			_both_reset()
			get_tree().create_timer(0.8).timeout.connect(_readd_item.bind(fake))
			return true
	return false

func _readd_item(it: Dictionary) -> void:
	if is_trading():
		_your_item_add(it)

func _refresh() -> void:
	if _my_grid == null:
		return
	_my_grid.set_items(my_items)
	_your_grid.set_items(your_items)
	_my_gold_lbl.text = MuItemsRes.format_zen(my_gold)
	_my_gold_lbl.add_theme_color_override("font_color", _gold_color(my_gold))
	_your_gold_lbl.text = MuItemsRes.format_zen(your_gold)
	_your_gold_lbl.add_theme_color_override("font_color", _gold_color(your_gold))
	_my_name.text = player.character_name if player else ""
	if partner and is_instance_valid(partner):
		_your_name.text = partner.character_name
		_your_guild.text = partner.guild_name
		var b := _level_bucket(partner.level)
		_your_level.text = "Lv.%d" % b if b == 400 else "Lv.~%d" % b
		_your_level.add_theme_color_override("font_color", LEVEL_BUCKET_COLORS[b])
	_update_confirm_sprites()
	_badge_layer.queue_redraw()

## Màu số Zen theo mốc (ClassifyGoldAmount + .gold-amount trong base.rcss)
static func _gold_color(v: int) -> Color:
	if v >= 10000000:
		return Color("#ff0000")
	if v >= 1000000:
		return Color("#ff9600")
	if v >= 100000:
		return Color("#00c918")
	return Color("#ffdc96")

## ConvertYourLevel: cấp đối phương làm tròn xuống theo mốc (client gốc chỉ cho biết "khoảng")
static func _level_bucket(lv: int) -> int:
	for b in [400, 300, 200, 100, 50]:
		if lv >= b:
			return b
	return 10

func _update_confirm_sprites() -> void:
	if _tex_accept == null:
		return
	var off := MuUiSkinRes.atlas_sub(_tex_accept, Rect2(0, 0, 36, 29))
	var on := MuUiSkinRes.atlas_sub(_tex_accept, Rect2(0, 29, 36, 29))
	_your_confirm_box.texture = on if your_confirm else off
	var t := on if my_confirm else off
	_my_confirm_btn.texture_normal = t
	_my_confirm_btn.texture_pressed = t
	# my_confirm_waiting: ảnh nhân màu đỏ RGBA(255, 0, 0)
	_my_confirm_btn.modulate = Color(1, 0, 0) if my_wait > 0.0 else Color(1, 1, 1)

## Mũi tên CursorSitDown màu (0,255,255) nhấp nhô + nhãn đỏ "Cảnh báo" rộng bằng món đồ
func _draw_badges() -> void:
	var cell := 20.0 * S
	var unit := cell / 20.0
	var font := get_theme_default_font()
	for n in your_items:
		if not bool(n.get("_warn", false)):
			continue
		var sz: Vector2i = MuItemsRes.size_of(n)
		var x := float(int(n["x"])) * cell
		var y := float(int(n["y"])) * cell + sin(_time * 1000.0 * 0.015) * unit
		if _arrow_tex:
			var src := Rect2(0, 0, _arrow_tex.get_width(), _arrow_tex.get_height() * 0.4)
			_badge_layer.draw_texture_rect_region(_arrow_tex, Rect2(x, y + 5.0 * unit, 24.0 * unit, 24.0 * unit), src, Color(0, 1, 1))
		var bw := sz.x * cell
		_badge_layer.draw_rect(Rect2(x, y, bw, 14.0), Color(210.0 / 255.0, 0, 0))
		var txt := "Cảnh báo"
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_badge_layer.draw_string(font, Vector2(x + (bw - tw) * 0.5, y + 11.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _on_hover(it: Dictionary) -> void:
	var ui = _ui()
	if ui == null:
		return
	if it.is_empty():
		ui.hide_tip()
	else:
		ui.show_tip(MuItemsRes.tooltip(_strip_pos(it)))

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		var hud = _hud()
		if hud:
			hud._bring_modal_to_front(self)
	accept_event()
