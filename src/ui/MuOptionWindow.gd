extends Control
class_name MuOptionWindow

## Cửa sổ Cài Đặt Hệ Thống (System Option Window) chuẩn phong cách MU Online Season 6 NewUI:
## - Khung viền & Tiêu đề newui_option_top chuẩn MU gốc
## - Điều chỉnh Âm lượng hiệu ứng âm thanh (Sound FX) & Nhạc nền (BGM)
## - Bật/Tắt Tự động đánh quái (Auto Attack)
## - Bật/Tắt Chế độ Toàn màn hình (Fullscreen)
## - Điều hướng hệ thống: Chọn nhân vật, Chọn server, Về đăng nhập, Thoát game
## - Nút tiện ích: Kho Đồ GM, Đóng tất cả cửa sổ, Nút Đóng / OK

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")

const W := 190.0
const H := 385.0
const S := 1.5

var body: Control
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var slider_sfx: HSlider
var lbl_sfx_val: Label
var slider_bgm: HSlider
var lbl_bgm_val: Label
var chk_auto_attack: TextureButton
var chk_fullscreen: TextureButton
var is_auto_attack: bool = false

# Hộp thoại xác nhận (Confirmation Overlay)
var _confirm_overlay: Control = null
var _confirm_dialog: Panel = null
var _confirm_label: Label = null
var _pending_confirm_action: Callable = Callable()

func _ready() -> void:
	custom_minimum_size = Vector2(W, H) * S
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false
	_build_ui()
	_setup_confirm_dialog()

