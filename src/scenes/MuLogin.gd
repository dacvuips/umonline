extends Control
class_name MuLogin

## Quản lý đăng nhập và kết nối máy chủ MU Online (Web, Mobile, PC)

@onready var txt_server: LineEdit = $Panel/VBoxContainer/ServerInput
@onready var txt_user: LineEdit = $Panel/VBoxContainer/UserInput
@onready var txt_pass: LineEdit = $Panel/VBoxContainer/PassInput
@onready var btn_login: Button = $Panel/VBoxContainer/LoginButton
@onready var btn_offline: Button = $Panel/VBoxContainer.get_node_or_null("OfflineButton")
@onready var lbl_status: Label = $Panel/VBoxContainer/StatusLabel

# Tham chiếu Network Client toàn cục hoặc cục bộ
var network_client: MuNetworkClient = null

func _ready() -> void:
	# Khởi tạo network client
	network_client = MuNetworkClient.new()
	add_child(network_client)
	
	network_client.connected_to_server.connect(_on_connected)
	network_client.connection_error.connect(_on_error)
	network_client.packet_received.connect(_on_packet_received)
	
	btn_login.pressed.connect(_on_login_pressed)
	if btn_offline:
		btn_offline.pressed.connect(_on_offline_pressed)
	lbl_status.text = "Sẵn sàng kết nối"

func _on_offline_pressed() -> void:
	lbl_status.text = "Đang vào thế giới Offline..."
	get_tree().change_scene_to_file("res://src/scenes/Main.tscn")

func _on_login_pressed() -> void:
	var server_url = txt_server.text.strip_edges()
	var username = txt_user.text.strip_edges()
	var password = txt_pass.text.strip_edges()

	if username == "":
		lbl_status.text = "Vui lòng nhập tài khoản!"
		return

	lbl_status.text = "Đang kết nối tới Gateway..."
	btn_login.disabled = true
	network_client.connect_to_gateway(server_url)

func _on_connected() -> void:
	lbl_status.text = "Đã kết nối! Đang gửi gói tin đăng nhập..."
	var username = txt_user.text.strip_edges()
	var password = txt_pass.text.strip_edges()
	
	# Gửi gói tin Login chuẩn
	var login_packet = MuPackets.build_login_packet(username, password)
	network_client.send_packet(login_packet)

func _on_error(msg: String) -> void:
	lbl_status.text = "Lỗi: " + msg
	btn_login.disabled = false

func _on_packet_received(header: int, code: int, sub_code: int, data: PackedByteArray) -> void:
	# Code 0xF1: Kết quả đăng nhập từ server
	if code == 0xF1 and sub_code == 0x01:
		var result = data[4] if data.size() > 4 else -1
		if result == 1: # Thành công
			lbl_status.text = "Đăng nhập thành công! Đang vào game..."
			# Chuyển cảnh sang Main World
			get_tree().change_scene_to_file("res://src/scenes/Main.tscn")
		elif result == 0:
			lbl_status.text = "Sai mật khẩu!"
			btn_login.disabled = false
		elif result == 2:
			lbl_status.text = "Tài khoản đang online!"
			btn_login.disabled = false
		else:
			lbl_status.text = "Đăng nhập thành công (Kết quả: %d)" % result
			get_tree().change_scene_to_file("res://src/scenes/Main.tscn")
	else:
		# Đối với chế độ Standalone / Test mode hoặc khi server phản hồi
		lbl_status.text = "Nhận phản hồi từ Server (Code: 0x%X)" % code
