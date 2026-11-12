extends Control
class_name MuSkillWindow

## Bảng Danh Sách Kỹ Năng (Skill Window - Phím K) chuẩn phong cách MU Online
## - Chỉ hiển thị icon kỹ năng trong các ô newui_skillbox (không có text trên ô)
## - Skill đã học: hiển thị icon có màu đầy đủ
## - Skill chưa học: hiển thị icon màu xám (grayscale)
## - Hiển thị tất cả skill của class nhân vật (kèm chế độ GM ALL xem mọi class)
## - Text thông tin chi tiết (tên, MP, hồi chiêu, trạng thái) chỉ hiển thị khi nhấp vào ô kỹ năng

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuAudioManagerRes = preload("res://src/audio/MuAudioManager.gd")

const W := 390.0
const H := 495.0

var player: MuPlayer = null

var _panel_root: Control
var _skill_grid: GridContainer
var _count_label: Label
var _class_label: Label
var _search_input: LineEdit
var _tab_bar: HBoxContainer
var _btn_gm_all: Button

# Panel chi tiết kỹ năng (chỉ hiển thị text khi nhấp vào ô skill)
var _detail_panel: Control
var _detail_icon: TextureRect
var _detail_box: TextureRect
var _detail_name: Label
var _detail_status: Label
var _detail_stats: Label
var _detail_kind: Label
var _detail_desc: Label
var _detail_actions: HBoxContainer
var _detail_hint_empty: Label

var _current_filter: String = "all" # "all", "attack", "magic", "buff"
var _gm_all_mode: bool = false      # false: Kỹ năng Class chuẩn ; true: Chế độ GM ALL
var _gm_class_filter: int = -1      # -1: Tất cả class ; 0..6: Class cụ thể

var _box_tex_normal: Texture2D = null
var _box_tex_active: Texture2D = null

