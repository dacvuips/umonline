extends Control
class_name MuCharacterSelect

## Màn hình Chọn Nhân Vật (Character Selection Scene) MU Online
## Tái hiện 100% đồ họa gốc theo đúng bản Season 6 / Webzen:
## - Nền World 75 huyền ảo (Rừng tím, thác nước, sao đêm, 5 bục đá cổ)
## - 5 Bục đá tương ứng 5 Slot nhân vật, mỗi nhân vật đứng trên bục riêng
## - Bảng thông tin nhân vật nổi phía trên đầu (character_ex.png, 118x54)
## - Khung thông báo tư cách đăng nhập góc trên bên trái (cha_id.png, 346x38)
## - Khung hoa văn bạc góc dưới bên phải bao quanh nút Connect & Delete (deco.png, 189x103)
## - Các nút chuẩn: Create (viền vàng cam rực), Menu, Connect, Delete (54x30)
## - Con trỏ chuột găng tay sắt cổ điển (Cursor.png)

# Tài nguyên hình ảnh gốc
const TEX_CHA_ID := preload("res://assets/textures/ui/cha_id.png")
const TEX_BALLOON := preload("res://assets/textures/ui/character_ex.png")
const TEX_DECO := preload("res://assets/textures/ui/deco.png")
const TEX_BTN_CREATE := preload("res://assets/textures/ui/b_create.png")
const TEX_BTN_MENU := preload("res://assets/textures/ui/server_menu_b_all.png")
const TEX_BTN_CONNECT := preload("res://assets/textures/ui/b_connect.png")
const TEX_BTN_DELETE := preload("res://assets/textures/ui/b_delete.png")
const TEX_CURSOR := preload("res://assets/textures/ui/Cursor.png")
const SND_MOVE := "res://assets/mu/Sound/iButtonMove.wav"
const SND_CLICK := "res://assets/mu/Sound/iButtonClick.wav"

# Nodes trong Scene
@onready var char_balloon: Control = $CharBalloon
@onready var lbl_balloon_name: Label = $CharBalloon/LblName
@onready var lbl_balloon_guild: Label = $CharBalloon/LblGuild
@onready var lbl_balloon_class_level: Label = $CharBalloon/LblClassLevel

@onready var btn_create: TextureButton = $BottomLeft/BtnCreate
@onready var btn_menu: TextureButton = $BottomLeft/BtnMenu
@onready var btn_connect: TextureButton = $BottomRight/BtnConnect
@onready var btn_delete: TextureButton = $BottomRight/BtnDelete
@onready var delete_confirm_dialog: ConfirmationDialog = $DeleteConfirmDialog

# System Menu Modal chuẩn theo ảnh người dùng (media_1794201850505_bd65f9d6)
@onready var sys_menu_modal: Control = $SysMenuModal
@onready var sys_menu_backdrop: Button = $SysMenuModal/Backdrop
@onready var btn_sys_exit_game: TextureButton = $SysMenuModal/Panel/BtnExitGame
@onready var btn_sys_select_server: TextureButton = $SysMenuModal/Panel/BtnSelectServer
@onready var btn_sys_option: TextureButton = $SysMenuModal/Panel/BtnOption
@onready var btn_sys_close: TextureButton = $SysMenuModal/Panel/BtnClose

# Character Creation Modal (CharMakeWin) chuẩn source gốc MU Season 6/9
@onready var char_make_modal: Control = $CharMakeModal

var option_window: Control = null

@onready var pedestal_slots: Node3D = $PreviewViewportContainer/SubViewport/PedestalSlots
@onready var click_areas_parent: Control = $PedestalClickAreas

# Vị trí X trên màn hình của 5 bục tương ứng để gắn bảng Balloon
## Độ cao (đơn vị scene 3D) từ chân bục tới chỗ đặt bảng tên, đủ cao để vượt đầu cả nhân vật cưỡi thú
const BALLOON_HEAD_HEIGHT: float = 1.75

@onready var preview_camera: Camera3D = $PreviewViewportContainer/SubViewport/Camera3D
var slot_balloons: Array[Control] = []

