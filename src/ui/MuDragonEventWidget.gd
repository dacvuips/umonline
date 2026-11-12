extends Control
class_name MuDragonEventWidget

## Giao Diện Sự Kiện Rồng Đỏ / Binh Đoàn Hoàng Kim (Red Dragon Invasion HUD Widget)
## - Xuất hiện nổi bật khi sự kiện Rồng Đỏ / Rồng Vàng bắt đầu
## - Biểu tượng Đầu Rồng Đỏ rực lửa nhấp nháy hiệu ứng hào quang ngọn lửa (Fire Aura Pulse)
## - Tiêu đề Rực Đỏ Vàng: "RỒNG ĐỎ XÂM LĂNG" / "BINH ĐOÀN HOÀNG KIM"
## - Đồng hồ đếm ngược thời gian sự kiện theo thời gian thực (Real-time Event Countdown)
## - Hiển thị vị trí xuất hiện: "Lorencia • Noria • Devias"
## - Nút [⚔️ SĂN RỒNG] dịch chuyển / tìm đường nhanh đến chiến trường
## - Nút thu nhỏ [➖] thành huy hiệu nhỏ gọn bên cạnh Mini Map tránh vướng màn hình
## - Tự động trượt vào (Slide-in) khi có rồng, tự động trượt ra (Slide-out) khi kết thúc!

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")

var _panel_box: PanelContainer
var _lbl_title: Label
var _lbl_map: Label
var _lbl_timer: Label
var _btn_hunt: Button
var _btn_toggle: Button
var _icon_rect: TextureRect
var _badge_button: Button
var _btn_close: Button
var _is_dismissed: bool = false

var _is_collapsed: bool = false
var _is_active: bool = false
var _current_event_id: String = ""
var _pulse_tween: Tween = null
var _slide_tween: Tween = null
var _update_timer: float = 0.0

const W_EXPANDED := 210.0
const H_EXPANDED := 94.0
const BADGE_SIZE := 46.0

func _ready() -> void:
	name = "MuDragonEventWidget"
	z_index = 45 # Nổi trên nền game, dưới modal dialogs
	mouse_filter = Control.MOUSE_FILTER_PASS

	anchors_preset = Control.PRESET_TOP_RIGHT
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0

	_apply_position()
	_build_ui()

	# Khởi đầu ẩn ngoài màn hình
	visible = false
	modulate.a = 0.0

	get_viewport().size_changed.connect(_apply_position)

func _apply_position() -> void:
	# Bố trí ở góc trên bên phải, bên dưới MiniMap & TargetInfo (TargetInfo kết thúc ở Y = 218)
	# Đặt tại Y = 224, cách lề phải 15px
	offset_left = -225.0
	offset_right = -15.0
	offset_top = 224.0
	offset_bottom = 224.0 + H_EXPANDED
	custom_minimum_size = Vector2(W_EXPANDED, H_EXPANDED)
	size = Vector2(W_EXPANDED, H_EXPANDED)
	if _badge_button:
		_badge_button.offset_left = -BADGE_SIZE - 15
		_badge_button.offset_right = -15
		_badge_button.offset_top = 224.0
		_badge_button.offset_bottom = 224.0 + BADGE_SIZE

