extends Control
class_name MuMiniMapWidget

## Bản Đồ Mini & Tọa Độ Góc Trên Bên Phải (Mobile MU Origin Mini Map)
## - Thanh tiêu đề Tên Bản Đồ & Tọa độ (Vd: Devias (228, 32) ▼ / Lorencia (140, 119) ▼)
## - Khung Bản đồ hình vuông viền kim loại tối màu bo tròn
## - Render ảnh địa hình thực tế của map (minimap_world_1.png cho Lorencia, minimap_world_3.png cho Devias...)
## - Mũi tên xanh lá cây biểu thị vị trí & hướng nhìn của người chơi
## - Hiển thị chấm đỏ cho Quái vật, chấm vàng cho NPC, chấm xanh ngọc cho Cổng
## - Nút thu phóng (+ / -) góc trên bản đồ
## - Nhấp vào mini map để phóng to mở Bản Đồ Lớn Toàn Cảnh (Big Map)

@export var player: MuPlayer = null

var lbl_location: Label
var lbl_coords: Label
var map_viewport_container: Control
var zoom_level: float = 1.0 # 1.0x, 1.5x, 2.0x
var current_map_texture: Texture2D = null
var current_world_id: int = 1
var current_map_name: String = "Lorencia"
var world_markers: Array = []

# Kích thước khung hiển thị minimap
const MAP_SIZE := 124.0

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE + 28)
	size = Vector2(MAP_SIZE, MAP_SIZE + 28)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_ui()
	_update_map_texture()
	if player:
		setup(player)

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if not player:
		return
	if not player.position_changed.is_connected(_on_position_changed):
		player.position_changed.connect(_on_position_changed)
	_on_position_changed(player.grid_x, player.grid_y)

func _update_map_texture() -> void:
	var wid: int = MuTerrain.world_id
	current_world_id = wid
	
	# Tìm tên map từ maps_index.json hoặc fallback
	current_map_name = "World %d" % wid
	var p_idx := "res://assets/mu/maps/maps_index.json"
	if FileAccess.file_exists(p_idx):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p_idx))
		if d is Dictionary and d.has(str(wid)):
			current_map_name = str(d[str(wid)].get("name", current_map_name))
	elif wid == 1:
		current_map_name = "Lorencia"
	elif wid == 2:
		current_map_name = "Dungeon"
	elif wid == 3:
		current_map_name = "Devias"
	elif wid == 4:
		current_map_name = "Noria"
	elif wid == 5:
		current_map_name = "Lost Tower"
	elif wid == 8:
		current_map_name = "Atlans"
	elif wid == 9:
		current_map_name = "Tarkan"

	# Nạp ảnh minimap tương ứng
	var path = "res://assets/textures/ui/minimap/minimap_world_%d.png" % wid
	if ResourceLoader.exists(path):
		current_map_texture = load(path)
	elif ResourceLoader.exists("res://assets/textures/ui/minimap/minimap_world_1.png"):
		current_map_texture = load("res://assets/textures/ui/minimap/minimap_world_1.png")

	# Nạp markers cho thế giới này từ minimap_markers.json
	world_markers.clear()
	var p_mk := "res://assets/mu/minimap_markers.json"
	if FileAccess.file_exists(p_mk):
		var m_dict = JSON.parse_string(FileAccess.get_file_as_string(p_mk))
		if m_dict is Dictionary and m_dict.has(str(wid)):
			world_markers = m_dict[str(wid)]

func _on_position_changed(gx: int, gy: int) -> void:
	if lbl_location:
		lbl_location.text = current_map_name
	if lbl_coords:
		lbl_coords.text = "%d, %d" % [gx, gy]
	if map_viewport_container:
		map_viewport_container.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_open_big_map_pressed()
		accept_event()

