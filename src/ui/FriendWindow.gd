extends Control
class_name FriendWindow

## Cửa sổ Bạn bè — clone CFriendShell (UI/Social/FriendShell.cpp + friend_shell.rml / .rcss legacy):
##   khung 300x212 ghép từ newui_msgbox_top / middle / bottom + nền newui_msgbox_back, dải tiêu đề newui_Message_03,
##   nút đóng win_size (góc phải), hàng tab bằng win_button (y = 26), ô "Từ chối chat" bên phải,
##   tiêu đề cột nền (106,97,88) cao 15: Tên / Máy chủ ; danh sách hàng 13 trên nền đen 70% ;
##   hàng nút dưới cùng: Thêm / Xóa / Chat. Chọn hàng: nền (146,134,121) chữ đen.

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuMsgBoxRes = preload("res://src/ui/MuMsgBox.gd")
const S := 1.5
const W := 300.0
const H := 212.0
const HEAD := Color8(106, 97, 88)
const SEL := Color8(146, 134, 121)

var social = null
var _list: Control
var _sel := ""
var _reject_box: ColorRect
var _drag := false
var _drag_off := Vector2.ZERO

func _ready() -> void:
	visible = false
	z_index = 32
	add_to_group("MuFriendWindow")
	size = Vector2(W, H) * S
	mouse_filter = Control.MOUSE_FILTER_STOP
	_nine("newui_msgbox_back", Rect2(4, 5, W - 8, H - 10), Rect2(0, 0, 222, 250), 8)
	_nine("newui_msgbox_top", Rect2(0, 0, W, 46), Rect2(0, 0, 230, 67), 12)
	_nine("newui_msgbox_middle", Rect2(0, 46, W, H - 86), Rect2(0, 0, 230, 15), 4)
	_nine("newui_msgbox_bottom", Rect2(0, H - 40, W, 40), Rect2(0, 0, 230, 50), 12)
	_nine("newui_message_03", Rect2(0, 0, W, 46), Rect2(0, 0, 230, 67), 20)
	MuUiSkinRes.text(self, "Bạn bè", Vector2(0, 9), Vector2(W, 14), 12, Color("#ffcc33"), HORIZONTAL_ALIGNMENT_CENTER)
	var close_b := TextureButton.new()
	var ts := MuUiSkinRes.tex("win_size")
	if ts:
		close_b.texture_normal = MuUiSkinRes.atlas_sub(ts, Rect2(0, 9, 9, 9))
	close_b.ignore_texture_size = true
	close_b.stretch_mode = TextureButton.STRETCH_SCALE
	close_b.position = Vector2(W - 22, 10) * S
	close_b.size = Vector2(9, 9) * S
	close_b.pressed.connect(close)
	add_child(close_b)
	# tab (chỉ tab Bạn bè; thư / cửa sổ chat chưa có server thư)
	_win_button("Bạn bè", Vector2(12, 26), Vector2(66, 16), func(): pass, Color("#ffcc33"))
	# Từ chối chat
	_reject_box = ColorRect.new()
	_reject_box.position = Vector2(W - 92, 31) * S
	_reject_box.size = Vector2(7, 7) * S
	_reject_box.color = HEAD
	_reject_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reject_box)
	var rej := Button.new()
	rej.flat = true
	rej.focus_mode = Control.FOCUS_NONE
	rej.position = Vector2(W - 94, 26) * S
	rej.size = Vector2(82, 16) * S
	rej.text = "     Từ chối chat"
	rej.add_theme_font_size_override("font_size", 11)
	rej.pressed.connect(func():
		social.reject_chat = not social.reject_chat
		social.save_data()
		_refresh_reject())
	add_child(rej)
	# tiêu đề cột
	var head := ColorRect.new()
	head.color = HEAD
	head.position = Vector2(12, 48) * S
	head.size = Vector2(W - 24, 15) * S
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	MuUiSkinRes.text(self, "Tên", Vector2(16, 48), Vector2(120, 15), 11, Color.WHITE)
	MuUiSkinRes.text(self, "Máy chủ", Vector2(170, 48), Vector2(110, 15), 11, Color.WHITE)
	var pane := ColorRect.new()
	pane.color = Color(0, 0, 0, 0.7)
	pane.position = Vector2(12, 64) * S
	pane.size = Vector2(W - 24, H - 64 - 44) * S
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pane)
	_list = Control.new()
	_list.position = pane.position
	_list.size = pane.size
	_list.clip_contents = true
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	# hàng nút
	_win_button("Thêm", Vector2(12, H - 38), Vector2(56, 16), _on_add)
	_win_button("Xóa", Vector2(72, H - 38), Vector2(56, 16), _on_delete)
	_win_button("Chat", Vector2(132, H - 38), Vector2(56, 16), _on_chat)

