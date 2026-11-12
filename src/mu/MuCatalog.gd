extends RefCounted
class_name MuCatalog

## Danh mục dữ liệu gốc của client MU (chép bởi tools/mu_convert_all.py vào assets/mu/catalog):
##   Monsters/Monsters.json  : số hiệu quái / NPC -> tên, loại, model slot
##   Monsters/Models.json    : model slot -> file .bmd, tốc độ animation, headBone, linkBones
##   Items/Models/GroupXX.json: (nhóm, số) item -> file .bmd, màu phát sáng
##   Effects/GlowColors.json : bảng màu phát sáng theo tên
## Mọi đường dẫn "Data/<Thư mục>/<tên>.bmd" được đổi thành "res://assets/mu/<Thư mục>/<tên>.glb"

const ROOT := "res://assets/mu/"
const CAT := "res://assets/mu/catalog/"

# Lớp nhân vật (CLASS_* của MU)
enum CharClass { DARK_WIZARD, DARK_KNIGHT, FAIRY_ELF, MAGIC_GLADIATOR, DARK_LORD, SUMMONER, RAGE_FIGHTER }

# Nhóm item
const GROUP_SWORD := 0
const GROUP_AXE := 1
const GROUP_MACE := 2
const GROUP_SPEAR := 3
const GROUP_BOW := 4
const GROUP_STAFF := 5
const GROUP_SHIELD := 6
const GROUP_HELM := 7
const GROUP_ARMOR := 8
const GROUP_PANTS := 9
const GROUP_GLOVES := 10
const GROUP_BOOTS := 11
const GROUP_WING := 12

const ITEM_GROUP_FILES := {
	0: "Group00_Sword.json", 1: "Group01_Axe.json", 2: "Group02_Mace.json", 3: "Group03_Spear.json",
	4: "Group04_Bow.json", 5: "Group05_Staff.json", 6: "Group06_Shield.json", 7: "Group07_Helm.json",
	8: "Group08_Armor.json", 9: "Group09_Pants.json", 10: "Group10_Gloves.json", 11: "Group11_Boots.json",
	12: "Group12_Wing.json", 13: "Group13_Helper.json", 14: "Group14_Potion.json", 15: "Group15_Etc.json",
}

static var _loaded := false
static var monsters_by_number: Dictionary = {}
static var monsters_by_name: Dictionary = {}
static var models_by_slot: Dictionary = {}
static var item_models: Dictionary = {}   # "g:n" -> Dictionary (Items/Models: file, glow ...)
static var item_data: Dictionary = {}     # "g:n" -> Dictionary (Items: name, weaponKind, twoHanded, slot ...)
static var glow_colors: Dictionary = {}   # tên -> Color

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var txt := FileAccess.get_file_as_string(path)
	var res = JSON.parse_string(txt)
	if res == null:
		push_warning("[MuCatalog] Lỗi đọc " + path)
	return res

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var mons = _read_json(CAT + "Monsters/Monsters.json")
	if mons is Dictionary:
		for m in mons.get("monsters", []):
			monsters_by_number[int(m.get("number", -1))] = m
			var nm = m.get("name", {})
			var en: String = nm.get("en", "") if nm is Dictionary else str(nm)
			if en != "":
				monsters_by_name[en.to_lower()] = m
	var models = _read_json(CAT + "Monsters/Models.json")
	if models is Dictionary:
		for m in models.get("models", []):
			models_by_slot[m.get("slot", "")] = m
	for g in ITEM_GROUP_FILES:
		var d = _read_json(CAT + "Items/Models/" + ITEM_GROUP_FILES[g])
		if d is Dictionary:
			for m in d.get("models", []):
				item_models["%d:%d" % [g, int(m.get("number", 0))]] = m
		var di = _read_json(CAT + "Items/" + ITEM_GROUP_FILES[g])
		if di is Dictionary:
			for it in di.get("items", []):
				it["group"] = g
				it["number"] = int(it.get("number", 0))
				item_data["%d:%d" % [g, int(it.get("number", 0))]] = it
	var gc = _read_json(CAT + "Effects/GlowColors.json")
	if gc is Dictionary:
		var cols: Dictionary = gc.get("colors", {})
		for k in cols:
			var a: Array = cols[k]
			glow_colors[k] = Color(a[0], a[1], a[2])
	print("[MuCatalog] %d quái/NPC, %d model, %d item" % [monsters_by_number.size(), models_by_slot.size(), item_models.size()])