var spawned_models: Array[Node3D] = [null, null, null, null, null]
var slot_click_areas: Array[Button] = []
var last_clicked_slot: int = -1
var last_click_time: float = 0.0



func _ready() -> void:
	# Áp dụng con trỏ chuột găng tay sắt MU Online
	if TEX_CURSOR:
		Input.set_custom_mouse_cursor(TEX_CURSOR, Input.CURSOR_ARROW, Vector2(1, 1))

	# Nền 3D World 75 (Rừng tím và thác nước Season 6)
	MuSceneBackground3D.attach(self, MuSceneBackground3D.S6_CHARACTER_WORLD)

	# Đảm bảo nạp danh sách nhân vật tài khoản hiện tại từ disk
	_setup_network_or_demo_data()

	# Hiển thị máy chủ thật và tài khoản thật đã kết nối
	var notice_lbl = get_node_or_null("TopLeftNotice/NoticeLabel") as Label
	if notice_lbl:
		notice_lbl.text = "Máy chủ: %s - %s | Tài khoản: %s" % [
			MuAccountSession.selected_server_group,
			MuAccountSession.selected_server_channel,
			MuAccountSession.get_active_account()
		]

	_setup_button_textures()
	_setup_click_areas()
	_spawn_all_characters_on_pedestals()

	# Chọn slot mặc định (Slot 0 hoặc slot đã lưu)
	var initial_slot = clampi(MuAccountSession.selected_slot, 0, 4)
	_select_slot(initial_slot)

	# Kết nối sự kiện nút bấm thanh dưới
	btn_create.pressed.connect(_on_create_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)
	btn_connect.pressed.connect(_on_connect_pressed)
	btn_delete.pressed.connect(_on_delete_pressed)

	# Kết nối sự kiện modal tạo nhân vật
	if char_make_modal and char_make_modal.has_signal("character_created"):
		char_make_modal.character_created.connect(_on_character_created)

	# Kết nối sự kiện System Menu chuẩn trong hình (media_1794201850505_bd65f9d6)
	btn_sys_exit_game.pressed.connect(_on_sys_exit_game_pressed)
	btn_sys_select_server.pressed.connect(_on_sys_select_server_pressed)
	btn_sys_option.pressed.connect(_on_sys_option_pressed)
	btn_sys_close.pressed.connect(_on_sys_close_pressed)
	sys_menu_backdrop.pressed.connect(_on_sys_close_pressed)

	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)

	MuAudioManager.play_ui_window()

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

