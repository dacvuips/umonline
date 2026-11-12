extends Control
class_name JewelBundleWindow

## Cửa sổ NPC Lahap / Jeweler Raul: gộp ngọc lẻ thành cụm (10 / 20 / 30 viên) và tách cụm ngọc.
## Luật theo OpenMU (ItemStackAction): phí gộp (N / 10) x 500.000 Zen, phí tách 1.000.000 Zen. Logic ở MuJewelBundle.

const MuJewelBundleRes = preload("res://src/mu/MuJewelBundle.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")

var player: MuPlayer = null
var npc: Node3D = null
var _list: VBoxContainer
var _msg: Label
var _zen: Label
var _panel: PanelContainer

func _ready() -> void:
	visible = false
	add_to_group("MuJewelBundleWindow")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	sb.border_color = Color(0.75, 0.62, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(520, 0)
	add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	_panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "Thương Nhân Ngọc — Gộp / Tách ngọc"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(self.close)
	head.add_child(close)
	_zen = Label.new()
	_zen.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	root.add_child(_zen)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 380)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_msg)

func open_window(p: MuPlayer, n: Node3D = null) -> void:
	player = p
	npc = n
	visible = true
	_msg.text = "Gộp 10 / 20 / 30 viên cùng loại thành 1 cụm. Phí gộp 500.000 Zen mỗi 10 viên, phí tách 1.000.000 Zen."
	_msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_refresh()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(maxf((vs.x - 520.0) * 0.5 - 120.0, 8.0), 40.0)

func close() -> void:
	visible = false

func _refresh() -> void:
	if player == null:
		return
	for c in _list.get_children():
		c.queue_free()
	_zen.text = "Zen: %s" % MuItemsRes.format_zen(player.zen)
	_add_header("GỘP NGỌC")
	for i in MuJewelBundleRes.TYPES.size():
		var row := HBoxContainer.new()
		var have := MuJewelBundleRes.count_singles(player, i)
		var name := Label.new()
		name.text = "%s  (có %d)" % [str(MuJewelBundleRes.TYPES[i][0]), have]
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		for cnt in [10, 20, 30]:
			var b := Button.new()
			b.text = "x%d" % cnt
			b.tooltip_text = "Phí %s Zen" % MuItemsRes.format_zen(MuJewelBundleRes.combine_fee(cnt))
			b.disabled = have < cnt or player.zen < MuJewelBundleRes.combine_fee(cnt)
			b.pressed.connect(_on_combine.bind(i, cnt))
			row.add_child(b)
		_list.add_child(row)
	_add_header("TÁCH CỤM NGỌC (trong túi đồ)")
	var bundles := MuJewelBundleRes.list_bundles(player)
	if bundles.is_empty():
		var none := Label.new()
		none.text = "Không có cụm ngọc nào trong túi."
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list.add_child(none)
	for bd in bundles:
		var row2 := HBoxContainer.new()
		var lb := Label.new()
		lb.text = "%s — %d viên" % [MuItemsRes.display_name(bd["item"]), int(bd["pieces"])]
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(lb)
		var tb := Button.new()
		tb.text = "Tách (1.000.000 Zen)"
		tb.disabled = player.zen < MuJewelBundleRes.DISMANTLE_FEE
		tb.pressed.connect(_on_dismantle.bind(bd["item"]))
		row2.add_child(tb)
		_list.add_child(row2)

func _add_header(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 14)
	h.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	_list.add_child(h)

func _on_combine(type_idx: int, count: int) -> void:
	_report(MuJewelBundleRes.combine(player, type_idx, count))

func _on_dismantle(bundle: Dictionary) -> void:
	_report(MuJewelBundleRes.dismantle(player, bundle))

func _report(res: Dictionary) -> void:
	_msg.text = str(res["msg"])
	_msg.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if bool(res["ok"]) else Color(1.0, 0.4, 0.3))
	if bool(res["ok"]) and MuAudioManager:
		MuAudioManager.play_jewel_drop()    # eGem.wav: tiếng ngọc khi vật phẩm thay đổi (ReceiveModifyItem)
	elif MuAudioManager:
		MuAudioManager.play_ui_click()
	_refresh()
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.inventory_window:
		hud.inventory_window.update_display()
