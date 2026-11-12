extends Control
class_name MuCharacterCreate

## Màn hình Tạo Nhân Vật (Character Creation Scene) MU Online
## Tái hiện 100% giao diện, đồ họa gốc (New_character01/02, Class Stats, Animation Xem Trước)

# Tải tài nguyên đồ họa gốc
const TEX_MAKE_TOP := preload("res://assets/textures/ui/login_classic/New_character01.png")
const TEX_MAKE_BOTTOM := preload("res://assets/textures/ui/login_classic/New_character02.png")
const TEX_ARROW_LEFT := preload("res://assets/textures/ui/login_classic/New_character001.png")
const TEX_ARROW_RIGHT := preload("res://assets/textures/ui/login_classic/New_character002.png")
const TEX_ARROW_LEFT_HOVER := preload("res://assets/textures/ui/login_classic/New_character003.png")
const TEX_ARROW_RIGHT_HOVER := preload("res://assets/textures/ui/login_classic/New_character004.png")
const TEX_BTN_OK := preload("res://assets/textures/ui/login_classic/New_character_ok.png")
const TEX_BTN_CANCEL := preload("res://assets/textures/ui/login_classic/New_character_cancel.png")

# Danh sách 7 Class chuẩn Season 6
const CLASS_ORDER: Array[int] = [1, 0, 2, 3, 4, 5, 6] # DK, DW, ELF, MG, DL, SUM, RF
var current_class_idx: int = 0

# UI Nodes
@onready var txt_name: LineEdit = $PanelContainer/VBox/NameInput
@onready var lbl_class_name: Label = $PanelContainer/VBox/ClassRow/ClassNameLabel
@onready var lbl_str: Label = $PanelContainer/VBox/StatsGrid/ValStr
@onready var lbl_agi: Label = $PanelContainer/VBox/StatsGrid/ValAgi
@onready var lbl_vit: Label = $PanelContainer/VBox/StatsGrid/ValVit
@onready var lbl_ene: Label = $PanelContainer/VBox/StatsGrid/ValEne
@onready var lbl_cmd_row: Control = $PanelContainer/VBox/StatsGrid/CmdRow
@onready var lbl_cmd: Label = $PanelContainer/VBox/StatsGrid/CmdRow/ValCmd
@onready var lbl_desc: Label = $PanelContainer/VBox/DescLabel
@onready var lbl_status: Label = $StatusLabel
@onready var btn_ok: TextureButton = $PanelContainer/VBox/ButtonRow/BtnOk
@onready var btn_cancel: TextureButton = $PanelContainer/VBox/ButtonRow/BtnCancel
@onready var btn_prev: TextureButton = $PanelContainer/VBox/ClassRow/BtnPrev
@onready var btn_next: TextureButton = $PanelContainer/VBox/ClassRow/BtnNext
@onready var preview_anchor: Node3D = $PreviewViewportContainer/SubViewport/PreviewAnchor

var preview_model: Node3D = null
var network_client: MuNetworkClient = null

