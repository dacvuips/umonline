extends Control
class_name MuMoveWindow

## Bảng dịch chuyển (phím M) chuẩn MU Online Season 6/8
## - Bên trái: Xem trước bản đồ (minimap terrain), điểm xuất hiện (orange marker ▼),
##   thông tin cấp yêu cầu, chi phí Zen, và nút [Dịch Chuyển].
## - Bên phải: Tiêu đề "Dịch Chuyển", nút đóng (X), danh sách cuộn (scroll) tất cả các map.
##   Mỗi dòng hiển thị: Tên map | Giá tiền (Zen) | Nút [Đi] di chuyển ngay lập tức.
##   Nhấp vào tên map/giá tiền sẽ chỉ xem trước minimap như bình thường; nhấp nút [Đi] sẽ dịch chuyển ngay.

const MuItemsRes = preload("res://src/mu/MuItems.gd")

const WIN_WIDTH := 700.0
const WIN_HEIGHT := 460.0

var player: MuPlayer = null

# Dữ liệu warps
var _all_warps: Array[Dictionary] = []
var _selected_warp: Dictionary = {}
var _item_widgets: Dictionary = {}

# Node tham chiếu
var dimmer: ColorRect
var panel_container: Panel
var map_canvas: WarpMapCanvas
var lbl_map_name: Label
var lbl_coords: Label
var lbl_req_level: Label
var lbl_warp_cost: Label
var lbl_player_zen: Label
var btn_warp: Button

var scroll_container: ScrollContainer
var list_container: VBoxContainer

# Textures
var tex_corner: Texture2D
var tex_btn_close_normal: Texture2D
var tex_btn_close_pressed: Texture2D

# Canvas vẽ bản đồ thu nhỏ bên trái
class WarpMapCanvas extends Control:
	var world_id: int = 1
	var target_pos: Vector2i = Vector2i(135, 125)
	var map_name: String = ""
	var map_tex: Texture2D = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_map(p_world: int, p_target: Vector2i, p_name: String) -> void:
		world_id = p_world
		target_pos = p_target
		map_name = p_name
		map_tex = null

		var path = "res://assets/textures/ui/minimap/minimap_world_%d.png" % world_id
		if ResourceLoader.exists(path):
			map_tex = load(path)
		queue_redraw()

	func _draw() -> void:
		var v_size = size
		# Vẽ nền đen sâu thẳm
		draw_rect(Rect2(Vector2.ZERO, v_size), Color(0.03, 0.03, 0.04, 1.0))

		var map_size = mini(int(v_size.x), int(v_size.y)) - 10
		var map_tl = Vector2((v_size.x - map_size) * 0.5, (v_size.y - map_size) * 0.5)
		var map_rect = Rect2(map_tl, Vector2(map_size, map_size))

		if map_tex:
			draw_texture_rect(map_tex, map_rect, false)
		else:
			# Nền dự phòng nếu không có texture riêng
			draw_rect(map_rect, Color(0.08, 0.1, 0.14))
			draw_rect(map_rect, Color(0.3, 0.35, 0.4), false, 1.0)
			var font = ThemeDB.fallback_font
			var font_size = 14
			var txt = "[ Chưa có ảnh địa hình ]"
			var txt_size = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, map_tl + (map_rect.size - txt_size) * 0.5 + Vector2(0, 10), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.6, 0.65, 0.7))

		# Vẽ viền khung bản đồ
		draw_rect(map_rect, Color(0.4, 0.35, 0.25, 0.8), false, 1.5)

		# Tọa độ MU: x: 0..255, y: 0..255 (y=0 ở dưới cùng, y=255 ở trên)
		var norm_x = clampf(float(target_pos.x) / 256.0, 0.0, 1.0)
		var norm_y = clampf((255.0 - float(target_pos.y)) / 256.0, 0.0, 1.0)
		var marker_pos = map_tl + Vector2(norm_x * map_rect.size.x, norm_y * map_rect.size.y)

		# Vẽ biểu tượng đích đến hình tam giác ngược màu cam/vàng đặc trưng MU (▼)
		var tip = marker_pos
		var p_left = marker_pos + Vector2(-8, -13)
		var p_right = marker_pos + Vector2(8, -13)

		# Đổ bóng / viền đen
		var poly_shadow = PackedVector2Array([tip + Vector2(0, 2), p_left + Vector2(-2, -1), p_right + Vector2(2, -1)])
		draw_colored_polygon(poly_shadow, Color(0, 0, 0, 0.9))

		# Thân tam giác cam rực rỡ
		var poly_orange = PackedVector2Array([tip, p_left, p_right])
		draw_colored_polygon(poly_orange, Color(1.0, 0.55, 0.1, 1.0))

		# Đường viền viền sáng phía trên
		draw_line(p_left + Vector2(1, 1), p_right + Vector2(-1, 1), Color(1.0, 0.9, 0.5, 1.0), 1.5)

		# Chấm tâm đích đến
		draw_circle(tip, 3.0, Color(1.0, 0.85, 0.2, 0.9))

		# Vẽ nhãn tên map + tọa độ kế bên marker
		var font = ThemeDB.fallback_font
		var lbl_text = "%s (%d, %d)" % [map_name, target_pos.x, target_pos.y]
		var text_pos = marker_pos + Vector2(12, -4)
		if text_pos.x + 120 > map_tl.x + map_rect.size.x:
			text_pos.x = marker_pos.x - 120
		# Bóng đen chữ
		draw_string(font, text_pos + Vector2(1, 1), lbl_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
		# Chữ vàng sáng
		draw_string(font, text_pos, lbl_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.88, 0.45))


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_load_textures()
	_build_ui()
	_load_warps_data()

	get_viewport().size_changed.connect(_recenter)
	_recenter()


