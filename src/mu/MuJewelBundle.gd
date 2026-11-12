extends RefCounted
class_name MuJewelBundle

## Gộp / tách ngọc thành cụm (NPC Lahap, Jeweler Raul ở Loren Market) — theo OpenMU
## PlayerActions/Items/ItemStackAction.cs + GameConfigurationInitializer.CreateJewelMixes:
##   Gộp : N viên lẻ (N = 10 / 20 / 30) -> 1 cụm cấp N/10 - 1, phí (N / 10) * 500.000 Zen
##   Tách: 1 cụm cấp L -> (L + 1) * 10 viên lẻ, phí 1.000.000 Zen, cần đủ ô trống trong túi

const MuItemsRes = preload("res://src/mu/MuItems.gd")

const COMBINE_FEE_PER_TEN := 500000
const DISMANTLE_FEE := 1000000

## [tên, nhóm viên lẻ, số viên lẻ, số cụm (nhóm 12)]  — thứ tự = số mix của OpenMU (0..9)
const TYPES := [
	["Ngọc Ước Nguyện (Bless)", 14, 13, 30],
	["Ngọc Tâm Linh (Soul)", 14, 14, 31],
	["Ngọc Sinh Mệnh (Life)", 14, 16, 136],
	["Ngọc Sáng Tạo (Creation)", 14, 22, 137],
	["Ngọc Hộ Mệnh (Guardian)", 14, 31, 138],
	["Đá Nguyên Thủy (Gemstone)", 14, 41, 139],
	["Đá Tạo Hóa (Harmony)", 14, 42, 140],
	["Ngọc Hỗn Nguyên (Chaos)", 12, 15, 141],
	["Đá Tinh Luyện Thấp", 14, 43, 142],
	["Đá Tinh Luyện Cao", 14, 44, 143],
]

static func combine_fee(count: int) -> int:
	return (count / 10) * COMBINE_FEE_PER_TEN

## Số viên lẻ của loại `type_idx` đang có trong túi
static func count_singles(player, type_idx: int) -> int:
	var t: Array = TYPES[type_idx]
	var n := 0
	for it in player.inventory:
		if int(it.get("group", -1)) == int(t[1]) and int(it.get("number", -1)) == int(t[2]):
			n += 1
	return n

## Các cụm ngọc đang có trong túi: [{"type": idx, "item": Dictionary, "pieces": int}]
static func list_bundles(player) -> Array:
	var out: Array = []
	for it in player.inventory:
		if int(it.get("group", -1)) != 12:
			continue
		for i in TYPES.size():
			if int(it.get("number", -1)) == int(TYPES[i][3]):
				out.append({"type": i, "item": it, "pieces": (int(it.get("level", 0)) + 1) * 10})
	return out

## Gộp. Trả về {"ok", "msg"}
static func combine(player, type_idx: int, count: int) -> Dictionary:
	if type_idx < 0 or type_idx >= TYPES.size() or not (count in [10, 20, 30]):
		return {"ok": false, "msg": "Số lượng gộp không hợp lệ (10 / 20 / 30)."}
	var t: Array = TYPES[type_idx]
	if count_singles(player, type_idx) < count:
		return {"ok": false, "msg": "Không đủ ngọc để gộp (cần %d viên)." % count}
	var fee := combine_fee(count)
	if player.zen < fee:
		return {"ok": false, "msg": "Không đủ Zen (cần %s)." % MuItemsRes.format_zen(fee)}
	var taken: Array = []
	for it in player.inventory.duplicate():
		if taken.size() >= count:
			break
		if int(it.get("group", -1)) == int(t[1]) and int(it.get("number", -1)) == int(t[2]):
			taken.append(it)
	for it in taken:
		player.inv_remove(it)
	var packed := MuItemsRes.make(12, int(t[3]), count / 10 - 1, {"dur": 1})
	if not player.inv_add(packed):
		# không còn chỗ (hiếm: các ô vừa trống đã đủ chỗ) -> hoàn lại
		for it in taken:
			player.inv_add(it)
		return {"ok": false, "msg": "Túi đồ không đủ chỗ."}
	player.add_zen(-fee)
	return {"ok": true, "msg": "Gộp ngọc thành công! (%s x%d)" % [str(t[0]), count]}

## Tách 1 cụm thành các viên lẻ. Trả về {"ok", "msg"}
static func dismantle(player, bundle: Dictionary) -> Dictionary:
	var type_idx := -1
	for i in TYPES.size():
		if int(bundle.get("group", -1)) == 12 and int(bundle.get("number", -1)) == int(TYPES[i][3]):
			type_idx = i
	if type_idx < 0 or not player.inventory.has(bundle):
		return {"ok": false, "msg": "Vật phẩm này không phải cụm ngọc."}
	if player.zen < DISMANTLE_FEE:
		return {"ok": false, "msg": "Không đủ Zen (cần %s)." % MuItemsRes.format_zen(DISMANTLE_FEE)}
	var t: Array = TYPES[type_idx]
	var pieces := (int(bundle.get("level", 0)) + 1) * 10
	player.inv_remove(bundle)
	var added: Array = []
	for _i in pieces:
		var single := MuItemsRes.make(int(t[1]), int(t[2]), 0, {"dur": 1})
		if not player.inv_add(single):
			# thiếu chỗ: hoàn tác
			for a in added:
				player.inv_remove(a)
			player.inv_add(bundle)
			return {"ok": false, "msg": "Túi đồ không đủ chỗ (cần %d ô trống)." % pieces}
		added.append(player.inventory.back())   # inv_add lưu bản sao: giữ đúng phần tử trong túi để hoàn tác
	player.add_zen(-DISMANTLE_FEE)
	return {"ok": true, "msg": "Tách ngọc thành công! (+%d viên)" % pieces}
