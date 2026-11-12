extends Control
class_name NpcDialogueWindow

## Cửa sổ Đối thoại NPC (NPC Dialogue Window) phong cách MU Online
## Hiển thị lời chào, cốt truyện, và thực hiện TÍNH NĂNG THỰC TẾ với NPC trên tất cả các map:
## - Chuyển chức cấp 2 (Sevina), Marlon (Hiệp sĩ danh dự & Combo), Chuyển chức cấp 3 (Devin)
## - Sửa chữa trang bị (Blacksmith), Tinh chế Đá Tạo Hóa (Elpis), Đổi Rena (Golden Archer)
## - Đặt cược may rủi (Moss), Lập bang hội (Guild Master), Huấn luyện thú nuôi (Pet Trainer)
## - Dịch chuyển Blood Castle & Đấu trường Vulcanus, Buff Binh sĩ bóng ma, Cửa hàng, Rương đồ, v.v.

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")

const S := 1.5
const W := 250.0
const H := 360.0

signal action_triggered(action: String, npc_node: Node3D)

var player: MuPlayer = null
var current_npc: Node3D = null
var npc_data: Dictionary = {}

var body: Control
var _title_label: Label
var _sub_title_label: Label
var _text_box: RichTextLabel
var _options_container: VBoxContainer
var _scroll_container: ScrollContainer

static var _npc_db: Dictionary = {}

static func _ensure_db() -> void:
	if _npc_db.is_empty():
		var path = "res://assets/mu/npc_data.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_npc_db = parsed

static func get_npc_info(npc_id: int) -> Dictionary:
	_ensure_db()
	return _npc_db.get(str(npc_id), {})

static func find_npc_id_by_name(p_name: String) -> int:
	_ensure_db()
	var nl := p_name.to_lower().strip_edges()
	for k in _npc_db:
		var data = _npc_db[k]
		if str(data.get("name", "")).to_lower().strip_edges() == nl:
			return int(k)
	return -1

func _ready() -> void:
	visible = false
	add_to_group("MuNpcDialogueWindow")
	for c in get_children():
		c.queue_free()

	set_anchors_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S
	mouse_filter = Control.MOUSE_FILTER_STOP

	body = Control.new()
	body.custom_minimum_size = Vector2(W, H) * S
	body.size = Vector2(W, H) * S
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(body)

	# Khung viền phong cách MU NewUI
	_title_label = MuUiSkin.build_frame(body, "Hội Thoại NPC", W, H, "newui_item_back01")
	MuUiSkin.close_button(body, W, close)

	# Tiêu đề phụ (Danh xưng NPC)
	_sub_title_label = MuUiSkin.font_label("", 12, Color(1.0, 0.85, 0.3))
	_sub_title_label.position = Vector2(16, 36) * S
	_sub_title_label.size = Vector2(W - 32, 20) * S
	_sub_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_sub_title_label)

	# Đường kẻ phân cách
	var sep = ColorRect.new()
	sep.color = Color(0.45, 0.35, 0.2, 0.8)
	sep.position = Vector2(18, 54) * S
	sep.size = Vector2(W - 36, 1.5) * S
	body.add_child(sep)

	# Vùng cuộn văn bản đối thoại
	_scroll_container = ScrollContainer.new()
	_scroll_container.position = Vector2(18, 60) * S
	_scroll_container.size = Vector2(W - 36, 170) * S
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll_container)

	_text_box = RichTextLabel.new()
	_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_box.custom_minimum_size = Vector2(W - 46, 0) * S
	_text_box.bbcode_enabled = true
	_text_box.scroll_active = false
	_text_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_box.add_theme_font_size_override("normal_font_size", 13)
	_text_box.add_theme_color_override("default_color", Color(0.95, 0.92, 0.82))
	_scroll_container.add_child(_text_box)

	# Vùng chứa các nút tùy chọn hành động
	var opt_scroll = ScrollContainer.new()
	opt_scroll.position = Vector2(16, 236) * S
	opt_scroll.size = Vector2(W - 32, 112) * S
	opt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(opt_scroll)

	_options_container = VBoxContainer.new()
	_options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_container.add_theme_constant_override("separation", int(4 * S))
	opt_scroll.add_child(_options_container)

	_place()
	get_viewport().size_changed.connect(_place)

func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(maxf(20.0, vs.x * 0.5 - (W * S) * 0.5 - 120.0), maxf(20.0, (vs.y - H * S) * 0.5))

