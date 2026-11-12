extends Control
class_name MuCharMakeModal

## Bảng Tạo Nhân Vật Mới (Character Creation Window - CharMakeWin)
## Tái hiện 100% đồ họa và thông số từ source code gốc Webzen MU Online:
## - Source C++: CharMakeWin.cpp, char_make.rcss, ZzzOpenData.cpp
## - 3D Model: NewFace01.glb -> NewFace07.glb (Bust 3D có animation idle a000)
## - Khung tên cha_id.png (346x38) kèm nút xúc xắc [D] tạo tên nhanh
## - Bảng chỉ số (Sức mạnh, Nhanh nhẹn, Thể lực, Năng lượng, Mệnh lệnh)
## - Nút chọn Class (cha_bt.png 108x26, viền đỏ sáng khi được chọn)
## - Nút OK và Cancel (op1_b_all.png 54x30)

signal character_created(char_data: Dictionary)
signal closed()

# Tài nguyên UI gốc
const TEX_CHA_ID := preload("res://assets/textures/ui/cha_id.png")
const TEX_CHA_BT := preload("res://assets/textures/ui/cha_bt.png")
const TEX_BTN_OK := preload("res://assets/textures/ui/newui_button_ok.png")
const TEX_BTN_CANCEL := preload("res://assets/textures/ui/newui_button_cancel.png")
const SND_CLICK := "res://assets/mu/Sound/iButtonClick.wav"
const SND_MOVE := "res://assets/mu/Sound/iButtonMove.wav"
const SND_CREATE_WIN := "res://assets/mu/Sound/iCreateWindow.wav"

