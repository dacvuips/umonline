extends RefCounted
class_name MuItems

## Dữ liệu & quy tắc đồ của MU (dùng chung cho túi đồ, cửa hàng, rơi đồ):
##   - kích thước ô, tên hiển thị + màu tên, ô trang bị
##   - giá mua / bán theo ItemPriceCalculator (OpenMU — port từ công thức của server gốc)
## Một món đồ = Dictionary {group, number, level, excellent, luck, skill, opt, dur, x, y}

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

const DROP_LEVEL_INC := {5: 4, 6: 10, 7: 25, 8: 45, 9: 65, 10: 95, 11: 135, 12: 185, 13: 245, 14: 305, 15: 365}

## Tên tiếng Việt chuẩn cho Ngọc, Thú cưỡi, Nhẫn, Dây chuyền, v.v.
const ITEM_VN_NAMES := {
	# Ngọc Quý (Jewels)
	"12:15": "Ngọc Chaos (Jewel of Chaos)",
	"12:30": "Cụm Ngọc Bless (Bundle of Bless)",
	"12:31": "Cụm Ngọc Soul (Bundle of Soul)",
	"12:136": "Cụm Ngọc Life (Bundle of Life)",
	"12:137": "Cụm Ngọc Creation (Bundle of Creation)",
	"12:138": "Cụm Ngọc Guardian (Bundle of Guardian)",
	"12:139": "Cụm Đá Gemstone (Bundle of Gemstone)",
	"12:140": "Cụm Đá Harmony (Bundle of Harmony)",
	"12:141": "Cụm Ngọc Chaos (Bundle of Chaos)",
	"14:13": "Ngọc Bless (Jewel of Bless)",
	"14:14": "Ngọc Soul (Jewel of Soul)",
	"14:16": "Ngọc Life (Jewel of Life)",
	"14:22": "Ngọc Creation (Jewel of Creation)",
	"14:31": "Ngọc Guardian (Jewel of Guardian)",
	"14:41": "Đá Nguyên Thủy (Gemstone)",
	"14:42": "Đá Tạo Hóa (Jewel of Harmony)",
	"14:43": "Đá Tinh Luyện Cấp Thấp (Lower Refining Stone)",
	"14:44": "Đá Tinh Luyện Cấp Cao (Higher Refining Stone)",
	"14:160": "Ngọc Gia Hạn (Jewel of Extension)",
	"14:161": "Ngọc Nâng Cấp (Jewel of Elevation)",

	# Thú Cưỡi & Thần Thú & Thiên Thần (Mounts & Pets)
	"13:0": "Thiên Thần Hộ Mệnh (Guardian Angel)",
	"13:1": "Tiểu Quỷ Satan (Imp)",
	"13:2": "Thú Cưỡi Ngựa Uniria (Horn of Uniria)",
	"13:3": "Thú Cưỡi Quái Điểu (Horn of Dinorant)",
	"13:4": "Chiến Mã Chúa Tể (Dark Horse)",
	"13:5": "Quạ Tinh Chúa Tể (Dark Raven)",
	"13:37": "Thú Cưỡi Sói Tinh (Horn of Fenrir)",
	"13:64": "Quỷ Vương (Demon)",
	"13:65": "Thần Hộ Mệnh (Spirit of Guardian)",
	"13:67": "Tuần Lộc May Mắn (Rudolf)",
	"13:80": "Gấu Trúc (Pet Panda)",
	"13:106": "Kỳ Lân (Pet Unicorn)",
	"13:123": "Bộ Xương Nhỏ (Pet Skeleton)",

	# Nhẫn (Rings)
	"13:8": "Nhẫn Băng (Ring of Ice)",
	"13:9": "Nhẫn Độc (Ring of Poison)",
	"13:10": "Nhẫn Biến Hình (Transformation Ring)",
	"13:20": "Nhẫn Phù Thủy (Wizards Ring)",
	"13:21": "Nhẫn Lửa (Ring of Fire)",
	"13:22": "Nhẫn Đất (Ring of Earth)",
	"13:23": "Nhẫn Gió (Ring of Wind)",
	"13:24": "Nhẫn Ma Lực (Ring of Magic)",
	"13:39": "Nhẫn Biến Hình Xương (Elite Transfer Skeleton Ring)",
	"13:40": "Nhẫn Bí Ngô (Jack O'Lantern Ring)",
	"13:41": "Nhẫn Giáng Sinh (Christmas Ring)",
	"13:42": "Nhẫn GM (Ring of GM)",
	"13:68": "Nhẫn Người Tuyết (Snowman Transformation Ring)",
	"13:76": "Nhẫn Gấu Trúc (Panda Ring)",
	"13:107": "Nhẫn Phù Thủy Cực Đại (Lethal Wizard's Ring)",
	"13:109": "Nhẫn Lam Ngọc (Sapphire Ring)",
	"13:110": "Nhẫn Hồng Ngọc (Ruby Ring)",
	"13:111": "Nhẫn Hoàng Ngọc (Topaz Ring)",
	"13:112": "Nhẫn Thạch Anh Tím (Amethyst Ring)",
	"13:122": "Nhẫn Bộ Xương (Skeleton Transformation Ring)",

	# Dây Chuyền (Pendants / Necklaces)
	"13:12": "Dây Chuyền Sét (Pendant of Lighting)",
	"13:13": "Dây Chuyền Lửa (Pendant of Fire)",
	"13:25": "Dây Chuyền Băng (Pendant of Ice)",
	"13:26": "Dây Chuyền Gió (Pendant of Wind)",
	"13:27": "Dây Chuyền Nước (Pendant of Water)",
	"13:28": "Dây Chuyền Kỹ Năng AG (Pendant of Ability)",
	"13:38": "Dây Chuyền Mặt Trăng (Moonstone Pendant)",
	"13:113": "Dây Chuyền Hồng Ngọc (Ruby Necklace)",
	"13:114": "Dây Chuyền Ngọc Lục Bảo (Emerald Necklace)",
	"13:115": "Dây Chuyền Lam Ngọc (Sapphire Necklace)",

	# Vật Phẩm Ép Đồ & Sự Kiện (Crafting & Chaos Materials)
	"13:7": "Hợp Đồng Triệu Hồi Crywolf (Contract of Summon)",
	"13:11": "Lệnh Bài Hộ Vệ / Đá Sinh Mệnh (Life Stone)",
	"13:14": "Lông Vũ Pha Lê / Huy Hiệu Hoàng Tộc (Loch's Feather)",
	"13:15": "Trái Cây Thần (Fruits)",
	"13:16": "Cuộn Giấy Thiên Sứ (Scroll of Archangel)",
	"13:17": "Xương Máu (Blood Bone)",
	"13:18": "Áo Tàng Hình / Vé Blood Castle (Invisibility Cloak)",
	"13:19": "Vũ Khí Thiên Sứ (Absolute Weapon of Archangel)",
	"13:29": "Áo Giáp Vệ Binh / Vé Chaos Castle (Armor of Guardsman)",
	"13:30": "Áo Choàng Chúa Tể (Cape of Lord)",
	"13:31": "Linh Hồn Chiến Mã / Huy Hiệu (Crest of Monarch)",
	"13:32": "Mảnh Áo Giáp Sói Tinh (Splinter of Armor)",
	"13:33": "Lời Chúc Bảo Hộ (Bless of Guardian)",
	"13:34": "Móng Vuốt Quái Thú (Claw of Beast)",
	"13:35": "Mảnh Sừng Gãy (Piece of Horn)",
	"13:36": "Sừng Gãy (Broken Horn)",
	"13:46": "Vé Quảng Trường Quỷ (Devil Square Ticket)",
	"13:47": "Vé Lâu Đài Máu (Blood Castle Ticket)",
	"13:48": "Vé Đền Kalima (Kalima Ticket)",
	"13:49": "Cuộn Giấy Cổ (Old Scroll)",
	"13:50": "Giao Ước Ảo Ảnh (Illusion Sorcerer Covenant)",
	"13:51": "Huyết Kính Ấn / Cuộn Giấy Máu (Scroll of Blood)",
	"13:52": "Ngọn Lửa Condor (Flame of Condor)",
	"13:53": "Lông Vũ Condor (Feather of Condor)",
	"13:61": "Vé Đền Ảo Ảnh (Illusion Temple Ticket)",
	"13:66": "Thiệp Mời Làng Santa (Invitation to Santa Village)",
	"13:121": "Vé Tự Do Hỗn Nguyên Lâu (Chaos Castle Access Ticket)",
	"13:125": "Vé Vùng Đất Bóng Ma (Ticket to Doppelganger)",
	"13:126": "Vé Pháo Đài Varka (Ticket to Varka)",
	"13:127": "Vé Varka Tầng 7 (Ticket to Varka Map 7)",
	"14:7": "Thuốc Công Thành (Siege Potion)",
	"14:11": "Hộp May Mắn (Box of Luck)",
	"14:12": "Trái Tim Yêu Thương (Heart of Love)",
	"14:17": "Mắt Quỷ (Devil's Eye)",
	"14:18": "Khóa Quỷ (Devil's Key)",
	"14:19": "Thiệp Lời Mời Quỷ (Devil's Invitation)",
	"14:21": "Dấu Ấn Lãnh Chúa (Sign of Lord / Rena)",
	"14:23": "Cuốn Sách Đế Vương (Scroll of the Emperor)",
	"14:24": "Gươm Gãy (Broken Sword)",
	"14:25": "Nước Mắt Tiên Nữ (Tear of Elf)",
	"14:26": "Mảnh Linh Hồn Phù Thủy (Soul Shard of Wizard)",
	"14:28": "Bản Đồ Biến Mất / Vé Kalima (Lost Map)",
	"14:29": "Huy Hiệu Kundun (Symbol of Kundun)",
	"14:32": "Hộp Sô-cô-la Hồng (Pink Chocolate Box)",
	"14:33": "Hộp Sô-cô-la Đỏ (Red Chocolate Box)",
	"14:34": "Hộp Sô-cô-la Xanh (Blue Chocolate Box)",
	"14:55": "Hộp Kundun +1 (Box of Kundun +1)",
	"14:56": "Hộp Kundun +2 (Box of Kundun +2)",
	"14:57": "Hộp Kundun +3 (Box of Kundun +3)",
	"14:58": "Hộp Kundun +4 (Box of Kundun +4)",
	"14:59": "Hộp Kundun +5 (Box of Kundun +5)",
	"14:63": "Pháo Hoa May Mắn (Firecracker)",
	"14:65": "Lửa Hiệp Sĩ Tia Chớp (Death-beam Knight Flame)",
	"14:67": "Lông Phượng Hoàng (Dark Phoenix Feather)",
	"14:68": "Mắt Quỷ Vực Sâu / Sừng Quỷ (Abyssal Eye)",
	"14:84": "Hộp Quà Hoa Anh Đào (Cherry Blossom Play-Box)",
	"14:85": "Rượu Hoa Anh Đào (Cherry Blossom Wine)",
	"14:86": "Bánh Dày Hoa Anh Đào (Cherry Blossom Rice Cake)",
	"14:87": "Cánh Hoa Anh Đào (Cherry Blossom Petal)",
	"14:88": "Cành Hoa Anh Đào Trắng (White Cherry Blossom Branch)",
	"14:89": "Cành Hoa Anh Đào Đỏ (Red Cherry Blossom Branch)",
	"14:90": "Cành Hoa Anh Đào Vàng (Golden Cherry Blossom Branch)",
	"14:99": "Pháo Hoa Giáng Sinh (Christmas Firecracker)",
	"14:102": "Lệnh Bài Gaion (Gaion's Order)",
	"14:103": "Mảnh Khải Huyền 1 (First Secromicon Fragment)",
	"14:104": "Mảnh Khải Huyền 2 (Second Secromicon Fragment)",
	"14:105": "Mảnh Khải Huyền 3 (Third Secromicon Fragment)",
	"14:106": "Mảnh Khải Huyền 4 (Fourth Secromicon Fragment)",
	"14:107": "Mảnh Khải Huyền 5 (Fifth Secromicon Fragment)",
	"14:108": "Mảnh Khải Huyền 6 (Sixth Secromicon Fragment)",
	"14:109": "Sách Khải Huyền Hoàn Chỉnh (Complete Secromicon)",
	"14:110": "Dấu Ấn Không Gian (Sign of Dimensions)",
	"14:111": "Gương Chiều Không Gian (Mirror of Dimensions)",
	"14:112": "Chìa Khóa Bạc (Silver Key)",
	"14:113": "Chìa Khóa Vàng (Gold Key)",
	"14:121": "Rương Vàng Niêm Phong (Sealed Golden Box)",
	"14:122": "Rương Bạc Niêm Phong (Sealed Silver Box)",
	"14:123": "Rương Vàng Báu Vật (Golden Box)",
	"14:124": "Rương Bạc Báu Vật (Silver Box)",
	"2:6": "Rìu Hỗn Nguyên (Chaos Dragon Axe)",
	"4:6": "Cung Hỗn Nguyên (Chaos Nature Bow)",
	"5:7": "Gậy Hỗn Nguyên (Chaos Lightning Staff)",
	"0:19": "Tuyệt Mệnh Kiếm (Divine Sword of Archangel)",
	"2:13": "Quyền Trượng Tuyệt Mệnh (Divine Scepter of Archangel)",
	"4:18": "Nỏ Tuyệt Mệnh (Divine Crossbow of Archangel)",
	"5:10": "Gậy Tuyệt Mệnh (Divine Staff of Archangel)",
	"5:36": "Gậy Thiên Sứ Thuật Sĩ (Divine Stick of the Archangel)",
}

