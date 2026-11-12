extends Control
class_name DevilSquareWindow

## Cửa sổ vào Quảng Trường Quỷ của Charon (NPC 237) — port từ CEnterDevilSquare (UI/Events/EnterDevilSquare.cpp)
## và ReceiveMoveToDevilSquareResult (WSclient.cpp) của client gốc, luật vé theo OpenMU EnterMiniGameAction:
##   - 7 nút quảng trường; chỉ nút đúng khoảng cấp của nhân vật được bấm
##   - Magic Gladiator / Dark Lord / Rage Fighter dùng bảng cấp riêng (thấp hơn)
##   - Phải có Thiệp Mời Quỷ (Devil's Invitation, 14:19) đúng cấp quảng trường trong túi; vào thì mất thiệp

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")

const S := 1.5
const W := 230.0
const H := 330.0
const MAX_ENTER_GRADE := 7
const MIN_LEVEL := 15
const INVITATION := [14, 19]

## m_iDevilSquareLimitLevel của client gốc: [0] lớp thường, [1] MG / DL / RF
const LIMIT_LEVELS := [
	[[15, 130], [131, 180], [181, 230], [231, 280], [281, 330], [331, 400]],
	[[15, 110], [111, 160], [161, 210], [211, 260], [261, 310], [311, 400]],
]

## Vùng của từng quảng trường trên bản đồ Devil Square (World10 = map 9; quảng trường 5-7 ở map 32 = World33)
const SQUARES := [
	{"world": 10, "area": Rect2i(119, 80, 31, 35)},
	{"world": 10, "area": Rect2i(121, 152, 30, 32)},
	{"world": 10, "area": Rect2i(49, 138, 30, 35)},
	{"world": 10, "area": Rect2i(53, 74, 30, 35)},
	{"world": 33, "area": Rect2i(119, 80, 31, 35)},
	{"world": 33, "area": Rect2i(121, 152, 30, 32)},
	{"world": 33, "area": Rect2i(49, 138, 30, 35)},
]

const INTRO_LINES := [
	"Ngươi được trao cơ hội chứng minh lòng dũng cảm.",
	"Chưa ai từng bước vào Quảng Trường Quỷ...",
	"Chưa một con người nào đặt chân tới đó.",
	"Đừng tin bất cứ thứ gì ngươi thấy trong đó.",
	"Chỉ hãy tin vào lòng can đảm và sức mạnh.",
	"Chỉ chúng mới giữ được mạng sống của ngươi.",
]

var player: MuPlayer = null
var npc: Node3D = null
var body: Control
var _buttons: Array[Button] = []
var _active := 0

func _ready() -> void:
	visible = false
	add_to_group("MuDevilSquareWindow")
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S
	mouse_filter = Control.MOUSE_FILTER_STOP

	body = Control.new()
	body.size = Vector2(W, H) * S
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(body)
	MuUiSkinRes.build_frame(body, "Quảng Trường Quỷ (Devil Square)", W, H)
	MuUiSkinRes.close_button(body, W, close)

	var intro := MuUiSkinRes.font_label("\n".join(INTRO_LINES), 11, Color(0.95, 0.85, 0.6))
	intro.position = Vector2(12, 38) * S
	intro.size = Vector2(W - 24, 80) * S
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	for i in MAX_ENTER_GRADE:
		var b := Button.new()
		b.position = Vector2(20, 128 + i * 25) * S
		b.size = Vector2(W - 40, 21) * S
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_square_pressed.bind(i))
		body.add_child(b)
		_buttons.append(b)

	var note := MuUiSkinRes.font_label("Cần Thiệp Mời Quỷ đúng cấp quảng trường", 10, Color(0.75, 0.75, 0.75))
	note.position = Vector2(12, H - 22) * S
	note.size = Vector2(W - 24, 14) * S
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)

	_place()
	get_viewport().size_changed.connect(_place)

func _place() -> void:
	var vs := get_viewport_rect().size
	position = ((vs - Vector2(W, H) * S) * 0.5).max(Vector2.ZERO)

