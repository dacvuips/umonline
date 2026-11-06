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
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("[MuCatalog] Lỗi đọc " + path)
		return null
	return j.get_data()

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
	if number >= 0 and monsters_by_number.has(number):
		return monsters_by_number[number]
	return {}

static func monster_model(mon: Dictionary) -> Dictionary:
	ensure_loaded()
	return models_by_slot.get(mon.get("model", ""), {})

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
		_skills = d if d is Dictionary else {}
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

## Orb / scroll / parchment dạy skill: {skill, level, energy, strength, agility, leadership, classes: {"lớp": cấp}}
static func skill_item(group: int, number: int) -> Dictionary:
	var s = _skill_data().get("items", {})
	return s.get("%d:%d" % [group, number], {}) if s is Dictionary else {}

# ------------------------------------------------------------- item
static func item_model(group: int, number: int) -> Dictionary:
	ensure_loaded()
	return item_models.get("%d:%d" % [group, number], {})

static func item_info(group: int, number: int) -> Dictionary:
	ensure_loaded()
	return item_data.get("%d:%d" % [group, number], {})

static func item_name(group: int, number: int) -> String:
	var nm = item_info(group, number).get("name", "")
	return str(nm.get("en", "")) if nm is Dictionary else str(nm)

static func item_glb(group: int, number: int) -> String:
	var m := item_model(group, number)
	return bmd_to_glb(m.get("file", "")) if not m.is_empty() else ""

## Màu phát sáng +7.. của item (mặc định cam như OtherModelColors của MU)
static func item_glow_color(group: int, number: int) -> Color:
	var g = item_model(group, number).get("glow", {})
	if g is Dictionary:
		return color_named(g.get("color", "orange"), Color(1, 0.5, 0))
	return Color(1, 0.5, 0)

## Render::Items::Glow::GetLevel: "glow.level" trong Items/Models = mức phát sáng cố định (số) hoặc bảng theo cấp (mảng)
static func glow_level(group: int, number: int, level: int) -> int:
	var g = item_model(group, number).get("glow", {})
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
