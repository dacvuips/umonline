extends Control
class_name MuServerSelect

## Màn hình Chọn Máy Chủ & Kênh (Server Selection Scene) MU Online
## Tái hiện 100% đồ họa gốc theo đúng bản gốc Webzen / InfinityMU:
## - Khung viền bạc cổ điển (Silver filigree ornament: server_deco_all.png)
## - Nút cụm máy chủ gốc: cha_bt.png (108x26, 4 frames: Idle, Hover, Pressed, Selected-Red)
## - Cánh mũi tên bạc chỉ vị trí cụm được chọn (server_deco_all.png right wing)
## - Nút phòng server gốc: server_b2_all.png (193x26, 3 frames: Idle, Hover, Pressed)
## - Thanh đo mức tải phòng 10 vạch gradient chuẩn: server_b2_loding.png (160x4)
## - Con trỏ chuột găng tay kim loại MU Online (Cursor.png)

# Tài nguyên hình ảnh gốc chuẩn Webzen
const TEX_CHA_BT := preload("res://assets/textures/ui/cha_bt.png")
const TEX_SERVER_B2 := preload("res://assets/textures/ui/login_classic/server_b2_all.png")
const TEX_SERVER_DECO := preload("res://assets/textures/ui/login_classic/server_deco_all.png")
const TEX_SERVER_LODING := preload("res://assets/textures/ui/server_b2_loding.png")
const TEX_CURSOR := preload("res://assets/textures/ui/Cursor.png")
const SND_MOVE := "res://assets/mu/Sound/iButtonMove.wav"
const SND_CLICK := "res://assets/mu/Sound/iButtonClick.wav"

# Nodes trong Scene
@onready var deco_top_left: TextureRect = $ServerDialog/GroupPanel/DecoTopLeft
@onready var group_vbox: VBoxContainer = $ServerDialog/GroupPanel/GroupVBox
@onready var selection_wing: TextureRect = $ServerDialog/GroupPanel/SelectionWing
@onready var channel_vbox: VBoxContainer = $ServerDialog/ChannelPanel/ChannelVBox
@onready var bg_texture: TextureRect = $Background
@onready var btn_back: Button = $BottomPrompt/BtnBack

var current_group_idx: int = 1 # Mặc định chọn InfinityMU theo ảnh
var current_channel_idx: int = 0
var group_buttons: Array[TextureButton] = []
var channel_buttons: Array[TextureButton] = []
var last_channel_click_time: float = 0.0
var last_clicked_channel_idx: int = -1

# Màu sắc chữ theo chuẩn MU
const COLOR_YELLOW := Color(1.0, 1.0, 0.47, 1.0) # #ffff79 cho Connect bình thường
const COLOR_WHITE := Color(1.0, 1.0, 1.0, 1.0)   # #ffffff khi Hover hoặc (Full)
const COLOR_FULL := Color(0.9, 0.9, 0.9, 1.0)    # Trắng sáng cho (Full)

func _ready() -> void:
	# Thiết lập con trỏ chuột găng tay kim loại gốc MU
	if TEX_CURSOR:
		Input.set_custom_mouse_cursor(TEX_CURSOR, Input.CURSOR_ARROW, Vector2(1, 1))
	
	# Nền 3D động Season 9 hoặc nền ảnh 720p
	MuSceneBackground3D.attach(self, MuSceneBackground3D.LOGIN_WORLD)
	
	# Khởi tạo hoa văn góc trên bên trái cụm server (server_deco_all: 0, 0, 67, 95)
	var deco_atlas = AtlasTexture.new()
	deco_atlas.atlas = TEX_SERVER_DECO
	deco_atlas.region = Rect2(0, 0, 67, 95)
	deco_top_left.texture = deco_atlas
	
	# Khởi tạo cánh mũi tên chỉ cụm được chọn (server_deco_all: 137, 0, 22, 28)
	var wing_atlas = AtlasTexture.new()
	wing_atlas.atlas = TEX_SERVER_DECO
	wing_atlas.region = Rect2(137, 0, 22, 28)
	selection_wing.texture = wing_atlas
	
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	
	current_group_idx = 0
	
	_build_group_list()
	_select_group(current_group_idx)
	MuAudioManager.play_ui_window()

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

## Tạo danh sách nút Cụm máy chủ (Cột trái)
func _build_group_list() -> void:
	for c in group_vbox.get_children():
		c.queue_free()
	group_buttons.clear()
	
	for i in range(MuAccountSession.SERVER_DATA.size()):
		var sdata = MuAccountSession.SERVER_DATA[i]
		var btn = _create_group_button(i, sdata.get("group_label", sdata.get("group_name", "")))
		group_vbox.add_child(btn)
		group_buttons.append(btn)

