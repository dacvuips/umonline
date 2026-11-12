extends Control
class_name MuTopMenuWidget

## Thanh Menu Nút Chức Năng Nằm Ngang Góc Trên (Mobile MU Origin Style)
## Hiển thị các icon tròn viền vàng kích thước 48x48 chuẩn phong cách MU:
## 1. Mũ giáp         -> Chỉ số nhân vật (C)
## 2. Cuộn giấy       -> Danh sách kỹ năng (K)
## 3. Rương đồ        -> Túi đồ / Ba lô (I)
## 4. Dấu hỏi (?)     -> Hướng dẫn phím tắt
## 5. Bánh răng vàng  -> Cài đặt hệ thống (Setting chuẩn MU gốc)
## Kèm nút mở rộng / thu gọn (Mũi tên ▶/◀ không viền, không nền) góc phải sát bản đồ mini

signal button_pressed(id: String)
signal menu_button_clicked(button_id: String)

const BTN_SIZE := 64.0
const GAP := 6.0

const MENU_ITEMS := [
	{"id": "character", "icon": "side_char", "tip": "Chỉ số nhân vật (C)"},
	{"id": "skill", "icon": "side_move", "tip": "Danh sách kỹ năng (K)"},
	{"id": "inventory", "icon": "side_bag", "tip": "Túi đồ (I)"},
	{"id": "market", "icon": "side_market", "tip": "Sàn Giao Dịch Chợ Online (Phím P)"},
	{"id": "event", "icon": "btn_calendar", "tip": "Lịch Sự Kiện (Events - Phím H)"},
	{"id": "party", "icon": "side_party", "tip": "Tổ đội"},
	{"id": "guild", "icon": "side_guild", "tip": "Guild"},
	{"id": "friend", "icon": "side_friend", "tip": "Bạn bè (F)"},
	{"id": "help", "icon": "side_help", "tip": "Hướng dẫn phím tắt"},
	{"id": "settings", "icon": "side_setting", "tip": "Cài đặt hệ thống (Esc / O)"},
]

var buttons_container: HBoxContainer
var toggle_btn: Button
var is_expanded: bool = true
var loaded_textures: Dictionary = {}

func _ready() -> void:
	var total_w = MENU_ITEMS.size() * BTN_SIZE + (MENU_ITEMS.size() - 1) * GAP + 32.0
	custom_minimum_size = Vector2(total_w, BTN_SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preload_textures()
	_build_ui()

func _preload_textures() -> void:
	for item in MENU_ITEMS:
		var path = "res://assets/textures/ui/mobile_origin/%s.png" % item["icon"]
		if ResourceLoader.exists(path):
			loaded_textures[path] = load(path)
		elif FileAccess.file_exists(path):
			var img = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				loaded_textures[path] = ImageTexture.create_from_image(img)

func _get_texture(icon_name: String) -> Texture2D:
	var path = "res://assets/textures/ui/mobile_origin/%s.png" % icon_name
	if loaded_textures.has(path):
		return loaded_textures[path]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			loaded_textures[path] = tex
			return tex
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			var itex = ImageTexture.create_from_image(img)
			loaded_textures[path] = itex
			return itex
	return null

func _build_ui() -> void:
	# 1. Nút mũi tên thu gọn / mở rộng menu: CỐ ĐỊNH Ở MÉP PHẢI (sát cạnh Mini Map)
	toggle_btn = Button.new()
	toggle_btn.name = "ToggleBtn"
	toggle_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	toggle_btn.anchor_left = 1.0
	toggle_btn.anchor_right = 1.0
	toggle_btn.anchor_top = 0.0
	toggle_btn.anchor_bottom = 1.0
	toggle_btn.offset_left = -26
	toggle_btn.offset_right = 0
	toggle_btn.offset_top = 0
	toggle_btn.offset_bottom = 0
	toggle_btn.flat = true
	toggle_btn.text = "▶"
	toggle_btn.tooltip_text = "Thu gọn / Mở rộng Menu"
	toggle_btn.add_theme_font_size_override("font_size", 18)
	toggle_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	toggle_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.75))
	toggle_btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.7, 0.3))
	toggle_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	toggle_btn.add_theme_constant_override("outline_size", 3)
	toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle_btn.focus_mode = Control.FOCUS_NONE

	# Xóa sạch border và background của nút
	var sb_empty := StyleBoxEmpty.new()
	toggle_btn.add_theme_stylebox_override("normal", sb_empty)
	toggle_btn.add_theme_stylebox_override("hover", sb_empty)
	toggle_btn.add_theme_stylebox_override("pressed", sb_empty)
	toggle_btn.add_theme_stylebox_override("focus", sb_empty)
	toggle_btn.add_theme_stylebox_override("disabled", sb_empty)

	toggle_btn.pressed.connect(_on_toggle_pressed)
	add_child(toggle_btn)

	# 2. Container các nút chức năng nằm ngang: Nằm bên TRÁI mũi tên
	buttons_container = HBoxContainer.new()
	buttons_container.name = "ButtonsContainer"
	buttons_container.anchors_preset = Control.PRESET_FULL_RECT
	buttons_container.anchor_left = 0.0
	buttons_container.anchor_right = 1.0
	buttons_container.anchor_top = 0.0
	buttons_container.anchor_bottom = 1.0
	buttons_container.offset_left = 0
	buttons_container.offset_right = -30
	buttons_container.offset_top = 0
	buttons_container.offset_bottom = 0
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", int(GAP))
	buttons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buttons_container)

	for item in MENU_ITEMS:
		var btn = _create_button(str(item["id"]), str(item["icon"]), str(item["tip"]))
		buttons_container.add_child(btn)

