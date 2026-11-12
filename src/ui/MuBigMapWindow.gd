extends Control
class_name MuBigMapWindow

## Cửa Sổ Bản Đồ Lớn (Big Map / World Map) Chuẩn Phong Cách MU Online
## - Tự động tải ảnh địa hình minimap_world_<id>.png từ dữ liệu gốc
## - Đọc danh sách NPC & Cổng Dịch Chuyển từ assets/mu/minimap_markers.json (nguồn gốc BMD)
## - Hiển thị vị trí người chơi (mũi tên / icon), quái vật (chấm đỏ), NPC (icon vàng), Cổng (icon xanh)
## - Khung viền kim loại hoa văn MU cổ điển (mini_map_ui_corner.png, mini_map_ui_line.png)
## - Nút Đóng bản đồ lớn chuẩn góc trên bên phải (mini_map_ui_cancel.png)
## - Nhấp chuột vào bất kỳ vị trí hoặc NPC trên bản đồ để tự động tìm đường di chuyển
## - Danh sách tìm kiếm & dẫn đường nhanh tới NPC / Cổng bên cạnh bản đồ
## - Hỗ trợ phóng to thu nhỏ và chuyển đổi góc nhìn Top-down / Xoay 45°

signal closed
signal marker_selected(marker_data: Dictionary)

@export var player: MuPlayer = null

var current_world_id: int = 1
var current_map_name: String = "Lorencia"
var current_map_texture: Texture2D = null
var markers_list: Array = []
var filtered_markers: Array = []
var current_filter: String = "all" # "all", "npc", "portal"

# UI Nodes
var panel_container: Panel
var map_viewport: Control
var lbl_title: Label
var lbl_coords: Label
var lbl_cursor_coords: Label
var list_container: VBoxContainer
var btn_close: TextureButton
var filter_all_btn: Button
var filter_npc_btn: Button
var filter_portal_btn: Button
var tooltip_panel: Panel
var tooltip_label: Label
var input_coord_x: LineEdit
var input_coord_y: LineEdit
var btn_auto_path: Button

# Trạng thái hiển thị bản đồ
var zoom_level: float = 1.0 # 1.0 -> 2.5
var pan_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var pan_start: Vector2 = Vector2.ZERO
var is_rotated_45: bool = false # Chế độ xoay 45° chuẩn CMiniMap client gốc

# Hiệu ứng ping đích đến
var dest_marker: Vector2 = Vector2(-1, -1)
var dest_ping_time: float = 0.0

# Textures từ client gốc
var tex_corner: Texture2D = null
var tex_line: Texture2D = null
var tex_hero: Texture2D = null
var tex_npc: Texture2D = null
var tex_portal: Texture2D = null
var tex_btn_close_normal: Texture2D = null
var tex_btn_close_pressed: Texture2D = null

# Kích thước vùng vẽ map
const VIEW_SIZE := Vector2(500, 480)

class BigMapCanvas extends Control:
	var window: MuBigMapWindow
	func _draw() -> void:
		if window:
			window.draw_big_map_canvas(self)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	visible = false

	_load_textures()
	_build_ui()
	_update_map_data()
	_on_viewport_resized()

	if is_inside_tree():
		get_viewport().size_changed.connect(_on_viewport_resized)

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player:
		if not player.position_changed.is_connected(_on_player_position_changed):
			player.position_changed.connect(_on_player_position_changed)
		_on_player_position_changed(player.grid_x, player.grid_y)

func _load_textures() -> void:
	if ResourceLoader.exists("res://assets/textures/ui/mini_map_ui_corner.png"):
		tex_corner = load("res://assets/textures/ui/mini_map_ui_corner.png")
	if ResourceLoader.exists("res://assets/textures/ui/mini_map_ui_line.png"):
		tex_line = load("res://assets/textures/ui/mini_map_ui_line.png")
	if ResourceLoader.exists("res://assets/textures/ui/mini_map_ui_cha.png"):
		tex_hero = load("res://assets/textures/ui/mini_map_ui_cha.png")
	if ResourceLoader.exists("res://assets/textures/ui/mini_map_ui_npc.png"):
		tex_npc = load("res://assets/textures/ui/mini_map_ui_npc.png")
	if ResourceLoader.exists("res://assets/textures/ui/mini_map_ui_portal.png"):
		tex_portal = load("res://assets/textures/ui/mini_map_ui_portal.png")
	if ResourceLoader.exists("res://assets/textures/ui/mini_map_ui_cancel.png"):
		var full_cancel_tex = load("res://assets/textures/ui/mini_map_ui_cancel.png")
		var at_norm = AtlasTexture.new()
		at_norm.atlas = full_cancel_tex
		at_norm.region = Rect2(0, 0, 36, 29)
		tex_btn_close_normal = at_norm
		
		var at_press = AtlasTexture.new()
		at_press.atlas = full_cancel_tex
		at_press.region = Rect2(0, 29, 36, 29)
		tex_btn_close_pressed = at_press

func _on_viewport_resized() -> void:
	var vs = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if vs.x <= 10.0 or vs.y <= 10.0:
		vs = Vector2(1280, 720)
	size = vs
	custom_minimum_size = vs
	if panel_container:
		panel_container.position = Vector2(
			maxf(10.0, (vs.x - panel_container.size.x) * 0.5),
			maxf(10.0, (vs.y - panel_container.size.y) * 0.5)
		)

func _update_map_data() -> void:
	current_world_id = MuTerrain.world_id
	
	# Đọc tên bản đồ từ maps_index.json
	current_map_name = "World %d" % current_world_id
	var p_idx := "res://assets/mu/maps/maps_index.json"
	if FileAccess.file_exists(p_idx):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p_idx))
		if d is Dictionary and d.has(str(current_world_id)):
			current_map_name = str(d[str(current_world_id)].get("name", current_map_name))
	elif current_world_id == 1:
		current_map_name = "Lorencia"
	elif current_world_id == 2:
		current_map_name = "Dungeon"
	elif current_world_id == 3:
		current_map_name = "Devias"
	elif current_world_id == 4:
		current_map_name = "Noria"
	elif current_world_id == 5:
		current_map_name = "Lost Tower"
	elif current_world_id == 8:
		current_map_name = "Atlans"
	elif current_world_id == 9:
		current_map_name = "Tarkan"

	# Tải ảnh bản đồ
	var tex_path := "res://assets/textures/ui/minimap/minimap_world_%d.png" % current_world_id
	if ResourceLoader.exists(tex_path):
		current_map_texture = load(tex_path)
	elif ResourceLoader.exists("res://assets/textures/ui/minimap/minimap_world_1.png"):
		current_map_texture = load("res://assets/textures/ui/minimap/minimap_world_1.png")

	# Tải danh sách Markers (NPC & Gate) từ minimap_markers.json
	markers_list.clear()
	var p_markers := "res://assets/mu/minimap_markers.json"
	if FileAccess.file_exists(p_markers):
		var m_dict = JSON.parse_string(FileAccess.get_file_as_string(p_markers))
		if m_dict is Dictionary and m_dict.has(str(current_world_id)):
			markers_list = m_dict[str(current_world_id)]

	if lbl_title:
		lbl_title.text = "BẢN ĐỒ THẾ GIỚI — %s" % current_map_name.to_upper()
	
	_apply_marker_filter(current_filter)
	if map_viewport:
		map_viewport.queue_redraw()

