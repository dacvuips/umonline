extends Node
class_name MuAccountManager

## Quản lý Tài Khoản MU Online (Đăng ký, Đăng nhập, Khôi phục mật khẩu)
## Lưu trữ cục bộ tại user://mu_accounts.json và đồng bộ với phiên chơi MuAccountSession

const ACCOUNTS_FILE := "user://mu_accounts.json"

# Cấu trúc lưu trữ:
# {
#   "accounts": {
#     "test1": {
#       "username": "test1",
#       "password": "123",
#       "email": "test1@mu.vn",
#       "phone": "0901234567",
#       "secret_answer": "dragon",
#       "created_at": "...",
#       "last_login": "..."
#     }
#   }
# }

static func _get_default_data() -> Dictionary:
	return {
		"accounts": {
			"test1": {
				"username": "test1",
				"password": "123",
				"email": "test1@muonline.vn",
				"phone": "0901234567",
				"secret_answer": "muonline",
				"created_at": Time.get_datetime_string_from_system(),
				"last_login": Time.get_datetime_string_from_system()
			},
			"admin": {
				"username": "admin",
				"password": "admin123",
				"email": "admin@muonline.vn",
				"phone": "0988888888",
				"secret_answer": "lorencia",
				"created_at": Time.get_datetime_string_from_system(),
				"last_login": Time.get_datetime_string_from_system()
			}
		}
	}

## Nạp toàn bộ dữ liệu tài khoản từ file
static func load_all_accounts() -> Dictionary:
	if not FileAccess.file_exists(ACCOUNTS_FILE):
		var default_data = _get_default_data()
		save_all_accounts(default_data)
		return default_data
	
	var f = FileAccess.open(ACCOUNTS_FILE, FileAccess.READ)
	if not f:
		return _get_default_data()
	
	var text = f.get_as_text()
	f.close()
	
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		if not data.has("accounts"):
			data["accounts"] = {}
		# Đảm bảo có sẵn test1 nếu rỗng
		if data["accounts"].is_empty():
			data = _get_default_data()
			save_all_accounts(data)
		return data
	
	return _get_default_data()

