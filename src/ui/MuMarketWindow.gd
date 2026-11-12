extends Control
class_name MuMarketWindow

## Sàn Giao Dịch Buôn Bán Online (Online Market / Chợ Trời Toàn Máy Chủ)
## - Cho phép người chơi mua bán trao đổi vật phẩm mọi lúc mọi nơi
## - Không cần phải đứng AFK rao bán hoặc bày shop cá nhân trong các map thành
## - 3 Tab chức năng:
##   1. [ SÀN GIAO DỊCH ] - Xem danh sách đồ đang bán, tìm kiếm theo tên/loại, mua đồ trực tiếp
##   2. [ ĐĂNG BÁN ĐỒ ]   - Chọn đồ từ túi đồ cá nhân, định giá Zen/Ngọc và niêm yết lên chợ
##   3. [ GIAN HÀNG CỦA TÔI ] - Quản lý đồ đang bán, hủy niêm yết nhận lại đồ, nhận tiền Zen đã bán

signal closed

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")

@export var player: MuPlayer = null

# UI Nodes chính
var panel_container: Panel
var btn_close: Button
var tab_container: HBoxContainer
var tab_btn_market: Button
var tab_btn_sell: Button
var tab_btn_my_shop: Button

# Body Views cho 3 tab
var view_market: Control
var view_sell: Control
var view_my_shop: Control
var current_tab: int = 0 # 0: Market, 1: Sell, 2: My Shop

# Tab 1: Sàn Giao Dịch
var market_search_input: LineEdit
var market_filter_category: String = "all"
var market_scroll: ScrollContainer
var market_list_container: VBoxContainer
var lbl_market_count: Label

# Tab 2: Đăng Bán
var sell_inventory_scroll: ScrollContainer
var sell_inventory_grid: GridContainer
var sell_selected_item: Dictionary = {}
var sell_preview_icon: TextureRect
var sell_lbl_name: Label
var sell_lbl_details: Label
var sell_price_input: LineEdit
var sell_btn_confirm: Button

# Tab 3: Gian Hàng Của Tôi
var my_shop_scroll: ScrollContainer
var my_shop_list_container: VBoxContainer
var lbl_my_shop_status: Label

# Dữ liệu thị trường (Market Listings)
static var market_items: Array = []
static var is_data_initialized: bool = false
const MARKET_SAVE_PATH := "user://mu_market_listings.json"

const WINDOW_SIZE := Vector2(820, 570)

func _ready() -> void:
	z_index = 45
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_init_market_data()
	_build_ui()
	_on_viewport_resized()
	if is_inside_tree():
		get_viewport().size_changed.connect(_on_viewport_resized)

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player and not player.inventory_changed.is_connected(_on_inventory_changed):
		player.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if visible:
		_refresh_current_tab()

func _on_viewport_resized() -> void:
	var vs = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if vs.x <= 10.0 or vs.y <= 10.0:
		vs = Vector2(1280, 720)
	size = vs
	custom_minimum_size = vs
	if panel_container:
		panel_container.position = (vs - panel_container.size) * 0.5