func _on_player_position_changed(gx: int, gy: int) -> void:
	if lbl_coords:
		lbl_coords.text = "Tọa độ: (%d, %d)" % [gx, gy]
	if input_coord_x and input_coord_x.text.is_empty():
		input_coord_x.placeholder_text = str(gx)
	if input_coord_y and input_coord_y.text.is_empty():
		input_coord_y.placeholder_text = str(gy)
	if visible and map_viewport:
		map_viewport.queue_redraw()

func _build_ui() -> void:
	# 1. Lớp phủ làm tối màn hình (Dimmer Backdrop)
	var dimmer = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.color = Color(0, 0, 0, 0.65)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(_on_dimmer_gui_input)
	add_child(dimmer)

	# 2. Khung chính trung tâm
	panel_container = Panel.new()
	panel_container.name = "WindowPanel"
	panel_container.size = Vector2(760, 560)
	panel_container.position = (size - panel_container.size) * 0.5
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.65, 0.55, 0.32, 0.9)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0, 0, 0, 0.75)
	sb.shadow_size = 8
	panel_container.add_theme_stylebox_override("panel", sb)
	add_child(panel_container)

	# Góc hoa văn kim loại cổ điển (mini_map_ui_corner.png)
	if tex_corner:
		_add_corner_icon(panel_container, Vector2(2, 2), 0)
		_add_corner_icon(panel_container, Vector2(760 - 44, 2), 1)
		_add_corner_icon(panel_container, Vector2(2, 560 - 44), 2)
		_add_corner_icon(panel_container, Vector2(760 - 44, 560 - 44), 3)

	# 3. Header Panel
	var header_bar = Panel.new()
	header_bar.position = Vector2(4, 4)
	header_bar.size = Vector2(752, 34)
	var sb_h = StyleBoxFlat.new()
	sb_h.bg_color = Color(0.1, 0.13, 0.18, 0.95)
	sb_h.border_width_bottom = 1
	sb_h.border_color = Color(0.5, 0.42, 0.25, 0.8)
	header_bar.add_theme_stylebox_override("panel", sb_h)
	panel_container.add_child(header_bar)

	lbl_title = Label.new()
	lbl_title.position = Vector2(16, 7)
	lbl_title.size = Vector2(380, 20)
	lbl_title.text = "BẢN ĐỒ THẾ GIỚI — LORENCIA"
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.add_theme_color_override("font_color", Color(0.96, 0.85, 0.48))
	lbl_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_title.add_theme_constant_override("outline_size", 3)
	header_bar.add_child(lbl_title)

	lbl_coords = Label.new()
	lbl_coords.position = Vector2(400, 7)
	lbl_coords.size = Vector2(180, 20)
	lbl_coords.text = "Tọa độ: (140, 119)"
	lbl_coords.add_theme_font_size_override("font_size", 12)
	lbl_coords.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	header_bar.add_child(lbl_coords)

	# Nút Tắt Bản Đồ Lớn (mini_map_ui_cancel.png)
	btn_close = TextureButton.new()
	btn_close.position = Vector2(752 - 38, 2)
	btn_close.size = Vector2(36, 29)
	if tex_btn_close_normal:
		btn_close.texture_normal = tex_btn_close_normal
	if tex_btn_close_pressed:
		btn_close.texture_pressed = tex_btn_close_pressed
	btn_close.tooltip_text = "Đóng bản đồ lớn (ESC / TAB / M)"
	btn_close.pressed.connect(close)
	header_bar.add_child(btn_close)

	# 4. Khu vực chính: Bản Đồ (Trái) & Danh Sách Điểm Đến (Phải)
	var map_frame = Panel.new()
	map_frame.position = Vector2(12, 44)
	map_frame.size = VIEW_SIZE
	var sb_mf = StyleBoxFlat.new()
	sb_mf.bg_color = Color(0.04, 0.05, 0.07, 1.0)
	sb_mf.border_width_left = 1
	sb_mf.border_width_top = 1
	sb_mf.border_width_right = 1
	sb_mf.border_width_bottom = 1
	sb_mf.border_color = Color(0.35, 0.4, 0.48, 0.9)
	map_frame.add_theme_stylebox_override("panel", sb_mf)
	panel_container.add_child(map_frame)

	# Viewport vẽ bản đồ
	map_viewport = BigMapCanvas.new()
	map_viewport.window = self
	map_viewport.position = Vector2.ZERO
	map_viewport.size = VIEW_SIZE
	map_viewport.custom_minimum_size = VIEW_SIZE
	map_viewport.clip_contents = true
	map_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	map_viewport.gui_input.connect(_on_map_gui_input)
	map_frame.add_child(map_viewport)

	# Nhãn toạ độ theo con trỏ chuột
	lbl_cursor_coords = Label.new()
	lbl_cursor_coords.position = Vector2(8, VIEW_SIZE.y - 24)
	lbl_cursor_coords.size = Vector2(180, 20)
	lbl_cursor_coords.text = "Trỏ chuột: (-- , --)"
	lbl_cursor_coords.add_theme_font_size_override("font_size", 10)
	lbl_cursor_coords.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6, 0.9))
	lbl_cursor_coords.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_cursor_coords.add_theme_constant_override("outline_size", 2)
	map_frame.add_child(lbl_cursor_coords)

	# Nút điều khiển Map: Zoom +, Zoom -, Định vị, Xoay 45°
	var ctrl_bar = HBoxContainer.new()
	ctrl_bar.position = Vector2(VIEW_SIZE.x - 170, 8)
	ctrl_bar.size = Vector2(165, 24)
	ctrl_bar.add_theme_constant_override("separation", 4)
	map_frame.add_child(ctrl_bar)

	var btn_zoom_in = _create_icon_button("+", "Phóng to bản đồ")
	btn_zoom_in.pressed.connect(func(): _set_zoom(zoom_level + 0.3))
	ctrl_bar.add_child(btn_zoom_in)

	var btn_zoom_out = _create_icon_button("-", "Thu nhỏ bản đồ")
	btn_zoom_out.pressed.connect(func(): _set_zoom(zoom_level - 0.3))
	ctrl_bar.add_child(btn_zoom_out)

	var btn_focus = _create_icon_button("🎯", "Định vị vị trí nhân vật")
	btn_focus.pressed.connect(_focus_on_player)
	ctrl_bar.add_child(btn_focus)

	var btn_rotate = _create_icon_button("🔄", "Chuyển chế độ: Top-Down / Xoay 45° MU")
	btn_rotate.pressed.connect(_toggle_rotation_mode)
	ctrl_bar.add_child(btn_rotate)

	# 5. Cột phải: Danh Sách NPC & Cổng Dịch Chuyển
	var list_panel = Panel.new()
	list_panel.position = Vector2(520, 44)
	list_panel.size = Vector2(228, VIEW_SIZE.y)
	var sb_lp = StyleBoxFlat.new()
	sb_lp.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb_lp.border_width_left = 1
	sb_lp.border_width_top = 1
	sb_lp.border_width_right = 1
	sb_lp.border_width_bottom = 1
	sb_lp.border_color = Color(0.3, 0.35, 0.45, 0.8)
	sb_lp.corner_radius_top_right = 4
	sb_lp.corner_radius_bottom_right = 4
	list_panel.add_theme_stylebox_override("panel", sb_lp)
	panel_container.add_child(list_panel)

	# 5.1. Khung Nhập Tọa Độ Tìm Đường Tự Động
	var nav_box = Panel.new()
	nav_box.position = Vector2(6, 6)
	nav_box.size = Vector2(216, 56)
	var sb_nb = StyleBoxFlat.new()
	sb_nb.bg_color = Color(0.05, 0.07, 0.1, 0.9)
	sb_nb.border_width_left = 1
	sb_nb.border_width_top = 1
	sb_nb.border_width_right = 1
	sb_nb.border_width_bottom = 1
	sb_nb.border_color = Color(0.45, 0.4, 0.25, 0.8)
	sb_nb.corner_radius_top_left = 4
	sb_nb.corner_radius_top_right = 4
	sb_nb.corner_radius_bottom_left = 4
	sb_nb.corner_radius_bottom_right = 4
	nav_box.add_theme_stylebox_override("panel", sb_nb)
	list_panel.add_child(nav_box)

	var lbl_nav_title = Label.new()
	lbl_nav_title.position = Vector2(4, 3)
	lbl_nav_title.size = Vector2(208, 16)
	lbl_nav_title.text = "TÌM ĐƯỜNG THEO TỌA ĐỘ"
	lbl_nav_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nav_title.add_theme_font_size_override("font_size", 10)
	lbl_nav_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	nav_box.add_child(lbl_nav_title)

	var hbox_nav = HBoxContainer.new()
	hbox_nav.position = Vector2(6, 22)
	hbox_nav.size = Vector2(204, 26)
	hbox_nav.add_theme_constant_override("separation", 3)
	nav_box.add_child(hbox_nav)

	var lbl_x = Label.new()
	lbl_x.text = "X:"
	lbl_x.add_theme_font_size_override("font_size", 10)
	lbl_x.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	hbox_nav.add_child(lbl_x)

	input_coord_x = LineEdit.new()
	input_coord_x.custom_minimum_size = Vector2(40, 22)
	input_coord_x.placeholder_text = "140"
	input_coord_x.max_length = 3
	input_coord_x.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_coord_x.add_theme_font_size_override("font_size", 10)
	input_coord_x.text_submitted.connect(func(_t): _on_auto_path_pressed())
	hbox_nav.add_child(input_coord_x)

	var lbl_y = Label.new()
	lbl_y.text = "Y:"
	lbl_y.add_theme_font_size_override("font_size", 10)
	lbl_y.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	hbox_nav.add_child(lbl_y)

	input_coord_y = LineEdit.new()
	input_coord_y.custom_minimum_size = Vector2(40, 22)
	input_coord_y.placeholder_text = "119"
	input_coord_y.max_length = 3
	input_coord_y.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_coord_y.add_theme_font_size_override("font_size", 10)
	input_coord_y.text_submitted.connect(func(_t): _on_auto_path_pressed())
	hbox_nav.add_child(input_coord_y)

	btn_auto_path = Button.new()
	btn_auto_path.text = "Tìm đường"
	btn_auto_path.custom_minimum_size = Vector2(68, 22)
	btn_auto_path.add_theme_font_size_override("font_size", 10)
	var sb_go = StyleBoxFlat.new()
	sb_go.bg_color = Color(0.18, 0.32, 0.2, 0.95)
	sb_go.border_width_left = 1
	sb_go.border_width_top = 1
	sb_go.border_width_right = 1
	sb_go.border_width_bottom = 1
	sb_go.border_color = Color(0.38, 0.65, 0.42, 0.9)
	sb_go.corner_radius_top_left = 3
	sb_go.corner_radius_top_right = 3
	sb_go.corner_radius_bottom_left = 3
	sb_go.corner_radius_bottom_right = 3
	btn_auto_path.add_theme_stylebox_override("normal", sb_go)
	btn_auto_path.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	btn_auto_path.pressed.connect(_on_auto_path_pressed)
	hbox_nav.add_child(btn_auto_path)

	# 5.2. Danh Sách Điểm Đến Nhanh (NPC & Cổng)
	var lbl_list_title = Label.new()
	lbl_list_title.position = Vector2(8, 68)
	lbl_list_title.size = Vector2(212, 18)
	lbl_list_title.text = "ĐIỂM ĐẾN NHANH (NPC / CỔNG)"
	lbl_list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_list_title.add_theme_font_size_override("font_size", 10)
	lbl_list_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	list_panel.add_child(lbl_list_title)

	# Hàng nút lọc (Tất cả / NPC / Cổng)
	var filter_bar = HBoxContainer.new()
	filter_bar.position = Vector2(8, 88)
	filter_bar.size = Vector2(212, 22)
	filter_bar.add_theme_constant_override("separation", 3)
	list_panel.add_child(filter_bar)

	filter_all_btn = _create_filter_button("Tất cả", "all")
	filter_bar.add_child(filter_all_btn)
	filter_npc_btn = _create_filter_button("NPC", "npc")
	filter_bar.add_child(filter_npc_btn)
	filter_portal_btn = _create_filter_button("Cổng", "portal")
	filter_bar.add_child(filter_portal_btn)

	# Danh sách cuộn
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(6, 114)
	scroll.size = Vector2(216, VIEW_SIZE.y - 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.custom_minimum_size = Vector2(204, 0)
	list_container.add_theme_constant_override("separation", 3)
	scroll.add_child(list_container)

	# 6. Footer chỉ dẫn
	var lbl_footer = Label.new()
	lbl_footer.position = Vector2(16, 532)
	lbl_footer.size = Vector2(728, 20)
	lbl_footer.text = "• Nhập tọa độ (X, Y) hoặc nhấp chuột vào bản đồ / danh sách để tự động tìm đường | Phím tắt: TAB / M / ESC"
	lbl_footer.add_theme_font_size_override("font_size", 10)
	lbl_footer.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.8))
	panel_container.add_child(lbl_footer)

	# Tooltip nổi
	tooltip_panel = Panel.new()
	tooltip_panel.size = Vector2(160, 26)
	var sb_tt = StyleBoxFlat.new()
	sb_tt.bg_color = Color(0.05, 0.07, 0.1, 0.95)
	sb_tt.border_width_left = 1
	sb_tt.border_width_top = 1
	sb_tt.border_width_right = 1
	sb_tt.border_width_bottom = 1
	sb_tt.border_color = Color(0.9, 0.8, 0.4, 0.9)
	sb_tt.corner_radius_top_left = 3
	sb_tt.corner_radius_top_right = 3
	sb_tt.corner_radius_bottom_left = 3
	sb_tt.corner_radius_bottom_right = 3
	tooltip_panel.add_theme_stylebox_override("panel", sb_tt)
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_container.add_child(tooltip_panel)

	tooltip_label = Label.new()
	tooltip_label.anchors_preset = Control.PRESET_FULL_RECT
	tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tooltip_label.add_theme_font_size_override("font_size", 10)
	tooltip_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	tooltip_panel.add_child(tooltip_label)

