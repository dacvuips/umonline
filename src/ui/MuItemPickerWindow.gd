extends Control
class_name MuItemPickerWindow

## Bảng Lấy Đồ / Kho Vật Phẩm GM (Item Generator) chuẩn phong cách MU Online
## Cho phép tìm kiếm, lọc theo loại, lọc theo Class, tùy chọn cấp độ +0 đến +15,
## Hoàn Hảo (Excellent), May Mắn (Luck), Tuyệt Chiêu (Skill), Option +4..+28.
## Hiển thị hình ảnh render 3D thực tế và bảng thông số chi tiết của món đồ!

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuAudioManagerRes = preload("res://src/audio/MuAudioManager.gd")

const W := 770.0
const H := 570.0
const ITEMS_PER_PAGE := 48

var player = null

# Dữ liệu danh mục
var _all_items: Array = []
var _filtered_items: Array = []
var _current_page: int = 0
var _selected_info: Dictionary = {}
var _card_buttons: Dictionary = {}

# Node giao diện
var _panel_root: Control
var _search_input: LineEdit
var _cat_option: OptionButton
var _class_option: OptionButton
var _level_slider: HSlider
var _level_label: Label
var _exc_check: CheckBox
var _purple_check: CheckBox
var _ancient_check: CheckBox
var _socket_check: CheckBox
var _harmony_check: CheckBox
var _luck_check: CheckBox
var _skill_check: CheckBox
var _opt_option: OptionButton
var _fenrir_option: OptionButton   # loại Sói Tinh (chỉ hiện khi chọn Horn of Fenrir)

var _count_label: Label
var _page_label: Label
var _btn_prev: Button
var _btn_next: Button
var _item_grid: GridContainer

# Cột thông tin bên phải
var _preview_rect: TextureRect
var _preview_name: Label
var _preview_stats: RichTextLabel
var _btn_take: Button
var _btn_equip: Button
var _btn_full_set: Button
var _btn_event_bundle: Button
var _btn_all_events: Button
var _btn_zen: Button
var _btn_point: Button
var _btn_god_mode: Button
var _btn_skill_class: Button
var _btn_skill_all: Button

# Danh mục phân loại
const CATEGORIES := [
	{"name": "— Tất Cả Thể Loại —", "group": -1},
	{"name": "🎟️ TẤT CẢ VẬT PHẨM SỰ KIỆN (All Events)", "group": -555},
	{"name": "🩸 Blood Castle (Lâu Đài Máu: Vé +1..8 & NL)", "group": -551},
	{"name": "😈 Devil Square (Quảng Trường Quỷ: Vé +1..7 & NL)", "group": -552},
	{"name": "🏰 Chaos Castle (Hỗn Nguyên Lâu: Vé +1..7)", "group": -553},
	{"name": "🏛️ Đền Kalima (Bản Đồ Kalima +1..7, Huy Hiệu)", "group": -554},
	{"name": "🔮 Illusion Temple (Đền Ảo Ảnh: Vé +1..6 & NL)", "group": -556},
	{"name": "🛡️ Crywolf, Kanturu & CTC (Công Thành, Life Stone)", "group": -557},
	{"name": "👑 Imperial Guardian & Doppelganger (Gaion, Gương)", "group": -558},
	{"name": "📜 Nhiệm Vụ Cấp 2 & 3 (Sách Đế Vương, Gươm, Condor)", "group": -559},
	{"name": "🎁 Hộp Kundun +1..5 & Quà Lễ Hội (May Mắn, Heart)", "group": -560},
	{"name": "💎 CÁC LOẠI NGỌC QUÝ (Jewels)", "group": -999},
	{"name": "🦄 THÚ CƯỠI & THẦN THÚ (Mounts & Pets)", "group": -998},
	{"name": "💍 NHẪN & DÂY CHUYỀN (Rings & Pendants)", "group": -997},
	{"name": "💜 ĐỒ TÍM & ĐỒ 380 (Tất Cả)", "group": -380},
	{"name": "💎 ĐỒ THẦN (Ancient Sets)", "group": -777},
	{"name": "🔮 ĐỒ KHẢM SOCKET (5 Lỗ)", "group": -888},
	{"name": "📖 Sách Kỹ Năng (Orb / Scroll — chuột phải để học)", "group": -666},
	{"name": "⚔️ Kiếm (Swords)", "group": 0},
	{"name": "🪓 Rìu (Axes)", "group": 1},
	{"name": "🔨 Chùy (Maces)", "group": 2},
	{"name": "🔱 Giáo / Thương (Spears)", "group": 3},
	{"name": "🏹 Cung & Nỏ (Bows)", "group": 4},
	{"name": "🪄 Gậy Phép (Staffs)", "group": 5},
	{"name": "🛡️ Khiên Bảo Vệ (Shields)", "group": 6},
	{"name": "👑 Mũ (Helms)", "group": 7},
	{"name": "🥋 Áo Giáp (Armors)", "group": 8},
	{"name": "👖 Quần (Pants)", "group": 9},
	{"name": "🧤 Găng Tay (Gloves)", "group": 10},
	{"name": "👢 Giày (Boots)", "group": 11},
	{"name": "🪽 Cánh & Áo Choàng (Wings)", "group": 12},
	{"name": "🦄 Thú Cưỡi & Nhẫn (Helpers - Group 13)", "group": 13},
	{"name": "🧪 Thuốc & Bình Máu (Potions - Group 14)", "group": 14},
	{"name": "📜 Sách Phép & Khác (Scrolls/Etc - Group 15)", "group": 15},
]

const CLASSES := [
	{"name": "— Tất Cả Class —", "key": ""},
	{"name": "Chiến Binh (DK)", "key": "darkKnight"},
	{"name": "Phù Thủy (DW)", "key": "darkWizard"},
	{"name": "Tiên Nữ (Elf)", "key": "fairyElf"},
	{"name": "Đấu Sĩ (MG)", "key": "magicGladiator"},
	{"name": "Chúa Tể (DL)", "key": "darkLord"},
	{"name": "Thuật Sĩ (SUM)", "key": "summoner"},
	{"name": "Thiết Binh (RF)", "key": "rageFighter"},
]

const CLASS_NAMES_VN := {
	"darkKnight": "Chiến Binh (DK)",
	"darkWizard": "Phù Thủy (DW)",
	"fairyElf": "Tiên Nữ (Elf)",
	"magicGladiator": "Đấu Sĩ (MG)",
	"darkLord": "Chúa Tể (DL)",
	"summoner": "Thuật Sĩ (SUM)",
	"rageFighter": "Thiết Binh (RF)",
}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)

	_build_ui()
	_place()
	get_viewport().size_changed.connect(_place)

	# Nạp danh sách đồ từ MuCatalog
	_load_catalog()

func setup(p_player: MuPlayer) -> void:
	player = p_player

func _place() -> void:
	var vs := get_viewport_rect().size
	# Đặt vị trí bên trái một chút để túi đồ (ở bên phải) mở cùng lúc mà không bị che khuất
	var target_x := maxf(20.0, (vs.x - W - 300.0) * 0.5)
	if target_x + W > vs.x - 290.0:
		target_x = maxf(10.0, (vs.x - W) * 0.5)
	position = Vector2(target_x, maxf(15.0, (vs.y - H) * 0.5))

