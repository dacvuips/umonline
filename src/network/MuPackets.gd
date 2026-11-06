class_name MuPackets

## Lớp tiện ích đóng gói & giải mã các gói tin MU Online Season 6
## Dựa trên định nghĩa chính thức trong OpenMU ClientToServerPackets / ServerToClientPackets

# Headers
const C1_HEADER: int = 0xC1
const C2_HEADER: int = 0xC2
const C3_HEADER: int = 0xC3
const C4_HEADER: int = 0xC4

# Packet Codes
enum Code {
	CONNECT_SERVER_INFO = 0xF4,
	LOGIN = 0xF1,
	CHARACTER_LIST = 0xF3,
	WALK = 0xD4,
	ATTACK = 0x11,
	SKILL = 0x19,
	CHAT = 0x00
}

## Tạo gói tin C1 không mã hoá (Standard C1 Packet)
static func build_c1_packet(code: int, payload: PackedByteArray) -> PackedByteArray:
	var packet = PackedByteArray()
	var total_size = 3 + payload.size()
	packet.append(C1_HEADER)
	packet.append(total_size)
	packet.append(code)
	packet.append_array(payload)
	return packet

## Tạo gói tin C1 có SubCode
static func build_c1_sub_packet(code: int, sub_code: int, payload: PackedByteArray) -> PackedByteArray:
	var packet = PackedByteArray()
	var total_size = 4 + payload.size()
	packet.append(C1_HEADER)
	packet.append(total_size)
	packet.append(code)
	packet.append(sub_code)
	packet.append_array(payload)
	return packet

## Gói tin yêu cầu danh sách máy chủ từ ConnectServer (Code 0xF4, SubCode 0x06)
static func build_server_list_request() -> PackedByteArray:
	return build_c1_sub_packet(0xF4, 0x06, PackedByteArray())

## Gói tin đăng nhập (Login Request) - Code 0xF1, SubCode 0x01
static func build_login_packet(username: String, password: String) -> PackedByteArray:
	var payload = PackedByteArray()
	payload.resize(20) # 10 bytes user + 10 bytes pass
	payload.fill(0)
	
	var user_bytes = username.to_ascii_buffer()
	for i in range(mini(user_bytes.size(), 10)):
		payload[i] = user_bytes[i]
		
	var pass_bytes = password.to_ascii_buffer()
	for i in range(mini(pass_bytes.size(), 10)):
		payload[10 + i] = pass_bytes[i]
		
	# Trong chuẩn MU C3, mật khẩu được mã hóa SimpleModulus. 
	# Khi qua Gateway / Test mode, payload có thể gửi raw hoặc decrypt bởi Proxy
	return build_c1_sub_packet(0xF1, 0x01, payload)

## Gói tin yêu cầu danh sách nhân vật (Character List Request) - Code 0xF3, SubCode 0x00
static func build_character_list_request() -> PackedByteArray:
	return build_c1_sub_packet(0xF3, 0x00, PackedByteArray())

## Gói tin chọn nhân vật vào thế giới (Character Select) - Code 0xF3, SubCode 0x03
static func build_character_select(character_name: String) -> PackedByteArray:
	var payload = PackedByteArray()
	payload.resize(10)
	payload.fill(0)
	var name_bytes = character_name.to_utf8_buffer()
	for i in range(mini(name_bytes.size(), 10)):
		payload[i] = name_bytes[i]
	return build_c1_sub_packet(0xF3, 0x03, payload)

## Gói tin di chuyển (Movement / Walk) - Code 0xD4
## Gửi vị trí hiện tại (TargetX, TargetY) và chuỗi các bước đi (Path nibbles)
static func build_walk_packet(source_x: int, source_y: int, path_data: PackedByteArray) -> PackedByteArray:
	var payload = PackedByteArray()
	payload.append(source_x)
	payload.append(source_y)
	payload.append_array(path_data)
	return build_c1_packet(Code.WALK, payload)