func _add_corner_icon(parent: Control, pos: Vector2, corner_idx: int) -> void:
	var tr = TextureRect.new()
	tr.texture = tex_corner
	tr.position = pos
	tr.size = Vector2(42, 42)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Xoay/Lật góc
	if corner_idx == 1: # TR
		tr.flip_h = true
	elif corner_idx == 2: # BL
		tr.flip_v = true
	elif corner_idx == 3: # BR
		tr.flip_h = true
		tr.flip_v = true
	parent.add_child(tr)

func _create_icon_button(text: String, tooltip: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(24, 22)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.45, 0.5, 0.6, 0.8)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_font_size_override("font_size", 11)
	return btn

func _create_filter_button(text: String, filter_key: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 20)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.16, 0.22, 0.85)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.4, 0.45, 0.55, 0.8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(func(): _apply_marker_filter(filter_key))
	return btn

func _apply_marker_filter(f_key: String) -> void:
	current_filter = f_key
	filtered_markers.clear()
	for m in markers_list:
		var kind = int(m.get("kind", 1))
		if f_key == "all":
			filtered_markers.append(m)
		elif f_key == "npc" and kind == 1:
			filtered_markers.append(m)
		elif f_key == "portal" and kind == 2:
			filtered_markers.append(m)
	_rebuild_markers_list_ui()