# Skill hiện đang được chọn để xem chi tiết
var _selected_skill: Dictionary = {}
var _slot_buttons: Array[SkillBoxSlot] = []
var _atlas_cache: Dictionary = {}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	add_to_group("MuSkillWindow")

	_load_textures()
	_build_ui()
	_place()
	if is_inside_tree() and get_viewport():
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
	if not is_inside_tree():
		return
	var vs := get_viewport_rect().size
	# Đặt ở bên trái cụm phím kỹ năng góc dưới phải để không che khuất
	var target_x := vs.x - 365.0 - W - 15.0
	var target_y := vs.y - H - 35.0
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
	title_bar.size = Vector2(W - 4, 32)
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(title_bar)

	var title_lbl := MuUiSkinRes.font_label("⚡ BẢNG KỸ NĂNG (Phím K)", 13, Color(1.0, 0.88, 0.45))
	title_lbl.position = Vector2(12, 7)
	_panel_root.add_child(title_lbl)

	# Nút đóng [X]
	var btn_close := Button.new()
	btn_close.text = "✖"
	btn_close.position = Vector2(W - 30, 4)
	btn_close.size = Vector2(24, 24)
	btn_close.add_theme_color_override("font_color", Color(1, 0.75, 0.5))
	btn_close.pressed.connect(func(): visible = false)
	_panel_root.add_child(btn_close)

	# 4. Thanh Thông Tin Class & Thống Kê & Nút GM ALL
	var sub_bar := ColorRect.new()
	sub_bar.color = Color(0.11, 0.09, 0.07, 0.9)
	sub_bar.position = Vector2(8, 38)
	sub_bar.size = Vector2(W - 16, 26)
	sub_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(sub_bar)

	_class_label = MuUiSkinRes.font_label("Lớp: Chiến Binh (DK)", 11, Color(0.85, 0.85, 0.85))
	_class_label.position = Vector2(14, 43)
	_panel_root.add_child(_class_label)

	_count_label = MuUiSkinRes.font_label("Tổng: 0", 11, Color(1.0, 0.9, 0.3))
	_count_label.position = Vector2(W - 180, 43)
	_panel_root.add_child(_count_label)

	_btn_gm_all = Button.new()
	_btn_gm_all.text = "👑 GM: ALL"
	_btn_gm_all.position = Vector2(W - 110, 40)
	_btn_gm_all.size = Vector2(100, 22)
	_btn_gm_all.add_theme_font_size_override("font_size", 10)
	_btn_gm_all.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_btn_gm_all.tooltip_text = "Chuyển sang chế độ GM: Xem và chọn tất cả kỹ năng trong game"
	_btn_gm_all.pressed.connect(_on_toggle_gm_all_mode)
	_panel_root.add_child(_btn_gm_all)

	# 5. Tab Lọc Loại Skill hoặc Lọc Class khi ở Chế độ GM ALL
	_tab_bar = HBoxContainer.new()
	_tab_bar.position = Vector2(8, 67)
	_tab_bar.size = Vector2(W - 16, 22)
	_tab_bar.add_theme_constant_override("separation", 2)
	_panel_root.add_child(_tab_bar)
	_rebuild_tab_bar()

	# 6. Danh Sách Lưới Icon Kỹ Năng Cuộn (ScrollContainer chứa GridContainer)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 93)
	scroll.size = Vector2(W - 16, 175)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_root.add_child(scroll)

	_skill_grid = GridContainer.new()
	_skill_grid.columns = 8
	_skill_grid.add_theme_constant_override("h_separation", 3)
	_skill_grid.add_theme_constant_override("v_separation", 4)
	_skill_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_skill_grid)

	# 7. Khung Thông Tin Chi Tiết (Skill Detail Panel - Chỉ hiện Text khi nhấp vào)
	_build_detail_panel()

	# 8. Thanh Công Cụ GM Dưới Cùng (Học Full / Reset)
	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0.12, 0.1, 0.08, 0.95)
	bottom_bar.position = Vector2(8, 460)
	bottom_bar.size = Vector2(W - 16, 28)
	_panel_root.add_child(bottom_bar)

	var btn_all_class := Button.new()
	btn_all_class.text = "⚡ Học All (Class)"
	btn_all_class.position = Vector2(10, 462)
	btn_all_class.size = Vector2(115, 24)
	btn_all_class.add_theme_font_size_override("font_size", 10)
	btn_all_class.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	btn_all_class.tooltip_text = "Học tất cả kỹ năng của lớp nhân vật hiện tại"
	btn_all_class.pressed.connect(func():
		if player:
			player.learn_all_skills(false)
			refresh_list()
	)
	_panel_root.add_child(btn_all_class)

	var btn_all_game := Button.new()
	btn_all_game.text = "🌟 Mọi Class (ALL)"
	btn_all_game.position = Vector2(133, 462)
	btn_all_game.size = Vector2(115, 24)
	btn_all_game.add_theme_font_size_override("font_size", 10)
	btn_all_game.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	btn_all_game.tooltip_text = "GM: Học tất cả kỹ năng của tất cả các class"
	btn_all_game.pressed.connect(func():
		if player:
			player.learn_all_skills(true)
			refresh_list()
	)
	_panel_root.add_child(btn_all_game)

	var btn_reset := Button.new()
	btn_reset.text = "🔄 Reset (Chưa Học)"
	btn_reset.position = Vector2(256, 462)
	btn_reset.size = Vector2(124, 24)
	btn_reset.add_theme_font_size_override("font_size", 10)
	btn_reset.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	btn_reset.tooltip_text = "Xóa danh sách kỹ năng đã học để test lại trạng thái icon màu xám"
	btn_reset.pressed.connect(func():
		if player:
			player.clear_learned_skills()
			refresh_list()
	)
	_panel_root.add_child(btn_reset)

