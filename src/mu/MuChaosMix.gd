extends RefCounted
class_name MuChaosMix

## Máy Chaos của Chaos Goblin (NPC 238) — chạy offline trong client Godot.
## Port từ OpenMU (Persistence/Initialization/VersionSeasonSix/ChaosMixes.cs + SimpleItemCraftingHandler
## + BaseEventTicketCrafting) và client gốc (ZzzInterface MOVEMENT_TALK: phải đạt cấp CHAOS_MIX_LEVEL = 10).
##
## Đồ trong máy là Array các Dictionary MuItems (group, number, level, opt, luck, skill, excellent, dur, x, y).
## evaluate(items)  -> {"ok", "name", "rate", "cost", "error"}  (chỉ xem trước, không đổi gì)
## execute(items)   -> {"ok", "success", "name", "items", "error"} (items = đồ còn lại trong máy sau khi trộn)

const MuItemsRes = preload("res://src/mu/MuItems.gd")

const MIX_LEVEL := 10   # CHAOS_MIX_LEVEL của client gốc

# Mã đồ (group, number) — theo Items.json của MU Season 6
const JEWEL_CHAOS := [12, 15]
const JEWEL_BLESS := [14, 13]
const JEWEL_SOUL := [14, 14]
const JEWEL_CREATION := [14, 22]
const LOCH_FEATHER := [13, 14]       # cấp 1 = Crest of Monarch
const HORN_UNIRIA := [13, 2]
const HORN_DINORANT := [13, 3]
const FRUITS := [13, 15]
const SIEGE_POTION := [14, 7]        # cấp 0 = Potion of Bless, cấp 1 = Potion of Soul
const DEVIL_EYE := [14, 17]
const DEVIL_KEY := [14, 18]
const DEVIL_INVITATION := [14, 19]
const ARCHANGEL_SCROLL := [13, 16]
const BLOOD_BONE := [13, 17]
const INVISIBILITY_CLOAK := [13, 18]
const CHAOS_WEAPONS := [[2, 6], [4, 6], [5, 7]]
const FIRST_WINGS := [[12, 0], [12, 1], [12, 2], [12, 41]]
const SECOND_WINGS := [[12, 3], [12, 4], [12, 5], [12, 6], [12, 42]]
const CAPES := [[13, 30], [12, 49]]

# Fenrir (OpenMU FenrirStage1..3): Mảnh Giáp / Lời Chúc Bảo Hộ / Móng Vuốt / Mảnh Sừng / Sừng Gãy / Sừng Sói Tinh
const SPLINTER_ARMOR := [13, 32]
const BLESS_GUARDIAN := [13, 33]
const CLAW_BEAST := [13, 34]
const FRAGMENT_HORN := [13, 35]
const BROKEN_HORN := [13, 36]
const HORN_FENRIR := [13, 37]
const LIFE_STONE := [13, 11]           # cấp 1 = Life Stone
const JEWEL_GUARDIAN := [14, 31]
const JEWEL_LIFE := [14, 16]
const PACKED_BLESS := [12, 30]
const PACKED_SOUL := [12, 31]
const FEATHER_CONDOR := [13, 53]
const FLAME_CONDOR := [13, 52]
const LARGE_HEAL := [14, 3]
const SMALL_COMPLEX := [14, 38]
const MEDIUM_COMPLEX := [14, 39]
const OLD_SCROLL := [13, 49]
const ILLUSION_COVENANT := [13, 50]
const BLOOD_SCROLL := [13, 51]
## Cánh cấp 3 (OpenMU ThirdWingsStage2Crafting)
const THIRD_WINGS := [[12, 36], [12, 37], [12, 38], [12, 39], [12, 40], [12, 43], [12, 50]]
## Đồ xếp chồng: số lượng = độ bền (OpenMU: IsStackable ? Durability : 1)
const STACKABLE := [[13, 32], [13, 33], [13, 34], [13, 35], [14, 3], [14, 38], [14, 39]]

## Giá "cũ" của ngọc khi tính tỉ lệ theo giá đồ (Chaos Weapon / Cánh cấp 1): mỗi viên Bless ~ +5%, Soul ~ +3.5%
const OLD_JEWEL_PRICE := {"14:13": 100000, "14:14": 70000, "12:15": 40000, "14:22": 450000}

# ------------------------------------------------------------------ tiện ích nhận dạng đồ
static func _is(it: Dictionary, gn: Array) -> bool:
	return int(it.get("group", -1)) == int(gn[0]) and int(it.get("number", -1)) == int(gn[1])

static func _is_any(it: Dictionary, list: Array) -> bool:
	for gn in list:
		if _is(it, gn):
			return true
	return false

static func _lv(it: Dictionary) -> int:
	return int(it.get("level", 0))

## Đồ trang bị thường (vũ khí, giáp, khiên, trang sức) — dùng cho "đồ ngẫu nhiên" của công thức
static func _is_equipment(it: Dictionary) -> bool:
	var g := int(it.get("group", 0))
	if g > 11:
		return MuItemsRes.is_ring(it) or MuItemsRes.is_pendant(it)
	return true

static func _old_price(it: Dictionary) -> int:
	var k := "%d:%d" % [int(it.get("group", 0)), int(it.get("number", 0))]
	if OLD_JEWEL_PRICE.has(k):
		return OLD_JEWEL_PRICE[k]
	return MuItemsRes.buy_price(it)

## Rút ra khỏi `pool` mọi món thoả `pred` và trả về danh sách đó
static func _take(pool: Array, pred: Callable) -> Array:
	var got: Array = []
	for it in pool.duplicate():
		if pred.call(it):
			got.append(it)
			pool.erase(it)
	return got