func toggle() -> void:
	visible = not visible
	if visible:
		_update_gm_god_button()
	if visible:
		_place()
		if _all_items.is_empty():
			_load_catalog()
		_update_preview()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.keycode == KEY_B or k.keycode == KEY_F2 or k.keycode == KEY_G:
			toggle()
			get_viewport().set_input_as_handled()
		elif visible and k.keycode == KEY_ESCAPE:
			visible = false
			get_viewport().set_input_as_handled()

func _load_catalog() -> void:
	MuCatalogRes.ensure_loaded()
	_all_items.clear()
	for it in MuCatalogRes.get_all_items():
		_all_items.append(it)
	# Sắp xếp theo nhóm, sau đó theo số thứ tự
	_all_items.sort_custom(func(a, b):
		var ga := int(a.get("group", 0))
		var gb := int(b.get("group", 0))
		if ga != gb:
			return ga < gb
		return int(a.get("number", 0)) < int(b.get("number", 0))
	)
	_filter_items()
	if not _filtered_items.is_empty():
		_select_item(_filtered_items[0])

# ==============================================================================
# XÂY DỰNG GIAO DIỆN
# ==============================================================================
func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel_root)

	# Khung nền phong cách MU NewUI
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.04, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(bg)

	# Viền ngoài vàng đồng cổ điển
	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.7, 0.55, 0.25, 0.9)
	border.border_width = 2.0
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(border)

	# Tiêu đề
	var title_bar := ColorRect.new()
	title_bar.color = Color(0.18, 0.13, 0.08, 0.95)
	title_bar.position = Vector2(2, 2)
	title_bar.size = Vector2(W - 4, 38)
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(title_bar)

	var title_lbl := MuUiSkinRes.font_label("⚔️ KHO VẬT PHẨM GM — ITEM BOX (Phím B / F2)", 15, Color(1.0, 0.88, 0.45))
	title_lbl.position = Vector2(16, 10)
	_panel_root.add_child(title_lbl)

	var btn_gm_panel := Button.new()
	btn_gm_panel.text = "👑 BẢNG GM (Buff Cấp & Reset)"
	btn_gm_panel.position = Vector2(W - 275, 6)
	btn_gm_panel.size = Vector2(230, 26)
	btn_gm_panel.add_theme_font_size_override("font_size", 11)
	btn_gm_panel.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	btn_gm_panel.pressed.connect(func():
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("toggle_gm_panel"):
			hud.toggle_gm_panel()
	)
	_panel_root.add_child(btn_gm_panel)

	# Nút đóng [X]
	var btn_close := Button.new()
	btn_close.text = "✖"
	btn_close.position = Vector2(W - 38, 6)
	btn_close.size = Vector2(28, 26)
	btn_close.add_theme_color_override("font_color", Color(1, 0.7, 0.5))
	btn_close.pressed.connect(func(): visible = false)
	_panel_root.add_child(btn_close)

	# ================= KHU VỰC BỘ LỌC (HÀNG 1) =================
	var row1 := HBoxContainer.new()
	row1.position = Vector2(14, 46)
	row1.size = Vector2(W - 28, 30)
	row1.add_theme_constant_override("separation", 10)
	_panel_root.add_child(row1)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "🔍 Tìm kiếm theo tên đồ (Kris, Dragon, Wings, Bless...)"
	_search_input.custom_minimum_size = Vector2(270, 28)
	_search_input.text_changed.connect(func(_t): _filter_items())
	row1.add_child(_search_input)

	_cat_option = OptionButton.new()
	_cat_option.custom_minimum_size = Vector2(240, 28)
	for i in CATEGORIES.size():
		_cat_option.add_item(CATEGORIES[i]["name"], i)
	_cat_option.item_selected.connect(func(_idx): _filter_items())
	row1.add_child(_cat_option)

	_class_option = OptionButton.new()
	_class_option.custom_minimum_size = Vector2(190, 28)
	for i in CLASSES.size():
		_class_option.add_item(CLASSES[i]["name"], i)
	_class_option.item_selected.connect(func(_idx): _filter_items())
	row1.add_child(_class_option)

	# ================= THANH TÙY CHỈNH THUỘC TÍNH (2 HÀNG) =================
	var opt_bar := ColorRect.new()
	opt_bar.color = Color(0.12, 0.1, 0.08, 0.9)
	opt_bar.position = Vector2(14, 80)
	opt_bar.size = Vector2(W - 28, 66)
	opt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(opt_bar)

	# Hàng 2a: Cấp độ, nút nhanh, option Life, nút Full Option
	var row2a := HBoxContainer.new()
	row2a.position = Vector2(20, 83)
	row2a.size = Vector2(W - 40, 26)
	row2a.add_theme_constant_override("separation", 8)
	_panel_root.add_child(row2a)

	var lbl_lvl_title := MuUiSkinRes.font_label("Cấp độ:", 12, Color(1, 0.9, 0.7))
	row2a.add_child(lbl_lvl_title)

	_level_slider = HSlider.new()
	_level_slider.min_value = 0
	_level_slider.max_value = 15
	_level_slider.step = 1
	_level_slider.value = 15
	_level_slider.custom_minimum_size = Vector2(110, 24)
	_level_slider.value_changed.connect(_on_level_changed)
	row2a.add_child(_level_slider)

	_level_label = MuUiSkinRes.font_label("+15", 13, Color(1.0, 0.85, 0.2))
	_level_label.custom_minimum_size = Vector2(28, 20)
	row2a.add_child(_level_label)

	for lv in [0, 9, 13, 15]:
		var b_lv := Button.new()
		b_lv.text = "+%d" % lv
		b_lv.custom_minimum_size = Vector2(32, 22)
		b_lv.pressed.connect(func(): _level_slider.value = lv)
		row2a.add_child(b_lv)

	var lbl_opt := MuUiSkinRes.font_label("Opt Life:", 12, Color(1, 0.9, 0.7))
	row2a.add_child(lbl_opt)

	_opt_option = OptionButton.new()
	_opt_option.custom_minimum_size = Vector2(75, 22)
	for i in 8:
		_opt_option.add_item("+%d" % (i * 4), i)
	_opt_option.selected = 7 # Mặc định +28
	_opt_option.item_selected.connect(func(_idx): _update_preview())
	row2a.add_child(_opt_option)

	# Loại Sói Tinh: cờ Excellent 0 = đỏ, 1 = Destroy (đen), 2 = Protect (xanh), 4 = Illusion (vàng)
	_fenrir_option = OptionButton.new()
	_fenrir_option.custom_minimum_size = Vector2(150, 22)
	_fenrir_option.add_item("Fenrir Đỏ", 0)
	_fenrir_option.add_item("Fenrir Đen (+Destroy)", 1)
	_fenrir_option.add_item("Fenrir Xanh (+Protect)", 2)
	_fenrir_option.add_item("Fenrir Vàng (+Illusion)", 4)
	_fenrir_option.selected = 3
	_fenrir_option.visible = false
	_fenrir_option.item_selected.connect(func(_idx): _update_preview())
	row2a.add_child(_fenrir_option)

	# Nút bấm 1-click kích hoạt Full Tất Cả Option Siêu Phẩm
	var btn_max := Button.new()
	btn_max.text = "⚡ MAX FULL TẤT CẢ OPTION"
	btn_max.custom_minimum_size = Vector2(210, 24)
	btn_max.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	btn_max.pressed.connect(_on_max_full_options)
	row2a.add_child(btn_max)

	# Hàng 2b: Các Checkbox chọn dòng tính năng đặc biệt
	var row2b := HBoxContainer.new()
	row2b.position = Vector2(20, 114)
	row2b.size = Vector2(W - 40, 26)
	row2b.add_theme_constant_override("separation", 6)
	_panel_root.add_child(row2b)

	_exc_check = CheckBox.new()
	_exc_check.text = "Hoàn Hảo"
	_exc_check.button_pressed = true
	_exc_check.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	_exc_check.toggled.connect(func(_b): _update_preview())
	row2b.add_child(_exc_check)

	_purple_check = CheckBox.new()
	_purple_check.text = "Tím 380"
	_purple_check.button_pressed = false
	_purple_check.add_theme_color_override("font_color", Color(0.9, 0.45, 1.0))
	_purple_check.toggled.connect(func(_b): _update_preview())
	row2b.add_child(_purple_check)

	_ancient_check = CheckBox.new()
	_ancient_check.text = "Đồ Thần"
	_ancient_check.button_pressed = false
	_ancient_check.add_theme_color_override("font_color", Color(0.1, 0.9, 0.8))
	_ancient_check.toggled.connect(func(_b): _update_preview())
	row2b.add_child(_ancient_check)

	_socket_check = CheckBox.new()
	_socket_check.text = "Socket 5 Lỗ"
	_socket_check.button_pressed = false
	_socket_check.add_theme_color_override("font_color", Color(1.0, 0.55, 1.0))
	_socket_check.toggled.connect(func(_b): _update_preview())
	row2b.add_child(_socket_check)

	_harmony_check = CheckBox.new()
	_harmony_check.text = "Tạo Hóa"
	_harmony_check.button_pressed = false
	_harmony_check.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_harmony_check.toggled.connect(func(_b): _update_preview())
	row2b.add_child(_harmony_check)

	_luck_check = CheckBox.new()
	_luck_check.text = "May Mắn"
	_luck_check.button_pressed = true
	_luck_check.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	_luck_check.toggled.connect(func(_b): _update_preview())
	row2b.add_child(_luck_check)

	_skill_check = CheckBox.new()
	_skill_check.text = "Skill"
	_skill_check.button_pressed = true
	_skill_check.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	_skill_check.toggled.connect(func(_b): _update_preview())
	row2b.add_child(_skill_check)

	# ================= CỘT TRÁI: DANH SÁCH MÓN ĐỒ (Width 470px) =================
	var left_box := Control.new()
	left_box.position = Vector2(14, 152)
	left_box.size = Vector2(464, 404)
	_panel_root.add_child(left_box)

	# Thanh đếm & phân trang
	var page_bar := HBoxContainer.new()
	page_bar.position = Vector2(0, 0)
	page_bar.size = Vector2(464, 26)
	left_box.add_child(page_bar)

	_count_label = MuUiSkinRes.font_label("Vật phẩm: 0", 12, Color(0.85, 0.85, 0.85))
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_bar.add_child(_count_label)

	_btn_prev = Button.new()
	_btn_prev.text = "◀ Trang trước"
	_btn_prev.custom_minimum_size = Vector2(95, 24)
	_btn_prev.pressed.connect(_on_prev_page)
	page_bar.add_child(_btn_prev)

	_page_label = MuUiSkinRes.font_label("1 / 1", 12, Color(1, 0.9, 0.5))
	_page_label.custom_minimum_size = Vector2(65, 24)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_bar.add_child(_page_label)

	_btn_next = Button.new()
	_btn_next.text = "Trang sau ▶"
	_btn_next.custom_minimum_size = Vector2(95, 24)
	_btn_next.pressed.connect(_on_next_page)
	page_bar.add_child(_btn_next)

	# Vùng cuộn chứa Grid các món đồ
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 32)
	scroll.size = Vector2(464, 370)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_box.add_child(scroll)

	_item_grid = GridContainer.new()
	_item_grid.columns = 8 # 8 cột ô vật phẩm chuẩn túi đồ
	_item_grid.add_theme_constant_override("h_separation", 6)
	_item_grid.add_theme_constant_override("v_separation", 6)
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_grid)

	# ================= CỘT PHẢI: CHI TIẾT & PREVIEW 3D (Width 264px) =================
	var right_box := Control.new()
	right_box.position = Vector2(490, 152)
	right_box.size = Vector2(266, 404)
	_panel_root.add_child(right_box)

	var right_bg := ColorRect.new()
	right_bg.color = Color(0.04, 0.035, 0.03, 0.9)
	right_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(right_bg)

	var right_border := ReferenceRect.new()
	right_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_border.border_color = Color(0.5, 0.4, 0.2, 0.8)
	right_border.border_width = 1.0
	right_border.editor_only = false
	right_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(right_border)

	# Khung Preview 3D
	var prev_bg := ColorRect.new()
	prev_bg.color = Color(0.08, 0.07, 0.06, 0.95)
	prev_bg.position = Vector2(10, 6)
	prev_bg.size = Vector2(246, 100)
	prev_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(prev_bg)

	_preview_rect = TextureRect.new()
	_preview_rect.position = Vector2(10, 6)
	_preview_rect.size = Vector2(246, 100)
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(_preview_rect)

	# Tên món đồ to nổi bật
	_preview_name = MuUiSkinRes.font_label("Chưa chọn vật phẩm", 14, Color(1, 1, 1))
	_preview_name.position = Vector2(12, 110)
	_preview_name.size = Vector2(242, 20)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_box.add_child(_preview_name)

	# Bảng chi tiết thông số
	_preview_stats = RichTextLabel.new()
	_preview_stats.bbcode_enabled = true
	_preview_stats.position = Vector2(12, 132)
	_preview_stats.size = Vector2(242, 126)
	_preview_stats.scroll_active = true
	right_box.add_child(_preview_stats)

	# Nút hành động
	_btn_take = Button.new()
	_btn_take.text = "🎁 LẤY VÀO TÚI ĐỒ"
	_btn_take.position = Vector2(10, 262)
	_btn_take.size = Vector2(246, 24)
	_btn_take.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_btn_take.pressed.connect(_on_take_item)
	right_box.add_child(_btn_take)

	_btn_equip = Button.new()
	_btn_equip.text = "⚔️ MẶC LÊN NGƯỜI NGAY"
	_btn_equip.position = Vector2(10, 288)
	_btn_equip.size = Vector2(246, 20)
	_btn_equip.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_btn_equip.pressed.connect(_on_equip_item)
	right_box.add_child(_btn_equip)

	_btn_full_set = Button.new()
	_btn_full_set.text = "🛡️ Lấy Trọn Bộ Set (5 món)"
	_btn_full_set.position = Vector2(10, 310)
	_btn_full_set.size = Vector2(246, 20)
	_btn_full_set.add_theme_color_override("font_color", Color(0.8, 1.0, 0.6))
	_btn_full_set.pressed.connect(_on_take_full_set)
	right_box.add_child(_btn_full_set)

	# Nút nhận nhanh combo sự kiện
	_btn_event_bundle = Button.new()
	_btn_event_bundle.text = "🎟️ LẤY VÉ SỰ KIỆN NÀY"
	_btn_event_bundle.position = Vector2(10, 310)
	_btn_event_bundle.size = Vector2(246, 20)
	_btn_event_bundle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_btn_event_bundle.visible = false
	_btn_event_bundle.pressed.connect(_on_take_event_bundle)
	right_box.add_child(_btn_event_bundle)

	_btn_all_events = Button.new()
	_btn_all_events.text = "⭐ NHẬN TRỌN BỘ VÉ TẤT CẢ SỰ KIỆN"
	_btn_all_events.position = Vector2(10, 310)
	_btn_all_events.size = Vector2(246, 20)
	_btn_all_events.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_btn_all_events.visible = false
	_btn_all_events.pressed.connect(_on_take_all_events)
	right_box.add_child(_btn_all_events)

	_btn_zen = Button.new()
	_btn_zen.text = "💰 +10M Zen"
	_btn_zen.position = Vector2(10, 332)
	_btn_zen.size = Vector2(120, 20)
	_btn_zen.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_btn_zen.pressed.connect(_on_get_zen)
	right_box.add_child(_btn_zen)

	_btn_point = Button.new()
	_btn_point.text = "✨ +5K Point"
	_btn_point.position = Vector2(136, 332)
	_btn_point.size = Vector2(120, 20)
	_btn_point.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_btn_point.pressed.connect(_on_get_point)
	right_box.add_child(_btn_point)

	_btn_skill_class = Button.new()
	_btn_skill_class.text = "⚡ Skill (Class)"
	_btn_skill_class.position = Vector2(10, 354)
	_btn_skill_class.size = Vector2(120, 20)
	_btn_skill_class.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	_btn_skill_class.pressed.connect(_on_learn_class_skills)
	right_box.add_child(_btn_skill_class)

	_btn_skill_all = Button.new()
	_btn_skill_all.text = "🌟 Mọi Class"
	_btn_skill_all.position = Vector2(136, 354)
	_btn_skill_all.size = Vector2(120, 20)
	_btn_skill_all.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_btn_skill_all.pressed.connect(_on_learn_all_class_skills)
	right_box.add_child(_btn_skill_all)

	_btn_god_mode = Button.new()
	_btn_god_mode.position = Vector2(10, 376)
	_btn_god_mode.size = Vector2(246, 22)
	_btn_god_mode.add_theme_font_size_override("font_size", 11)
	_btn_god_mode.pressed.connect(_on_toggle_god_mode)
	right_box.add_child(_btn_god_mode)
	_update_gm_god_button()