func _build_ui() -> void:
	body = Control.new()
	body.name = "Body"
	body.position = Vector2.ZERO
	body.size = Vector2(W, H) * S
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(body)

	# 1. Khung nền NewUI
	_add_texture("newui_msgbox_back", Vector2.ZERO, Vector2(W, H) * S)
	_add_texture("newui_option_top", Vector2.ZERO, Vector2(W, 64) * S)
	_add_texture("newui_item_back02-l", Vector2(0, 64) * S, Vector2(21, H - 64 - 45) * S)
	_add_texture("newui_item_back02-r", Vector2(W - 21, 64) * S, Vector2(21, H - 64 - 45) * S)
	_add_texture("newui_item_back03", Vector2(0, H - 45) * S, Vector2(W, 45) * S)

	# 2. Tiêu đề
	var title := MuUiSkinRes.font_label("CÀI ĐẶT HỆ THỐNG", 15, Color(1.0, 0.85, 0.45))
	title.position = Vector2(0, 10 * S)
	title.size = Vector2(W * S, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)

	# Nút đóng [X] góc trên phải (tận dụng icon X nguyên bản trên texture newui_option_top)
	MuUiSkinRes.close_button(body, W, close_window)

	var cur_y := 66.0

	# 3. Phân mục 1: ÂM LƯỢNG HIỆU ỨNG (SFX)
	var lbl_sfx := MuUiSkinRes.font_label("Hiệu ứng âm thanh (SFX):", 12, Color(0.95, 0.88, 0.7))
	lbl_sfx.position = Vector2(18, cur_y) * S
	body.add_child(lbl_sfx)

	lbl_sfx_val = MuUiSkinRes.font_label("100%", 12, Color(0.4, 0.95, 0.4))
	lbl_sfx_val.position = Vector2(W - 55, cur_y) * S
	lbl_sfx_val.size = Vector2(40, 16) * S
	lbl_sfx_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(lbl_sfx_val)

	cur_y += 18.0
	slider_sfx = _create_volume_slider()
	slider_sfx.position = Vector2(18, cur_y) * S
	slider_sfx.size = Vector2(W - 36, 16) * S
	slider_sfx.value = 100
	slider_sfx.value_changed.connect(_on_sfx_changed)
	body.add_child(slider_sfx)

	cur_y += 22.0

	# 4. Phân mục 2: NHẠC NỀN (BGM)
	var lbl_bgm := MuUiSkinRes.font_label("Nhạc nền & Môi trường (BGM):", 12, Color(0.95, 0.88, 0.7))
	lbl_bgm.position = Vector2(18, cur_y) * S
	body.add_child(lbl_bgm)

	lbl_bgm_val = MuUiSkinRes.font_label("100%", 12, Color(0.4, 0.95, 0.4))
	lbl_bgm_val.position = Vector2(W - 55, cur_y) * S
	lbl_bgm_val.size = Vector2(40, 16) * S
	lbl_bgm_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(lbl_bgm_val)

	cur_y += 18.0
	slider_bgm = _create_volume_slider()
	slider_bgm.position = Vector2(18, cur_y) * S
	slider_bgm.size = Vector2(W - 36, 16) * S
	slider_bgm.value = 100
	slider_bgm.value_changed.connect(_on_bgm_changed)
	body.add_child(slider_bgm)

	cur_y += 22.0

	# Đường kẻ phân cách MU
	_add_texture("newui_option_line", Vector2(18, cur_y) * S, Vector2(W - 36, 2) * S)
	cur_y += 8.0

	# 5. Phân mục 3: TỰ ĐỘNG ĐÁNH & TOÀN MÀN HÌNH
	var row_auto := _create_checkbox_row("Tự động đánh quái (Auto)", is_auto_attack, _on_toggle_auto_attack)
	row_auto.position = Vector2(18, cur_y) * S
	body.add_child(row_auto)
	chk_auto_attack = row_auto.get_node("CheckBtn") as TextureButton

	cur_y += 23.0

	var is_fs = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var row_fs := _create_checkbox_row("Chế độ Toàn màn hình", is_fs, _on_toggle_fullscreen)
	row_fs.position = Vector2(18, cur_y) * S
	body.add_child(row_fs)
	chk_fullscreen = row_fs.get_node("CheckBtn") as TextureButton

	cur_y += 24.0

	# Đường kẻ phân cách MU
	_add_texture("newui_option_line", Vector2(18, cur_y) * S, Vector2(W - 36, 2) * S)
	cur_y += 7.0

	# 6. Phân mục 4: HỆ THỐNG & ĐĂNG XUẤT (Thoát game / Đổi NV / Đổi Server / Đăng xuất)
	var lbl_nav := MuUiSkinRes.font_label("HỆ THỐNG & ĐĂNG XUẤT", 11, Color(1.0, 0.85, 0.45))
	lbl_nav.position = Vector2(0, cur_y) * S
	lbl_nav.size = Vector2(W, 16) * S
	lbl_nav.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(lbl_nav)

	cur_y += 17.0

	var col_w := 74.0
	var col_h := 24.0

	# Hàng 1: [ 👤 Chọn NV ]   [ 🌐 Đổi Server ]
	var btn_char := _create_mu_button("👤 Chọn NV", _on_return_to_char_select, 11)
	btn_char.tooltip_text = "Trở về màn hình Chọn Nhân Vật"
	btn_char.position = Vector2(18, cur_y) * S
	btn_char.size = Vector2(col_w, col_h) * S
	body.add_child(btn_char)

	var btn_server := _create_mu_button("🌐 Đổi Server", _on_return_to_server_select, 11)
	btn_server.tooltip_text = "Trở về màn hình Chọn Máy Chủ"
	btn_server.position = Vector2(98, cur_y) * S
	btn_server.size = Vector2(col_w, col_h) * S
	body.add_child(btn_server)

	cur_y += 27.0

	# Hàng 2: [ 🚪 Về Đ.Nhập ]   [ Đóng Cửa Sổ ]
	var btn_login := _create_mu_button("🚪 Về Đ.Nhập", _on_return_to_login, 11)
	btn_login.tooltip_text = "Đăng xuất về màn hình Đăng Nhập"
	btn_login.position = Vector2(18, cur_y) * S
	btn_login.size = Vector2(col_w, col_h) * S
	body.add_child(btn_login)

	var btn_close_all := _create_mu_button("Đóng Cửa Sổ", func():
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("_close_any_open_modal"):
			hud._close_any_open_modal()
		close_window()
	, 11)
	btn_close_all.tooltip_text = "Đóng tất cả các cửa sổ đang mở"
	btn_close_all.position = Vector2(98, cur_y) * S
	btn_close_all.size = Vector2(col_w, col_h) * S
	body.add_child(btn_close_all)

	cur_y += 27.0

	# Hàng 3: [ 📦 Kho Đồ GM (Phím B) ]
	var btn_picker := _create_mu_button("📦 Kho Đồ GM (Phím B)", func():
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("toggle_item_picker"):
			hud.toggle_item_picker()
	, 11)
	btn_picker.position = Vector2(18, cur_y) * S
	btn_picker.size = Vector2(W - 36, col_h) * S
	body.add_child(btn_picker)

	# 7. Hàng chân trang (newui_item_back03):
	# [ ĐỒNG Ý ] NGANG HÀNG [ ✕ THOÁT GAME ]
	var btn_ok := _create_mu_button("ĐỒNG Ý", close_window, 11)
	btn_ok.position = Vector2(18, 346) * S
	btn_ok.size = Vector2(col_w, 26) * S
	btn_ok.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	body.add_child(btn_ok)

	var btn_quit := _create_mu_button("X THOÁT GAME", _on_exit_game, 10, true)
	btn_quit.tooltip_text = "Đóng và thoát khỏi trò chơi"
	btn_quit.position = Vector2(98, 346) * S
	btn_quit.size = Vector2(col_w, 26) * S
	body.add_child(btn_quit)