## Số lượng của 1 loại (đồ xếp chồng tính theo độ bền)
static func _cnt(items: Array, gn: Array) -> int:
	var n := 0
	for it in items:
		if _is(it, gn):
			n += maxi(1, int(it.get("dur", 1))) if _is_any(it, STACKABLE) else 1
	return n

## Mọi đồ trong máy đều thuộc `allowed` (danh sách [group, number])
static func _only(items: Array, allowed: Array) -> bool:
	for it in items:
		if not _is_any(it, allowed):
			return false
	return true

static func _gen(name: String, rate: int, cost: int, result: Array) -> Dictionary:
	return {"kind": "gen", "name": name, "rate": rate, "cost": cost, "result": result}

## Các công thức cố định theo ChaosMixes.cs (Season 6) ngoài Chaos Weapon / Cánh 1-2 / +10..+15 / vé sự kiện:
##   Fenrir bước 1-3, Life Stone, Bình SD nhỏ / vừa / lớn, Vé Illusion Temple, Cánh cấp 3 (2 bước)
static func _match_extra(items: Array) -> Dictionary:
	var chaos := _cnt(items, JEWEL_CHAOS)
	# --- Fenrir bước 1: 20 Splinter of Armor + 20 Bless of Guardian + 1 Chaos -> Fragment of Horn (70%)
	if _cnt(items, SPLINTER_ARMOR) > 0 or _cnt(items, BLESS_GUARDIAN) > 0:
		if _only(items, [SPLINTER_ARMOR, BLESS_GUARDIAN, JEWEL_CHAOS]) and _cnt(items, SPLINTER_ARMOR) == 20 \
				and _cnt(items, BLESS_GUARDIAN) == 20 and chaos == 1:
			return _gen("Mảnh Sừng Sói Tinh (Fenrir bước 1)", 70, 0, [[13, 35, 0, {"dur": 1}]])
		return {"error": "Fenrir bước 1: 20 Mảnh Giáp + 20 Lời Chúc Bảo Hộ + 1 Ngọc Chaos"}
	# --- Fenrir bước 2: 5 Fragment of Horn + 10 Claw of Beast + 1 Chaos -> Broken Horn (50%)
	if _cnt(items, FRAGMENT_HORN) > 0 or _cnt(items, CLAW_BEAST) > 0:
		if _only(items, [FRAGMENT_HORN, CLAW_BEAST, JEWEL_CHAOS]) and _cnt(items, FRAGMENT_HORN) == 5 \
				and _cnt(items, CLAW_BEAST) == 10 and chaos == 1:
			return _gen("Sừng Gãy (Fenrir bước 2)", 50, 0, [[13, 36, 0, {"dur": 1}]])
		return {"error": "Fenrir bước 2: 5 Mảnh Sừng + 10 Móng Vuốt Quái Thú + 1 Ngọc Chaos"}
	# --- Fenrir bước 3: 1 Broken Horn + 3 Jewel of Life + 1 Chaos -> Horn of Fenrir (30%, 10.000.000 Zen)
	if _cnt(items, BROKEN_HORN) > 0:
		if _only(items, [BROKEN_HORN, JEWEL_LIFE, JEWEL_CHAOS]) and _cnt(items, BROKEN_HORN) == 1 \
				and _cnt(items, JEWEL_LIFE) == 3 and chaos == 1:
			return _gen("Sừng Sói Tinh (Fenrir bước 3)", 30, 10000000, [[13, 37, 0, {"dur": 255, "skill": true}]])
		return {"error": "Fenrir bước 3: 1 Sừng Gãy + 3 Ngọc Sinh Mệnh + 1 Ngọc Chaos"}
	# --- Life Stone: 1 Guardian + 5 Bless + 5 Soul + 1 Chaos (100%, 5.000.000 Zen)
	if _cnt(items, JEWEL_GUARDIAN) > 0:
		if _only(items, [JEWEL_GUARDIAN, JEWEL_BLESS, JEWEL_SOUL, JEWEL_CHAOS]) and _cnt(items, JEWEL_GUARDIAN) == 1 \
				and _cnt(items, JEWEL_BLESS) == 5 and _cnt(items, JEWEL_SOUL) == 5 and chaos == 1:
			return _gen("Đá Sinh Mệnh (Life Stone)", 100, 5000000, [[13, 11, 1, {"dur": 1}]])
		return {"error": "Life Stone: 1 Ngọc Hộ Mệnh + 5 Bless + 5 Soul + 1 Chaos"}
	# --- Bình SD: 3 Large Healing (50%, 100k) / 3 Small Complex (30%, 500k) / 3 Medium Complex (30%, 1M); không cần Chaos
	if _cnt(items, LARGE_HEAL) > 0 and _only(items, [LARGE_HEAL]) and _cnt(items, LARGE_HEAL) == 3:
		return _gen("Bình SD Nhỏ", 50, 100000, [[14, 35, 0, {"dur": 1}]])
	if _cnt(items, SMALL_COMPLEX) > 0 and _only(items, [SMALL_COMPLEX]) and _cnt(items, SMALL_COMPLEX) == 3:
		return _gen("Bình SD Vừa", 30, 500000, [[14, 36, 0, {"dur": 1}]])
	if _cnt(items, MEDIUM_COMPLEX) > 0 and _only(items, [MEDIUM_COMPLEX]) and _cnt(items, MEDIUM_COMPLEX) == 3:
		return _gen("Bình SD Lớn", 30, 1000000, [[14, 37, 0, {"dur": 1}]])
	# --- Vé Illusion Temple: Illusion Sorcerer Covenant + Old Scroll + Scroll of Blood cùng cấp + Chaos (70%)
	if _cnt(items, ILLUSION_COVENANT) > 0 or _cnt(items, OLD_SCROLL) > 0 or _cnt(items, BLOOD_SCROLL) > 0:
		var a := items.filter(func(i): return _is(i, ILLUSION_COVENANT))
		var b := items.filter(func(i): return _is(i, OLD_SCROLL))
		var c := items.filter(func(i): return _is(i, BLOOD_SCROLL))
		if a.size() != 1 or b.size() != 1 or c.size() != 1 or chaos != 1 or items.size() != 4:
			return {"error": "Vé Illusion Temple: Giao Ước Ảo Thuật + Cuộn Cổ + Huyết Ấn cùng cấp + 1 Ngọc Chaos"}
		var lv := _lv(a[0])
		if lv != _lv(b[0]) or lv != _lv(c[0]):
			return {"error": "Ba vật phẩm phải cùng cấp!"}
		var price: int = {2: 5000000, 3: 7000000, 4: 9000000, 5: 11000000, 6: 13000000}.get(lv, 3000000)
		return _gen("Vé Illusion Temple +%d" % lv, 70, price, [[13, 61, lv, {"dur": 1}]])
	# --- Cánh cấp 3 bước 2: đồ Excellent +9.. có option + Chaos + Creation + Cụm Soul + Cụm Bless + Lông Vũ + Ngọn Lửa Condor
	if _cnt(items, FEATHER_CONDOR) > 0 or _cnt(items, FLAME_CONDOR) > 0:
		var pool := items.duplicate()
		var exc := _take(pool, func(i): return _is_equipment(i) and bool(i.get("excellent", false)) and _lv(i) >= 9 and int(i.get("opt", 0)) > 0)
		_take(pool, func(i): return _is(i, JEWEL_CHAOS) or _is(i, JEWEL_CREATION) or _is(i, PACKED_SOUL) or _is(i, PACKED_BLESS) or _is(i, FEATHER_CONDOR) or _is(i, FLAME_CONDOR))
		if exc.size() != 1 or not pool.is_empty() or chaos != 1 or _cnt(items, JEWEL_CREATION) != 1 or _cnt(items, PACKED_SOUL) != 1 \
				or _cnt(items, PACKED_BLESS) != 1 or _cnt(items, FEATHER_CONDOR) != 1 or _cnt(items, FLAME_CONDOR) != 1:
			return {"error": "Cánh cấp 3: đồ Excellent +9 có option + Chaos + Creation + Cụm Soul + Cụm Bless + Lông Vũ + Ngọn Lửa Condor"}
		var rate := mini(40, 1 + MuItemsRes.buy_price(exc[0]) / 3000000)
		return {"kind": "wings3_2", "name": "Cánh Cấp 3", "rate": rate, "cost": rate * 200000}
	# --- Cánh cấp 3 bước 1: cánh cấp 2 +9.. có option + đồ Thần +7.. có option + Chaos + Creation + Cụm Soul -> Lông Vũ Condor
	if _cnt(items, PACKED_SOUL) > 0 and _cnt(items, PACKED_BLESS) == 0:
		var pool2 := items.duplicate()
		var second := _take(pool2, func(i): return (_is_any(i, SECOND_WINGS) or _is_any(i, CAPES)) and _lv(i) >= 9 and int(i.get("opt", 0)) > 0)
		var ancient := _take(pool2, func(i): return _is_equipment(i) and bool(i.get("ancient", false)) and _lv(i) >= 7 and int(i.get("opt", 0)) > 0)
		_take(pool2, func(i): return _is(i, JEWEL_CHAOS) or _is(i, JEWEL_CREATION) or _is(i, PACKED_SOUL))
		if second.size() != 1 or ancient.size() != 1 or not pool2.is_empty() or chaos != 1 or _cnt(items, JEWEL_CREATION) != 1 or _cnt(items, PACKED_SOUL) != 1:
			return {"error": "Cánh cấp 3 bước 1: cánh cấp 2 +9 có option + đồ Thần +7 có option + Chaos + Creation + Cụm Soul"}
		var rate1 := mini(60, 1 + MuItemsRes.buy_price(ancient[0]) / 300000)
		return {"kind": "wings3_1", "name": "Lông Vũ Condor (Cánh cấp 3 bước 1)", "rate": rate1, "cost": rate1 * 200000}
	return {}

