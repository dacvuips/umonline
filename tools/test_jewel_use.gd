extends SceneTree

## Kiểm tra đập ngọc vào đồ (MuJewelUse):  godot --headless --path . --script res://tools/test_jewel_use.gd

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const J = preload("res://src/mu/MuJewelUse.gd")

var _fail := 0

func _check(name: String, cond: bool, extra = "") -> void:
	print(("  OK   " if cond else "  FAIL ") + name + ("  " + str(extra) if str(extra) != "" else ""))
	if not cond:
		_fail += 1

func _init() -> void:
	var M := MuItemsRes
	var bless := M.make(14, 13)
	var soul := M.make(14, 14)
	var life := M.make(14, 16)

	print("== Bless: +0..+5 -> +1, 100%")
	var sw := M.make(0, 5, 3)
	var r: Dictionary = J.apply(bless, sw, 100)
	_check("Bless +3 -> +4", r["ok"] and r["consumed"] and int(sw["level"]) == 4, r["msg"])
	sw["level"] = 6
	r = J.apply(bless, sw, 1)
	_check("Bless lên đồ +6 bị từ chối, không mất ngọc", r["handled"] and not r["consumed"] and int(sw["level"]) == 6, r["msg"])

	print("== Soul: 50% (+25% May Mắn), thất bại giảm cấp")
	var a := M.make(0, 5, 6)
	r = J.apply(soul, a, 50)
	_check("Soul 50 -> thành công +7", r["ok"] and int(a["level"]) == 7, r["msg"])
	r = J.apply(soul, a, 51)
	_check("Soul 51 -> thất bại, từ +7 về +0", (not r["ok"]) and r["consumed"] and int(a["level"]) == 0, r["msg"])
	var b := M.make(0, 5, 4)
	r = J.apply(soul, b, 99)
	_check("Soul thất bại dưới +7 giảm 1 cấp (+4 -> +3)", int(b["level"]) == 3, r["msg"])
	var lucky := M.make(0, 5, 2, {"luck": true})
	r = J.apply(soul, lucky, 75)
	_check("Soul + May Mắn: 75 vẫn thành công", r["ok"] and int(lucky["level"]) == 3, r["msg"])
	r = J.apply(soul, lucky, 76)
	_check("Soul + May Mắn: 76 thất bại", not r["ok"], r["msg"])
	var top := M.make(0, 5, 9)
	r = J.apply(soul, top, 1)
	_check("Soul lên đồ +9 bị từ chối", not r["consumed"] and int(top["level"]) == 9, r["msg"])

	print("== Life: 50%, thêm / tăng Tuỳ chọn, thất bại mất Tuỳ chọn")
	var armor := M.make(8, 1, 0)
	r = J.apply(life, armor, 10)
	_check("Life thành công: opt 0 -> 1 (+4)", r["ok"] and int(armor["opt"]) == 1, r["msg"])
	r = J.apply(life, armor, 80)
	_check("Life thất bại: mất Tuỳ chọn", (not r["ok"]) and r["consumed"] and int(armor["opt"]) == 0, r["msg"])
	var maxed := M.make(8, 1, 0, {"opt": 7})
	r = J.apply(life, maxed, 1)
	_check("Life lên đồ +28 bị từ chối", not r["consumed"], r["msg"])

	print("== Đồ không hợp lệ")
	var potion := M.make(14, 3, 0)
	r = J.apply(life, potion, 1)
	_check("Life lên thuốc bị từ chối", r["handled"] and not r["consumed"], r["msg"])
	r = J.apply(bless, potion, 1)
	_check("Bless lên thuốc bị từ chối", r["handled"] and not r["consumed"], r["msg"])
	var jw := M.make(14, 22)
	_check("Ngọc Creation không phải ngọc đập", not J.is_usable_jewel(jw))
	r = J.apply(jw, sw)
	_check("Ngọc không đập được -> handled = false", not r["handled"])

	print("== Sừng Sói Tinh: Bless sửa độ bền")
	var horn := M.make(13, 37, 0, {"dur": 100})
	r = J.apply(bless, horn, 1)
	_check("Bless sửa Sừng Sói Tinh -> 255", r["ok"] and int(horn["dur"]) == 255, r["msg"])

	print("== Kết quả: %s" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	quit(_fail)
