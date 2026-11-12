extends Node
class_name MuNetworkClient

## Client mạng MU Online cho Godot (WebAssembly & Mobile/Desktop)
## Giao tiếp qua WebSocket nhị phân kết nối tới WebSocket Gateway / OpenMU

signal connected_to_server()
signal connection_closed()
signal connection_error(err_msg: String)
signal packet_received(header_type: int, code: int, sub_code: int, data: PackedByteArray)

enum HeaderType {
	C1 = 0xC1, # Không mã hoá, size 1 byte (max 255)
	C2 = 0xC2, # Không mã hoá, size 2 byte (max 65535)
	C3 = 0xC3, # Mã hoá SimpleModulus, size 1 byte
	C4 = 0xC4  # Mã hoá SimpleModulus, size 2 byte
}

var socket: WebSocketPeer = WebSocketPeer.new()
var is_connected: bool = false
var server_url: String = "ws://127.0.0.1:8080"
var incoming_buffer: PackedByteArray = PackedByteArray()

func _ready() -> void:
	add_to_group("Network")
	# Cấu hình WebSocketPeer
	socket.inbound_buffer_size = 1048576 # 1MB
	socket.outbound_buffer_size = 1048576

func connect_to_gateway(url: String = "") -> Error:
	if url != "":
		server_url = url
	print("[MuNetwork] Đang kết nối tới Gateway: ", server_url)
	
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close(1000, "Reconnecting")
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 1048576 # 1MB
	socket.outbound_buffer_size = 1048576
	is_connected = false
	incoming_buffer.clear()

	var err = socket.connect_to_url(server_url)
	if err != OK:
		print("[MuNetwork] Lỗi khởi tạo WebSocket: ", err)
		emit_signal("connection_error", "Không thể khởi tạo socket (Mã %d)!" % err)
		return err
	set_process(true)
	return OK

func disconnect_from_gateway() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close(1000, "Normal closure")
	is_connected = false
	incoming_buffer.clear()

func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			print("[MuNetwork] Đã kết nối thành công tới WebSocket Gateway!")
			emit_signal("connected_to_server")

		# Đọc toàn bộ packet nhị phân đến
		while socket.get_available_packet_count() > 0:
			var raw_packet = socket.get_packet()
			if raw_packet.size() > 0:
				_handle_raw_incoming_data(raw_packet)

	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected:
			is_connected = false
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print("[MuNetwork] Mất kết nối tới máy chủ! Code: %d, Lý do: %s" % [code, reason])
			emit_signal("connection_closed")
		else:
			set_process(false)
			var reason = socket.get_close_reason()
			var err_text = "Không thể kết nối tới Gateway!"
			if reason != "":
				err_text += " (" + reason + ")"
			else:
				err_text += " (Vui lòng chạy Start-Gateway.bat)"
			print("[MuNetwork] ", err_text)
			emit_signal("connection_error", err_text)

func _handle_raw_incoming_data(bytes: PackedByteArray) -> void:
	incoming_buffer.append_array(bytes)
	
	# Xử lý cắt frame packet MU (Stream slicing)
	while incoming_buffer.size() >= 3:
		var header = incoming_buffer[0]
		if header not in [0xC1, 0xC2, 0xC3, 0xC4]:
			# Dữ liệu rác hoặc lệch đồng bộ, tìm byte header kế tiếp
			print("[MuNetwork] Cảnh báo: Header không hợp lệ (0x%X), đang đồng bộ lại..." % header)
			incoming_buffer.remove_at(0)
			continue

		var packet_len: int = 0
		var header_len: int = 0
		if header == 0xC1 or header == 0xC3:
			packet_len = incoming_buffer[1]
			header_len = 2
		elif header == 0xC2 or header == 0xC4:
			if incoming_buffer.size() < 3:
				break # Đợi thêm byte
			packet_len = (incoming_buffer[1] << 8) | incoming_buffer[2]
			header_len = 3

		if packet_len <= 0 or packet_len > 8192:
			print("[MuNetwork] Độ dài gói tin bất thường: ", packet_len)
			incoming_buffer.remove_at(0)
			continue

		if incoming_buffer.size() < packet_len:
			# Chưa nhận đủ byte của gói tin hiện tại, đợi poll tiếp theo
			break

		# Trích xuất đúng 1 packet hoàn chỉnh
		var full_packet = incoming_buffer.slice(0, packet_len)
		incoming_buffer = incoming_buffer.slice(packet_len)
		_dispatch_packet(header, full_packet, header_len)

func _dispatch_packet(header_type: int, full_packet: PackedByteArray, header_len: int) -> void:
	if full_packet.size() <= header_len:
		return
	
	var code = full_packet[header_len]
	var sub_code = -1
	# Kiểm tra nếu packet có SubCode (thông thường gói tin tiếp theo chứa subcode)
	if full_packet.size() > header_len + 1:
		sub_code = full_packet[header_len + 1]

	print("[MuNetwork] Nhận Packet: Header=0x%X, Code=0x%X, SubCode=0x%X, Size=%d" % [header_type, code, sub_code, full_packet.size()])
	emit_signal("packet_received", header_type, code, sub_code, full_packet)

## Gửi packet nhị phân tới Server
func send_packet(packet: PackedByteArray) -> Error:
	if not is_connected or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("[MuNetwork] Lỗi: Chưa kết nối tới server!")
		return ERR_CONNECTION_ERROR
	return socket.send(packet)
