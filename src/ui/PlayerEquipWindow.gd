extends Control
class_name PlayerEquipWindow

## Xem trang bị của người chơi khác.
## Dựng bằng đúng phần "paperdoll" của CNewUIMyInventory (my_inventory.rcss): khung 190x429,
## 12 ô trang bị cùng toạ độ + ảnh nền ô (newui_item_cap / upper / weapon(r)...), đồ vẽ bằng ảnh 3D như túi đồ.
## Phía dưới (thay cho lưới túi đồ 8x8) là thông tin nhân vật trình bày theo kiểu CTrade:
## dải tên newui_Account_title, cấp / class / guild, vạch newui_myquest_Line, tóm tắt trang bị, dải Zen.
## Chỉ xem: rê chuột hiện bảng mô tả đồ, không nhấc / mặc được.

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const InventoryWindowRes = preload("res://src/ui/InventoryWindow.gd")

const S := 1.5
const W := 190.0
const H := 429.0
const C_TEXT_INFO := Color("#d2e6ff")
const C_CLASS := Color("#ffd927")
const C_HINT := Color("#ffdc96")

var target: MuOtherPlayer = null
var _slots: Dictionary = {}
var _icon_layer: Control
var _hover_slot := ""
var _title: Label
var _name: Label
var _class: Label
var _level: Label
var _guild: Label
var _summary: Label

func _ready() -> void:
	visible = false
	add_to_group("MuPlayerEquipWindow")
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30
	_title = MuUiSkinRes.build_frame(self, "Trang Bị")
	MuUiSkinRes.close_button(self, W, close)
	var eq: Dictionary = InventoryWindowRes.EQUIP
	for slot in eq:
		var d: Array = eq[slot]
		var b := Control.new()
		b.position = Vector2(d[0], d[1]) * S
		b.size = Vector2(d[2], d[3]) * S
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_entered.connect(_on_slot_hover.bind(slot, true))
		b.mouse_exited.connect(_on_slot_hover.bind(slot, false))
		b.draw.connect(_draw_slot_bg.bind(b, slot))
		add_child(b)
		_slots[slot] = b
	_icon_layer = Control.new()
	_icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_layer.size = size
	_icon_layer.draw.connect(_draw_icons)
	add_child(_icon_layer)

	# --- thông tin nhân vật (vùng lưới túi đồ y = 208..368)
	_strip("newui_account_title", Vector2(11, 206), Vector2(171, 26))
	_name = _label("", Vector2(11, 211), Vector2(171, 16), 14, C_TEXT_INFO)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class = _label("", Vector2(16, 236), Vector2(160, 14), 12, C_CLASS)
	_level = _label("", Vector2(16, 252), Vector2(160, 14), 12, Color.WHITE)
	_guild = _label("", Vector2(16, 268), Vector2(160, 14), 12, Color("#d8d8d8"))
	var line := TextureRect.new()
	line.texture = MuUiSkinRes.tex("newui_myquest_line")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.position = Vector2(1, 286) * S
	line.size = Vector2(188, 2) * S
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	_summary = _label("", Vector2(16, 292), Vector2(160, 70), 11, C_HINT)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var b_exit := MuUiSkinRes.make_btn_2state("newui_exit_00", 36, 29, close)
	b_exit.position = Vector2(13, 391) * S
	b_exit.size = Vector2(36, 29) * S
	b_exit.tooltip_text = "Đóng"
	add_child(b_exit)
	var b_trade := MuUiSkinRes.make_btn_2state("newui_bt_accept", 36, 29, _on_trade_pressed)
	b_trade.position = Vector2(141, 391) * S
	b_trade.size = Vector2(36, 29) * S
	b_trade.tooltip_text = "Giao dịch"
	add_child(b_trade)
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

func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(maxf(0.0, vs.x * 0.5 - W * S - 20.0), maxf(0.0, (vs.y - H * S) * 0.5))

func open_for(p: MuOtherPlayer) -> void:
	if target and is_instance_valid(target) and target.equipment_changed.is_connected(_refresh):
		target.equipment_changed.disconnect(_refresh)
	target = p
	target.equipment_changed.connect(_refresh)
	_place()
	visible = true
	_refresh()
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func close() -> void:
	visible = false
	if target and is_instance_valid(target) and target.equipment_changed.is_connected(_refresh):
		target.equipment_changed.disconnect(_refresh)
	target = null
	var ui = MuItemUiRes.get_ui(get_tree())
	if ui:
		ui.hide_tip()

