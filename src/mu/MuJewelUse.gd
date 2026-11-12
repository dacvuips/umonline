extends RefCounted
class_name MuJewelUse

## Đập ngọc vào đồ (cầm ngọc trên chuột rồi bấm vào món đồ trong túi / ô trang bị), theo OpenMU
## (PlayerActions/ItemConsumeActions: Bless / Soul / Life JewelConsumeHandlerPlugIn, UpgradeItemLevelJewelConsumeHandlerPlugIn)
## và client gốc (InventoryActionController: Ngọc Ước Nguyện lên Sừng Sói Tinh = sửa độ bền).
##
##   Ngọc Ước Nguyện (Bless 14:13): đồ +0..+5 -> +1, thành công 100%.
##   Ngọc Tâm Linh (Soul 14:14)   : đồ +0..+8 -> +1, thành công 50% (+25% nếu đồ có May Mắn).
##                                  Thất bại: từ +7 trở lên về +0, dưới +7 giảm 1 cấp.
##   Ngọc Sinh Mệnh (Life 14:16)  : 50%: thêm / tăng 1 cấp Tuỳ chọn (+4 mỗi cấp, tối đa +28). Thất bại: mất Tuỳ chọn.
##   (Ngọc Tạo Hoá / Đá Tinh Luyện cần cửa sổ riêng ở NPC nên chưa xử lý ở đây.)

const MuItemsRes = preload("res://src/mu/MuItems.gd")

const BLESS := [14, 13]
const SOUL := [14, 14]
const LIFE := [14, 16]
const MAX_ITEM_LEVEL := 15
const MAX_OPT := 7

static func _is(it: Dictionary, gn: Array) -> bool:
	return int(it.get("group", -1)) == int(gn[0]) and int(it.get("number", -1)) == int(gn[1])

## Ngọc này có thể "đập" vào đồ không?
static func is_usable_jewel(it: Dictionary) -> bool:
	return _is(it, BLESS) or _is(it, SOUL) or _is(it, LIFE)

## Đồ có nâng cấp cấp được không (CanLevelBeUpgraded): trang bị, cánh, dây chuyền, nhẫn
static func can_upgrade_level(t: Dictionary) -> bool:
	var g := int(t.get("group", 0))
	return g <= 11 or MuItemsRes.is_wing(t) or MuItemsRes.is_pendant(t) or MuItemsRes.is_ring(t)

static func _res(handled: bool, consumed: bool, ok: bool, msg: String, color: Color = Color.WHITE) -> Dictionary:
	return {"handled": handled, "consumed": consumed, "ok": ok, "msg": msg, "color": color}

## Thực hiện. Sửa trực tiếp `target` (Dictionary tham chiếu). `roll` = số 1..100 dùng cho test (mặc định ngẫu nhiên).
static func apply(jewel: Dictionary, target: Dictionary, roll: int = -1) -> Dictionary:
	if not is_usable_jewel(jewel) or target.is_empty():
		return _res(false, false, false, "")
	var name := MuItemsRes.display_name(target)
	var r := roll if roll > 0 else randi_range(1, 100)

	# Ngọc Ước Nguyện lên Sừng Sói Tinh chưa đầy độ bền: sửa (client gốc: InventoryActionController)
	if _is(jewel, BLESS) and int(target.get("group", 0)) == 13 and int(target.get("number", 0)) == 37 and int(target.get("dur", 255)) != 255:
		target["dur"] = 255
		return _res(true, true, true, "Đã sửa Sừng Sói Tinh (độ bền 255).", Color(0.4, 1.0, 0.5))

	if _is(jewel, LIFE):
		var caps := MuItemsRes.option_caps(target)
		if not bool(caps["opt"]):
			return _res(true, false, false, "Không thể dùng Ngọc Sinh Mệnh lên %s." % name, Color(1.0, 0.4, 0.3))
		var opt := int(target.get("opt", 0))
		if opt >= MAX_OPT:
			return _res(true, false, false, "%s đã đạt Tuỳ chọn tối đa (+28)." % name, Color(1.0, 0.7, 0.3))
		if r <= 50:
			target["opt"] = opt + 1
			return _res(true, true, true, "Thành công! %s: Tuỳ chọn +%d." % [name, (opt + 1) * 4], Color(0.4, 1.0, 0.5))
		target["opt"] = 0
		return _res(true, true, false, "Thất bại! %s mất Tuỳ chọn." % name, Color(1.0, 0.4, 0.3))

	# Bless / Soul: tăng cấp
	if not can_upgrade_level(target):
		return _res(true, false, false, "Không thể nâng cấp %s." % name, Color(1.0, 0.4, 0.3))
	var lv := int(target.get("level", 0))
	var max_lv := 5 if _is(jewel, BLESS) else 8        # cấp tối đa của đồ để còn được nâng (đích +6 / +9)
	if lv > max_lv or lv + 1 > MAX_ITEM_LEVEL:
		var tip := "+6" if _is(jewel, BLESS) else "+9"
		return _res(true, false, false, "%s đã đạt %s, không dùng được ngọc này." % [name, tip], Color(1.0, 0.7, 0.3))
	var rate := 100 if _is(jewel, BLESS) else 50
	if _is(jewel, SOUL) and bool(target.get("luck", false)):
		rate += 25
	if r <= rate:
		target["level"] = lv + 1
		target["dur"] = MuItemsRes.max_durability(target)
		return _res(true, true, true, "Thành công! %s +%d." % [MuItemsRes.base_name(target), lv + 1], Color(0.4, 1.0, 0.5))
	# thất bại (chỉ Soul): từ +7 về +0, dưới +7 giảm 1
	target["level"] = 0 if lv >= 7 else maxi(0, lv - 1)
	target["dur"] = MuItemsRes.max_durability(target)
	return _res(true, true, false, "Thất bại! %s còn +%d." % [MuItemsRes.base_name(target), int(target["level"])], Color(1.0, 0.4, 0.3))