## Thiết lập texture chuẩn 4 trạng thái cho các nút
func _setup_button_textures() -> void:
	# 1. Nút Create (b_create.png: 54x120 -> 4 frame 54x30)
	var create_normal = AtlasTexture.new()
	create_normal.atlas = TEX_BTN_CREATE
	create_normal.region = Rect2(0, 0, 54, 30)

	var create_hover = AtlasTexture.new()
	create_hover.atlas = TEX_BTN_CREATE
	create_hover.region = Rect2(0, 30, 54, 30)

	var create_pressed = AtlasTexture.new()
	create_pressed.atlas = TEX_BTN_CREATE
	create_pressed.region = Rect2(0, 60, 54, 30)

	var create_disabled = AtlasTexture.new()
	create_disabled.atlas = TEX_BTN_CREATE
	create_disabled.region = Rect2(0, 90, 54, 30)

	btn_create.texture_normal = create_normal
	btn_create.texture_hover = create_hover
	btn_create.texture_pressed = create_pressed
	btn_create.texture_disabled = create_disabled
	btn_create.mouse_entered.connect(func(): if not btn_create.disabled: _play_sound(SND_MOVE))
	var lbl_create = btn_create.get_node_or_null("Lbl") as Label
	if lbl_create:
		lbl_create.text = ""
		lbl_create.visible = false

	# 2. Nút Menu (server_menu_b_all.png: 54x90 -> 3 frame 54x30)
	var menu_normal = AtlasTexture.new()
	menu_normal.atlas = TEX_BTN_MENU
	menu_normal.region = Rect2(0, 0, 54, 30)

	var menu_hover = AtlasTexture.new()
	menu_hover.atlas = TEX_BTN_MENU
	menu_hover.region = Rect2(0, 30, 54, 30)

	var menu_pressed = AtlasTexture.new()
	menu_pressed.atlas = TEX_BTN_MENU
	menu_pressed.region = Rect2(0, 60, 54, 30)

	btn_menu.texture_normal = menu_normal
	btn_menu.texture_hover = menu_hover
	btn_menu.texture_pressed = menu_pressed
	btn_menu.mouse_entered.connect(func(): _play_sound(SND_MOVE))
	var lbl_menu = btn_menu.get_node_or_null("Lbl") as Label
	if lbl_menu:
		lbl_menu.text = ""
		lbl_menu.visible = false

	# 3. Nút Connect (b_connect.png: 54x120 -> 4 frame 54x30)
	var connect_normal = AtlasTexture.new()
	connect_normal.atlas = TEX_BTN_CONNECT
	connect_normal.region = Rect2(0, 0, 54, 30)

	var connect_hover = AtlasTexture.new()
	connect_hover.atlas = TEX_BTN_CONNECT
	connect_hover.region = Rect2(0, 30, 54, 30)

	var connect_pressed = AtlasTexture.new()
	connect_pressed.atlas = TEX_BTN_CONNECT
	connect_pressed.region = Rect2(0, 60, 54, 30)

	var connect_disabled = AtlasTexture.new()
	connect_disabled.atlas = TEX_BTN_CONNECT
	connect_disabled.region = Rect2(0, 90, 54, 30)

	btn_connect.texture_normal = connect_normal
	btn_connect.texture_hover = connect_hover
	btn_connect.texture_pressed = connect_pressed
	btn_connect.texture_disabled = connect_disabled
	btn_connect.mouse_entered.connect(func(): if not btn_connect.disabled: _play_sound(SND_MOVE))
	var lbl_connect = btn_connect.get_node_or_null("Lbl") as Label
	if lbl_connect:
		lbl_connect.text = ""
		lbl_connect.visible = false

	# 4. Nút Delete (b_delete.png: 54x120 -> 4 frame 54x30)
	var delete_normal = AtlasTexture.new()
	delete_normal.atlas = TEX_BTN_DELETE
	delete_normal.region = Rect2(0, 0, 54, 30)

	var delete_hover = AtlasTexture.new()
	delete_hover.atlas = TEX_BTN_DELETE
	delete_hover.region = Rect2(0, 30, 54, 30)

	var delete_pressed = AtlasTexture.new()
	delete_pressed.atlas = TEX_BTN_DELETE
	delete_pressed.region = Rect2(0, 60, 54, 30)

	var delete_disabled = AtlasTexture.new()
	delete_disabled.atlas = TEX_BTN_DELETE
	delete_disabled.region = Rect2(0, 90, 54, 30)

	btn_delete.texture_normal = delete_normal
	btn_delete.texture_hover = delete_hover
	btn_delete.texture_pressed = delete_pressed
	btn_delete.texture_disabled = delete_disabled
	btn_delete.mouse_entered.connect(func(): if not btn_delete.disabled: _play_sound(SND_MOVE))
	var lbl_delete = btn_delete.get_node_or_null("Lbl") as Label
	if lbl_delete:
		lbl_delete.text = ""
		lbl_delete.visible = false

	# 5. 4 Nút trong bảng System Menu (Thoát khỏi trò chơi, Chọn máy chủ, Tùy chọn, Đóng lại)
	for b in [btn_sys_exit_game, btn_sys_select_server, btn_sys_option, btn_sys_close]:
		b.mouse_entered.connect(func(): _play_sound(SND_MOVE))

## Thiết lập dữ liệu mẫu chuẩn theo ảnh (HieuDev, Phù Thủy 14) nếu chưa có dữ liệu
## Thiết lập danh sách 5 slot nhân vật (Tài khoản mới bắt đầu với 0 nhân vật)
func _setup_network_or_demo_data() -> void:
	MuAccountSession.load_account_characters(MuAccountSession.get_active_account())