# ==============================================================================
# XÂY DỰNG KHUNG TEXT THÔNG TIN CHI TIẾT (SKILL DETAIL PANEL)
# ==============================================================================
func _build_detail_panel() -> void:
	_detail_panel = Control.new()
	_detail_panel.position = Vector2(8, 274)
	_detail_panel.size = Vector2(W - 16, 178)
	_panel_root.add_child(_detail_panel)

	# Nền tối viền vàng đồng
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(bg)

	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.55, 0.45, 0.25, 0.85)
	border.border_width = 1.0
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(border)

	# Gợi ý ban đầu khi chưa nhấp vào skill nào
	_detail_hint_empty = Label.new()
	_detail_hint_empty.text = "👉 Nhấp vào một ô kỹ năng ở trên\nđể xem thông tin chi tiết và thiết lập."
	_detail_hint_empty.position = Vector2(15, 60)
	_detail_hint_empty.size = Vector2(W - 46, 50)
	_detail_hint_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_hint_empty.add_theme_font_size_override("font_size", 11)
	_detail_hint_empty.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	_detail_panel.add_child(_detail_hint_empty)

	# 1. Khung Box & Icon to
	_detail_box = TextureRect.new()
	_detail_box.position = Vector2(10, 8)
	_detail_box.size = Vector2(56, 66)
	_detail_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_box.texture = _box_tex_active
	_detail_box.visible = false
	_detail_panel.add_child(_detail_box)

	_detail_icon = TextureRect.new()
	_detail_icon.position = Vector2(13, 11)
	_detail_icon.size = Vector2(50, 60)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.visible = false
	_detail_panel.add_child(_detail_icon)

	# 2. Text Tên Kỹ Năng
	_detail_name = Label.new()
	_detail_name.position = Vector2(74, 8)
	_detail_name.size = Vector2(W - 90, 20)
	_detail_name.add_theme_font_size_override("font_size", 12)
	_detail_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	_detail_name.visible = false
	_detail_panel.add_child(_detail_name)

	# 3. Trạng Thái (Đã học / Chưa học)
	_detail_status = Label.new()
	_detail_status.position = Vector2(74, 29)
	_detail_status.size = Vector2(W - 90, 18)
	_detail_status.add_theme_font_size_override("font_size", 10)
	_detail_status.visible = false
	_detail_panel.add_child(_detail_status)

	# 4. Tiêu hao MP & Thời gian hồi chiêu
	_detail_stats = Label.new()
	_detail_stats.position = Vector2(74, 48)
	_detail_stats.size = Vector2(W - 90, 18)
	_detail_stats.add_theme_font_size_override("font_size", 10)
	_detail_stats.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	_detail_stats.visible = false
	_detail_panel.add_child(_detail_stats)

	# 5. Phân Loại / Lớp nhân vật
	_detail_kind = Label.new()
	_detail_kind.position = Vector2(10, 78)
	_detail_kind.size = Vector2(W - 36, 18)
	_detail_kind.add_theme_font_size_override("font_size", 10)
	_detail_kind.add_theme_color_override("font_color", Color(0.9, 0.85, 0.65))
	_detail_kind.visible = false
	_detail_panel.add_child(_detail_kind)

	# 6. Mô tả kỹ năng
	_detail_desc = Label.new()
	_detail_desc.position = Vector2(10, 98)
	_detail_desc.size = Vector2(W - 36, 40)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 10)
	_detail_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_detail_desc.visible = false
	_detail_panel.add_child(_detail_desc)

	# 7. Nút hành động tương tác với kỹ năng
	_detail_actions = HBoxContainer.new()
	_detail_actions.position = Vector2(10, 142)
	_detail_actions.size = Vector2(W - 36, 26)
	_detail_actions.add_theme_constant_override("separation", 6)
	_detail_actions.visible = false
	_detail_panel.add_child(_detail_actions)

func _on_toggle_gm_all_mode() -> void:
	_gm_all_mode = not _gm_all_mode
	_rebuild_tab_bar()
	refresh_list()
	if MuAudioManagerRes:
		MuAudioManagerRes.play_ui_click()

func _rebuild_tab_bar() -> void:
	if not _tab_bar:
		return
	for c in _tab_bar.get_children():
		c.queue_free()

	if not _gm_all_mode:
		if _btn_gm_all:
			_btn_gm_all.text = "👑 GM: ALL"
			_btn_gm_all.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

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
			btn_tab.add_theme_font_size_override("font_size", 9)
			var f_key: String = t["filter"]
			btn_tab.pressed.connect(func():
				_current_filter = f_key
				refresh_list()
			)
			_tab_bar.add_child(btn_tab)
	else:
		if _btn_gm_all:
			_btn_gm_all.text = "⚔️ Class"
			_btn_gm_all.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

		var class_tabs := [
			{"name": "Tất Cả", "cls": -1},
			{"name": "DW", "cls": 0},
			{"name": "DK", "cls": 1},
			{"name": "Elf", "cls": 2},
			{"name": "MG", "cls": 3},
			{"name": "DL", "cls": 4},
			{"name": "SUM", "cls": 5},
			{"name": "RF", "cls": 6}
		]
		for ct in class_tabs:
			var btn_ct := Button.new()
			btn_ct.text = ct["name"]
			btn_ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_ct.add_theme_font_size_override("font_size", 9)
			var c_val: int = ct["cls"]
			btn_ct.pressed.connect(func():
				_gm_class_filter = c_val
				refresh_list()
			)
			_tab_bar.add_child(btn_ct)

