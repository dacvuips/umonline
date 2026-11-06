extends Control
class_name MuSkillWindow

## Bảng Danh Sách Kỹ Năng (Skill Modal Window) chuẩn phong cách MU Online
## Hiển thị danh sách kỹ năng của nhân vật với icon gốc, khung newui_skillbox, tên, lượng MP và loại chiêu.
## Cho phép click chọn kỹ năng nhanh chóng, tự động đồng bộ lên HUD và phím kỹ năng.

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuAudioManagerRes = preload("res://src/audio/MuAudioManager.gd")

const W := 360.0
const H := 480.0

var player: MuPlayer = null

var _panel_root: Control
var _skill_list_container: VBoxContainer
var _count_label: Label
var _class_label: Label
var _search_input: LineEdit
var _current_filter: String = "all" # "all", "attack", "magic", "buff"

var _box_tex_normal: Texture2D = null
var _box_tex_active: Texture2D = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)

	_load_textures()
	_build_ui()
	_place()
	get_viewport().size_changed.connect(_place)

func _load_textures() -> void:
	if ResourceLoader.exists("res://assets/textures/ui/newui_skillbox.png"):
		_box_tex_normal = load("res://assets/textures/ui/newui_skillbox.png")
	if ResourceLoader.exists("res://assets/textures/ui/newui_skillbox2.png"):
		_box_tex_active = load("res://assets/textures/ui/newui_skillbox2.png")
	elif ResourceLoader.exists("res://assets/textures/ui/skill_active_box.png"):
		_box_tex_active = load("res://assets/textures/ui/skill_active_box.png")

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player:
		if not player.skills_updated.is_connected(_on_skills_updated):
			player.skills_updated.connect(_on_skills_updated)
		if not player.active_skill_changed.is_connected(_on_active_skill_changed):
			player.active_skill_changed.connect(_on_active_skill_changed)

func _place() -> void:
	var vs := get_viewport_rect().size
	# Đặt ở góc dưới bên phải, ngay phía trên thanh HUD và cụm skill
	var target_x := vs.x - W - 15.0
	var target_y := vs.y - H - 65.0
	if target_x < 10.0:
		target_x = maxf(10.0, (vs.x - W) * 0.5)
	if target_y < 10.0:
		target_y = maxf(10.0, (vs.y - H) * 0.5)
	position = Vector2(target_x, target_y)

func toggle() -> void:
	visible = not visible
	if visible:
		_place()
		refresh_list()
		if MuAudioManagerRes:
			MuAudioManagerRes.play_ui_window()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.keycode == KEY_K or k.keycode == KEY_S:
			toggle()
			get_viewport().set_input_as_handled()
		elif visible and k.keycode == KEY_ESCAPE:
			visible = false
			get_viewport().set_input_as_handled()

func _on_skills_updated() -> void:
	if visible:
		refresh_list()

func _on_active_skill_changed(_skill_id: String) -> void:
	if visible:
		refresh_list()