# ------------------------------------------------------------------ nhận dạng công thức
## Trả về công thức khớp với đồ trong máy (Dictionary rỗng nếu không có)
static func _match(items: Array) -> Dictionary:
	if items.is_empty():
		return {}
	var has_chaos := items.any(func(i): return _is(i, JEWEL_CHAOS))

	var extra := _match_extra(items)
	if not extra.is_empty():
		return extra

	# --- Vé sự kiện: Devil's Eye + Devil's Key cùng cấp + Ngọc Chaos -> Devil's Invitation (Charon)
	if items.any(func(i): return _is(i, DEVIL_EYE)) or items.any(func(i): return _is(i, DEVIL_KEY)):
		return _match_ticket(items, DEVIL_EYE, DEVIL_KEY, DEVIL_INVITATION, "Thiệp Mời Quỷ (Devil Square)", true)
	# --- Archangel Scroll + Blood Bone cùng cấp + Ngọc Chaos -> Invisibility Cloak (Blood Castle)
	if items.any(func(i): return _is(i, ARCHANGEL_SCROLL)) or items.any(func(i): return _is(i, BLOOD_BONE)):
		return _match_ticket(items, ARCHANGEL_SCROLL, BLOOD_BONE, INVISIBILITY_CLOAK, "Áo Choàng Tàng Hình (Blood Castle)", false)

	# --- Potion of Bless / Soul: chỉ toàn Ngọc Ước Nguyện hoặc toàn Ngọc Tâm Linh (không cần Chaos)
	if items.all(func(i): return _is(i, JEWEL_BLESS)):
		return {"kind": "potion", "name": "Bình Ước Nguyện (Potion of Bless)", "count": items.size(),
			"rate": 100, "cost": 100000 * items.size(), "potion_level": 0}
	if items.all(func(i): return _is(i, JEWEL_SOUL)):
		return {"kind": "potion", "name": "Bình Tâm Linh (Potion of Soul)", "count": items.size(),
			"rate": 100, "cost": 50000 * items.size(), "potion_level": 1}

	if not has_chaos:
		return {"error": "Cần có Ngọc Hỗn Nguyên (Jewel of Chaos)!"}

	# --- Fruits: 1 Chaos + 1 Creation
	if items.size() == 2 and items.any(func(i): return _is(i, JEWEL_CREATION)):
		return {"kind": "fruit", "name": "Trái Cây (Fruits)", "rate": 90, "cost": 3000000}

	# --- Dinorant: 1 Chaos + 10 Horn of Uniria
	if items.any(func(i): return _is(i, HORN_UNIRIA)):
		var horns := items.filter(func(i): return _is(i, HORN_UNIRIA)).size()
		if horns == 10 and items.size() == 11:
			return {"kind": "dinorant", "name": "Sừng Dinorant (Horn of Dinorant)", "rate": 70, "cost": 500000}
		return {"error": "Cần đúng 10 Sừng Uniria + 1 Ngọc Chaos (đang có %d sừng)" % horns}

	# --- Cánh cấp 2 / Áo choàng: Cánh cấp 1 + Chaos + Loch's Feather (+ đồ Excellent +4 trở lên tuỳ ý)
	if items.any(func(i): return _is_any(i, FIRST_WINGS)) and items.any(func(i): return _is(i, LOCH_FEATHER)):
		var pool := items.duplicate()
		var wings := _take(pool, func(i): return _is_any(i, FIRST_WINGS))
		var chaos := _take(pool, func(i): return _is(i, JEWEL_CHAOS))
		var feather := _take(pool, func(i): return _is(i, LOCH_FEATHER) and _lv(i) == 0)
		var crest := _take(pool, func(i): return _is(i, LOCH_FEATHER) and _lv(i) == 1)
		var exc := _take(pool, func(i): return _is_equipment(i) and bool(i.get("excellent", false)) and _lv(i) >= 4)
		if wings.size() != 1 or chaos.size() != 1 or feather.size() + crest.size() != 1 or not pool.is_empty():
			return {"error": "Cánh cấp 2: 1 Cánh cấp 1 + 1 Ngọc Chaos + 1 Lông Vũ Loch (Crest cho Áo Choàng)"}
		var rate := 0
		for w in wings:
			rate += MuItemsRes.buy_price(w) / 4000000
		for e in exc:
			rate += MuItemsRes.buy_price(e) / 40000
		rate = mini(rate, 90)
		var is_cape := crest.size() == 1
		return {"kind": "cape" if is_cape else "wings2",
			"name": "Áo Choàng Chúa Tể / Đấu Sĩ" if is_cape else "Cánh Cấp 2",
			"rate": rate, "cost": 5000000}

	# --- Nâng cấp +10 .. +15: 1 đồ +9..+14 + 1 Chaos + N Bless + N Soul (N = cấp đích - 9)
	# Tỉ lệ chuẩn theo mix.bmd (Webzen) và OpenMU:
	#   +10..+11: Đồ thường 60% (có Luck 85%), Exc/Thần 50% (có Luck 75%), Socket 40% (có Luck 65%)
	#   +12..+13: Đồ thường 55% (có Luck 80%), Exc/Thần 45% (có Luck 70%), Socket 35% (có Luck 60%)
	#   +14..+15: Đồ thường 50% (có Luck 75%), Exc/Thần 40% (có Luck 65%), Socket 30% (có Luck 55%)
	var targets := items.filter(func(i): return _is_equipment(i) or MuItemsRes.is_wing(i))
	var blesses := items.filter(func(i): return _is(i, JEWEL_BLESS)).size()
	var souls := items.filter(func(i): return _is(i, JEWEL_SOUL)).size()
	var chaoses := items.filter(func(i): return _is(i, JEWEL_CHAOS)).size()
	if targets.size() == 1 and _lv(targets[0]) >= 9 and _lv(targets[0]) <= 14 and blesses > 0 and blesses == souls:
		var it: Dictionary = targets[0]
		var tl := _lv(it) + 1
		var need := tl - 9
		if chaoses != 1 or blesses != need or items.size() != 2 + need * 2:
			return {"error": "Đồ +%d cần: 1 Chaos + %d Bless + %d Soul" % [tl, need, need]}
		var step: int = (tl - 10) / 2 * 5
		var base_rate := 60 - step
		var max_rate := 85 - step
		if bool(it.get("socket", false)):
			base_rate = 40 - step
			max_rate = 65 - step
		elif bool(it.get("excellent", false)) or bool(it.get("ancient", false)):
			base_rate = 50 - step
			max_rate = 75 - step
		var rate := base_rate + (25 if bool(it.get("luck", false)) else 0)
		rate = mini(rate, max_rate)
		return {"kind": "upgrade", "name": "Nâng Cấp Đồ +%d" % tl, "rate": clampi(rate, 0, 100),
			"cost": 2000000 * need, "target": it}

	# --- Chaos Weapon / Cánh cấp 1: đồ +4 trở lên có dòng option + Chaos (+ Bless/Soul tuỳ ý)
	var pool2 := items.duplicate()
	var cw := _take(pool2, func(i): return _is_any(i, CHAOS_WEAPONS) and _lv(i) >= 4 and int(i.get("opt", 0)) > 0)
	var rnd := _take(pool2, func(i): return _is_equipment(i) and _lv(i) >= 4 and int(i.get("opt", 0)) > 0)
	_take(pool2, func(i): return _is(i, JEWEL_CHAOS) or _is(i, JEWEL_BLESS) or _is(i, JEWEL_SOUL))
	if not pool2.is_empty():
		return {"error": "Có đồ không dùng được trong công thức này."}
	if cw.size() > 1 or (cw.is_empty() and rnd.is_empty()):
		return {"error": "Cần đồ +4 trở lên có dòng tuỳ chọn (Jewel of Life) để trộn Vũ Khí Chaos / Cánh."}
	var total := 0
	for it2 in items:
		total += _old_price(it2)
	var rate2 := mini(100, total / 20000)
	if cw.size() == 1:
		return {"kind": "wings1", "name": "Cánh Cấp 1", "rate": rate2, "cost": 10000 * rate2}
	return {"kind": "chaos_weapon", "name": "Vũ Khí Hỗn Nguyên (Chaos Weapon)", "rate": rate2, "cost": 10000 * rate2}