## Bảng cấp của lớp nhân vật: MG(3) / DL(4) / RF(6) dùng bảng thấp hơn (CLASS_DARK, CLASS_DARK_LORD, CLASS_RAGEFIGHTER)
static func limit_index(char_class: int) -> int:
	return 1 if char_class in [3, 4, 6] else 0

static func is_master(p: Node) -> bool:
	return p != null and (int(p.get("master_level") if p.get("master_level") != null else 0) > 0 or int(p.get("level")) > 400)

## CheckLimitLV: quảng trường (0..6) mà nhân vật được vào
static func active_square(p: Node) -> int:
	if p == null:
		return 0
	if is_master(p):
		return MAX_ENTER_GRADE - 1
	var lv := int(p.get("level"))
	var tbl: Array = LIMIT_LEVELS[limit_index(int(p.get("char_class")))]
	for i in tbl.size():
		if lv >= int(tbl[i][0]) and lv <= int(tbl[i][1]):
			return i
	return 0

func open_window(p_player: MuPlayer, p_npc: Node3D = null) -> void:
	player = p_player
	npc = p_npc
	_active = active_square(player)
	var li := limit_index(int(player.char_class)) if player else 0
	for i in MAX_ENTER_GRADE:
		var b := _buttons[i]
		if i < MAX_ENTER_GRADE - 1:
			var r: Array = LIMIT_LEVELS[li][i]
			b.text = "Quảng Trường %d (Cấp %d-%d)" % [i + 1, int(r[0]), int(r[1])]
		else:
			b.text = "Quảng Trường %d (Master Level)" % MAX_ENTER_GRADE
		b.disabled = i != _active
		b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if i == _active else Color(0.5, 0.5, 0.5))
	_place()
	visible = true
	move_to_front()
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func close() -> void:
	visible = false

func _process(_d: float) -> void:
	if visible and player and npc and is_instance_valid(npc) and player.global_position.distance_to(npc.global_position) > 6.0:
		close()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if visible and k and k.pressed and k.keycode == KEY_ESCAPE:
		close()
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		get_viewport().set_input_as_handled()

func _gui_input(_event: InputEvent) -> void:
	accept_event()

func _msg(text: String, col: Color = Color(1.0, 0.85, 0.4)) -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(text, col)
	var chat = get_tree().get_first_node_in_group("ChatWindow")
	if chat and chat.has_method("add_system_message"):
		chat.add_system_message("[color=#FF9966][b][Charon][/b][/color] " + text)

func _find_invitation(square: int) -> Dictionary:
	for it in player.inventory:
		if int(it.get("group", -1)) == INVITATION[0] and int(it.get("number", -1)) == INVITATION[1] and int(it.get("level", 0)) == square + 1:
			return it
	return {}

## SendDevilSquareEnterRequest + kết quả của server (mã 1..6 trong ReceiveMoveToDevilSquareResult)
func _on_square_pressed(i: int) -> void:
	if player == null or i != _active:
		return
	close()
	if int(player.level) < MIN_LEVEL:
		_msg("Muốn sống sót thì hãy chọn quảng trường khác! (cần cấp %d trở lên)" % MIN_LEVEL, Color(1.0, 0.4, 0.3))
		return
	var ticket := _find_invitation(i)
	if ticket.is_empty():
		_msg("Hãy mang Thiệp Mời Quỷ +%d để vào. (Bring the Devil's invitation to enter.)" % (i + 1), Color(1.0, 0.4, 0.3))
		return
	var sq: Dictionary = SQUARES[i]
	var world := int(sq["world"])
	if not MuTerrain.has_map(world):
		_msg("Quảng Trường %d chưa có bản đồ trong client Godot." % (i + 1), Color(1.0, 0.4, 0.3))
		return
	player.inv_remove(ticket)
	var area: Rect2i = sq["area"]
	var spawn := area.position + Vector2i(randi_range(0, area.size.x), randi_range(0, area.size.y))
	_msg("Ngươi đã bước vào Quảng Trường Quỷ %d. Hãy chứng minh lòng dũng cảm!" % (i + 1), Color(1.0, 0.5, 0.3))
	if MuAudioManager:
		MuAudioManager.play_ui_button()
	MuTerrain.change_world(world, spawn)
	get_tree().call_deferred("reload_current_scene")