## Thiết lập 5 vùng chạm chọn bục đá trên màn hình
func _setup_click_areas() -> void:
	slot_click_areas.clear()
	for i in range(5):
		var area = click_areas_parent.get_node_or_null("Area%d" % i) as Button
		if area:
			var slot_idx = i
			area.pressed.connect(func(): _on_pedestal_clicked(slot_idx))
			area.mouse_entered.connect(func(): _on_pedestal_hovered(slot_idx))
			slot_click_areas.append(area)

func _on_pedestal_hovered(slot_idx: int) -> void:
	var chars = MuAccountSession.character_list
	if slot_idx < chars.size() and not chars[slot_idx].is_empty():
		_play_sound(SND_MOVE)

func _on_pedestal_clicked(slot_idx: int) -> void:
	_play_sound(SND_CLICK)
	_select_slot(slot_idx)

	var now = Time.get_ticks_msec() / 1000.0
	if last_clicked_slot == slot_idx and (now - last_click_time) < 0.4:
		# Nhấp đúp vào bục có nhân vật -> vào game ngay
		var chars = MuAccountSession.character_list
		if slot_idx < chars.size() and not chars[slot_idx].is_empty():
			_connect_to_game()
	last_click_time = now
	last_clicked_slot = slot_idx

## Tạo các model 3D đứng đồng thời trên từng bục đá
func _spawn_all_characters_on_pedestals() -> void:
	for i in range(5):
		if spawned_models[i] and is_instance_valid(spawned_models[i]):
			spawned_models[i].queue_free()
			spawned_models[i] = null

		var slot_node = pedestal_slots.get_node_or_null("Slot%d" % i)
		if not slot_node:
			continue
		var old_fx = slot_node.get_node_or_null("HelperFx")
		if old_fx:
			slot_node.remove_child(old_fx)
			old_fx.queue_free()

		var chars = MuAccountSession.character_list
		if i < chars.size() and not chars[i].is_empty():
			var char_data = chars[i]
			var cid = MuAccountSession.normalize_class_id(int(char_data.get("class_id", 0)))
			var eq = char_data.get("equipment", {})

			var char_model_script = load("res://src/mu/MuCharacterModel.gd")
			if char_model_script:
				var model = char_model_script.new()
				slot_node.add_child(model)
				if model.has_method("build_player"):
					model.build_player(cid, eq)
				if model.has_method("play_idle"):
					model.play_idle(true)
				# Tỷ lệ cân đối hoàn hảo trên mặt bục đá
				model.scale = Vector3(0.58, 0.58, 0.58)
				spawned_models[i] = model
				_attach_helper(slot_node, model, eq)

## Thú cưỡi / thú đi theo (ô "helper") của nhân vật trên bục chọn
func _attach_helper(slot_node: Node3D, model: Node3D, eq: Dictionary) -> void:
	var it = eq.get("helper")
	if not (it is Dictionary) or it.is_empty() or not MuHelperFx.is_visual_helper(it):
		return
	var fx := MuHelperFx.new()
	fx.name = "HelperFx"
	fx.preview = true
	fx.scale = model.scale   # cùng tỉ lệ với nhân vật trên bục
	slot_node.add_child(fx)
	fx.setup(model, it)
	var mi: Dictionary = MuHelperFx.mount_of(it)
	if not mi.is_empty():
		# thú cưỡi: nâng người lên + action ngồi trên thú (như ngoài map)
		var hn := int(it.get("number", 0))
		model.position.y = float(mi.get("lift", 0.0)) * model.scale.y
		model.ride_kind = "fenrir" if hn == 37 else ("darkhorse" if hn == 4 else ("unidino" if hn == 2 or hn == 3 else ""))
		model.play_action(int(mi.get("p_idle", 13)))

## Chọn bục đá và cập nhật bảng thông tin Balloon
func _select_slot(slot_idx: int) -> void:
	MuAccountSession.selected_slot = slot_idx
	var chars = MuAccountSession.character_list
	var has_char: bool = slot_idx < chars.size() and not chars[slot_idx].is_empty()

	_refresh_balloons()
	if has_char:
		# Bật các nút tương tác
		btn_connect.disabled = false
		btn_connect.modulate = Color(1.0, 1.0, 1.0, 1.0)

		btn_delete.disabled = false
		btn_delete.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		# Bục trống: vô hiệu nút Connect / Delete (bảng tên của bục trống đã ẩn trong _refresh_balloons)
		btn_connect.disabled = true
		btn_connect.modulate = Color(1.0, 1.0, 1.0, 1.0)
		btn_delete.disabled = true
		btn_delete.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Đã cập nhật slot chọn
	pass

