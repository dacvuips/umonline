extends Control
class_name RavenCommandBar

## Lệnh Quạ Tinh — clone hàng lệnh thú trong danh sách skill gốc (CSkillList: #pet_skill_row, main_frame.rcss legacy)
## + tooltip BuildPetCmdTooltipModel (GameLogic/Pets/GIPetManager.cpp):
##   4 ô 32x38 nối nhau (pitch 32), khung newui_skillbox.jpg ; ô của lệnh đang chọn (Hero->CurrentSkill) newui_skillbox2.jpg
##   icon 20x28 tại (6, 6) trong ô: newui_command.jpg, cột = số lệnh (20 px mỗi cột), hàng 0 ;
##   newui_non_command.jpg khi lệnh không dùng được (thiếu Quạ / quạ hết độ bền)
##   chữ phím tắt góc dưới phải (đậm, viền đen) — chỉ hiện khi lệnh được gán phím tắt (Shift + 1..4 trên PC)
##   tooltip: tên lệnh xanh đậm, 2 dòng trống, dòng mô tả trắng.
## Game gốc: chọn ô = đặt lệnh hiện tại, chuột phải để gửi ; điện thoại: chạm vào ô = chọn + gửi luôn.

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const MuItemUiRes = preload("res://src/ui/MuItemUi.gd")
const S := 1.5
## kPetCommandNames / Tooltip theo thứ tự PET_COMMAND
const NAMES := ["Hành động cơ bản", "Tấn công tự động ngẫu nhiên", "Tấn công cùng chủ nhân", "Tấn công mục tiêu"]
const DESCS := ["Bay theo xung quanh nhân vật.", "Tấn công bất kỳ quái vật nào quanh nhân vật.",
	"Tấn công quái vật cùng với nhân vật.", "Tấn công quái vật mà nhân vật đang chọn."]
const TEXT_BLUE := Color(0.5, 0.7, 1.0)

var player: MuPlayer = null
var current := 0
var _cells: Array = []
var _icons: Array = []
var _tex_box: Texture2D
var _tex_box_use: Texture2D
var _tex_cmd: Texture2D
var _tex_non: Texture2D
var _tip_timer := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_tex_box = MuUiSkinRes.tex("newui_skillbox")
	_tex_box_use = MuUiSkinRes.tex("newui_skillbox2")
	_tex_cmd = MuUiSkinRes.tex("newui_command")
	_tex_non = MuUiSkinRes.tex("newui_non_command")
	size = Vector2(4 * 32, 38) * S
	for i in 4:
		var cell := TextureButton.new()
		cell.ignore_texture_size = true
		cell.stretch_mode = TextureButton.STRETCH_SCALE
		cell.position = Vector2(i * 32, 0) * S
		cell.size = Vector2(32, 38) * S
		cell.focus_mode = Control.FOCUS_NONE
		cell.pressed.connect(_on_cell.bind(i))
		cell.mouse_entered.connect(_show_tip.bind(i))
		cell.mouse_exited.connect(_hide_tip)
		add_child(cell)
		_cells.append(cell)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.position = Vector2(6, 6) * S
		icon.size = Vector2(20, 28) * S
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		_icons.append(icon)
		# .skill-hotkey-label: phải 3, dưới 2, đậm trắng viền đen
		var key := Label.new()
		key.text = str(i + 1)
		key.add_theme_font_size_override("font_size", 12)
		key.add_theme_color_override("font_color", Color.WHITE)
		key.add_theme_color_override("font_outline_color", Color.BLACK)
		key.add_theme_constant_override("outline_size", 3)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		key.size = Vector2(32 - 3, 38 - 2) * S
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(key)
	get_viewport().size_changed.connect(_place)
	_place()

func setup(p: MuPlayer) -> void:
	player = p
	refresh()

## Hàng lệnh thú nằm ngay trên ô đầu của danh sách skill (top -38) ; ở HUD điện thoại: giữa, trên khung chat
func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(floorf((vs.x - size.x) * 0.5), vs.y - 180.0 - size.y - 6.0)

func _raven():
	return player.dark_raven if player and is_instance_valid(player.dark_raven) else null

func refresh() -> void:
	var r = _raven()
	visible = r != null
	if r != null:
		current = int(r.command)
	var usable: bool = r != null
	for i in 4:
		var c := _cells[i] as TextureButton
		var t := _tex_box_use if i == current else _tex_box
		c.texture_normal = t
		c.texture_pressed = _tex_box_use
		c.texture_hover = t
		var src := _tex_cmd if usable else _tex_non
		(_icons[i] as TextureRect).texture = MuUiSkinRes.atlas_sub(src, Rect2(i * 20, 0, 20, 28)) if src else null

func _on_cell(i: int) -> void:
	# chọn lệnh (Hero->CurrentSkill) + PlayBuffer(SOUND_CLICK01)
	current = i
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	send_command(i)
	_show_tip(i)
	_tip_timer = 1.5

## SendPetCommand
func send_command(i: int) -> void:
	var r = _raven()
	if r == null:
		return
	if i == 3:
		var t = player.target_monster
		if t == null or not is_instance_valid(t) or t.is_dead:
			var hud = get_tree().get_first_node_in_group("HUD")
			if hud:
				hud.show_pickup_notification("Hãy chọn quái vật để Quạ Tinh tấn công.", Color(1.0, 0.6, 0.4))
			refresh()
			return
		r.set_command(i, t)
	else:
		r.set_command(i)
	refresh()

func _show_tip(i: int) -> void:
	var ui = MuItemUiRes.get_ui(get_tree())
	if ui:
		ui.show_tip([[NAMES[i], TEXT_BLUE], [" ", Color.WHITE], [" ", Color.WHITE], [DESCS[i], Color.WHITE]])

func _hide_tip() -> void:
	if _tip_timer > 0.0:
		return
	var ui = MuItemUiRes.get_ui(get_tree())
	if ui:
		ui.hide_tip()

func _process(d: float) -> void:
	if _tip_timer > 0.0:
		_tip_timer -= d
		if _tip_timer <= 0.0:
			_hide_tip()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if visible and k and k.pressed and not k.echo and k.shift_pressed and k.keycode >= KEY_1 and k.keycode <= KEY_4:
		_on_cell(k.keycode - KEY_1)
		get_viewport().set_input_as_handled()