# -------------------------------------------------------------------------
# Khởi Tạo & Lưu Trữ Dữ Liệu Chợ Online
# -------------------------------------------------------------------------
func _init_market_data() -> void:
	if is_data_initialized and not market_items.is_empty():
		return

	if FileAccess.file_exists(MARKET_SAVE_PATH):
		var text = FileAccess.get_file_as_string(MARKET_SAVE_PATH)
		var json = JSON.parse_string(text)
		if json is Array:
			market_items = json
			is_data_initialized = true
			return

	# Dữ liệu khởi tạo mặc định phong phú chuẩn MU Online
	market_items.clear()
	_add_seed_listing("Kiếm Rồng +11", 0, 19, 11, true, true, 4, 15000000, "BladeMaster_HN", "weapon")
	_add_seed_listing("Đao Quyền Năng +13", 0, 22, 13, true, true, 7, 35000000, "DragonKnight_SG", "weapon")
	_add_seed_listing("Gậy Thần Ma +11", 5, 12, 11, true, true, 4, 22000000, "ArchMage_Vip", "weapon")
	_add_seed_listing("Nỏ Rồng Tuyệt Đẹp +9", 4, 8, 9, true, true, 3, 12000000, "MuseElf_Lover", "weapon")
	_add_seed_listing("Quyền Trượng Đại Vương +11", 2, 13, 11, true, true, 4, 18000000, "LordOfLorencia", "weapon")

	_add_seed_listing("Áo Thần Long +11", 8, 17, 11, true, true, 4, 16000000, "KnightLegend", "armor")
	_add_seed_listing("Mũ Ma Thuật +11", 7, 16, 11, true, false, 0, 9500000, "SoulMaster_99", "armor")
	_add_seed_listing("Quần Giai Nhân +9", 9, 15, 9, true, true, 3, 8000000, "ElfPrincess", "armor")
	_add_seed_listing("Găng Hắc Vương +11", 10, 21, 11, true, true, 4, 14000000, "DarkLord_Vip", "armor")
	_add_seed_listing("Giày Phượng Hoàng +13", 11, 28, 13, true, true, 7, 42000000, "Top1_BladeKnight", "armor")

	_add_seed_listing("Cánh Rồng (Wing 2 DK) +9", 12, 5, 9, true, false, 0, 20000000, "FlyToSky", "wings")
	_add_seed_listing("Cánh Linh Hồn (Wing 2 DW) +11", 12, 4, 11, true, true, 4, 28000000, "MysticWings", "wings")
	_add_seed_listing("Cánh Chiến Thần (Wing 3 DK) +11", 12, 36, 11, true, true, 4, 85000000, "GrandMaster_MU", "wings")

	_add_seed_listing("Cụm Ngọc Ước Nguyện (10 viên Bless)", 14, 13, 0, false, false, 0, 10000000, "JewelTrader", "jewel", 10)
	_add_seed_listing("Cụm Ngọc Tâm Linh (10 viên Soul)", 14, 14, 0, false, false, 0, 7500000, "JewelTrader", "jewel", 10)
	_add_seed_listing("Ngọc Hỗn Nguyên (Chaos) x10", 12, 15, 0, false, false, 0, 3000000, "LootMaster", "jewel", 10)
	_add_seed_listing("Ngọc Sinh Mệnh (Life) x5", 14, 16, 0, false, false, 0, 5000000, "BossHunter", "jewel", 5)
	_add_seed_listing("Đá Tạo Hóa (Harmony) x5", 14, 42, 0, false, false, 0, 8000000, "KanturuMiner", "jewel", 5)

	_add_seed_listing("Nhẫn Phép Thuật +1 (Ring of Magic)", 13, 8, 1, false, false, 0, 2500000, "LuckyDrop", "other")
	_add_seed_listing("Dây Chuyền Ánh Sáng (Pendant of Lightning)", 13, 12, 2, true, false, 0, 4500000, "StormLord", "other")
	_add_seed_listing("Chiến Mã Hoàng Gia (Dark Horse)", 13, 4, 50, false, false, 0, 25000000, "LordRider", "other")

	_save_market_data()
	is_data_initialized = true

func _add_seed_listing(item_title: String, g: int, n: int, lvl: int, has_luck: bool, has_skill: bool, exc_opt: int, price_zen: int, seller: String, cat: String, count: int = 1) -> void:
	var item_dict = MuItemsRes.make(g, n, lvl)
	item_dict["luck"] = has_luck
	item_dict["skill"] = has_skill
	item_dict["opt"] = 4 if lvl >= 7 else 0
	item_dict["count"] = count
	if exc_opt > 0:
		item_dict["exc"] = exc_opt

	market_items.append({
		"id": "list_%d_%d" % [Time.get_ticks_msec(), randi() % 100000],
		"title": item_title,
		"item": item_dict,
		"price": price_zen,
		"seller": seller,
		"category": cat,
		"time": "Vừa đăng",
		"sold": false,
		"claimed": false
	})

func _save_market_data() -> void:
	var f = FileAccess.open(MARKET_SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(market_items, "\t"))
		f.close()