const MARKER_NAME_TRANSLATIONS: Dictionary = {
	"trainer": "HLV Trainer",
	"wandering merchant alex": "Thương Nhân Alex",
	"wandering merchant herald": "Thương Nhân Herald",
	"wandering merchant martin": "Thương Nhân Martin",
	"potion girl amy": "Bán Máu Amy",
	"hanzo the blacksmith": "Thợ Rèn Hanzo",
	"lumen the barmaid": "Quán Rượu Lumen",
	"pasi the mage": "Pháp Sư Pasi",
	"safety guardian": "Vệ Binh Hoàng Gia",
	"shadow phantom soldier": "Binh Sĩ Phantom",
	"gens duprian steward": "Quản Gia Duprian",
	"gens vanert steward": "Quản Gia Vanert",
	"chaos card master": "Chủ Thẻ Chaos",
	"chaos goblin": "Yêu Tinh Chaos",
	"lahap": "Thương Nhân Lahap",
	"captain marlon": "Đội Trưởng Marlon",
	"royal guard captain lorence": "Đội Trưởng Lorence",
	"doorkeeper titus": "Gác Cổng Titus",
	"guardsman": "Vệ Binh Hoàng Gia",
	"gatekeeper": "Người Gác Cổng",
	"gateway machine": "Máy Dịch Chuyển",
	"elf lala": "Tiên Nữ Lala",
	"eo the craftsman": "Thợ Thủ Công Eo",
	"charon": "Sứ Giả Charon",
	"caren the barmaid": "Quán Rượu Caren",
	"weapons merchant bolo": "Vũ Khí Bolo",
	"weapons merchant rhea": "Vũ Khí Rhea",
	"weapons merchant zienna": "Vũ Khí Zienna",
	"potion merchant silvia": "Bán Máu Silvia",
	"sebina the priest": "Giáo Sĩ Sebina",
	"wizard izabel": "Phù Thủy Izabel",
	"magic shop owner marce": "Cửa Hàng Phép Marce",
	"werewolf quarel": "Người Sói Quarel",
	"apostle devin": "Tông Đồ Devin",
	"david": "Thương Nhân David",
	"jerridon": "Thợ Rèn Jerridon",
	"osbourne": "Chế Tác Osbourne",
	"seed master": "Bậc Thầy Seed",
	"seed researcher": "Nghiên Cứu Seed",
	"moss": "Thương Nhân Moss",
	"mirage": "Ảo Ảnh Mirage",
	"messenger of archangel": "Sứ Giả Archangel",
	"leina, the general goods merchant": "Tạp Hóa Leina",
	"natasha the firecracker merchant": "Bán Pháo Natasha",
	"mercenary guild manager tercia": "Quản Lý Tercia",
	"jerint the assistant": "Trợ Lý Jerint",
	"lugard": "Sứ Giả Lugard",
	"vault keeper": "Thủ Kho",
	"dungeon entrance": "Cổng vào Dungeon",
	"dungeon level 1 entrance": "Cổng Dungeon 1",
	"dungeon level 2 entrance": "Cổng Dungeon 2",
	"dungeon level 2 east entrance": "Cổng Dungeon 2 (Đông)",
	"dungeon level 2 west entrance": "Cổng Dungeon 2 (Tây)",
	"dungeon level 3 east entrance": "Cổng Dungeon 3 (Đông)",
	"dungeon level 3 west entrance": "Cổng Dungeon 3 (Tây)",
	"entrance to devias": "Cổng đi Devias",
	"entrance to noria": "Cổng đi Noria",
	"entrance to lorencia": "Cổng về Lorencia",
	"entrance to dungeon": "Cổng đi Dungeon",
	"entrance to atlans": "Cổng đi Atlans",
	"entrance to lost tower": "Cổng đi Lost Tower",
	"entrance to the lost tower": "Cổng đi Lost Tower",
	"entrance to tarkan": "Cổng đi Tarkan",
	"entrance to aida": "Cổng đi Aida",
	"entrance to icarus": "Cổng đi Icarus",
	"entrance to elveland": "Cổng đi Elveland",
	"entrance to karutan": "Cổng đi Karutan",
	"entrance to karutan 1": "Cổng đi Karutan 1",
	"entrance to karutan 2": "Cổng đi Karutan 2",
	"entrance to la cleon": "Cổng đi Raklion",
	"entrance to valley of loren": "Cổng đi Công Thành (Loren)",
	"entrance to the valley of loren": "Cổng đi Công Thành (Loren)",
	"entrance to safe zone": "Cổng Vùng An Toàn",
	"entrance to the kanturu ruins": "Cổng Kanturu Tàn Tích",
	"entrance to the kanturu relics": "Cổng Kanturu Di Tích",
	"entrance to the hatchery": "Cổng Hang Nhện Raklion",
	"lost tower level 2 entrance": "Cổng Lost Tower 2",
	"lost tower level 3 entrance": "Cổng Lost Tower 3",
	"lost tower level 4 entrance": "Cổng Lost Tower 4",
	"lost tower level 5 entrance": "Cổng Lost Tower 5",
	"lost tower level 6 entrance": "Cổng Lost Tower 6",
	"lost tower level 7 entrance": "Cổng Lost Tower 7",
}

