extends Control
class_name PartyWindow

## Cửa sổ Tổ đội — clone CPartyInfoWindow (UI/Party/PartyInfoWindow.cpp + party_info.rcss legacy):
##   khung 190x429, mỗi thành viên một ô 170x71 từ (10,40): tên (chữ đậm, trưởng nhóm xanh lá) trên thẻ tiêu đề,
##   cờ trưởng nhóm newui_party_flag (136,23), bản đồ (10,26) + toạ độ (85,26) màu xám (194,194,194),
##   thanh máu newui_party_lifebar01 (8,39) 151x8 + phần đầy newui_party_lifebar02 147x4, số máu (88,51) căn phải,
##   nút trục xuất newui_party_x (149,23) (chỉ trưởng nhóm thấy). Chưa có tổ đội: dòng hướng dẫn từ (20,60).

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const S := 1.5
const W := 190.0
const H := 429.0
const GRAY := Color8(194, 194, 194)

var social = null
var _rows: Control
var _hp_fills: Dictionary = {}
var _hp_texts: Dictionary = {}
var _locs: Dictionary = {}
var _tick := 0.0

func _ready() -> void:
	visible = false
	z_index = 30
	add_to_group("MuPartyWindow")
	MuUiSkinRes.docked_window(self, "Tổ đội", close)
	_rows = Control.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	get_viewport().size_changed.connect(_place)

func setup(p_social) -> void:
	social = p_social
	social.party_changed.connect(_rebuild)

func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(maxf(0.0, vs.x - W * S), maxf(0.0, (vs.y - H * S) * 0.5))

func toggle() -> void:
	if visible:
		close()
	else:
		_place()
		_rebuild()
		visible = true
		if MuAudioManager:
			MuAudioManager.play_ui_window()

func close() -> void:
	visible = false

func _rebuild() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_hp_fills.clear()
	_hp_texts.clear()
	_locs.clear()
	if social == null:
		return
	if not social.in_party():
		var lines := ["Bạn chưa ở trong tổ đội nào.", "", "Chạm vào người chơi khác rồi chọn", "nút [Tổ đội] để mời vào nhóm.",
			"", "Thành viên trong tổ đội được chia", "kinh nghiệm theo cấp độ."]
		var y := 57.5
		for l in lines:
			MuUiSkinRes.text(_rows, l, Vector2(20, y), Vector2(160, 15), 12, Color.WHITE)
			y += 15.0
		return
	for i in social.party.size():
		var nm: String = social.party[i]
		var o := Vector2(10, 40 + i * 71)
		MuUiSkinRes.table_box(_rows, Rect2(o, Vector2(70, 26)), Color(0, 0, 0, 0.75))
		MuUiSkinRes.table_box(_rows, Rect2(o + Vector2(0, 20), Vector2(170, 46)), Color(0, 0, 0, 0.75))
		var info: Dictionary = social.member_info(nm)
		MuUiSkinRes.text(_rows, nm, o + Vector2(0, 6), Vector2(70, 14), 12,
			Color(0, 1, 0) if info["leader"] else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		if info["leader"]:
			MuUiSkinRes.img(_rows, "newui_party_flag", o + Vector2(136, 23), Vector2(10, 12))
		_locs[nm] = MuUiSkinRes.text(_rows, "", o + Vector2(10, 25), Vector2(150, 13), 11, GRAY)
		MuUiSkinRes.img(_rows, "newui_party_lifebar01", o + Vector2(8, 39), Vector2(151, 8))
		_hp_fills[nm] = MuUiSkinRes.img(_rows, "newui_party_lifebar02", o + Vector2(10, 41), Vector2(147, 4))
		_hp_texts[nm] = MuUiSkinRes.text(_rows, "", o + Vector2(88, 49), Vector2(70, 13), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		if social.is_leader() and nm != social._hero_name():
			var kick := TextureButton.new()
			kick.texture_normal = MuUiSkinRes.tex("newui_party_x")
			kick.ignore_texture_size = true
			kick.stretch_mode = TextureButton.STRETCH_SCALE
			kick.position = (o + Vector2(149, 23)) * S
			kick.size = Vector2(13, 13) * S
			kick.tooltip_text = "Trục xuất"
			kick.pressed.connect(social.kick_member.bind(nm))
			_rows.add_child(kick)
	_update_values()

func _update_values() -> void:
	for nm in _hp_fills:
		var info: Dictionary = social.member_info(nm)
		var r := clampf(float(info["hp"]) / maxf(1.0, float(info["max_hp"])), 0.0, 1.0)
		var f: TextureRect = _hp_fills[nm]
		f.size.x = 147.0 * r * S
		_hp_texts[nm].text = "%d / %d" % [info["hp"], info["max_hp"]]
		_locs[nm].text = "%s          %d, %d" % [info["map"], info["x"], info["y"]]

func _process(d: float) -> void:
	if not visible or social == null:
		return
	_tick -= d
	if _tick <= 0.0:
		_tick = 0.25
		_update_values()

func _gui_input(event: InputEvent) -> void:
	accept_event()