func setup(p: MuPlayer) -> void:
	player = p
	if player and not player.exp_changed.is_connected(_on_player_status_changed):
		player.exp_changed.connect(_on_player_status_changed)


func _on_player_status_changed(_cur_exp: int, _max_exp: int, _lvl: int) -> void:
	if visible:
		_refresh_ui_state()


func _unhandled_input(event: InputEvent) -> void:
	var k = event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.keycode == KEY_M:
			toggle()
			get_viewport().set_input_as_handled()
		elif visible and k.keycode == KEY_ESCAPE:
			visible = false
			get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		_recenter()
		_refresh_ui_state()
		_scroll_to_selected.call_deferred()


func _recenter() -> void:
	var vs = get_viewport_rect().size
	if panel_container:
		panel_container.position = Vector2(
			maxf(0.0, (vs.x - WIN_WIDTH) * 0.5),
			maxf(0.0, (vs.y - WIN_HEIGHT) * 0.5)
		)


func _load_textures() -> void:
	var corner_p = "res://assets/textures/ui/mini_map_ui_corner.png"
	if ResourceLoader.exists(corner_p):
		tex_corner = load(corner_p)

	var cancel_p = "res://assets/textures/ui/mini_map_ui_cancel.png"
	if ResourceLoader.exists(cancel_p):
		var raw = load(cancel_p)
		if raw is Texture2D:
			var at_norm = AtlasTexture.new()
			at_norm.atlas = raw
			at_norm.region = Rect2(0, 0, 36, 29)
			tex_btn_close_normal = at_norm

			var at_press = AtlasTexture.new()
			at_press.atlas = raw
			at_press.region = Rect2(0, 29, 36, 29)
			tex_btn_close_pressed = at_press


