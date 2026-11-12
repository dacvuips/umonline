extends SceneTree

## Kiểm tra gộp / tách ngọc (MuJewelBundle):  godot --headless --path . --script res://tools/test_jewel_bundle.gd

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const B = preload("res://src/mu/MuJewelBundle.gd")

var _fail := 0

func _check(name: String, cond: bool, extra = "") -> void:
	print(("  OK   " if cond else "  FAIL ") + name + ("  " + str(extra) if str(extra) != "" else ""))
	if not cond:
		_fail += 1

func _init() -> void:
	var player = load("res://src/entities/MuPlayer.gd").new()
	player.zen = 100000000
	for _i in 25:
		player.inv_add(MuItemsRes.make(14, 13, 0, {"dur": 1}))

	print("== Gộp")
	var r: Dictionary = B.combine(player, 0, 30)
	_check("Gộp 30 Bless khi chỉ có 25 -> từ chối", not r["ok"], r["msg"])
	var zen0: int = player.zen
	r = B.combine(player, 0, 20)
	_check("Gộp 20 Bless OK", r["ok"], r["msg"])
	_check("Phí gộp 20 viên = 1.000.000", zen0 - player.zen == 1000000, zen0 - player.zen)
	_check("Còn 5 Bless lẻ + 1 cụm", B.count_singles(player, 0) == 5 and B.list_bundles(player).size() == 1)
	var bd: Dictionary = B.list_bundles(player)[0]
	_check("Cụm 12:30 cấp 1 (20 viên)", int(bd["item"]["number"]) == 30 and int(bd["item"]["level"]) == 1 and int(bd["pieces"]) == 20)

	print("== Tách")
	zen0 = player.zen
	r = B.dismantle(player, bd["item"])
	_check("Tách cụm OK", r["ok"], r["msg"])
	_check("Phí tách 1.000.000", zen0 - player.zen == 1000000)
	_check("Trở lại 25 Bless lẻ, không còn cụm", B.count_singles(player, 0) == 25 and B.list_bundles(player).is_empty())

	print("== Thiếu Zen / thiếu chỗ")
	player.zen = 100
	r = B.combine(player, 0, 10)
	_check("Thiếu Zen khi gộp", not r["ok"], r["msg"])
	player.zen = 100000000
	player.inventory.clear()
	player.inv_add(MuItemsRes.make(12, 30, 2, {"dur": 1}))
	for y in 8:
		for x in 8:
			pass
	# đầy túi bằng đồ 1x1 để cụm 30 viên không có chỗ tách
	while player.inv_add(MuItemsRes.make(14, 3, 0, {"dur": 1})):
		pass
	var bundle: Dictionary = B.list_bundles(player)[0]["item"]
	r = B.dismantle(player, bundle)
	_check("Tách cụm 30 khi túi đầy -> từ chối, cụm còn nguyên", not r["ok"] and B.list_bundles(player).size() == 1, r["msg"])

	print("== Kết quả: %s" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	quit(_fail)