func _create_group_button(idx: int, label_text: String) -> TextureButton:
	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(108, 26)
	btn.size = Vector2(108, 26)
	
	# Thiết lập các frame texture từ cha_bt.png
	var tex_idle = AtlasTexture.new()
	tex_idle.atlas = TEX_CHA_BT
	tex_idle.region = Rect2(0, 0, 108, 26)
	
	var tex_hover = AtlasTexture.new()
	tex_hover.atlas = TEX_CHA_BT
	tex_hover.region = Rect2(0, 26, 108, 26)
	
	var tex_pressed = AtlasTexture.new()
	tex_pressed.atlas = TEX_CHA_BT
	tex_pressed.region = Rect2(0, 52, 108, 26)
	
	btn.texture_normal = tex_idle
	btn.texture_hover = tex_hover
	btn.texture_pressed = tex_pressed
	
	# Nhãn chữ hiển thị tên cụm
	var lbl = Label.new()
	lbl.name = "Label"
	lbl.anchors_preset = Control.PRESET_FULL_RECT
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.offset_top = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	btn.add_child(lbl)
	
	btn.mouse_entered.connect(func(): _play_sound(SND_MOVE))
	btn.pressed.connect(func(): _on_group_clicked(idx))
	return btn

func _on_group_clicked(g_idx: int) -> void:
	_play_sound(SND_CLICK)
	_select_group(g_idx)

func _select_group(g_idx: int) -> void:
	current_group_idx = g_idx
	
	for i in range(group_buttons.size()):
		var btn = group_buttons[i]
		if i == g_idx:
			# Nút đang chọn dùng Frame 3: nền đỏ ánh kim rực rỡ
			var tex_sel = AtlasTexture.new()
			tex_sel.atlas = TEX_CHA_BT
			tex_sel.region = Rect2(0, 78, 108, 26)
			btn.texture_normal = tex_sel
			btn.texture_hover = tex_sel
			
			# Định vị cánh hoa văn bạc chỉ vào danh sách phòng (29px mỗi nút = 26px height + 3px separation)
			selection_wing.visible = true
			selection_wing.position.x = 107.0
			selection_wing.position.y = g_idx * 29.0 + 5.0
		else:
			var tex_idle = AtlasTexture.new()
			tex_idle.atlas = TEX_CHA_BT
			tex_idle.region = Rect2(0, 0, 108, 26)
			var tex_hover = AtlasTexture.new()
			tex_hover.atlas = TEX_CHA_BT
			tex_hover.region = Rect2(0, 26, 108, 26)
			btn.texture_normal = tex_idle
			btn.texture_hover = tex_hover
	
	_build_channel_list()

## Tạo danh sách nút Kênh/Phòng máy chủ (Cột phải)
func _build_channel_list() -> void:
	for c in channel_vbox.get_children():
		c.queue_free()
	channel_buttons.clear()
	
	if current_group_idx < 0 or current_group_idx >= MuAccountSession.SERVER_DATA.size():
		return
	
	var gdata = MuAccountSession.SERVER_DATA[current_group_idx]
	var channels: Array = gdata.get("channels", [])
	
	for i in range(channels.size()):
		var ch = channels[i]
		var btn = _create_channel_button(i, ch)
		channel_vbox.add_child(btn)
		channel_buttons.append(btn)
	
	if not channels.is_empty():
		_highlight_channel(0)