func _build_ui() -> void:
	# 1. Dimmer mờ nền
	dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			visible = false
	)
	add_child(dimmer)

	# 2. Khung chính cửa sổ (Panel Container)
	panel_container = Panel.new()
	panel_container.size = Vector2(WIN_WIDTH, WIN_HEIGHT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.98)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.6, 0.5, 0.32, 0.95)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.shadow_color = Color(0, 0, 0, 0.85)
	sb.shadow_size = 10
	panel_container.add_theme_stylebox_override("panel", sb)
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_container)

	# Góc hoa văn kim loại cổ điển
	if tex_corner:
		_add_corner_icon(panel_container, Vector2(2, 2), 0)
		_add_corner_icon(panel_container, Vector2(WIN_WIDTH - 44, 2), 1)
		_add_corner_icon(panel_container, Vector2(2, WIN_HEIGHT - 44), 2)
		_add_corner_icon(panel_container, Vector2(WIN_WIDTH - 44, WIN_HEIGHT - 44), 3)

	# 3. Phân vùng Trái (Xem trước bản đồ + Chi phí + Dịch chuyển)
	var left_panel = Panel.new()
	left_panel.position = Vector2(10, 10)
	left_panel.size = Vector2(426, 440)
	var sb_left = StyleBoxFlat.new()
	sb_left.bg_color = Color(0.04, 0.05, 0.07, 0.9)
	sb_left.border_width_left = 1
	sb_left.border_width_top = 1
	sb_left.border_width_right = 1
	sb_left.border_width_bottom = 1
	sb_left.border_color = Color(0.35, 0.32, 0.25, 0.7)
	sb_left.corner_radius_top_left = 3
	sb_left.corner_radius_bottom_left = 3
	left_panel.add_theme_stylebox_override("panel", sb_left)
	panel_container.add_child(left_panel)

	map_canvas = WarpMapCanvas.new()
	map_canvas.position = Vector2(3, 3)
	map_canvas.size = Vector2(420, 344)
	left_panel.add_child(map_canvas)

	# Thanh thông tin dưới cùng của bản đồ xem trước
	var info_panel = Panel.new()
	info_panel.position = Vector2(3, 350)
	info_panel.size = Vector2(420, 87)
	var sb_info = StyleBoxFlat.new()
	sb_info.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	sb_info.border_width_top = 1
	sb_info.border_color = Color(0.5, 0.42, 0.28, 0.8)
	info_panel.add_theme_stylebox_override("panel", sb_info)
	left_panel.add_child(info_panel)

	# Dòng 1: Tên Map & Tọa độ
	lbl_map_name = Label.new()
	lbl_map_name.position = Vector2(12, 6)
	lbl_map_name.size = Vector2(240, 20)
	lbl_map_name.text = "Lorencia"
	lbl_map_name.add_theme_font_size_override("font_size", 14)
	lbl_map_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lbl_map_name.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_map_name.add_theme_constant_override("outline_size", 2)
	info_panel.add_child(lbl_map_name)

	lbl_coords = Label.new()
	lbl_coords.position = Vector2(170, 7)
	lbl_coords.size = Vector2(140, 18)
	lbl_coords.text = "Tọa độ: (142, 126)"
	lbl_coords.add_theme_font_size_override("font_size", 11)
	lbl_coords.add_theme_color_override("font_color", Color(0.7, 0.82, 0.95))
	lbl_coords.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_coords.add_theme_constant_override("outline_size", 2)
	info_panel.add_child(lbl_coords)

	# Dòng 2: Cấp yêu cầu & Chi phí Zen
	lbl_req_level = Label.new()
	lbl_req_level.position = Vector2(12, 30)
	lbl_req_level.size = Vector2(150, 18)
	lbl_req_level.text = "Cấp yêu cầu: 10"
	lbl_req_level.add_theme_font_size_override("font_size", 11)
	lbl_req_level.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_req_level.add_theme_constant_override("outline_size", 2)
	info_panel.add_child(lbl_req_level)

	lbl_warp_cost = Label.new()
	lbl_warp_cost.position = Vector2(165, 30)
	lbl_warp_cost.size = Vector2(140, 18)
	lbl_warp_cost.text = "Chi phí: 2,000 Zen"
	lbl_warp_cost.add_theme_font_size_override("font_size", 11)
	lbl_warp_cost.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_warp_cost.add_theme_constant_override("outline_size", 2)
	info_panel.add_child(lbl_warp_cost)

	# Dòng 3: Zen hiện có
	lbl_player_zen = Label.new()
	lbl_player_zen.position = Vector2(12, 54)
	lbl_player_zen.size = Vector2(280, 18)
	lbl_player_zen.text = "Zen hiện có: 10,000"
	lbl_player_zen.add_theme_font_size_override("font_size", 11)
	lbl_player_zen.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl_player_zen.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_player_zen.add_theme_constant_override("outline_size", 2)
	info_panel.add_child(lbl_player_zen)

	# Nút [ Dịch Chuyển ] bên dưới xem trước
	btn_warp = Button.new()
	btn_warp.position = Vector2(295, 24)
	btn_warp.size = Vector2(115, 38)
	btn_warp.text = "Dịch Chuyển"
	btn_warp.add_theme_font_size_override("font_size", 12)

	var sb_btn_n = StyleBoxFlat.new()
	sb_btn_n.bg_color = Color(0.2, 0.17, 0.1, 0.95)
	sb_btn_n.border_width_left = 1
	sb_btn_n.border_width_top = 1
	sb_btn_n.border_width_right = 1
	sb_btn_n.border_width_bottom = 1
	sb_btn_n.border_color = Color(0.85, 0.72, 0.3)
	sb_btn_n.corner_radius_top_left = 3
	sb_btn_n.corner_radius_top_right = 3
	sb_btn_n.corner_radius_bottom_left = 3
	sb_btn_n.corner_radius_bottom_right = 3
	btn_warp.add_theme_stylebox_override("normal", sb_btn_n)

	var sb_btn_h = sb_btn_n.duplicate()
	sb_btn_h.bg_color = Color(0.35, 0.28, 0.12, 1.0)
	sb_btn_h.border_color = Color(1.0, 0.9, 0.45)
	btn_warp.add_theme_stylebox_override("hover", sb_btn_h)

	var sb_btn_d = sb_btn_n.duplicate()
	sb_btn_d.bg_color = Color(0.12, 0.12, 0.14, 0.8)
	sb_btn_d.border_color = Color(0.35, 0.35, 0.35)
	btn_warp.add_theme_stylebox_override("disabled", sb_btn_d)

	btn_warp.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	btn_warp.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	btn_warp.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	btn_warp.pressed.connect(_on_warp_button_pressed)
	info_panel.add_child(btn_warp)

	# 4. Phân vùng Phải (Tiêu đề, Danh sách Cuộn Scroll)
	var right_panel = Panel.new()
	right_panel.position = Vector2(442, 10)
	right_panel.size = Vector2(248, 440)
	var sb_right = StyleBoxFlat.new()
	sb_right.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	sb_right.border_width_left = 1
	sb_right.border_width_top = 1
	sb_right.border_width_right = 1
	sb_right.border_width_bottom = 1
	sb_right.border_color = Color(0.35, 0.32, 0.25, 0.7)
	sb_right.corner_radius_top_right = 3
	sb_right.corner_radius_bottom_right = 3
	right_panel.add_theme_stylebox_override("panel", sb_right)
	panel_container.add_child(right_panel)

	# Header: "Dịch Chuyển" + nút tắt (X)
	var lbl_title = Label.new()
	lbl_title.position = Vector2(10, 6)
	lbl_title.size = Vector2(160, 22)
	lbl_title.text = "Dịch Chuyển"
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.add_theme_color_override("font_color", Color(0.96, 0.85, 0.48))
	lbl_title.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_title.add_theme_constant_override("outline_size", 2)
	right_panel.add_child(lbl_title)

	var btn_close = TextureButton.new()
	btn_close.position = Vector2(248 - 32, 4)
	btn_close.size = Vector2(28, 24)
	btn_close.ignore_texture_size = true
	btn_close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if tex_btn_close_normal:
		btn_close.texture_normal = tex_btn_close_normal
	if tex_btn_close_pressed:
		btn_close.texture_pressed = tex_btn_close_pressed
	btn_close.tooltip_text = "Đóng bảng dịch chuyển (ESC / M)"
	btn_close.pressed.connect(func(): visible = false)
	right_panel.add_child(btn_close)

	# Sub-header: Các cột [Bản đồ] [Chi phí] [Đến]
	var sub_header = HBoxContainer.new()
	sub_header.position = Vector2(8, 30)
	sub_header.size = Vector2(230, 16)
	sub_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_panel.add_child(sub_header)

	var h_map = Label.new()
	h_map.text = " Bản đồ"
	h_map.custom_minimum_size = Vector2(116, 0)
	h_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_map.add_theme_font_size_override("font_size", 10)
	h_map.add_theme_color_override("font_color", Color(0.75, 0.68, 0.5))
	sub_header.add_child(h_map)

	var h_cost = Label.new()
	h_cost.text = "Chi phí"
	h_cost.custom_minimum_size = Vector2(58, 0)
	h_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_cost.add_theme_font_size_override("font_size", 10)
	h_cost.add_theme_color_override("font_color", Color(0.75, 0.68, 0.5))
	sub_header.add_child(h_cost)

	var h_act = Label.new()
	h_act.text = "Đi"
	h_act.custom_minimum_size = Vector2(46, 0)
	h_act.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_act.add_theme_font_size_override("font_size", 10)
	h_act.add_theme_color_override("font_color", Color(0.75, 0.68, 0.5))
	sub_header.add_child(h_act)

	# Đường kẻ phân cách header
	var div1 = ColorRect.new()
	div1.position = Vector2(4, 48)
	div1.size = Vector2(240, 1)
	div1.color = Color(0.4, 0.35, 0.25, 0.6)
	right_panel.add_child(div1)

	# Danh sách cuộn (ScrollContainer) chứa toàn bộ các Map
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(4, 52)
	scroll_container.size = Vector2(240, 380)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_panel.add_child(scroll_container)

	_style_scroll_bar(scroll_container.get_v_scroll_bar())

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 2)
	scroll_container.add_child(list_container)