# -------------------------------------------------------------------------
# Xây Dựng Giao Diện
# -------------------------------------------------------------------------
func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	# 1. Dimmer nền tối
	var dimmer = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.color = Color(0, 0, 0, 0.65)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(dimmer)

	# 2. Khung chính trung tâm
	panel_container = Panel.new()
	panel_container.name = "MarketPanel"
	panel_container.size = WINDOW_SIZE
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb_main = StyleBoxFlat.new()
	sb_main.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	sb_main.border_width_left = 2
	sb_main.border_width_top = 2
	sb_main.border_width_right = 2
	sb_main.border_width_bottom = 2
	sb_main.border_color = Color(0.75, 0.62, 0.35, 0.9)
	sb_main.corner_radius_top_left = 6
	sb_main.corner_radius_top_right = 6
	sb_main.corner_radius_bottom_left = 6
	sb_main.corner_radius_bottom_right = 6
	sb_main.shadow_color = Color(0, 0, 0, 0.75)
	sb_main.shadow_size = 10
	panel_container.add_theme_stylebox_override("panel", sb_main)
	add_child(panel_container)

	# 3. Thanh tiêu đề (Header Bar)
	var header = Panel.new()
	header.position = Vector2(4, 4)
	header.size = Vector2(WINDOW_SIZE.x - 8, 38)
	var sb_hdr = StyleBoxFlat.new()
	sb_hdr.bg_color = Color(0.1, 0.13, 0.18, 0.95)
	sb_hdr.border_width_bottom = 1
	sb_hdr.border_color = Color(0.6, 0.5, 0.28, 0.8)
	header.add_theme_stylebox_override("panel", sb_hdr)
	panel_container.add_child(header)

	var lbl_title = Label.new()
	lbl_title.position = Vector2(16, 8)
	lbl_title.size = Vector2(480, 22)
	lbl_title.text = "🏛️ SÀN GIAO DỊCH BUÔN BÁN ONLINE — CHỢ TRỜI MU ONLINE"
	lbl_title.add_theme_font_size_override("font_size", 13)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	lbl_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_title.add_theme_constant_override("outline_size", 3)
	header.add_child(lbl_title)

	# Nút đóng X
	btn_close = Button.new()
	btn_close.position = Vector2(WINDOW_SIZE.x - 42, 6)
	btn_close.size = Vector2(28, 26)
	btn_close.text = "X"
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.add_theme_color_override("font_color", Color(1, 0.8, 0.8))
	btn_close.tooltip_text = "Đóng cửa sổ (ESC)"
	var sb_cls = StyleBoxFlat.new()
	sb_cls.bg_color = Color(0.35, 0.12, 0.12, 0.9)
	sb_cls.border_width_left = 1
	sb_cls.border_width_top = 1
	sb_cls.border_width_right = 1
	sb_cls.border_width_bottom = 1
	sb_cls.border_color = Color(0.8, 0.3, 0.3, 0.9)
	sb_cls.corner_radius_top_left = 3
	sb_cls.corner_radius_top_right = 3
	sb_cls.corner_radius_bottom_left = 3
	sb_cls.corner_radius_bottom_right = 3
	btn_close.add_theme_stylebox_override("normal", sb_cls)
	btn_close.pressed.connect(close)
	header.add_child(btn_close)

	# 4. Hàng Nút Chuyển Tab
	tab_container = HBoxContainer.new()
	tab_container.position = Vector2(14, 48)
	tab_container.size = Vector2(WINDOW_SIZE.x - 28, 32)
	tab_container.add_theme_constant_override("separation", 6)
	panel_container.add_child(tab_container)

	tab_btn_market = _create_tab_button("🛒 SÀN GIAO DỊCH (MUA HÀNG)", 0)
	tab_btn_sell = _create_tab_button("🏷️ ĐĂNG BÁN VẬT PHẨM", 1)
	tab_btn_my_shop = _create_tab_button("📦 GIAN HÀNG CỦA TÔI", 2)
	tab_container.add_child(tab_btn_market)
	tab_container.add_child(tab_btn_sell)
	tab_container.add_child(tab_btn_my_shop)

	# 5. Khu vực nội dung các Tab
	var content_rect = Rect2(12, 86, WINDOW_SIZE.x - 24, WINDOW_SIZE.y - 128)

	view_market = Control.new()
	view_market.position = content_rect.position
	view_market.size = content_rect.size
	panel_container.add_child(view_market)
	_build_market_view(view_market)

	view_sell = Control.new()
	view_sell.position = content_rect.position
	view_sell.size = content_rect.size
	panel_container.add_child(view_sell)
	_build_sell_view(view_sell)

	view_my_shop = Control.new()
	view_my_shop.position = content_rect.position
	view_my_shop.size = content_rect.size
	panel_container.add_child(view_my_shop)
	_build_my_shop_view(view_my_shop)

	# 6. Thanh Footer trạng thái & Tiền Zen
	var footer = Panel.new()
	footer.position = Vector2(8, WINDOW_SIZE.y - 36)
	footer.size = Vector2(WINDOW_SIZE.x - 16, 28)
	var sb_ft = StyleBoxFlat.new()
	sb_ft.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb_ft.border_width_top = 1
	sb_ft.border_color = Color(0.4, 0.35, 0.25, 0.7)
	footer.add_theme_stylebox_override("panel", sb_ft)
	panel_container.add_child(footer)

	var lbl_help = Label.new()
	lbl_help.position = Vector2(10, 5)
	lbl_help.size = Vector2(500, 18)
	lbl_help.text = "• Mua bán tự động toàn server không cần AFK | Vật phẩm mua sẽ tự động vào Túi Đồ | Phím: P / ESC"
	lbl_help.add_theme_font_size_override("font_size", 10)
	lbl_help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.8))
	footer.add_child(lbl_help)

	var lbl_my_zen = Label.new()
	lbl_my_zen.name = "MyZenLabel"
	lbl_my_zen.position = Vector2(WINDOW_SIZE.x - 260, 5)
	lbl_my_zen.size = Vector2(240, 18)
	lbl_my_zen.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_my_zen.add_theme_font_size_override("font_size", 11)
	lbl_my_zen.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	lbl_my_zen.text = "Số dư Zen: %s" % _format_number(player.zen if player else 10000)
	footer.add_child(lbl_my_zen)

	_switch_tab(0)

func _create_tab_button(text: String, tab_idx: int) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 30)
	btn.add_theme_font_size_override("font_size", 11)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func(): _switch_tab(tab_idx))
	return btn

func _switch_tab(tab_idx: int) -> void:
	current_tab = tab_idx
	view_market.visible = (tab_idx == 0)
	view_sell.visible = (tab_idx == 1)
	view_my_shop.visible = (tab_idx == 2)

	_update_tab_button_style(tab_btn_market, tab_idx == 0)
	_update_tab_button_style(tab_btn_sell, tab_idx == 1)
	_update_tab_button_style(tab_btn_my_shop, tab_idx == 2)

	_refresh_current_tab()