func _ready() -> void:
	# Nền 3D động gốc Season 9 (Data/World94) — client gốc tạo nhân vật trên cảnh chọn nhân vật
	MuSceneBackground3D.attach(self, MuSceneBackground3D.CHARACTER_WORLD)
	# Cảnh 3D đã có bệ đá thật -> ẩn đĩa CSG dùng cho ảnh nền phẳng cũ
	var disc := get_node_or_null("PreviewViewportContainer/SubViewport/PreviewAnchor/Pedestal")
	if disc:
		disc.visible = false
	# Khởi tạo kết nối mạng nếu có
	network_client = MuNetworkClient.new()
	add_child(network_client)
	network_client.packet_received.connect(_on_packet_received)
	if MuAccountSession.server_gateway_url != "":
		network_client.connect_to_gateway(MuAccountSession.server_gateway_url)

	# Gắn sự kiện nút
	btn_prev.pressed.connect(_on_prev_class)
	btn_next.pressed.connect(_on_next_class)
	btn_ok.pressed.connect(_on_ok_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	txt_name.text_submitted.connect(func(_t): _on_ok_pressed())

	# Bắt đầu với Dark Knight
	current_class_idx = 0
	_update_class_ui()
	MuAudioManager.play_ui_window()

func _process(delta: float) -> void:
	if preview_model and is_instance_valid(preview_model):
		# Xoay nhẹ mô hình xem trước tạo cảm giác 3D sống động
		preview_model.rotation.y += delta * 0.45

func _get_current_class_id() -> int:
	return CLASS_ORDER[current_class_idx]

func _on_prev_class() -> void:
	MuAudioManager.play_ui_click()
	current_class_idx = (current_class_idx - 1 + CLASS_ORDER.size()) % CLASS_ORDER.size()
	_update_class_ui()

func _on_next_class() -> void:
	MuAudioManager.play_ui_click()
	current_class_idx = (current_class_idx + 1) % CLASS_ORDER.size()
	_update_class_ui()

func _update_class_ui() -> void:
	var cid = _get_current_class_id()
	var info = MuAccountSession.CLASS_INFO[cid]

	lbl_class_name.text = "%s\n(%s)" % [info["name"], info["title"]]
	lbl_str.text = str(info["str"])
	lbl_agi.text = str(info["agi"])
	lbl_vit.text = str(info["vit"])
	lbl_ene.text = str(info["ene"])
	
	if info.get("cmd", 0) > 0:
		lbl_cmd_row.visible = true
		lbl_cmd.text = str(info["cmd"])
	else:
		lbl_cmd_row.visible = false
	
	var is_unlocked = MuAccountSession.is_class_unlocked(cid)
	if not is_unlocked:
		var req = MuAccountSession.get_class_requirement_text(cid)
		lbl_desc.text = info["desc"] + "\n\n[Khóa: " + req + "]"
		lbl_status.text = req
		btn_ok.disabled = true
	else:
		lbl_desc.text = info["desc"]
		lbl_status.text = ""
		btn_ok.disabled = false

	_spawn_preview_character(cid)

func _spawn_preview_character(class_id: int) -> void:
	if preview_model and is_instance_valid(preview_model):
		preview_model.queue_free()
		preview_model = null
	
	var floor_shadow = preview_anchor.get_node_or_null("Pedestal")
	if floor_shadow and floor_shadow is CSGCylinder3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.01, 0.01, 0.02, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		floor_shadow.material = mat
	
	var char_model_script = load("res://src/mu/MuCharacterModel.gd")
	if char_model_script:
		var model = char_model_script.new()
		preview_anchor.add_child(model)
		if model.has_method("build_player"):
			# Chuẩn game gốc MU: nhân vật level 1 hiển thị trang phục cơ bản nguyên bản của Class
			model.build_player(class_id, {})
		if model.has_method("play_idle"):
			model.play_idle(true)
		model.scale = Vector3(1.0, 1.0, 1.0)
		preview_model = model

func _on_ok_pressed() -> void:
	var char_name = txt_name.text.strip_edges()
	if char_name.length() < 3 or char_name.length() > 10:
		lbl_status.text = "Tên nhân vật phải từ 3 đến 10 ký tự!"
		MuAudioManager.play_ui_click()
		return
	
	# Kiểm tra tên đã tồn tại trong tài khoản chưa
	for c in MuAccountSession.character_list:
		if not c.is_empty() and c.get("name", "").to_lower() == char_name.to_lower():
			lbl_status.text = "Tên nhân vật đã tồn tại!"
			MuAudioManager.play_ui_click()
			return
	
	MuAudioManager.play_ui_click()
	lbl_status.text = "Đang tạo nhân vật..."
	btn_ok.disabled = true

	var cid = _get_current_class_id()
	if not MuAccountSession.is_class_unlocked(cid):
		lbl_status.text = MuAccountSession.get_class_requirement_text(cid)
		MuAudioManager.play_ui_click()
		return
	
	# Gửi gói tin lên Server / Gateway nếu đang kết nối
	if network_client and network_client.is_connected:
		var create_packet = MuPackets.build_character_create(char_name, cid)
		network_client.send_packet(create_packet)
	
	# Lưu trực tiếp vào Session tài khoản
	var new_char = MuAccountSession.create_character(char_name, cid)
	if new_char.is_empty():
		lbl_status.text = "Tài khoản đã đầy 5 nhân vật!"
		btn_ok.disabled = false
		return
	
	lbl_status.text = "Tạo nhân vật thành công!"
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file("res://src/scenes/CharacterSelectScene.tscn")

func _on_cancel_pressed() -> void:
	MuAudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://src/scenes/CharacterSelectScene.tscn")

func _on_packet_received(_header: int, code: int, sub_code: int, data: PackedByteArray) -> void:
	if code == 0xF3 and sub_code == 0x01:
		var result = data[4] if data.size() > 4 else 1
		if result == 1:
			get_tree().change_scene_to_file("res://src/scenes/CharacterSelectScene.tscn")
		else:
			lbl_status.text = "Tạo nhân vật thất bại (Mã: %d)" % result
			btn_ok.disabled = false