func _style_scroll_bar(v_bar: VScrollBar) -> void:
	if not v_bar:
		return
	v_bar.custom_minimum_size = Vector2(6, 0)

	var sb_grab = StyleBoxFlat.new()
	sb_grab.bg_color = Color(0.55, 0.45, 0.28, 0.85)
	sb_grab.corner_radius_top_left = 3
	sb_grab.corner_radius_top_right = 3
	sb_grab.corner_radius_bottom_left = 3
	sb_grab.corner_radius_bottom_right = 3
	v_bar.add_theme_stylebox_override("grabber", sb_grab)

	var sb_grab_h = sb_grab.duplicate()
	sb_grab_h.bg_color = Color(0.85, 0.72, 0.38, 1.0)
	v_bar.add_theme_stylebox_override("grabber_highlight", sb_grab_h)
	v_bar.add_theme_stylebox_override("grabber_pressed", sb_grab_h)

	var sb_track = StyleBoxFlat.new()
	sb_track.bg_color = Color(0.04, 0.05, 0.07, 0.6)
	sb_track.corner_radius_top_left = 3
	sb_track.corner_radius_top_right = 3
	sb_track.corner_radius_bottom_left = 3
	sb_track.corner_radius_bottom_right = 3
	v_bar.add_theme_stylebox_override("scroll", sb_track)