# ==============================================================================
# LỌC & PHÂN TRANG
# ==============================================================================
static func _unaccent(s: String) -> String:
	var r := s.to_lower()
	var maps := {
		"a": ["à","á","ạ","ả","ã","â","ầ","ấ","ậ","ẩ","ẫ","ă","ằ","ắ","ặ","ẳ","ẵ"],
		"e": ["è","é","ẹ","ẻ","ẽ","ê","ề","ế","ệ","ể","ễ"],
		"i": ["ì","í","ị","ỉ","ĩ"],
		"o": ["ò","ó","ọ","ỏ","õ","ô","ồ","ố","ộ","ổ","ỗ","ơ","ờ","ớ","ợ","ở","ỡ"],
		"u": ["ù","ú","ụ","ủ","ũ","ư","ừ","ứ","ự","ử","ữ"],
		"y": ["ỳ","ý","ỵ","ỷ","ỹ"],
		"d": ["đ"]
	}
	for target in maps:
		for ch in maps[target]:
			r = r.replace(ch, target)
	return r

func _filter_items() -> void:
	var kw: String = _search_input.text.strip_edges().to_lower() if _search_input else ""
	var cat_idx: int = _cat_option.selected if _cat_option else 0
	var cat_grp: int = CATEGORIES[cat_idx]["group"]
	var class_idx: int = _class_option.selected if _class_option else 0
	var class_key: String = CLASSES[class_idx]["key"]

	_filtered_items.clear()
	for it in _all_items:
		var g := int(it.get("group", -1))
		var n := int(it.get("number", 0))

		# Lọc theo thể loại
		if cat_grp == -555:
			# Tất Cả Vật Phẩm Sự Kiện
			if not MuItemsRes.is_event_item(it):
				continue
		elif cat_grp in [-551, -552, -553, -554, -556, -557, -558, -559, -560]:
			# Từng nhóm sự kiện cụ thể
			if MuItemsRes.event_category_id(it) != cat_grp:
				continue
		elif cat_grp == -999:
			# Các Loại Ngọc Quý (Bless, Soul, Chaos, Life, Creation, Guardian, Harmony, Gemstones, Bundles)
			if not MuItemsRes.is_jewel(it):
				continue
		elif cat_grp == -998:
			# Thú Cưỡi & Thần Thú (Guardian Angel, Imp/Satan, Uniria, Dinorant, Dark Horse, Dark Raven, Fenrir, Demon, Panda, Rudolf...)
			if not (MuItemsRes.is_mount(it) or MuItemsRes.is_pet(it) or MuItemsRes.is_helper(it)):
				continue
		elif cat_grp == -997:
			# Nhẫn & Dây Chuyền (Rings & Pendants)
			if not (MuItemsRes.is_ring(it) or MuItemsRes.is_pendant(it)):
				continue
		elif cat_grp == -380:
			var req = it.get("requirements", {})
			var req_lv: int = int(req.get("level", 0)) if req is Dictionary else 0
			var it_lv: int = int(it.get("level", 0))
			if it_lv < 380 and req_lv < 380:
				continue
		elif cat_grp == -777:
			# Đồ Thần (Ancient)
			var is_ancient := (g <= 11 and n in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 14, 15, 16, 17, 18])
			if not is_ancient:
				continue
		elif cat_grp == -888:
			# Đồ Socket (Vũ khí & Giáp socket cấp cao)
			var is_socket := (g <= 11 and (n >= 19 and n <= 55))
			if not is_socket:
				continue
		elif cat_grp == -666:
			# Orb / scroll / parchment dạy skill (skills.json "items", tools/mu_gamedata.py)
			if MuCatalogRes.skill_item(g, n).is_empty():
				continue
		elif cat_grp >= 0 and g != cat_grp:
			continue

		# Lọc theo Class (nếu có yêu cầu Class và class hiện tại không dùng được thì bỏ qua)
		if class_key != "":
			var raw_reqs = it.get("classRequirements")
			if raw_reqs is Dictionary and not raw_reqs.is_empty():
				if int(raw_reqs.get(class_key, 0)) <= 0:
					continue

		# Lọc theo từ khóa tìm kiếm (hỗ trợ cả Tiếng Anh, Tiếng Việt có dấu, Tiếng Việt không dấu và ID g:n)
		if kw != "":
			var base_n := MuItemsRes.base_name(it).to_lower()
			var raw_nm = it.get("name", "")
			var en_n: String = (raw_nm.get("en", "") if raw_nm is Dictionary else str(raw_nm)).to_lower()
			var gn := "%d:%d" % [g, n]
			var kw_plain := _unaccent(kw)
			var base_plain := _unaccent(base_n)
			var matched := en_n.contains(kw) or base_n.contains(kw) or base_plain.contains(kw_plain) or gn.contains(kw)
			if not matched:
				continue

		_filtered_items.append(it)

	_current_page = 0
	_render_page()

