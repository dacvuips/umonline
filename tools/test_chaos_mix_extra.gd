extends SceneTree

## Kiểm tra các công thức Chaos bổ sung (Fenrir, Life Stone, Bình SD, vé Illusion, Cánh cấp 3):
##   godot --headless --path . --script res://tools/test_chaos_mix_extra.gd

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const Mix = preload("res://src/mu/MuChaosMix.gd")

var _fail := 0

func _check(name: String, cond: bool, extra = "") -> void:
	print(("  OK   " if cond else "  FAIL ") + name + ("  " + str(extra) if str(extra) != "" else ""))
	if not cond:
		_fail += 1

func _stack(g: int, n: int, count: int) -> Dictionary:
	return MuItemsRes.make(g, n, 0, {"dur": count})

func _init() -> void:
	var M := MuItemsRes
	var chaos := M.make(12, 15)

	print("== Fenrir")
	var ev: Dictionary = Mix.evaluate([_stack(13, 32, 20), _stack(13, 33, 20), chaos])
	_check("Fenrir bước 1 = 70%, 0 Zen", ev["ok"] and ev["rate"] == 70 and ev["cost"] == 0, ev)
	ev = Mix.evaluate([_stack(13, 32, 19), _stack(13, 33, 20), chaos])
	_check("Fenrir bước 1 thiếu -> lỗi", not ev["ok"], ev["error"])
	ev = Mix.evaluate([_stack(13, 35, 5), _stack(13, 34, 10), chaos])
	_check("Fenrir bước 2 = 50%", ev["ok"] and ev["rate"] == 50, ev)
	ev = Mix.evaluate([M.make(13, 36), M.make(14, 16), M.make(14, 16), M.make(14, 16), chaos])
	_check("Fenrir bước 3 = 30%, 10M Zen", ev["ok"] and ev["rate"] == 30 and ev["cost"] == 10000000, ev)
	var done := false
	for i in 200:
		var ex: Dictionary = Mix.execute([M.make(13, 36), M.make(14, 16), M.make(14, 16), M.make(14, 16), chaos])
		if bool(ex["success"]):
			var h: Dictionary = ex["items"][0]
			done = int(h["group"]) == 13 and int(h["number"]) == 37 and int(h["dur"]) == 255
			break
	_check("Fenrir bước 3 ra Sừng Sói Tinh dur 255", done)

	print("== Life Stone / Bình SD / vé Illusion")
	var bl := M.make(14, 13)
	var so := M.make(14, 14)
	ev = Mix.evaluate([M.make(14, 31), bl, bl, bl, bl, bl, so, so, so, so, so, chaos])
	_check("Life Stone 100%, 5M", ev["ok"] and ev["rate"] == 100 and ev["cost"] == 5000000, ev)
	ev = Mix.evaluate([_stack(14, 3, 3)])
	_check("Bình SD nhỏ 50%", ev["ok"] and ev["rate"] == 50 and ev["cost"] == 100000, ev)
	ev = Mix.evaluate([_stack(14, 38, 3)])
	_check("Bình SD vừa 30%", ev["ok"] and ev["rate"] == 30, ev)
	ev = Mix.evaluate([M.make(13, 50, 3), M.make(13, 49, 3), M.make(13, 51, 3), chaos])
	_check("Vé Illusion +3 = 70%, 7M", ev["ok"] and ev["rate"] == 70 and ev["cost"] == 7000000, ev)
	ev = Mix.evaluate([M.make(13, 50, 3), M.make(13, 49, 2), M.make(13, 51, 3), chaos])
	_check("Vé Illusion khác cấp -> lỗi", not ev["ok"], ev["error"])

	print("== Cánh cấp 3")
	var wing2 := M.make(12, 3, 9, {"opt": 1})
	var anc := M.make(7, 1, 7, {"ancient": true, "opt": 1})
	var crea := M.make(14, 22)
	ev = Mix.evaluate([wing2, anc, chaos, crea, M.make(12, 31)])
	_check("Cánh 3 bước 1 hợp lệ", ev["ok"] and ev["rate"] >= 1 and ev["rate"] <= 60 and ev["cost"] == int(ev["rate"]) * 200000, ev)
	ev = Mix.evaluate([wing2, chaos, crea, M.make(12, 31)])
	_check("Cánh 3 bước 1 thiếu đồ Thần -> lỗi", not ev["ok"], ev["error"])
	var exc := M.make(0, 5, 9, {"excellent": true, "opt": 2})
	ev = Mix.evaluate([exc, chaos, crea, M.make(12, 31), M.make(12, 30), M.make(13, 53), M.make(13, 52)])
	_check("Cánh 3 bước 2 hợp lệ (tối đa 40%)", ev["ok"] and ev["rate"] >= 1 and ev["rate"] <= 40, ev)
	var got := false
	for i in 2000:
		var ex2: Dictionary = Mix.execute([exc, chaos, crea, M.make(12, 31), M.make(12, 30), M.make(13, 53), M.make(13, 52)])
		if bool(ex2["success"]):
			var w: Dictionary = ex2["items"][0]
			got = int(w["group"]) == 12 and int(w["number"]) in [36, 37, 38, 39, 40, 43, 50]
			break
	_check("Cánh 3 bước 2 ra cánh cấp 3", got)
	var ex3: Dictionary = Mix.execute([wing2, anc, chaos, crea, M.make(12, 31)])
	_check("Cánh 3 bước 1 chạy được", ex3["ok"], ex3)

	print("== Không phá công thức cũ")
	ev = Mix.evaluate([M.make(12, 1, 0), chaos, M.make(13, 14, 0)])
	_check("Cánh cấp 2 vẫn nhận", ev["ok"] and ev["name"] == "Cánh Cấp 2", ev)
	ev = Mix.evaluate([M.make(0, 5, 9, {"luck": true}), chaos, bl, so])
	_check("+10 vẫn nhận", ev["ok"] and ev["rate"] == 85, ev)

	print("== Kết quả: %s" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	quit(_fail)