## "Data/Monster/Monster01.bmd" -> "res://assets/mu/Monster/Monster01.glb"
static func bmd_to_glb(file: String) -> String:
	var f := file.replace("\\", "/")
	if f.begins_with("Data/"):
		f = f.substr(5)
	return ROOT + f.get_basename() + ".glb"

static func color_named(name, fallback: Color) -> Color:
	ensure_loaded()
	if name is String and glow_colors.has(name):
		return glow_colors[name]
	if name is Array and name.size() >= 3:
		return Color(name[0], name[1], name[2])
	return fallback

# ------------------------------------------------------------- quái & NPC
static func find_monster(number: int = -1, name: String = "") -> Dictionary:
	ensure_loaded()
	if number >= 0 and monsters_by_number.has(number):
		return monsters_by_number[number]
	if name != "":
		var key := name.to_lower()
		if monsters_by_name.has(key):
			return monsters_by_name[key]
		# khớp gần đúng: "Lorencia Guard East" -> "Guard", "Han the Blacksmith" -> "... Blacksmith"
		for k in monsters_by_name:
			if key.contains(k) or k.contains(key):
				return monsters_by_name[k]
		var words := key.split(" ", false)
		for w in words:
			if w.length() < 4 or w == "the":
				continue
			for k in monsters_by_name:
				if k.contains(w):
					return monsters_by_name[k]
	return {}

static func monster_model(mon: Dictionary) -> Dictionary:
	ensure_loaded()
	return models_by_slot.get(mon.get("model", ""), {})

## Bảng tra cứu tên tiếng Việt chuẩn MU Online cho các kỹ năng
const VIETNAMESE_SKILL_NAMES := {
	0: "Đánh Thường",
	1: "Độc Tố (Poison)",
	2: "Mưa Sao Băng (Meteorite)",
	3: "Tia Sét (Lightning)",
	4: "Cầu Lửa (Fireball)",
	5: "Hỏa Diệm (Flame)",
	6: "Dịch Chuyển (Teleport)",
	7: "Băng Lan (Ice)",
	8: "Cơn Lốc (Twister)",
	9: "Linh Hồn Quỷ (Evil Spirit)",
	10: "Lửa Địa Ngục (Hellfire)",
	11: "Sóng Năng Lượng (Power Wave)",
	12: "Tia Nước (Aqua Beam)",
	13: "Sao Băng Rơi (Cometfall)",
	14: "Vòng Tròn Lửa (Inferno)",
	15: "Dịch Chuyển Đồng Đội (Teleport Ally)",
	16: "Vòng Tròn Ma Thuật (Soul Barrier)",
	17: "Quả Cầu Năng Lượng (Energy Ball)",
	18: "Phòng Thủ (Defense)",
	19: "Chém Xuống (Falling Slash)",
	20: "Đâm Lao (Lunge)",
	21: "Chém Ngược (Uppercut)",
	22: "Chém Xoáy (Cyclone)",
	23: "Chém Ngang (Slash)",
	24: "Tam Tiễn (Triple Shot)",
	25: "Bắn Nỏ (Crossbow Shoot)",
	26: "Hồi Máu (Heal)",
	27: "Tăng Phòng Thủ (Greater Defense)",
	28: "Tăng Sức Đánh (Greater Damage)",
	30: "Gọi Yêu Tinh (Summon Goblin)",
	31: "Gọi Người Đá (Summon Golem)",
	32: "Gọi Sát Thủ (Summon Assassin)",
	33: "Gọi Người Tuyết (Summon Yeti)",
	34: "Gọi Hắc Hiệp Sĩ (Summon Dark Knight)",
	35: "Gọi Quái Vật Bali (Summon Bali)",
	36: "Gọi Chiến Binh (Summon Soldier)",
	38: "Chưởng Độc (Decay)",
	39: "Mưa Băng Tuyết (Ice Storm)",
	40: "Gồng Năng Lượng (Nova)",
	41: "Xoay Kiếm (Twisting Slash)",
	42: "Cuồng Nộ (Rageful Blow)",
	43: "Đâm Gió (Death Stab)",
	44: "Chém Trăng Khuyết (Crescent Moon)",
	47: "Đâm Giáo (Impale)",
	48: "Gồng Máu (Greater Fortitude)",
	49: "Cưỡi Ngựa (Rider)",
	51: "Băng Tiễn (Ice Arrow)",
	52: "Xuyên Tâm Tiễn (Penetration)",
	55: "Chém Lửa (Fire Slash)",
	56: "Chém Quét (Power Slash)",
	57: "Chém Xoắn Ốc (Spiral Slash)",
	60: "Hỏa Lực (Force)",
	61: "Hỏa Long (Fireburst)",
	62: "Địa Chấn (Earthshake)",
	63: "Triệu Hồi Đồng Đội (Summon Party)",
	64: "Tăng Chí Mạng (Critical Damage)",
	65: "Tia Chớp Điện (Electric Spark)",
	66: "Sóng Lực (Force Wave)",
	76: "Bão Điện Sói Tinh (Plasma Storm)",
	77: "Vô Hạn Tiễn (Infinity Arrow)",
	78: "Hỏa Thần Long (Fire Scream)",
	214: "Hút Máu (Drain Life)",
	215: "Tia Sét Lan (Chain Lightning)",
	216: "Quả Cầu Sét (Lightning Orb)",
	217: "Phản Đòn (Damage Reflection)",
	218: "Cuồng Bạo (Berserker)",
	219: "Ru Ngủ (Sleep)",
	220: "Làm Mù (Blind)",
	221: "Yếu Đuối (Weakness)",
	222: "Giảm Sức (Enervation)",
	223: "Bộc Phá (Explosion)",
	224: "Chiêu Hồn (Requiem)",
	225: "Ô Nhiễm (Pollution)",
	230: "Sốc Điện (Lightning Shock)",
	232: "Cú Đánh Hủy Diệt (Destruction)",
	233: "Khai Sáng Phép (Expansion)",
	234: "Hồi Phục Sinh Lực (Recover)",
	235: "Ngũ Tiễn (Multi-Shot)",
	236: "Cột Lửa Hắc Ám (Flame Strike)",
	237: "Bão Tố Khổng Lồ (Gigantic Storm)",
	238: "Hỗn Loạn Thần Bí (Chaotic Diseier)",
	260: "Cú Đấm Hủy Diệt (Killing Blow)",
	261: "Cú Đấm Mãnh Thú (Beast Uppercut)",
	262: "Liên Hoàn Kích (Chain Drive)",
	263: "Hắc Ảnh Quyền (Dark Side)",
	264: "Hống Long Quyền (Dragon Roar)",
	265: "Trảm Long Đao (Dragon Slasher)",
	266: "Hỏa Phượng Hoàn (Phoenix Shot)",
	267: "Thách Thức (Defiance)",
	268: "Thể Lực (Fitness)",
}