func _create_button(id: String, icon_name: String, tip: String) -> TextureButton:
	var b := TextureButton.new()
	b.name = "Btn_" + id
	var tex = _get_texture(icon_name)
	if tex:
		b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	b.size = Vector2(BTN_SIZE, BTN_SIZE)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = Vector2(BTN_SIZE, BTN_SIZE) * 0.5
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Hiệu ứng nhấn nút & rê chuột mượt mà
	b.button_down.connect(func():
		b.scale = Vector2(0.92, 0.92)
		b.modulate = Color(1.25, 1.2, 1.0))
	b.button_up.connect(func():
		b.scale = Vector2.ONE
		b.modulate = Color.WHITE)
	b.mouse_entered.connect(func(): b.modulate = Color(1.15, 1.12, 1.0))
	b.mouse_exited.connect(func(): b.modulate = Color.WHITE)

	b.pressed.connect(func():
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		print("[MuTopMenuWidget] Bấm nút menu: ", id)
		emit_signal("button_pressed", id)
		emit_signal("menu_button_clicked", id)
		# Chỉ gọi fallback _handle_action khi không có listener nào kết nối vào signal
		# (tránh việc gọi 2 lần liên tiếp làm cửa sổ vừa mở ra lập tức đóng lại)
		if get_signal_connection_list("button_pressed").is_empty() and get_signal_connection_list("menu_button_clicked").is_empty():
			_handle_action(id))
	return b

func _on_toggle_pressed() -> void:
	is_expanded = not is_expanded
	if toggle_btn:
		toggle_btn.text = "▶" if is_expanded else "◀"

	var tween = create_tween()
	if is_expanded:
		buttons_container.visible = true
		tween.tween_property(buttons_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(buttons_container, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): buttons_container.visible = false)

	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _handle_action(id: String) -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if not hud:
		return

	match id:
		"character":
			if hud.has_method("toggle_character_stats"):
				hud.toggle_character_stats()
		"skill":
			if hud.has_method("toggle_skill_window"):
				hud.toggle_skill_window()
		"inventory":
			if hud.has_method("toggle_inventory"):
				hud.toggle_inventory()
		"market":
			if hud.has_method("toggle_market_window"):
				hud.toggle_market_window()
		"event":
			if hud.has_method("toggle_event_schedule"):
				hud.toggle_event_schedule()
		"help":
			if hud.has_method("toggle_help"):
				hud.toggle_help()
		"settings":
			if hud.has_method("toggle_settings"):
				hud.toggle_settings()
			elif hud.has_method("toggle_item_picker"):
				hud.toggle_item_picker()