# ==============================================================================
# CLASS Ô KỸ NĂNG: CHỈ HIỂN THỊ ICON TRONG KHUNG, KHÔNG CÓ TEXT
# ==============================================================================
class SkillBoxSlot extends Button:
	var skill_dict: Dictionary = {}
	var is_learned: bool = false
	var is_selected: bool = false
	var is_active_combat: bool = false
	var skill_tex: Texture2D = null

	var box_rect: TextureRect = null
	var icon_rect: TextureRect = null

	var _owner_window: MuSkillWindow = null

	func _init(p_owner: MuSkillWindow, p_skill: Dictionary, p_learned: bool, p_selected: bool, p_active: bool, tex_box_normal: Texture2D, tex_box_active: Texture2D, p_tex_icon: Texture2D, p_is_grey_file: bool) -> void:
		_owner_window = p_owner
		skill_dict = p_skill
		is_learned = p_learned
		is_selected = p_selected
		is_active_combat = p_active
		skill_tex = p_tex_icon

		custom_minimum_size = Vector2(42, 50)
		size = Vector2(42, 50)
		flat = true
		mouse_filter = Control.MOUSE_FILTER_STOP

		var s_name := str(skill_dict.get("name", ""))
		var state_str := "Đã học" if is_learned else "Chưa học"
		tooltip_text = "%s (%s)\n• Nhấp để xem thông tin chi tiết\n• Kéo thả vào ô góc phải để gán phím" % [s_name, state_str]

		# 1. Khung Box (chuẩn MU: newui_skillbox hoặc newui_skillbox2 khi được chọn/active)
		box_rect = TextureRect.new()
		box_rect.size = Vector2(42, 50)
		box_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box_rect.texture = tex_box_active if (is_selected or is_active_combat) else tex_box_normal
		box_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box_rect)

		# 2. Icon Kỹ Năng
		if skill_tex:
			icon_rect = TextureRect.new()
			icon_rect.position = Vector2(2, 2)
			icon_rect.size = Vector2(38, 46)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = skill_tex
			if not is_learned and not p_is_grey_file:
				# Nếu chưa học mà không có file ảnh xám riêng biệt thì phủ màu xám
				icon_rect.modulate = Color(0.45, 0.45, 0.45, 0.8)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(icon_rect)

	func update_selection(p_selected: bool, tex_box_normal: Texture2D, tex_box_active: Texture2D) -> void:
		is_selected = p_selected
		if box_rect:
			box_rect.texture = tex_box_active if (is_selected or is_active_combat) else tex_box_normal

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			var target_s := -1
			match event.keycode:
				KEY_1: target_s = 0
				KEY_2: target_s = 1
				KEY_3: target_s = 2
				KEY_4: target_s = 3
				KEY_5: target_s = 4
			if target_s != -1:
				var wheel = get_tree().get_first_node_in_group("MuBottomRightCombatWidget")
				if wheel and wheel.has_method("assign_skill_to_slot"):
					wheel.assign_skill_to_slot(target_s, skill_dict)
					accept_event()
					return

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := Control.new()
		var p_box := TextureRect.new()
		p_box.size = Vector2(42, 50)
		p_box.position = Vector2(-21, -25)
		p_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if box_rect:
			p_box.texture = box_rect.texture
		preview.add_child(p_box)

		if skill_tex:
			var p_icon := TextureRect.new()
			p_icon.size = Vector2(38, 46)
			p_icon.position = Vector2(-19, -23)
			p_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			p_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			p_icon.texture = skill_tex
			if not is_learned:
				p_icon.modulate = Color(0.5, 0.5, 0.5, 0.8)
			preview.add_child(p_icon)

		var lbl := Label.new()
		lbl.text = str(skill_dict.get("name", ""))
		lbl.position = Vector2(-35, 28)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		preview.add_child(lbl)

		set_drag_preview(preview)
		return {
			"type": "mu_skill",
			"skill": skill_dict
		}