## Sói Tinh (13:37) theo cờ Excellent trong dữ liệu Source: 1 = Destroy (đen), 2 = Protect (xanh), 4 = Illusion (vàng)
const FENRIR_NAME_SUFFIX := {1: " +Destroy", 2: " +Protect", 4: " +Illusion"}
const FENRIR_TYPE_NAME := {0: "Red Fenrir", 1: "Black Fenrir", 2: "Blue Fenrir", 4: "Golden Fenrir"}

static func make(group: int, number: int, level: int = 0, extra: Dictionary = {}) -> Dictionary:
	var it := {"group": group, "number": number, "level": level, "excellent": false, "luck": false,
		"skill": false, "opt": 0, "dur": 0, "x": 0, "y": 0}
	it.merge(extra, true)
	it = sanitize(it)
	if int(it["dur"]) <= 0:
		it["dur"] = max_durability(it)
	return it

## Mục hàng trong shops.json ({slot,g,n,lvl,dur,opt,luck,skill,exc})
static func from_shop(e: Dictionary) -> Dictionary:
	var it := make(int(e.get("g", 0)), int(e.get("n", 0)), int(e.get("lvl", 0)), {
		"excellent": bool(e.get("exc", false)), "luck": bool(e.get("luck", false)), "skill": bool(e.get("skill", false)),
		"opt": int(e.get("opt", 0)), "dur": int(e.get("dur", 0))})
	var slot := int(e.get("slot", 0))
	it["x"] = slot % 8
	it["y"] = slot / 8
	return it

## Loại đồ nào được có dòng phụ (Excellent / May mắn / Kỹ năng / Tuỳ chọn thêm / Thần / Tím / Socket / Tạo hóa).
## Theo Source gốc: Ngọc, thuốc, vật phẩm ép, vé, thú cưỡi, thú cưng... KHÔNG có các dòng này.
## Trang bị (nhóm 0..11) có đủ; cánh có Excellent + Tuỳ chọn; dây chuyền / nhẫn chỉ Excellent.
static func option_caps(it: Dictionary) -> Dictionary:
	var g := int(it.get("group", 0))
	if g <= 11:
		return {"exc": true, "luck": true, "skill": g <= 6, "opt": true, "special": true}
	if is_wing(it):
		return {"exc": true, "luck": false, "skill": false, "opt": true, "special": false}
	if g == 13 and (is_pendant(it) or is_ring(it)):
		return {"exc": true, "luck": false, "skill": false, "opt": false, "special": false}
	return {"exc": false, "luck": false, "skill": false, "opt": false, "special": false}