func _render_page() -> void:
	_card_buttons.clear()
	for c in _item_grid.get_children():
		c.queue_free()

	var total := _filtered_items.size()
	_count_label.text = "Vật phẩm: %d" % total

	var total_pages := maxi(1, int(ceil(float(total) / float(ITEMS_PER_PAGE))))
	_current_page = clampi(_current_page, 0, total_pages - 1)
	_page_label.text = "%d / %d" % [_current_page + 1, total_pages]
	_btn_prev.disabled = (_current_page <= 0)
	_btn_next.disabled = (_current_page >= total_pages - 1)

	var start := _current_page * ITEMS_PER_PAGE
	var end := mini(total, start + ITEMS_PER_PAGE)

	for i in range(start, end):
		var it: Dictionary = _filtered_items[i]
		var btn := _create_item_card(it)
		var key := "%s:%s" % [str(it.get("group", -1)), str(it.get("number", -1))]
		_card_buttons[key] = btn
		_item_grid.add_child(btn)

func _create_item_card(it: Dictionary) -> Control:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	var item_name: String = MuItemsRes.base_name(it)
	if item_name == "":
		item_name = "Item %d-%d" % [g, n]

	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s %s" % [item_name, _group_badge(it)]

	var is_sel: bool = (int(_selected_info.get("group", -1)) == g and int(_selected_info.get("number", -1)) == n)
	_apply_slot_style(b, is_sel)

	# Ảnh đồ vật phẩm (hiển thị vừa khít trong ô)
	var icon_rect := TextureRect.new()
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 3
	icon_rect.offset_top = 3
	icon_rect.offset_right = -3
	icon_rect.offset_bottom = -3
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sample := MuItemsRes.make(g, n, 0)
	var t: Texture2D = MuItemIconRes.catalog_icon(get_tree(), sample, 52)
	if t:
		icon_rect.texture = t
	else:
		var fallback_lbl := Label.new()
		fallback_lbl.text = "%d:%d" % [g, n]
		fallback_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback_lbl.add_theme_font_size_override("font_size", 9)
		fallback_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		b.add_child(fallback_lbl)

	b.add_child(icon_rect)
	b.pressed.connect(func(): _select_item(it))
	return b