# Danh sách 7 Class theo đúng thứ tự bố cục trong source gốc MU (char_make.rcss):
# wizard(131px), knight(157px), elf(183px), summoner(209px), [gap], rage-fighter(246px), dark(272px), dark-lord(298px)
const CLASS_LIST: Array[Dictionary] = [
	{
		"class_id": 0,
		"key": "wizard",
		"name": "Phù Thủy",
		"english": "Dark Wizard",
		"title": "Phù Thủy Áo Đen",
		"glb": "res://assets/mu/Logo/NewFace01.glb",
		"str": 18, "agi": 18, "vit": 15, "ene": 30, "cmd": 0,
		"desc": "Phù Thủy: Thể lực yếu nhưng có sức mạnh ma thuật to lớn, có khả năng sử dụng các phép thuật tấn công tầm xa tự do.",
		"btn_top": 131,
		"model_pos": Vector3(0, -0.015, 0),
		"model_rot": Vector3(0, -25, 0),
		"model_scale": Vector3(1.0, 1.0, 1.0)
	},
	{
		"class_id": 1,
		"key": "knight",
		"name": "Chiến Binh",
		"english": "Dark Knight",
		"title": "Chiến Binh Bóng Đêm",
		"glb": "res://assets/mu/Logo/NewFace02.glb",
		"str": 28, "agi": 20, "vit": 25, "ene": 10, "cmd": 0,
		"desc": "Chiến Binh: Rất mạnh trong trận đánh cận chiến với sức chịu đựng cao, có khả năng sử dụng tất cả các vũ khí.",
		"btn_top": 157,
		"model_pos": Vector3(0, -0.012, 0),
		"model_rot": Vector3(0, -12, 0),
		"model_scale": Vector3(1.0, 1.0, 1.0)
	},
	{
		"class_id": 2,
		"key": "elf",
		"name": "Tiên Nữ",
		"english": "Fairy Elf",
		"title": "Tiên Nữ Xạ Thủ",
		"glb": "res://assets/mu/Logo/NewFace03.glb",
		"str": 22, "agi": 25, "vit": 20, "ene": 15, "cmd": 0,
		"desc": "Tiên Nữ: Hậu duệ của vương quốc Noria. Bậc thầy về cung tiễn và có khả năng sử dụng các phép thuật hỗ trợ đa dạng.",
		"btn_top": 183,
		"model_pos": Vector3(0, -0.005, 0),
		"model_rot": Vector3(5, 5, 0),
		"model_scale": Vector3(1.45, 1.45, 1.45)
	},
	{
		"class_id": 5,
		"key": "summoner",
		"name": "Thuật Sĩ",
		"english": "Summoner",
		"title": "Thuật Sĩ Triệu Hồi",
		"glb": "res://assets/mu/Logo/NewFace06.glb",
		"str": 21, "agi": 21, "vit": 18, "ene": 23, "cmd": 0,
		"desc": "Thuật Sĩ: Sở hữu tinh thần thép và khả năng nhìn thấu tuyệt vời tạo nên những phép thuật nguyền rủa mạnh nhất.",
		"btn_top": 209,
		"model_pos": Vector3(0, 0.002, 0),
		"model_rot": Vector3(2, 2, 0),
		"model_scale": Vector3(1.45, 1.45, 1.45)
	},
	{
		"class_id": 6,
		"key": "rage-fighter",
		"name": "Thiết Binh",
		"english": "Rage Fighter",
		"title": "Thiết Binh Quyền Thần",
		"glb": "res://assets/mu/Logo/NewFace07.glb",
		"str": 32, "agi": 27, "vit": 25, "ene": 20, "cmd": 0,
		"desc": "Thiết Binh: Võ tướng mang dòng máu hoàng gia Karutan với thể lực phi thường, chiến đấu bằng nắm đấm uy lực.",
		"btn_top": 246,
		"model_pos": Vector3(0, -0.015, 0),
		"model_rot": Vector3(0, 0, 0),
		"model_scale": Vector3(0.95, 0.95, 0.95)
	},
	{
		"class_id": 3,
		"key": "dark",
		"name": "Đấu Sĩ",
		"english": "Magic Gladiator",
		"title": "Đấu Sĩ Ma Pháp",
		"glb": "res://assets/mu/Logo/NewFace04.glb",
		"str": 26, "agi": 26, "vit": 26, "ene": 26, "cmd": 0,
		"desc": "Đấu Sĩ: Nhân vật phức hợp mang đặc tính của Chiến Binh và Phù Thủy, bậc thầy cận chiến và sử dụng ma thuật.",
		"btn_top": 272,
		"model_pos": Vector3(0, -0.012, 0),
		"model_rot": Vector3(0, -13, 0),
		"model_scale": Vector3(1.0, 1.0, 1.0)
	},
	{
		"class_id": 4,
		"key": "dark-lord",
		"name": "Chúa Tể",
		"english": "Dark Lord",
		"title": "Chúa Tể Bóng Đêm",
		"glb": "res://assets/mu/Logo/NewFace05.glb",
		"str": 26, "agi": 20, "vit": 20, "ene": 15, "cmd": 25,
		"desc": "Chúa Tể: Nhân vật đầy uy quyền có thể chỉ huy binh đoàn, điều khiển Thần mã và Quạ tinh bóng đêm.",
		"btn_top": 298,
		"model_pos": Vector3(0, -0.015, 0),
		"model_rot": Vector3(0, -16, 0),
		"model_scale": Vector3(1.0, 1.0, 1.0)
	}
]

# Tên ngẫu nhiên chuẩn MU phong cách Việt & Quốc tế
const RANDOM_NAMES: Array[String] = [
	"ChienThan", "KiemThanh", "BaoChua", "MaPhap", "HaoKiet",
	"CuongLong", "DocCo", "ThienSu", "LethalHero", "DarkKnight",
	"ShadowLord", "DragonFire", "AuraMage", "WindElf", "IronFist",
	"VoSong", "ThanhKiem", "BangSat", "LongThan", "TuyetDinh"
]

var selected_class_idx: int = 1 # Mặc định Chiến Binh (DK) như ảnh người dùng
var current_bust_model: Node3D = null