func _add_corner_icon(parent: Control, pos: Vector2, corner_idx: int) -> void:
	var tr = TextureRect.new()
	tr.texture = tex_corner
	tr.size = Vector2(44, 44)
	tr.position = pos
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match corner_idx:
		0: pass # Top-Left
		1: tr.flip_h = true # Top-Right
		2: tr.flip_v = true # Bottom-Left
		3: # Bottom-Right
			tr.flip_h = true
			tr.flip_v = true
	parent.add_child(tr)


static func _read_json(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(p))


## Chỉ các map này có trong bảng dịch chuyển (giống client gốc), theo đúng thứ tự hiển thị.
## Map sự kiện (Devil Square, Blood/Chaos Castle, Illusion Temple...) và map phụ không có ở đây.
const WARP_MAP_WHITELIST: Array[String] = [
	"Arena", "Lorencia", "Noria", "Elveland", "Elveland2", "Elveland3",
	"Devias", "Devias2", "Devias3", "Devias4",
	"Dungeon", "Dungeon2", "Dungeon3",
	"Atlans", "Atlans2", "Atlans3",
	"LostTower", "LostTower2", "LostTower3", "LostTower4", "LostTower5", "LostTower6", "LostTower7",
	"Tarkan", "Tarkan2", "Aida1", "Aida2", "Icarus",
	"KanturuRuins1", "KanturuRuins2", "KanturuRuins3", "KanturuRelics",
	"Karutan1", "Karutan2", "LaCleon", "PeaceSwamp", "Vulcanus",
]

static func _warp_key(map_name: String) -> String:
	return map_name.replace(" ", "")