static func _match_ticket(items: Array, a: Array, b: Array, result: Array, name: String, is_ds: bool) -> Dictionary:
	var ia := items.filter(func(i): return _is(i, a))
	var ib := items.filter(func(i): return _is(i, b))
	var ic := items.filter(func(i): return _is(i, JEWEL_CHAOS))
	if ia.size() != 1 or ib.size() != 1 or ic.size() != 1 or items.size() != 3:
		return {"error": "%s: cần 1 %s + 1 %s cùng cấp + 1 Ngọc Chaos" % [name, MuItemsRes.base_name(MuItemsRes.make(a[0], a[1])), MuItemsRes.base_name(MuItemsRes.make(b[0], b[1]))]}
	var lv := _lv(ia[0])
	if lv != _lv(ib[0]):
		return {"error": "Hai vật phẩm phải cùng cấp (+%d và +%d)!" % [lv, _lv(ib[0])]}
	var cost: int
	var rate: int
	if is_ds:
		cost = [100000, 100000, 200000, 400000, 700000, 1100000, 1600000, 2000000][clampi(lv, 0, 7)]
		rate = 60 if lv <= 1 else (80 if lv <= 4 else 70)
	else:
		cost = [50000, 50000, 80000, 150000, 250000, 400000, 600000, 850000, 1050000][clampi(lv, 0, 8)]
		rate = 80
	return {"kind": "ticket", "name": "%s +%d" % [name, lv], "rate": rate, "cost": cost, "result": result, "level": lv}