# UI Nodes
@onready var panel: Control = $Panel
@onready var preview_viewport: SubViewport = $Panel/PreviewContainer/SubViewport
@onready var bust_anchor: Node3D = $Panel/PreviewContainer/SubViewport/BustAnchor
@onready var stat_bg: ColorRect = $Panel/StatPanel/StatBg
@onready var stat_panel: Control = $Panel/StatPanel
@onready var lbl_str_val: Label = $Panel/StatPanel/RowStr/Val
@onready var lbl_agi_val: Label = $Panel/StatPanel/RowAgi/Val
@onready var lbl_vit_val: Label = $Panel/StatPanel/RowVit/Val
@onready var lbl_ene_val: Label = $Panel/StatPanel/RowEne/Val
@onready var row_cmd: Control = $Panel/StatPanel/RowCmd
@onready var lbl_cmd_val: Label = $Panel/StatPanel/RowCmd/Val
@onready var txt_name: LineEdit = $Panel/InputFrame/TxtName
@onready var btn_dice: TextureButton = $Panel/InputFrame/BtnDice
@onready var lbl_desc: Label = $Panel/DescPanel/LblDesc
@onready var lbl_status_msg: Label = $Panel/StatusLabel
@onready var btn_ok: TextureButton = $Panel/BtnOk
@onready var btn_cancel: TextureButton = $Panel/BtnCancel
@onready var job_buttons_container: Control = $Panel/JobButtons

# Button textures
var tex_btn_normal: AtlasTexture
var tex_btn_hover: AtlasTexture
var tex_btn_pressed: AtlasTexture
var tex_btn_checked: AtlasTexture

var tex_ok_normal: AtlasTexture
var tex_ok_hover: AtlasTexture
var tex_cancel_normal: AtlasTexture
var tex_cancel_hover: AtlasTexture

var job_button_nodes: Array[TextureButton] = []

func _ready() -> void:
	for child in bust_anchor.get_children():
		child.queue_free()
	current_bust_model = null

	_init_textures()
	_build_job_buttons()
	_setup_events()

func _init_textures() -> void:
	# cha_bt.png (108 x 104: 4 frames 108x26)
	tex_btn_normal = AtlasTexture.new()
	tex_btn_normal.atlas = TEX_CHA_BT
	tex_btn_normal.region = Rect2(0, 0, 108, 26)

	tex_btn_hover = AtlasTexture.new()
	tex_btn_hover.atlas = TEX_CHA_BT
	tex_btn_hover.region = Rect2(0, 26, 108, 26)

	tex_btn_pressed = AtlasTexture.new()
	tex_btn_pressed.atlas = TEX_CHA_BT
	tex_btn_pressed.region = Rect2(0, 52, 108, 26)

	# Frame 3 (y=78..104): Viền đỏ rực sáng khi được chọn (Checked)
	tex_btn_checked = AtlasTexture.new()
	tex_btn_checked.atlas = TEX_CHA_BT
	tex_btn_checked.region = Rect2(0, 78, 108, 26)

	# newui_button_ok.png (54 x 90: 3 frame 54x30)
	tex_ok_normal = AtlasTexture.new()
	tex_ok_normal.atlas = TEX_BTN_OK
	tex_ok_normal.region = Rect2(0, 0, 54, 30)

	tex_ok_hover = AtlasTexture.new()
	tex_ok_hover.atlas = TEX_BTN_OK
	tex_ok_hover.region = Rect2(0, 30, 54, 30)

	var tex_ok_pressed = AtlasTexture.new()
	tex_ok_pressed.atlas = TEX_BTN_OK
	tex_ok_pressed.region = Rect2(0, 60, 54, 30)

	btn_ok.texture_normal = tex_ok_normal
	btn_ok.texture_hover = tex_ok_hover
	btn_ok.texture_pressed = tex_ok_pressed
	var lbl_ok = btn_ok.get_node_or_null("Lbl") as Label
	if lbl_ok:
		lbl_ok.text = ""
		lbl_ok.visible = false

	# newui_button_cancel.png (54 x 90: 3 frame 54x30)
	tex_cancel_normal = AtlasTexture.new()
	tex_cancel_normal.atlas = TEX_BTN_CANCEL
	tex_cancel_normal.region = Rect2(0, 0, 54, 30)

	tex_cancel_hover = AtlasTexture.new()
	tex_cancel_hover.atlas = TEX_BTN_CANCEL
	tex_cancel_hover.region = Rect2(0, 30, 54, 30)

	var tex_cancel_pressed = AtlasTexture.new()
	tex_cancel_pressed.atlas = TEX_BTN_CANCEL
	tex_cancel_pressed.region = Rect2(0, 60, 54, 30)

	btn_cancel.texture_normal = tex_cancel_normal
	btn_cancel.texture_hover = tex_cancel_hover
	btn_cancel.texture_pressed = tex_cancel_pressed
	var lbl_cancel = btn_cancel.get_node_or_null("Lbl") as Label
	if lbl_cancel:
		lbl_cancel.text = ""
		lbl_cancel.visible = false