func open_dialogue(p_player: MuPlayer, p_npc: Node3D) -> void:
	player = p_player
	current_npc = p_npc

	var nid: int = -1
	if "npc_id" in p_npc:
		nid = p_npc.npc_id
	var nname: String = p_npc.npc_name if "npc_name" in p_npc else "NPC"
	var ntitle: String = p_npc.npc_title if "npc_title" in p_npc else ""

	# Nếu là NPC bán đồ / vật phẩm -> mở thẳng Shop và Túi đồ, không mở hộp thoại
	var check_id: int = nid
	if check_id <= 0:
		check_id = find_npc_id_by_name(nname)
	var is_shop: bool = false
	if "is_shop_npc" in p_npc and p_npc.has_method("is_shop_npc"):
		is_shop = p_npc.is_shop_npc()
	elif check_id > 0:
		const ShopWindowRes = preload("res://src/ui/ShopWindow.gd")
		if ShopWindowRes.has_shop(check_id):
			is_shop = true
		else:
			var info = get_npc_info(check_id)
			if info.get("has_shop", false) == true:
				is_shop = true

	if is_shop:
		var tree := get_tree()
		var hud = tree.get_first_node_in_group("HUD") if tree else null
		if hud and hud.has_method("open_npc_shop") and p_npc is MuNpc:
			close()
			hud.open_npc_shop(p_npc as MuNpc)
			return

	npc_data = get_npc_info(nid)

	var display_name: String = npc_data.get("name", nname)
	var display_title: String = npc_data.get("title", ntitle)
	var dialogue_text: String = npc_data.get("dialogue", "")
	var options: Array = npc_data.get("options", []).duplicate(true)

	# -------------------------------------------------------------------------
	# XỬ LÝ LỜI THOẠI & NÚT CHỨC NĂNG ĐỘNG THEO TIẾN TRÌNH THẬT CỦA NGƯỜI CHƠI
	# -------------------------------------------------------------------------
	if player:
		# 1. NỮ TU SEVINA (235) - NHIỆM VỤ CHUYỂN CHỨC CẤP 2
		if nid == 235:
			options.clear()
			if player.class_tier >= 2:
				dialogue_text = "[color=#55FFAA]Lời chúc phúc của thần linh luôn ở cùng con![/color]\nCon đã thăng chức thành [b][color=#FFD700]%s[/color][/b] dũng mãnh, hãy tiếp tục trừ gian diệt ác!" % player.get_class_display_name()
				options.append({"action": "close", "label": "Tạ Ơn Người"})
			elif player.level < 150:
				dialogue_text = "Chào con! Nghi thức phong chức cao quý chỉ mở ra khi con đạt từ [b][color=#FF5555]cấp độ 150[/color][/b] trở lên. Hiện tại cấp độ của con là %d, hãy rèn luyện thêm!" % player.level
				options.append({"action": "close", "label": "Con Sẽ Rèn Luyện Thêm"})
			elif player.quest_sevina_step == 0:
				dialogue_text = "Chào dũng sĩ %s! Con đã đủ điều kiện thực hiện [color=#FFD700]Nhiệm Vụ Thăng Chức Cấp 2[/color].\nBước 1: Hãy tìm về [b]Cuốn Sách Đế Vương[/b] (Scroll of the Emperor) thất lạc trong Lost Tower!" % player.character_name
				options.append({"action": "quest_sevina_accept", "label": "★ Nhận Nhiệm Vụ (Bước 1)"})
				options.append({"action": "close", "label": "Để Sau"})
			elif player.quest_sevina_step == 1:
				var has_scroll = player.has_item(14, 23)
				dialogue_text = "Con đã tìm thấy [b]Cuốn Sách Đế Vương[/b] (Scroll of the Emperor) chưa?\n[color=#88CCFF]Trạng thái: %s[/color]" % ("Đã tìm thấy trong túi đồ!" if has_scroll else "Chưa có trong túi đồ.")
				if has_scroll:
					options.append({"action": "quest_sevina_submit_step1", "label": "★ Nộp Cuốn Sách Đế Vương (+10 Điểm)"})
				else:
					options.append({"action": "quest_sevina_help_scroll", "label": "★ Nhận Cuốn Sách Đế Vương (Hỗ Trợ)"})
				options.append({"action": "close", "label": "Con Đi Tìm Ngay"})
			elif player.quest_sevina_step == 2:
				var quest_item_id = 24 # Broken Sword mặc định
				var item_name = "Gươm Gãy (Broken Sword)"
				if player.char_class == 0:
					quest_item_id = 26
					item_name = "Mảnh Linh Hồn (Soul Shard)"
				elif player.char_class == 2:
					quest_item_id = 25
					item_name = "Nước Mắt Tiên Nữ (Tear of Elf)"
				elif player.char_class == 5:
					quest_item_id = 68
					item_name = "Mắt Quỷ Vực Sâu (Abyssal Eye)"

				var has_treasure = player.has_item(14, quest_item_id)
				dialogue_text = "Bước 2: Để hoàn thành nghi thức trở thành [b][color=#FFD700]%s[/color][/b], hãy tìm [b]%s[/b]!" % [
					"Blade Knight" if player.char_class == 1 else ("Soul Master" if player.char_class == 0 else ("Muse Elf" if player.char_class == 2 else "Bloody Summoner")),
					item_name
				]
				if has_treasure:
					options.append({"action": "quest_sevina_submit_step2", "label": "★ Nộp %s (Thăng Chức Ngay!)" % item_name.split(" ")[0]})
				else:
					options.append({"action": "quest_sevina_help_treasure", "label": "★ Nhận %s (Hỗ Trợ)" % item_name.split(" ")[0]})
				options.append({"action": "close", "label": "Con Đi Tìm Ngay"})

		# 2. HIỆP SĨ MARLON (229) - NHIỆM VỤ DANH DỰ & COMBO
		elif nid == 229:
			options.clear()
			if player.class_tier < 2:
				dialogue_text = "Ngươi chưa thăng chức cấp 2! Hãy hoàn thành nhiệm vụ với Nữ Tu Sevina tại Devias trước khi tìm gặp ta."
				options.append({"action": "close", "label": "Tôi Hiểu Rồi"})
			elif player.level < 220:
				dialogue_text = "Nhiệm vụ Hiệp Sĩ Danh Dự chỉ dành cho chiến binh từ [b][color=#FF5555]cấp 220[/color][/b] trở lên. Hãy tích lũy thêm sức mạnh!"
				options.append({"action": "close", "label": "Để Sau"})
			elif player.quest_marlon_step == 0:
				dialogue_text = "Chào mừng dũng sĩ %s! Ngươi đã sẵn sàng kế thừa ý chí của các bậc tiền bối?\nHãy tìm cho ta [b]Chiếc Nhẫn Vinh Quang[/b] (Ring of Honor) tại vùng đất Tarkan!" % player.character_name
				options.append({"action": "quest_marlon_accept", "label": "★ Nhận Nhiệm Vụ Marlon (Bước 1)"})
				options.append({"action": "close", "label": "Rời Khỏi"})
			elif player.quest_marlon_step == 1:
				var has_ring = player.has_item(14, 22)
				dialogue_text = "Ngươi đã tìm thấy [b]Chiếc Nhẫn Vinh Quang[/b] (Ring of Honor) chưa?\n[color=#88CCFF]Trạng thái: %s[/color]" % ("Đã có trong túi đồ!" if has_ring else "Chưa tìm thấy.")
				if has_ring:
					options.append({"action": "quest_marlon_submit_step1", "label": "★ Nộp Nhẫn Vinh Quang (Nhận Bonus Point)"})
				else:
					options.append({"action": "quest_marlon_help_ring", "label": "★ Nhận Chiếc Nhẫn Vinh Quang (Hỗ Trợ)"})
				options.append({"action": "close", "label": "Tôi Đi Tìm Ngay"})
			elif player.quest_marlon_step == 2:
				if player.char_class == 1: # DK/BK
					var has_stone = player.has_item(14, 25)
					dialogue_text = "Thử thách tối thượng của Blade Knight: Hãy tìm [b]Viên Đá Bóng Tối[/b] (Dark Stone) để khai mở Kỹ Năng Combo liên hoàn sát thương bộc phá!"
					if has_stone:
						options.append({"action": "quest_marlon_submit_step2", "label": "★ Nộp Viên Đá Bóng Tối (Mở Khóa Combo!)"})
					else:
						options.append({"action": "quest_marlon_help_stone", "label": "★ Nhận Viên Đá Bóng Tối (Hỗ Trợ)"})
					options.append({"action": "close", "label": "Tôi Đi Tìm Ngay"})
				else:
					dialogue_text = "[color=#55FFAA]Chúc mừng![/color] Ngươi đã hoàn thành mọi nhiệm vụ danh dự của Marlon!"
					options.append({"action": "close", "label": "Tạ Ơn Marlon"})
			elif player.quest_marlon_step >= 3:
				dialogue_text = "[color=#55FFAA]Chúc mừng dũng sĩ![/color] Ngươi đã sở hữu tiềm năng và tuyệt kỹ Combo tối thượng của lục địa MU!"
				options.append({"action": "close", "label": "Tạ Ơn Marlon"})

		# 3. ĐẠI GIÁO SĨ DEVIN (406) - CHUYỂN CHỨC CẤP 3 (MASTER CLASS)
		elif nid == 406:
			options.clear()
			if player.class_tier >= 3:
				dialogue_text = "[color=#55FFAA]Hỡi Đại Hiệp Sĩ Master Class![/color]\nNgươi đã đứng trên đỉnh cao sức mạnh của nhân loại. Hãy dùng quyền năng ấy bảo vệ lục địa MU!"
				options.append({"action": "close", "label": "Tôi Sẽ Làm Được"})
			elif player.level < 400:
				dialogue_text = "Thử thách Cấp 3 chỉ dành cho những huyền thoại đã chạm mốc [b][color=#FF5555]cấp độ 400[/color][/b]. Ngươi hiện tại cấp %d, hãy tiếp tục tu luyện!" % player.level
				options.append({"action": "close", "label": "Tôi Sẽ Tu Luyện Thêm"})
			elif player.quest_devin_step == 0:
				dialogue_text = "Hỡi dũng sĩ %s! Để phá vỡ giới hạn phàm trần và tiến hóa thành [b][color=#FFD700]Master Class[/color][/b], hãy tìm 3 bảo vật chứng minh sức mạnh: [b]Ngọn Lửa Hiệp Sĩ, Sừng Quỷ và Lông Phượng Hoàng[/b]!" % player.character_name
				options.append({"action": "quest_devin_accept", "label": "★ Nhận Thử Thách Cấp 3"})
				options.append({"action": "close", "label": "Rời Khỏi"})
			elif player.quest_devin_step == 1:
				var has_all = player.has_item(14, 65) and player.has_item(14, 67) and player.has_item(14, 68)
				dialogue_text = "3 Bảo Vật Chứng Minh Sức Mạnh:\n- Ngọn Lửa Hiệp Sĩ: %s\n- Lông Phượng Hoàng: %s\n- Sừng Quỷ: %s" % [
					"[color=lime]Có[/color]" if player.has_item(14, 65) else "[color=red]Chưa[/color]",
					"[color=lime]Có[/color]" if player.has_item(14, 67) else "[color=red]Chưa[/color]",
					"[color=lime]Có[/color]" if player.has_item(14, 68) else "[color=red]Chưa[/color]"
				]
				if has_all:
					options.append({"action": "quest_devin_submit", "label": "★ Nộp 3 Bảo Vật (Thăng Chức Master!)"})
				else:
					options.append({"action": "quest_devin_help_items", "label": "★ Nhận 3 Bảo Vật Sức Mạnh (Hỗ Trợ)"})
				options.append({"action": "close", "label": "Tôi Đi Săn Quái Ngay"})

		# 4. THỢ RÈN (Blacksmith) - SỬA CHỮA ĐỒ THẬT
		elif nid in [251, 243, 246, 578]:
			var repair_btn_found := false
			for opt in options:
				if opt.get("action") == "repair_all":
					repair_btn_found = true
					break
			if not repair_btn_found:
				options.insert(1, {"action": "repair_all", "label": "★ Sửa Chữa Toàn Bộ Trang Bị"})

		# 5. ELPIS (368) - TINH CHẾ ĐÁ TẠO HÓA THẬT
		elif nid == 368:
			options.clear()
			var gem_count = player.count_item(14, 41)
			dialogue_text = "Chào mừng đến Tháp Tinh Chế Kanturu! Đưa cho ta Đá Quý Thô (Gemstone), ta sẽ tinh chế thành [b]Đá Tạo Hóa (Jewel of Harmony)[/b].\n[color=#88CCFF]Bạn đang có: %d viên Gemstone[/color]" % gem_count
			options.append({"action": "refinery_execute", "label": "★ Tinh Chế 1 Đá Tạo Hóa (Cần 1 Gemstone)"})
			options.append({"action": "refinery_execute_all", "label": "★ Tinh Chế Toàn Bộ Gemstone"})
			options.append({"action": "refinery_help_gem", "label": "★ Nhận 5 Viên Đá Quý Thô (Hỗ Trợ)"})
			options.append({"action": "close", "label": "Rời Khỏi"})

		# 6. CUNG THỦ HOÀNG KIM (236) - ĐỔI RENA LẤY QUÀ THẬT
		elif nid == 236:
			options.clear()
			var rena_count = player.count_item(14, 21)
			dialogue_text = "Chào dũng sĩ! Gom đủ 5 viên Đá May Mắn / Rena, hoàng gia MU sẽ ban tặng ngươi [b]100.000 Zen[/b] và [b]1 Viên Ngọc Quý (Bless/Soul/Chaos/Life)[/b]!\n[color=#88CCFF]Hiện có: %d viên Rena trong túi[/color]" % rena_count
			options.append({"action": "exchange_rena_execute", "label": "★ Đổi 5 Viên Rena Lấy Quà"})
			options.append({"action": "exchange_rena_help", "label": "★ Nhận 5 Viên Rena (Hỗ Trợ)"})
			options.append({"action": "close", "label": "Hẹn Gặp Lại"})

		# 7. MOSS THE MERCHANT (492) - THỬ VẬN MAY THẬT
		elif nid == 492:
			options.clear()
			dialogue_text = "Kekeke! Đặt cược [b]500.000 Zen[/b] để thử vận may mở rương vũ khí thần bí! Tỉ lệ nhận được vũ khí Hoàn Hảo (Excellent), có Tuyệt Chiêu (Skill) và May Mắn (Luck) cực cao!\n[color=#FFD700]Zen hiện có của bạn: %s[/color]" % MuItems.format_zen(player.zen)
			options.append({"action": "moss_gamble_execute", "label": "★ Đặt Cược 500k Zen (Mở Vũ Khí)"})
			options.append({"action": "close", "label": "Để Sau"})

		# 8. GUILD MASTER (241) - LẬP BANG HỘI THẬT
		elif nid == 241:
			options.clear()
			if not player.guild_name.is_empty():
				dialogue_text = "Chào mừng Bang Chủ của Guild [b][color=#FFD700]%s[/color][/b]! Hãy dẫn dắt các huynh đệ bảo vệ thành trì và chinh phục Lâu Đài Sói (Crywolf)!" % player.guild_name
				options.append({"action": "close", "label": "Tôi Hiểu Rồi"})
			else:
				dialogue_text = "Điều kiện thành lập Bang Hội: [b]Cấp 100 trở lên[/b] và [b]1.000.000 Zen[/b].\nKhi có Bang Hội, bạn có thể tham gia Công Thành Chiến và xưng bá thiên hạ!"
				options.append({"action": "guild_create_execute", "label": "★ Thành Lập Bang Hội (1 Triệu Zen)"})
				options.append({"action": "close", "label": "Rời Khỏi"})

		# 9. PET TRAINER (226) - HUẤN LUYỆN THÚ NUÔI THẬT
		elif nid == 226:
			options.clear()
			dialogue_text = "Ta có thể hồi sinh [b]Chiến Mã (Dark Horse)[/b] và [b]Quạ Tinh (Dark Raven)[/b] từ Linh Hồn Thú Cưỡi và ngọc quý, cũng như hồi phục hoàn toàn sinh lực cho các chiến thú của bạn!"
			options.append({"action": "pet_craft_horse", "label": "★ Hồi Sinh Chiến Mã (Dark Horse)"})
			options.append({"action": "pet_craft_raven", "label": "★ Hồi Sinh Quạ Tinh (Dark Raven)"})
			options.append({"action": "pet_heal_all", "label": "★ Hồi Phục Máu Toàn Bộ Thú Cưỡi"})
			options.append({"action": "pet_help_materials", "label": "★ Nhận Nguyên Liệu Ép Thú (Hỗ Trợ)"})
			options.append({"action": "close", "label": "Rời Khỏi"})

		# 10. SỨ GIẢ THIÊN SỨ (233) - BLOOD CASTLE THẬT
		elif nid == 233:
			options.clear()
			var has_cloak = player.has_item(13, 18)
			dialogue_text = "Lâu Đài Máu (Blood Castle) đang mở cửa! Cần mang theo [b]Áo Choàng Tàng Hình (Invisibility Cloak)[/b] để tiến vào giải cứu Thiên Sứ.\n[color=#88CCFF]Trạng thái: %s[/color]" % ("Đã có Áo Choàng trong túi!" if has_cloak else "Chưa có Áo Choàng.")
			options.append({"action": "blood_castle_enter", "label": "★ Tiến Vào Lâu Đài Máu"})
			options.append({"action": "blood_castle_help_cloak", "label": "★ Nhận Áo Choàng Tàng Hình (Hỗ Trợ)"})
			options.append({"action": "close", "label": "Rời Khỏi"})

		# 11. TITUS - ĐẤU TRƯỜNG VULCANUS (479)
		elif nid == 479:
			options.clear()
			dialogue_text = "Đấu trường Vulcanus là nơi chứng minh bản lĩnh và kỹ năng PK tự do không tính điểm phạt giết người. Ngươi có dám bước vào?"
			options.append({"action": "duel_arena_enter", "label": "★ Tiến Vào Đấu Trường Vulcanus"})
			options.append({"action": "close", "label": "Rời Khỏi"})

	if dialogue_text.is_empty():
		dialogue_text = "Xin chào chiến binh %s! Ta là %s. Chúc bạn có một ngày thám hiểm bình an!" % [
			player.character_name if player else "anh hùng",
			display_name
		]

	_title_label.text = display_name
	_sub_title_label.text = "[ %s ]" % display_title if not display_title.is_empty() else ""
	_text_box.text = dialogue_text

	_build_options(options)

	_place()
	visible = true

	if MuAudioManager:
		MuAudioManager.play_ui_window()