func _create_channel_button(idx: int, ch_data: Dictionary) -> TextureButton:
	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(193, 26)
	btn.size = Vector2(193, 26)
	
	# Texture nút từ server_b2_all.png (193x78)
	var tex_idle = AtlasTexture.new()
	tex_idle.atlas = TEX_SERVER_B2
	tex_idle.region = Rect2(0, 0, 193, 26)
	
	var tex_hover = AtlasTexture.new()
	tex_hover.atlas = TEX_SERVER_B2
	tex_hover.region = Rect2(0, 26, 193, 26)
	
	var tex_pressed = AtlasTexture.new()
	tex_pressed.atlas = TEX_SERVER_B2
	tex_pressed.region = Rect2(0, 52, 193, 26)
	
	btn.texture_normal = tex_idle
	btn.texture_hover = tex_hover
	btn.texture_pressed = tex_pressed
	
	# Chuỗi nhãn phòng & trạng thái
	var ch_name = ch_data.get("name", "Phòng %d" % (idx + 1))
	var status = ch_data.get("status", "Connect")
	var is_full: bool = status == "(Full)" or int(ch_data.get("load", 0)) >= 100
	
	var display_title = ""
	if is_full:
		display_title = "%s (Full)" % ch_name if not "(Full)" in ch_name else ch_name
	else:
		display_title = "%s Connect" % ch_name if not "Connect" in ch_name else ch_name
	
	# Label tên server
	var lbl = Label.new()
	lbl.name = "TitleLabel"
	lbl.anchors_preset = Control.PRESET_TOP_WIDE
	lbl.offset_top = 2.0
	lbl.offset_bottom = 18.0
	lbl.offset_left = 0.0
	lbl.offset_right = 193.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = display_title
	lbl.add_theme_font_size_override("font_size", 12)
	
	var default_color = COLOR_FULL if is_full else COLOR_YELLOW
	lbl.add_theme_color_override("font_color", default_color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	btn.add_child(lbl)
	
	# Thanh đo mức tải phòng (Server Load Bar 10 vạch 160x4 gốc Webzen)
	var load_val: int = int(ch_data.get("load", 20))
	var gauge_ctrl = Control.new()
	gauge_ctrl.name = "GaugeSlot"
	gauge_ctrl.position = Vector2(16, 22)
	gauge_ctrl.clip_contents = true
	gauge_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Độ rộng tính theo 10 phân đoạn 16px mỗi vạch
	var num_segments = clampi(roundi(load_val / 10.0), 0, 10)
	var gauge_width = num_segments * 16
	gauge_ctrl.size = Vector2(gauge_width, 4)
	
	var gauge_tex = TextureRect.new()
	gauge_tex.texture = TEX_SERVER_LODING
	gauge_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gauge_tex.custom_minimum_size = Vector2(160, 4)
	gauge_tex.size = Vector2(160, 4)
	gauge_tex.position = Vector2.ZERO
	gauge_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_ctrl.add_child(gauge_tex)
	btn.add_child(gauge_ctrl)
	
	# Hiệu ứng đổi màu chữ sang trắng khi hover
	btn.mouse_entered.connect(func():
		_play_sound(SND_MOVE)
		lbl.add_theme_color_override("font_color", COLOR_WHITE)
	)
	btn.mouse_exited.connect(func():
		if current_channel_idx != idx:
			lbl.add_theme_color_override("font_color", default_color)
		else:
			lbl.add_theme_color_override("font_color", COLOR_WHITE)
	)
	
	# Xử lý nhấp chuột & Nhấp đúp (Double click vào thẳng game)
	btn.pressed.connect(func(): _on_channel_clicked(idx))
	
	return btn

func _highlight_channel(ch_idx: int) -> void:
	current_channel_idx = ch_idx
	for i in range(channel_buttons.size()):
		var btn = channel_buttons[i]
		var lbl: Label = btn.get_node_or_null("TitleLabel")
		if not lbl:
			continue
		var gdata = MuAccountSession.SERVER_DATA[current_group_idx]
		var channels: Array = gdata.get("channels", [])
		var ch = channels[i] if i < channels.size() else {}
		var is_full: bool = ch.get("status", "") == "(Full)" or int(ch.get("load", 0)) >= 100
		
		if i == ch_idx:
			lbl.add_theme_color_override("font_color", COLOR_WHITE)
		else:
			lbl.add_theme_color_override("font_color", COLOR_FULL if is_full else COLOR_YELLOW)

func _on_channel_clicked(ch_idx: int) -> void:
	_play_sound(SND_CLICK)
	_highlight_channel(ch_idx)
	
	var now = Time.get_ticks_msec() / 1000.0
	if last_clicked_channel_idx == ch_idx and (now - last_channel_click_time) < 0.4:
		# Nhấp đúp chuột -> Kết nối vào server
		_connect_to_server(ch_idx)
	
	last_channel_click_time = now
	last_clicked_channel_idx = ch_idx

func _connect_to_server(ch_idx: int) -> void:
	if current_group_idx < 0 or current_group_idx >= MuAccountSession.SERVER_DATA.size():
		return
	var gdata = MuAccountSession.SERVER_DATA[current_group_idx]
	var channels: Array = gdata.get("channels", [])
	if ch_idx < 0 or ch_idx >= channels.size():
		return
	
	var ch = channels[ch_idx]
	MuAccountSession.selected_server_group = gdata.get("group_name", "InfinityMU")
	MuAccountSession.selected_server_channel = ch.get("name", "InfinityMU-1")
	MuAccountSession.selected_server_code = int(ch.get("code", 1))
	
	_play_sound(SND_CLICK)
	
	# Hiệu ứng chuyển cảnh vào màn hình chọn nhân vật
	await get_tree().create_timer(0.2).timeout
	# Màn chọn nhân vật dựng bằng model nhân vật + nền World75 (gói tier 1): chờ tải xong mới vào.
	await MuContent.require_tier(1)
	get_tree().change_scene_to_file("res://src/scenes/CharacterSelectScene.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_connect_to_server(current_channel_idx)
		elif event.keycode == KEY_UP:
			if current_channel_idx > 0:
				_highlight_channel(current_channel_idx - 1)
				_play_sound(SND_MOVE)
		elif event.keycode == KEY_DOWN:
			if current_channel_idx < channel_buttons.size() - 1:
				_highlight_channel(current_channel_idx + 1)
				_play_sound(SND_MOVE)

func _on_back_pressed() -> void:
	_play_sound(SND_CLICK)
	get_tree().change_scene_to_file("res://src/scenes/LoginScene.tscn")

func _play_sound(path: String) -> void:
	if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		MuAudioManager.play_sound_file(path, -2.0)
	else:
		MuAudioManager.play_ui_click()
