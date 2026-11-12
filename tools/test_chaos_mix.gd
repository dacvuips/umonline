extends SceneTree

## Kiểm tra nhanh Máy Chaos (Chaos Goblin) và bảng Devil Square (Charon):
##   godot --headless --path . --script res://tools/test_chaos_mix.gd

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const Mix = preload("res://src/mu/MuChaosMix.gd")
const DS = preload("res://src/ui/DevilSquareWindow.gd")
const ChaosWin = preload("res://src/ui/ChaosMixWindow.gd")

var _fail := 0

func _check(name: String, cond: bool, extra = "") -> void:
	print(("  OK   " if cond else "  FAIL ") + name + ("  " + str(extra) if str(extra) != "" else ""))
	if not cond:
		_fail += 1

func _init() -> void:
	var M := MuItemsRes
	var chaos := M.make(12, 15)
	var bless := M.make(14, 13)
	var soul := M.make(14, 14)

	print("== Thiệp Mời Quỷ")
	var ev: Dictionary = Mix.evaluate([M.make(14, 17, 3), M.make(14, 18, 3), chaos])
	_check("DS ticket +3", ev["ok"] and ev["rate"] == 80 and ev["cost"] == 400000, ev)
	ev = Mix.evaluate([M.make(14, 17, 3), M.make(14, 18, 2), chaos])
	_check("DS ticket khác cấp -> lỗi", not ev["ok"], ev["error"])
	var ex: Dictionary = Mix.execute([M.make(14, 17, 6), M.make(14, 18, 6), chaos])
	_check("DS ticket execute", ex["ok"] and (not ex["success"] or (ex["items"][0]["number"] == 19 and ex["items"][0]["level"] == 6)), ex)

	print("== Nâng cấp +10..+15")
	var sword := M.make(0, 5, 9, {"luck": true})
	ev = Mix.evaluate([sword, chaos, bless, soul])
	_check("+10 có luck = 85%", ev["ok"] and ev["rate"] == 85 and ev["cost"] == 2000000, ev)
	ev = Mix.evaluate([M.make(0, 5, 12), chaos, bless, bless, bless, bless, soul, soul, soul, soul])
	_check("+13 = 55% (60 - (3/2)*5)", ev["ok"] and ev["rate"] == 55 and ev["cost"] == 8000000, ev)
	ev = Mix.evaluate([M.make(0, 5, 12), chaos, bless, soul])
	_check("+13 thiếu ngọc -> lỗi", not ev["ok"], ev["error"])

	print("== Chaos Weapon / Cánh")
	ev = Mix.evaluate([M.make(0, 5, 6, {"opt": 2}), chaos, bless, bless])
	_check("Chaos Weapon", ev["ok"] and ev["name"].contains("Chaos") and ev["rate"] > 0, ev)
	ev = Mix.evaluate([M.make(2, 6, 5, {"opt": 1}), chaos, bless])
	_check("Cánh cấp 1", ev["ok"] and ev["name"] == "Cánh Cấp 1", ev)
	ev = Mix.evaluate([M.make(12, 1, 0), chaos, M.make(13, 14, 0)])
	_check("Cánh cấp 2", ev["ok"] and ev["name"] == "Cánh Cấp 2" and ev["cost"] == 5000000, ev)
	ev = Mix.evaluate([M.make(0, 5, 6), chaos])
	_check("Đồ không option -> lỗi", not ev["ok"], ev["error"])

	print("== Khác")
	var horns: Array = [chaos]
	for i in 10:
		horns.append(M.make(13, 2))
	ev = Mix.evaluate(horns)
	_check("Dinorant", ev["ok"] and ev["rate"] == 70, ev)
	_check("Fruits", Mix.evaluate([chaos, M.make(14, 22)])["ok"])
	ex = Mix.execute([bless, bless])
	_check("Potion of Bless x2", ex["success"] and ex["items"].size() == 2 and ex["items"][0]["number"] == 7, ex)
	_check("Rỗng", not Mix.evaluate([])["ok"])

	print("== Devil Square")
	_check("DK 150 -> QT 2", _sq(_P.new(150, 1)) == 1)
	_check("MG 150 -> QT 2", _sq(_P.new(150, 3)) == 1)
	_check("MG 170 -> QT 3", _sq(_P.new(170, 3)) == 2)
	_check("DW 350 -> QT 6", _sq(_P.new(350, 0)) == 5)
	_check("Lv 401 -> Master (QT 7)", _sq(_P.new(401, 0)) == 6)

	print("== Khởi tạo cửa sổ")
	var w = ChaosWin.new()
	_check("ChaosMixWindow tạo được", w != null)
	w.free()
	var d = DS.new()
	_check("DevilSquareWindow tạo được", d != null)
	d.free()

	print("KẾT QUẢ: %s (%d lỗi)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

func _sq(n: Node) -> int:
	var r: int = DS.active_square(n)
	n.free()
	return r

class _P extends Node:
	var level := 1
	var char_class := 0
	func _init(l: int, c: int) -> void:
		level = l
		char_class = c