func _setup_confirm_dialog() -> void:
	_confirm_overlay = Control.new()
	_confirm_overlay.name = "ConfirmOverlay"
	_confirm_overlay.position = Vector2.ZERO
	_confirm_overlay.size = Vector2(W, H) * S
	_confirm_overlay.visible = false
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(_confirm_overlay)

	# Lớp mờ nền đen mờ
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.65)
	dimmer.size = _confirm_overlay.size
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.add_child(dimmer)

	# Bảng hộp thoại
	var dlg_w := 162.0
	var dlg_h := 125.0
	_confirm_dialog = Panel.new()
	_confirm_dialog.name = "ConfirmDialog"
	_confirm_dialog.size = Vector2(dlg_w, dlg_h) * S
	_confirm_dialog.position = Vector2((W - dlg_w) * 0.5, (H - dlg_h) * 0.5) * S
	_confirm_dialog.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb_dialog := StyleBoxFlat.new()
	sb_dialog.bg_color = Color(0.08, 0.07, 0.06, 0.98)
	sb_dialog.border_color = Color(0.85, 0.7, 0.35, 1.0)
	sb_dialog.border_width_left = 2
	sb_dialog.border_width_top = 2
	sb_dialog.border_width_right = 2
	sb_dialog.border_width_bottom = 2
	sb_dialog.corner_radius_top_left = 6
	sb_dialog.corner_radius_top_right = 6
	sb_dialog.corner_radius_bottom_left = 6
	sb_dialog.corner_radius_bottom_right = 6
	sb_dialog.shadow_color = Color(0, 0, 0, 0.8)
	sb_dialog.shadow_size = 8
	_confirm_dialog.add_theme_stylebox_override("panel", sb_dialog)
	_confirm_overlay.add_child(_confirm_dialog)

	# Tiêu đề thông báo
	var title := MuUiSkinRes.font_label("XÁC NHẬN", 13, Color(1.0, 0.85, 0.4))
	title.position = Vector2(0, 8 * S)
	title.size = Vector2(dlg_w * S, 20 * S)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_dialog.add_child(title)

	var line := ColorRect.new()
	line.color = Color(0.7, 0.55, 0.25, 0.7)
	line.position = Vector2(12, 30) * S
	line.size = Vector2(dlg_w - 24, 1) * S
	_confirm_dialog.add_child(line)

	# Nội dung thông báo
	_confirm_label = MuUiSkinRes.font_label("", 12, Color(0.96, 0.94, 0.88))
	_confirm_label.position = Vector2(8, 36) * S
	_confirm_label.size = Vector2(dlg_w - 16, 42) * S
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_confirm_dialog.add_child(_confirm_label)

	# 2 Nút Xác nhận & Hủy
	var btn_w := 64.0
	var btn_h := 24.0

	var btn_yes := _create_mu_button("XÁC NHẬN", func():
		_confirm_overlay.visible = false
		if _pending_confirm_action.is_valid():
			_pending_confirm_action.call()
	, 11)
	btn_yes.position = Vector2(12, dlg_h - 32) * S
	btn_yes.size = Vector2(btn_w, btn_h) * S
	btn_yes.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_confirm_dialog.add_child(btn_yes)

	var btn_no := _create_mu_button("HỦY BỎ", func():
		_confirm_overlay.visible = false
		_pending_confirm_action = Callable()
	, 11)
	btn_no.position = Vector2(dlg_w - 12 - btn_w, dlg_h - 32) * S
	btn_no.size = Vector2(btn_w, btn_h) * S
	_confirm_dialog.add_child(btn_no)

func _show_confirm_dialog(message: String, action: Callable) -> void:
	if not _confirm_overlay:
		_setup_confirm_dialog()
	_pending_confirm_action = action
	_confirm_label.text = message
	_confirm_overlay.visible = true
	_confirm_overlay.move_to_front()
	if MuAudioManager:
		MuAudioManager.play_ui_window()

# -----------------------------------------------------------------------------
# XỬ LÝ 4 CHỨC NĂNG HỆ THỐNG / ĐĂNG XUẤT
# -----------------------------------------------------------------------------
func _on_return_to_char_select() -> void:
	_show_confirm_dialog("Bạn có muốn trở về\nmàn hình Chọn Nhân Vật?", func():
		_save_player_state()
		_send_logout_packet(1) # BackToCharacterSelection
		close_window()
		get_tree().change_scene_to_file("res://src/scenes/CharacterSelectScene.tscn")
	)

