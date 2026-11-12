extends Control
class_name GuildWindow

## Cửa sổ Guild — clone CGuildInfoWindow (Guild/GuildInfoWindow.cpp + guild_info.rcss legacy):
##   Chưa có guild: tiêu đề + 3 dòng hướng dẫn (gi_hint) ; thêm nút Lập guild (thay NPC Guild Master, cấp 100).
##   Có guild: tên guild (35,48) ; dải tab newui_guild_tab01 (12,68) + tab chọn newui_guild_tab02 (x 12 / 68 / 124)
##   Tab Guild: dấu guild (74,106) 39x39 trong khung, bảng số liệu (10,159) [ngày lập 169, điểm 182, số thành viên 195,
##              guild thù địch 208], thẻ "Thông báo" newui_guild_tab03 (11,237), khung thông báo (10,260), nút Rời/Giải tán (100,350)
##   Tab Thành viên: tiêu đề cột Tên / Chức vụ (y 112), danh sách (13,123) 164x234 hàng 13 ;
##              nút Bổ nhiệm (3,360), Bãi nhiệm (64,360), Trục xuất (125,360) — chỉ chủ guild
##   Tab Liên minh: tiêu đề cột Tên guild / Thành viên (y 115), danh sách (15,130), nút Rời liên minh (100,230)

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuMsgBoxRes = preload("res://src/ui/MuMsgBox.gd")
const S := 1.5
const W := 190.0
const H := 429.0
const ROW_SEL := Color8(106, 97, 88)
const POSITION_NAMES := {"Master": "Chủ guild", "Assist M": "Phó guild", "Battle M": "Đội trưởng", "Member": "Thành viên"}

var social = null
var tab := 0
var _content: Control
var _sel_member := ""
var _sel_union := ""

func _ready() -> void:
	visible = false
	z_index = 30
	add_to_group("MuGuildWindow")
	MuUiSkinRes.docked_window(self, "Guild", close)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	get_viewport().size_changed.connect(_place)