func _apply_slot_style(btn: Button, is_sel: bool) -> void:
	var normal_sb := StyleBoxFlat.new()
	var hover_sb := StyleBoxFlat.new()
	var pressed_sb := StyleBoxFlat.new()

	if is_sel:
		normal_sb.bg_color = Color(0.24, 0.20, 0.10, 0.95)
		normal_sb.border_color = Color(1.0, 0.85, 0.2, 1.0)
		normal_sb.set_border_width_all(2)

		hover_sb.bg_color = Color(0.30, 0.25, 0.13, 0.98)
		hover_sb.border_color = Color(1.0, 0.95, 0.4, 1.0)
		hover_sb.set_border_width_all(2)

		pressed_sb.bg_color = Color(0.35, 0.28, 0.15, 1.0)
		pressed_sb.border_color = Color(1.0, 0.9, 0.3, 1.0)
		pressed_sb.set_border_width_all(2)
	else:
		normal_sb.bg_color = Color(0.10, 0.11, 0.13, 0.9)
		normal_sb.border_color = Color(0.32, 0.32, 0.38, 0.75)
		normal_sb.set_border_width_all(1)

		hover_sb.bg_color = Color(0.18, 0.20, 0.26, 0.95)
		hover_sb.border_color = Color(0.7, 0.75, 0.88, 1.0)
		hover_sb.set_border_width_all(1)

		pressed_sb.bg_color = Color(0.24, 0.22, 0.16, 0.95)
		pressed_sb.border_color = Color(0.9, 0.8, 0.3, 1.0)
		pressed_sb.set_border_width_all(1)

	normal_sb.set_corner_radius_all(2)
	hover_sb.set_corner_radius_all(2)
	pressed_sb.set_corner_radius_all(2)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

func _group_badge(it: Dictionary) -> String:
	var g := int(it.get("group", 0))
	if MuItemsRes.is_event_item(it):
		var ev_id := MuItemsRes.event_category_id(it)
		match ev_id:
			-551: return "[Blood Castle]"
			-552: return "[Devil Square]"
			-553: return "[Chaos Castle]"
			-554: return "[Kalima]"
			-556: return "[Illusion]"
			-557: return "[Crywolf/CTC]"
			-558: return "[Gaion/Doppel]"
			-559: return "[Nhiệm Vụ]"
			-560: return "[Hộp Quà]"
		return "[Sự Kiện]"
	if MuItemsRes.is_jewel(it):
		return "[Ngọc Quý]"
	if MuItemsRes.is_mount(it):
		return "[Thú Cưỡi]"
	if MuItemsRes.is_pet(it):
		return "[Thần Thú/Pet]"
	if MuItemsRes.is_pendant(it):
		return "[Dây Chuyền]"
	if MuItemsRes.is_ring(it):
		return "[Nhẫn]"
	match g:
		0: return "[Kiếm]"
		1: return "[Rìu]"
		2: return "[Chùy]"
		3: return "[Giáo]"
		4: return "[Cung/Nỏ]"
		5: return "[Gậy Phép]"
		6: return "[Khiên]"
		7: return "[Mũ]"
		8: return "[Áo Giáp]"
		9: return "[Quần]"
		10: return "[Găng Tay]"
		11: return "[Giày]"
		12: return "[Cánh]"
		13: return "[Phụ Kiện]"
		14: return "[Thuốc/Bình]"
		15: return "[Sách/Khác]"
	return "[Item]"

func _select_item(it: Dictionary) -> void:
	var old_key := "%s:%s" % [str(_selected_info.get("group", -1)), str(_selected_info.get("number", -1))]
	_selected_info = it
	var new_key := "%s:%s" % [str(it.get("group", -1)), str(it.get("number", -1))]
	if _card_buttons.has(old_key) and is_instance_valid(_card_buttons[old_key]):
		_apply_slot_style(_card_buttons[old_key], false)
	if _card_buttons.has(new_key) and is_instance_valid(_card_buttons[new_key]):
		_apply_slot_style(_card_buttons[new_key], true)

	var req = it.get("requirements", {})
	var req_lv: int = int(req.get("level", 0)) if req is Dictionary else 0
	var it_lv: int = int(it.get("level", 0))
	if (it_lv >= 380 or req_lv >= 380) and _purple_check:
		_purple_check.button_pressed = true
	if _fenrir_option:
		_fenrir_option.visible = int(it.get("group", 0)) == 13 and int(it.get("number", 0)) == 37
	_update_preview()

func _on_prev_page() -> void:
	if _current_page > 0:
		_current_page -= 1
		_render_page()

func _on_next_page() -> void:
	var total_pages := maxi(1, int(ceil(float(_filtered_items.size()) / float(ITEMS_PER_PAGE))))
	if _current_page < total_pages - 1:
		_current_page += 1
		_render_page()

func _on_level_changed(val: float) -> void:
	_level_label.text = "+%d" % int(val)
	_update_preview()

