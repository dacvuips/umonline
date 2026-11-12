extends Control
class_name ChaosMixWindow

## Cửa sổ Máy Hỗn Nguyên của Chaos Goblin (CNewUIMixInventory, Season 6 chuẩn Webzen).
## Lưới trộn 8 x 4 ô, giao diện và màu sắc chuẩn client gốc MU Online:
##   - Hàng 1: Tỉ lệ thuế là: 0% (xám trắng, căn giữa)
##   - Hàng 2: Trạng thái / Tên công thức (đỏ #FF2E2E khi chưa khớp, vàng #FFFF00 khi khớp)
##   - Hàng 3: Tỉ lệ Kết hợp thành công: %d% (trắng)
##   - Hàng 4: Số Zen cần thiết: %s (%s) (trắng)
##   - Lưới 8x4 ô item máy Chaos
##   - Dưới lưới: Dự đoán (Khả năng sử dụng), Checklist nguyên liệu (vàng = đủ, đỏ = thiếu 1 phần, trắng = chưa có)
##   - Cảnh báo thất bại (đỏ #FF3822)
##   - Nút swirl "Kết hợp" chuẩn MU Online (newui_bt_mix.png)
##   - Nút tra cứu "Công Thức Ép" popup

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuItemGridRes = preload("res://src/ui/MuItemGrid.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const MuChaosMixRes = preload("res://src/mu/MuChaosMix.gd")
const ChaosRecipeDialogRes = preload("res://src/ui/ChaosRecipeDialog.gd")

const S := 1.5
const W := 190.0
const H := 429.0
const COLS := 8
const ROWS := 4

var player: MuPlayer = null
var npc: Node3D = null
var items: Array = []
var body: Control
var grid = null

# UI labels
var _title: Label
var _tax_label: Label
var _status_name_label: Label
var _rate_label: Label
var _cost_label: Label
var _prediction_label: Label
var _checklist_box: VBoxContainer
var _warning_box: VBoxContainer
var _btn_mix_label: Label
var _btn_mix: TextureButton
var _btn_recipes: Button
var _recipe_dialog = null
var _busy := false

func _ready() -> void:
	visible = false
	add_to_group("MuChaosMixWindow")
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S
	mouse_filter = Control.MOUSE_FILTER_STOP

	body = Control.new()
	body.size = Vector2(W, H) * S
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.gui_input.connect(_on_body_input)
	add_child(body)

	_title = MuUiSkinRes.build_frame(body, "Máy Hỗn Nguyên")
	MuUiSkinRes.close_button(body, W, close)

	# 1. Tỉ lệ thuế là: 0% (căn giữa)
	_tax_label = _make_mu_label("Tỉ lệ thuế là: 0%", 10, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_tax_label.position = Vector2(14, 25) * S
	_tax_label.size = Vector2(W - 28, 13) * S
	body.add_child(_tax_label)

	# 2. Tên công thức / thông báo lỗi (căn trái)
	_status_name_label = _make_mu_label("Món đồ này không phù hợp", 11, Color(1.0, 0.18, 0.18), HORIZONTAL_ALIGNMENT_LEFT)
	_status_name_label.position = Vector2(15, 38) * S
	_status_name_label.size = Vector2(W - 30, 14) * S
	body.add_child(_status_name_label)

	# 3. Tỉ lệ kết hợp thành công (căn trái)
	_rate_label = _make_mu_label("Tỉ lệ Kết hợp thành công: 0%", 11, Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	_rate_label.position = Vector2(15, 51) * S
	_rate_label.size = Vector2(W - 30, 14) * S
	body.add_child(_rate_label)

	# 4. Số Zen cần thiết (căn trái)
	_cost_label = _make_mu_label("Số Zen cần thiết: 0 (0)", 11, Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	_cost_label.position = Vector2(15, 64) * S
	_cost_label.size = Vector2(W - 30, 14) * S
	body.add_child(_cost_label)

	# 5. Lưới máy Chaos 8x4 ô
	grid = MuItemGridRes.new()
	grid.setup(COLS, ROWS, 20.0 * S)
	grid.position = Vector2(15, 79) * S
	grid.cell_clicked.connect(_on_cell)
	grid.hover_changed.connect(_on_hover)
	body.add_child(grid)

	# 6. Dưới lưới: Dự đoán công thức "Khả năng sử dụng: ..."
	_prediction_label = _make_mu_label("", 11, Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	_prediction_label.position = Vector2(15, 163) * S
	_prediction_label.size = Vector2(W - 30, 14) * S
	body.add_child(_prediction_label)

	# 7. Danh sách checklist nguyên liệu
	_checklist_box = VBoxContainer.new()
	_checklist_box.position = Vector2(15, 178) * S
	_checklist_box.size = Vector2(W - 30, 70) * S
	_checklist_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_checklist_box.add_theme_constant_override("separation", 1)
	body.add_child(_checklist_box)

	# 8. Cảnh báo thất bại màu đỏ chuẩn MU Online
	_warning_box = VBoxContainer.new()
	_warning_box.position = Vector2(15, 252) * S
	_warning_box.size = Vector2(W - 30, 65) * S
	_warning_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_box.add_theme_constant_override("separation", 2)
	body.add_child(_warning_box)

	# 9. Chữ "Kết hợp" căn giữa trên nút
	_btn_mix_label = _make_mu_label("Kết hợp", 11, Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_btn_mix_label.position = Vector2(0, 328) * S
	_btn_mix_label.size = Vector2(W, 14) * S
	body.add_child(_btn_mix_label)

	# 10. Nút xoay kết hợp chuẩn Webzen (newui_bt_mix.png: 44x35)
	var mix_tex: Texture2D = MuUiSkinRes.tex("newui_bt_mix")
	_btn_mix = TextureButton.new()
	_btn_mix.ignore_texture_size = true
	_btn_mix.stretch_mode = TextureButton.STRETCH_SCALE
	if mix_tex:
		_btn_mix.texture_normal = MuUiSkinRes.atlas_sub(mix_tex, Rect2(0, 0, 44, 35))
		_btn_mix.texture_pressed = MuUiSkinRes.atlas_sub(mix_tex, Rect2(0, 35, 44, 35))
		_btn_mix.texture_hover = MuUiSkinRes.atlas_sub(mix_tex, Rect2(0, 35, 44, 35))
	_btn_mix.position = Vector2((W - 44) * 0.5, 344) * S
	_btn_mix.size = Vector2(44, 35) * S
	_btn_mix.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_mix.pressed.connect(_on_mix_pressed)
	body.add_child(_btn_mix)

	# 11. Nút mở popup "📖 Công Thức"
	_btn_recipes = _create_recipe_guide_btn("📖 Công Thức", _on_recipes_pressed)
	_btn_recipes.position = Vector2((W - 96) * 0.5, 396) * S
	_btn_recipes.size = Vector2(96, 20) * S
	body.add_child(_btn_recipes)

	_place()
	get_viewport().size_changed.connect(_place)
	_refresh()

func _make_mu_label(text: String, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _create_recipe_guide_btn(btn_text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = btn_text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(cb)

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.10, 0.08, 0.9)
	sb_n.border_width_left = 1
	sb_n.border_width_top = 1
	sb_n.border_width_right = 1
	sb_n.border_width_bottom = 1
	sb_n.border_color = Color(0.65, 0.52, 0.3, 0.85)
	sb_n.corner_radius_top_left = 3
	sb_n.corner_radius_top_right = 3
	sb_n.corner_radius_bottom_left = 3
	sb_n.corner_radius_bottom_right = 3

	var sb_h: StyleBoxFlat = sb_n.duplicate()
	sb_h.bg_color = Color(0.24, 0.18, 0.12, 0.95)
	sb_h.border_color = Color(0.95, 0.82, 0.45, 0.95)

	var sb_p: StyleBoxFlat = sb_n.duplicate()
	sb_p.bg_color = Color(0.08, 0.07, 0.05, 0.95)
	sb_p.border_color = Color(0.5, 0.4, 0.25, 0.8)

	b.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.85))
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_p)
	return b

func _format_zen_with_commas(n: int) -> String:
	var s := str(abs(n))
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return ("-" if n < 0 else "") + res

func _on_recipes_pressed() -> void:
	if _recipe_dialog == null:
		_recipe_dialog = ChaosRecipeDialogRes.new()
		var p = get_parent()
		if p:
			p.add_child(_recipe_dialog)
		else:
			add_child(_recipe_dialog)
	_recipe_dialog.open_dialog()

func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(vs.x - 2 * W * S, maxf(0.0, (vs.y - H * S) * 0.5))

func _ui():
	return MuItemUiRes.get_ui(get_tree())

func open_mix(p_player: MuPlayer, p_npc: Node3D = null) -> void:
	player = p_player
	npc = p_npc
	_title.text = "Máy Hỗn Nguyên"
	_place()
	visible = true
	_refresh()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.inventory_window:
		hud.inventory_window.visible = true
		hud.inventory_window.update_display()
	if MuAudioManager:
		MuAudioManager.play_ui_window()

## Đóng máy: trả mọi đồ trong máy về túi (như OpenMU trả TemporaryStorage về Inventory)
func close() -> void:
	if _recipe_dialog and is_instance_valid(_recipe_dialog):
		_recipe_dialog.close()
	if player:
		for it in items.duplicate():
			if player.inv_add(it):
				items.erase(it)
		if not items.is_empty():
			show_msg("Túi đồ đã đầy! Hãy dọn túi trước khi đóng máy Chaos.", Color(1.0, 0.3, 0.2))
			_refresh()
			return
	visible = false
	var ui = _ui()
	if ui:
		ui.hide_tip()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.inventory_window:
		hud.inventory_window.update_display()

func show_msg(text: String, col: Color = Color.WHITE) -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(text, col)

func _chat(text: String) -> void:
	var chat = get_tree().get_first_node_in_group("ChatWindow")
	if chat and chat.has_method("add_system_message"):
		chat.add_system_message(text)

# ------------------------------------------------------------------ lưới máy Chaos
func _fits(x: int, y: int, w: int, h: int) -> bool:
	if x < 0 or y < 0 or x + w > COLS or y + h > ROWS:
		return false
	for it in items:
		var s: Vector2i = MuItemsRes.size_of(it)
		if x < int(it["x"]) + s.x and int(it["x"]) < x + w and y < int(it["y"]) + s.y and int(it["y"]) < y + h:
			return false
	return true

func _place_item(it: Dictionary, x: int, y: int) -> bool:
	var s: Vector2i = MuItemsRes.size_of(it)
	if not _fits(x, y, s.x, s.y):
		return false
	var n := it.duplicate()
	n["x"] = x
	n["y"] = y
	items.append(n)
	_refresh()
	return true

## Bỏ đồ vào ô trống đầu tiên của máy
func add_item(it: Dictionary) -> bool:
	var s: Vector2i = MuItemsRes.size_of(it)
	for y in ROWS:
		for x in COLS:
			if _fits(x, y, s.x, s.y):
				return _place_item(it, x, y)
	return false

func _clear_vbox(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()

func _refresh() -> void:
	if grid == null:
		return
	grid.set_items(items)
	_clear_vbox(_checklist_box)
	_clear_vbox(_warning_box)

	var ev: Dictionary = MuChaosMixRes.evaluate(items)
	var is_ok: bool = bool(ev.get("ok", false))
	var rate: int = int(ev.get("rate", 0))
	var cost: int = int(ev.get("cost", 0))
	var tax_rate: int = int(ev.get("tax_rate", 0))
	var total_cost: int = cost + int(cost * tax_rate / 100.0)

	_tax_label.text = "Tỉ lệ thuế là: %d%%" % tax_rate

	# Khi chưa có đồ trong máy
	if items.is_empty():
		_status_name_label.text = ""
		_rate_label.text = "Tỉ lệ Kết hợp thành công: 0%"
		_rate_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		_cost_label.text = "Số Zen cần thiết: 0 (0)"
		_cost_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		_prediction_label.text = ""
		_btn_mix.disabled = true
		_btn_mix.modulate = Color(0.35, 0.35, 0.35, 0.6)
		_btn_mix_label.modulate = Color(0.5, 0.5, 0.5, 0.7)
		return

	# Đồ trong máy chưa đủ hoặc không phù hợp (như ảnh 1 của user)
	if not is_ok:
		_status_name_label.text = str(ev.get("name", "Món đồ này không phù hợp"))
		_status_name_label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18)) # Đỏ chuẩn MU

		_rate_label.text = "Tỉ lệ Kết hợp thành công: 0%"
		_rate_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

		_cost_label.text = "Số Zen cần thiết: 0 (0)"
		_cost_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

		# Hiển thị Khả năng sử dụng
		var pred: String = str(ev.get("prediction", ""))
		_prediction_label.text = pred
		_checklist_box.position = Vector2(15, 178) * S

		# Checklist nguyên liệu (vàng: đã đủ, đỏ: thiếu 1 phần, trắng: chưa có)
		var cl: Array = ev.get("checklist", [])
		for entry in cl:
			var txt: String = str(entry.get("text", ""))
			var is_ready: bool = bool(entry.get("ready", false))
			var is_part: bool = bool(entry.get("partial", false))
			var c_col := Color(1.0, 1.0, 0.0) if is_ready else (Color(1.0, 0.2, 0.13) if is_part else Color(1.0, 1.0, 1.0))
			var lbl := _make_mu_label(txt, 11, c_col, HORIZONTAL_ALIGNMENT_LEFT)
			_checklist_box.add_child(lbl)

		_btn_mix.disabled = true
		_btn_mix.modulate = Color(0.35, 0.35, 0.35, 0.6)
		_btn_mix_label.modulate = Color(0.5, 0.5, 0.5, 0.7)
		return

	# Đã đúng công thức (như ảnh 2 của user)
	_status_name_label.text = str(ev.get("name", ""))
	_status_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) # Vàng chuẩn MU

	_rate_label.text = "Tỉ lệ Kết hợp thành công: %d%%" % rate
	_rate_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	var zen_str := _format_zen_with_commas(cost)
	var tot_str := _format_zen_with_commas(total_cost)
	_cost_label.text = "Số Zen cần thiết: %s (%s)" % [zen_str, tot_str]

	var enough_zen: bool = (player != null and player.zen >= total_cost)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if enough_zen else Color(1.0, 0.2, 0.15))

	# Khi đã khớp công thức, checklist bắt đầu ngay dưới lưới
	_prediction_label.text = ""
	_checklist_box.position = Vector2(15, 163) * S

	var cl2: Array = ev.get("checklist", [])
	for entry in cl2:
		var txt: String = str(entry.get("text", ""))
		# Ở trạng thái thành công, mọi nguyên liệu đều màu vàng #FFFF00
		var lbl := _make_mu_label(txt, 11, Color(1.0, 1.0, 0.0), HORIZONTAL_ALIGNMENT_LEFT)
		_checklist_box.add_child(lbl)

	# Khối cảnh báo đỏ chuẩn MU Online:
	# "Nâng cấp thành công đồ cấp 10 -> 15 ."
	# "Hãy chú ý!"
	# "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."
	var warns: Array = ev.get("warnings", [])
	for w_txt in warns:
		var w_lbl := _make_mu_label(str(w_txt), 11, Color(1.0, 0.22, 0.13), HORIZONTAL_ALIGNMENT_LEFT)
		_warning_box.add_child(w_lbl)

	# Bật nút Kết hợp
	var can_mix: bool = enough_zen and not _busy
	_btn_mix.disabled = not can_mix
	_btn_mix.modulate = Color.WHITE if can_mix else Color(0.35, 0.35, 0.35, 0.6)
	_btn_mix_label.modulate = Color.WHITE if can_mix else Color(0.5, 0.5, 0.5, 0.7)

func _process(_d: float) -> void:
	if not visible:
		return
	if player and npc and is_instance_valid(npc) and player.global_position.distance_to(npc.global_position) > 6.0:
		close()
		return
	var ui = _ui()
	if ui:
		if ui.held.is_empty():
			grid.preview_size = Vector2i.ZERO
		else:
			grid.preview_size = MuItemsRes.size_of(ui.held)
			var hc: Vector2i = grid.hover_cell
			grid.preview_ok = _fits(hc.x, hc.y, grid.preview_size.x, grid.preview_size.y)

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if visible and k and k.pressed and k.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _on_cell(c: int, r: int, button: int) -> void:
	if player == null or _busy:
		return
	var ui = _ui()
	if ui == null:
		return
	if button == MOUSE_BUTTON_RIGHT:
		var it: Dictionary = grid.item_at(c, r)
		if it.is_empty() or not ui.held.is_empty():
			return
		if player.inv_add(it):
			items.erase(it)
			if MuAudioManager:
				MuAudioManager.play_item_pickup()
		else:
			show_msg("Túi đồ đã đầy!", Color(1.0, 0.3, 0.2))
		_refresh()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if ui.held.is_empty():
		var it2: Dictionary = grid.item_at(c, r)
		if it2.is_empty():
			return
		items.erase(it2)
		ui.hold(it2, "mix")
		ui.hide_tip()
		if MuAudioManager:
			MuAudioManager.play_item_pickup()
	else:
		if _place_item(ui.held, c, r):
			ui.drop_held()
			if MuAudioManager:
				MuAudioManager.play_item_pickup()
	_refresh()

func _on_body_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _busy:
		var ui = _ui()
		if ui and not ui.held.is_empty() and add_item(ui.held):
			ui.drop_held()
			if MuAudioManager:
				MuAudioManager.play_item_pickup()
	accept_event()

func _on_hover(it: Dictionary) -> void:
	var ui = _ui()
	if ui == null:
		return
	if it.is_empty():
		ui.hide_tip()
	else:
		ui.show_tip(MuItemsRes.tooltip(it))

# ------------------------------------------------------------------ trộn
func _on_mix_pressed() -> void:
	if player == null or _busy or items.is_empty():
		return
	var ev: Dictionary = MuChaosMixRes.evaluate(items)
	if not bool(ev.get("ok", false)):
		show_msg(str(ev.get("error", "Không đúng công thức")), Color(1.0, 0.4, 0.3))
		return
	var cost := int(ev.get("cost", 0))
	var tax_rate: int = int(ev.get("tax_rate", 0))
	var total_cost: int = cost + int(cost * tax_rate / 100.0)
	if player.zen < total_cost:
		show_msg("Không đủ Zen để trộn! (cần %s Zen)" % _format_zen_with_commas(total_cost), Color(1.0, 0.3, 0.2))
		return
	_busy = true
	_btn_mix.disabled = true
	_btn_mix.modulate = Color(0.35, 0.35, 0.35, 0.6)
	_btn_mix_label.modulate = Color(0.5, 0.5, 0.5, 0.7)

	player.add_zen(-total_cost)
	if MuAudioManager:
		MuAudioManager.play_sound_file("eMix.wav")
	# hiệu ứng xoay chờ ngắn như máy Chaos gốc trước khi trả kết quả
	await get_tree().create_timer(0.8).timeout
	var res: Dictionary = MuChaosMixRes.execute(items)
	items = []
	for it in res["items"]:
		if not add_item(it):
			player.inv_add(it)
	_busy = false
	if bool(res["success"]):
		show_msg("Trộn Chaos thành công! (%s)" % str(res["name"]), Color(0.4, 1.0, 0.5))
		_chat("[color=#66FF88]Chaos combination has succeeded[/color] — %s" % str(res["name"]))
		if MuAudioManager:
			MuAudioManager.play_jewel_drop()      # eGem.wav (eMix.wav đã phát lúc bắt đầu trộn)
	else:
		show_msg("Trộn Chaos thất bại! Đã mất nguyên liệu.", Color(1.0, 0.35, 0.3))
		_chat("[color=#FF6655]Chaos combination has failed[/color] — %s" % str(res["name"]))
		if MuAudioManager:
			MuAudioManager.play_sound_file("eBreak.wav")
	_refresh()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.inventory_window:
		hud.inventory_window.update_display()