func _update_tab_button_style(btn: Button, active: bool) -> void:
	var sb = StyleBoxFlat.new()
	if active:
		sb.bg_color = Color(0.24, 0.28, 0.38, 0.95)
		sb.border_width_bottom = 3
		sb.border_color = Color(1.0, 0.85, 0.3, 1.0)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	else:
		sb.bg_color = Color(0.1, 0.12, 0.16, 0.8)
		sb.border_width_bottom = 1
		sb.border_color = Color(0.3, 0.35, 0.45, 0.6)
		btn.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	btn.add_theme_stylebox_override("normal", sb)

func _refresh_current_tab() -> void:
	# Cập nhật nhãn Zen
	var zen_lbl = panel_container.find_child("MyZenLabel", true, false)
	if zen_lbl is Label and player:
		zen_lbl.text = "Số dư Zen: %s" % _format_number(player.zen)

	match current_tab:
		0: _render_market_list()
		1: _render_sell_inventory()
		2: _render_my_shop_list()

# -------------------------------------------------------------------------
# TAB 1: SÀN GIAO DỊCH (MUA HÀNG)
# -------------------------------------------------------------------------
func _build_market_view(parent: Control) -> void:
	# Thanh tìm kiếm & bộ lọc thể loại
	var top_bar = Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(parent.size.x, 34)
	var sb_tb = StyleBoxFlat.new()
	sb_tb.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	sb_tb.corner_radius_top_left = 4
	sb_tb.corner_radius_top_right = 4
	top_bar.add_theme_stylebox_override("panel", sb_tb)
	parent.add_child(top_bar)

	var lbl_s = Label.new()
	lbl_s.position = Vector2(10, 8)
	lbl_s.text = "🔍 Tìm kiếm:"
	lbl_s.add_theme_font_size_override("font_size", 10)
	lbl_s.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	top_bar.add_child(lbl_s)

	market_search_input = LineEdit.new()
	market_search_input.position = Vector2(80, 5)
	market_search_input.size = Vector2(160, 24)
	market_search_input.placeholder_text = "Nhập tên vật phẩm..."
	market_search_input.add_theme_font_size_override("font_size", 10)
	market_search_input.text_changed.connect(func(_t): _render_market_list())
	top_bar.add_child(market_search_input)

	# Nút phân loại danh mục
	var cat_hbox = HBoxContainer.new()
	cat_hbox.position = Vector2(250, 5)
	cat_hbox.size = Vector2(parent.size.x - 260, 24)
	cat_hbox.add_theme_constant_override("separation", 4)
	top_bar.add_child(cat_hbox)

	var cats = [
		{"id": "all", "label": "Tất cả"},
		{"id": "weapon", "label": "Vũ khí"},
		{"id": "armor", "label": "Giáp trụ"},
		{"id": "wings", "label": "Cánh"},
		{"id": "jewel", "label": "Ngọc quý"},
		{"id": "other", "label": "Khác"},
	]
	for c in cats:
		var b = Button.new()
		b.text = c["label"]
		b.add_theme_font_size_override("font_size", 10)
		b.custom_minimum_size = Vector2(60, 22)
		b.pressed.connect(func():
			market_filter_category = c["id"]
			_render_market_list())
		cat_hbox.add_child(b)

	# Danh sách cuộn các món hàng
	market_scroll = ScrollContainer.new()
	market_scroll.position = Vector2(0, 38)
	market_scroll.size = Vector2(parent.size.x, parent.size.y - 38)
	market_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(market_scroll)

	market_list_container = VBoxContainer.new()
	market_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_list_container.add_theme_constant_override("separation", 4)
	market_scroll.add_child(market_list_container)

func _render_market_list() -> void:
	if not market_list_container:
		return
	for c in market_list_container.get_children():
		c.queue_free()

	var search_q = market_search_input.text.strip_edges().to_lower() if market_search_input else ""
	var my_name = player.character_name if player else ""

	var count_visible = 0
	for listing in market_items:
		if listing.get("sold", false):
			continue
		# Không hiển thị hàng do chính mình đăng ở tab Mua
		if listing.get("seller", "") == my_name and my_name != "":
			continue

		var title = str(listing.get("title", "")).to_lower()
		var cat = str(listing.get("category", "other"))
		if market_filter_category != "all" and cat != market_filter_category:
			continue
		if search_q != "" and not title.contains(search_q):
			continue

		var row = _create_market_item_row(listing)
		market_list_container.add_child(row)
		count_visible += 1

	if count_visible == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "Không tìm thấy vật phẩm nào đang bán phù hợp với tiêu chí tìm kiếm."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.custom_minimum_size = Vector2(0, 100)
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
		market_list_container.add_child(empty_lbl)