## Đường dẫn Texture Icon chuẩn cho từng Kỹ Năng
static func get_skill_icon_path(number: int) -> String:
	if number == 0:
		return "res://assets/textures/ui/skills/skill_0.png"
	var p := "res://assets/textures/ui/skills/skill_%d.png" % number
	if ResourceLoader.exists(p):
		return p
	# Fallback kiểm tra trong skills_extracted
	if number >= 1 and number <= 64:
		var r := (number - 1) / 8
		var c := (number - 1) % 8
		var p_ext := "res://assets/textures/ui/skills_extracted/skill_%d_%d.png" % [r, c]
		if ResourceLoader.exists(p_ext):
			return p_ext
	return "res://assets/textures/ui/skills/skill_0.png"

## Đường dẫn Texture Icon xám (chưa học) cho từng Kỹ Năng
static func get_skill_grey_icon_path(number: int) -> String:
	if number == 0:
		return "res://assets/textures/ui/skills/skill_0.png"
	var p := "res://assets/textures/ui/skills_grey/skill_%d.png" % number
	if ResourceLoader.exists(p) or FileAccess.file_exists(p):
		return p
	return get_skill_icon_path(number)

## Lấy tên kỹ năng có bản dịch tiếng Việt chuẩn MU Online
static func get_skill_vietnamese_name(number: int, default_name: String = "") -> String:
	if VIETNAMESE_SKILL_NAMES.has(number):
		return VIETNAMESE_SKILL_NAMES[number]
	if default_name != "":
		return default_name
	var sk := skill(number)
	return str(sk.get("name", "Kỹ năng %d" % number))

# ------------------------------------------------------------- chỉ số quái + skill (tools/mu_gamedata.py)
static var _monster_stats = null
static var _skills = null