func _build_ui() -> void:
	# 1. Khung chính dạng Thẻ Sự Kiện Dark Fantasy Viền Lửa Đỏ
	_panel_box = PanelContainer.new()
	_panel_box.name = "PanelBox"
	_panel_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_box.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.04, 0.04, 0.92) # Nền đỏ đen huyền ảo
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.35, 0.15, 0.95) # Viền cam đỏ rực lửa
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.8, 0.15, 0.05, 0.45)
	sb.shadow_size = 6
	_panel_box.add_theme_stylebox_override("panel", sb)
	add_child(_panel_box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_panel_box.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 3)
	margin.add_child(main_vbox)

	# Hàng 1: Icon Rồng + Tiêu Đề + Nút Thu Nhỏ
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(header_hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "🔥🐉"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(icon_lbl)

	_lbl_title = Label.new()
	_lbl_title.text = "RỒNG ĐỎ XÂM LĂNG"
	_lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_title.add_theme_font_size_override("font_size", 12)
	_lbl_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Chữ vàng viền đỏ
	_lbl_title.add_theme_color_override("font_outline_color", Color(0.6, 0.05, 0.0, 1.0))
	_lbl_title.add_theme_constant_override("outline_size", 3)
	header_hbox.add_child(_lbl_title)

	_btn_toggle = Button.new()
	_btn_toggle.text = "➖"
	_btn_toggle.flat = true
	_btn_toggle.custom_minimum_size = Vector2(22, 22)
	_btn_toggle.add_theme_font_size_override("font_size", 10)
	_btn_toggle.pressed.connect(_on_toggle_collapsed)
	header_hbox.add_child(_btn_toggle)
	_btn_close = Button.new()
	_btn_close.text = "✖"
	_btn_close.flat = true
	_btn_close.custom_minimum_size = Vector2(22, 22)
	_btn_close.add_theme_font_size_override("font_size", 10)
	_btn_close.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	_btn_close.pressed.connect(_on_close_pressed)
	header_hbox.add_child(_btn_close)

	# Hàng 2: Bản đồ xuất hiện + Đồng hồ đếm ngược
	var info_hbox := HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(info_hbox)

	_lbl_map = Label.new()
	_lbl_map.text = "📍 Lorencia, Noria"
	_lbl_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_map.add_theme_font_size_override("font_size", 10)
	_lbl_map.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7))
	info_hbox.add_child(_lbl_map)

	_lbl_timer = Label.new()
	_lbl_timer.text = "⏱️ 14:59"
	_lbl_timer.add_theme_font_size_override("font_size", 11)
	_lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2)) # Đỏ cam
	_lbl_timer.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_lbl_timer.add_theme_constant_override("outline_size", 2)
	info_hbox.add_child(_lbl_timer)

	# Hàng 3: Nút hành động "SĂN RỒNG NGAY"
	_btn_hunt = Button.new()
	_btn_hunt.text = "⚔️ SĂN RỒNG NGAY (ĐẾN BÃI)"
	_btn_hunt.custom_minimum_size = Vector2(0, 24)
	_btn_hunt.add_theme_font_size_override("font_size", 10)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.65, 0.15, 0.05, 0.95) # Đỏ thẫm
	btn_sb.border_width_left = 1
	btn_sb.border_width_top = 1
	btn_sb.border_width_right = 1
	btn_sb.border_width_bottom = 1
	btn_sb.border_color = Color(1.0, 0.75, 0.2)
	btn_sb.corner_radius_top_left = 4
	btn_sb.corner_radius_top_right = 4
	btn_sb.corner_radius_bottom_left = 4
	btn_sb.corner_radius_bottom_right = 4
	_btn_hunt.add_theme_stylebox_override("normal", btn_sb)

	var btn_hover_sb := btn_sb.duplicate() as StyleBoxFlat
	btn_hover_sb.bg_color = Color(0.85, 0.22, 0.08, 1.0)
	btn_hover_sb.border_color = Color(1.0, 0.95, 0.4)
	_btn_hunt.add_theme_stylebox_override("hover", btn_hover_sb)

	_btn_hunt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_btn_hunt.pressed.connect(_on_hunt_button_pressed)
	main_vbox.add_child(_btn_hunt)

	# 2. Huy hiệu thu nhỏ (Collapsed Badge Icon)
	_badge_button = Button.new()
	_badge_button.name = "DragonBadge"
	_badge_button.text = "🔥\n15m"
	_badge_button.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge_button.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge_button.anchors_preset = Control.PRESET_TOP_RIGHT
	_badge_button.anchor_left = 1.0
	_badge_button.anchor_right = 1.0
	_badge_button.offset_left = -BADGE_SIZE - 10
	_badge_button.offset_right = -10
	_badge_button.offset_top = 175.0
	_badge_button.offset_bottom = 175.0 + BADGE_SIZE

	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.2, 0.05, 0.05, 0.95)
	badge_sb.border_width_left = 2
	badge_sb.border_width_top = 2
	badge_sb.border_width_right = 2
	badge_sb.border_width_bottom = 2
	badge_sb.border_color = Color(1.0, 0.6, 0.1)
	badge_sb.corner_radius_top_left = 8
	badge_sb.corner_radius_top_right = 8
	badge_sb.corner_radius_bottom_left = 8
	badge_sb.corner_radius_bottom_right = 8
	_badge_button.add_theme_stylebox_override("normal", badge_sb)
	_badge_button.add_theme_font_size_override("font_size", 10)
	_badge_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_badge_button.pressed.connect(_on_toggle_collapsed)
	_badge_button.visible = false
	add_child(_badge_button)

	_start_pulse_animation()

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= 1.0:
		_update_timer = 0.0
		_sync_with_event()

func _sync_with_event() -> void:
	var mgr := get_tree().get_first_node_in_group("MuEventManager") if get_tree() else null
	if not mgr:
		return

	var is_red: bool = false
	var is_gold: bool = false
	var info: Dictionary = {}

	if mgr.has_method("is_event_active"):
		is_red = mgr.is_event_active("red_dragon")
		is_gold = mgr.is_event_active("golden_invasion")
		if is_gold:
			info = mgr.get_event_info("golden_invasion")
		elif is_red:
			info = mgr.get_event_info("red_dragon")
	else:
		var all: Array = mgr.get_all_events_status() if mgr.has_method("get_all_events_status") else []
		for ev in all:
			if ev.get("id") == "golden_invasion" and ev.get("state") in ["open", "running"]:
				is_gold = true
				info = ev
				break
			elif ev.get("id") == "red_dragon" and ev.get("state") in ["open", "running"]:
				is_red = true
				info = ev
				break

	if is_red or is_gold:
		_current_event_id = "golden_invasion" if is_gold else "red_dragon"
		_update_display_data(info, is_gold)
		if not _is_active and not _is_dismissed:
			_show_widget()
	else:
		if _is_active:
			_hide_widget()

