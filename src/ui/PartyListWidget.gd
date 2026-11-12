extends Control
class_name PartyListWidget

## Danh sách tổ đội trên màn hình — clone CPartyListWindow (party_list.rcss legacy):
##   mỗi thẻ 77x23: nền newui_party_back + lớp đen, tên (4,4) trắng / trưởng nhóm cam #ff9416 (xám khi ở xa),
##   cờ trưởng nhóm (53,3), thanh máu newui_party_hpbar (4,16) 69x3, nút rời nhóm newui_party_x (63,3) trên thẻ của mình.
## Chạm vào thẻ: mở cửa sổ Tổ đội.

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const S := 1.5

var social = null
var _bars: Dictionary = {}
var _names: Dictionary = {}
var _tick := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func setup(p_social) -> void:
	social = p_social
	social.party_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_bars.clear()
	_names.clear()
	visible = social != null and social.in_party()
	if not visible:
		return
	for i in social.party.size():
		var nm: String = social.party[i]
		var card := Control.new()
		card.position = Vector2(0, i * 24) * S
		card.size = Vector2(77, 23) * S
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input)
		add_child(card)
		var fill := ColorRect.new()
		fill.color = Color(0, 0, 0, 0.9)
		fill.position = Vector2(2, 2) * S
		fill.size = Vector2(74, 17) * S
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fill)
		MuUiSkinRes.img(card, "newui_party_back", Vector2.ZERO, Vector2(77, 23))
		var leader: bool = i == 0
		_names[nm] = MuUiSkinRes.text(card, nm, Vector2(4, 2), Vector2(56, 13), 11, Color("#ff9416") if leader else Color.WHITE)
		if leader:
			MuUiSkinRes.img(card, "newui_party_flag", Vector2(53, 3), Vector2(9, 10))
		_bars[nm] = MuUiSkinRes.img(card, "newui_party_hpbar", Vector2(4, 16), Vector2(69, 3))
		if nm == social._hero_name():
			var x := TextureButton.new()
			var t := MuUiSkinRes.tex("newui_party_x")
			if t:
				x.texture_normal = MuUiSkinRes.atlas_sub(t, Rect2(0, 0, 11, 11))
				x.texture_pressed = MuUiSkinRes.atlas_sub(t, Rect2(0, 11, 11, 11))
			x.ignore_texture_size = true
			x.stretch_mode = TextureButton.STRETCH_SCALE
			x.position = Vector2(63, 3) * S
			x.size = Vector2(11, 11) * S
			x.tooltip_text = "Rời tổ đội"
			x.pressed.connect(social.leave_party)
			card.add_child(x)
	size = Vector2(77, social.party.size() * 24) * S
	_update()

func _on_card_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("toggle_party_window"):
			hud.toggle_party_window()

func _update() -> void:
	for i in social.party.size():
		var nm: String = social.party[i]
		if not _bars.has(nm):
			continue
		var info: Dictionary = social.member_info(nm)
		var r := clampf(float(info["hp"]) / maxf(1.0, float(info["max_hp"])), 0.0, 1.0)
		_bars[nm].size.x = 69.0 * r * S
		var base := Color("#ff9416") if i == 0 else Color.WHITE
		var far := Color("#804b0b") if i == 0 else Color(0.5, 0.5, 0.5)
		_names[nm].add_theme_color_override("font_color", base if info["near"] else far)

func _process(d: float) -> void:
	if not visible or social == null:
		return
	_tick -= d
	if _tick <= 0.0:
		_tick = 0.25
		_update()
