extends Control
class_name VaultWindow

## Cửa sổ Rương Chứa Đồ (Vault / Warehouse) chuẩn MU Online (CNewUIStorage Season 6)
## Dung lượng 8 x 15 = 120 ô, quản lý gửi/rút tiền Zen và hệ thống khóa PIN bảo mật.
## Mở song song cùng Túi đồ của người chơi:
##   - Bấm chuột trái: Bốc / Đặt đồ theo ô chỉ định
##   - Bấm chuột phải: Chuyển nhanh giữa Rương và Túi đồ (Quick Transfer)
##   - Gửi / Rút Zen: Có nút nhập tiền & nút Tối Đa (Max)
##   - Khóa Rương (PIN 4 số): Bảo vệ an toàn đồ đạc & tiền trong rương

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuItemGridRes = preload("res://src/ui/MuItemGrid.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")

const S := 1.5
const W := 190.0
const H := 429.0

var player: MuPlayer = null
var npc: Node3D = null
var body: Control
var grid = null
var _title: Label
var _zen_label: Label
var _lock_status_label: Label
var _btn_lock: Button
var _btn_deposit: Button
var _btn_withdraw: Button

# Pop-up dialogs
var _zen_dialog: Control = null
var _zen_input: LineEdit = null
var _zen_dialog_title: Label = null
var _zen_dialog_is_deposit := true

var _pin_dialog: Control = null
var _pin_input: LineEdit = null
var _pin_dialog_title: Label = null
var _pin_mode := "unlock" # "unlock" | "set"

func _ready() -> void:
	visible = false
	add_to_group("MuVaultWindow")
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

	_title = MuUiSkinRes.build_frame(body, "Rương Chứa Đồ")
	MuUiSkinRes.close_button(body, W, close)

	# Lưới rương 8 cột x 15 hàng (chuẩn CNewUIStorage của MU)
	grid = MuItemGridRes.new()
	grid.setup(8, 15, 20.0 * S)
	grid.position = Vector2(15, 46) * S
	grid.cell_clicked.connect(_on_cell)
	grid.hover_changed.connect(_on_hover)
	body.add_child(grid)

	# Vùng hiển thị Zen trong kho (y hệt NewUI Inventory/Shop)
	var money_bg := TextureRect.new()
	money_bg.texture = MuUiSkinRes.tex("newui_item_money")
	money_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money_bg.position = Vector2(11, 350) * S
	money_bg.size = Vector2(170, 24) * S
	money_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(money_bg)

	_zen_label = MuUiSkinRes.font_label("0", 12, Color(1, 0.9, 0.55))
	_zen_label.position = Vector2(38, 354) * S
	_zen_label.size = Vector2(138, 16) * S
	_zen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(_zen_label)

	# Hàng nút Thao tác Tiền tệ: [ Gửi Zen ] [ Rút Zen ]
	_btn_deposit = Button.new()
	_btn_deposit.text = "Gửi Zen"
	_btn_deposit.position = Vector2(12, 378) * S
	_btn_deposit.size = Vector2(80, 22) * S
	_btn_deposit.add_theme_font_size_override("font_size", 11)
	_btn_deposit.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_btn_deposit.pressed.connect(func(): _open_zen_dialog(true))
	body.add_child(_btn_deposit)

	_btn_withdraw = Button.new()
	_btn_withdraw.text = "Rút Zen"
	_btn_withdraw.position = Vector2(98, 378) * S
	_btn_withdraw.size = Vector2(80, 22) * S
	_btn_withdraw.add_theme_font_size_override("font_size", 11)
	_btn_withdraw.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_btn_withdraw.pressed.connect(func(): _open_zen_dialog(false))
	body.add_child(_btn_withdraw)

	# Nút Khóa / Mở khóa Bảo Vệ (Mã PIN)
	_btn_lock = Button.new()
	_btn_lock.text = "🔓 Mở Khóa"
	_btn_lock.position = Vector2(12, 403) * S
	_btn_lock.size = Vector2(166, 21) * S
	_btn_lock.add_theme_font_size_override("font_size", 11)
	_btn_lock.pressed.connect(_on_lock_button_pressed)
	body.add_child(_btn_lock)

	# Xây dựng các dialog con
	_build_zen_dialog()
	_build_pin_dialog()

	_place()
	get_viewport().size_changed.connect(_place)