func _on_return_to_server_select() -> void:
	_show_confirm_dialog("Bạn có muốn trở về\nmàn hình Chọn Máy Chủ?", func():
		_save_player_state()
		_send_logout_packet(2) # BackToServerSelection
		close_window()
		get_tree().change_scene_to_file("res://src/scenes/ServerSelectScene.tscn")
	)

func _on_return_to_login() -> void:
	_show_confirm_dialog("Bạn có muốn Đăng Xuất\nvề màn hình Đăng Nhập?", func():
		_save_player_state()
		_disconnect_network()
		close_window()
		get_tree().change_scene_to_file("res://src/scenes/LoginScene.tscn")
	)

func _on_exit_game() -> void:
	_show_confirm_dialog("Bạn có chắc chắn muốn\nThoát Khỏi Trò Chơi?", func():
		_save_player_state()
		_send_logout_packet(0) # CloseGame
		_disconnect_network()
		get_tree().quit()
	)

func _save_player_state() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		if player.has_method("sync_to_session"):
			player.sync_to_session()
		elif player.has_method("save_vault"):
			player.save_vault()

func _send_logout_packet(logout_type: int) -> void:
	var net = get_tree().get_first_node_in_group("Network")
	if not net:
		net = get_node_or_null("/root/Main/MuNetworkClient")
	if net and "is_connected" in net and net.is_connected:
		var pkt = MuPackets.build_logout_packet(logout_type)
		net.send_packet(pkt)

func _disconnect_network() -> void:
	var net = get_tree().get_first_node_in_group("Network")
	if not net:
		net = get_node_or_null("/root/Main/MuNetworkClient")
	if net and net.has_method("disconnect_from_gateway"):
		net.disconnect_from_gateway()

func _add_texture(tex_name: String, pos: Vector2, sz: Vector2) -> void:
	var t = MuUiSkinRes.tex(tex_name)
	if t:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.position = pos
		r.size = sz
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(r)

func _create_volume_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 5.0
	s.focus_mode = Control.FOCUS_NONE
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	sb_bg.border_width_left = 1
	sb_bg.border_width_top = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_bottom = 1
	sb_bg.border_color = Color(0.65, 0.52, 0.25, 0.8)
	sb_bg.corner_radius_top_left = 3
	sb_bg.corner_radius_top_right = 3
	sb_bg.corner_radius_bottom_left = 3
	sb_bg.corner_radius_bottom_right = 3
	s.add_theme_stylebox_override("slider", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.85, 0.65, 0.18, 0.9)
	sb_fill.corner_radius_top_left = 3
	sb_fill.corner_radius_bottom_left = 3
	s.add_theme_stylebox_override("grabber_area", sb_fill)
	s.add_theme_stylebox_override("grabber_area_highlight", sb_fill)

	# Knob point
	var pt = MuUiSkinRes.tex("newui_option_point")
	if pt:
		s.add_theme_icon_override("grabber", pt)
		s.add_theme_icon_override("grabber_highlight", pt)

	return s

func _create_checkbox_row(text: String, initial_val: bool, toggle_cb: Callable) -> Control:
	var container := HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_theme_constant_override("separation", 8)

	var check_tex = MuUiSkinRes.tex("newui_option_check")
	var btn := TextureButton.new()
	btn.name = "CheckBtn"
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = Vector2(16, 16) * S
	btn.size = btn.custom_minimum_size
	btn.focus_mode = Control.FOCUS_NONE

	if check_tex:
		var tex_unchecked := AtlasTexture.new()
		tex_unchecked.atlas = check_tex
		tex_unchecked.region = Rect2(0, 0, 15, 15)

		var tex_checked := AtlasTexture.new()
		tex_checked.atlas = check_tex
		tex_checked.region = Rect2(0, 15, 15, 15)

		btn.texture_normal = tex_checked if initial_val else tex_unchecked
	else:
		btn.text = "X" if initial_val else ""

	btn.pressed.connect(func():
		toggle_cb.call(btn)
	)
	container.add_child(btn)

	var lbl := MuUiSkinRes.font_label(text, 12, Color(0.92, 0.9, 0.82))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			toggle_cb.call(btn)
	)
	container.add_child(lbl)

	return container