func _build_options(options: Array) -> void:
	for c in _options_container.get_children():
		c.queue_free()

	if options.is_empty():
		options = [{"action": "close", "label": "Rời Khỏi"}]

	for opt in options:
		var action: String = opt.get("action", "close")
		var label_text: String = opt.get("label", "Xác Nhận")

		var btn := Button.new()
		btn.text = label_text
		btn.custom_minimum_size = Vector2(W - 40, 24) * S
		btn.focus_mode = Control.FOCUS_NONE

		# Style phong cách nút MU
		var sb_n = StyleBoxFlat.new()
		sb_n.corner_radius_top_left = 3
		sb_n.corner_radius_top_right = 3
		sb_n.corner_radius_bottom_left = 3
		sb_n.corner_radius_bottom_right = 3

		if action == "close":
			sb_n.bg_color = Color(0.2, 0.16, 0.14, 0.9)
			sb_n.border_width_left = 1
			sb_n.border_width_top = 1
			sb_n.border_width_right = 1
			sb_n.border_width_bottom = 1
			sb_n.border_color = Color(0.5, 0.4, 0.3)
			btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
		elif action.begins_with("quest") or action.contains("submit") or action.contains("enter"):
			sb_n.bg_color = Color(0.18, 0.28, 0.15, 0.95)
			sb_n.border_width_left = 1
			sb_n.border_width_top = 1
			sb_n.border_width_right = 1
			sb_n.border_width_bottom = 1
			sb_n.border_color = Color(0.45, 0.85, 0.35)
			btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.65))
		else:
			sb_n.bg_color = Color(0.28, 0.22, 0.12, 0.95)
			sb_n.border_width_left = 1
			sb_n.border_width_top = 1
			sb_n.border_width_right = 1
			sb_n.border_width_bottom = 1
			sb_n.border_color = Color(0.85, 0.7, 0.25)
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))

		btn.add_theme_stylebox_override("normal", sb_n)

		var sb_h = sb_n.duplicate()
		sb_h.bg_color = Color(0.4, 0.32, 0.18, 1.0)
		sb_h.border_color = Color(1.0, 0.85, 0.4)
		btn.add_theme_stylebox_override("hover", sb_h)

		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_option_clicked.bind(action))

		_options_container.add_child(btn)

func _on_option_clicked(action: String) -> void:
	if MuAudioManager:
		MuAudioManager.play_ui_click()

	if action == "close":
		close()
		return

	# Phát tín hiệu kích hoạt hành động thật tới HUD
	emit_signal("action_triggered", action, current_npc)

	# Các hành động mở cửa sổ độc lập (shop, vault, mix, devil square, move) sẽ đóng dialogue window
	if action in ["shop", "vault", "chaos_box", "devil_square", "lahap", "duel_arena_enter", "blood_castle_enter"]:
		close()
	else:
		# Đối với các hành động nhiệm vụ, rèn ngọc, đổi rena, lập guild:
		# Cho một khoảng trễ cực ngắn rồi refresh lại nội dung để hiển thị bước tiếp theo ngay lập tức!
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(player) and is_instance_valid(current_npc) and visible:
			open_dialogue(player, current_npc)

func close() -> void:
	visible = false
	current_npc = null
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
