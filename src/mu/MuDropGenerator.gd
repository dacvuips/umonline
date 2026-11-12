extends RefCounted
class_name MuDropGenerator

## Bộ sinh vật phẩm và tiền rơi khi tiêu diệt quái vật (Drop Generator)
## Ported & tối ưu hóa theo quy tắc chuẩn từ server OpenMU (DefaultDropGenerator.cs & GameConfigurationInitializerBase.cs)
##
## Tỷ lệ theo server gốc:
##   - 20.0%: Không rơi gì (giữ nguyên độ hiếm của MU Online)
##   - 48.0%: Rơi tiền Zen (công thức phụ thuộc cấp quái & exp)
##   - 25.0%: Rơi Trang bị / Vũ khí / Giáp / Khiên (theo DropLevel của quái, có tỷ lệ Skill/Luck/Opt/Exc)
##   -  6.5%: Rơi Bình máu / Mana / Thuốc giải độc
##   -  0.5%: Rơi Ngọc quý (Bless, Soul, Chaos, Life, Creation theo cấp quái)

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")

# Bảng phân cấp trang bị (group 0..11) được cache theo level
static var _items_by_level: Dictionary = {} # int level -> Array[Dictionary]
static var _all_equip_items: Array = []
static var _initialized := false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	MuCatalogRes.ensure_loaded()
	
	for g in range(12): # Group 0 đến 11: Vũ khí và Trang bị
		for k in MuCatalogRes.item_data:
			var it: Dictionary = MuCatalogRes.item_data[k]
			var group := int(it.get("group", -1))
			if group != g:
				continue
			var number := int(it.get("number", -1))
			# Bỏ qua mũi tên / bolt làm trang bị rơi
			if group == 4 and (number == 7 or number == 15):
				continue
			var nm = it.get("name", "")
			var name_str := str(nm.get("en", "")) if nm is Dictionary else str(nm)
			if name_str.strip_edges() == "":
				continue
			
			var drop_lvl := int(it.get("level", 0))
			if drop_lvl <= 0:
				continue
				
			var entry := {
				"group": group,
				"number": number,
				"level": drop_lvl,
				"name": name_str,
				"twoHanded": bool(it.get("twoHanded", false)),
				"statProfile": str(it.get("statProfile", ""))
			}
			_all_equip_items.append(entry)
			if not _items_by_level.has(drop_lvl):
				_items_by_level[drop_lvl] = []
			_items_by_level[drop_lvl].append(entry)

## Sinh vật phẩm hoặc tiền rơi khi quái chết
## Trả về Dictionary:
##   - {"type": "none"} -> Không rơi gì
##   - {"type": "zen", "amount": int} -> Rơi Zen
##   - {"type": "item", "category": int, "item_dict": Dictionary, "amount": int} -> Rơi Item/Ngọc/Thuốc
static func generate_drop(monster_level: int) -> Dictionary:
	_ensure_initialized()
	
	var roll := randf()
	
	# 1. 20% quái không rơi gì
	if roll < 0.20:
		return {"type": "none"}
	
	# 2. 48% rơi Zen (từ 0.20 đến 0.68)
	if roll < 0.68:
		var zen_amount := _calculate_zen(monster_level)
		return {
			"type": "zen",
			"amount": zen_amount,
			"category": 0 # MuDropItem.ItemCategory.ZEN
		}
	
	# 3. 6.5% rơi Potion / Thuốc (từ 0.68 đến 0.745)
	if roll < 0.745:
		return _generate_potion(monster_level)
	
	# 4. 0.5% rơi Ngọc (Jewel: Bless, Soul, Chaos...) (từ 0.745 đến 0.75)
	if roll < 0.75:
		var jewel_drop := _generate_jewel(monster_level)
		if not jewel_drop.is_empty():
			return jewel_drop
		# Nếu cấp quái quá thấp chưa đủ rớt ngọc, rơi Potion
		return _generate_potion(monster_level)
	
	# 5. 25.0% còn lại rơi Trang bị (Vũ khí, Giáp, Khiên)
	return _generate_equipment(monster_level)

## Công thức tính lượng Zen rơi theo cấp quái (chuẩn OpenMU / Webzen)
static func _calculate_zen(monster_level: int) -> int:
	var base := monster_level * randi_range(35, 75) + randi_range(25, 120)
	# Quái cấp càng cao thì lượng zen tối thiểu càng tăng
	if monster_level <= 5:
		return randi_range(60, 250)
	elif monster_level <= 15:
		return randi_range(250, 850)
	elif monster_level <= 30:
		return randi_range(800, 2400)
	elif monster_level <= 60:
		return randi_range(2000, 5500)
	else:
		return base