func _load_warps_data() -> void:
	_all_warps.clear()
	var raw_warps = _read_json("res://assets/mu/warps.json")

	var by_key := {}
	if raw_warps is Array:
		for w in raw_warps:
			var key := _warp_key(str(w.get("name", "")))
			if not WARP_MAP_WHITELIST.has(key) or by_key.has(key):
				continue
			var x1 := int(w.get("x1", 128))
			var y1 := int(w.get("y1", 128))
			var x2 := int(w.get("x2", x1))
			var y2 := int(w.get("y2", y1))
			by_key[key] = {
				"name": str(w.get("name", "")),
				"level": int(w.get("level", 0)),
				"cost": int(w.get("cost", 0)),
				"world": int(w.get("world", 0)),
				"x1": x1,
				"y1": y1,
				"x2": x2,
				"y2": y2,
				"target_x": int((x1 + x2) * 0.5),
				"target_y": int((y1 + y2) * 0.5)
			}

	for key in WARP_MAP_WHITELIST:
		if by_key.has(key):
			_all_warps.append(by_key[key])

	_select_default_warp()


func _select_default_warp() -> void:
	var cur_world = MuTerrain.world_id
	var found = false
	for item in _all_warps:
		if item.world == cur_world:
			_selected_warp = item
			found = true
			break
	if not found and not _all_warps.is_empty():
		_selected_warp = _all_warps[0]


func _render_list() -> void:
	for c in list_container.get_children():
		c.queue_free()
	_item_widgets.clear()

	for item in _all_warps:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 24)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 3)

		# 1. Nút chọn xem bản đồ (chứa Tên Map + Giá tiền)
		var btn_select = Button.new()
		btn_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_select.custom_minimum_size = Vector2(178, 24)

		var inner = HBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 2)
		btn_select.add_child(inner)

		var lbl_name = Label.new()
		lbl_name.text = " " + item.name
		lbl_name.custom_minimum_size = Vector2(114, 0)
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_name.add_theme_font_size_override("font_size", 11)
		lbl_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(lbl_name)

		var lbl_cost = Label.new()
		lbl_cost.custom_minimum_size = Vector2(58, 0)
		lbl_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_cost.add_theme_font_size_override("font_size", 10)
		lbl_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(lbl_cost)

		# 2. Nút "Đi" - Dịch chuyển ngay lập tức
		var btn_quick = Button.new()
		btn_quick.text = "Đi"
		btn_quick.custom_minimum_size = Vector2(40, 22)
		btn_quick.add_theme_font_size_override("font_size", 11)

		# Kết nối sự kiện:
		# Bấm vào dòng (btn_select) -> Chỉ xem trước minimap như bình thường
		btn_select.pressed.connect(func(): _on_item_clicked(item))
		btn_select.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_quick_warp_pressed(item)
		)

		# Bấm vào nút "Đi" -> Dịch chuyển ngay lập tức tới map!
		btn_quick.pressed.connect(func(): _on_quick_warp_pressed(item))

		row.add_child(btn_select)
		row.add_child(btn_quick)
		list_container.add_child(row)

		_item_widgets[item] = {
			"row": row,
			"btn_select": btn_select,
			"lbl_name": lbl_name,
			"lbl_cost": lbl_cost,
			"btn_quick": btn_quick
		}

	_update_list_selection()