func _nine(tex_name: String, r: Rect2, region: Rect2, margin: int) -> void:
	var n := NinePatchRect.new()
	n.texture = MuUiSkinRes.tex(tex_name)
	n.region_rect = region
	n.patch_margin_left = margin
	n.patch_margin_right = margin
	n.patch_margin_top = margin
	n.patch_margin_bottom = margin
	n.position = r.position * S
	n.size = r.size * S
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(n)

func _win_button(label: String, pos: Vector2, sz: Vector2, cb: Callable, col: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = label
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", col)
	var t := MuUiSkinRes.tex("win_button")
	if t:
		var sb := StyleBoxTexture.new()
		sb.texture = t
		sb.texture_margin_left = 6
		sb.texture_margin_right = 6
		sb.texture_margin_top = 4
		sb.texture_margin_bottom = 4
		b.add_theme_stylebox_override("normal", sb)
		var sbh: StyleBoxTexture = sb.duplicate()
		sbh.modulate_color = Color(1.2, 1.2, 1.2)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sb)
	b.position = pos * S
	b.size = sz * S
	b.pressed.connect(func():
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		cb.call())
	add_child(b)
	return b

func setup(p_social) -> void:
	social = p_social
	social.friends_changed.connect(_rebuild)

func toggle() -> void:
	if visible:
		close()
		return
	var vs := get_viewport_rect().size
	position = ((vs - size) * 0.5).floor()
	_rebuild()
	_refresh_reject()
	visible = true
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func close() -> void:
	visible = false

func _refresh_reject() -> void:
	_reject_box.color = Color(0.9, 0.8, 0.3) if social.reject_chat else HEAD

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	if social == null:
		return
	var y := 0.0
	if social.friends.is_empty():
		MuUiSkinRes.text(_list, "Chưa có bạn bè. Chạm vào người chơi rồi chọn [Kết bạn].", Vector2(4, 4), Vector2(W - 32, 13), 11, Color(0.75, 0.75, 0.75))
	for f in social.friends:
		var nm: String = f["name"]
		var sel := nm == _sel
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.position = Vector2(0, y) * S
		row.size = Vector2(W - 24, 13) * S
		var sb := StyleBoxFlat.new()
		sb.bg_color = SEL if sel else Color(0, 0, 0, 0)
		var sbh := StyleBoxFlat.new()
		sbh.bg_color = SEL if sel else HEAD
		row.add_theme_stylebox_override("normal", sb)
		row.add_theme_stylebox_override("hover", sbh)
		row.add_theme_stylebox_override("pressed", sbh)
		row.pressed.connect(func():
			_sel = nm
			_rebuild())
		_list.add_child(row)
		var online: bool = social.is_online(nm)
		var col := Color.BLACK if sel else Color.WHITE
		MuUiSkinRes.text(_list, nm, Vector2(4, y), Vector2(150, 13), 11, col)
		MuUiSkinRes.text(_list, "Lorencia (Online)" if online else "Offline", Vector2(158, y), Vector2(110, 13), 11,
			col if sel else (Color(0.4, 1, 0.4) if online else Color(0.6, 0.6, 0.6)))
		y += 13.0

func _on_add() -> void:
	MuMsgBoxRes.open(get_tree().get_first_node_in_group("HUD"), [["Nhập tên nhân vật muốn kết bạn."]], func():
		var box = MuMsgBoxRes.active
		if box and box.get_input_text() != "":
			social.add_friend(box.get_input_text()), Callable(), {"input": true, "max_length": 10})

func _on_delete() -> void:
	if _sel == "":
		return
	MuMsgBoxRes.open(get_tree().get_first_node_in_group("HUD"), [["Xóa %s khỏi danh sách bạn bè?" % _sel]], func():
		social.delete_friend(_sel)
		_sel = "")

func _on_chat() -> void:
	if _sel == "":
		return
	if not social.is_online(_sel):
		social.msg("%s đang offline." % _sel)
		return
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.chat_window and hud.chat_window.has_method("start_whisper"):
		hud.chat_window.start_whisper(_sel)
	close()

func _gui_input(event: InputEvent) -> void:
	# kéo cửa sổ bằng thanh tiêu đề
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_drag = mb.pressed and mb.position.y < 24 * S
		_drag_off = mb.position
	var mm := event as InputEventMouseMotion
	if mm and _drag:
		position = (position + mm.position - _drag_off).clamp(Vector2.ZERO, get_viewport_rect().size - size)
	accept_event()