func _create_market_item_row(listing: Dictionary) -> Panel:
	var row = Panel.new()
	row.custom_minimum_size = Vector2(0, 48)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.9)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.25, 0.3, 0.4, 0.7)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.offset_left = 8
	hbox.offset_right = -8
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var item_data: Dictionary = listing.get("item", {})
	var icon_tex: Texture2D = MuItemIconRes.catalog_icon(get_tree(), item_data, 38) if is_inside_tree() else null

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(38, 38)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if icon_tex:
		icon_rect.texture = icon_tex
	hbox.add_child(icon_rect)

	# Thông tin tên & người bán
	var vb_info = VBoxContainer.new()
	vb_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb_info.add_theme_constant_override("separation", 2)
	hbox.add_child(vb_info)

	var lbl_name = Label.new()
	lbl_name.text = str(listing.get("title", "Vật phẩm"))
	lbl_name.add_theme_font_size_override("font_size", 11)
	lbl_name.add_theme_color_override("font_color", MuItemsRes.name_color(item_data))
	lbl_name.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_name.add_theme_constant_override("outline_size", 2)
	vb_info.add_child(lbl_name)

	var lbl_seller = Label.new()
	lbl_seller.text = "Người bán: %s  •  Thời gian: %s" % [str(listing.get("seller", "Ẩn danh")), str(listing.get("time", "Hôm nay"))]
	lbl_seller.add_theme_font_size_override("font_size", 9)
	lbl_seller.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	vb_info.add_child(lbl_seller)

	# Giá bán
	var price = int(listing.get("price", 0))
	var lbl_price = Label.new()
	lbl_price.text = "💰 %s Zen" % _format_number(price)
	lbl_price.custom_minimum_size = Vector2(150, 0)
	lbl_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_price.add_theme_font_size_override("font_size", 12)
	lbl_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lbl_price.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_price.add_theme_constant_override("outline_size", 2)
	hbox.add_child(lbl_price)

	# Nút Mua
	var btn_buy = Button.new()
	btn_buy.text = "Mua Ngay"
	btn_buy.custom_minimum_size = Vector2(84, 28)
	btn_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_buy.add_theme_font_size_override("font_size", 11)
	var sb_b = StyleBoxFlat.new()
	sb_b.bg_color = Color(0.2, 0.42, 0.25, 0.95)
	sb_b.border_width_left = 1
	sb_b.border_width_top = 1
	sb_b.border_width_right = 1
	sb_b.border_width_bottom = 1
	sb_b.border_color = Color(0.45, 0.85, 0.5, 0.9)
	sb_b.corner_radius_top_left = 3
	sb_b.corner_radius_top_right = 3
	sb_b.corner_radius_bottom_left = 3
	sb_b.corner_radius_bottom_right = 3
	btn_buy.add_theme_stylebox_override("normal", sb_b)
	btn_buy.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95))
	btn_buy.pressed.connect(func(): _on_buy_item_clicked(listing))
	hbox.add_child(btn_buy)

	return row

func _on_buy_item_clicked(listing: Dictionary) -> void:
	if not player:
		return
	var price = int(listing.get("price", 0))
	if player.zen < price:
		_notify("Không đủ Zen! Bạn cần %s Zen để mua món này." % _format_number(price), Color(1.0, 0.4, 0.4))
		return

	var item_data: Dictionary = listing.get("item", {}).duplicate(true)
	# Thêm vào túi đồ
	var added = player.inv_add(item_data)
	if not added:
		_notify("Túi đồ của bạn đã đầy! Hãy dọn chỗ trống trước khi mua hàng.", Color(1.0, 0.4, 0.4))
		return

	# Trừ Zen người mua
	player.add_zen(-price)
	listing["sold"] = true
	_save_market_data()

	if MuAudioManager:
		MuAudioManager.play_ui_click()

	_notify("★ Mua thành công [%s] với giá %s Zen!" % [listing.get("title", ""), _format_number(price)], Color(0.3, 0.95, 0.4))
	_refresh_current_tab()

