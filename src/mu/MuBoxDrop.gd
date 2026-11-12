extends RefCounted
class_name MuBoxDrop

## Rương / hộp / trái tim: khi VỨT ra đất thì mở ra và rớt đồ (hoặc Zen) ngẫu nhiên.
## Port từ server OpenMU: GameLogic/PlayerActions/Items/ItemBoxDroppedPlugIn.cs
##   - lấy các nhóm rớt ứng với cấp của món (SourceItemLevel), đòi cấp nhân vật (RequiredCharacterLevel)
##   - SelectRandomGroup: nhóm xếp theo Chance tăng dần, random 0..1 trừ dần Chance ; nhóm Zen (Chance 1.0) hứng phần còn lại
##   - nhóm RandomItem: 1 món ngẫu nhiên trong danh sách, cấp ngẫu nhiên Min..Max ; nhóm Excellent: món Excellent
##   - Zen rớt ở vị trí người chơi ; DropEffect (Fireworks / FanfareSound / Swirl ...) chiếu tại người chơi
## Bảng rớt trích từ Persistence/Initialization/VersionSeasonSix/Items/BoxOfLuck.cs -> assets/mu/box_drops.json
##   (Hộp May Mắn 14:11 cấp +0..+13 gồm Pháo, Trái Tim, Huy chương, Hộp Thiên Đường, Hộp Kundun +1..+5, Tim Dark Lord ;
##    Hộp Sô-cô-la 14:32..34 ; Hộp Ruy-băng 12:32..34 ; Bí Ngô 14:45 ; Hộp Hoa Anh Đào 14:84 ; Sao Giáng Sinh / Pháo Hoa chỉ có hiệu ứng ;
##    Nhẫn Pháp Sư 13:20 cấp +1/+2)

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")

const DATA_PATH := "res://assets/mu/box_drops.json"
static var _data: Dictionary = {}

## Tên mã của Godot cho cấp của Hộp May Mắn (OpenMU: 14:11 + cấp): Trái Tim = +3, Hộp Kundun +1..+5 = +8..+12
const ALIAS := {
	"14:12": ["14:11", 3],
	"14:55": ["14:11", 8], "14:56": ["14:11", 9], "14:57": ["14:11", 10], "14:58": ["14:11", 11], "14:59": ["14:11", 12],
}

static func _load() -> void:
	if not _data.is_empty():
		return
	if FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed

## [khoá hộp, cấp nguồn]
static func _resolve(it: Dictionary) -> Array:
	var key := "%d:%d" % [int(it.get("group", 0)), int(it.get("number", 0))]
	var lvl := int(it.get("level", 0))
	if ALIAS.has(key):
		return [ALIAS[key][0], int(ALIAS[key][1])]
	return [key, lvl]

static func _groups_of(it: Dictionary) -> Array:
	_load()
	var r := _resolve(it)
	var box: Dictionary = _data.get(r[0], {})
	var out: Array = []
	for g in box.get("groups", []):
		if int(g.get("level", 0)) == int(r[1]):
			out.append(g)
	return out

## Món này là hộp mở được khi vứt ra đất (có nhóm rớt ứng với cấp của nó)?
static func is_box(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	return not _groups_of(it).is_empty()

## Mở hộp. Trả về:
##   {"ok": false, "message": "..."}                       -> chưa đủ cấp, giữ nguyên món đồ
##   {"ok": true, "effect": "Fireworks", "drops": [ {"type": "zen", "amount": n} | {"type": "item", "item_dict": {...}} ]}
static func open(it: Dictionary, char_level: int) -> Dictionary:
	var groups := _groups_of(it)
	if groups.is_empty():
		return {"ok": false, "message": ""}
	var need := 0
	for g in groups:
		need = maxi(need, int(g.get("req_level", 0)))
	if need > char_level:
		return {"ok": false, "message": "Cần đạt cấp %d để mở vật phẩm này." % need}

	groups.sort_custom(func(a, b): return float(a.get("chance", 1.0)) < float(b.get("chance", 1.0)))
	var threshold := randf()
	var picked: Dictionary = {}
	for g in groups:
		if threshold > float(g.get("chance", 1.0)):
			threshold -= float(g.get("chance", 1.0))
		else:
			picked = g
			break

	var result := {"ok": true, "effect": "", "drops": []}
	if picked.is_empty():
		return result
	result["effect"] = str(picked.get("effect", ""))
	var type := str(picked.get("type", "random"))
	if type == "money":
		result["drops"].append({"type": "zen", "amount": int(picked.get("money", 0))})
	elif type == "random" or type == "excellent":
		var item := _roll_item(picked, type == "excellent")
		if not item.is_empty():
			result["drops"].append({"type": "item", "item_dict": item})
	return result

## Danh sách món có thật trong catalog (bộ giáp "set" = mũ, giáp, quần, găng, giày cùng số)
static func _candidates(picked: Dictionary) -> Array:
	MuCatalogRes.ensure_loaded()
	var out: Array = []
	for e in picked.get("items", []):
		if e is Array and e.size() == 2:
			if str(e[0]) == "set":
				for grp in [7, 8, 9, 10, 11]:
					if not MuCatalogRes.item_info(grp, int(e[1])).is_empty():
						out.append([grp, int(e[1])])
			else:
				if not MuCatalogRes.item_info(int(e[0]), int(e[1])).is_empty():
					out.append([int(e[0]), int(e[1])])
	return out

static func _roll_item(picked: Dictionary, excellent: bool) -> Dictionary:
	var pool := _candidates(picked)
	if pool.is_empty():
		return {}
	var pick: Array = pool[randi() % pool.size()]
	var g := int(pick[0])
	var lvl := randi_range(int(picked.get("min", 0)), maxi(int(picked.get("min", 0)), int(picked.get("max", 0))))
	var weapon_like := g <= 6
	var extra := {
		"excellent": excellent,
		# Skill (vũ khí / khiên): Excellent luôn có, thường 50% ; Luck 25% ; Option +4/+8 ~28%
		"skill": weapon_like and (excellent or randf() < 0.5),
		"luck": randf() < 0.25,
		"opt": 0,
	}
	var r := randf()
	if r < 0.20:
		extra["opt"] = 1
	elif r < 0.28:
		extra["opt"] = 2
	# Đồ trang bị trong hộp thường (jewel, bình thuốc...) không cần luck/option
	if g >= 12:
		extra["luck"] = false
		extra["opt"] = 0
		extra["skill"] = false
	return MuItemsRes.make(g, int(pick[1]), lvl, extra)