## Chỉ số quái của server OpenMU: {name, level, hp, dmg_min, dmg_max, def, atk_rate, def_rate, move_range,
## attack_range, view_range, move_delay, attack_delay (ms), respawn (giây)} ; {} nếu không có
static func monster_stats(number: int) -> Dictionary:
	if _monster_stats == null:
		var d = _read_json(ROOT + "monster_stats.json")
		_monster_stats = d if d is Dictionary else {}
	return _monster_stats.get(str(number), {})

static func _skill_data() -> Dictionary:
	if _skills == null:
		var d = _read_json(ROOT + "skills.json")
		if d is Dictionary:
			var s_dict = d.get("skills", {})
			if s_dict is Dictionary:
				for k in s_dict:
					var sk = s_dict[k]
					if sk is Dictionary and sk.has("classes"):
						var int_classes: Array = []
						for c in sk["classes"]:
							int_classes.append(int(c))
						sk["classes"] = int_classes
			_skills = d
		else:
			_skills = {}
	return _skills

## Trả về toàn bộ danh mục kỹ năng từ skills.json
static func get_all_skills() -> Dictionary:
	var s = _skill_data().get("skills", {})
	return s if s is Dictionary else {}

## Skill theo số (SkillNumber của OpenMU): {name, key, classes, damage_type, damage, distance, mana, ag, level,
## energy, leadership, element, type, target, range, moves_to_target, cooldown}
static func skill(number: int) -> Dictionary:
	var s = _skill_data().get("skills", {})
	return s.get(str(number), {}) if s is Dictionary else {}

## Tìm ID kỹ năng theo tên (ví dụ: "Meteorite", "Lightning", "PowerWave", "Fire Ball")
static func find_skill_by_name(skill_name: String) -> int:
	if skill_name.is_empty():
		return -1
	var s: Dictionary = get_all_skills()
	var clean := skill_name.to_lower().replace(" ", "").replace("_", "")
	for k in s:
		var sn := str(s[k].get("name", "")).to_lower().replace(" ", "").replace("_", "")
		if sn == clean:
			return int(k)
	return -1

## Orb / scroll / parchment dạy skill: {skill, level, energy, strength, agility, leadership, classes: {"lớp": cấp}}
static func skill_item(group: int, number: int) -> Dictionary:
	var s = _skill_data().get("items", {})
	return s.get("%d:%d" % [group, number], {}) if s is Dictionary else {}

# ------------------------------------------------------------- item
const MODEL_NAME_TO_GLB := {
	# Sinh từ Source/src/bin/Data/Items/Models/SharedModels.json (tên model dùng chung -> file)
	"capeOfFighter": "res://assets/mu/Item/Wing50.glb",
	"capeOfLord": "res://assets/mu/Item/DarkLordRobe.glb",
	"chaosCard": "res://assets/mu/Item/partCharge3/juju.glb",
	"characterCard": "res://assets/mu/Item/Ingameshop/charactercard.glb",
	"darkLordScroll": "res://assets/mu/Item/skillScroll.glb",
	"eliteHealingPotion": "res://assets/mu/Item/partCharge2/EPotionR.glb",
	"gemstone": "res://assets/mu/Item/rs.glb",
	"goldenBox": "res://assets/mu/Item/Ingameshop/itembox_gold.glb",
	"higherRefiningStone": "res://assets/mu/Item/HighRefineStone.glb",
	"jackOLanternScroll": "res://assets/mu/Item/hellowinscroll.glb",
	"jewelOfBless": "res://assets/mu/Item/Jewel01.glb",
	"jewelOfChaos": "res://assets/mu/Item/Jewel15.glb",
	"jewelOfCreation": "res://assets/mu/Item/jewel22.glb",
	"jewelOfGuardian": "res://assets/mu/Item/suho.glb",
	"jewelOfHarmony": "res://assets/mu/Item/jos.glb",
	"jewelOfLife": "res://assets/mu/Item/Jewel03.glb",
	"jewelOfSoul": "res://assets/mu/Item/Jewel02.glb",
	"lowerRefiningStone": "res://assets/mu/Item/LowRefineStone.glb",
	"luckyTicketGreen": "res://assets/mu/Item/LuckyItem/LuckyCardgreen.glb",
	"luckyTicketRed": "res://assets/mu/Item/LuckyItem/LuckyCardred.glb",
	"membershipItem": "res://assets/mu/Item/Ingameshop/primium_membership_item.glb",
	"packageBox": "res://assets/mu/Item/Ingameshop/package_money_item.glb",
	"secromiconFragment": "res://assets/mu/Item/secromicon_piece.glb",
	"seedSphere1": "res://assets/mu/Item/s30_sphere01.glb",
	"seedSphere2": "res://assets/mu/Item/s30_sphere02.glb",
	"seedSphere3": "res://assets/mu/Item/s30_sphere03.glb",
	"seedSphere4": "res://assets/mu/Item/s30_sphere04.glb",
	"seedSphere5": "res://assets/mu/Item/s30_sphere05.glb",
	"silverBox": "res://assets/mu/Item/Ingameshop/itembox_silver.glb",
	"skillCrystal": "res://assets/mu/Item/Gem06.glb",
	"skillParchment": "res://assets/mu/Item/rollofpaper.glb",
	"socketSeed": "res://assets/mu/Item/s30_seed.glb",
	"transformationRing": "res://assets/mu/Item/Ring01.glb",
	"wizardScroll": "res://assets/mu/Item/Book18.glb",
}

