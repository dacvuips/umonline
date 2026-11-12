extends Node
class_name MuAccountSession

## Quản lý Phiên Tài Khoản, Danh Sách Nhân Vật & Lựa Chọn Nhân Vật MU Online
## Đồng bộ giữa Giao diện (UI) và Mạng (Network/Server)

const SAVE_PATH_TEMPLATE := "user://mu_characters_%s.json"
const CURRENT_ACCOUNT_FILE := "user://mu_current_account.txt"
const MAX_SLOTS := 5

## Lấy tài khoản đang hoạt động (đồng bộ giữa các scene và file lưu)
static func get_active_account() -> String:
	if current_account != "" and current_account != "Player":
		return current_account
	if FileAccess.file_exists(CURRENT_ACCOUNT_FILE):
		var f = FileAccess.open(CURRENT_ACCOUNT_FILE, FileAccess.READ)
		if f:
			var acc = f.get_as_text().strip_edges()
			f.close()
			if acc != "":
				current_account = acc
				return current_account
	if FileAccess.file_exists("user://mu_login_saved.json"):
		var f2 = FileAccess.open("user://mu_login_saved.json", FileAccess.READ)
		if f2:
			var json = JSON.parse_string(f2.get_as_text())
			f2.close()
			if json is Dictionary and str(json.get("account", "")) != "":
				current_account = str(json["account"]).strip_edges()
				return current_account
	return current_account

## Đặt tài khoản hoạt động và ghi nhận vĩnh viễn
static func set_active_account(acc: String) -> void:
	var cleaned = acc.strip_edges()
	if cleaned == "":
		cleaned = "Player"
	current_account = cleaned
	var f = FileAccess.open(CURRENT_ACCOUNT_FILE, FileAccess.WRITE)
	if f:
		f.store_string(cleaned)
		f.close()

# Dữ liệu chuẩn gốc từ Webzen (CharMakeWin.cpp / w_CharacterInfo.cpp)
## Nhân vật mới tạo Level 1 trong game gốc MU Online không có trang bị nào trên người (equipment = {})
## Trang phục hiển thị là trang phục cơ bản nguyên bản theo lớp (Class Underwear / Default Skin)
const CLASS_INFO := {
	0: {
		"id": 0,
		"key": "wizard",
		"name": "Dark Wizard",
		"title": "Phù Thủy Áo Đen",
		"str": 18,
		"agi": 18,
		"vit": 15,
		"ene": 30,
		"cmd": 0,
		"req_level": 1,
		"desc": "Hậu duệ của hội pháp thuật Arka cổ xưa, thành thạo các nguyên tố ma thuật diện rộng.",
		"default_equipment": {}
	},
	1: {
		"id": 1,
		"key": "knight",
		"name": "Dark Knight",
		"title": "Chiến Binh Bóng Đêm",
		"str": 28,
		"agi": 20,
		"vit": 25,
		"ene": 10,
		"cmd": 0,
		"req_level": 1,
		"desc": "Chiến binh kiên cường của vương quốc Lorencia, sở hữu sức mạnh cận chiến vô song và giáp trụ cứng cáp.",
		"default_equipment": {}
	},
	2: {
		"id": 2,
		"key": "elf",
		"name": "Fairy Elf",
		"title": "Tiên Nữ Xạ Thủ",
		"str": 22,
		"agi": 25,
		"vit": 20,
		"ene": 15,
		"cmd": 0,
		"req_level": 1,
		"desc": "Những nữ chiến binh thanh nhã từ vương quốc Noria, cung thủ bách phát bách trúng và có khả năng hồi phục sinh lực.",
		"default_equipment": {}
	},
	3: {
		"id": 3,
		"key": "dark",
		"name": "Magic Gladiator",
		"title": "Đấu Sĩ Ma Pháp",
		"str": 26,
		"agi": 26,
		"vit": 26,
		"ene": 26,
		"cmd": 0,
		"req_level": 220,
		"desc": "Chiến binh kết hợp tuyệt đỉnh giữa kiếm thuật cận chiến tàn bạo và phép thuật hủy diệt.",
		"default_equipment": {}
	},
	4: {
		"id": 4,
		"key": "dark-lord",
		"name": "Dark Lord",
		"title": "Chúa Tể Bóng Đêm",
		"str": 26,
		"agi": 20,
		"vit": 20,
		"ene": 15,
		"cmd": 25,
		"req_level": 250,
		"desc": "Thủ lĩnh mang dòng dõi đế vương với uy quyền lãnh đạo, điều khiển chiến mã và quạ tinh bóng đêm.",
		"default_equipment": {}
	},
	5: {
		"id": 5,
		"key": "summoner",
		"name": "Summoner",
		"title": "Thuật Sĩ Triệu Hồi",
		"str": 21,
		"agi": 21,
		"vit": 18,
		"ene": 23,
		"cmd": 0,
		"req_level": 1,
		"desc": "Nữ thuật sĩ với tinh thần thép và khả năng nguyền rủa, triệu hồi sức mạnh bóng tối.",
		"default_equipment": {}
	},
	6: {
		"id": 6,
		"key": "rage-fighter",
		"name": "Rage Fighter",
		"title": "Thiết Binh Quyền Thần",
		"str": 32,
		"agi": 27,
		"vit": 25,
		"ene": 20,
		"cmd": 0,
		"req_level": 250,
		"desc": "Chiến binh hoàng gia Karutan, chiến đấu bằng nắm đấm thép cuồng bạo và kình lực cận chiến mãnh liệt.",
		"default_equipment": {}
	}
}