const MARKER_SHORT_NAMES: Dictionary = {
	"trainer": "Trainer",
	"wandering merchant alex": "Alex",
	"wandering merchant herald": "Herald",
	"wandering merchant martin": "Martin",
	"potion girl amy": "Amy",
	"hanzo the blacksmith": "Hanzo",
	"lumen the barmaid": "Lumen",
	"pasi the mage": "Pasi",
	"safety guardian": "Vệ Binh",
	"shadow phantom soldier": "Phantom",
	"gens duprian steward": "Duprian",
	"gens vanert steward": "Vanert",
	"chaos card master": "Chaos Card",
	"chaos goblin": "Goblin",
	"lahap": "Lahap",
	"captain marlon": "Marlon",
	"royal guard captain lorence": "Lorence",
	"doorkeeper titus": "Titus",
	"guardsman": "Vệ Binh",
	"gatekeeper": "Gác Cổng",
	"gateway machine": "Dịch Chuyển",
	"elf lala": "Lala",
	"eo the craftsman": "Eo",
	"charon": "Charon",
	"caren the barmaid": "Caren",
	"weapons merchant bolo": "Bolo",
	"weapons merchant rhea": "Rhea",
	"weapons merchant zienna": "Zienna",
	"potion merchant silvia": "Silvia",
	"sebina the priest": "Sebina",
	"wizard izabel": "Izabel",
	"magic shop owner marce": "Marce",
	"werewolf quarel": "Quarel",
	"apostle devin": "Devin",
	"david": "David",
	"jerridon": "Jerridon",
	"osbourne": "Osbourne",
	"seed master": "Seed Master",
	"seed researcher": "Seed Res.",
	"moss": "Moss",
	"mirage": "Mirage",
	"messenger of archangel": "Archangel",
	"leina, the general goods merchant": "Leina",
	"natasha the firecracker merchant": "Natasha",
	"mercenary guild manager tercia": "Tercia",
	"jerint the assistant": "Jerint",
	"lugard": "Lugard",
	"vault keeper": "Thủ Kho",
	"dungeon entrance": "Dungeon",
	"dungeon level 1 entrance": "Dungeon 1",
	"dungeon level 2 entrance": "Dungeon 2",
	"dungeon level 2 east entrance": "Dungeon 2-Đ",
	"dungeon level 2 west entrance": "Dungeon 2-T",
	"dungeon level 3 east entrance": "Dungeon 3-Đ",
	"dungeon level 3 west entrance": "Dungeon 3-T",
	"entrance to devias": "Devias",
	"entrance to noria": "Noria",
	"entrance to lorencia": "Lorencia",
	"entrance to dungeon": "Dungeon",
	"entrance to atlans": "Atlans",
	"entrance to lost tower": "Lost Tower",
	"entrance to the lost tower": "Lost Tower",
	"entrance to tarkan": "Tarkan",
	"entrance to aida": "Aida",
	"entrance to icarus": "Icarus",
	"entrance to elveland": "Elveland",
	"entrance to karutan": "Karutan",
	"entrance to karutan 1": "Karutan 1",
	"entrance to karutan 2": "Karutan 2",
	"entrance to la cleon": "Raklion",
	"entrance to valley of loren": "Công Thành",
	"entrance to the valley of loren": "Công Thành",
	"entrance to safe zone": "An Toàn",
	"entrance to the kanturu ruins": "Kanturu 1",
	"entrance to the kanturu relics": "Kanturu 2",
	"entrance to the hatchery": "Hang Nhện",
	"lost tower level 2 entrance": "LT 2",
	"lost tower level 3 entrance": "LT 3",
	"lost tower level 4 entrance": "LT 4",
	"lost tower level 5 entrance": "LT 5",
	"lost tower level 6 entrance": "LT 6",
	"lost tower level 7 entrance": "LT 7",
}