# ==============================================================================
# XÂY DỰNG GIAO DIỆN MODAL CHUẨN MU ONLINE
# ==============================================================================
func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel_root)

	# 1. Nền tối đá đen MU
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.04, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(bg)

	# 2. Viền kim loại vàng đồng
	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.75, 0.6, 0.25, 0.95)
	border.border_width = 2.0
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(border)

	# 3. Thanh Tiêu Đề
	var title_bar := ColorRect.new()
	title_bar.color = Color(0.18, 0.13, 0.08, 0.95)
	title_bar.position = Vector2(2, 2)
	title_bar.size = Vector2(W - 4, 34)
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(title_bar)

	var title_lbl := MuUiSkinRes.font_label("⚡ DANH SÁCH KỸ NĂNG (Phím K)", 13, Color(1.0, 0.88, 0.45))
	title_lbl.position = Vector2(12, 8)
	_panel_root.add_child(title_lbl)

	# Nút đóng [X]
	var btn_close := Button.new()
	btn_close.text = "✖"
	btn_close.position = Vector2(W - 32, 4)
	btn_close.size = Vector2(26, 24)
	btn_close.add_theme_color_override("font_color", Color(1, 0.75, 0.5))
	btn_close.pressed.connect(func(): visible = false)
	_panel_root.add_child(btn_close)

	# 4. Thanh Thông Tin Class & Số Lượng Skill
	var sub_bar := ColorRect.new()
	sub_bar.color = Color(0.11, 0.09, 0.07, 0.9)
	sub_bar.position = Vector2(8, 40)
	sub_bar.size = Vector2(W - 16, 24)
	sub_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(sub_bar)

	_class_label = MuUiSkinRes.font_label("Class: Chiến Binh (DK)", 11, Color(0.85, 0.85, 0.85))
	_class_label.position = Vector2(14, 44)
	_panel_root.add_child(_class_label)

	_count_label = MuUiSkinRes.font_label("Tổng: 5", 11, Color(1.0, 0.9, 0.3))
	_count_label.position = Vector2(W - 80, 44)
	_panel_root.add_child(_count_label)

	# 5. Thanh Tìm Kiếm
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "🔍 Tìm kiếm kỹ năng..."
	_search_input.position = Vector2(8, 68)
	_search_input.size = Vector2(W - 16, 26)
	_search_input.text_changed.connect(func(_t): refresh_list())
	_panel_root.add_child(_search_input)

	# 6. Tab Lọc Loại Skill: [Tất Cả] [Tấn Công] [Phép] [Buff]
	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(8, 98)
	tab_bar.size = Vector2(W - 16, 24)
	tab_bar.add_theme_constant_override("separation", 4)
	_panel_root.add_child(tab_bar)

	var tabs := [
		{"name": "Tất Cả", "filter": "all"},
		{"name": "Tấn Công", "filter": "attack"},
		{"name": "Phép Thuật", "filter": "magic"},
		{"name": "Hỗ Trợ", "filter": "buff"}
	]
	for t in tabs:
		var btn_tab := Button.new()
		btn_tab.text = t["name"]
		btn_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_tab.add_theme_font_size_override("font_size", 10)
		var f_key: String = t["filter"]
		btn_tab.pressed.connect(func():
			_current_filter = f_key
			refresh_list()
		)
		tab_bar.add_child(btn_tab)

	# 7. Danh Sách Kỹ Năng Cuộn (ScrollContainer)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 126)
	scroll.size = Vector2(W - 16, 316)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_root.add_child(scroll)

	_skill_list_container = VBoxContainer.new()
	_skill_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_skill_list_container)

	# 8. Thanh Công Cụ GM Dưới Cùng (Học Full / Reset)
	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0.12, 0.1, 0.08, 0.95)
	bottom_bar.position = Vector2(8, 446)
	bottom_bar.size = Vector2(W - 16, 28)
	_panel_root.add_child(bottom_bar)

	var btn_all_class := Button.new()
	btn_all_class.text = "⚡ Học All Skill"
	btn_all_class.position = Vector2(10, 448)
	btn_all_class.size = Vector2(110, 24)
	btn_all_class.add_theme_font_size_override("font_size", 10)
	btn_all_class.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	btn_all_class.pressed.connect(func():
		if player:
			player.learn_all_skills(false)
			refresh_list()
	)
	_panel_root.add_child(btn_all_class)

	var btn_all_game := Button.new()
	btn_all_game.text = "🌟 Mọi Class"
	btn_all_game.position = Vector2(126, 448)
	btn_all_game.size = Vector2(105, 24)
	btn_all_game.add_theme_font_size_override("font_size", 10)
	btn_all_game.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	btn_all_game.pressed.connect(func():
		if player:
			player.learn_all_skills(true)
			refresh_list()
	)
	_panel_root.add_child(btn_all_game)

	var btn_reset := Button.new()
	btn_reset.text = "🔄 Reset"
	btn_reset.position = Vector2(237, 448)
	btn_reset.size = Vector2(110, 24)
	btn_reset.add_theme_font_size_override("font_size", 10)
	btn_reset.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	btn_reset.pressed.connect(func():
		if player:
			player.clear_learned_skills()
			refresh_list()
	)
	_panel_root.add_child(btn_reset)