# Biến trạng thái toàn cục (Static Session)
static var current_account: String = "Player"
static var server_gateway_url: String = "ws://127.0.0.1:8080"
## Token phiên do gateway cấp khi đăng nhập đúng; gửi lại trong "join" của kênh người chơi (kết nối thứ hai).
static var session_token: String = ""
static var character_list: Array[Dictionary] = []
static var selected_slot: int = 0
static var selected_character_name: String = ""

# Thông tin Máy Chủ / Server đã chọn
static var selected_server_group: String = "Lorencia"
static var selected_server_channel: String = "Lorencia-1"
static var selected_server_code: int = 1

# Cấu trúc Cụm & Kênh máy chủ chuẩn MU Online
const SERVER_DATA := [
	{
		"group_name": "Lorencia",
		"group_label": "Lorencia",
		"channels": [
			{"code": 1, "name": "Lorencia-1", "desc": "Connect", "load": 35, "status": "Connect"},
			{"code": 2, "name": "Lorencia-2", "desc": "Connect", "load": 55, "status": "Connect"},
			{"code": 3, "name": "Lorencia-3", "desc": "Connect", "load": 20, "status": "Connect"},
			{"code": 4, "name": "Lorencia-4", "desc": "Connect", "load": 15, "status": "Connect"},
		]
	},
	{
		"group_name": "Noria",
		"group_label": "Noria",
		"channels": [
			{"code": 101, "name": "Noria-1", "desc": "Connect", "load": 25, "status": "Connect"},
			{"code": 102, "name": "Noria-2", "desc": "Connect", "load": 40, "status": "Connect"},
			{"code": 103, "name": "Noria-3", "desc": "Connect", "load": 10, "status": "Connect"},
		]
	},
	{
		"group_name": "Devias",
		"group_label": "Devias",
		"channels": [
			{"code": 201, "name": "Devias-1", "desc": "Connect", "load": 30, "status": "Connect"},
			{"code": 202, "name": "Devias-2", "desc": "Connect", "load": 65, "status": "Connect"},
			{"code": 203, "name": "Devias-3", "desc": "Connect", "load": 15, "status": "Connect"},
		]
	}
]

## Khởi tạo và nạp danh sách nhân vật cho tài khoản
static func load_account_characters(account: String = "") -> void:
	if account != "":
		set_active_account(account)
	else:
		current_account = get_active_account()
	
	character_list.clear()
	for i in range(MAX_SLOTS):
		character_list.append({}) # 5 slot rỗng
	
	var file_path = SAVE_PATH_TEMPLATE % current_account
	if FileAccess.file_exists(file_path):
		var f = FileAccess.open(file_path, FileAccess.READ)
		if f:
			var json_str = f.get_as_text()
			f.close()
			var json = JSON.new()
			if json.parse(json_str) == OK and json.data is Array:
				var saved_list: Array = json.data
				for item in saved_list:
					if item is Dictionary and item.has("slot"):
						var slot = int(item["slot"])
						if slot >= 0 and slot < MAX_SLOTS:
							character_list[slot] = item
	
	# Nếu tài khoản mới chưa có nhân vật nào thì để danh sách trống (0 nhân vật) để người chơi tự tạo
	# Tự động chọn slot có nhân vật đầu tiên nếu có
	selected_slot = -1
	for i in range(MAX_SLOTS):
		if not character_list[i].is_empty():
			selected_slot = i
			break

## Lưu danh sách nhân vật vào file cục bộ
static func save_account_characters() -> void:
	var acc = get_active_account()
	if acc == "":
		return
	var file_path = SAVE_PATH_TEMPLATE % acc
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		var list_to_save: Array = []
		for item in character_list:
			if not item.is_empty():
				list_to_save.append(item)
		f.store_string(JSON.stringify(list_to_save, "\t"))
		f.close()

## Đếm số nhân vật đang có
static func get_live_character_count() -> int:
	var count = 0
	for item in character_list:
		if not item.is_empty():
			count += 1
	return count