func _update_list_selection() -> void:
	var cur_lvl = player.level if player else 1
	var cur_zen = player.zen if player else 0

	for item in _all_warps:
		if not _item_widgets.has(item):
			continue
		var w = _item_widgets[item]
		var btn_select: Button = w["btn_select"]
		var lbl_name: Label = w["lbl_name"]
		var lbl_cost: Label = w["lbl_cost"]
		var btn_quick: Button = w["btn_quick"]

		var lvl_ok = (cur_lvl >= item.level)
		var cost = item.cost
		var zen_ok = (cur_zen >= cost)
		var is_selected = (_selected_warp == item)

		# Màu tên map: Vàng nếu đang chọn, Trắng nếu đủ cấp, Đỏ nếu thiếu cấp
		if is_selected:
			lbl_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
		elif lvl_ok:
			lbl_name.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		else:
			lbl_name.add_theme_color_override("font_color", Color(0.88, 0.26, 0.26))

		# Hiển thị giá tiền
		if cost <= 0:
			lbl_cost.text = "0 "
			lbl_cost.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
		else:
			lbl_cost.text = "%s " % MuItemsRes.format_zen(cost)
			lbl_cost.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if zen_ok else Color(0.88, 0.26, 0.26))

		# StyleBox cho ô chọn xem map
		if is_selected:
			var sb_sel = StyleBoxFlat.new()
			sb_sel.bg_color = Color(0.2, 0.3, 0.45, 0.85)
			sb_sel.border_width_left = 1
			sb_sel.border_width_top = 1
			sb_sel.border_width_right = 1
			sb_sel.border_width_bottom = 1
			sb_sel.border_color = Color(0.85, 0.75, 0.3)
			sb_sel.corner_radius_top_left = 2
			sb_sel.corner_radius_top_right = 2
			sb_sel.corner_radius_bottom_left = 2
			sb_sel.corner_radius_bottom_right = 2
			btn_select.add_theme_stylebox_override("normal", sb_sel)
			btn_select.add_theme_stylebox_override("hover", sb_sel)
		else:
			var sb_empty = StyleBoxEmpty.new()
			btn_select.add_theme_stylebox_override("normal", sb_empty)
			var sb_hov = StyleBoxFlat.new()
			sb_hov.bg_color = Color(0.18, 0.22, 0.3, 0.4)
			btn_select.add_theme_stylebox_override("hover", sb_hov)

		# StyleBox & Trạng thái cho nút "Đi" ngay
		_style_quick_warp_button(btn_quick, lvl_ok, zen_ok, item)


func _style_quick_warp_button(btn: Button, lvl_ok: bool, zen_ok: bool, item: Dictionary) -> void:
	var sb_n = StyleBoxFlat.new()
	sb_n.corner_radius_top_left = 3
	sb_n.corner_radius_top_right = 3
	sb_n.corner_radius_bottom_left = 3
	sb_n.corner_radius_bottom_right = 3

	if lvl_ok and zen_ok:
		btn.disabled = false
		sb_n.bg_color = Color(0.18, 0.24, 0.16, 0.95)
		sb_n.border_width_left = 1
		sb_n.border_width_top = 1
		sb_n.border_width_right = 1
		sb_n.border_width_bottom = 1
		sb_n.border_color = Color(0.55, 0.7, 0.35)
		btn.add_theme_stylebox_override("normal", sb_n)

		var sb_h = sb_n.duplicate()
		sb_h.bg_color = Color(0.28, 0.38, 0.22, 1.0)
		sb_h.border_color = Color(0.85, 1.0, 0.5)
		btn.add_theme_stylebox_override("hover", sb_h)

		btn.add_theme_color_override("font_color", Color(0.88, 1.0, 0.65))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.8))
		btn.tooltip_text = "Dịch chuyển ngay đến %s (Chi phí: %s Zen)" % [item.name, MuItemsRes.format_zen(item.cost)]
	else:
		btn.disabled = true
		sb_n.bg_color = Color(0.1, 0.1, 0.12, 0.5)
		sb_n.border_width_left = 1
		sb_n.border_width_top = 1
		sb_n.border_width_right = 1
		sb_n.border_width_bottom = 1
		sb_n.border_color = Color(0.28, 0.28, 0.3, 0.5)
		btn.add_theme_stylebox_override("disabled", sb_n)
		btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
		if not lvl_ok:
			btn.tooltip_text = "Cần cấp %d để dịch chuyển" % item.level
		else:
			btn.tooltip_text = "Không đủ Zen (Cần %s Zen)" % MuItemsRes.format_zen(item.cost)


func _scroll_to_selected() -> void:
	if not _selected_warp.is_empty() and _item_widgets.has(_selected_warp) and scroll_container:
		var w = _item_widgets[_selected_warp]
		var row: Control = w["row"]
		scroll_container.ensure_control_visible(row)


func _on_item_clicked(item: Dictionary) -> void:
	# Nhấp vào tên map: Chỉ xem trước minimap như bình thường
	_selected_warp = item
	_update_list_selection()
	_update_preview()