func _place() -> void:
	var vs := get_viewport_rect().size
	# Đặt bên trái túi đồ (giống vị trí Shop)
	position = Vector2(vs.x - 2 * W * S, maxf(0.0, (vs.y - H * S) * 0.5))

func _ui():
	return MuItemUiRes.get_ui(get_tree())

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player and not player.vault_changed.is_connected(update_display):
		player.vault_changed.connect(update_display)
	update_display()

func is_locked() -> bool:
	return player != null and player.vault_locked

## Mở rương chứa đồ
func open_vault(p_player: MuPlayer, keeper_name: String = "Thủ Kho", p_npc: Node3D = null) -> void:
	player = p_player
	npc = p_npc
	if player and not player.vault_changed.is_connected(update_display):
		player.vault_changed.connect(update_display)
	_title.text = keeper_name if keeper_name != "" else "Rương Chứa Đồ"
	update_display()
	_place()
	visible = true

	# Tự động mở túi đồ bên phải để cất/rút đồ
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.inventory_window:
		hud.inventory_window.visible = true
		hud.inventory_window.update_display()

	if MuAudioManager:
		MuAudioManager.play_ui_window()
	show_msg("%s: \"Chào mừng bạn đến với Rương Chứa Đồ!\"" % [keeper_name], Color(1.0, 0.9, 0.5))

func close() -> void:
	visible = false
	if _zen_dialog:
		_zen_dialog.visible = false
	if _pin_dialog:
		_pin_dialog.visible = false
	var ui = _ui()
	if ui:
		ui.hide_tip()

func update_display() -> void:
	if player == null or grid == null:
		return
	grid.set_items(player.vault)
	_zen_label.text = MuItemsRes.format_zen(player.vault_zen)

	if player.vault_locked:
		_btn_lock.text = "🔒 Đang Khóa (Bấm để Mở)"
		_btn_lock.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	else:
		if player.vault_pin == "":
			_btn_lock.text = "🔓 Đặt Mã PIN Bảo Vệ"
			_btn_lock.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		else:
			_btn_lock.text = "🔓 Đang Mở (Bấm để Khóa)"
			_btn_lock.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

func _process(_d: float) -> void:
	if not visible:
		return
	# Đi xa NPC Thủ Kho thì tự đóng rương
	if player and npc and is_instance_valid(npc):
		if player.global_position.distance_to(npc.global_position) > 6.0:
			close()
			return

	var ui = _ui()
	if ui:
		if ui.held.is_empty():
			grid.preview_size = Vector2i.ZERO
		else:
			grid.preview_size = MuItemsRes.size_of(ui.held)
			var hc: Vector2i = grid.hover_cell
			grid.preview_ok = player != null and player.vault_fits(hc.x, hc.y, grid.preview_size.x, grid.preview_size.y)

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if visible and k and k.pressed and k.keycode == KEY_ESCAPE:
		if _zen_dialog and _zen_dialog.visible:
			_zen_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		if _pin_dialog and _pin_dialog.visible:
			_pin_dialog.visible = false
			get_viewport().set_input_as_handled()
			return
		close()
		get_viewport().set_input_as_handled()

func show_msg(text: String, col: Color = Color.WHITE) -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(text, col)