## Bản sao đã xoá các dòng phụ mà loại đồ này không được có (ngọc "Excellent + May mắn + Opt +28" là sai)
static func sanitize(it: Dictionary) -> Dictionary:
	var caps := option_caps(it)
	var out := it
	if not bool(caps["exc"]) and bool(out.get("excellent", false)):
		out["excellent"] = false
	if not bool(caps["luck"]) and bool(out.get("luck", false)):
		out["luck"] = false
	if not bool(caps["skill"]) and bool(out.get("skill", false)):
		out["skill"] = false
	if not bool(caps["opt"]) and int(out.get("opt", 0)) != 0:
		out["opt"] = 0
	if not bool(caps["special"]):
		for k in ["ancient", "purple", "option_380", "socket", "harmony"]:
			if out.has(k) and bool(out[k]):
				out[k] = false
	return out

static func info(it: Dictionary) -> Dictionary:
	return MuCatalogRes.item_info(int(it.get("group", 0)), int(it.get("number", 0)))

static func size_of(it: Dictionary) -> Vector2i:
	var inf := info(it)
	return Vector2i(maxi(1, int(inf.get("width", 1))), maxi(1, int(inf.get("height", 1))))

static func max_durability(it: Dictionary) -> int:
	var inf := info(it)
	var d := int(inf.get("durability", 0))
	if d <= 0:
		return 1
	# MU: độ bền tăng theo cấp đồ (+1 mỗi cấp tới +4, rồi nhiều hơn) — xấp xỉ
	var lv := int(it.get("level", 0))
	return d + lv + (maxi(0, lv - 4) * 2)

## Trạng thái màu theo độ bền (CInventoryCtrl::SetItemColorState): 0 = bình thường, 50 / 70 / 80 = còn <= 50% / 30% / 20%,
## 100 = hết bền. Chỉ áp dụng cho đồ nhóm 0..11 (vũ khí, giáp) — Type < ITEM_WING trong client gốc.
static func durability_state(it: Dictionary) -> int:
	if int(it.get("group", 0)) > 11:
		return 0
	var mx := max_durability(it)
	if mx <= 1:
		return 0
	var d := int(it.get("dur", mx))
	if d <= 0:
		return 100
	if d <= int(mx * 0.2):
		return 80
	if d <= int(mx * 0.3):
		return 70
	if d <= int(mx * 0.5):
		return 50
	return 0

## Màu nền ô (alpha 102) và màu phủ ô trang bị (alpha 64) theo trạng thái độ bền (item_grid.rcss / my_inventory.rcss)
static func durability_tint(state: int, alpha: float) -> Color:
	match state:
		50: return Color(1.0, 1.0, 0.0, alpha)
		70: return Color(1.0, 168.0 / 255.0, 0.0, alpha)
		80: return Color(1.0, 84.0 / 255.0, 0.0, alpha)
		100: return Color(1.0, 0.0, 0.0, alpha)
	return Color(0, 0, 0, 0)

static func base_name(it: Dictionary) -> String:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	var key := "%d:%d" % [g, n]
	if ITEM_VN_NAMES.has(key):
		return ITEM_VN_NAMES[key]
	var nm = info(it).get("name", "")
	if nm is Dictionary:
		return str(nm.get("en", ""))
	return str(nm) if str(nm) != "" else "Item %d-%d" % [g, n]

static func display_name(it: Dictionary) -> String:
	it = sanitize(it.duplicate())
	var s := base_name(it)
	if bool(it.get("ancient", false)):
		s = "[Thần] " + s
	if bool(it.get("excellent", false)):
		s = "Excellent " + s
	if bool(it.get("purple", false)) or bool(it.get("option_380", false)):
		s = "[Tím 380] " + s
	if bool(it.get("socket", false)):
		s = "[Socket] " + s
	if int(it.get("group", 0)) == 13 and int(it.get("number", 0)) == 37:
		s += FENRIR_NAME_SUFFIX.get(int(it.get("excellent_flags", 0)), "")
	var lv := int(it.get("level", 0))
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	# Các vật phẩm sự kiện có cấp độ (+1..+8) cần hiển thị rõ ràng kể cả ở Group 14
	var is_event_with_level := (g == 14 and (n in [17, 18, 19, 28, 29, 55, 56, 57, 58, 59])) or (g == 13 and (n in [16, 17, 18, 29, 46, 47, 48, 49, 50, 51, 61]))
	if lv > 0 and (is_event_with_level or (g != 14 and g != 15 and g != 12) or (g == 12 and is_wing(it) and lv > 0)):
		s += " +%d" % lv
	if int(it.get("dur", 0)) > 1 and (g == 14 or (g == 4 and (int(it.get("number", 0)) == 7 or int(it.get("number", 0)) == 15))):
		s += " x%d" % int(it.get("dur", 0))
	return s

## Màu tên giống ItemNameColor của MU: Xanh ngọc cho Đồ Thần, Tím cho Đồ Tím/Socket, Excellent xanh lá, +7.. vàng, +4.. xanh nhạt, còn lại trắng
static func name_color(it: Dictionary) -> Color:
	it = sanitize(it.duplicate())
	if bool(it.get("ancient", false)):
		return Color(0.0, 1.0, 0.0)   # TEXT_COLOR_GREEN_BLUE: chữ xanh lá trên nền xanh dương (60, 60, 200)
	if bool(it.get("socket", false)) or bool(it.get("purple", false)) or bool(it.get("option_380", false)):
		return Color(0.88, 0.45, 1.0)
	if bool(it.get("excellent", false)):
		return Color(0.1, 1.0, 0.5)
	if int(it.get("group", 0)) == 13 and int(it.get("number", 0)) == 37:
		return Color(0.4, 0.75, 1.0)   # Sói Tinh: tên màu xanh như Source
	var lv := int(it.get("level", 0))
	if lv >= 7:
		return Color(1.0, 0.8, 0.1)
	if lv >= 4 or bool(it.get("luck", false)) or bool(it.get("skill", false)) or int(it.get("opt", 0)) > 0:
		return Color(0.4, 0.75, 1.0)
	return Color(1, 1, 1)