func setup(p_social) -> void:
	social = p_social
	social.guild_changed.connect(func():
		if visible:
			_rebuild())

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
	for c in _content.get_children():
		c.queue_free()
	if social == null:
		return
	if not social.in_guild():
		_build_no_guild()
		return
	var g: Dictionary = social.guild
	MuUiSkinRes.text(_content, str(g["name"]), Vector2(35, 44), Vector2(120, 16), 14, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	# tab
	MuUiSkinRes.img(_content, "newui_guild_tab01", Vector2(12, 68), Vector2(166, 22))
	MuUiSkinRes.img(_content, "newui_guild_tab02", Vector2(12 + tab * 56, 68), Vector2(56, 22))
	var names := ["Guild", "Thành viên", "Liên minh"]
	for i in 3:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(12 + i * 56, 68) * S
		b.size = Vector2(56, 22) * S
		b.text = names[i]
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", Color.WHITE if i == tab else Color(0.7, 0.7, 0.7))
		b.pressed.connect(func():
			tab = i
			if MuAudioManager:
				MuAudioManager.play_ui_click()
			_rebuild())
		_content.add_child(b)
	match tab:
		0: _build_info(g)
		1: _build_members(g)
		2: _build_union(g)

func _build_no_guild() -> void:
	MuUiSkinRes.text(_content, "Guild", Vector2(0, 42), Vector2(190, 16), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 70.0
	for l in ["Bạn chưa thuộc guild nào.", "", "Để gia nhập guild, chạm vào chủ guild", "rồi chọn nút [Guild] để gửi yêu cầu.",
			"", "Để lập guild mới, cần đạt cấp %d." % social.GUILD_CREATE_LEVEL]:
		MuUiSkinRes.text(_content, l, Vector2(20, y), Vector2(160, 15), 11, Color.WHITE)
		y += 15.0
	MuUiSkinRes.text_button(_content, "Lập guild", Vector2(63, 190), Vector2(64, 29), _on_create_pressed)

func _on_create_pressed() -> void:
	MuMsgBoxRes.open(get_tree().get_first_node_in_group("HUD"), [["Nhập tên guild (tối đa 8 ký tự)."]], func():
		var box = MuMsgBoxRes.active
		if box and not social.create_guild(box.get_input_text()):
			box.keep_open(), Callable(), {"input": true, "max_length": 8})

func _build_info(g: Dictionary) -> void:
	MuUiSkinRes.table_box(_content, Rect2(70, 102, 49, 50))
	MuUiSkinRes.guild_mark(_content, g.get("mark", []), Vector2(74, 106), Vector2(39, 39))
	MuUiSkinRes.table_box(_content, Rect2(10, 159, 171, 70))
	var count: int = g["members"].size()
	MuUiSkinRes.text(_content, "Ngày lập: %s" % g.get("created", ""), Vector2(22, 166), Vector2(150, 13), 11, Color.WHITE)
	MuUiSkinRes.text(_content, "Điểm guild: %d" % int(g.get("score", 0)), Vector2(22, 179), Vector2(150, 13), 11, Color.WHITE)
	MuUiSkinRes.text(_content, "Thành viên: %d / %d" % [count, 80], Vector2(22, 192), Vector2(150, 13), 11, Color.WHITE)
	var rival: String = str(g.get("rival", ""))
	MuUiSkinRes.text(_content, "Guild thù địch: %s" % (rival if rival != "" else "Không có"), Vector2(22, 205), Vector2(150, 13), 11,
		Color(1.0, 0.45, 0.4) if rival != "" else Color.WHITE)
	MuUiSkinRes.img(_content, "newui_guild_tab03", Vector2(11, 237), Vector2(63, 25))
	MuUiSkinRes.text(_content, "Thông báo", Vector2(11, 243), Vector2(63, 14), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	MuUiSkinRes.table_box(_content, Rect2(10, 260, 171, 88))
	var notice := MuUiSkinRes.text(_content, str(g.get("notice", "")), Vector2(15, 264), Vector2(161, 80), 11, Color("#ffdc96"))
	notice.clip_text = false
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if social.is_guild_master():
		MuUiSkinRes.text_button(_content, "Sửa", Vector2(30, 350), Vector2(64, 29), _on_edit_notice)
	MuUiSkinRes.text_button(_content, "Giải tán" if social.is_guild_master() else "Rời guild", Vector2(100, 350), Vector2(64, 29), _on_leave_pressed)

func _on_edit_notice() -> void:
	MuMsgBoxRes.open(get_tree().get_first_node_in_group("HUD"), [["Nhập thông báo của guild."]], func():
		var box = MuMsgBoxRes.active
		if box:
			social.set_guild_notice(box.get_input_text()), Callable(), {"input": true, "max_length": 60})

func _on_leave_pressed() -> void:
	var lines := [["Bạn có muốn giải tán guild không?", Color(1, 0.85, 0.3), true], ["Mọi thông tin của guild sẽ bị xóa."]] \
		if social.is_guild_master() else [["Bạn có muốn rời khỏi guild không?"]]
	MuMsgBoxRes.open(get_tree().get_first_node_in_group("HUD"), lines, social.leave_guild)

func _build_members(g: Dictionary) -> void:
	MuUiSkinRes.table_box(_content, Rect2(8, 105, 169, 256))
	var head := ColorRect.new()
	head.color = ROW_SEL
	head.position = Vector2(12, 108) * S
	head.size = Vector2(161, 14) * S
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(head)
	MuUiSkinRes.text(_content, "Tên", Vector2(24, 108), Vector2(60, 13), 11, Color.WHITE)
	MuUiSkinRes.text(_content, "Chức vụ", Vector2(89, 108), Vector2(50, 13), 11, Color.WHITE)
	MuUiSkinRes.text(_content, "Kết nối", Vector2(132, 108), Vector2(40, 13), 11, Color.WHITE)
	var y := 125.0
	for m in g["members"]:
		var nm: String = m["name"]
		var pos: String = m["pos"]
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.position = Vector2(13, y) * S
		row.size = Vector2(160, 13) * S
		var sb := StyleBoxFlat.new()
		sb.bg_color = ROW_SEL if (nm == _sel_member or pos != "Member") else Color(0, 0, 0, 0)
		row.add_theme_stylebox_override("normal", sb)
		row.add_theme_stylebox_override("hover", sb)
		row.add_theme_stylebox_override("pressed", sb)
		row.pressed.connect(func():
			_sel_member = nm
			_rebuild())
		_content.add_child(row)
		var col := Color.BLACK if nm == _sel_member else Color.WHITE
		MuUiSkinRes.text(_content, nm, Vector2(18, y - 1), Vector2(70, 13), 11, col)
		MuUiSkinRes.text(_content, POSITION_NAMES.get(pos, pos), Vector2(85, y - 1), Vector2(50, 13), 11, col)
		var online: bool = nm == social._hero_name() or social.is_online(nm)
		MuUiSkinRes.text(_content, "Online" if online else "Offline", Vector2(132, y - 1), Vector2(40, 13), 11,
			Color(0.4, 1, 0.4) if online and nm != _sel_member else col)
		y += 13.0
	if social.is_guild_master():
		MuUiSkinRes.text_button(_content, "Bổ nhiệm", Vector2(3, 360), Vector2(64, 29), _on_get_position)
		MuUiSkinRes.text_button(_content, "Bãi nhiệm", Vector2(64, 360), Vector2(64, 29), func():
			if _sel_member != "":
				social.set_member_position(_sel_member, "Member"))
		MuUiSkinRes.text_button(_content, "Trục xuất", Vector2(125, 360), Vector2(64, 29), func():
			if _sel_member != "" and _sel_member != social._hero_name():
				MuMsgBoxRes.open(get_tree().get_first_node_in_group("HUD"), [["Trục xuất %s khỏi guild?" % _sel_member]],
					social.kick_guild_member.bind(_sel_member)))

## Bổ nhiệm: Phó guild (Assist M) hoặc Đội trưởng (Battle M)
func _on_get_position() -> void:
	if _sel_member == "" or _sel_member == social._hero_name():
		return
	var cur := ""
	for m in social.guild["members"]:
		if m["name"] == _sel_member:
			cur = m["pos"]
	social.set_member_position(_sel_member, "Battle M" if cur == "Assist M" else "Assist M")

func _build_union(g: Dictionary) -> void:
	MuUiSkinRes.table_box(_content, Rect2(10, 109, 170, 102))
	var head := ColorRect.new()
	head.color = ROW_SEL
	head.position = Vector2(13, 112) * S
	head.size = Vector2(164, 14) * S
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(head)
	MuUiSkinRes.text(_content, "Tên guild", Vector2(34, 112), Vector2(90, 13), 11, Color.WHITE)
	MuUiSkinRes.text(_content, "T.viên", Vector2(140, 112), Vector2(35, 13), 11, Color.WHITE)
	var all: Array = [str(g["name"])] + g["union"]
	var y := 130.0
	if g["union"].is_empty():
		MuUiSkinRes.text(_content, "Chưa có liên minh.", Vector2(20, 150), Vector2(150, 13), 11, Color(0.75, 0.75, 0.75))
	else:
		for gname in all:
			var info: Dictionary = social.guild_info_of(gname)
			var row := Button.new()
			row.flat = true
			row.focus_mode = Control.FOCUS_NONE
			row.position = Vector2(15, y) * S
			row.size = Vector2(160, 13) * S
			var sb := StyleBoxFlat.new()
			sb.bg_color = ROW_SEL if gname == _sel_union else Color(0, 0, 0, 0)
			row.add_theme_stylebox_override("normal", sb)
			row.add_theme_stylebox_override("hover", sb)
			row.pressed.connect(func():
				_sel_union = gname
				_rebuild())
			_content.add_child(row)
			MuUiSkinRes.guild_mark(_content, info.get("mark", []), Vector2(19, y + 2), Vector2(8, 8))
			MuUiSkinRes.text(_content, gname, Vector2(31, y - 1), Vector2(100, 13), 11, Color.WHITE)
			MuUiSkinRes.text(_content, str(info.get("members", []).size()), Vector2(140, y - 1), Vector2(30, 13), 11, Color.WHITE)
			y += 13.0
	var rival: String = str(g.get("rival", ""))
	MuUiSkinRes.text(_content, "Guild thù địch: %s" % (rival if rival != "" else "Không có"), Vector2(15, 215), Vector2(160, 13), 11,
		Color(1.0, 0.45, 0.4) if rival != "" else Color(0.8, 0.8, 0.8))
	if social.is_guild_master():
		MuUiSkinRes.text_button(_content, "Rời L.minh", Vector2(100, 230), Vector2(64, 29), func():
			if _sel_union != "" and _sel_union != str(g["name"]):
				social.leave_union(_sel_union))
	var y2 := 270.0
	for l in ["Liên minh / Thù địch: chạm vào chủ guild", "khác rồi chọn nút [Liên minh],", "[Thù địch] hoặc [Hủy thù địch]."]:
		MuUiSkinRes.text(_content, l, Vector2(16, y2), Vector2(160, 13), 10, Color(0.75, 0.75, 0.75))
		y2 += 13.0

func _gui_input(event: InputEvent) -> void:
	accept_event()