# ------------------------------------------------------------------ Tương tác ô lưới rương
func _on_cell(c: int, r: int, button: int) -> void:
	if player == null:
		return
	var ui = _ui()
	if ui == null:
		return

	# Chuột phải: Rút nhanh món đồ về Túi Đồ (Quick Withdraw)
	if button == MOUSE_BUTTON_RIGHT:
		var it: Dictionary = grid.item_at(c, r)
		if it.is_empty() or not ui.held.is_empty():
			return
		if is_locked():
			show_msg("Rương đồ đang bị khóa bảo vệ! Vui lòng mở khóa trước.", Color(1.0, 0.4, 0.3))
			return
		player.vault_remove(it)
		if player.inv_add(it):
			if MuAudioManager:
				MuAudioManager.play_item_pickup()
			show_msg("Đã rút: %s về túi đồ!" % MuItemsRes.display_name(it), Color(0.4, 1.0, 0.5))
		else:
			# Túi đầy -> trả lại rương
			player.vault_add(it)
			show_msg("Túi đồ đã đầy, không thể rút thêm!", Color(1.0, 0.3, 0.2))
		update_display()
		return

	# Chuột trái: Cầm lên / Đặt xuống
	if button == MOUSE_BUTTON_LEFT:
		if is_locked():
			show_msg("Rương đồ đang bị khóa bảo vệ! Vui lòng mở khóa trước.", Color(1.0, 0.4, 0.3))
			return

		if ui.held.is_empty():
			# Bốc đồ từ rương lên chuột
			var it2: Dictionary = grid.item_at(c, r)
			if it2.is_empty():
				return
			player.vault_remove(it2)
			ui.hold(it2, "vault")
			ui.hide_tip()
			if MuAudioManager:
				MuAudioManager.play_item_pickup()
		else:
			# Đặt đồ đang cầm vào ô rương
			if player.vault_place(ui.held, c, r):
				ui.drop_held()
				if MuAudioManager:
					MuAudioManager.play_item_pickup()
		update_display()

func _on_body_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var ui = _ui()
		if ui and not ui.held.is_empty():
			if is_locked():
				show_msg("Rương đồ đang bị khóa bảo vệ!", Color(1.0, 0.4, 0.3))
				return
			# Thả vào khoảng trống của thân rương -> tự tìm ô trống đầu tiên
			if player.vault_add(ui.held):
				ui.drop_held()
				if MuAudioManager:
					MuAudioManager.play_item_pickup()
				update_display()
	accept_event()

func _on_hover(it: Dictionary) -> void:
	var ui = _ui()
	if ui == null:
		return
	if it.is_empty():
		ui.hide_tip()
	else:
		ui.show_tip(MuItemsRes.tooltip(it))

# ------------------------------------------------------------------ Hộp thoại Tiền Zen
func _build_zen_dialog() -> void:
	_zen_dialog = Control.new()
	_zen_dialog.custom_minimum_size = Vector2(170, 130) * S
	_zen_dialog.size = Vector2(170, 130) * S
	_zen_dialog.position = Vector2(10, 240) * S
	_zen_dialog.visible = false
	_zen_dialog.mouse_filter = Control.MOUSE_FILTER_STOP

	# Khung nền
	var bg := ColorRect.new()
	bg.size = _zen_dialog.size
	bg.color = Color(0.08, 0.07, 0.06, 0.96)
	_zen_dialog.add_child(bg)

	var border := ReferenceRect.new()
	border.size = _zen_dialog.size
	border.border_color = Color(0.7, 0.6, 0.4)
	border.border_width = 1.5
	border.editor_only = false
	_zen_dialog.add_child(border)

	_zen_dialog_title = Label.new()
	_zen_dialog_title.text = "Gửi Zen vào Rương"
	_zen_dialog_title.add_theme_font_size_override("font_size", 13)
	_zen_dialog_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_zen_dialog_title.position = Vector2(10, 8) * S
	_zen_dialog_title.size = Vector2(150, 20) * S
	_zen_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zen_dialog.add_child(_zen_dialog_title)

	_zen_input = LineEdit.new()
	_zen_input.placeholder_text = "Nhập số Zen..."
	_zen_input.position = Vector2(15, 34) * S
	_zen_input.size = Vector2(140, 26) * S
	_zen_input.add_theme_font_size_override("font_size", 12)
	_zen_dialog.add_child(_zen_input)

	var btn_max := Button.new()
	btn_max.text = "Tối Đa (Max)"
	btn_max.position = Vector2(15, 66) * S
	btn_max.size = Vector2(140, 22) * S
	btn_max.add_theme_font_size_override("font_size", 11)
	btn_max.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	btn_max.pressed.connect(_on_zen_max_pressed)
	_zen_dialog.add_child(btn_max)

	var btn_confirm := Button.new()
	btn_confirm.text = "Đồng Ý"
	btn_confirm.position = Vector2(15, 94) * S
	btn_confirm.size = Vector2(65, 24) * S
	btn_confirm.add_theme_font_size_override("font_size", 11)
	btn_confirm.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	btn_confirm.pressed.connect(_on_zen_confirm_pressed)
	_zen_dialog.add_child(btn_confirm)

	var btn_cancel := Button.new()
	btn_cancel.text = "Hủy"
	btn_cancel.position = Vector2(90, 94) * S
	btn_cancel.size = Vector2(65, 24) * S
	btn_cancel.add_theme_font_size_override("font_size", 11)
	btn_cancel.pressed.connect(func(): _zen_dialog.visible = false)
	_zen_dialog.add_child(btn_cancel)

	body.add_child(_zen_dialog)