func _on_max_full_options() -> void:
	if _level_slider: _level_slider.value = 15
	if _exc_check: _exc_check.button_pressed = true
	if _purple_check: _purple_check.button_pressed = true
	if _ancient_check: _ancient_check.button_pressed = true
	if _socket_check: _socket_check.button_pressed = true
	if _harmony_check: _harmony_check.button_pressed = true
	if _luck_check: _luck_check.button_pressed = true
	if _skill_check: _skill_check.button_pressed = true
	if _opt_option: _opt_option.selected = 7 # +28
	_update_preview()
	_notify("Đã bật TẤT CẢ Option cực phẩm (+15, Exc, Tím 380, Thần, Socket, Tạo Hóa, Luck, Skill, Opt +28)!", Color(1.0, 0.85, 0.2))

# ==============================================================================
# HIỂN THỊ XEM TRƯỚC (PREVIEW 3D) & THÔNG TIN CHI TIẾT
# ==============================================================================
func _get_current_configured_item() -> Dictionary:
	if _selected_info.is_empty():
		return {}
	var g := int(_selected_info.get("group", 0))
	var n := int(_selected_info.get("number", 0))
	var lv := int(_level_slider.value) if _level_slider else 0
	var exc := _exc_check.button_pressed if _exc_check else false
	var purple := _purple_check.button_pressed if _purple_check else false
	var ancient := _ancient_check.button_pressed if _ancient_check else false
	var socket := _socket_check.button_pressed if _socket_check else false
	var harmony := _harmony_check.button_pressed if _harmony_check else false
	var luck := _luck_check.button_pressed if _luck_check else false
	var skill := _skill_check.button_pressed if _skill_check else false
	var opt := _opt_option.selected if _opt_option else 0

	return MuItemsRes.make(g, n, lv, {
		"excellent": exc,
		"purple": purple,
		"option_380": purple,
		"ancient": ancient,
		"socket": socket,
		"harmony": harmony,
		"luck": luck,
		"skill": skill,
		"opt": opt,
		"excellent_flags": _fenrir_option.get_item_id(_fenrir_option.selected) if (_fenrir_option and _fenrir_option.visible) else 0
	})

func _update_preview() -> void:
	if _selected_info.is_empty():
		_preview_rect.texture = null
		_preview_name.text = "Chưa chọn vật phẩm"
		_preview_stats.text = ""
		return

	var configured := _get_current_configured_item()
	var g := int(configured.get("group", 0))
	var lv := int(configured.get("level", 0))
	var exc := bool(configured.get("excellent", false))
	var purple := bool(configured.get("purple", false))
	var ancient := bool(configured.get("ancient", false))
	var socket := bool(configured.get("socket", false))
	var harmony := bool(configured.get("harmony", false))

	# Cập nhật ảnh render 3D
	var t: Texture2D = MuItemIconRes.preview_icon(get_tree(), configured, Vector2i(246, 100))
	_preview_rect.texture = t

	# Cập nhật tên hiển thị & màu sắc
	var dname := MuItemsRes.display_name(configured)
	var col := MuItemsRes.name_color(configured)
	_preview_name.text = dname
	_preview_name.add_theme_color_override("font_color", col)

	# Bảng thống kê chi tiết (BBCode)
	var inf: Dictionary = _selected_info
	var bb := ""

	# Loại slot
	var slot_name := _slot_vn_name(inf, g)
	if slot_name != "":
		bb += "[color=#aaccff]Vị trí:[/color] %s\n" % slot_name

	# Sát thương
	if inf.has("damageMin"):
		var bonus: int = lv * 3 + maxi(0, lv - 9) * (lv - 9) / 2
		var min_d: int = int(inf["damageMin"]) + bonus
		var max_d: int = int(inf["damageMax"]) + bonus
		bb += "[color=#ffffaa]Sát thương:[/color] %d ~ %d" % [min_d, max_d]
		if bonus > 0:
			bb += " [color=#88ff88](+%d)[/color]" % bonus
		bb += "\n"

	# Sức mạnh phép thuật
	if inf.has("magicPower") and int(inf.get("magicPower", 0)) > 0:
		bb += "[color=#ffffaa]Lực đánh phép thuật:[/color] %d%%\n" % int(inf["magicPower"])

	# Phòng thủ
	if inf.has("defense"):
		var def_val: int = int(inf["defense"]) + lv * 3
		bb += "[color=#ffffaa]Sức phòng thủ:[/color] %d" % def_val
		if lv > 0:
			bb += " [color=#88ff88](+%d)[/color]" % (lv * 3)
		bb += "\n"

	# Tốc độ đánh
	if inf.has("attackSpeed"):
		bb += "[color=#dddddd]Tốc độ tấn công:[/color] %d\n" % int(inf["attackSpeed"])

	# Độ bền
	var dur := MuItemsRes.max_durability(configured)
	bb += "[color=#dddddd]Độ bền:[/color] [%d/%d]\n" % [dur, dur]

	# Yêu cầu chỉ số
	var reqs: Dictionary = inf.get("requirements", {}) if inf.get("requirements") is Dictionary else {}
	if not reqs.is_empty():
		bb += "[color=#ffbb88]Yêu cầu:[/color] "
		var parts := []
		if reqs.has("level"): parts.append("Cấp %d" % int(reqs["level"]))
		if reqs.has("strength"): parts.append("Sức mạnh %d" % int(reqs["strength"]))
		if reqs.has("dexterity"): parts.append("Nhanh nhẹn %d" % int(reqs["dexterity"]))
		if reqs.has("vitality"): parts.append("Thể lực %d" % int(reqs["vitality"]))
		if reqs.has("energy"): parts.append("Năng lượng %d" % int(reqs["energy"]))
		if reqs.has("command"): parts.append("Mệnh lệnh %d" % int(reqs["command"]))
		bb += ", ".join(parts) + "\n"

	# Class yêu cầu
	var class_reqs: Dictionary = inf.get("classRequirements", {}) if inf.get("classRequirements") is Dictionary else {}
	if not class_reqs.is_empty():
		var cl_list := []
		for ck in class_reqs:
			if int(class_reqs[ck]) > 0 and CLASS_NAMES_VN.has(ck):
				cl_list.append(CLASS_NAMES_VN[ck])
		if not cl_list.is_empty():
			bb += "[color=#ff99aa]Dành cho:[/color] %s\n" % ", ".join(cl_list)

	# Các dòng đặc biệt
	if ancient:
		bb += "[color=#1ae6cc]★ Kích Hoạt Tính Năng Set Thần (Ancient)[/color]\n"
		bb += "[color=#66ffee]  + Sát thương chí mạng +15% / Hoàn hảo +15%\n  + Tăng sức mạnh +30 / Năng lượng +30\n  + Tỉ lệ loại bỏ phòng ngự đối phương 5%[/color]\n"

	if exc:
		bb += "[color=#22ff88]★ Thuộc Tính Hoàn Hảo (Excellent)[/color]\n"
		if g <= 5: # Vũ khí
			bb += "[color=#44ff99]  + Sát thương Hoàn hảo +10%%\n  + Tăng sức tấn công +%d%%\n  + Tăng tốc độ tấn công +7[/color]\n" % (lv * 2 + 2)
		else: # Giáp / khiên
			bb += "[color=#44ff99]  + Khả năng tránh đòn +10%\n  + Giảm sát thương 4%\n  + Phản hồi sát thương 5%[/color]\n"

	if purple:
		bb += "[color=#e066ff]★ Tính Năng Gia Cường 380 (Dòng Tím)[/color]\n"
		if g <= 5: # Vũ khí
			bb += "[color=#f088ff]  + Gia tăng sức tấn công PvP +200\n  + Tăng tỉ lệ tấn công SD PvP +10[/color]\n"
		elif g <= 11: # Giáp / khiên
			bb += "[color=#f088ff]  + Gia tăng sức phòng thủ SD +100\n  + Tự động hồi phục lượng SD\n  + Gia tăng phòng thủ PvP +200[/color]\n"
		else:
			bb += "[color=#f088ff]  + Khảm Ngọc Nguyên Tố Socket Tím\n  + Tăng sát thương/hấp thụ hoàn hảo[/color]\n"

	if harmony:
		bb += "[color=#ffd700]★ Tính Năng Đá Tạo Hóa (Jewel of Harmony)[/color]\n"
		if g <= 5:
			bb += "[color=#ffee66]  + Lực đánh chí mạng +30 / Bỏ qua SD 10%[/color]\n"
		else:
			bb += "[color=#ffee66]  + Sức phòng thủ +35 / Giảm sát thương 7%[/color]\n"

	if socket:
		bb += "[color=#ff88ff]★ Khảm 5 Lỗ Ngọc Nguyên Tố Socket[/color]\n"
		bb += "[color=#ddaaff]  (Lửa) Sát thương tối đa +30\n  (Sét) Tỉ lệ sát thương hoàn hảo +12%\n  (Băng) Sát thương kỹ năng +37\n  (Gió) Tốc độ hồi phục SD +20\n  (Nước) Giảm sát thương +8%\n  [Phụ Trội] Tăng sát thương hoàn hảo +40[/color]\n"

	if MuItemsRes.is_wing(configured) and lv >= 9:
		bb += "[color=#e6b8ff]★ Thuộc Tính Cánh Cấp Cao:\n  + 5% Hồi phục hoàn toàn HP/SD\n  + 3% Tấn công loại bỏ phòng ngự đối phương[/color]\n"

	if bool(configured.get("luck", false)):
		bb += "[color=#66bbff]★ May mắn: Tỉ lệ sát thương chí mạng +5%[/color]\n"
		bb += "[color=#66bbff]★ May mắn: Tỉ lệ đập Ngọc Tâm Linh +25%[/color]\n"
	if bool(configured.get("skill", false)):
		bb += "[color=#aa88ff]★ Có kỹ năng đặc biệt của vũ khí[/color]\n"
	var opt_val := int(configured.get("opt", 0)) * 4
	if opt_val > 0:
		bb += "[color=#ffff66]★ Tính năng bổ sung +%d[/color]\n" % opt_val

	_preview_stats.text = bb

	# Kiểm tra nút full set: chỉ hiện nếu là đồ bộ (Group 7..11)
	var is_set := (g >= 7 and g <= 11)
	_btn_full_set.visible = is_set

	# Kiểm tra nút combo sự kiện
	var is_ev := MuItemsRes.is_event_item(configured)
	var ev_id := MuItemsRes.event_category_id(configured)
	var cat_idx: int = _cat_option.selected if _cat_option else 0
	var cat_grp: int = CATEGORIES[cat_idx]["group"]

	_btn_all_events.visible = (cat_grp == -555) and not is_set
	_btn_event_bundle.visible = is_ev and not is_set and not _btn_all_events.visible

	if is_ev and not is_set:
		match ev_id:
			-551: _btn_event_bundle.text = "🩸 Nhận Full Vé Blood Castle"
			-552: _btn_event_bundle.text = "😈 Nhận Full Vé Devil Square"
			-553: _btn_event_bundle.text = "🏰 Nhận Full Vé Chaos Castle"
			-554: _btn_event_bundle.text = "🏛️ Nhận Full Vé Kalima"
			-556: _btn_event_bundle.text = "🔮 Nhận Full Vé Illusion Temple"
			-557: _btn_event_bundle.text = "🛡️ Nhận Vé Crywolf, Kanturu & CTC"
			-558: _btn_event_bundle.text = "👑 Nhận Vé Gaion & Doppelganger"
			-559: _btn_event_bundle.text = "📜 Nhận Đồ Nhiệm Vụ Cấp 2 & 3"
			-560: _btn_event_bundle.text = "🎁 Nhận Bộ Hộp Kundun (+1..5)"
			_: _btn_event_bundle.text = "🎟️ LẤY VÉ SỰ KIỆN NÀY"