func _refresh() -> void:
	if target == null or not is_instance_valid(target):
		return
	_title.text = "Trang Bị"
	_name.text = target.character_name
	_class.text = target.get_class_display_name()
	_level.text = "Cấp độ: %d" % target.level
	_guild.text = "Guild: %s" % (target.guild_name if target.guild_name != "" else "-")
	_summary.text = _build_summary()
	for b in _slots.values():
		b.queue_redraw()
	_icon_layer.queue_redraw()

func _build_summary() -> String:
	var n_exc := 0
	var min_lv := 99
	var armor_count := 0
	var set_no := -1
	var same_set := true
	for slot in ["helm", "armor", "pants", "gloves", "boots"]:
		var it = target.equipment.get(slot)
		if not (it is Dictionary) or it.is_empty():
			same_set = false
			continue
		armor_count += 1
		min_lv = mini(min_lv, int(it.get("level", 0)))
		if set_no < 0:
			set_no = int(it.get("number", 0))
		elif set_no != int(it.get("number", 0)):
			same_set = false
	for it in target.equipment.values():
		if it is Dictionary and bool(it.get("excellent", false)):
			n_exc += 1
	var lines := PackedStringArray()
	if same_set and armor_count == 5:
		var nm := MuItemsRes.base_name(target.equipment["armor"]).replace(" Armor", "")
		lines.append("Bộ %s +%d (đủ 5 món)" % [nm, min_lv])
	else:
		lines.append("Giáp đang mặc: %d / 5 món" % armor_count)
	if n_exc > 0:
		lines.append("Đồ Excellent: %d món" % n_exc)
	var w = target.equipment.get("wings")
	if w is Dictionary and not w.is_empty():
		lines.append("Cánh: %s" % MuItemsRes.display_name(w))
	return "\n".join(lines)

func _on_trade_pressed() -> void:
	if target == null or not is_instance_valid(target):
		return
	var p := target
	close()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("request_trade_with"):
		hud.request_trade_with(p)

# ------------------------------------------------------------------ ô trang bị (giống InventoryWindow)
func _draw_slot_bg(b: Control, slot: String) -> void:
	var d: Array = InventoryWindowRes.EQUIP[slot]
	var t := MuUiSkinRes.tex(str(d[4]))
	var rc := Rect2(Vector2.ZERO, b.size)
	if t:
		b.draw_texture_rect(t, rc, false)
	else:
		b.draw_rect(rc, Color(0.1, 0.08, 0.06, 0.9))

func _draw_icons() -> void:
	if target == null or not is_instance_valid(target):
		return
	for slot in _slots:
		var b: Control = _slots[slot]
		var cur = target.equipment.get(slot)
		if not (cur is Dictionary) or cur.is_empty():
			continue
		var dst: int = MuItemsRes.durability_state(cur)
		if dst != 0:
			_icon_layer.draw_rect(Rect2(b.position + Vector2(1, 0) * S, b.size - Vector2(4, 4) * S), MuItemsRes.durability_tint(dst, 64.0 / 255.0))
		var icon: Texture2D = MuItemIconRes.live_icon(get_tree(), cur) if slot == _hover_slot else MuItemIconRes.icon(get_tree(), cur)
		if icon == null:
			continue
		var sz: Vector2i = MuItemsRes.size_of(cur)
		var isz := Vector2(sz) * 20.0 * S
		var an: Vector2 = MuItemIconRes.anchor_of(int(cur.get("group", 0)), int(cur.get("number", 0)))
		var rc := Rect2(b.position, b.size)
		_icon_layer.draw_texture_rect(icon, MuItemIconRes.overflow_rect(Rect2(rc.position + rc.size * an - isz * an, isz), sz), false)

func _on_slot_hover(slot: String, inside: bool) -> void:
	if inside:
		_hover_slot = slot
	elif _hover_slot == slot:
		_hover_slot = ""
		MuItemIconRes.stop_live()
	_icon_layer.queue_redraw()
	var ui = MuItemUiRes.get_ui(get_tree())
	if ui == null:
		return
	var cur = target.equipment.get(slot) if target and is_instance_valid(target) else null
	if inside and cur is Dictionary and not cur.is_empty():
		ui.show_tip(MuItemsRes.tooltip(cur))
	else:
		ui.hide_tip()

func _process(d: float) -> void:
	if not visible:
		return
	if target == null or not is_instance_valid(target):
		close()
		return
	var hero = get_tree().get_first_node_in_group("Player")
	if hero and hero.global_position.distance_to(target.global_position) > 15.0:
		close()
		return
	if _hover_slot != "":
		MuItemIconRes.spin(d)
		_icon_layer.queue_redraw()
	elif Engine.get_process_frames() % 15 == 0:
		_icon_layer.queue_redraw()   # ảnh đồ là ViewportTexture: vẽ lại để nhận ảnh đã render

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud:
			hud._bring_modal_to_front(self)
	accept_event()