## Tìm slot trống đầu tiên (trả về -1 nếu đầy 5 slot)
static func get_first_empty_slot() -> int:
	for i in range(MAX_SLOTS):
		if character_list[i].is_empty():
			return i
	return -1

## Chuẩn hóa bất kỳ mã class nào (Base ID 0..6, OpenMU CharacterClassNumber, Webzen class byte) về Base ID 0..6
static func normalize_class_id(cid: int) -> int:
	if cid >= 0 and cid <= 6:
		return cid
	match cid:
		0, 2, 3: return 0     # Dark Wizard
		4, 6, 7: return 1     # Dark Knight
		8, 10, 11: return 2   # Fairy Elf
		12, 13: return 3      # Magic Gladiator
		16, 17: return 4      # Dark Lord
		20, 22, 23: return 5  # Summoner
		24, 25: return 6      # Rage Fighter
	var high = (cid >> 4) & 0x0F
	if high >= 0 and high <= 6:
		return high
	return 1

## Lấy tên hiển thị danh hiệu Class tiếng Việt chuẩn MU
static func get_class_title(cid: int) -> String:
	var base_id = normalize_class_id(cid)
	match base_id:
		0: return "Phù Thủy"
		1: return "Chiến Binh"
		2: return "Tiên Nữ"
		3: return "Đấu Sĩ"
		4: return "Chúa Tể"
		5: return "Thuật Sĩ"
		6: return "Thiết Binh"
		_: return "Chiến Binh"

## Lấy cấp độ cao nhất trong tài khoản hiện tại để kiểm tra điều kiện mở khóa Class
static func get_highest_character_level() -> int:
	var max_lvl = 0
	for item in character_list:
		if not item.is_empty():
			var lvl = int(item.get("level", 1))
			if lvl > max_lvl:
				max_lvl = lvl
	return max_lvl

## Kiểm tra xem class có được phép tạo hay không theo luật MU Online gốc:
## - Dark Wizard, Dark Knight, Fairy Elf, Summoner: Level 1 (Mở khóa sẵn)
## - Magic Gladiator: Cần nhân vật Level 220+
## - Dark Lord, Rage Fighter: Cần nhân vật Level 250+
static func is_class_unlocked(class_id: int) -> bool:
	var max_lvl = get_highest_character_level()
	match class_id:
		0, 1, 2, 5: # DW, DK, ELF, SUM
			return true
		3: # Magic Gladiator
			return max_lvl >= 220
		4: # Dark Lord
			return max_lvl >= 250
		6: # Rage Fighter
			return max_lvl >= 250
		_:
			return true

## Lấy thông tin điều kiện tạo của class
static func get_class_requirement_text(class_id: int) -> String:
	match class_id:
		3: return "Cần nhân vật Level 220+"
		4: return "Cần nhân vật Level 250+"
		6: return "Cần nhân vật Level 250+"
		_: return ""

## Tạo nhân vật mới
static func create_character(char_name: String, class_id: int, target_slot: int = -1, start_level: int = 1) -> Dictionary:
	if not is_class_unlocked(class_id):
		return {}

	var slot = target_slot
	if slot < 0 or slot >= MAX_SLOTS or not character_list[slot].is_empty():
		slot = get_first_empty_slot()
	if slot == -1:
		return {} # Đã đầy 5 slot
	
	var cinfo = CLASS_INFO.get(class_id, CLASS_INFO[1])
	var char_data = {
		"slot": slot,
		"name": char_name,
		"class_id": class_id,
		"class_name": cinfo["name"],
		"class_title": cinfo["title"],
		"level": start_level,
		"current_exp": 0,
		"stat_points": 0,
		"stat_str": cinfo["str"],
		"stat_agi": cinfo["agi"],
		"stat_vit": cinfo["vit"],
		"stat_ene": cinfo["ene"],
		"stat_cmd": cinfo.get("cmd", 0),
		"zen": 0,
		"equipment": {}, # Chuẩn game gốc: nhân vật mới tạo hoàn toàn không mặc trang bị nào
		"inventory": []
	}
	
	character_list[slot] = char_data
	selected_slot = slot
	save_account_characters()
	return char_data

## Xoá nhân vật tại slot
static func delete_character_at(slot: int) -> bool:
	if slot < 0 or slot >= character_list.size():
		return false
	if character_list[slot].is_empty():
		return false
	
	character_list[slot] = {}
	save_account_characters()
	
	# Chọn lại slot hợp lệ khác
	selected_slot = -1
	for i in range(character_list.size()):
		if not character_list[i].is_empty():
			selected_slot = i
			break
	return true

## Lấy nhân vật tại slot
static func get_character_at(slot: int) -> Dictionary:
	if slot >= 0 and slot < character_list.size():
		return character_list[slot]
	return {}

## Lấy nhân vật đang chọn
static func get_selected_character() -> Dictionary:
	return get_character_at(selected_slot)