func _build_job_buttons() -> void:
	for child in job_buttons_container.get_children():
		child.queue_free()
	job_button_nodes.clear()

	for i in range(CLASS_LIST.size()):
		var info = CLASS_LIST[i]
		var btn = TextureButton.new()
		btn.name = "BtnJob_%s" % info["key"]
		btn.custom_minimum_size = Vector2(108, 26)
		btn.size = Vector2(108, 26)
		btn.position = Vector2(346, info["btn_top"])
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# Label tên Class
		var lbl = Label.new()
		lbl.name = "LblName"
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.offset_top = 1.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.text = info["name"]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92, 1.0))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		btn.add_child(lbl)

		var idx = i
		btn.pressed.connect(func(): _select_class(idx))
		btn.mouse_entered.connect(func(): _play_sound(SND_MOVE))

		job_buttons_container.add_child(btn)
		job_button_nodes.append(btn)

func _setup_events() -> void:
	btn_ok.pressed.connect(_on_ok_pressed)
	btn_ok.mouse_entered.connect(func(): _play_sound(SND_MOVE))

	btn_cancel.pressed.connect(_on_cancel_pressed)
	btn_cancel.mouse_entered.connect(func(): _play_sound(SND_MOVE))

	btn_dice.pressed.connect(_on_dice_pressed)
	btn_dice.mouse_entered.connect(func(): _play_sound(SND_MOVE))

	txt_name.text_submitted.connect(func(_t): _on_ok_pressed())

func open_dialog() -> void:
	visible = true
	_play_sound(SND_CREATE_WIN)
	lbl_status_msg.text = ""
	txt_name.text = ""
	# Mặc định mở ra chọn Chiến Binh
	_select_class(1)
	txt_name.grab_focus()

func close_dialog() -> void:
	visible = false
	if current_bust_model and is_instance_valid(current_bust_model):
		current_bust_model.queue_free()
		current_bust_model = null
	closed.emit()

func _select_class(idx: int) -> void:
	if idx < 0 or idx >= CLASS_LIST.size():
		return
	
	if visible and idx != selected_class_idx:
		_play_sound(SND_CLICK)
		
	selected_class_idx = idx
	var info = CLASS_LIST[idx]
	var cid = info["class_id"]
	var unlocked = MuAccountSession.is_class_unlocked(cid)

	_update_job_buttons_state()

	# Cập nhật Bảng chỉ số (Stats Panel)
	lbl_str_val.text = str(info["str"])
	lbl_agi_val.text = str(info["agi"])
	lbl_vit_val.text = str(info["vit"])
	lbl_ene_val.text = str(info["ene"])

	var is_dark_lord = (info["class_id"] == 4)
	if is_dark_lord:
		row_cmd.visible = true
		lbl_cmd_val.text = str(info["cmd"])
		stat_bg.size.y = 96.0
	else:
		row_cmd.visible = false
		stat_bg.size.y = 80.0

	# Cập nhật Mô tả Class & Điều kiện mở khóa
	if not unlocked:
		var req_msg = MuAccountSession.get_class_requirement_text(cid)
		lbl_desc.text = info["desc"] + "\n\n[Khóa: " + req_msg + "]"
		lbl_status_msg.text = req_msg
		btn_ok.disabled = true
		btn_ok.modulate = Color(0.5, 0.5, 0.5, 0.6)
	else:
		lbl_desc.text = info["desc"]
		lbl_status_msg.text = ""
		btn_ok.disabled = false
		btn_ok.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Cập nhật Model 3D xem trước
	_load_bust_model(info)

func _update_job_buttons_state() -> void:
	for i in range(job_button_nodes.size()):
		var b = job_button_nodes[i]
		var lbl = b.get_node_or_null("LblName") as Label
		var cid = CLASS_LIST[i]["class_id"]
		var unlocked = MuAccountSession.is_class_unlocked(cid)
		
		if not unlocked:
			b.modulate = Color(0.65, 0.65, 0.65, 0.8)
			if lbl:
				lbl.text = CLASS_LIST[i]["name"] + " [Khóa]"
		else:
			b.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if lbl:
				lbl.text = CLASS_LIST[i]["name"]

		if i == selected_class_idx:
			b.texture_normal = tex_btn_checked
			b.texture_hover = tex_btn_checked
			b.texture_pressed = tex_btn_checked
			if lbl:
				if unlocked:
					lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5, 1.0))
				else:
					lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6, 1.0))
		else:
			b.texture_normal = tex_btn_normal
			b.texture_hover = tex_btn_hover
			b.texture_pressed = tex_btn_pressed
			if lbl:
				if unlocked:
					lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88, 1.0))
				else:
					lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.8))