func _slot_vn_name(inf: Dictionary, g: int) -> String:
	if MuItemsRes.is_jewel(inf):
		return "Ngọc Quý (Jewel)"
	if MuItemsRes.is_mount(inf):
		return "Thú Cưỡi (Mount)"
	if MuItemsRes.is_pet(inf):
		return "Thần Thú / Thú Nuôi (Pet)"
	if MuItemsRes.is_pendant(inf):
		return "Dây Chuyền (Pendant/Necklace)"
	if MuItemsRes.is_ring(inf):
		return "Nhẫn (Ring)"
	match g:
		0, 1, 2, 3, 4, 5:
			var sl: String = str(inf.get("slot", "mainHand"))
			return "Tay Phụ (Trái)" if sl == "offHand" else "Vũ Khí Chính (Phải)"
		6: return "Khiên Bảo Vệ (Tay Trái)"
		7: return "Mũ Giáp (Helm)"
		8: return "Áo Giáp (Armor)"
		9: return "Quần (Pants)"
		10: return "Găng Tay (Gloves)"
		11: return "Giày (Boots)"
		12: return "Cánh / Áo Choàng (Wings)"
		13: return "Thú Cưỡi / Nhẫn / Dây Chuyền"
		14: return "Bình Thuốc / Vật Phẩm"
		15: return "Sách Phép / Cuộn Giấy"
	return "Vật Phẩm"

# ==============================================================================
# HÀNH ĐỘNG: LẤY ĐỒ VÀO TÚI, MẶC LÊN NGƯỜI, LẤY CẢ BỘ, ZEN
# ==============================================================================
func _hud():
	return get_tree().get_first_node_in_group("HUD")

func _notify(msg: String, col: Color = Color(1.0, 0.9, 0.4)) -> void:
	var hud = _hud()
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(msg, col)
	else:
		print("[MuItemPicker] " + msg)

func _on_take_item() -> void:
	if player == null:
		_notify("Lỗi: Không tìm thấy nhân vật người chơi!", Color.RED)
		return
	if _selected_info.is_empty():
		_notify("Vui lòng chọn 1 món đồ trước!", Color.ORANGE)
		return

	var it := _get_current_configured_item()
	var dname := MuItemsRes.display_name(it)

	# Kiểm tra túi đồ có chỗ trống không
	var ok = player.inv_add(it)
	if not ok:
		_notify("Túi đồ đã đầy! Hãy dọn bớt đồ trong túi trước.", Color.RED)
		return

	# Phát âm thanh ngọc rơi KENG thần thánh
	MuAudioManagerRes.play_jewel_drop()

	_notify("Đã nhận: %s!" % dname, Color(0.2, 1.0, 0.5))

	# Mở túi đồ cho người chơi nhìn thấy
	var hud = _hud()
	if hud and hud.inventory_window:
		hud.inventory_window.visible = true
		hud.inventory_window.update_display()