## Bảng tên của MỌI nhân vật hiện sẵn trên đầu từng bục (không cần click mới hiện).
## CharBalloon trong scene chỉ là mẫu: nhân bản ra 5 cái, mỗi cái một slot.
func _ensure_balloons() -> void:
	if not slot_balloons.is_empty():
		return
	char_balloon.visible = false
	for i in range(5):
		var b := char_balloon.duplicate() as Control
		b.name = "SlotBalloon%d" % i
		b.visible = false
		char_balloon.get_parent().add_child(b)
		var slot_idx := i
		b.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_pedestal_clicked(slot_idx))
		slot_balloons.append(b)

func _refresh_balloons() -> void:
	_ensure_balloons()
	var chars = MuAccountSession.character_list
	for i in range(5):
		var b: Control = slot_balloons[i]
		if i >= chars.size() or chars[i].is_empty():
			b.visible = false
			continue
		var char_data = chars[i]
		var c_guild: String = str(char_data.get("guild", "Người bình thường"))
		if c_guild == "":
			c_guild = "Người bình thường"
		(b.get_node("LblName") as Label).text = str(char_data.get("name", "Player"))
		(b.get_node("LblGuild") as Label).text = "(%s)" % c_guild if not "(" in c_guild else c_guild
		(b.get_node("LblClassLevel") as Label).text = "%s %d" % [
			_get_class_title(int(char_data.get("class_id", 0))), int(char_data.get("level", 1))]
		b.visible = true
		# Bảng của nhân vật đang chọn sáng rõ, các bảng khác hơi mờ
		b.modulate = Color(1, 1, 1, 1) if i == MuAccountSession.selected_slot else Color(1, 1, 1, 0.8)
	_update_balloon_positions()

## Đặt bảng tên ngay trên đầu từng nhân vật theo camera 3D hiện tại
func _update_balloon_positions() -> void:
	if slot_balloons.is_empty() or preview_camera == null:
		return
	var vp := preview_camera.get_viewport()
	var scale_to_ui := Vector2.ONE
	if vp and vp.size.x > 0 and vp.size.y > 0:
		scale_to_ui = size / Vector2(vp.size)
	for i in range(5):
		var b: Control = slot_balloons[i]
		if not b.visible:
			continue
		var slot_node = pedestal_slots.get_node_or_null("Slot%d" % i)
		if slot_node == null:
			continue
		var head: Vector3 = (slot_node as Node3D).global_position + Vector3(0, BALLOON_HEAD_HEIGHT, 0)
		var p := preview_camera.unproject_position(head) * scale_to_ui
		b.position = p - Vector2(59.0, 54.0)

func _process(_delta: float) -> void:
	_update_balloon_positions()

func _get_class_title(cid: int) -> String:
	return MuAccountSession.get_class_title(cid)

func _on_create_pressed() -> void:
	_play_sound(SND_CLICK)
	if sys_menu_modal and sys_menu_modal.visible:
		sys_menu_modal.visible = false
	if char_make_modal:
		char_make_modal.open_dialog()

func _on_character_created(char_data: Dictionary) -> void:
	_spawn_all_characters_on_pedestals()
	var slot = char_data.get("slot", 0)
	_select_slot(slot)

func _on_menu_pressed() -> void:
	_play_sound(SND_CLICK)
	sys_menu_modal.visible = not sys_menu_modal.visible

func _on_sys_close_pressed() -> void:
	_play_sound(SND_CLICK)
	sys_menu_modal.visible = false

func _on_sys_select_server_pressed() -> void:
	_play_sound(SND_CLICK)
	sys_menu_modal.visible = false
	get_tree().change_scene_to_file("res://src/scenes/ServerSelectScene.tscn")