const DIRECT_ITEM_GLB := {
	# Ngọc Quý (Jewels & Bundles)
	"14:13": "res://assets/mu/Item/Jewel01.glb",
	"14:14": "res://assets/mu/Item/Jewel02.glb",
	"12:15": "res://assets/mu/Item/Jewel03.glb",
	"14:16": "res://assets/mu/Item/Jewel15.glb",
	"14:22": "res://assets/mu/Item/jewel22.glb",
	"14:31": "res://assets/mu/Item/suho.glb",
	"14:41": "res://assets/mu/Item/Gem01.glb",
	"14:42": "res://assets/mu/Item/Gem02.glb",
	"14:43": "res://assets/mu/Item/LowRefineStone.glb",
	"14:44": "res://assets/mu/Item/HighRefineStone.glb",
	"12:30": "res://assets/mu/Item/Jewel01.glb",
	"12:31": "res://assets/mu/Item/Jewel02.glb",
	"12:136": "res://assets/mu/Item/Jewel15.glb",
	"12:137": "res://assets/mu/Item/jewel22.glb",
	"12:138": "res://assets/mu/Item/suho.glb",
	"12:139": "res://assets/mu/Item/Gem01.glb",
	"12:140": "res://assets/mu/Item/Gem02.glb",
	"12:141": "res://assets/mu/Item/Jewel03.glb",
	# Thú Cưỡi & Thần Thú (Mounts & Pets)
	"13:0": "res://assets/mu/Player/Helper01.glb",
	"13:1": "res://assets/mu/Player/Helper02.glb",
	"13:2": "res://assets/mu/Player/Helper03.glb",
	"13:3": "res://assets/mu/Player/Helper04.glb",
	"13:4": "res://assets/mu/Item/DarkHorseHorn.glb",
	"13:5": "res://assets/mu/Item/spiritbill.glb",
	"13:37": "res://assets/mu/Item/FR_6.glb",
	"13:80": "res://assets/mu/Item/PandaPet.glb",
	"13:123": "res://assets/mu/Item/skeletonpet.glb",
	# Vật Phẩm Ép Đồ (Crafting & Chaos Materials)
	"13:14": "res://assets/mu/Item/Quest04.glb",
	"13:16": "res://assets/mu/Item/EventBloodCastle00.glb",
	"13:17": "res://assets/mu/Item/EventBloodCastle01.glb",
	"13:18": "res://assets/mu/Item/EventBloodCastle02.glb",
	"13:29": "res://assets/mu/Item/EventChaosCastle.glb",
	"13:30": "res://assets/mu/Item/wing08.glb",
	"13:31": "res://assets/mu/Item/DarkHorseSoul.glb",
	"13:32": "res://assets/mu/Item/FR_1.glb",
	"13:33": "res://assets/mu/Item/FR_2.glb",
	"13:34": "res://assets/mu/Item/FR_3.glb",
	"13:35": "res://assets/mu/Item/FR_4.glb",
	"13:36": "res://assets/mu/Item/FR_5.glb",
	"13:52": "res://assets/mu/Item/condolstone.glb",
	"13:53": "res://assets/mu/Item/condolwing.glb",
	"14:17": "res://assets/mu/Item/Devil00.glb",
	"14:18": "res://assets/mu/Item/Devil01.glb",
	"14:19": "res://assets/mu/Item/Devil02.glb",
	"13:8": "res://assets/mu/Item/Ring01.glb",
	"13:10": "res://assets/mu/Item/Ring01.glb",
}

