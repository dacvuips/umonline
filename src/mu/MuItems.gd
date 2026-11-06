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
	"12:15": "Ngọc Hỗn Nguyên (Jewel of Chaos)",
	"12:30": "Cụm Ngọc Ước Nguyện (Bundle of Jewel of Bless)",
	"12:31": "Cụm Ngọc Tâm Linh (Bundle of Jewel of Soul)",
	"12:136": "Cụm Ngọc Sinh Mệnh (Bundle of Jewel of Life)",
	"12:137": "Cụm Ngọc Sáng Tạo (Bundle of Jewel of Creation)",
	"12:138": "Cụm Ngọc Hộ Mệnh (Bundle of Jewel of Guardian)",
	"12:139": "Cụm Đá Nguyên Thủy (Bundle of Gemstone)",
	"12:140": "Cụm Đá Tạo Hóa (Bundle of Jewel of Harmony)",
	"12:141": "Cụm Ngọc Hỗn Nguyên (Bundle of Jewel of Chaos)",
	"14:13": "Ngọc Ước Nguyện (Jewel of Bless)",
	"14:14": "Ngọc Tâm Linh (Jewel of Soul)",
	"14:16": "Ngọc Sinh Mệnh (Jewel of Life)",
	"14:22": "Ngọc Sáng Tạo (Jewel of Creation)",
	"14:31": "Ngọc Hộ Mệnh (Jewel of Guardian)",
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
}

static func make(group: int, number: int, level: int = 0, extra: Dictionary = {}) -> Dictionary:
	var it := {"group": group, "number": number, "level": level, "excellent": false, "luck": false,
		"skill": false, "opt": 0, "dur": 0, "x": 0, "y": 0}
	it.merge(extra, true)
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
	var s := base_name(it)
	if bool(it.get("ancient", false)):
		s = "[Thần] " + s
	if bool(it.get("excellent", false)):
		s = "Excellent " + s
	if bool(it.get("purple", false)) or bool(it.get("option_380", false)):
		s = "[Tím 380] " + s
	if bool(it.get("socket", false)):
		s = "[Socket] " + s
	var lv := int(it.get("level", 0))
	var g := int(it.get("group", 0))
	if lv > 0 and g != 14 and g != 15 and g != 12 or (g == 12 and is_wing(it) and lv > 0):
		s += " +%d" % lv
	if int(it.get("dur", 0)) > 1 and (g == 14 or (g == 4 and (int(it.get("number", 0)) == 7 or int(it.get("number", 0)) == 15))):
		s += " x%d" % int(it.get("dur", 0))
	return s

## Màu tên giống ItemNameColor của MU: Xanh ngọc cho Đồ Thần, Tím cho Đồ Tím/Socket, Excellent xanh lá, +7.. vàng, +4.. xanh nhạt, còn lại trắng
static func name_color(it: Dictionary) -> Color:
	if bool(it.get("ancient", false)):
		return Color(0.1, 0.9, 0.8)
	if bool(it.get("socket", false)) or bool(it.get("purple", false)) or bool(it.get("option_380", false)):
		return Color(0.88, 0.45, 1.0)
	if bool(it.get("excellent", false)):
		return Color(0.1, 1.0, 0.5)
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

## Ô trang bị của nhân vật: helm/armor/pants/gloves/boots/right/left/wings/helper/amulet/ring ("" = không mặc được)
static func equip_slot(it: Dictionary) -> String:
	var g := int(it.get("group", 0))
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

## Các dòng mô tả (tooltip) [[chữ, màu], ...] — bố cục như ItemExplanationWindow
static func tooltip(it: Dictionary, price_label: String = "", price: int = -1) -> Array:
	var inf := info(it)
	var lines := []
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
	if int(inf.get("durability", 0)) > 0:
		lines.append(["Độ bền: [%d/%d]" % [int(it.get("dur", 0)), max_durability(it)], white])
	elif int(it.get("dur", 0)) > 1:
		lines.append(["Số lượng: %d" % int(it.get("dur", 0)), white])
	var req: Dictionary = inf.get("requirements", {}) if inf.get("requirements") is Dictionary else {}
	var names := {"level": "Cấp", "strength": "Sức mạnh", "dexterity": "Nhanh nhẹn", "energy": "Năng lượng", "vitality": "Thể lực", "command": "Mệnh lệnh"}
	for k in req:
		lines.append(["Yêu cầu %s: %d" % [names.get(k, k), int(req[k])], white])
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