func _open_zen_dialog(is_deposit: bool) -> void:
	if is_locked():
		show_msg("Rương đồ đang bị khóa bảo vệ!", Color(1.0, 0.4, 0.3))
		return
	_zen_dialog_is_deposit = is_deposit
	_zen_dialog_title.text = "Gửi Zen vào Rương" if is_deposit else "Rút Zen về Túi"
	_zen_input.text = ""
	_zen_dialog.visible = true
	_zen_dialog.move_to_front()
	_zen_input.grab_focus()

func _on_zen_max_pressed() -> void:
	if player == null:
		return
	if _zen_dialog_is_deposit:
		var max_dep := mini(player.zen, MuPlayer.MAX_VAULT_ZEN - player.vault_zen)
		_zen_input.text = str(maxi(0, max_dep))
	else:
		var max_with := mini(player.vault_zen, MuPlayer.MAX_INV_ZEN - player.zen)
		_zen_input.text = str(maxi(0, max_with))

func _on_zen_confirm_pressed() -> void:
	if player == null:
		return
	var amount := int(_zen_input.text.strip_edges())
	if amount <= 0:
		show_msg("Số Zen không hợp lệ!", Color(1.0, 0.4, 0.3))
		return

	if _zen_dialog_is_deposit:
		if player.zen < amount:
			show_msg("Bạn không có đủ Zen trên người!", Color(1.0, 0.3, 0.2))
			return
		if player.vault_zen + amount > MuPlayer.MAX_VAULT_ZEN:
			show_msg("Rương không thể chứa quá 2 Tỷ Zen!", Color(1.0, 0.3, 0.2))
			return
		if player.vault_deposit_zen(amount):
			if MuAudioManager:
				MuAudioManager.play_coin_pickup()
			show_msg("Đã gửi %s Zen vào rương!" % MuItemsRes.format_zen(amount), Color(0.4, 1.0, 0.5))
			_zen_dialog.visible = false
	else:
		if player.vault_zen < amount:
			show_msg("Rương không có đủ Zen để rút!", Color(1.0, 0.3, 0.2))
			return
		if player.zen + amount > MuPlayer.MAX_INV_ZEN:
			show_msg("Túi đồ không thể chứa quá 2 Tỷ Zen!", Color(1.0, 0.3, 0.2))
			return
		if player.vault_withdraw_zen(amount):
			if MuAudioManager:
				MuAudioManager.play_coin_pickup()
			show_msg("Đã rút %s Zen về túi đồ!" % MuItemsRes.format_zen(amount), Color(0.4, 1.0, 0.5))
			_zen_dialog.visible = false
	update_display()