# ==============================================================================
# LÀM MỚI DANH SÁCH LƯỚI KỸ NĂNG (REFRESH LIST)
# ==============================================================================
func refresh_list() -> void:
	if not _skill_grid:
		return

	_slot_buttons.clear()
	for c in _skill_grid.get_children():
		c.queue_free()

	if not player:
		return

	var class_names := ["Phù Thủy (DW)", "Chiến Binh (DK)", "Tiên Nữ (Elf)", "Đấu Sĩ (MG)", "Chúa Tể (DL)", "Thuật Sĩ (SUM)", "Thiết Binh (RF)"]
	var cname: String = class_names[player.char_class] if player.char_class >= 0 and player.char_class < class_names.size() else "Class %d" % player.char_class

	var act_id = player.active_skill_id
	var all_skills: Array[Dictionary] = []

	if not _gm_all_mode:
		if _class_label:
			_class_label.text = "Lớp: %s" % cname
		all_skills = _get_all_class_skills()
	else:
		if _class_label:
			_class_label.text = "👑 GM: ALL SKILLS"
		all_skills = _get_all_game_skills()

	var learned_count := 0
	var shown_count := 0

	# Tìm skill được chọn hiện tại nếu chưa chọn
	var selected_num := int(_selected_skill.get("skill", -999))
	var has_selected_in_list := false

	for sk in all_skills:
		var s_id = str(sk.get("id", ""))
		var s_num = int(sk.get("skill", 0))
		var s_name = str(sk.get("name", ""))
		var desc = str(sk.get("desc", ""))

		# Lọc theo tab (khi ở chế độ class chuẩn)
		if not _gm_all_mode and _current_filter != "all":
			var is_buff = desc.contains("buff") or s_id in ["buff", "teleport"] or s_name.contains("Gồng") or s_name.contains("Dịch")
			var is_magic = desc.contains("magic") or desc.contains("area") or s_id in ["fireball", "twisting"] or s_name.contains("Lửa") or s_name.contains("Phép")
			if _current_filter == "buff" and not is_buff:
				continue
			elif _current_filter == "magic" and not is_magic:
				continue
			elif _current_filter == "attack" and is_buff:
				continue

		# Trạng thái đã học hay chưa
		var is_learned := (s_num == 0 or (player != null and s_num in player.learned_skills))
		if is_learned:
			learned_count += 1

		# Đang là kỹ năng kích hoạt (active) của nhân vật
		var is_active := (s_id == act_id or (act_id == "twisting" and s_num == 41) or (act_id == "fireball" and s_num == 4))

		# Đang được click chọn xem chi tiết
		var is_selected := false
		if selected_num == s_num:
			is_selected = true
			has_selected_in_list = true

		# Nạp icon: màu nếu đã học, xám nếu chưa học
		var tex_info := _get_skill_texture_info(s_num, is_learned, str(sk.get("icon_path", "")))
		var slot_btn := SkillBoxSlot.new(
			self,
			sk,
			is_learned,
			is_selected,
			is_active,
			_box_tex_normal,
			_box_tex_active,
			tex_info["texture"],
			tex_info["is_grey_file"]
		)

		slot_btn.pressed.connect(func():
			_on_skill_slot_clicked(sk)
		)

		_skill_grid.add_child(slot_btn)
		_slot_buttons.append(slot_btn)
		shown_count += 1

	if _count_label:
		_count_label.text = "Tổng: %d (Học: %d)" % [shown_count, learned_count]

	# Nếu skill đã chọn không còn trong danh sách (do đổi tab hoặc filter), tự động chọn skill đầu tiên
	if not has_selected_in_list and not all_skills.is_empty():
		_selected_skill = all_skills[0]
		_update_detail_panel()
	elif has_selected_in_list:
		_update_detail_panel()
	else:
		_clear_detail_panel()