# ==============================================================================
# LÀM MỚI DANH SÁCH KỸ NĂNG (REFRESH LIST)
# ==============================================================================
func refresh_list() -> void:
	if not _skill_list_container:
		return

	for c in _skill_list_container.get_children():
		c.queue_free()

	if not player:
		return

	var class_names := ["Phù Thủy (DW)", "Chiến Binh (DK)", "Tiên Nữ (Elf)", "Đấu Sĩ (MG)", "Chúa Tể (DL)", "Thuật Sĩ (SUM)", "Thiết Binh (RF)"]
	var cname: String = class_names[player.char_class] if player.char_class >= 0 and player.char_class < class_names.size() else "Class %d" % player.char_class
	if _class_label:
		_class_label.text = "Lớp: %s" % cname

	var all_skills = player.get_available_skills()
	if _count_label:
		_count_label.text = "Tổng: %d" % all_skills.size()

	var kw: String = _search_input.text.strip_edges().to_lower() if _search_input else ""
	var act_id = player.active_skill_id

	var shown_count := 0
	for sk in all_skills:
		var s_id = str(sk.get("id", ""))
		var s_name = str(sk.get("name", ""))
		var mana = int(sk.get("mana_cost", 0))
		var desc = str(sk.get("desc", ""))
		var kind = ""

		# Phân loại theo filter
		var is_buff = desc.contains("buff") or s_id in ["buff", "teleport"] or s_name.contains("Gồng") or s_name.contains("Dịch")
		var is_magic = desc.contains("magic") or desc.contains("area") or s_id in ["fireball", "twisting"] or s_name.contains("Lửa") or s_name.contains("Phép")
		
		if _current_filter == "buff" and not is_buff:
			continue
		elif _current_filter == "magic" and not is_magic:
			continue
		elif _current_filter == "attack" and is_buff:
			continue

		# Tìm kiếm theo từ khóa
		if kw != "" and not s_name.to_lower().contains(kw) and not s_id.to_lower().contains(kw) and not desc.to_lower().contains(kw):
			continue

		var is_active = (s_id == act_id)
		var item_card = _create_skill_card(sk, is_active)
		_skill_list_container.add_child(item_card)
		shown_count += 1

	if shown_count == 0:
		var empty_lbl = MuUiSkinRes.font_label("Không tìm thấy kỹ năng phù hợp.", 11, Color(0.7, 0.7, 0.7))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_skill_list_container.add_child(empty_lbl)

## Tạo 1 Card kỹ năng chuẩn MU
func _create_skill_card(sk: Dictionary, is_active: bool) -> Control:
	var s_id = str(sk.get("id", ""))
	var s_name = str(sk.get("name", ""))
	var mana = int(sk.get("mana_cost", 0))
	var icon_path = str(sk.get("icon_path", ""))

	var row := Button.new()
	row.custom_minimum_size = Vector2(W - 20, 48)
	row.size = Vector2(W - 20, 48)
	row.flat = true
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	# Nền card
	var bg := ColorRect.new()
	bg.position = Vector2(0, 0)
	bg.size = Vector2(W - 20, 48)
	bg.color = Color(0.2, 0.16, 0.08, 0.85) if is_active else Color(0.09, 0.08, 0.07, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)

	# Viền card
	var border := ReferenceRect.new()
	border.position = Vector2(0, 0)
	border.size = Vector2(W - 20, 48)
	border.border_color = Color(1.0, 0.85, 0.3, 0.95) if is_active else Color(0.4, 0.35, 0.25, 0.6)
	border.border_width = 2.0 if is_active else 1.0
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(border)

	# Khung Box chuẩn MU (newui_skillbox)
	var box_rect := TextureRect.new()
	box_rect.position = Vector2(6, 4)
	box_rect.size = Vector2(32, 40)
	box_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box_rect.texture = _box_tex_active if is_active else _box_tex_normal
	box_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box_rect)

	# Icon kỹ năng
	if ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.position = Vector2(8, 7)
		icon_rect.size = Vector2(28, 32)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = load(icon_path)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)

	# Tên kỹ năng
	var name_color = Color(1.0, 0.9, 0.35) if is_active else Color(0.95, 0.95, 0.95)
	var name_lbl := MuUiSkinRes.font_label(s_name, 12, name_color)
	name_lbl.position = Vector2(46, 6)
	row.add_child(name_lbl)

	# Tiêu hao Mana
	var mp_text = "%d MP" % mana if mana > 0 else "0 MP (Không tốn)"
	var mp_lbl := MuUiSkinRes.font_label(mp_text, 10, Color(0.35, 0.85, 1.0))
	mp_lbl.position = Vector2(46, 26)
	row.add_child(mp_lbl)

	# Nhãn trạng thái bên phải
	if is_active:
		var active_lbl := MuUiSkinRes.font_label("✓ ĐANG DÙNG", 10, Color(0.4, 1.0, 0.4))
		active_lbl.position = Vector2(W - 105, 16)
		row.add_child(active_lbl)
	else:
		var btn_pick_lbl := MuUiSkinRes.font_label("Chọn [Click]", 10, Color(0.7, 0.7, 0.7))
		btn_pick_lbl.position = Vector2(W - 95, 16)
		row.add_child(btn_pick_lbl)

	# Khi click vào row -> chọn skill ngay
	row.pressed.connect(func():
		_select_skill(s_id)
	)

	return row

func _select_skill(s_id: String) -> void:
	if not player or s_id == "":
		return
	player.set_active_skill(s_id)
	if MuAudioManagerRes:
		MuAudioManagerRes.play_ui_click()
	visible = false