static func is_wing(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	if g == 13 and n == 30: # Cape of Lord
		return true
	return g == 12 and (n <= 6 or (n >= 36 and n <= 43) or n == 49 or n == 50 or (n >= 130 and n <= 135))

static func is_mount(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	return g == 13 and (n in [2, 3, 4, 37]) # Uniria, Dinorant, Dark Horse, Fenrir

static func is_pet(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	return g == 13 and (n in [0, 1, 5, 64, 65, 67, 80, 106, 123]) # Angel, Satan, Raven, Demon, Guardian, Rudolf, Panda, Unicorn, Skeleton

static func is_helper(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	if g == 13:
		var inf := info(it)
		var s := str(inf.get("slot", ""))
		if s == "pet":
			return true
		return is_mount(it) or is_pet(it)
	return false

static func is_jewel(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	if g == 14 and (n in [13, 14, 16, 22, 31, 41, 42, 43, 44, 160, 161]):
		return true
	if g == 12 and (n == 15 or n in [30, 31, 136, 137, 138, 139, 140, 141]):
		return true
	var nm := base_name(it).to_lower()
	return "jewel" in nm or "ngọc" in nm or "gemstone" in nm or "refining stone" in nm or "đá tạo hóa" in nm

static func is_valuable(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if is_jewel(it):
		return true
	if int(it.get("level", 0)) >= 7:
		return true
	if bool(it.get("excellent", false)) or int(it.get("ancient", 0)) > 0:
		return true
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	if g == 12 and (n in [0, 1, 2, 3, 4, 5, 36, 37, 38, 39, 40, 41, 42, 43] or n in [130, 131, 132, 133, 134, 135]):
		return true
	if g == 13 and (n in [4, 37]):
		return true
	return false

static func is_pendant(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	if g == 13:
		var n := int(it.get("number", 0))
		if n in [12, 13, 25, 26, 27, 28, 38, 113, 114, 115]:
			return true
		var inf := info(it)
		var s := str(inf.get("slot", ""))
		if s == "pendant":
			return true
		var nm := base_name(it).to_lower()
		return "pendant" in nm or "necklace" in nm or "dây chuyền" in nm
	return false

## Nhận diện danh mục sự kiện (trả về nhóm ID -551 .. -560 hoặc 0 nếu không phải item sự kiện)
static func event_category_id(it: Dictionary) -> int:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	# 1. Blood Castle (Lâu Đài Máu)
	if (g == 13 and (n in [16, 17, 18, 19, 47])) or (g == 0 and n == 19) or (g == 2 and n == 13) or (g == 4 and n == 18) or (g == 5 and (n == 10 or n == 36)):
		return -551
	# 2. Devil Square (Quảng Trường Quỷ)
	if (g == 14 and (n in [17, 18, 19])) or (g == 13 and n == 46):
		return -552
	# 3. Chaos Castle (Hỗn Nguyên Lâu)
	if g == 13 and (n == 29 or n == 121):
		return -553
	# 4. Kalima & Kundun
	if (g == 14 and (n == 28 or n == 29)) or (g == 13 and n == 48):
		return -554
	# 5. Illusion Temple (Đền Ảo Ảnh)
	if g == 13 and (n in [49, 50, 51, 61]):
		return -556
	# 6. Crywolf, Kanturu & Công Thành Chiến (Castle Siege)
	if (g == 13 and (n in [7, 11, 14, 31, 38])) or (g == 14 and (n == 7 or n == 21)):
		return -557
	# 7. Imperial Guardian & Doppelganger
	if (g == 14 and (n in [102, 103, 104, 105, 106, 107, 108, 109, 110, 111])) or (g == 13 and (n in [125, 126, 127])):
		return -558
	# 8. Nhiệm Vụ Chuyển Cấp 2 & 3
	if (g == 14 and (n in [23, 24, 25, 26, 65, 67, 68])) or (g == 13 and (n in [52, 53])):
		return -559
	# 9. Hộp Báu Kundun & Hộp Quà Lễ Hội
	if (g == 14 and (n in [11, 12, 32, 33, 34, 55, 56, 57, 58, 59, 63, 84, 85, 86, 87, 88, 89, 90, 99, 112, 113, 121, 122, 123, 124])) or (g == 13 and n == 66):
		return -560
	return 0

## Kiểm tra xem món đồ có phải là vé hoặc vật phẩm sự kiện không
static func is_event_item(it: Dictionary) -> bool:
	return event_category_id(it) != 0

static func is_ring(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	if g == 13:
		var n := int(it.get("number", 0))
		if n in [8, 9, 10, 20, 21, 22, 23, 24, 39, 40, 41, 42, 68, 76, 107, 109, 110, 111, 112, 122]:
			return true
		var inf := info(it)
		var s := str(inf.get("slot", ""))
		if s == "ring":
			return true
		var nm := base_name(it).to_lower()
		return "ring" in nm or "nhẫn" in nm
	return false

static func is_potion(it: Dictionary) -> bool:
	return int(it.get("group", 0)) == 14 and int(it.get("number", 0)) <= 8

static func is_crafting(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	if g == 12 and (n == 15 or n == 141): # Ngọc Chaos & Cụm Chaos
		return true
	if g == 13 and (n in [14, 15, 16, 17, 18, 29, 31, 32, 33, 34, 35, 36, 49, 50, 51, 52, 53]):
		return true
	if g == 14 and (n in [11, 12, 17, 18, 19, 55, 56, 57, 58, 59]):
		return true
	if (g == 2 and n == 6) or (g == 4 and n == 6) or (g == 5 and n == 7):
		return true
	var nm := base_name(it).to_lower()
	return "chaos" in nm or "feather" in nm or "condor" in nm or "crest" in nm or "splinter" in nm or "horn" in nm or "blood bone" in nm or "archangel" in nm or "devil" in nm or "cloak" in nm or "box of kundun" in nm or "kundun" in nm

## Ô trang bị của nhân vật: helm/armor/pants/gloves/boots/right/left/wings/helper/amulet/ring ("" = không mặc được)
static func equip_slot(it: Dictionary) -> String:
	var g := int(it.get("group", 0))
	# Quạ Tinh (Dark Raven) đeo ở ô tay trái (OpenMU: ItemSlot 1) — Dark Lord vừa cưỡi Chiến Mã vừa có quạ
	if g == 13 and int(it.get("number", 0)) == 5:
		return "left"
	if is_wing(it):
		return "wings"
	if is_helper(it):
		return "helper"
	if is_pendant(it):
		return "amulet"
	if is_ring(it):
		return "ring"
	match g:
		7: return "helm"
		8: return "armor"
		9: return "pants"
		10: return "gloves"
		11: return "boots"
		6: return "left"
	if g <= 5:
		var s := str(info(it).get("slot", "mainHand"))
		return "left" if s == "offHand" else "right"
	if g == 13:
		var inf := info(it)
		var s := str(inf.get("slot", ""))
		match s:
			"pet": return "helper"
			"pendant": return "amulet"
			"ring": return "ring"
			"wings": return "wings"
			"offHand": return "left"
			"mainHand": return "right"
	return ""

## Kiểm tra món đồ có đặt vừa ô trang bị cụ thể hay không
static func can_equip_in_slot(it: Dictionary, slot: String) -> bool:
	var want := equip_slot(it)
	if want == "":
		return false
	if want == slot:
		return true
	if (slot == "ring_right" or slot == "ring_left") and (want == "ring" or want == "ring_right" or want == "ring_left"):
		return true
	if want == "right" and slot == "left" and int(it.get("group", 0)) <= 5:
		return true
	return false

# ---------------------------------------------------------------------------- giá
static func _special(g: int, n: int, lv: int, it: Dictionary) -> int:
	# SpecialPrices của ItemPriceDefinitions (các món hay bán ở NPC)
	match [g, n]:
		[4, 15]:
			return [70, 1200, 2000, 2800][clampi(lv, 0, 3)]
		[4, 7]:
			return [100, 1400, 2200, 3000][clampi(lv, 0, 3)]
		[14, 13]: return 9000000
		[14, 14]: return 6000000
		[12, 15]: return 810000
		[14, 16]: return 45000000
		[14, 22]: return 36000000
		[14, 31]: return 60000000
		[13, 15]: return 33000000
		[13, 14]: return 7500000 if lv == 1 else 180000
		[14, 3], [14, 6]: return 1500 * (lv + 1) * maxi(1, int(it.get("dur", 1)))
		[14, 7]: return (900000 if lv == 0 else 450000) * maxi(1, int(it.get("dur", 1)))
		[14, 9]: return 750
		[14, 20]: return 900
		[14, 35]: return 2000 * maxi(1, int(it.get("dur", 1)))
		[14, 36]: return 4000 * maxi(1, int(it.get("dur", 1)))
		[14, 37]: return 6000 * maxi(1, int(it.get("dur", 1)))
		[14, 38]: return 2500 * maxi(1, int(it.get("dur", 1)))
		[14, 39]: return 5000 * maxi(1, int(it.get("dur", 1)))
		[14, 40]: return 7500 * maxi(1, int(it.get("dur", 1)))
		[13, 29]: return 5000
		[14, 17]: return [10000, 10000, 50000, 100000, 300000, 500000, 800000, 1000000][clampi(lv, 0, 7)]
		[14, 18]: return [15000, 15000, 75000, 150000, 450000, 750000, 1200000, 1500000][clampi(lv, 0, 7)]
		[13, 16], [13, 17]: return [10000, 10000, 50000, 100000, 300000, 500000, 800000, 1000000, 1200000][clampi(lv, 0, 8)]
	return -1

static func _round(p: int) -> int:
	if p >= 1000:
		return p / 100 * 100
	if p >= 100:
		return p / 10 * 10
	return p

static func buy_price(it: Dictionary) -> int:
	var inf := info(it)
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	var lv := int(it.get("level", 0))
	var value := int(inf.get("sellValue", inf.get("value", 0)))
	var drop := int(inf.get("level", 0)) + lv * 3
	if bool(it.get("excellent", false)):
		drop += 25
	var price := 0
	var sp := _special(g, n, lv, it)
	if sp >= 0:
		price = sp
	elif value > 0 and (g == 15 or g == 12):
		price = value
	elif value > 0:
		if is_potion(it):
			price = int(floor(floor(value * value * 10.0 / 12.0) * pow(2, lv) / 10.0)) * 10 * maxi(1, int(it.get("dur", 1)))
		else:
			price = int(floor(value * value * 10.0 / 12.0))
	elif g == 13 or g == 15 or (g == 12 and not is_wing(it)):
		price = drop * drop * drop + 100
	else:
		var d := drop + int(DROP_LEVEL_INC.get(lv, 0))
		if is_wing(it):
			price = (d + 40) * d * d * 11 + 40000000
		else:
			price = (d + 40) * d * d / 8 + 100
		var w := int(inf.get("width", 1))
		if (g < 6 and w < 2) or g == 6:
			price = int(floor(price * 80 / 100.0))
		# ApplyOptionModifiers: skill, luck, option, excellent
		if bool(it.get("skill", false)):
			price += int(price * 1.5)
		if bool(it.get("luck", false)):
			price += price * 25 / 100
		var ol := int(it.get("opt", 0))
		if ol == 1:
			price += int(price * 0.6)
		elif ol > 1:
			price += int(price * 0.7 * pow(2, ol - 1))
		if bool(it.get("excellent", false)):
			price += price
	return _round(mini(price, 3000000000))

static func sell_price(it: Dictionary) -> int:
	return _round(buy_price(it) / 3)

## Thứ tự 7 lớp nhân vật chuẩn MU (RequireClass trong ZzzInventory.cpp)
const CLASS_REQUIREMENT_ORDER := [
	{"id": 0, "key": "darkWizard", "names": ["Dark Wizard", "Soul Master", "Grand Master"]},
	{"id": 1, "key": "darkKnight", "names": ["Dark Knight", "Blade Knight", "Blade Master"]},
	{"id": 2, "key": "fairyElf", "names": ["Elf", "Muse Elf", "High Elf"]},
	{"id": 3, "key": "magicGladiator", "names": ["Magic Gladiator", "", "Duel Master"]},
	{"id": 4, "key": "darkLord", "names": ["Dark Lord", "", "Lord Emperor"]},
	{"id": 5, "key": "summoner", "names": ["Summoner", "Bloody Summoner", "Dimension Master"]},
	{"id": 6, "key": "rageFighter", "names": ["Rage Fighter", "", "Fist Master"]},
]

## Màu chữ/nền chuẩn Source gốc (TEXT_COLOR_WHITE & TEXT_COLOR_DARKRED: rgb(160, 0, 0))
const TOOLTIP_COLOR_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const TOOLTIP_BG_DARKRED := Color(160.0 / 255.0, 0.0, 0.0, 1.0)

## Tên class theo bậc yêu cầu (1..3); bậc bị bỏ qua (MG/DL/RF bậc 2) lấy bậc kế tiếp như ClassLineName
static func _class_line_name(names: Array, needed: int) -> String:
	for tier_idx in range(maxi(needed, 1) - 1, names.size()):
		var nm := str(names[tier_idx])
		if nm != "":
			return nm
	return ""

## Thêm các dòng class yêu cầu vào tooltip theo đúng điều kiện & màu của Source gốc (RequireClass / Tooltip.json)
static func _append_class_requirement_lines(lines: Array, inf: Dictionary, hero_class: int, hero_tier: int) -> void:
	var layout := str(inf.get("tooltipLayout", ""))
	if layout == "noClassLines" or layout == "noClassOrDurabilityLines":
		return
	var changes = inf.get("tooltipLayoutChanges")
	if changes is Dictionary:
		var hidden = changes.get("hide")
		if hidden is Array and hidden.has("classLines"):
			return
	var class_reqs = inf.get("classRequirements")
	if not (class_reqs is Dictionary) or class_reqs.is_empty():
		return
	# Nếu cả 7 class đều yêu cầu bậc 1 (allClasses) -> không hiển thị dòng class (ZzzInventory.cpp)
	var all_tier1 := true
	for entry in CLASS_REQUIREMENT_ORDER:
		if int(class_reqs.get(entry["key"], 0)) != 1:
			all_tier1 = false
			break
	if all_tier1:
		return
	for entry in CLASS_REQUIREMENT_ORDER:
		var needed := int(class_reqs.get(entry["key"], 0))
		if needed <= 0 or needed > 3:
			continue
		var cname := _class_line_name(entry["names"], needed)
		if cname == "":
			continue
		var text := "Trang bị cho %s" % cname
		var class_usable: bool = (int(entry["id"]) == hero_class and needed <= hero_tier)
		if class_usable:
			lines.append([text, TOOLTIP_COLOR_WHITE])
		else:
			lines.append([text, TOOLTIP_COLOR_WHITE, TOOLTIP_BG_DARKRED])

## Các dòng mô tả (tooltip) [[chữ, màu], ...] hoặc [[chữ, màu, màu_nền], ...] — bố cục như ItemExplanationWindow
static func tooltip(it: Dictionary, price_label: String = "", price: int = -1) -> Array:
	it = sanitize(it.duplicate())
	var inf := info(it)
	var lines := []
	if bool(it.get("ancient", false)):
		# Đồ thần (set): dòng tên có nền xanh dương (60, 60, 200), chữ xanh lá — ZzzInventory.cpp GreenBlue
		lines.append([display_name(it), name_color(it), Color(60.0 / 255.0, 60.0 / 255.0, 200.0 / 255.0, 1.0)])
	else:
		lines.append([display_name(it), name_color(it)])
	var white := Color(0.9, 0.9, 0.9)
	var blue := Color(0.45, 0.65, 1.0)
	if inf.has("damageMin"):
		var lv := int(it.get("level", 0))
		var bonus := lv * 3 + maxi(0, lv - 9) * (lv - 9) / 2
		lines.append(["Sát thương: %d ~ %d" % [int(inf["damageMin"]) + bonus, int(inf["damageMax"]) + bonus], white])
	if inf.has("magicPower") and int(inf.get("magicPower", 0)) > 0:
		lines.append(["Sức mạnh phép: %d%%" % int(inf["magicPower"]), white])
	if inf.has("defense"):
		lines.append(["Phòng thủ: %d" % (int(inf["defense"]) + int(it.get("level", 0)) * 3), white])
	if inf.has("attackSpeed"):
		lines.append(["Tốc độ đánh: %d" % int(inf["attackSpeed"]), white])
	if is_mount(it) or is_pet(it):
		pass   # thú cưỡi / thú cưng hiện "Mạng: N" ở phần mô tả (đúng Source gốc)
	elif int(inf.get("durability", 0)) > 0:
		lines.append(["Độ bền: [%d/%d]" % [int(it.get("dur", 0)), max_durability(it)], white])
	elif int(it.get("dur", 0)) > 1:
		lines.append(["Số lượng: %d" % int(it.get("dur", 0)), white])
	var req: Dictionary = inf.get("requirements", {}) if inf.get("requirements") is Dictionary else {}
	var names := {"level": "Cấp", "strength": "Sức mạnh", "dexterity": "Nhanh nhẹn", "energy": "Năng lượng", "vitality": "Thể lực", "command": "Mệnh lệnh"}
	for k in req:
		lines.append(["Yêu cầu %s: %d" % [names.get(k, k), int(req[k])], white])
	var hero_node = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("Player") if Engine.get_main_loop() is SceneTree else null
	var hero_class: int = int(hero_node.get("char_class")) if hero_node != null and hero_node.get("char_class") != null else -1
	var hero_tier: int = int(hero_node.get("class_tier")) if hero_node != null and hero_node.get("class_tier") != null else 0
	_append_class_requirement_lines(lines, inf, hero_class, hero_tier)

	# Thú cưỡi / thú cưng / tiểu quỷ / thiên thần: chỉ ghi đúng mô tả trong Source gốc (Items/Group13_Helper.json).
	# Yêu cầu cấp độ đã được in ở phần "Yêu cầu" phía trên, "Mạng" = độ bền của thú.
	if is_mount(it) or is_pet(it):
		var pc := Color(1.0, 0.75, 0.3)
		var pg := int(it.get("group", 0))
		var pn := int(it.get("number", 0))
		if pg == 13:
			match pn:
				0:
					lines.append(["Hấp thụ 20% sát thương", pc])
					lines.append(["Sinh lực tối đa +50", pc])
				1:
					lines.append(["Tăng 30% sức tấn công và phép thuật", pc])
				3:
					lines.append(["Tăng 15% sát thương", pc])
					lines.append(["Hấp thụ 10% sát thương", pc])
				64:
					lines.append(["Tăng 40% sức tấn công và phép thuật", pc])
					lines.append(["Tăng tốc độ tấn công +10", pc])
				65:
					lines.append(["Giảm 30% sát thương từ quái vật", pc])
					lines.append(["Sinh lực tối đa +50", pc])
				67:
					lines.append(["Tự động nhặt Zen xung quanh", pc])
				80:
					lines.append(["Tự động nhặt Zen xung quanh", pc])
					lines.append(["Tăng 50% kinh nghiệm", pc])
					lines.append(["Tăng phòng thủ +50", pc])
				106:
					lines.append(["Tự động nhặt Zen xung quanh", pc])
					lines.append(["Tăng 50% lượng Zen", pc])
					lines.append(["Tăng phòng thủ +50", pc])
				123:
					lines.append(["Tự động nhặt Zen xung quanh", pc])
					lines.append(["Tăng 20% sát thương, phép thuật và nguyền rủa", pc])
					lines.append(["Tăng tốc độ tấn công +10", pc])
					lines.append(["Tăng 30% kinh nghiệm", pc])
					lines.append(["Đeo cùng Nhẫn Bộ Xương: tăng 30% kinh nghiệm", pc])
		if int(it.get("group", 0)) == 13 and int(it.get("number", 0)) == 37:
			var ff := int(it.get("excellent_flags", 0))
			var pl = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("Player") if Engine.get_main_loop() is SceneTree else null
			var plv := int(pl.get("level")) if pl != null and pl.get("level") != null else 1
			lines.append(["Kỹ năng Plasma Storm (Mana: 50)", blue])
			match ff:
				1:
					lines.append(["Tăng 10% sát thương", blue])
				2:
					lines.append(["Giảm 10% sát thương nhận vào", blue])
				4:
					lines.append(["Tăng %d Sinh lực tối đa" % (plv / 2), blue])
					lines.append(["Tăng %d Mana tối đa" % (plv / 2), blue])
					lines.append(["Tăng %d Sát thương vật lý" % (plv / 12), blue])
					lines.append(["Tăng %d Sát thương phép" % (plv / 25), blue])
			lines.append([str(FENRIR_TYPE_NAME.get(ff, "Red Fenrir")), Color(1.0, 0.85, 0.2) if ff == 4 else Color(0.2, 1.0, 0.5)])
			if ff == 4:
				lines.append(["Phiên bản đặc biệt chỉ trao cho MU Heroes", Color(0.2, 1.0, 0.5)])
			lines.append(["Triệu hồi Fenrir khi trang bị", Color(1.0, 0.85, 0.2)])
		lines.append(["Mạng: %d" % int(it.get("dur", 0)), white])

	# Ngọc: theo mô tả trong Source gốc (Items/Group12_Wing.json, Group14_Potion.json) và OpenMU (tỉ lệ thật)
	if is_jewel(it):
		var jg := int(it.get("group", 0))
		var jn := int(it.get("number", 0))
		var jc := Color(1.0, 0.88, 0.3)
		var good := Color(0.2, 1.0, 0.5)
		var bad := Color(1.0, 0.4, 0.4)
		if jg == 12 and jn != 15:
			# Cụm ngọc: cấp 0/1/2 = 10/20/30 viên (OpenMU MaximumItemLevel = 2)
			var cnt := (int(it.get("level", 0)) + 1) * 10
			var kind := {30: "Bless", 31: "Soul", 136: "Life", 137: "Creation", 138: "Guardian",
				139: "Gemstone", 140: "Harmony", 141: "Chaos", 142: "Lower Refining Stone", 143: "Higher Refining Stone"}
			lines.append(["Gộp %d viên %s" % [cnt, str(kind.get(jn, ""))], jc])
			lines.append(["Dùng được sau khi tách ra", white])
		else:
			match jn:
				13:
					if jg == 14:
						lines.append(["Dùng để nâng cấp trang bị lên tới +6", jc])
						lines.append(["Tỉ lệ thành công: 100%", good])
				14:
					if jg == 14:
						lines.append(["Dùng để nâng cấp trang bị lên +7, +8, +9", jc])
						lines.append(["Tỉ lệ thành công: 50% (75% nếu có May Mắn)", good])
						lines.append(["Thất bại: giảm 1 cấp (dưới +7) hoặc về +0 (từ +7)", bad])
				15:
					if jg == 12:
						lines.append(["Dùng để kết hợp đồ Chaos", jc])
				16:
					if jg == 14:
						lines.append(["Tăng thêm 1 cấp Tuỳ chọn của trang bị", jc])
						lines.append(["Tỉ lệ thành công: 50% (thất bại mất Tuỳ chọn)", good])
				22:
					if jg == 14:
						lines.append(["Dùng để tạo Quả tăng chỉ số", jc])
				31:
					if jg == 14:
						lines.append(["Tạo và nâng cấp vật phẩm công thành", jc])
				41:
					if jg == 14:
						lines.append(["Ngọc còn lẫn tạp chất", jc])
				42:
					if jg == 14:
						lines.append(["Ngọc dùng để cường hoá trang bị", jc])
				43, 44:
					if jg == 14:
						lines.append(["Ban sức mạnh thực cho trang bị đã cường hoá", jc])
				160:
					if jg == 14:
						lines.append(["Ngọc dùng để sửa Lucky Item", jc])
				161:
					if jg == 14:
						lines.append(["Ngọc dùng để cường hoá trang bị", jc])

	# Thông tin chi tiết Vật Phẩm Ép Đồ (Crafting & Chaos Materials)
	if is_crafting(it):
		var craft_col := Color(1.0, 0.65, 0.2)
		var cg := int(it.get("group", 0))
		var cn := int(it.get("number", 0))
		if cg == 13:
			match cn:
				14:
					lines.append(["🛠️ Công Thức Ép Cánh Cấp 2 (Wing 2)", craft_col])
					lines.append(["  + 1 Cánh Cấp 1 bất kỳ", white])
					lines.append(["  + 1 Lông Vũ Pha Lê (Loch's Feather)", craft_col])
					lines.append(["  + 1 Ngọc Hỗn Nguyên (Jewel of Chaos)", Color(0.4, 1.0, 0.4)])
					lines.append(["  + 1 Đồ Hoàn Hảo +4 trở lên (để tăng tỉ lệ)", Color(0.2, 1.0, 0.5)])
				31:
					lines.append(["🛠️ Công Thức Tạo Chiến Mã & Quạ Tinh", craft_col])
					lines.append(["  + 1 Huy Hiệu Hoàng Tộc / Linh Hồn Thú", craft_col])
					lines.append(["  + Ngọc Sáng Tạo (Creation) + Ngọc Chaos", Color(1.0, 0.88, 0.3)])
					lines.append(["  + Ngọc Bless + Soul theo cấp yêu cầu", white])
				32, 33:
					lines.append(["🛠️ Bước 1 Ép Sói Tinh (Fenrir)", craft_col])
					lines.append(["  + 20 Mảnh Áo Giáp Sói Tinh", craft_col])
					lines.append(["  + 20 Lời Chúc Bảo Hộ", craft_col])
					lines.append(["  + 1 Ngọc Hỗn Nguyên (Chaos)", Color(0.4, 1.0, 0.4)])
					lines.append(["  -> Tạo thành: Mảnh Sừng Gãy (Piece of Horn)", Color(1, 0.9, 0.4)])
				34, 35:
					lines.append(["🛠️ Bước 2 Ép Sói Tinh (Fenrir)", craft_col])
					lines.append(["  + 5 Mảnh Sừng Gãy (Piece of Horn)", craft_col])
					lines.append(["  + 10 Móng Vuốt Quái Thú (Claw of Beast)", craft_col])
					lines.append(["  + 1 Ngọc Hỗn Nguyên (Chaos)", Color(0.4, 1.0, 0.4)])
					lines.append(["  -> Tạo thành: Sừng Gãy (Broken Horn)", Color(1, 0.9, 0.4)])
				36:
					lines.append(["🛠️ Bước 3 Ép Sói Tinh (Fenrir Hoàn Chỉnh)", craft_col])
					lines.append(["  + 1 Sừng Gãy (Broken Horn)", craft_col])
					lines.append(["  + 3 Ngọc Sinh Mệnh (Jewel of Life)", Color(1.0, 0.9, 0.2)])
					lines.append(["  + 1 Ngọc Hỗn Nguyên (Chaos)", Color(0.4, 1.0, 0.4)])
					lines.append(["  -> Tạo thành: Thú Cưỡi Sói Tinh (Horn of Fenrir)", Color(1.0, 0.3, 0.2)])
				52:
					lines.append(["🛠️ Nguyên Liệu Tối Thượng Ép Cánh Cấp 3 (Wing 3)", Color(1.0, 0.3, 0.3)])
					lines.append(["  + Rơi tại vùng đất tử thần Barracks of Balgass", craft_col])
					lines.append(["  + Kết hợp cùng Lông Vũ Condor + Cánh 2 +9 4opt", white])
					lines.append(["  + 1 Ngọc Chaos + 1 Ngọc Creation + Cụm Bless/Soul", Color(0.4, 1.0, 0.4)])
				53:
					lines.append(["🛠️ Nguyên Liệu Ép Cánh Cấp 3 (Wing 3)", Color(0.8, 0.4, 1.0)])
					lines.append(["  + Tạo từ: Cánh 2 +9 4opt + Đồ Thần +7 + Chaos + Creation", white])
					lines.append(["  + Kết hợp cùng Ngọn Lửa Condor để tạo Cánh Cấp 3", craft_col])
				16, 17:
					var b_lv := int(it.get("level", 1))
					lines.append(["🛠️ Công Thức Ép Vé Huyết Lâu (Blood Castle)", craft_col])
					lines.append(["  + 1 Xương Máu (Blood Bone) +%d" % b_lv, craft_col])
					lines.append(["  + 1 Giấy Thiên Sứ (Scroll of Archangel) +%d" % b_lv, craft_col])
					lines.append(["  + 1 Ngọc Hỗn Nguyên (Jewel of Chaos)", Color(0.4, 1.0, 0.4)])
					lines.append(["  -> Tạo thành: Áo Tàng Hình +%d" % b_lv, Color(0.4, 0.8, 1.0)])
				18:
					var c_lv := int(it.get("level", 1))
					lines.append(["🏰 Vé Tham Gia Phó Bản Huyết Lâu (Blood Castle +%d)" % c_lv, Color(0.4, 0.8, 1.0)])
					lines.append(["  + Mang vé đến gặp NPC Thiên Sứ tại Lorencia/Noria/Devias", white])
					lines.append(["  + Phá cổng, giải cứu Thiên Sứ để nhận Ngọc và Vũ Khí", craft_col])
				29:
					lines.append(["⚔️ Vé Tham Gia Đấu Trường Hỗn Thần (Chaos Castle)", Color(1.0, 0.5, 0.3)])
					lines.append(["  + Sinh tồn chiến đấu giữa 100 chiến binh và quái vật", white])
					lines.append(["  + Sống sót cuối cùng nhận được Đồ Thần (Ancient) & Ngọc", craft_col])
		elif cg == 14:
			match cn:
				17, 18:
					var d_lv := int(it.get("level", 1))
					lines.append(["🛠️ Công Thức Ép Thiệp Quảng Trường Quỷ", craft_col])
					lines.append(["  + 1 Mắt Quỷ (Devil's Eye) +%d" % d_lv, craft_col])
					lines.append(["  + 1 Khóa Quỷ (Devil's Key) +%d" % d_lv, craft_col])
					lines.append(["  + 1 Ngọc Hỗn Nguyên (Jewel of Chaos)", Color(0.4, 1.0, 0.4)])
					lines.append(["  -> Tạo thành: Thiệp Lời Mời Quỷ +%d" % d_lv, Color(1.0, 0.8, 0.3)])
				19:
					var i_lv := int(it.get("level", 1))
					lines.append(["👹 Vé Tham Gia Quảng Trường Quỷ (Devil Square +%d)" % i_lv, Color(1.0, 0.8, 0.3)])
					lines.append(["  + Đến gặp NPC Charon để tiến vào sự kiện", white])
					lines.append(["  + Nơi luyện cấp EXP nhanh nhất lục địa MU Online", craft_col])
				11:
					lines.append(["🎁 Hộp Quà May Mắn: Thả ra đất để nhận Zen và ngọc quý", Color(1.0, 0.85, 0.3)])
				12:
					lines.append(["❤️ Trái Tim Tình Yêu: Thả ra đất để nhận vũ khí và giáp may mắn", Color(1.0, 0.4, 0.6)])
				55, 56, 57, 58, 59:
					var k_lv := cn - 54
					lines.append(["👑 Hộp Kundun +%d (Box of Kundun +%d)" % [k_lv, k_lv], Color(1.0, 0.85, 0.2)])
					lines.append(["  + Rơi từ Binh Đoàn Phù Thủy Trắng và Quái Vật Vàng", white])
					lines.append(["  + Ném ra đất để nhận Đồ Hoàn Hảo (Excellent) cấp cao!", Color(0.2, 1.0, 0.5)])
		elif (cg == 2 and cn == 6) or (cg == 4 and cn == 6) or (cg == 5 and cn == 7):
			lines.append(["🛠️ Vũ Khí Hỗn Nguyên (Chaos Weapon)", Color(0.4, 1.0, 0.4)])
			lines.append(["  + Nâng cấp lên +4 kèm 4 option trở lên", craft_col])
			lines.append(["  + Dùng làm nguyên liệu cốt lõi ép Cánh Cấp 1 (Wing 1)", Color(1.0, 0.85, 0.2)])
	if bool(it.get("skill", false)):
		lines.append(["Có kỹ năng vũ khí", blue])
	if bool(it.get("luck", false)):
		lines.append(["May mắn (tỉ lệ nâng cấp ngọc tâm linh +25%)", blue])
		lines.append(["May mắn (tỉ lệ chí mạng +5%)", blue])
	if int(it.get("opt", 0)) > 0:
		lines.append(["Tuỳ chọn thêm +%d" % (int(it.get("opt", 0)) * 4), blue])
	if bool(it.get("ancient", false)):
		var cyan := Color(0.1, 0.9, 0.8)
		lines.append(["★ Tính Năng Kích Hoạt Đồ Thần (Ancient)", cyan])
		lines.append(["  + Gia tăng sức mạnh +30 / Năng lượng +30", cyan])
		lines.append(["  + Sát thương chí mạng +15% / Hoàn hảo +15%", cyan])
		lines.append(["  + Tỉ lệ loại bỏ phòng ngự đối phương +5%", cyan])
	if bool(it.get("excellent", false)):
		lines.append(["Excellent", Color(0.1, 1.0, 0.5)])
	if bool(it.get("purple", false)) or bool(it.get("option_380", false)):
		var purple := Color(0.88, 0.45, 1.0)
		lines.append(["★ Tính Năng Gia Cường 380 (Dòng Tím)", purple])
		var g := int(it.get("group", 0))
		if g <= 5:
			lines.append(["  + Gia tăng sức tấn công PvP +200", purple])
			lines.append(["  + Gia tăng tỉ lệ tấn công SD PvP +10", purple])
		elif g <= 11:
			lines.append(["  + Gia tăng sức phòng thủ SD +100", purple])
			lines.append(["  + Tự động hồi phục lượng SD", purple])
			lines.append(["  + Gia tăng phòng thủ PvP +200", purple])
		else:
			lines.append(["  + Khảm Ngọc Nguyên Tố Socket Tím", purple])
			lines.append(["  + Tăng sát thương & hấp thụ hoàn hảo", purple])
	if bool(it.get("harmony", false)):
		var yellow := Color(1.0, 0.85, 0.2)
		var g := int(it.get("group", 0))
		lines.append(["★ Tính Năng Đá Tạo Hóa (Jewel of Harmony)", yellow])
		if g <= 5:
			lines.append(["  + Gia tăng lực đánh chí mạng +30", yellow])
			lines.append(["  + Tỉ lệ loại bỏ phòng thủ SD +10%", yellow])
		else:
			lines.append(["  + Gia tăng sức phòng thủ +35", yellow])
			lines.append(["  + Giảm sát thương phòng thủ 7%", yellow])
	if bool(it.get("socket", false)):
		var violet := Color(0.88, 0.45, 1.0)
		lines.append(["★ Khảm 5 Lỗ Ngọc Nguyên Tố Socket", violet])
		lines.append(["  [1-Lửa] Sát thương tối đa +30", violet])
		lines.append(["  [2-Sét] Tỉ lệ sát thương hoàn hảo +12%", violet])
		lines.append(["  [3-Băng] Sát thương kỹ năng +37", violet])
		lines.append(["  [4-Gió] Tốc độ hồi phục SD +20", violet])
		lines.append(["  [5-Nước] Giảm sát thương +8%", violet])
		lines.append(["  [Phụ Trội] Tăng sát thương hoàn hảo +40", violet])
	if is_wing(it) and int(it.get("level", 0)) >= 9:
		var wing_col := Color(0.9, 0.7, 1.0)
		lines.append(["★ Thuộc Tính Cánh Cấp Cao", wing_col])
		lines.append(["  + 5% Cơ hội hồi phục hoàn toàn HP / SD", wing_col])
		lines.append(["  + 3% Tấn công loại bỏ phòng ngự đối phương", wing_col])
	if price >= 0:
		lines.append(["%s: %s Zen" % [price_label, format_zen(price)], Color(1.0, 0.85, 0.3)])
	return lines

static func format_zen(n: int) -> String:
	var s := str(n)
	var res := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		c += 1
		if c % 3 == 0 and i > 0:
			res = "," + res
	return res

## Trả về danh sách các vật phẩm thuộc một sự kiện cụ thể
static func get_event_bundle_items(category_id: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	match category_id:
		-551: # Blood Castle (Lâu Đài Máu)
			for lv in range(1, 9):
				list.append(make(13, 18, lv)) # Invisibility Cloak +1..+8
			for lv in range(1, 9):
				list.append(make(13, 16, lv)) # Scroll of Archangel +1..+8
			for lv in range(1, 9):
				list.append(make(13, 17, lv)) # Blood Bone +1..+8
			list.append(make(13, 19, 0)) # Absolute Weapon of Archangel
			list.append(make(13, 47, 0)) # Blood Castle Ticket
			list.append(make(12, 15, 0)) # Ngọc Chaos để ép
		-552: # Devil Square (Quảng Trường Quỷ)
			for lv in range(1, 8):
				list.append(make(14, 19, lv)) # Devil's Invitation +1..+7
			for lv in range(1, 8):
				list.append(make(14, 17, lv)) # Devil's Eye +1..+7
			for lv in range(1, 8):
				list.append(make(14, 18, lv)) # Devil's Key +1..+7
			list.append(make(13, 46, 0)) # Devil Square Ticket
			list.append(make(12, 15, 0)) # Ngọc Chaos để ép
		-553: # Chaos Castle (Hỗn Nguyên Lâu)
			for lv in range(1, 8):
				list.append(make(13, 29, lv)) # Armor of Guardsman +1..+7
			list.append(make(13, 121, 0)) # Chaos Castle Access Ticket
		-554: # Kalima & Kundun
			for lv in range(1, 8):
				list.append(make(14, 28, lv)) # Lost Map +1..+7
			for lv in range(1, 8):
				list.append(make(14, 29, lv)) # Symbol of Kundun +1..+7
			list.append(make(13, 48, 0)) # Kalima Ticket
		-556: # Illusion Temple (Đền Ảo Ảnh)
			for lv in range(1, 7):
				list.append(make(13, 51, lv)) # Scroll of Blood +1..+6
			for lv in range(1, 7):
				list.append(make(13, 49, lv)) # Old Scroll +1..+6
			for lv in range(1, 7):
				list.append(make(13, 50, lv)) # Illusion Covenant +1..+6
			list.append(make(13, 61, 0)) # Illusion Temple Ticket
			list.append(make(12, 15, 0)) # Ngọc Chaos để ép
		-557: # Crywolf, Kanturu & Castle Siege
			list.append(make(13, 7, 0))  # Contract of Summon Crywolf
			list.append(make(13, 38, 0)) # Moonstone Pendant Kanturu
			list.append(make(13, 11, 1)) # Life Stone (Castle Siege)
			list.append(make(13, 31, 0)) # Crest of Monarch
			list.append(make(14, 21, 0)) # Sign of Lord
			list.append(make(14, 7, 0))  # Potion of Bless
			list.append(make(14, 7, 1))  # Potion of Soul
		-558: # Imperial Guardian & Doppelganger
			list.append(make(14, 102, 0)) # Gaion's Order
			list.append(make(14, 109, 0)) # Complete Secromicon
			for frag in range(103, 109):
				list.append(make(14, frag, 0)) # Fragments 1..6
			list.append(make(14, 111, 0)) # Mirror of Dimensions
			list.append(make(14, 110, 0)) # Sign of Dimensions
			list.append(make(13, 125, 0)) # Ticket to Doppelganger
			list.append(make(13, 126, 0)) # Ticket to Varka
			list.append(make(13, 127, 0)) # Ticket to Varka Map 7
		-559: # Nhiệm Vụ Chuyển Cấp 2 & 3
			list.append(make(14, 23, 0)) # Scroll of the Emperor
			list.append(make(14, 24, 0)) # Broken Sword
			list.append(make(14, 25, 0)) # Tear of Elf
			list.append(make(14, 26, 0)) # Soul Shard of Wizard
			list.append(make(14, 65, 0)) # Death-beam Knight Flame
			list.append(make(14, 67, 0)) # Dark Phoenix Feather
			list.append(make(14, 68, 0)) # Abyssal Eye
			list.append(make(13, 53, 0)) # Condor Feather
			list.append(make(13, 52, 0)) # Condor Flame
		-560: # Hộp Báu Kundun & Hộp Quà Lễ Hội
			for k in range(55, 60):
				list.append(make(14, k, 0)) # Box of Kundun +1..+5
			list.append(make(14, 11, 0)) # Box of Luck
			list.append(make(14, 12, 0)) # Heart of Love
			list.append(make(14, 84, 0)) # Cherry Blossom Play-Box
			list.append(make(14, 32, 0)) # Pink Chocolate
			list.append(make(14, 33, 0)) # Red Chocolate
			list.append(make(14, 34, 0)) # Blue Chocolate
			list.append(make(13, 66, 0)) # Invitation to Santa Village
			list.append(make(14, 123, 0)) # Golden Box
			list.append(make(14, 124, 0)) # Silver Box
			list.append(make(14, 113, 0)) # Gold Key
			list.append(make(14, 112, 0)) # Silver Key
			list.append(make(14, 63, 0)) # Firecracker
	return list

## Trả về bộ vé đi TOÀN BỘ các sự kiện trong game (mỗi sự kiện 1 vé mọi cấp độ)
static func get_all_event_tickets() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	# 1. Blood Castle 1..8
	for lv in range(1, 9):
		list.append(make(13, 18, lv))
	# 2. Devil Square 1..7
	for lv in range(1, 8):
		list.append(make(14, 19, lv))
	# 3. Chaos Castle 1..7
	for lv in range(1, 8):
		list.append(make(13, 29, lv))
	# 4. Kalima 1..7
	for lv in range(1, 8):
		list.append(make(14, 28, lv))
	# 5. Illusion Temple 1..6
	for lv in range(1, 7):
		list.append(make(13, 51, lv))
	# 6. Phó bản & Sự kiện đặc biệt
	list.append(make(14, 102, 0)) # Lệnh Bài Gaion
	list.append(make(14, 109, 0)) # Sách Khải Huyền Hoàn Chỉnh
	list.append(make(14, 111, 0)) # Gương Không Gian (Doppelganger)
	list.append(make(13, 66, 0))  # Thiệp Mời Làng Santa
	list.append(make(13, 7, 0))   # Hợp Đồng Triệu Hồi Crywolf
	list.append(make(13, 38, 0))  # Dây Chuyền Mặt Trăng Kanturu
	list.append(make(13, 11, 1))  # Life Stone (Công Thành Chiến)
	list.append(make(13, 31, 0))  # Huy Hiệu Hoàng Tộc
	# 7. Hộp Kundun +1..+5
	for k in range(55, 60):
		list.append(make(14, k, 0))
	return list