## Sinh bình máu, mana, táo, thuốc giải độc theo cấp quái
static func _generate_potion(monster_level: int) -> Dictionary:
	var p_roll := randf()
	var g := 14
	var n := 0
	var dur := 3
	
	if monster_level <= 10:
		# Quái sơ cấp: Táo (40%), Bình máu nhỏ (35%), Bình mana nhỏ (25%)
		if p_roll < 0.40:
			n = 0 # Apple
		elif p_roll < 0.75:
			n = 1 # Small Healing Potion
		else:
			n = 4 # Small Mana Potion
	elif monster_level <= 25:
		# Quái trung cấp: Bình máu vừa (35%), Bình mana vừa (30%), Bình máu nhỏ (20%), Antidote (15%)
		if p_roll < 0.35:
			n = 2 # Medium Healing Potion
		elif p_roll < 0.65:
			n = 5 # Medium Mana Potion
		elif p_roll < 0.85:
			n = 1 # Small Healing Potion
		else:
			n = 8 # Antidote
	else:
		# Quái cao cấp: Bình máu lớn (40%), Bình mana lớn (35%), Bình máu vừa (25%)
		if p_roll < 0.40:
			n = 3 # Large Healing Potion
		elif p_roll < 0.75:
			n = 6 # Large Mana Potion
		else:
			n = 2 # Medium Healing Potion
			
	var item_dict := MuItemsRes.make(g, n, 0, {"dur": dur})
	return {
		"type": "item",
		"category": 5, # POTION
		"item_dict": item_dict,
		"amount": dur
	}

## Sinh Ngọc rơi (Jewel of Chaos, Bless, Soul, Life, Creation)
static func _generate_jewel(monster_level: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	
	# Jewel of Chaos: cấp quái >= 12
	if monster_level >= 12:
		candidates.append({"group": 12, "number": 15, "cat": 3}) # CHAOS
	
	# Jewel of Bless: cấp quái >= 25
	if monster_level >= 25:
		candidates.append({"group": 14, "number": 13, "cat": 1}) # BLESS
		
	# Jewel of Soul: cấp quái >= 30
	if monster_level >= 30:
		candidates.append({"group": 14, "number": 14, "cat": 2}) # SOUL
		
	# Jewel of Life: cấp quái >= 72
	if monster_level >= 72:
		candidates.append({"group": 14, "number": 16, "cat": 4}) # EQUIPMENT/JEWEL
		
	# Jewel of Creation: cấp quái >= 72
	if monster_level >= 72:
		candidates.append({"group": 14, "number": 22, "cat": 4}) # EQUIPMENT/JEWEL
	
	if candidates.is_empty():
		return {}
	
	var picked: Dictionary = candidates[randi() % candidates.size()]
	var item_dict := MuItemsRes.make(picked["group"], picked["number"], 0, {"dur": 1})
	return {
		"type": "item",
		"category": picked["cat"],
		"item_dict": item_dict,
		"amount": 1
	}

## Sinh Trang bị / Vũ khí / Giáp trụ theo cấp độ quái
static func _generate_equipment(monster_level: int) -> Dictionary:
	# Quy tắc DropLevelMaxGap = 12 từ DefaultDropGenerator.cs
	# Đồ rơi có DropLevel từ [monster_level - 12] đến monster_level
	var min_drop_lvl := maxi(1, monster_level - 12)
	var max_drop_lvl := maxi(6, monster_level)
	
	var pool: Array = []
	for lvl in range(min_drop_lvl, max_drop_lvl + 1):
		if _items_by_level.has(lvl):
			pool.append_array(_items_by_level[lvl])
	
	# Nếu không tìm thấy trong khoảng hẹp, lấy trong toàn bộ danh sách hợp lệ
	if pool.is_empty():
		for it in _all_equip_items:
			if it["level"] <= max_drop_lvl + 5:
				pool.append(it)
	
	if pool.is_empty():
		# Fallback nếu danh sách rỗng
		return {
			"type": "zen",
			"amount": _calculate_zen(monster_level),
			"category": 0
		}
	
	var selected: Dictionary = pool[randi() % pool.size()]
	var base_drop_lvl: int = selected["level"]
	
	# Cấp độ cộng của món đồ (+0 .. +3) theo công thức OpenMU: (monster_level - drop_level) / 3
	var item_plus: int = clampi(int((monster_level - base_drop_lvl) / 3), 0, 3)
	
	# Xác định thuộc tính mở rộng (Skill, Luck, Option, Excellent)
	var is_weapon_or_shield: bool = selected["group"] <= 6
	
	# Đồ Hoàn Hảo (Excellent): Quái cấp >= 25 mới có tỉ lệ rơi đồ Exc (~1.5% trong số equipment)
	var is_exc: bool = (monster_level >= 25) and (randf() < 0.015)
	
	# Skill: Nếu là Exc thì luôn có skill, nếu thường thì 50% có skill (cho vũ khí & khiên)
	var has_skill: bool = false
	if is_weapon_or_shield:
		has_skill = true if is_exc else (randf() < 0.50)
	
	# Luck: 25% cơ hội có Luck
	var has_luck: bool = (randf() < 0.25)
	
	# Option (+4, +8): ~28% cơ hội
	var opt_level := 0
	var opt_roll := randf()
	if opt_roll < 0.20:
		opt_level = 1 # +4 Dame/Def
	elif opt_roll < 0.28:
		opt_level = 2 # +8 Dame/Def
	
	var extra := {
		"skill": has_skill,
		"luck": has_luck,
		"opt": opt_level,
		"excellent": is_exc
	}
	
	var item_dict := MuItemsRes.make(selected["group"], selected["number"], item_plus, extra)
	
	return {
		"type": "item",
		"category": 4, # EQUIPMENT
		"item_dict": item_dict,
		"amount": 1
	}