func _get_marker_display_name(m: Dictionary) -> String:
	var raw_name = str(m.get("name", "")).strip_edges()
	if raw_name.is_empty():
		return "NPC" if int(m.get("kind", 1)) == 1 else "Cổng"
	var key = raw_name.to_lower()
	if MARKER_NAME_TRANSLATIONS.has(key):
		return MARKER_NAME_TRANSLATIONS[key]
	return raw_name

func _get_marker_full_name(m: Dictionary) -> String:
	var disp = _get_marker_display_name(m)
	var raw = str(m.get("name", "")).strip_edges()
	if raw.is_empty() or raw.to_lower() == disp.to_lower():
		return disp
	return "%s (%s)" % [disp, raw]

func _get_marker_short_name(m: Dictionary) -> String:
	var raw = str(m.get("name", "")).strip_edges()
	var lower = raw.to_lower()
	if MARKER_SHORT_NAMES.has(lower):
		return MARKER_SHORT_NAMES[lower]
	return _get_marker_display_name(m)

func _rebuild_markers_list_ui() -> void:
	if not list_container:
		return
	for c in list_container.get_children():
		c.queue_free()

	for m in filtered_markers:
		var kind = int(m.get("kind", 1))
		var target_x = int(m.get("x", 0))
		var target_y = int(m.get("y", 0))
		var disp_name = _get_marker_display_name(m)
		var full_name = _get_marker_full_name(m)

		var row = Button.new()
		row.flat = true
		row.custom_minimum_size = Vector2(200, 26)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.tooltip_text = "%s [%d, %d]\n• Nhấp chuột để tự động di chuyển tới đây" % [full_name, target_x, target_y]

		var sb_norm = StyleBoxFlat.new()
		sb_norm.bg_color = Color(0.12, 0.15, 0.2, 0.5)
		sb_norm.border_width_bottom = 1
		sb_norm.border_color = Color(0.2, 0.25, 0.35, 0.4)
		row.add_theme_stylebox_override("normal", sb_norm)

		var sb_hover = StyleBoxFlat.new()
		sb_hover.bg_color = Color(0.2, 0.26, 0.38, 0.8)
		sb_hover.border_width_left = 2
		sb_hover.border_color = Color(0.9, 0.8, 0.3, 1.0)
		row.add_theme_stylebox_override("hover", sb_hover)

		var sb_pressed = StyleBoxFlat.new()
		sb_pressed.bg_color = Color(0.15, 0.3, 0.25, 0.9)
		sb_pressed.border_width_left = 3
		sb_pressed.border_color = Color(0.3, 0.9, 0.4, 1.0)
		row.add_theme_stylebox_override("pressed", sb_pressed)

		# HBoxContainer nằm bên trong Button
		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 5)
		row.add_child(hbox)

		# Định vị hbox lấp đầy row với lề 6px hai bên
		hbox.anchor_left = 0.0
		hbox.anchor_top = 0.0
		hbox.anchor_right = 1.0
		hbox.anchor_bottom = 1.0
		hbox.offset_left = 6
		hbox.offset_right = -6
		hbox.offset_top = 0
		hbox.offset_bottom = 0

		# 1. Icon NPC hoặc Cổng
		var icon_rect = TextureRect.new()
		icon_rect.texture = tex_portal if kind == 2 else tex_npc
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon_rect)

		# 2. Tên NPC / Cổng hiển thị rõ ràng, nổi bật
		var lbl_m_name = Label.new()
		lbl_m_name.text = disp_name
		lbl_m_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_m_name.custom_minimum_size = Vector2(95, 0)
		lbl_m_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_m_name.add_theme_font_size_override("font_size", 10)
		lbl_m_name.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0) if kind == 2 else Color(0.98, 0.92, 0.72))
		lbl_m_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl_m_name)

		# 3. Tọa độ (X, Y)
		var lbl_m_pos = Label.new()
		lbl_m_pos.text = "(%d, %d)" % [target_x, target_y]
		lbl_m_pos.custom_minimum_size = Vector2(54, 0)
		lbl_m_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_m_pos.add_theme_font_size_override("font_size", 9)
		lbl_m_pos.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		lbl_m_pos.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl_m_pos)

		row.pressed.connect(func(): _on_marker_row_clicked(target_x, target_y, disp_name))
		list_container.add_child(row)

func _on_marker_row_clicked(target_x: int, target_y: int, m_name: String) -> void:
	if input_coord_x and input_coord_y:
		input_coord_x.text = str(target_x)
		input_coord_y.text = str(target_y)
	_command_move_to_grid(target_x, target_y, m_name)

func _on_auto_path_pressed() -> void:
	if not input_coord_x or not input_coord_y:
		return
	var str_x = input_coord_x.text.strip_edges()
	var str_y = input_coord_y.text.strip_edges()
	if str_x.is_empty():
		str_x = input_coord_x.placeholder_text
	if str_y.is_empty():
		str_y = input_coord_y.placeholder_text

	if not str_x.is_valid_int() or not str_y.is_valid_int():
		var tree = get_tree() if is_inside_tree() else null
		var hud = tree.get_first_node_in_group("HUD") if tree else null
		if hud and hud.has_method("show_pickup_notification"):
			hud.show_pickup_notification("Tọa độ không hợp lệ! Vui lòng nhập số từ 0 đến 255.", Color(1.0, 0.4, 0.4))
		return

	var gx = clampi(str_x.to_int(), 0, 255)
	var gy = clampi(str_y.to_int(), 0, 255)
	input_coord_x.text = str(gx)
	input_coord_y.text = str(gy)

	if MuAudioManager:
		MuAudioManager.play_ui_click()

	_command_move_to_grid(gx, gy, "Tọa độ (%d, %d)" % [gx, gy])

func _command_move_to_grid(gx: int, gy: int, label: String = "") -> void:
	dest_marker = Vector2(gx, gy)
	dest_ping_time = 3.0

	var tree = get_tree() if is_inside_tree() else null
	var hud = tree.get_first_node_in_group("HUD") if tree else null
	if player and MuWorld.current:
		var cur_pos = Vector2i(player.grid_x, player.grid_y)
		var target_pos = Vector2i(gx, gy)
		var path = MuWorld.current.find_path_grid(cur_pos, target_pos)
		if path.size() > 0:
			player.move_to_path(path)
			if hud and hud.has_method("show_pickup_notification"):
				var desc = "★ Đang tự động tìm đường tới: %s (%d, %d)" % [label if label != "" else "Tọa độ", gx, gy]
				hud.show_pickup_notification(desc, Color(0.3, 0.95, 0.4))
		else:
			if hud and hud.has_method("show_pickup_notification"):
				var desc = "Không tìm thấy đường tới %s (%d, %d) (bị chặn hoặc không thể đi tới)!" % [label if label != "" else "Tọa độ", gx, gy]
				hud.show_pickup_notification(desc, Color(1.0, 0.4, 0.4))

	if map_viewport:
		map_viewport.queue_redraw()