# ------------------------------------------------------------------ API
static func evaluate(items: Array) -> Dictionary:
	var res := {
		"ok": false,
		"name": "Món đồ này không phù hợp",
		"rate": 0,
		"cost": 0,
		"tax_rate": 0,
		"prediction": "",
		"checklist": [],
		"warnings": [],
		"error": ""
	}
	if items.is_empty():
		res["name"] = ""
		return res

	var m := _match(items)
	var chaos_cnt := _cnt(items, JEWEL_CHAOS)
	var bless_cnt := _cnt(items, JEWEL_BLESS)
	var soul_cnt := _cnt(items, JEWEL_SOUL)

	# 1. Dự đoán / Checklist cho Nâng cấp đồ +10 .. +15
	var upgrade_targets := items.filter(func(i): return (_is_equipment(i) or MuItemsRes.is_wing(i)) and _lv(i) >= 9 and _lv(i) <= 14)
	if upgrade_targets.size() == 1:
		var it: Dictionary = upgrade_targets[0]
		var tl: int = _lv(it) + 1
		var need: int = tl - 9
		res["prediction"] = "Khả năng sử dụng: Nâng cấp item cấp %d" % tl
		var pfx := ""
		if bool(it.get("socket", false)):
			pfx = "Đồ Socket "
		elif bool(it.get("ancient", false)):
			pfx = "Đồ thần "
		elif bool(it.get("excellent", false)):
			pfx = "Đồ hoàn hảo "
		res["checklist"].append({"text": "%sVật phẩm +%d 1 Cái" % [pfx, _lv(it)], "ready": true, "partial": false})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["checklist"].append({"text": "Ngọc Ước Nguyện %d Cái" % need, "ready": bless_cnt >= need, "partial": bless_cnt > 0 and bless_cnt < need})
		res["checklist"].append({"text": "Ngọc Tâm Linh %d Cái" % need, "ready": soul_cnt >= need, "partial": soul_cnt > 0 and soul_cnt < need})
		res["warnings"] = [
			"Nâng cấp thành công đồ cấp 10 -> 15 .",
			"Hãy chú ý!",
			"Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."
		]

	# 2. Cánh cấp 1 & Vũ Khí Chaos
	elif items.any(func(i): return _is_any(i, CHAOS_WEAPONS) and _lv(i) >= 4 and int(i.get("opt", 0)) > 0):
		res["prediction"] = "Khả năng sử dụng: Cánh Cấp 1"
		res["checklist"].append({"text": "Vũ Khí Chaos +4 có Option 1 Cái", "ready": true, "partial": false})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["checklist"].append({"text": "Vật phẩm +4 có Option (Tuỳ chọn)", "ready": items.size() > 2, "partial": false})
		res["warnings"] = [
			"Kết hợp thành công Cánh Cấp 1 .",
			"Hãy chú ý!",
			"Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."
		]
	elif items.any(func(i): return _is_equipment(i) and _lv(i) >= 4 and int(i.get("opt", 0)) > 0):
		res["prediction"] = "Khả năng sử dụng: Vũ Khí Hỗn Nguyên"
		res["checklist"].append({"text": "Vật phẩm +4 có Option 1 Cái", "ready": true, "partial": false})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = [
			"Kết hợp thành công Vũ Khí Chaos .",
			"Hãy chú ý!",
			"Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."
		]

	# 3. Cánh cấp 2 & Áo Choàng
	elif items.any(func(i): return _is_any(i, FIRST_WINGS)):
		var has_feather := items.any(func(i): return _is(i, LOCH_FEATHER) and _lv(i) == 0)
		var has_crest := items.any(func(i): return _is(i, LOCH_FEATHER) and _lv(i) == 1)
		res["prediction"] = "Khả năng sử dụng: Cánh Cấp 2 / Áo Choàng"
		res["checklist"].append({"text": "Cánh cấp 1 1 Cái", "ready": true, "partial": false})
		res["checklist"].append({"text": "Lông Vũ Loch / Huy Hiệu 1 Cái", "ready": has_feather or has_crest, "partial": false})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["checklist"].append({"text": "Đồ hoàn hảo +4 (Tuỳ chọn)", "ready": items.any(func(i): return _is_equipment(i) and bool(i.get("excellent", false))), "partial": false})
		res["warnings"] = [
			"Kết hợp thành công Cánh Cấp 2 .",
			"Hãy chú ý!",
			"Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."
		]

	# 4. Fenrir
	elif _cnt(items, SPLINTER_ARMOR) > 0 or _cnt(items, BLESS_GUARDIAN) > 0:
		var spl := _cnt(items, SPLINTER_ARMOR)
		var blg := _cnt(items, BLESS_GUARDIAN)
		res["prediction"] = "Khả năng sử dụng: Mảnh Sừng Fenrir"
		res["checklist"].append({"text": "Mảnh Giáp 20 Cái", "ready": spl == 20, "partial": spl > 0 and spl < 20})
		res["checklist"].append({"text": "Lời Chúc Bảo Hộ 20 Cái", "ready": blg == 20, "partial": blg > 0 and blg < 20})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = ["Kết hợp Mảnh Sừng Fenrir.", "Hãy chú ý!", "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."]
	elif _cnt(items, FRAGMENT_HORN) > 0 or _cnt(items, CLAW_BEAST) > 0:
		var frg := _cnt(items, FRAGMENT_HORN)
		var clw := _cnt(items, CLAW_BEAST)
		res["prediction"] = "Khả năng sử dụng: Sừng Gãy Fenrir"
		res["checklist"].append({"text": "Mảnh Sừng 5 Cái", "ready": frg == 5, "partial": frg > 0 and frg < 5})
		res["checklist"].append({"text": "Móng Vuốt Quái Thú 10 Cái", "ready": clw == 10, "partial": clw > 0 and clw < 10})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = ["Kết hợp Sừng Gãy Fenrir.", "Hãy chú ý!", "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."]
	elif _cnt(items, BROKEN_HORN) > 0:
		var lf := _cnt(items, JEWEL_LIFE)
		res["prediction"] = "Khả năng sử dụng: Sừng Sói Tinh (Fenrir)"
		res["checklist"].append({"text": "Sừng Gãy 1 Cái", "ready": _cnt(items, BROKEN_HORN) == 1, "partial": false})
		res["checklist"].append({"text": "Ngọc Sinh Mệnh 3 Cái", "ready": lf == 3, "partial": lf > 0 and lf < 3})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = ["Kết hợp Sừng Sói Tinh .", "Hãy chú ý!", "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."]

	# 5. Vé Devil Square / Blood Castle
	elif items.any(func(i): return _is(i, DEVIL_EYE) or _is(i, DEVIL_KEY)):
		var eyes := items.filter(func(i): return _is(i, DEVIL_EYE))
		var keys := items.filter(func(i): return _is(i, DEVIL_KEY))
		var dlv := _lv(eyes[0]) if not eyes.is_empty() else (_lv(keys[0]) if not keys.is_empty() else 1)
		res["prediction"] = "Khả năng sử dụng: Thiệp Mời Quỷ +%d" % dlv
		res["checklist"].append({"text": "Mắt Quỷ +%d 1 Cái" % dlv, "ready": eyes.size() == 1, "partial": false})
		res["checklist"].append({"text": "Khóa Quỷ +%d 1 Cái" % dlv, "ready": keys.size() == 1, "partial": false})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = ["Kết hợp Thiệp Mời Quỷ .", "Hãy chú ý!", "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."]
	elif items.any(func(i): return _is(i, ARCHANGEL_SCROLL) or _is(i, BLOOD_BONE)):
		var scrs := items.filter(func(i): return _is(i, ARCHANGEL_SCROLL))
		var bns := items.filter(func(i): return _is(i, BLOOD_BONE))
		var blv := _lv(scrs[0]) if not scrs.is_empty() else (_lv(bns[0]) if not bns.is_empty() else 1)
		res["prediction"] = "Khả năng sử dụng: Áo Tàng Hình +%d" % blv
		res["checklist"].append({"text": "Cuộn Giấy Thiên Sứ +%d 1 Cái" % blv, "ready": scrs.size() == 1, "partial": false})
		res["checklist"].append({"text": "Huyết Xương +%d 1 Cái" % blv, "ready": bns.size() == 1, "partial": false})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = ["Kết hợp Áo Choàng Tàng Hình .", "Hãy chú ý!", "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."]

	# 6. Dinorant
	elif _cnt(items, HORN_UNIRIA) > 0:
		var uni := _cnt(items, HORN_UNIRIA)
		res["prediction"] = "Khả năng sử dụng: Quái Thú Dinorant"
		res["checklist"].append({"text": "Sừng Uniria đầy máu (255) 10 Cái", "ready": uni >= 10, "partial": uni > 0 and uni < 10})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = ["Kết hợp Quái Thú Dinorant.", "Hãy chú ý!", "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."]

	# 7. Cánh cấp 3 (Giai đoạn 1 & 2)
	elif items.any(func(i): return _is(i, FEATHER_CONDOR) or _is(i, FLAME_CONDOR)):
		var has_feather := _cnt(items, FEATHER_CONDOR) > 0
		var has_flame := _cnt(items, FLAME_CONDOR) > 0
		var has_bless10 := _cnt(items, PACKED_BLESS) > 0
		var has_soul10 := _cnt(items, PACKED_SOUL) > 0
		var has_cre := _cnt(items, JEWEL_CREATION) > 0
		res["prediction"] = "Khả năng sử dụng: Cánh Cấp 3"
		res["checklist"].append({"text": "Lông Vũ Condor 1 Cái", "ready": has_feather, "partial": false})
		res["checklist"].append({"text": "Ngọn Lửa Condor 1 Cái", "ready": has_flame, "partial": false})
		res["checklist"].append({"text": "Cụm Ước Nguyện (10) 1 Cái", "ready": has_bless10, "partial": false})
		res["checklist"].append({"text": "Cụm Tâm Linh (10) 1 Cái", "ready": has_soul10, "partial": false})
		res["checklist"].append({"text": "Ngọc Sáng Tạo 1 Cái", "ready": has_cre, "partial": false})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = ["Kết hợp Cánh Cấp 3.", "Hãy chú ý!", "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."]
	elif items.any(func(i): return _is_any(i, SECOND_WINGS) and _lv(i) >= 9):
		var has_ancient := items.any(func(i): return _is_equipment(i) and bool(i.get("ancient", false)) and _lv(i) >= 7)
		var has_cre := _cnt(items, JEWEL_CREATION) > 0
		var has_soul10 := _cnt(items, PACKED_SOUL) > 0
		res["prediction"] = "Khả năng sử dụng: Lông Vũ Condor"
		res["checklist"].append({"text": "Cánh cấp 2 +9 trở lên 1 Cái", "ready": true, "partial": false})
		res["checklist"].append({"text": "Đồ Thần +7 trở lên 1 Cái", "ready": has_ancient, "partial": false})
		res["checklist"].append({"text": "Cụm Tâm Linh (10) 1 Cái", "ready": has_soul10, "partial": false})
		res["checklist"].append({"text": "Ngọc Sáng Tạo 1 Cái", "ready": has_cre, "partial": false})
		res["checklist"].append({"text": "Ngọc Hỗn Nguyên 1 Cái", "ready": chaos_cnt >= 1, "partial": false})
		res["warnings"] = ["Kết hợp Lông Vũ Condor.", "Hãy chú ý!", "Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."]

	if m.is_empty() or m.has("error"):
		res["ok"] = false
		res["name"] = "Món đồ này không phù hợp"
		res["rate"] = 0
		res["cost"] = 0
		res["error"] = str(m.get("error", "Món đồ này không phù hợp"))
		return res

	res["ok"] = true
	res["name"] = str(m["name"])
	res["rate"] = int(m["rate"])
	res["cost"] = int(m["cost"])
	res["error"] = ""

	if res["warnings"].is_empty():
		res["warnings"] = [
			"Kết hợp thành công %s ." % str(res["name"]),
			"Hãy chú ý!",
			"Các item sẽ không còn nguyên vẹn nếu kết hợp thất bại."
		]
	if res["checklist"].is_empty():
		for it in items:
			res["checklist"].append({"text": "%s 1 Cái" % MuItemsRes.base_name(it), "ready": true, "partial": false})
	return res

