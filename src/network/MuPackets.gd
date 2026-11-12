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
		
	return build_c1_sub_packet(0xF1, 0x01, payload)

## Gói đăng ký tài khoản (tự chế, gateway xử lý) - Code 0xF1, SubCode 0x02
## Format: [Tài khoản 10 byte] [Mật khẩu 10 byte] [Email/SĐT 30 byte]
static func build_register_packet(username: String, password: String, contact: String) -> PackedByteArray:
	var payload = PackedByteArray()
	payload.resize(50)
	payload.fill(0)
	var u = username.to_ascii_buffer()
	for i in range(mini(u.size(), 10)):
		payload[i] = u[i]
	var p = password.to_ascii_buffer()
	for i in range(mini(p.size(), 10)):
		payload[10 + i] = p[i]
	var c = contact.to_ascii_buffer()
	for i in range(mini(c.size(), 30)):
		payload[20 + i] = c[i]
	return build_c1_sub_packet(0xF1, 0x02, payload)

## Gói tin yêu cầu danh sách nhân vật (Character List Request) - Code 0xF3, SubCode 0x00
static func build_character_list_request() -> PackedByteArray:
	return build_c1_sub_packet(0xF3, 0x00, PackedByteArray())

## Gói tin tạo nhân vật mới (Character Create Request) - Code 0xF3, SubCode 0x01
## Format: [Name 10 bytes] [Class 1 byte]
## Chuẩn Webzen MU / OpenMU: Byte class trong gói C1 F3 01 là CharacterClassNumber (class_id << 2)
static func build_character_create(character_name: String, class_id: int) -> PackedByteArray:
	var payload = PackedByteArray()
	payload.resize(11)
	payload.fill(0)
	var name_bytes = character_name.to_utf8_buffer()
	for i in range(mini(name_bytes.size(), 10)):
		payload[i] = name_bytes[i]
	var base_id = class_id if (class_id >= 0 and class_id <= 6) else (class_id >> 2)
	payload[10] = (base_id << 2) & 0xFF
	return build_c1_sub_packet(0xF3, 0x01, payload)

## Gói tin xóa nhân vật (Character Delete Request) - Code 0xF3, SubCode 0x02
## Format: [Name 10 bytes] [SecurityCode 7 bytes]
static func build_character_delete(character_name: String, security_code: String = "1234567") -> PackedByteArray:
	var payload = PackedByteArray()
	payload.resize(17)
	payload.fill(0)
	var name_bytes = character_name.to_utf8_buffer()
	for i in range(mini(name_bytes.size(), 10)):
		payload[i] = name_bytes[i]
	var code_bytes = security_code.to_utf8_buffer()
	for i in range(mini(code_bytes.size(), 7)):
		payload[10 + i] = code_bytes[i]
	return build_c1_sub_packet(0xF3, 0x02, payload)

## Gói tin chọn nhân vật vào thế giới (Character Select) - Code 0xF3, SubCode 0x03
## Format: [Name 10 bytes]
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

## Gói tin đăng xuất / thoát (LogOut Request) - Code 0xF1, SubCode 0x02
## logout_type: 0 = CloseGame, 1 = BackToCharacterSelection, 2 = BackToServerSelection
static func build_logout_packet(logout_type: int) -> PackedByteArray:
	var payload = PackedByteArray()
	payload.append(logout_type & 0xFF)
	return build_c1_sub_packet(0xF1, 0x02, payload)