func _build_ui() -> void:
	# 1. Thanh tiêu đề vị trí (Hiển thị Tên Map to rõ, không kèm icon phóng to hay tọa độ)
	var header_panel = Panel.new()
	header_panel.name = "HeaderPanel"
	header_panel.position = Vector2(0, 0)
	header_panel.size = Vector2(MAP_SIZE, 24)
	
	var sb_header = StyleBoxFlat.new()
	sb_header.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb_header.border_width_left = 1
	sb_header.border_width_top = 1
	sb_header.border_width_right = 1
	sb_header.border_width_bottom = 1
	sb_header.border_color = Color(0.55, 0.58, 0.65, 0.85)
	sb_header.corner_radius_top_left = 4
	sb_header.corner_radius_top_right = 4
	sb_header.corner_radius_bottom_left = 4
	sb_header.corner_radius_bottom_right = 4
	header_panel.add_theme_stylebox_override("panel", sb_header)
	add_child(header_panel)

	lbl_location = Label.new()
	lbl_location.anchors_preset = Control.PRESET_FULL_RECT
	lbl_location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_location.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_location.add_theme_font_size_override("font_size", 12)
	lbl_location.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	lbl_location.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_location.add_theme_constant_override("outline_size", 3)
	lbl_location.text = current_map_name
	lbl_location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.add_child(lbl_location)

	# Bấm vào thanh tiêu đề mở Bản Đồ Lớn (Big Map)
	var btn_header = Button.new()
	btn_header.anchors_preset = Control.PRESET_FULL_RECT
	btn_header.flat = true
	btn_header.focus_mode = Control.FOCUS_NONE
	btn_header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_header.tooltip_text = "Nhấp để mở Bản Đồ Lớn Toàn Cảnh (M / TAB)"
	var empty_sb = StyleBoxEmpty.new()
	btn_header.add_theme_stylebox_override("normal", empty_sb)
	btn_header.add_theme_stylebox_override("hover", empty_sb)
	btn_header.add_theme_stylebox_override("pressed", empty_sb)
	btn_header.add_theme_stylebox_override("focus", empty_sb)
	btn_header.pressed.connect(_on_open_big_map_pressed)
	header_panel.add_child(btn_header)

	# 2. Khung viền Radar Mini Map
	var radar_frame = Panel.new()
	radar_frame.name = "RadarFrame"
	radar_frame.position = Vector2(0, 26)
	radar_frame.size = Vector2(MAP_SIZE, MAP_SIZE)
	radar_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	radar_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	radar_frame.gui_input.connect(_on_radar_gui_input)
	
	var sb_radar = StyleBoxFlat.new()
	sb_radar.bg_color = Color(0.04, 0.05, 0.07, 0.95)
	sb_radar.border_width_left = 2
	sb_radar.border_width_top = 2
	sb_radar.border_width_right = 2
	sb_radar.border_width_bottom = 2
	sb_radar.border_color = Color(0.35, 0.4, 0.48, 0.9)
	sb_radar.corner_radius_top_left = 6
	sb_radar.corner_radius_top_right = 6
	sb_radar.corner_radius_bottom_left = 6
	sb_radar.corner_radius_bottom_right = 6
	sb_radar.shadow_color = Color(0, 0, 0, 0.6)
	sb_radar.shadow_size = 4
	radar_frame.add_theme_stylebox_override("panel", sb_radar)
	add_child(radar_frame)

	# Khu vực vẽ Minimap tùy biến (Custom draw)
	map_viewport_container = MinimapDrawCanvas.new()
	map_viewport_container.widget = self
	map_viewport_container.position = Vector2(2, 2)
	map_viewport_container.size = Vector2(MAP_SIZE - 4.0, MAP_SIZE - 4.0)
	map_viewport_container.custom_minimum_size = Vector2(MAP_SIZE - 4.0, MAP_SIZE - 4.0)
	map_viewport_container.clip_contents = true
	map_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_frame.add_child(map_viewport_container)

	# Nút bấm tàng hình phủ toàn bộ radar - nhấp bất cứ đâu trên mini map cũng mở Big Map
	var btn_radar_click = Button.new()
	btn_radar_click.anchors_preset = Control.PRESET_FULL_RECT
	btn_radar_click.flat = true
	btn_radar_click.focus_mode = Control.FOCUS_NONE
	btn_radar_click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_radar_click.tooltip_text = "Nhấp để mở Bản Đồ Lớn Toàn Cảnh (M / TAB)"
	btn_radar_click.add_theme_stylebox_override("normal", empty_sb)
	btn_radar_click.add_theme_stylebox_override("hover", empty_sb)
	btn_radar_click.add_theme_stylebox_override("pressed", empty_sb)
	btn_radar_click.add_theme_stylebox_override("focus", empty_sb)
	btn_radar_click.pressed.connect(_on_open_big_map_pressed)
	radar_frame.add_child(btn_radar_click)

	# 3. Khung Tọa độ người chơi hiển thị ngay bên trong Mini Map (phía dưới)
	var coords_badge = Panel.new()
	coords_badge.name = "CoordsBadge"
	coords_badge.position = Vector2((MAP_SIZE - 72.0) * 0.5, MAP_SIZE - 20.0)
	coords_badge.size = Vector2(72, 16)
	coords_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sb_coords = StyleBoxFlat.new()
	sb_coords.bg_color = Color(0.04, 0.06, 0.1, 0.82)
	sb_coords.border_width_left = 1
	sb_coords.border_width_top = 1
	sb_coords.border_width_right = 1
	sb_coords.border_width_bottom = 1
	sb_coords.border_color = Color(0.4, 0.45, 0.55, 0.7)
	sb_coords.corner_radius_top_left = 3
	sb_coords.corner_radius_top_right = 3
	sb_coords.corner_radius_bottom_left = 3
	sb_coords.corner_radius_bottom_right = 3
	coords_badge.add_theme_stylebox_override("panel", sb_coords)
	radar_frame.add_child(coords_badge)

	lbl_coords = Label.new()
	lbl_coords.anchors_preset = Control.PRESET_FULL_RECT
	lbl_coords.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_coords.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_coords.add_theme_font_size_override("font_size", 10)
	lbl_coords.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	lbl_coords.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_coords.add_theme_constant_override("outline_size", 2)
	lbl_coords.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var init_gx = player.grid_x if player else 140
	var init_gy = player.grid_y if player else 119
	lbl_coords.text = "%d, %d" % [init_gx, init_gy]
	coords_badge.add_child(lbl_coords)

