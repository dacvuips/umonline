extends Control
class_name ChatCommandWindow

## Danh sách lệnh chat (nút "Đặc biệt" của Command Window -> INTERFACE_COMMAND_LIST) — clone CChatCommandWindow
## (UI/Dialogs/ChatCommandWindow.cpp + chat_command.rcss legacy): khung 190x432, danh sách từ (22,36) rộng 146 hàng 15,
## hai nút newui_btn_empty_small ở y = 358: Quay lại (22) / Thực hiện (104).
## Chọn một lệnh rồi bấm Thực hiện: lệnh được điền vào ô chat (thêm tên người đang chọn nếu cần).

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const S := 1.5
const COMMANDS := [
	["/trade", "Giao dịch với người đứng cạnh", true],
	["/xemdo", "Xem trang bị người chơi", true],
	["/w", "Nói thầm (tên + lời nhắn)", true],
	["/party", "Mời vào tổ đội", true],
	["/guild", "Xin gia nhập guild", true],
	["/friend", "Kết bạn", true],
	["/duel", "Thách quyết đấu", true],
	["/follow", "Đi theo người chơi", true],
	["/leaveparty", "Rời tổ đội", false],
	["/event", "Lịch sự kiện", false],
	["/map", "Danh sách bản đồ", false],
	["/help", "Trợ giúp", false],
]

var target_name := ""
var _sel := -1
var _rows: Control

func _ready() -> void:
	visible = false
	z_index = 32
	add_to_group("MuChatCommandWindow")
	MuUiSkinRes.docked_window(self, "Lệnh đặc biệt", close)
	_rows = Control.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	MuUiSkinRes.text_button(self, "Đóng", Vector2(22, 358), Vector2(64, 29), close)
	MuUiSkinRes.text_button(self, "Thực hiện", Vector2(104, 358), Vector2(64, 29), _execute)

func open_for(p_target: String) -> void:
	target_name = p_target
	_sel = -1
	_rebuild()
	var vs := get_viewport_rect().size
	position = Vector2(maxf(0.0, vs.x - 190 * S), maxf(0.0, (vs.y - 429 * S) * 0.5))
	visible = true
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func close() -> void:
	visible = false

func _rebuild() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var y := 36.0
	for i in COMMANDS.size():
		var c: Array = COMMANDS[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(20, y) * S
		b.size = Vector2(150, 24) * S
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color8(106, 97, 88) if i == _sel else Color(0, 0, 0, 0)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(func():
			if _sel == i:
				_execute()
				return
			_sel = i
			_rebuild())
		_rows.add_child(b)
		MuUiSkinRes.text(_rows, str(c[0]), Vector2(22, y), Vector2(146, 12), 11, Color("#ffdc96"))
		MuUiSkinRes.text(_rows, str(c[1]), Vector2(30, y + 11), Vector2(140, 12), 10, Color(0.85, 0.85, 0.85))
		y += 26.0

func _execute() -> void:
	if _sel < 0:
		return
	var c: Array = COMMANDS[_sel]
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud == null or hud.chat_window == null:
		return
	var line: String = str(c[0])
	if bool(c[2]) and target_name != "":
		line += " " + target_name + " "
	elif not bool(c[2]):
		close()
		hud.chat_window._handle_command(line)
		return
	var ci = hud.chat_window.chat_input
	if ci:
		ci.text = line
		ci.grab_focus()
		ci.caret_column = line.length()
	close()

func _gui_input(event: InputEvent) -> void:
	accept_event()