func _set_zoom(val: float) -> void:
	zoom_level = clampf(val, 1.0, 3.0)
	if map_viewport:
		map_viewport.queue_redraw()

func _focus_on_player() -> void:
	pan_offset = Vector2.ZERO
	if map_viewport:
		map_viewport.queue_redraw()

func _toggle_rotation_mode() -> void:
	is_rotated_45 = not is_rotated_45
	if map_viewport:
		map_viewport.queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	if dest_ping_time > 0.0:
		dest_ping_time -= delta
		if map_viewport:
			map_viewport.queue_redraw()
	elif player and map_viewport:
		map_viewport.queue_redraw()

# -------------------------------------------------------------
# Vẽ Bản Đồ Lớn (Custom Draw)
# -------------------------------------------------------------
func draw_big_map_canvas(canvas: Control) -> void:
	if not canvas:
		return
	var v_size = canvas.size
	if v_size.x <= 1.0 or v_size.y <= 1.0:
		v_size = VIEW_SIZE
		canvas.size = v_size
	var center = v_size * 0.5 + pan_offset

	var gx = player.grid_x if player else 140
	var gy = player.grid_y if player else 119

	# 1. Vẽ ảnh bản đồ địa hình (Texture 1024x1024)
	if current_map_texture:
		var tex_w = current_map_texture.get_width()
		var tex_h = current_map_texture.get_height()

		# Khi zoom_level = 1.0, map hiển thị toàn bộ 256x256 ô hình vuông
		var map_draw_size = Vector2(VIEW_SIZE.y, VIEW_SIZE.y) * zoom_level
		var map_top_left = center - map_draw_size * 0.5

		# Nếu ở chế độ 45° chuẩn CMiniMap gốc
		if is_rotated_45:
			# Vẽ xoay quanh tâm người chơi
			var center_hero_px = Vector2(gx * (tex_w / 256.0), (255.0 - gy) * (tex_h / 256.0))
			var view_span = 400.0 / zoom_level
			var src_rect = Rect2(center_hero_px - Vector2(view_span, view_span) * 0.5, Vector2(view_span, view_span))
			canvas.draw_texture_rect_region(current_map_texture, Rect2(Vector2.ZERO, v_size), src_rect)
		else:
			# Chế độ bản đồ toàn cảnh 2D Grid
			canvas.draw_texture_rect(current_map_texture, Rect2(map_top_left, map_draw_size), false)

		# Đường lưới & Toạ độ biên
		_draw_grid_overlay(canvas, map_top_left, map_draw_size)

		# 2. Vẽ NPC và Cổng Dịch Chuyển
		var fallback_font := ThemeDB.fallback_font
		for m in markers_list:
			var mx = float(m.get("x", 0))
			var my = float(m.get("y", 0))
			var kind = int(m.get("kind", 1))
			var m_screen_pos: Vector2 = _grid_to_screen(mx, my, map_top_left, map_draw_size)
			if _is_inside_view(m_screen_pos, v_size):
				if kind == 2 and tex_portal:
					canvas.draw_texture(tex_portal, m_screen_pos - Vector2(9, 9))
				elif tex_npc:
					canvas.draw_texture(tex_npc, m_screen_pos - Vector2(9, 9))
				else:
					var col = Color(0.2, 0.85, 0.95, 0.9) if kind == 2 else Color(0.95, 0.85, 0.2, 0.9)
					canvas.draw_circle(m_screen_pos, 4.0, col)

				# Vẽ tên NPC / Cổng trực tiếp dưới icon trên bản đồ
				var short_name := _get_marker_short_name(m)
				if not short_name.is_empty():
					var text_pos: Vector2 = Vector2(m_screen_pos.x - 45.0, m_screen_pos.y + 16.0)
					var txt_col := Color(0.8, 0.92, 1.0) if kind == 2 else Color(1.0, 0.95, 0.72)
					canvas.draw_string_outline(fallback_font, text_pos, short_name, HORIZONTAL_ALIGNMENT_CENTER, 90, 9, 3, Color(0, 0, 0, 0.9))
					canvas.draw_string(fallback_font, text_pos, short_name, HORIZONTAL_ALIGNMENT_CENTER, 90, 9, txt_col)

		# 3. Quái vật lân cận (Chấm đỏ)
		var monsters = get_tree().get_nodes_in_group("Monster")
		for mon in monsters:
			if mon is MuMonster and is_instance_valid(mon) and not mon.is_dead:
				var m_pos = _grid_to_screen(float(mon.grid_x), float(mon.grid_y), map_top_left, map_draw_size)
				if _is_inside_view(m_pos, v_size):
					canvas.draw_circle(m_pos, 2.5, Color(0.95, 0.2, 0.2, 0.85))

		# 4. Hiệu ứng Ping vị trí đích đến
		if dest_ping_time > 0.0 and dest_marker.x >= 0:
			var dest_screen = _grid_to_screen(dest_marker.x, dest_marker.y, map_top_left, map_draw_size)
			var pulse_r = 6.0 + sin(dest_ping_time * 8.0) * 3.0
			canvas.draw_circle(dest_screen, pulse_r, Color(0.2, 0.95, 0.4, 0.6))
			canvas.draw_arc(dest_screen, pulse_r + 4.0, 0, TAU, 16, Color(0.4, 1.0, 0.5, 0.8), 2.0)

		# 5. Vị trí người chơi (Mũi tên hoặc Icon)
		var player_screen_pos = _grid_to_screen(float(gx), float(gy), map_top_left, map_draw_size)
		if _is_inside_view(player_screen_pos, v_size):
			# Vòng hào quang sáng nhấp nháy quanh nhân vật
			canvas.draw_arc(player_screen_pos, 10.0, 0, TAU, 16, Color(0.95, 0.85, 0.3, 0.8), 2.0)
			if tex_hero:
				canvas.draw_texture(tex_hero, player_screen_pos - Vector2(9, 9))
			else:
				var angle = 0.0
				if player:
					angle = -player.rotation.y - PI * 0.5
				_draw_player_arrow(canvas, player_screen_pos, angle)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, v_size), Color(0.1, 0.12, 0.16, 1.0))