# ==============================================================================
# LẤY TOÀN BỘ KỸ NĂNG CỦA CLASS (BAO GỒM CẢ CHƯA HỌC)
# ==============================================================================
func _get_all_class_skills() -> Array[Dictionary]:
	MuCatalogRes.ensure_loaded()
	var all_sk := MuCatalogRes.get_all_skills()
	var keys = all_sk.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))

	var list: Array[Dictionary] = []

	# 1. Đòn đánh thường Skill 0
	list.append({
		"id": "attack",
		"skill": 0,
		"name": "Đánh Thường",
		"icon_path": "res://assets/textures/ui/skills/skill_0.png",
		"mana_cost": 0,
		"cooldown": 0.0,
		"classes": [],
		"desc": "Đòn đánh vật lý cơ bản, không tiêu tốn Mana."
	})

	# 2. Toàn bộ kỹ năng của class nhân vật hiện tại
	var p_class: int = player.char_class if player else 1
	for k in keys:
		var num := int(k)
		if num == 0 or num >= 300:
			continue
		var sk: Dictionary = all_sk[k]
		if str(sk.get("type", "")) == "PassiveBoost":
			continue

		var classes: Array = sk.get("classes", [])
		var matches := false
		for c in classes:
			if int(c) == p_class:
				matches = true
				break
		if not matches:
			continue

		var vn_name := MuCatalogRes.get_skill_vietnamese_name(num, str(sk.get("name", "Skill %d" % num)))
		var icon_file := MuCatalogRes.get_skill_icon_path(num)
		var s_id := "sk_%d" % num

		list.append({
			"id": s_id,
			"skill": num,
			"name": vn_name,
			"icon_path": icon_file,
			"mana_cost": int(sk.get("mana", 0)),
			"cooldown": float(sk.get("cooldown", 0.0)),
			"classes": classes,
			"type": str(sk.get("type", "")),
			"damage_type": str(sk.get("damage_type", "")),
			"desc": "%s - Kỹ năng chiến đấu của %s" % [vn_name, _get_class_name(p_class)]
		})

	return list

# ==============================================================================
# LẤY TOÀN BỘ KỸ NĂNG TRONG GAME CHO CHẾ ĐỘ GM ALL
# ==============================================================================
func _get_all_game_skills() -> Array[Dictionary]:
	MuCatalogRes.ensure_loaded()
	var all_sk := MuCatalogRes.get_all_skills()
	var keys = all_sk.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))

	var list: Array[Dictionary] = []

	# Skill 0
	if _gm_class_filter == -1 or (_gm_class_filter == (player.char_class if player else 0)):
		list.append({
			"id": "attack",
			"skill": 0,
			"name": "Đánh Thường",
			"icon_path": "res://assets/textures/ui/skills/skill_0.png",
			"mana_cost": 0,
			"cooldown": 0.0,
			"classes": [],
			"desc": "Đòn đánh cận chiến cơ bản, không tiêu tốn Mana."
		})

	for k in keys:
		var num := int(k)
		if num == 0 or num >= 300:
			continue
		var sk: Dictionary = all_sk[k]
		if str(sk.get("type", "")) == "PassiveBoost":
			continue

		var classes: Array = sk.get("classes", [])
		if _gm_class_filter >= 0 and not classes.is_empty() and not classes.has(_gm_class_filter):
			continue

		var vn_name := MuCatalogRes.get_skill_vietnamese_name(num, str(sk.get("name", "Skill %d" % num)))
		var icon_file := MuCatalogRes.get_skill_icon_path(num)
		var s_id := "sk_%d" % num

		list.append({
			"id": s_id,
			"skill": num,
			"name": vn_name,
			"icon_path": icon_file,
			"mana_cost": int(sk.get("mana", 0)),
			"cooldown": float(sk.get("cooldown", 0.0)),
			"classes": classes,
			"type": str(sk.get("type", "")),
			"damage_type": str(sk.get("damage_type", "")),
			"desc": "%s (Skill #%d)" % [vn_name, num]
		})

	return list