func _load_bust_model(info: Dictionary) -> void:
	if current_bust_model and is_instance_valid(current_bust_model):
		current_bust_model.queue_free()
		current_bust_model = null

	var glb_path = info["glb"]
	var res = load(glb_path)
	if not res:
		push_warning("Không tìm thấy model bust: " + glb_path)
		return

	var inst: Node3D = res.instantiate()
	inst.position = info.get("model_pos", Vector3.ZERO)
	inst.rotation_degrees = info.get("model_rot", Vector3.ZERO)
	inst.scale = info.get("model_scale", Vector3.ONE)

	bust_anchor.add_child(inst)
	current_bust_model = inst

	# Phát animation nhàn rỗi (idle / a000)
	for child in inst.find_children("*", "AnimationPlayer"):
		if child.has_animation("a000"):
			child.play("a000")
			# Chỉnh tốc độ phát PlaySpeed = 0.3 chuẩn gốc
			child.speed_scale = 0.3

func _on_dice_pressed() -> void:
	_play_sound(SND_CLICK)
	var rand_name = RANDOM_NAMES[randi() % RANDOM_NAMES.size()]
	# Thêm hậu tố số ngẫu nhiên nếu cần
	var full_name = rand_name
	if full_name.length() > 10:
		full_name = full_name.substr(0, 10)
	txt_name.text = full_name
	lbl_status_msg.text = ""

func _on_ok_pressed() -> void:
	var char_name = txt_name.text.strip_edges()
	if char_name.length() < 3 or char_name.length() > 10:
		_play_sound(SND_CLICK)
		lbl_status_msg.text = "Tên nhân vật phải từ 3 đến 10 ký tự!"
		return

	# Kiểm tra ký tự hợp lệ (chữ, số)
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	if not regex.search(char_name):
		_play_sound(SND_CLICK)
		lbl_status_msg.text = "Tên không được chứa ký tự đặc biệt!"
		return

	# Kiểm tra tên đã tồn tại trong tài khoản
	for c in MuAccountSession.character_list:
		if not c.is_empty() and c.get("name", "").to_lower() == char_name.to_lower():
			_play_sound(SND_CLICK)
			lbl_status_msg.text = "Tên nhân vật đã tồn tại!"
			return

	# Kiểm tra số lượng slot
	var empty_slot = MuAccountSession.get_first_empty_slot()
	if empty_slot == -1:
		_play_sound(SND_CLICK)
		lbl_status_msg.text = "Đã đầy 5 slot nhân vật!"
		return

	_play_sound(SND_CLICK)
	var info = CLASS_LIST[selected_class_idx]
	var cid = info["class_id"]

	# Kiểm tra điều kiện mở khóa Class
	if not MuAccountSession.is_class_unlocked(cid):
		lbl_status_msg.text = MuAccountSession.get_class_requirement_text(cid)
		return

	# Tạo nhân vật qua MuAccountSession
	var char_data = MuAccountSession.create_character(char_name, cid, empty_slot, 1)
	if char_data.is_empty():
		lbl_status_msg.text = "Không thể tạo nhân vật!"
		return

	# Gửi packet nếu có mạng kết nối
	# MuPackets.build_character_create(char_name, cid)

	lbl_status_msg.text = "Tạo nhân vật thành công!"
	character_created.emit(char_data)
	close_dialog()

func _on_cancel_pressed() -> void:
	_play_sound(SND_CLICK)
	close_dialog()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_cancel_pressed()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_on_ok_pressed()

func _play_sound(path: String) -> void:
	var stream = load(path)
	if stream:
		var asp = AudioStreamPlayer.new()
		asp.stream = stream
		asp.finished.connect(asp.queue_free)
		add_child(asp)
		asp.play()