# -------------------------------------------------------------------------
# TAB 2: ĐĂNG BÁN VẬT PHẨM (TỪ TÚI ĐỒ CÁ NHÂN)
# -------------------------------------------------------------------------
func _build_sell_view(parent: Control) -> void:
	var hbox = HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	# Cột Trái: Danh sách đồ trong Túi Đồ
	var left_panel = Panel.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_lp = StyleBoxFlat.new()
	sb_lp.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb_lp.border_width_left = 1
	sb_lp.border_width_top = 1
	sb_lp.border_width_right = 1
	sb_lp.border_width_bottom = 1
	sb_lp.border_color = Color(0.3, 0.35, 0.45, 0.8)
	sb_lp.corner_radius_top_left = 4
	sb_lp.corner_radius_top_right = 4
	sb_lp.corner_radius_bottom_left = 4
	sb_lp.corner_radius_bottom_right = 4
	left_panel.add_theme_stylebox_override("panel", sb_lp)
	hbox.add_child(left_panel)

	var lbl_inv_title = Label.new()
	lbl_inv_title.position = Vector2(10, 8)
	lbl_inv_title.text = "🎒 VẬT PHẨM TRONG TÚI ĐỒ (CHỌN MÓN ĐỂ ĐĂNG BÁN)"
	lbl_inv_title.add_theme_font_size_override("font_size", 11)
	lbl_inv_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	left_panel.add_child(lbl_inv_title)

	sell_inventory_scroll = ScrollContainer.new()
	sell_inventory_scroll.position = Vector2(8, 32)
	sell_inventory_scroll.size = Vector2(460, 395)
	sell_inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(sell_inventory_scroll)

	sell_inventory_grid = GridContainer.new()
	sell_inventory_grid.columns = 2
	sell_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_inventory_grid.add_theme_constant_override("h_separation", 6)
	sell_inventory_grid.add_theme_constant_override("v_separation", 6)
	sell_inventory_scroll.add_child(sell_inventory_grid)

	# Cột Phải: Chi tiết món đồ được chọn & Định giá bán
	var right_panel = Panel.new()
	right_panel.custom_minimum_size = Vector2(280, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_rp = StyleBoxFlat.new()
	sb_rp.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	sb_rp.border_width_left = 1
	sb_rp.border_width_top = 1
	sb_rp.border_width_right = 1
	sb_rp.border_width_bottom = 1
	sb_rp.border_color = Color(0.45, 0.4, 0.25, 0.8)
	sb_rp.corner_radius_top_left = 4
	sb_rp.corner_radius_top_right = 4
	sb_rp.corner_radius_bottom_left = 4
	sb_rp.corner_radius_bottom_right = 4
	right_panel.add_theme_stylebox_override("panel", sb_rp)
	hbox.add_child(right_panel)

	var vb_right = VBoxContainer.new()
	vb_right.anchors_preset = Control.PRESET_FULL_RECT
	vb_right.offset_left = 12
	vb_right.offset_top = 12
	vb_right.offset_right = -12
	vb_right.offset_bottom = -12
	vb_right.add_theme_constant_override("separation", 10)
	right_panel.add_child(vb_right)

	var lbl_det_title = Label.new()
	lbl_det_title.text = "🏷️ THIẾT LẬP GIÁ BÁN"
	lbl_det_title.add_theme_font_size_override("font_size", 12)
	lbl_det_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl_det_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb_right.add_child(lbl_det_title)

	sell_preview_icon = TextureRect.new()
	sell_preview_icon.custom_minimum_size = Vector2(64, 64)
	sell_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sell_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sell_preview_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb_right.add_child(sell_preview_icon)

	sell_lbl_name = Label.new()
	sell_lbl_name.text = "Chưa chọn vật phẩm"
	sell_lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_lbl_name.add_theme_font_size_override("font_size", 11)
	sell_lbl_name.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vb_right.add_child(sell_lbl_name)

	sell_lbl_details = Label.new()
	sell_lbl_details.text = "Hãy nhấp vào 1 món đồ ở danh sách bên trái để tiến hành đăng bán lên Chợ Online."
	sell_lbl_details.autowrap_mode = TextServer.AUTOWRAP_WORD
	sell_lbl_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_lbl_details.add_theme_font_size_override("font_size", 9)
	sell_lbl_details.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	vb_right.add_child(sell_lbl_details)

	var lbl_prc_tag = Label.new()
	lbl_prc_tag.text = "Giá bán mong muốn (Zen):"
	lbl_prc_tag.add_theme_font_size_override("font_size", 10)
	lbl_prc_tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vb_right.add_child(lbl_prc_tag)

	sell_price_input = LineEdit.new()
	sell_price_input.placeholder_text = "Ví dụ: 5000000"
	sell_price_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_price_input.add_theme_font_size_override("font_size", 11)
	vb_right.add_child(sell_price_input)

	sell_btn_confirm = Button.new()
	sell_btn_confirm.text = "ĐĂNG BÁN LÊN CHỢ"
	sell_btn_confirm.custom_minimum_size = Vector2(0, 34)
	sell_btn_confirm.add_theme_font_size_override("font_size", 11)
	var sb_cf = StyleBoxFlat.new()
	sb_cf.bg_color = Color(0.2, 0.42, 0.25, 0.95)
	sb_cf.border_width_left = 1
	sb_cf.border_width_top = 1
	sb_cf.border_width_right = 1
	sb_cf.border_width_bottom = 1
	sb_cf.border_color = Color(0.45, 0.85, 0.5, 0.9)
	sb_cf.corner_radius_top_left = 4
	sb_cf.corner_radius_top_right = 4
	sb_cf.corner_radius_bottom_left = 4
	sb_cf.corner_radius_bottom_right = 4
	sell_btn_confirm.add_theme_stylebox_override("normal", sb_cf)
	sell_btn_confirm.add_theme_color_override("font_color", Color(1, 1, 1))
	sell_btn_confirm.pressed.connect(_on_confirm_sell_clicked)
	vb_right.add_child(sell_btn_confirm)

func _render_sell_inventory() -> void:
	if not sell_inventory_grid:
		return
	for c in sell_inventory_grid.get_children():
		c.queue_free()

	if not player or player.inventory.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Túi đồ của bạn đang trống."
		sell_inventory_grid.add_child(empty_lbl)
		return

	for it in player.inventory:
		if it is Dictionary and not it.is_empty():
			var btn = _create_inventory_item_button(it)
			sell_inventory_grid.add_child(btn)

func _create_inventory_item_button(it: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(220, 42)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.2, 0.9)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.35, 0.45, 0.7)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", sb)

	var hbox = HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.offset_left = 4
	hbox.offset_right = -4
	hbox.add_theme_constant_override("separation", 6)
	btn.add_child(hbox)

	var icon_tex: Texture2D = MuItemIconRes.catalog_icon(get_tree(), it, 32) if is_inside_tree() else null
	var irect = TextureRect.new()
	irect.custom_minimum_size = Vector2(32, 32)
	irect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	irect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	irect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon_tex:
		irect.texture = icon_tex
	hbox.add_child(irect)

	var lbl = Label.new()
	lbl.text = MuItemsRes.display_name(it)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", MuItemsRes.name_color(it))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl)

	btn.pressed.connect(func(): _select_sell_item(it))
	return btn