# ==============================================================================
# XỬ LÝ CLICK CHỌN KỸ NĂNG VÀ CẬP NHẬT TEXT CHI TIẾT
# ==============================================================================
func _on_skill_slot_clicked(sk: Dictionary) -> void:
	_selected_skill = sk
	var sel_num := int(sk.get("skill", -999))

	# Cập nhật viền cho các ô trong lưới
	for slot in _slot_buttons:
		var is_this_selected := (int(slot.skill_dict.get("skill", -999)) == sel_num)
		slot.update_selection(is_this_selected, _box_tex_normal, _box_tex_active)

	_update_detail_panel()

	if MuAudioManagerRes:
		MuAudioManagerRes.play_ui_click()

func _update_detail_panel() -> void:
	if _selected_skill.is_empty():
		_clear_detail_panel()
		return

	if _detail_hint_empty:
		_detail_hint_empty.visible = false

	var s_num := int(_selected_skill.get("skill", 0))
	var s_name := str(_selected_skill.get("name", ""))
	var s_id := str(_selected_skill.get("id", ""))
	var mana := int(_selected_skill.get("mana_cost", 0))
	var cd := float(_selected_skill.get("cooldown", 0.0))
	var desc := str(_selected_skill.get("desc", ""))

	var is_learned := (s_num == 0 or (player != null and s_num in player.learned_skills))
	var is_active := (player != null and (player.active_skill_id == s_id or (player.active_skill_id == "twisting" and s_num == 41)))

	# 1. Icon to
	var tex_info := _get_skill_texture_info(s_num, is_learned, str(_selected_skill.get("icon_path", "")))
	if _detail_icon:
		_detail_icon.visible = true
		_detail_icon.texture = tex_info["texture"]
		if not is_learned and not tex_info["is_grey_file"]:
			_detail_icon.modulate = Color(0.45, 0.45, 0.45, 0.8)
		else:
			_detail_icon.modulate = Color.WHITE

	if _detail_box:
		_detail_box.visible = true

	# 2. Tên kỹ năng
	if _detail_name:
		_detail_name.visible = true
		_detail_name.text = "%s (ID: %d)" % [s_name, s_num]

	# 3. Trạng thái ĐÃ HỌC / CHƯA HỌC
	if _detail_status:
		_detail_status.visible = true
		if is_active:
			_detail_status.text = "★ [ĐANG SỬ DỤNG - SKILL CHÍNH]"
			_detail_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		elif is_learned:
			_detail_status.text = "✅ [ĐÃ HỌC - SẴN SÀNG SỬ DỤNG]"
			_detail_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			_detail_status.text = "🔒 [CHƯA HỌC - ICON MÀU XÁM]"
			_detail_status.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))

	# 4. MP & Hồi chiêu
	if _detail_stats:
		_detail_stats.visible = true
		var cd_str := "%.1fs" % cd if cd > 0.0 else "0s (Liên tục)"
		_detail_stats.text = "Tiêu hao: %d MP   •   Thời gian hồi: %s" % [mana, cd_str]

	# 5. Phân loại / Class
	if _detail_kind:
		_detail_kind.visible = true
		var cls_arr: Array = _selected_skill.get("classes", [])
		var cls_badges: Array = []
		var short_names := {0: "DW", 1: "DK", 2: "Elf", 3: "MG", 4: "DL", 5: "SUM", 6: "RF"}
		for c in cls_arr:
			if short_names.has(int(c)):
				cls_badges.append(short_names[int(c)])
		var class_str := "/".join(cls_badges) if not cls_badges.is_empty() else "Tất cả"
		_detail_kind.text = "Lớp: [%s]   •   Loại: %s" % [class_str, str(_selected_skill.get("type", "Active"))]

	# 6. Mô tả
	if _detail_desc:
		_detail_desc.visible = true
		_detail_desc.text = desc

	# 7. Nút hành động
	if _detail_actions:
		_detail_actions.visible = true
		for c in _detail_actions.get_children():
			c.queue_free()

		if is_learned:
			# Nút kích hoạt làm skill đánh chính
			var btn_use := Button.new()
			btn_use.text = "⚡ Đang Dùng" if is_active else "⚡ Dùng Skill Này"
			btn_use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_use.add_theme_font_size_override("font_size", 10)
			btn_use.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if is_active else Color(0.4, 1.0, 0.5))
			btn_use.pressed.connect(func():
				if player:
					player.set_active_skill(s_id)
				refresh_list()
			)
			_detail_actions.add_child(btn_use)

			# Nút gán vào slot combat wheel
			var btn_assign := Button.new()
			btn_assign.text = "🎯 Gán Vào Ô Phím"
			btn_assign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_assign.add_theme_font_size_override("font_size", 10)
			btn_assign.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
			btn_assign.pressed.connect(func():
				var wheel = get_tree().get_first_node_in_group("MuBottomRightCombatWidget")
				if wheel and wheel.has_method("assign_to_first_empty_or_selected"):
					wheel.assign_to_first_empty_or_selected(_selected_skill)
				if MuAudioManagerRes:
					MuAudioManagerRes.play_ui_click()
			)
			_detail_actions.add_child(btn_assign)
		else:
			# Nút học ngay kỹ năng này (chuyển xám thành màu)
			var btn_learn := Button.new()
			btn_learn.text = "📖 Học Kỹ Năng Này"
			btn_learn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_learn.add_theme_font_size_override("font_size", 10)
			btn_learn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			btn_learn.pressed.connect(func():
				if player and player.has_method("learn_skill_number"):
					player.learn_skill_number(s_num)
					refresh_list()
			)
			_detail_actions.add_child(btn_learn)