func _update_display_data(info: Dictionary, is_gold: bool) -> void:
	var s_name := "BINH ĐOÀN HOÀNG KIM" if is_gold else "RỒNG ĐỎ XÂM LĂNG"
	var color := Color(1.0, 0.9, 0.2) if is_gold else Color(1.0, 0.45, 0.2)
	_lbl_title.text = s_name
	_lbl_title.add_theme_color_override("font_color", color)

	var time_str: String = info.get("time_str", "15:00")
	_lbl_timer.text = "⏱️ %s" % time_str
	_badge_button.text = ("✨\n" if is_gold else "🔥\n") + time_str.substr(0, 5)

	var npc_loc: String = info.get("npc", "Lorencia, Noria, Devias")
	_lbl_map.text = "📍 %s" % npc_loc.substr(0, 24)

func _show_widget() -> void:
	_is_active = true
	visible = true
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween().set_parallel(true)
	_slide_tween.tween_property(self, "modulate:a", 1.0, 0.4)
	if not _is_collapsed:
		_panel_box.visible = true
		_badge_button.visible = false
	else:
		_panel_box.visible = false
		_badge_button.visible = true

func _hide_widget() -> void:
	_is_active = false
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween().set_parallel(true)
	_slide_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_slide_tween.chain().tween_callback(func():
		visible = false
	)

func _on_close_pressed() -> void:
	_is_dismissed = true
	_hide_widget()

func _on_toggle_collapsed() -> void:
	_is_collapsed = not _is_collapsed
	if _is_collapsed:
		_panel_box.visible = false
		_badge_button.visible = true
	else:
		_panel_box.visible = true
		_badge_button.visible = false

func _on_hunt_button_pressed() -> void:
	var flock = get_tree().get_first_node_in_group("DragonFlockManager") if get_tree() else null
	var dragons: Array = flock.get_active_ground_dragons() if (flock and flock.has_method("get_active_ground_dragons")) else []
	if dragons.is_empty():
		dragons = get_tree().get_nodes_in_group("EventDragon") if get_tree() else []

	var p_pos := Vector2i(130, 130)
	var player = get_tree().get_first_node_in_group("Player") if get_tree() else null
	if player:
		p_pos = Vector2i(player.grid_x, player.grid_y)

	var target_dragon = null
	var min_dist := 999999.0
	for d in dragons:
		if is_instance_valid(d) and not d.is_dead:
			var d_tile := Vector2i(d.grid_x, d.grid_y)
			var dist := p_pos.distance_to(d_tile)
			if dist < min_dist:
				min_dist = dist
				target_dragon = d

	var chat = get_tree().get_first_node_in_group("ChatWindow") if get_tree() else null
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null

	if target_dragon:
		var gx: int = target_dragon.grid_x
		var gy: int = target_dragon.grid_y
		var name_str := str(target_dragon.monster_name)
		if chat and chat.has_method("add_system_message"):
			chat.add_system_message("[color=#FF3300][SĂN RỒNG][/color] [color=#FFDD44]Đã định vị %s tại (%d, %d)! Đang tiến đến chiến trường...[/color]" % [name_str, gx, gy])

		# Điều hướng tự động qua BigMap nếu có
		if hud and hud.has_node("BigMapWindow"):
			var bm = hud.get_node("BigMapWindow")
			if bm and bm.has_method("_command_move_to_grid"):
				bm._command_move_to_grid(gx, gy, name_str)
				return
		if player and MuWorld.current:
			var path = MuWorld.current.find_path_grid(p_pos, Vector2i(gx, gy))
			if path.size() > 0:
				player.move_to_path(path)
	else:
		if chat and chat.has_method("add_system_message"):
			chat.add_system_message("[color=#FF3300][RỒNG ĐỎ][/color] [color=#FFDD44]Hãy nhanh chân tiến ra ngoại ô Lorencia (140, 80) hoặc Devias để săn Rồng Đỏ![/color]")

func _start_pulse_animation() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_lbl_title, "modulate", Color(1.25, 1.25, 1.25), 0.7).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_lbl_title, "modulate", Color(0.85, 0.85, 0.85), 0.7).set_trans(Tween.TRANS_SINE)