func _select_sell_item(it: Dictionary) -> void:
	sell_selected_item = it
	sell_lbl_name.text = MuItemsRes.display_name(it)
	sell_lbl_name.add_theme_color_override("font_color", MuItemsRes.name_color(it))
	var icon_tex: Texture2D = MuItemIconRes.catalog_icon(get_tree(), it, 48) if is_inside_tree() else null
	sell_preview_icon.texture = icon_tex

	var lvl = int(it.get("level", 0))
	var has_luck = bool(it.get("luck", false))
	var has_skill = bool(it.get("skill", false))
	sell_lbl_details.text = "Cấp độ: +%d | May mắn: %s | Kỹ năng: %s" % [lvl, "Có" if has_luck else "Không", "Có" if has_skill else "Không"]

	# Đề xuất giá mặc định
	var def_price = 1000000 + lvl * 500000
	if sell_price_input.text.is_empty():
		sell_price_input.text = str(def_price)

func _on_confirm_sell_clicked() -> void:
	if sell_selected_item.is_empty() or not player:
		_notify("Vui lòng chọn 1 món đồ từ danh sách bên trái để đăng bán!", Color(1.0, 0.4, 0.4))
		return

	var str_price = sell_price_input.text.strip_edges()
	if not str_price.is_valid_int() or str_price.to_int() <= 0:
		_notify("Giá bán không hợp lệ! Vui lòng nhập số Zen lớn hơn 0.", Color(1.0, 0.4, 0.4))
		return

	var price = str_price.to_int()
	var it_to_sell = sell_selected_item.duplicate(true)

	# Xóa khỏi túi đồ của người chơi
	player.inv_remove(sell_selected_item)

	var title = MuItemsRes.display_name(it_to_sell)
	var cat = "other"
	var g = int(it_to_sell.get("group", 0))
	if g <= 5: cat = "weapon"
	elif g >= 6 and g <= 11: cat = "armor"
	elif g == 12 and int(it_to_sell.get("number", 0)) in [3, 4, 5, 6, 36, 37, 38, 39, 40]: cat = "wings"
	elif g == 14 or (g == 12 and int(it_to_sell.get("number", 0)) == 15): cat = "jewel"

	market_items.push_front({
		"id": "list_%d_%d" % [Time.get_ticks_msec(), randi() % 100000],
		"title": title,
		"item": it_to_sell,
		"price": price,
		"seller": player.character_name,
		"category": cat,
		"time": "Vừa xong",
		"sold": false,
		"claimed": false
	})
	_save_market_data()

	sell_selected_item = {}
	sell_lbl_name.text = "Chưa chọn vật phẩm"
	sell_preview_icon.texture = null
	sell_lbl_details.text = "Hãy nhấp vào 1 món đồ ở danh sách bên trái để tiến hành đăng bán."
	sell_price_input.text = ""

	if MuAudioManager:
		MuAudioManager.play_ui_click()

	_notify("★ Đã đăng bán [%s] thành công lên Chợ Online với giá %s Zen!" % [title, _format_number(price)], Color(0.3, 0.95, 0.4))
	_switch_tab(2) # Chuyển sang xem Gian hàng của tôi

# -------------------------------------------------------------------------
# TAB 3: GIAN HÀNG CỦA TÔI
# -------------------------------------------------------------------------
func _build_my_shop_view(parent: Control) -> void:
	my_shop_scroll = ScrollContainer.new()
	my_shop_scroll.anchors_preset = Control.PRESET_FULL_RECT
	my_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(my_shop_scroll)

	my_shop_list_container = VBoxContainer.new()
	my_shop_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_shop_list_container.add_theme_constant_override("separation", 6)
	my_shop_scroll.add_child(my_shop_list_container)

func _render_my_shop_list() -> void:
	if not my_shop_list_container:
		return
	for c in my_shop_list_container.get_children():
		c.queue_free()

	var my_name = player.character_name if player else ""
	var my_listings: Array = []
	for it in market_items:
		if it.get("seller", "") == my_name:
			my_listings.append(it)

	if my_listings.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Hiện tại bạn chưa đăng bán món đồ nào lên Chợ Online.\nHãy qua Tab 'Đăng Bán Vật Phẩm' để niêm yết đồ bán nhé!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.custom_minimum_size = Vector2(0, 120)
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		my_shop_list_container.add_child(empty_lbl)
		return

	for listing in my_listings:
		var row = _create_my_listing_row(listing)
		my_shop_list_container.add_child(row)