func _on_equip_item() -> void:
	if player == null or _selected_info.is_empty():
		return

	var it := _get_current_configured_item()
	var slot := MuItemsRes.equip_slot(it)
	if slot == "":
		_notify("Món đồ này không thể mặc trực tiếp lên người!", Color.ORANGE)
		return

	var g := int(it["group"])
	if slot == "ring":
		if player.equipment.has("ring_right") and not player.equipment.has("ring_left"):
			slot = "ring_left"
		else:
			slot = "ring_right"
	elif slot == "right" and player.equipment.has("right") and not player.equipment.has("left") and g <= 5:
		slot = "left"

	player.equipment[slot] = it
	player.rebuild_model()
	player.inventory_changed.emit()
	MuAudioManagerRes.play_jewel_drop()
	_notify("Đã trang bị %s lên nhân vật!" % MuItemsRes.display_name(it), Color(0.3, 0.9, 1.0))

	var hud = _hud()
	if hud and hud.inventory_window:
		hud.inventory_window.update_display()

func _on_take_full_set() -> void:
	if player == null or _selected_info.is_empty():
		return

	var g_orig := int(_selected_info.get("group", 0))
	if g_orig < 7 or g_orig > 11:
		_notify("Chỉ có thể lấy cả bộ đối với Mũ, Áo, Quần, Găng, Giày!", Color.ORANGE)
		return

	var num := int(_selected_info.get("number", 0))
	var lv := int(_level_slider.value)
	var exc := _exc_check.button_pressed
	var purple := _purple_check.button_pressed if _purple_check else false
	var ancient := _ancient_check.button_pressed if _ancient_check else false
	var socket := _socket_check.button_pressed if _socket_check else false
	var harmony := _harmony_check.button_pressed if _harmony_check else false
	var luck := _luck_check.button_pressed
	var skill := _skill_check.button_pressed
	var opt := _opt_option.selected

	var added_count := 0
	# Nhóm 7 (Mũ), 8 (Áo), 9 (Quần), 10 (Găng), 11 (Giày)
	for g in [7, 8, 9, 10, 11]:
		var it := MuItemsRes.make(g, num, lv, {
			"excellent": exc,
			"purple": purple,
			"option_380": purple,
			"ancient": ancient,
			"socket": socket,
			"harmony": harmony,
			"luck": luck,
			"skill": skill,
			"opt": opt
		})
		if player.inv_add(it):
			added_count += 1

	if added_count > 0:
		MuAudioManagerRes.play_jewel_drop()
		_notify("Đã nhận trọn bộ Set (%d/5 món) vào túi đồ!" % added_count, Color(0.2, 1.0, 0.5))
		var hud = _hud()
		if hud and hud.inventory_window:
			hud.inventory_window.visible = true
			hud.inventory_window.update_display()
	else:
		_notify("Túi đồ đã đầy, không thể thêm trọn bộ!", Color.RED)

func _on_take_event_bundle() -> void:
	if player == null or _selected_info.is_empty():
		return
	var it := _get_current_configured_item()
	var ev_id := MuItemsRes.event_category_id(it)
	if ev_id == 0:
		return
	var items := MuItemsRes.get_event_bundle_items(ev_id)
	var count := 0
	for item in items:
		if player.inv_add(item):
			count += 1
	if count > 0:
		MuAudioManagerRes.play_jewel_drop()
		_notify("Đã nhận %d vật phẩm sự kiện vào túi đồ!" % count, Color(0.2, 1.0, 0.5))
		var hud = _hud()
		if hud and hud.inventory_window:
			hud.inventory_window.visible = true
			hud.inventory_window.update_display()
	else:
		_notify("Túi đồ đã đầy, không thể thêm vật phẩm sự kiện!", Color.RED)

func _on_take_all_events() -> void:
	if player == null:
		return
	var items := MuItemsRes.get_all_event_tickets()
	var count := 0
	for item in items:
		if player.inv_add(item):
			count += 1
	if count > 0:
		MuAudioManagerRes.play_jewel_drop()
		_notify("⭐ ĐÃ NHẬN TRỌN BỘ %d VÉ SỰ KIỆN TOÀN GAME VÀO TÚI ĐỒ!" % count, Color(1.0, 0.85, 0.2))
		var hud = _hud()
		if hud and hud.inventory_window:
			hud.inventory_window.visible = true
			hud.inventory_window.update_display()
	else:
		_notify("Túi đồ đã đầy, không thể thêm vé sự kiện!", Color.RED)

func _on_get_point() -> void:
	if player == null:
		return
	player.gm_add_points(5000)
	var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
	if stats_win and stats_win.has_method("update_stats"):
		stats_win.update_stats()
	MuAudioManagerRes.play_coin_pickup()
	_notify("✨ GM: Đã nhận +5,000 Điểm Point (Bấm phím C để nâng)!", Color(1.0, 0.9, 0.3))

func _on_toggle_god_mode() -> void:
	if player == null:
		return
	var active = player.toggle_god_mode()
	_update_gm_god_button()
	var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
	if stats_win and stats_win.has_method("update_stats"):
		stats_win.update_stats()
	if active:
		_notify("🛡️ GM: ĐÃ BẬT BẤT TỬ (Không bao giờ hết Máu & Mana)!", Color(0.2, 1.0, 0.4))
	else:
		_notify("🛡️ GM: ĐÃ TẮT BẤT TỬ.", Color(1.0, 0.7, 0.4))

func _update_gm_god_button() -> void:
	if not _btn_god_mode or not player:
		return
	if player.infinite_hp_mp:
		_btn_god_mode.text = "🛡️ BẤT TỬ HP/MP: ĐANG BẬT"
		_btn_god_mode.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		_btn_god_mode.text = "🛡️ BẤT TỬ HP/MP: ĐANG TẮT"
		_btn_god_mode.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

func _on_get_zen() -> void:
	if player == null:
		return
	player.add_zen(10000000)
	MuAudioManagerRes.play_coin_pickup()
	_notify("Đã nhận thêm 10,000,000 Zen!", Color(1.0, 0.85, 0.3))

func _on_learn_class_skills() -> void:
	if player == null:
		_notify("Lỗi: Không tìm thấy nhân vật!", Color.RED)
		return
	var n = player.learn_all_skills(false)
	var class_names := ["Phù Thủy (DW)", "Chiến Binh (DK)", "Tiên Nữ (Elf)", "Đấu Sĩ (MG)", "Chúa Tể (DL)", "Thuật Sĩ (SUM)", "Thiết Binh (RF)"]
	var cname: String = class_names[player.char_class] if player.char_class >= 0 and player.char_class < class_names.size() else "Class"
	_notify("⚡ GM: Đã mở %d skill cho %s!" % [player.learned_skills.size(), cname], Color(1.0, 0.9, 0.2))

func _on_learn_all_class_skills() -> void:
	if player == null:
		_notify("Lỗi: Không tìm thấy nhân vật!", Color.RED)
		return
	var n = player.learn_all_skills(true)
	_notify("🌟 GM: Đã mở TOÀN BỘ %d kỹ năng game!" % player.learned_skills.size(), Color(0.4, 1.0, 0.4))