## Thực hiện trộn. Không tự trừ Zen — người gọi trừ `cost` trước khi gọi.
static func execute(items: Array) -> Dictionary:
	var m := _match(items)
	if m.is_empty() or m.has("error"):
		return {"ok": false, "success": false, "name": "", "items": items, "error": str(m.get("error", "Không có công thức phù hợp."))}
	var success := randi_range(1, 100) <= int(m["rate"])
	var out: Array = []
	match str(m["kind"]):
		"gen":
			if success:
				for r in m["result"]:
					out.append(MuItemsRes.make(int(r[0]), int(r[1]), int(r[2]), (r[3] as Dictionary).duplicate()))
		"wings3_1", "wings3_2":
			if success:
				if str(m["kind"]) == "wings3_1":
					out.append(MuItemsRes.make(FEATHER_CONDOR[0], FEATHER_CONDOR[1], 0, {"dur": 1}))
				else:
					var w3: Array = THIRD_WINGS.pick_random()
					# 5% May Mắn ; 5% có dòng Excellent / Option ngẫu nhiên (ThirdWingsCrafting)
					var w_opt := 0
					if randi_range(1, 100) <= 5:
						w_opt = 1 + randi() % 3
					out.append(MuItemsRes.make(w3[0], w3[1], 0, {"luck": randi_range(1, 100) <= 5,
						"excellent": randi_range(1, 100) <= 5, "opt": w_opt}))
			else:
				# thất bại: cánh / đồ chính giảm 2-3 cấp, mất dòng Option, được giữ lại; các vật phẩm khác mất
				for it4 in items:
					if _is_any(it4, SECOND_WINGS) or _is_any(it4, CAPES) or (_is_equipment(it4) and int(it4.get("opt", 0)) > 0 \
							and (bool(it4.get("ancient", false)) or bool(it4.get("excellent", false)))):
						var d3: Dictionary = it4.duplicate()
						d3["level"] = maxi(0, _lv(d3) - (2 if randi() % 2 == 0 else 3))
						d3["opt"] = 0
						d3["dur"] = MuItemsRes.max_durability(d3)
						out.append(d3)
		"potion":
			# luôn thành công: mỗi viên ngọc -> 10 bình
			for _i in int(m["count"]):
				out.append(MuItemsRes.make(SIEGE_POTION[0], SIEGE_POTION[1], int(m["potion_level"]), {"dur": 10}))
		"fruit":
			if success:
				out.append(MuItemsRes.make(FRUITS[0], FRUITS[1], randi_range(0, 4)))
		"dinorant":
			if success:
				out.append(MuItemsRes.make(HORN_DINORANT[0], HORN_DINORANT[1], 0, {"skill": true}))
		"ticket":
			if success:
				var r: Array = m["result"]
				out.append(MuItemsRes.make(r[0], r[1], int(m["level"]), {"dur": 1}))
		"wings2", "cape":
			if success:
				var pick: Array = (CAPES if str(m["kind"]) == "cape" else SECOND_WINGS).pick_random()
				out.append(MuItemsRes.make(pick[0], pick[1], 0, {
					"luck": randi_range(1, 100) <= 20,
					"excellent": randi_range(1, 100) <= 20}))
		"upgrade":
			# thành công: đồ +1 cấp, ngọc mất; thất bại: đồ biến mất cùng ngọc
			if success:
				var it: Dictionary = (m["target"] as Dictionary).duplicate()
				it["level"] = _lv(it) + 1
				it["dur"] = MuItemsRes.max_durability(it)
				out.append(it)
		"chaos_weapon", "wings1":
			if success:
				var list: Array = FIRST_WINGS if str(m["kind"]) == "wings1" else CHAOS_WEAPONS
				var pick2: Array = list.pick_random()
				var lv := randi_range(0, 4) if str(m["kind"]) == "chaos_weapon" else 0
				out.append(MuItemsRes.make(pick2[0], pick2[1], lv, {
					"skill": str(m["kind"]) == "chaos_weapon",
					"luck": randi_range(1, 100) <= 20}))
			else:
				# thất bại: vũ khí/đồ chính bị hạ cấp ngẫu nhiên và giữ lại (ChaosWeaponAndFirstWingsDowngradedRandom)
				for it3 in items:
					if (_is_equipment(it3) or _is_any(it3, CHAOS_WEAPONS)) and _lv(it3) >= 4 and int(it3.get("opt", 0)) > 0:
						var d: Dictionary = it3.duplicate()
						d["level"] = randi_range(0, maxi(0, _lv(d) - 1))
						if bool(d.get("skill", false)) and not bool(d.get("excellent", false)) and randi() % 2 == 0:
							d["skill"] = false
						if randi() % 2 == 0:
							d["opt"] = maxi(0, int(d.get("opt", 0)) - 1)
						d["dur"] = MuItemsRes.max_durability(d)
						out.append(d)
						if str(m["kind"]) == "wings1":
							break   # chỉ vũ khí Chaos được giữ lại, đồ phụ mất
	if str(m["kind"]) == "potion":
		success = true
	return {"ok": true, "success": success, "name": str(m["name"]), "items": out, "error": ""}