func _create_mu_button(label: String, cb: Callable, font_sz: int = 11, is_danger: bool = false) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", font_sz)

	if is_danger:
		b.add_theme_color_override("font_color", Color(1.0, 0.65, 0.65))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.35, 0.35))
	else:
		b.add_theme_color_override("font_color", Color(0.92, 0.85, 0.65))
		b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.85))

	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = Color(0.18, 0.08, 0.08, 0.95) if is_danger else Color(0.14, 0.12, 0.1, 0.95)
	sb_norm.border_width_left = 1
	sb_norm.border_width_top = 1
	sb_norm.border_width_right = 1
	sb_norm.border_width_bottom = 1
	sb_norm.border_color = Color(0.85, 0.3, 0.3, 0.9) if is_danger else Color(0.68, 0.55, 0.28, 0.9)
	sb_norm.corner_radius_top_left = 4
	sb_norm.corner_radius_top_right = 4
	sb_norm.corner_radius_bottom_left = 4
	sb_norm.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", sb_norm)

	var sb_hover := sb_norm.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.28, 0.12, 0.12, 0.98) if is_danger else Color(0.24, 0.2, 0.14, 0.98)
	sb_hover.border_color = Color(1.0, 0.45, 0.45, 1.0) if is_danger else Color(0.95, 0.8, 0.35, 1.0)
	b.add_theme_stylebox_override("hover", sb_hover)

	var sb_press := sb_norm.duplicate() as StyleBoxFlat
	sb_press.bg_color = Color(0.1, 0.04, 0.04, 1.0) if is_danger else Color(0.08, 0.07, 0.05, 1.0)
	sb_press.border_color = Color(0.6, 0.2, 0.2, 0.9) if is_danger else Color(0.5, 0.4, 0.2, 0.9)
	b.add_theme_stylebox_override("pressed", sb_press)

	b.pressed.connect(func():
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		cb.call()
	)
	return b

func _on_sfx_changed(val: float) -> void:
	if lbl_sfx_val:
		lbl_sfx_val.text = "%d%%" % int(val)
	# Điều chỉnh volume SFX bus
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx < 0:
		bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var db = linear_to_db(max(val / 100.0, 0.0001))
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_bgm_changed(val: float) -> void:
	if lbl_bgm_val:
		lbl_bgm_val.text = "%d%%" % int(val)
	# Điều chỉnh volume BGM / Music bus
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var db = linear_to_db(max(val / 100.0, 0.0001))
		AudioServer.set_bus_volume_db(bus_idx, db)
	var audio_mgr = MuAudioManager.get_instance() if MuAudioManager else null
	if audio_mgr and audio_mgr.ambient_player:
		var db_amb = -14.0 + (val - 100.0) * 0.2
		audio_mgr.ambient_player.volume_db = db_amb

func _on_toggle_auto_attack(btn: TextureButton) -> void:
	# Bật/tắt MU Helper thật (client gốc: phím Home)
	var hud = get_tree().get_first_node_in_group("HUD")
	var helper = hud.get("mu_helper") if hud else null
	if helper == null:
		helper = get_tree().get_first_node_in_group("MuHelper")
	if helper == null:
		return
	helper.toggle()
	is_auto_attack = helper.active
	_update_checkbox_texture(btn, is_auto_attack)

func _on_toggle_fullscreen(btn: TextureButton) -> void:
	var mode = DisplayServer.window_get_mode()
	var will_fs = not (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if will_fs else DisplayServer.WINDOW_MODE_WINDOWED)
	_update_checkbox_texture(btn, will_fs)
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Chế độ màn hình: " + ("Toàn màn hình" if will_fs else "Cửa sổ"), Color(0.95, 0.85, 0.4))

func _update_checkbox_texture(btn: TextureButton, val: bool) -> void:
	if not btn: return
	var check_tex = MuUiSkinRes.tex("newui_option_check")
	if check_tex:
		var t := AtlasTexture.new()
		t.atlas = check_tex
		t.region = Rect2(0, 15 if val else 0, 15, 15)
		btn.texture_normal = t
	else:
		btn.text = "X" if val else ""

func toggle() -> void:
	if visible:
		close_window()
	else:
		open_window()

func open_window() -> void:
	if _confirm_overlay:
		_confirm_overlay.visible = false
	visible = true
	var helper = get_tree().get_first_node_in_group("MuHelper")
	if helper and chk_auto_attack:
		is_auto_attack = helper.active
		_update_checkbox_texture(chk_auto_attack, is_auto_attack)
	var vs = get_viewport_rect().size
	position = (vs - size) * 0.5
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func close_window() -> void:
	if _confirm_overlay:
		_confirm_overlay.visible = false
	visible = false
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Kéo thả cửa sổ nếu nhấn vào vùng tiêu đề
			var local_pos = event.position
			if local_pos.y <= 64 * S:
				is_dragging = true
				drag_offset = event.global_position - global_position
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		global_position = event.global_position - drag_offset