class MinimapDrawCanvas extends Control:
	var widget: MuMiniMapWidget
	func _draw() -> void:
		if widget:
			widget.draw_canvas(self)

func _process(_delta: float) -> void:
	if map_viewport_container:
		map_viewport_container.queue_redraw()

func draw_canvas(canvas: Control) -> void:
	if not canvas:
		return
	var v_size = canvas.size
	if v_size.x <= 1.0 or v_size.y <= 1.0:
		v_size = Vector2(MAP_SIZE - 4.0, MAP_SIZE - 4.0)
		canvas.size = v_size
	var center = v_size * 0.5

	# Tọa độ người chơi (0 đến 255)
	var gx = player.grid_x if player else 140
	var gy = player.grid_y if player else 119

	# 1. Vẽ bản đồ địa hình (Texture 1024x1024, mỗi tile = 4px)
	if current_map_texture:
		var tex_w = current_map_texture.get_width()
		var tex_h = current_map_texture.get_height()

		# Vị trí pixel tâm trên texture 1024x1024 (trục Y chuẩn MU đảo ngược: 255 - gy)
		var center_tex_x = gx * (tex_w / 256.0)
		var center_tex_y = (255.0 - gy) * (tex_h / 256.0)

		# Kích thước vùng crop texture dựa trên zoom level
		var view_span = 240.0 / zoom_level
		var half_span = view_span * 0.5
		center_tex_x = clampf(center_tex_x, half_span, tex_w - half_span)
		center_tex_y = clampf(center_tex_y, half_span, tex_h - half_span)
		var src_rect = Rect2(
			center_tex_x - half_span,
			center_tex_y - half_span,
			view_span,
			view_span
		)
		var dest_rect = Rect2(Vector2.ZERO, v_size)
		canvas.draw_texture_rect_region(current_map_texture, dest_rect, src_rect)
	else:
		# Nền kẻ lưới giả lập nếu chưa có texture
		canvas.draw_rect(Rect2(Vector2.ZERO, v_size), Color(0.1, 0.14, 0.18, 1.0))
		for i in range(1, 4):
			var pos_x = (v_size.x / 4.0) * i
			canvas.draw_line(Vector2(pos_x, 0), Vector2(pos_x, v_size.y), Color(0.2, 0.25, 0.35, 0.5))
			var pos_y = (v_size.y / 4.0) * i
			canvas.draw_line(Vector2(0, pos_y), Vector2(v_size.x, pos_y), Color(0.2, 0.25, 0.35, 0.5))

	var scale_factor = (v_size.x / (240.0 / zoom_level)) * 4.0

	# 2. Vẽ Cổng Dịch Chuyển lân cận (Chấm xanh ngọc)
	for m in world_markers:
		if int(m.get("kind", 1)) == 2:
			var px = float(m.get("x", 0))
			var py = float(m.get("y", 0))
			var dx = (px - gx) * scale_factor
			var dy = -(py - gy) * scale_factor
			var dot_pos = center + Vector2(dx, dy)
			if dot_pos.x >= 2 and dot_pos.x <= v_size.x - 2 and dot_pos.y >= 2 and dot_pos.y <= v_size.y - 2:
				canvas.draw_circle(dot_pos, 3.0, Color(0.2, 0.9, 0.95, 0.95))

	# 3. Vẽ Quái vật lân cận (Chấm đỏ)
	var monsters = get_tree().get_nodes_in_group("Monster")
	for m in monsters:
		if m is MuMonster and is_instance_valid(m) and not m.is_dead:
			var dx = (m.grid_x - gx) * scale_factor
			var dy = -(m.grid_y - gy) * scale_factor # Trục Y đảo
			var dot_pos = center + Vector2(dx, dy)
			if dot_pos.x >= 2 and dot_pos.x <= v_size.x - 2 and dot_pos.y >= 2 and dot_pos.y <= v_size.y - 2:
				canvas.draw_circle(dot_pos, 2.5, Color(0.95, 0.2, 0.2, 0.9))

	# 4. Vẽ NPC lân cận (Chấm vàng)
	var npcs = get_tree().get_nodes_in_group("NPC")
	for n in npcs:
		if is_instance_valid(n):
			var n_gx = n.grid_x if "grid_x" in n else 0
			var n_gy = n.grid_y if "grid_y" in n else 0
			var dx = (n_gx - gx) * scale_factor
			var dy = -(n_gy - gy) * scale_factor
			var dot_pos = center + Vector2(dx, dy)
			if dot_pos.x >= 2 and dot_pos.x <= v_size.x - 2 and dot_pos.y >= 2 and dot_pos.y <= v_size.y - 2:
				canvas.draw_circle(dot_pos, 2.5, Color(0.95, 0.85, 0.2, 0.9))

	# 5. Vẽ Mũi tên xanh lá cây người chơi ở chính giữa (Xoay theo hướng nhìn)
	var facing_angle = 0.0
	if player:
		facing_angle = -player.rotation.y - PI * 0.5
	
	_draw_player_arrow(canvas, center, facing_angle)