static func item_model(group: int, number: int) -> Dictionary:
	ensure_loaded()
	var key := "%d:%d" % [group, number]
	var m: Dictionary = item_models.get(key, {})
	if m.is_empty():
		m = {}
	# Đảm bảo có inventory & glow hợp lý nếu bị thiếu
	if not m.has("inventory"):
		if (group == 14 and number in [13, 14, 16, 22, 31, 41, 42, 43, 44]) or (group == 12 and number in [15, 30, 31, 136, 137, 138, 139, 140, 141]):
			m["inventory"] = {"anchor": [0.5, 0.95], "scale": 0.0035}
			if not m.has("glow"):
				m["glow"] = {"level": 8}
		elif group == 13 and number in [2, 3, 4, 37]:
			m["inventory"] = {"anchor": [0.5, 0.7], "scale": 0.004}
	return m

static func item_info(group: int, number: int) -> Dictionary:
	ensure_loaded()
	return item_data.get("%d:%d" % [group, number], {})

static func item_name(group: int, number: int) -> String:
	var nm = item_info(group, number).get("name", "")
	return str(nm.get("en", "")) if nm is Dictionary else str(nm)

static func item_glb(group: int, number: int) -> String:
	var m := item_model(group, number)
	var f: String = str(m.get("file", ""))
	if f != "" and f != "null":
		var p := bmd_to_glb(f)
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return p
	# Kiểm tra tên model (jewelOfBless, capeOfLord, transformationRing...)
	var md_name: String = str(m.get("model", ""))
	if MODEL_NAME_TO_GLB.has(md_name):
		var p2: String = MODEL_NAME_TO_GLB[md_name]
		if ResourceLoader.exists(p2) or FileAccess.file_exists(p2):
			return p2
	# Kiểm tra tra cứu trực tiếp theo group:number
	var key := "%d:%d" % [group, number]
	if DIRECT_ITEM_GLB.has(key):
		var p3: String = DIRECT_ITEM_GLB[key]
		if ResourceLoader.exists(p3) or FileAccess.file_exists(p3):
			return p3
	return ""

## Màu phát sáng +7.. của item (mặc định cam như OtherModelColors của MU)
static func item_glow_color(group: int, number: int) -> Color:
	var g = item_model(group, number).get("glow", {})
	if g is Dictionary:
		return color_named(g.get("color", "orange"), Color(1, 0.5, 0))
	return Color(1, 0.5, 0)

## Render::Items::Glow::GetLevel: "glow.level" trong Items/Models = mức phát sáng cố định (số) hoặc bảng theo cấp (mảng)
static func glow_level(group: int, number: int, level: int) -> int:
	var md := item_model(group, number)
	# ItemEffects ApplyPotion: bình thuốc có cấp (+1..) phát sáng như đồ +7
	if str(md.get("itemEffect", "")) == "potion":
		return 7 if level > 0 else 0
	var g = md.get("glow", {})
	if not (g is Dictionary) or not g.has("level"):
		return level
	var lv = g["level"]
	if lv is Array:
		if lv.is_empty():
			return level
		return int(lv[clampi(level, 0, lv.size() - 1)])
	return int(lv)

static func item_ancient_color(group: int, number: int) -> Color:
	var g = item_model(group, number).get("glow", {})
	return color_named(g.get("ancientColor", "azure"), Color(0.0, 0.5, 1.0)) if g is Dictionary else Color(0.0, 0.5, 1.0)

static func item_shine_color(group: int, number: int) -> Color:
	var g = item_model(group, number).get("glow", {})
	if g is Dictionary:
		if g.get("shineWhite", false):
			return Color(1, 1, 1)
		return color_named(g.get("shineColor", "white"), Color(1, 1, 1))
	return Color(1, 1, 1)

## Lấy toàn bộ danh sách item trong Catalog (dùng cho Kho Đồ GM / Item Picker)
static func get_all_items() -> Array:
	ensure_loaded()
	var list: Array = []
	for k in item_data:
		var it: Dictionary = item_data[k]
		if not it.has("group"):
			var parts = k.split(":")
			it["group"] = int(parts[0])
			it["number"] = int(parts[1])
		list.append(it)
	for k in item_models:
		if not item_data.has(k):
			var parts = k.split(":")
			list.append({
				"group": int(parts[0]),
				"number": int(parts[1]),
				"name": "Item %s" % k
			})
	return list