## Hướng dẫn hiển thị trong cửa sổ máy Chaos
const RECIPE_HELP := [
	"Vũ Khí Chaos: đồ +4 có option + Ngọc Chaos (+Bless/Soul)",
	"Cánh cấp 1: Vũ Khí Chaos +4 có option + Ngọc Chaos",
	"Cánh cấp 2: Cánh cấp 1 + Chaos + Lông Vũ Loch",
	"Đồ +10..+15: đồ +9..+14 + Chaos + N Bless + N Soul",
	"Thiệp Mời Quỷ: Mắt Quỷ + Khóa Quỷ cùng cấp + Chaos",
	"Áo Tàng Hình: Cuộn Tổng Lãnh TT + Xương Máu + Chaos",
	"Dinorant: 10 Sừng Uniria + Chaos  •  Trái Cây: Chaos + Creation",
	"Cánh cấp 3 (1): Cánh cấp 2 +9 option + đồ Thần +7 option + Chaos + Creation + Cụm Soul",
	"Cánh cấp 3 (2): đồ Exc +9 option + Chaos + Creation + Cụm Soul + Cụm Bless + Lông Vũ + Ngọn Lửa Condor",
	"Fenrir: 20 Mảnh Giáp + 20 Lời Chúc + Chaos -> 5 Mảnh Sừng + 10 Móng + Chaos -> Sừng Gãy + 3 Life + Chaos",
	"Life Stone: Guardian + 5 Bless + 5 Soul + Chaos  •  Vé Illusion: 3 vật phẩm cùng cấp + Chaos",
	"Bình SD: 3 Large Healing / 3 Small Complex / 3 Medium Complex",
]