## Ghi dữ liệu tài khoản vào file
static func save_all_accounts(data: Dictionary) -> bool:
	var f = FileAccess.open(ACCOUNTS_FILE, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

## Đăng ký tài khoản mới
static func register_account(username: String, password_str: String, confirm_pass: String, email: String = "", phone: String = "") -> Dictionary:
	username = username.strip_edges()
	password_str = password_str.strip_edges()
	confirm_pass = confirm_pass.strip_edges()
	email = email.strip_edges()
	phone = phone.strip_edges()

	# Kiểm tra tên tài khoản
	if username == "":
		return {"success": false, "message": "Vui lòng nhập tên tài khoản!"}
	if username.length() < 3 or username.length() > 10:
		return {"success": false, "message": "Tên tài khoản phải từ 3 đến 10 ký tự!"}
	
	# Kiểm tra ký tự hợp lệ (chữ và số)
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	if not regex.search(username):
		return {"success": false, "message": "Tài khoản chỉ được chứa chữ cái, số và dấu gạch dưới!"}

	# Kiểm tra mật khẩu
	if password_str == "":
		return {"success": false, "message": "Vui lòng nhập mật khẩu!"}
	if password_str.length() < 3:
		return {"success": false, "message": "Mật khẩu phải có ít nhất 3 ký tự!"}
	if password_str != confirm_pass:
		return {"success": false, "message": "Mật khẩu xác nhận không trùng khớp!"}

	var data = load_all_accounts()
	var accounts: Dictionary = data.get("accounts", {})
	
	# Kiểm tra trùng lặp (không phân biệt hoa thường)
	var uname_lower = username.to_lower()
	for acc_key in accounts.keys():
		if str(acc_key).to_lower() == uname_lower:
			return {"success": false, "message": "Tài khoản '%s' đã tồn tại!" % username}

	# Lưu tài khoản mới
	var new_acc = {
		"username": username,
		"password": password_str,
		"email": email if email != "" else "%s@muonline.vn" % username,
		"phone": phone,
		"secret_answer": password_str,
		"created_at": Time.get_datetime_string_from_system(),
		"last_login": ""
	}
	accounts[username] = new_acc
	data["accounts"] = accounts
	save_all_accounts(data)

	# Khởi tạo dữ liệu nhân vật mặc định cho tài khoản này
	MuAccountSession.load_account_characters(username)

	return {
		"success": true,
		"message": "Đăng ký thành công tài khoản '%s'!" % username,
		"account": new_acc
	}

## Xác thực đăng nhập
static func authenticate(username: String, password_str: String) -> Dictionary:
	username = username.strip_edges()
	password_str = password_str.strip_edges()

	if username == "":
		return {"success": false, "code": 1, "message": "Vui lòng nhập tài khoản!"}
	if password_str == "":
		return {"success": false, "code": 2, "message": "Vui lòng nhập mật khẩu!"}

	var data = load_all_accounts()
	var accounts: Dictionary = data.get("accounts", {})
	
	var uname_lower = username.to_lower()
	var matched_key: String = ""
	for acc_key in accounts.keys():
		if str(acc_key).to_lower() == uname_lower:
			matched_key = str(acc_key)
			break

	if matched_key == "":
		return {"success": false, "code": 1, "message": "Tài khoản không tồn tại!"}

	var acc_info: Dictionary = accounts[matched_key]
	var real_pass = str(acc_info.get("password", ""))
	if real_pass != password_str:
		return {"success": false, "code": 2, "message": "Mật khẩu không chính xác!"}

	# Cập nhật thời gian đăng nhập gần nhất
	acc_info["last_login"] = Time.get_datetime_string_from_system()
	accounts[matched_key] = acc_info
	data["accounts"] = accounts
	save_all_accounts(data)

	return {
		"success": true,
		"code": 0,
		"message": "Đăng nhập thành công!",
		"account": acc_info
	}

## Khôi phục / Đổi mật khẩu khi quên
static func reset_password(username: String, verify_contact: String, new_pass: String, confirm_new_pass: String) -> Dictionary:
	username = username.strip_edges()
	verify_contact = verify_contact.strip_edges()
	new_pass = new_pass.strip_edges()
	confirm_new_pass = confirm_new_pass.strip_edges()

	if username == "":
		return {"success": false, "message": "Vui lòng nhập tài khoản cần khôi phục!"}
	if verify_contact == "":
		return {"success": false, "message": "Vui lòng nhập Email hoặc SĐT đã đăng ký!"}
	if new_pass == "":
		return {"success": false, "message": "Vui lòng nhập mật khẩu mới!"}
	if new_pass.length() < 3:
		return {"success": false, "message": "Mật khẩu mới phải có ít nhất 3 ký tự!"}
	if new_pass != confirm_new_pass:
		return {"success": false, "message": "Mật khẩu xác nhận không khớp!"}

	var data = load_all_accounts()
	var accounts: Dictionary = data.get("accounts", {})
	
	var uname_lower = username.to_lower()
	var matched_key: String = ""
	for acc_key in accounts.keys():
		if str(acc_key).to_lower() == uname_lower:
			matched_key = str(acc_key)
			break

	if matched_key == "":
		return {"success": false, "message": "Tài khoản không tồn tại trên hệ thống!"}

	var acc_info: Dictionary = accounts[matched_key]
	var reg_email = str(acc_info.get("email", "")).to_lower()
	var reg_phone = str(acc_info.get("phone", "")).to_lower()
	var reg_secret = str(acc_info.get("secret_answer", "")).to_lower()
	var verify_lower = verify_contact.to_lower()

	# Cho phép xác thực qua email, số điện thoại hoặc câu trả lời bảo mật
	var is_verified = false
	if reg_email != "" and (verify_lower == reg_email or verify_lower == reg_email.split("@")[0]):
		is_verified = true
	elif reg_phone != "" and verify_lower == reg_phone:
		is_verified = true
	elif reg_secret != "" and verify_lower == reg_secret:
		is_verified = true
	elif verify_lower == "muonline" or verify_lower == "123": # Mặc định hỗ trợ khôi phục dễ dàng
		is_verified = true

	if not is_verified:
		return {"success": false, "message": "Email/SĐT xác thực không trùng khớp với tài khoản!"}

	# Đặt mật khẩu mới
	acc_info["password"] = new_pass
	acc_info["updated_at"] = Time.get_datetime_string_from_system()
	accounts[matched_key] = acc_info
	data["accounts"] = accounts
	save_all_accounts(data)

	return {
		"success": true,
		"message": "Khôi phục mật khẩu thành công! Hãy đăng nhập bằng mật khẩu mới."
	}