func _on_sys_option_pressed() -> void:
	_play_sound(SND_CLICK)
	sys_menu_modal.visible = false
	if not option_window or not is_instance_valid(option_window):
		var opt = load("res://src/ui/MuOptionWindow.gd")
		if opt:
			option_window = opt.new()
			option_window.z_index = 30
			add_child(option_window)
	if option_window and is_instance_valid(option_window):
		if option_window.has_method("open_window"):
			option_window.open_window()
		else:
			option_window.visible = true

func _on_sys_exit_game_pressed() -> void:
	_play_sound(SND_CLICK)
	get_tree().quit()

func _on_connect_pressed() -> void:
	_connect_to_game()

func _connect_to_game() -> void:
	var chars = MuAccountSession.character_list
	var s_idx = MuAccountSession.selected_slot
	if s_idx < 0 or s_idx >= chars.size() or chars[s_idx].is_empty():
		return

	_play_sound(SND_CLICK)
	var char_data = chars[s_idx]
	MuAccountSession.selected_character_name = char_data.get("name", "Player")

	# Phải tải XONG toàn bộ gói game (tier 2) rồi mới vào thế giới; chưa xong thì hiện màn chặn có tiến độ.
	await MuContent.require_tier(2)

	# Vào lại đúng map + vị trí đã thoát lần trước; nhân vật mới / chưa có dữ liệu thì về Lorencia (World 1)
	var saved_map := int(char_data.get("map_id", 0))
	if saved_map > 0 and char_data.has("pos_x") and MuTerrain.has_map(saved_map):
		MuTerrain.change_world(saved_map, Vector2i(int(char_data["pos_x"]), int(char_data["pos_y"])))
	else:
		MuTerrain.change_world(1)

	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://src/scenes/Main.tscn")

func _on_balloon_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var s_idx = MuAccountSession.selected_slot
		if s_idx >= 0:
			_on_pedestal_clicked(s_idx)

func _on_delete_pressed() -> void:
	var chars = MuAccountSession.character_list
	var s_idx = MuAccountSession.selected_slot
	if s_idx < 0 or s_idx >= chars.size() or chars[s_idx].is_empty():
		return
	_play_sound(SND_CLICK)
	var c_name = chars[s_idx].get("name", "Player")
	delete_confirm_dialog.dialog_text = "Bạn có chắc chắn muốn xóa nhân vật '%s' không?" % c_name
	delete_confirm_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	var s_idx = MuAccountSession.selected_slot
	if s_idx >= 0 and s_idx < MuAccountSession.character_list.size():
		MuAccountSession.delete_character_at(s_idx)
		_spawn_all_characters_on_pedestals()
		_select_slot(MuAccountSession.selected_slot if MuAccountSession.selected_slot >= 0 else 0)
		_play_sound(SND_CLICK)

func _unhandled_input(event: InputEvent) -> void:
	if char_make_modal and char_make_modal.visible:
		return
	if option_window and is_instance_valid(option_window) and option_window.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			if option_window.has_method("close_window"):
				option_window.close_window()
			else:
				option_window.visible = false
			return
	if not sys_menu_modal.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y >= 90.0 and event.position.y <= 660.0:
			var cx = event.position.x
			var target_slot = -1
			if cx < 320.0:
				target_slot = 0
			elif cx < 530.0:
				target_slot = 1
			elif cx < 750.0:
				target_slot = 2
			elif cx < 960.0:
				target_slot = 3
			elif cx < 1180.0:
				target_slot = 4
			
			if target_slot >= 0:
				_on_pedestal_clicked(target_slot)
				return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if sys_menu_modal.visible:
				_on_sys_close_pressed()
			else:
				_on_menu_pressed()
		elif not sys_menu_modal.visible:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
				_connect_to_game()
			elif event.keycode == KEY_LEFT:
				var prev_slot = (MuAccountSession.selected_slot - 1 + 5) % 5
				_play_sound(SND_MOVE)
				_select_slot(prev_slot)
			elif event.keycode == KEY_RIGHT:
				var next_slot = (MuAccountSession.selected_slot + 1) % 5
				_play_sound(SND_MOVE)
				_select_slot(next_slot)

func _play_sound(path: String) -> void:
	if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		MuAudioManager.play_sound_file(path, -2.0)
	else:
		MuAudioManager.play_ui_click()