func _on_quick_warp_pressed(item: Dictionary) -> void:
	# Nhấp nút [Đi]: Dịch chuyển ngay lập tức tới map!
	_selected_warp = item
	_update_list_selection()
	_update_preview()
	_warp_to_item(item)


func _update_preview() -> void:
	if _selected_warp.is_empty():
		return

	var w_id = _selected_warp.world
	var t_pos = Vector2i(_selected_warp.target_x, _selected_warp.target_y)
	var m_name = _selected_warp.name

	map_canvas.set_map(w_id, t_pos, m_name)

	lbl_map_name.text = m_name
	lbl_coords.text = "Tọa độ: (%d, %d)" % [t_pos.x, t_pos.y]

	var req_lvl = _selected_warp.level
	var cost = _selected_warp.cost
	var cur_lvl = player.level if player else 1
	var cur_zen = player.zen if player else 0

	var lvl_ok = (cur_lvl >= req_lvl)
	var zen_ok = (cur_zen >= cost)

	# Hiển thị Cấp yêu cầu
	lbl_req_level.text = "Cấp yêu cầu: %d" % req_lvl if req_lvl > 0 else "Cấp yêu cầu: Không"
	lbl_req_level.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if lvl_ok else Color(0.95, 0.3, 0.3))

	# Hiển thị Chi phí
	lbl_warp_cost.text = "Chi phí: %s Zen" % MuItemsRes.format_zen(cost) if cost > 0 else "Chi phí: Miễn phí"
	lbl_warp_cost.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if zen_ok else Color(0.95, 0.3, 0.3))

	# Hiển thị Zen người chơi
	lbl_player_zen.text = "Zen hiện có: %s" % MuItemsRes.format_zen(cur_zen)

	# Cập nhật trạng thái nút Dịch Chuyển bên dưới bản đồ
	if not lvl_ok:
		btn_warp.disabled = true
		btn_warp.tooltip_text = "Cấp độ chưa đủ yêu cầu (Cần cấp %d)" % req_lvl
	elif not zen_ok:
		btn_warp.disabled = true
		btn_warp.tooltip_text = "Không đủ Zen để dịch chuyển (Cần %s Zen)" % MuItemsRes.format_zen(cost)
	else:
		btn_warp.disabled = false
		btn_warp.tooltip_text = "Bấm để dịch chuyển đến %s" % m_name


func _refresh_ui_state() -> void:
	if list_container.get_child_count() == 0:
		_render_list()
	else:
		_update_list_selection()
	_update_preview()


func _on_warp_button_pressed() -> void:
	if _selected_warp.is_empty():
		return
	_warp_to_item(_selected_warp)


func _warp_to_item(item: Dictionary) -> void:
	if item.is_empty():
		return

	var req_lvl = int(item.get("level", 0))
	var cost = int(item.get("cost", 0))
	var world = int(item.get("world", 0))

	if player:
		if player.level < req_lvl:
			print("[MuMoveWindow] Cấp độ không đủ (%d < %d)" % [player.level, req_lvl])
			return
		if cost > 0 and player.zen < cost:
			print("[MuMoveWindow] Không đủ Zen (%d < %d)" % [player.zen, cost])
			return

	if not MuTerrain.has_map(world):
		print("[MuMoveWindow] Bản đồ thế giới %d chưa được cài đặt!" % world)
		return

	# Tính tọa độ xuất hiện ngẫu nhiên trong vùng cổng (Gate)
	var x1 = int(item.get("x1", 128))
	var y1 = int(item.get("y1", 128))
	var x2 = int(item.get("x2", x1))
	var y2 = int(item.get("y2", y1))
	var spawn = Vector2i(
		randi_range(mini(x1, x2), maxi(x1, x2)),
		randi_range(mini(y1, y2), maxi(y1, y2))
	)

	# Trừ tiền Zen nếu có phí
	if player and cost > 0:
		player.add_zen(-cost)

	visible = false
	print("[MuMoveWindow] Dịch chuyển ngay đến %s (World %d) tại (%d, %d), trừ %d Zen" % [item.name, world, spawn.x, spawn.y, cost])
	MuTerrain.change_world(world, spawn)
	get_tree().call_deferred("reload_current_scene")