func _draw_player_arrow(canvas: Control, pos: Vector2, angle: float) -> void:
	var tip = pos + Vector2(cos(angle), sin(angle)) * 7.0
	var left = pos + Vector2(cos(angle + 2.5), sin(angle + 2.5)) * 5.5
	var right = pos + Vector2(cos(angle - 2.5), sin(angle - 2.5)) * 5.5
	var inner = pos + Vector2(cos(angle + PI), sin(angle + PI)) * 2.0
	
	var points = PackedVector2Array([tip, left, inner, right])
	canvas.draw_colored_polygon(points, Color(0.25, 0.95, 0.35, 1.0))
	canvas.draw_polyline(PackedVector2Array([tip, left, inner, right, tip]), Color(0.05, 0.3, 0.1, 1.0), 1.2)

func _on_zoom_pressed() -> void:
	if zoom_level == 1.0:
		zoom_level = 1.5
	elif zoom_level == 1.5:
		zoom_level = 2.0
	else:
		zoom_level = 1.0
	if map_viewport_container:
		map_viewport_container.queue_redraw()

func _on_radar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_open_big_map_pressed()

func _on_open_big_map_pressed() -> void:
	var tree = get_tree() if is_inside_tree() else null
	var hud = tree.get_first_node_in_group("HUD") if tree else null
	if hud and hud.has_method("toggle_big_map"):
		hud.toggle_big_map()
	elif hud and "move_window" in hud and hud.move_window:
		hud.move_window.toggle()