func _clear_detail_panel() -> void:
	if _detail_hint_empty:
		_detail_hint_empty.visible = true
	if _detail_box:
		_detail_box.visible = false
	if _detail_icon:
		_detail_icon.visible = false
	if _detail_name:
		_detail_name.visible = false
	if _detail_status:
		_detail_status.visible = false
	if _detail_stats:
		_detail_stats.visible = false
	if _detail_kind:
		_detail_kind.visible = false
	if _detail_desc:
		_detail_desc.visible = false
	if _detail_actions:
		_detail_actions.visible = false

# ==============================================================================
# TIỆN ÍCH TẢI TEXTURE ICON MÀU HOẶC XÁM
# ==============================================================================
func _get_skill_texture_info(skill_num: int, is_learned: bool, color_path: String) -> Dictionary:
	var raw_tex: Texture2D = null
	var is_grey := false

	if is_learned:
		var p := color_path
		if p == "":
			p = MuCatalogRes.get_skill_icon_path(skill_num)
		raw_tex = _load_tex(p)
	else:
		var p_grey := MuCatalogRes.get_skill_grey_icon_path(skill_num)
		if p_grey.contains("skills_grey") and (ResourceLoader.exists(p_grey) or FileAccess.file_exists(p_grey)):
			raw_tex = _load_tex(p_grey)
			is_grey = true
		else:
			# Fallback sang icon màu (sẽ modulate xám khi vẽ)
			raw_tex = _load_tex(color_path if color_path != "" else MuCatalogRes.get_skill_icon_path(skill_num))
			is_grey = false

	var final_tex: Texture2D = raw_tex
	if raw_tex:
		var cache_key := "%d_%s" % [skill_num, "grey" if is_grey else "col"]
		if _atlas_cache.has(cache_key):
			final_tex = _atlas_cache[cache_key]
		else:
			var tw := raw_tex.get_width()
			var th := raw_tex.get_height()
			if tw == 64 and th == 64:
				var atlas := AtlasTexture.new()
				atlas.atlas = raw_tex
				if skill_num == 0:
					atlas.region = Rect2(2, 2, 60, 60)
				else:
					atlas.region = Rect2(9, 0, 46, 64)
				final_tex = atlas
			_atlas_cache[cache_key] = final_tex

	return {
		"texture": final_tex,
		"is_grey_file": is_grey
	}

func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	if path.begins_with("res://") and FileAccess.file_exists(path):
		var abs_p := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_p)
		if img:
			return ImageTexture.create_from_image(img)
	return null

func _get_class_name(c: int) -> String:
	var class_names := ["Phù Thủy (DW)", "Chiến Binh (DK)", "Tiên Nữ (Elf)", "Đấu Sĩ (MG)", "Chúa Tể (DL)", "Thuật Sĩ (SUM)", "Thiết Binh (RF)"]
	if c >= 0 and c < class_names.size():
		return class_names[c]
	return "Class %d" % c