func _grid_to_screen(mx: float, my: float, map_tl: Vector2, map_sz: Vector2) -> Vector2:
	# Tọa độ chuẩn MU: X từ 0..255 (trái qua phải), Y từ 0..255 (dưới lên trên -> đảo trục Y)
	var norm_x = mx / 256.0
	var norm_y = (255.0 - my) / 256.0
	return map_tl + Vector2(norm_x * map_sz.x, norm_y * map_sz.y)

func _screen_to_grid(s_pos: Vector2, map_tl: Vector2, map_sz: Vector2) -> Vector2i:
	var norm_x = (s_pos.x - map_tl.x) / map_sz.x
	var norm_y = (s_pos.y - map_tl.y) / map_sz.y
	var gx = clampi(int(norm_x * 256.0), 0, 255)
	var gy = clampi(int(255.0 - norm_y * 256.0), 0, 255)
	return Vector2i(gx, gy)

func _is_inside_view(p: Vector2, v_size: Vector2) -> bool:
	return p.x >= 0 and p.x <= v_size.x and p.y >= 0 and p.y <= v_size.y

func _draw_grid_overlay(canvas: Control, map_tl: Vector2, map_sz: Vector2) -> void:
	# Vẽ các vạch chia toạ độ mốc 64, 128, 192, 255
	for step in [64, 128, 192]:
		var px_x = map_tl.x + (float(step) / 256.0) * map_sz.x
		var px_y = map_tl.y + ((255.0 - float(step)) / 256.0) * map_sz.y
		canvas.draw_line(Vector2(px_x, map_tl.y), Vector2(px_x, map_tl.y + map_sz.y), Color(0.3, 0.4, 0.5, 0.2), 1.0)
		canvas.draw_line(Vector2(map_tl.x, px_y), Vector2(map_tl.x + map_sz.x, px_y), Color(0.3, 0.4, 0.5, 0.2), 1.0)

func _draw_player_arrow(canvas: Control, pos: Vector2, angle: float) -> void:
	var tip = pos + Vector2(cos(angle), sin(angle)) * 8.0
	var left = pos + Vector2(cos(angle + 2.5), sin(angle + 2.5)) * 6.0
	var right = pos + Vector2(cos(angle - 2.5), sin(angle - 2.5)) * 6.0
	var inner = pos + Vector2(cos(angle + PI), sin(angle + PI)) * 2.5
	var points = PackedVector2Array([tip, left, inner, right])
	canvas.draw_colored_polygon(points, Color(0.25, 0.95, 0.35, 1.0))
	canvas.draw_polyline(PackedVector2Array([tip, left, inner, right, tip]), Color(0.05, 0.3, 0.1, 1.0), 1.2)

# -------------------------------------------------------------
# Xử lý Tương Tác Chuột & Phím
# -------------------------------------------------------------
func _on_map_gui_input(event: InputEvent) -> void:
	var v_size = map_viewport.size
	if v_size.x <= 1.0 or v_size.y <= 1.0:
		v_size = VIEW_SIZE
	var center = v_size * 0.5 + pan_offset
	var map_draw_size = Vector2(VIEW_SIZE.y, VIEW_SIZE.y) * zoom_level
	var map_top_left = center - map_draw_size * 0.5

	if event is InputEventMouseMotion:
		var grid_pos = _screen_to_grid(event.position, map_top_left, map_draw_size)
		if lbl_cursor_coords:
			lbl_cursor_coords.text = "Trỏ chuột: (%d, %d)" % [grid_pos.x, grid_pos.y]

		# Kéo bản đồ khi giữ chuột phải
		if is_dragging:
			pan_offset = pan_start + (event.position - drag_start)
			map_viewport.queue_redraw()

		# Kiểm tra di chuột vào Marker nào
		_check_hover_marker(event.position, map_top_left, map_draw_size)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var target = _screen_to_grid(event.position, map_top_left, map_draw_size)
			if input_coord_x and input_coord_y:
				input_coord_x.text = str(target.x)
				input_coord_y.text = str(target.y)
			_command_move_to_grid(target.x, target.y)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging = true
				drag_start = event.position
				pan_start = pan_offset
			else:
				is_dragging = false

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(zoom_level + 0.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(zoom_level - 0.15)

func _check_hover_marker(m_pos: Vector2, map_tl: Vector2, map_sz: Vector2) -> void:
	var found = false
	for m in markers_list:
		var mx = float(m.get("x", 0))
		var my = float(m.get("y", 0))
		var s_pos = _grid_to_screen(mx, my, map_tl, map_sz)
		if s_pos.distance_to(m_pos) < 14.0:
			tooltip_panel.visible = true
			tooltip_panel.position = panel_container.get_local_mouse_position() + Vector2(14, -20)
			var kind = int(m.get("kind", 1))
			var prefix = "[CỔNG] " if kind == 2 else "[NPC] "
			var full_name = _get_marker_full_name(m)
			var text_content = "%s%s (%d, %d)" % [prefix, full_name, int(mx), int(my)]
			tooltip_label.text = text_content
			var req_w = maxf(180.0, ThemeDB.fallback_font.get_string_size(text_content, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 24.0)
			tooltip_panel.size = Vector2(req_w, 26)
			found = true
			break
	if not found and tooltip_panel:
		tooltip_panel.visible = false

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB or event.keycode == KEY_M:
			close()
			get_viewport().set_input_as_handled()

# -------------------------------------------------------------
# Mở / Đóng Bản Đồ
# -------------------------------------------------------------
func open_map() -> void:
	if not panel_container:
		_load_textures()
		_build_ui()
	_update_map_data()
	visible = true
	_on_viewport_resized()
	if player:
		_on_player_position_changed(player.grid_x, player.grid_y)
		if input_coord_x and input_coord_x.text.is_empty():
			input_coord_x.placeholder_text = str(player.grid_x)
		if input_coord_y and input_coord_y.text.is_empty():
			input_coord_y.placeholder_text = str(player.grid_y)
		_focus_on_player()
	if map_viewport:
		map_viewport.queue_redraw()

func close() -> void:
	visible = false
	if tooltip_panel:
		tooltip_panel.visible = false
	closed.emit()

func toggle() -> void:
	if visible:
		close()
	else:
		open_map()