# ------------------------------------------------------------------ Hộp thoại Mã PIN Bảo Vệ
func _build_pin_dialog() -> void:
	_pin_dialog = Control.new()
	_pin_dialog.custom_minimum_size = Vector2(170, 120) * S
	_pin_dialog.size = Vector2(170, 120) * S
	_pin_dialog.position = Vector2(10, 245) * S
	_pin_dialog.visible = false
	_pin_dialog.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.size = _pin_dialog.size
	bg.color = Color(0.08, 0.07, 0.06, 0.96)
	_pin_dialog.add_child(bg)

	var border := ReferenceRect.new()
	border.size = _pin_dialog.size
	border.border_color = Color(0.7, 0.6, 0.4)
	border.border_width = 1.5
	border.editor_only = false
	_pin_dialog.add_child(border)

	_pin_dialog_title = Label.new()
	_pin_dialog_title.text = "Nhập Mã PIN (4 số)"
	_pin_dialog_title.add_theme_font_size_override("font_size", 13)
	_pin_dialog_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_pin_dialog_title.position = Vector2(10, 10) * S
	_pin_dialog_title.size = Vector2(150, 20) * S
	_pin_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pin_dialog.add_child(_pin_dialog_title)

	_pin_input = LineEdit.new()
	_pin_input.placeholder_text = "4 chữ số..."
	_pin_input.max_length = 4
	_pin_input.secret = true
	_pin_input.position = Vector2(25, 40) * S
	_pin_input.size = Vector2(120, 26) * S
	_pin_input.add_theme_font_size_override("font_size", 14)
	_pin_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pin_dialog.add_child(_pin_input)

	var btn_ok := Button.new()
	btn_ok.text = "Xác Nhận"
	btn_ok.position = Vector2(15, 80) * S
	btn_ok.size = Vector2(65, 24) * S
	btn_ok.add_theme_font_size_override("font_size", 11)
	btn_ok.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	btn_ok.pressed.connect(_on_pin_confirm_pressed)
	_pin_dialog.add_child(btn_ok)

	var btn_canc := Button.new()
	btn_canc.text = "Hủy"
	btn_canc.position = Vector2(90, 80) * S
	btn_canc.size = Vector2(65, 24) * S
	btn_canc.add_theme_font_size_override("font_size", 11)
	btn_canc.pressed.connect(func(): _pin_dialog.visible = false)
	_pin_dialog.add_child(btn_canc)

	body.add_child(_pin_dialog)

func _on_lock_button_pressed() -> void:
	if player == null:
		return
	if player.vault_locked:
		# Đang khóa -> Yêu cầu nhập PIN để mở
		_pin_mode = "unlock"
		_pin_dialog_title.text = "Mở Khóa Rương"
		_pin_input.text = ""
		_pin_dialog.visible = true
		_pin_dialog.move_to_front()
		_pin_input.grab_focus()
	else:
		if player.vault_pin == "":
			# Chưa có PIN -> Cài PIN mới
			_pin_mode = "set"
			_pin_dialog_title.text = "Cài Mã PIN Mới"
			_pin_input.text = ""
			_pin_dialog.visible = true
			_pin_dialog.move_to_front()
			_pin_input.grab_focus()
		else:
			# Đã có PIN và đang mở -> Khóa lại ngay
			player.lock_vault()
			show_msg("Rương đồ đã được KHÓA an toàn!", Color(1.0, 0.8, 0.3))
			update_display()

func _on_pin_confirm_pressed() -> void:
	if player == null:
		return
	var pin := _pin_input.text.strip_edges()
	if pin.length() < 4 or not pin.is_valid_int():
		show_msg("Mã PIN phải gồm đúng 4 chữ số!", Color(1.0, 0.4, 0.3))
		return

	if _pin_mode == "set":
		player.set_vault_pin(pin)
		player.lock_vault()
		show_msg("Đã cài mã PIN và khóa rương thành công!", Color(0.4, 1.0, 0.5))
		_pin_dialog.visible = false
	elif _pin_mode == "unlock":
		if player.unlock_vault(pin):
			show_msg("Mở khóa rương thành công!", Color(0.4, 1.0, 0.5))
			_pin_dialog.visible = false
		else:
			show_msg("Mã PIN không chính xác!", Color(1.0, 0.3, 0.2))
	update_display()