func _create_my_listing_row(listing: Dictionary) -> Panel:
	var row = Panel.new()
	row.custom_minimum_size = Vector2(0, 48)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.9)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.35, 0.48, 0.7)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.offset_left = 10
	hbox.offset_right = -10
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var item_data: Dictionary = listing.get("item", {})
	var icon_tex: Texture2D = MuItemIconRes.catalog_icon(get_tree(), item_data, 36) if is_inside_tree() else null

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if icon_tex:
		icon_rect.texture = icon_tex
	hbox.add_child(icon_rect)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vb)

	var lbl_name = Label.new()
	lbl_name.text = str(listing.get("title", ""))
	lbl_name.add_theme_font_size_override("font_size", 11)
	lbl_name.add_theme_color_override("font_color", MuItemsRes.name_color(item_data))
	vb.add_child(lbl_name)

	var is_sold = bool(listing.get("sold", false))
	var is_claimed = bool(listing.get("claimed", false))

	var status_text = "Trạng thái: [ĐANG RAO BÁN TRÊN CHỢ]" if not is_sold else ("[ĐÃ BÁN THÀNH CÔNG]" if not is_claimed else "[ĐÃ NHẬN TIỀN]")
	var status_color = Color(0.3, 0.95, 0.4) if not is_sold else Color(1.0, 0.85, 0.2)

	var lbl_st = Label.new()
	lbl_st.text = status_text
	lbl_st.add_theme_font_size_override("font_size", 9)
	lbl_st.add_theme_color_override("font_color", status_color)
	vb.add_child(lbl_st)

	var price = int(listing.get("price", 0))
	var lbl_prc = Label.new()
	lbl_prc.text = "💰 %s Zen" % _format_number(price)
	lbl_prc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_prc.add_theme_font_size_override("font_size", 11)
	lbl_prc.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	hbox.add_child(lbl_prc)

	if not is_sold:
		# Nút Hủy Bán (Lấy lại đồ)
		var btn_cancel = Button.new()
		btn_cancel.text = "Hủy Bán (Lấy Lại)"
		btn_cancel.custom_minimum_size = Vector2(110, 26)
		btn_cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn_cancel.add_theme_font_size_override("font_size", 10)
		btn_cancel.pressed.connect(func(): _on_cancel_listing_clicked(listing))
		hbox.add_child(btn_cancel)
	elif not is_claimed:
		# Nút Nhận Zen
		var btn_claim = Button.new()
		btn_claim.text = "Nhận Zen Ngay"
		btn_claim.custom_minimum_size = Vector2(110, 26)
		btn_claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn_claim.add_theme_font_size_override("font_size", 10)
		btn_claim.pressed.connect(func(): _on_claim_zen_clicked(listing))
		hbox.add_child(btn_claim)

	return row

func _on_cancel_listing_clicked(listing: Dictionary) -> void:
	if not player:
		return
	var item_data: Dictionary = listing.get("item", {}).duplicate(true)
	var added = player.inv_add(item_data)
	if not added:
		_notify("Túi đồ đã đầy! Hãy dọn chỗ trống trước khi nhận lại đồ.", Color(1.0, 0.4, 0.4))
		return

	market_items.erase(listing)
	_save_market_data()

	if MuAudioManager:
		MuAudioManager.play_ui_click()

	_notify("★ Đã hủy bán và nhận lại món đồ [%s] vào Túi Đồ!" % listing.get("title", ""), Color(0.3, 0.95, 0.4))
	_refresh_current_tab()

func _on_claim_zen_clicked(listing: Dictionary) -> void:
	if not player:
		return
	var price = int(listing.get("price", 0))
	player.add_zen(price)
	listing["claimed"] = true
	market_items.erase(listing)
	_save_market_data()

	if MuAudioManager:
		MuAudioManager.play_ui_click()

	_notify("★ Đã nhận thành công +%s Zen từ món đồ đã bán!" % _format_number(price), Color(1.0, 0.85, 0.2))
	_refresh_current_tab()

# -------------------------------------------------------------------------
# Tiện Ích & Điều Khiển Mở/Đóng
# -------------------------------------------------------------------------
func _format_number(n: int) -> String:
	var s = str(n)
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res

func _notify(msg: String, color: Color) -> void:
	var tree = get_tree() if is_inside_tree() else null
	var hud = tree.get_first_node_in_group("HUD") if tree else null
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(msg, color)
	print("[MuMarketWindow] ", msg)

func open_market() -> void:
	if not panel_container:
		_build_ui()
	visible = true
	_on_viewport_resized()
	_refresh_current_tab()

func close() -> void:
	visible = false
	closed.emit()

func toggle() -> void:
	if visible:
		close()
	else:
		open_market()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			close()
			get_viewport().set_input_as_handled()
