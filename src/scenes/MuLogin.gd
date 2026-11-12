extends Control
class_name MuLogin

## Giao diện Đăng Nhập, Đăng Ký & Khôi Phục Mật Khẩu MU Online
## Tái hiện 100% đồ họa gốc: 0account_new, Login_Back, các nút Register/Login/Cancel beveled vàng kim

# UI Nodes - Hộp Đăng Nhập
@onready var login_box: Control = $LoginBox
@onready var txt_user: LineEdit = $LoginBox/UserInput
@onready var txt_pass: LineEdit = $LoginBox/PassInput
@onready var btn_register: BaseButton = $LoginBox/BtnRegister
@onready var btn_ok: BaseButton = $LoginBox/BtnOk
@onready var btn_exit: BaseButton = $LoginBox/BtnExit
@onready var chk_remember: CheckBox = $LoginBox/ChkRemember
@onready var btn_forgot: Button = $LoginBox/BtnForgot
@onready var lbl_status: Label = $StatusLabel
@onready var btn_toggle_theme: Button = get_node_or_null("ThemeToggleButton")
@onready var txt_gateway: LineEdit = $GatewayConfig/GatewayInput
@onready var video_bg: VideoStreamPlayer = get_node_or_null("VideoBackground")
@onready var bgm_player: AudioStreamPlayer = get_node_or_null("BgmPlayer")

# UI Nodes - Hộp Đăng Ký
@onready var register_box: Control = $RegisterBox
@onready var txt_reg_user: LineEdit = $RegisterBox/RegUserInput
@onready var txt_reg_pass: LineEdit = $RegisterBox/RegPassInput
@onready var txt_reg_confirm: LineEdit = $RegisterBox/RegConfirmInput
@onready var txt_reg_contact: LineEdit = $RegisterBox/RegContactInput
@onready var btn_reg_submit: BaseButton = $RegisterBox/BtnRegSubmit
@onready var btn_reg_back: BaseButton = $RegisterBox/BtnRegBack

# UI Nodes - Hộp Quên Mật Khẩu
@onready var forgot_box: Control = $ForgotBox
@onready var txt_forgot_user: LineEdit = $ForgotBox/ForgotUserInput
@onready var txt_forgot_contact: LineEdit = $ForgotBox/ForgotContactInput
@onready var txt_forgot_new_pass: LineEdit = $ForgotBox/ForgotNewPassInput
@onready var txt_forgot_confirm: LineEdit = $ForgotBox/ForgotConfirmInput
@onready var btn_forgot_submit: BaseButton = $ForgotBox/BtnForgotSubmit
@onready var btn_forgot_back: BaseButton = $ForgotBox/BtnForgotBack

var network_client: MuNetworkClient = null
var current_video_is_season9: bool = false
var is_authenticating: bool = false

## Địa chỉ Gateway lấy từ manifest của server nội dung (MuContent tải ngầm), điền sẵn vào ô Gateway.
func _sync_gateway_from_content() -> void:
	for i in 40:
		if MuContent.gateway_url != "":
			txt_gateway.text = MuContent.gateway_url
			return
		if MuContent.get_state() in ["downloading", "done", "error"]:
			return
		await get_tree().create_timer(0.1).timeout

func _ready() -> void:
	# Nền 3D động gốc Season 9 (Data/World95: biển & chiến thuyền)
	MuSceneBackground3D.attach(self, MuSceneBackground3D.LOGIN_WORLD)
	_sync_gateway_from_content()

	# Khởi tạo network client
	network_client = MuNetworkClient.new()
	add_child(network_client)
	
	network_client.connected_to_server.connect(_on_connected)
	network_client.connection_error.connect(_on_network_error)
	network_client.packet_received.connect(_on_packet_received)
	
	# Sự kiện Login Box
	btn_ok.pressed.connect(_on_login_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	btn_register.pressed.connect(_show_register_modal)
	btn_forgot.pressed.connect(_show_forgot_modal)

	txt_user.text_submitted.connect(func(_t): txt_pass.grab_focus())
	txt_pass.text_submitted.connect(func(_t): _on_login_pressed())

	# Sự kiện Register Box
	btn_reg_submit.pressed.connect(_on_register_submit)
	btn_reg_back.pressed.connect(_show_login_modal)
	txt_reg_user.text_submitted.connect(func(_t): txt_reg_pass.grab_focus())
	txt_reg_pass.text_submitted.connect(func(_t): txt_reg_confirm.grab_focus())
	txt_reg_confirm.text_submitted.connect(func(_t): txt_reg_contact.grab_focus())
	txt_reg_contact.text_submitted.connect(func(_t): _on_register_submit())

	# Sự kiện Forgot Box
	btn_forgot_submit.pressed.connect(_on_forgot_submit)
	btn_forgot_back.pressed.connect(_show_login_modal)
	txt_forgot_user.text_submitted.connect(func(_t): txt_forgot_contact.grab_focus())
	txt_forgot_contact.text_submitted.connect(func(_t): txt_forgot_new_pass.grab_focus())
	txt_forgot_new_pass.text_submitted.connect(func(_t): txt_forgot_confirm.grab_focus())
	txt_forgot_confirm.text_submitted.connect(func(_t): _on_forgot_submit())

	if btn_toggle_theme:
		btn_toggle_theme.pressed.connect(_toggle_video_theme)

	# Tải hình ảnh nút bấm và giao diện chuẩn MU
	_setup_authentic_ui()
	_setup_login_bgm()

	# Nạp sẵn cơ sở dữ liệu tài khoản
	MuAccountManager.load_all_accounts()

	# Tải tài khoản đã lưu nếu có
	if FileAccess.file_exists("user://mu_login_saved.json"):
		var f = FileAccess.open("user://mu_login_saved.json", FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if data is Dictionary:
				txt_user.text = data.get("account", "")
				chk_remember.button_pressed = data.get("remember", true)
				# Bản cũ từng lưu mật khẩu thô: xoá ngay khỏi máy, chỉ nhớ tên tài khoản.
				if data.has("pass"):
					var f_clean = FileAccess.open("user://mu_login_saved.json", FileAccess.WRITE)
					if f_clean:
						f_clean.store_string(JSON.stringify({"account": data.get("account", ""), "remember": true}))
						f_clean.close()
	else:
		txt_user.text = ""
		chk_remember.button_pressed = false
		txt_pass.text = ""

	lbl_status.text = "Chào mừng đến với Lục Địa MU Online"
	MuAudioManager.play_ui_window()

# ==============================================================================
# CHUYỂN ĐỔI GIAO DIỆN MODAL
# ==============================================================================

func _show_login_modal() -> void:
	MuAudioManager.play_ui_click()
	login_box.visible = true
	register_box.visible = false
	forgot_box.visible = false
	lbl_status.text = "Chào mừng đến với Lục Địa MU Online"
	lbl_status.modulate = Color(1, 1, 1, 1)
	txt_user.grab_focus()

func _show_register_modal() -> void:
	MuAudioManager.play_ui_click()
	login_box.visible = false
	register_box.visible = true
	forgot_box.visible = false
	lbl_status.text = "Vui lòng nhập thông tin đăng ký tài khoản mới"
	lbl_status.modulate = Color(1, 0.9, 0.45, 1)
	txt_reg_user.text = ""
	txt_reg_pass.text = ""
	txt_reg_confirm.text = ""
	txt_reg_contact.text = ""
	txt_reg_user.grab_focus()

func _show_forgot_modal() -> void:
	MuAudioManager.play_ui_click()
	login_box.visible = false
	register_box.visible = false
	forgot_box.visible = true
	lbl_status.text = "Nhập tài khoản và thông tin xác thực để đặt mật khẩu mới"
	lbl_status.modulate = Color(1, 0.9, 0.45, 1)
	txt_forgot_user.text = txt_user.text.strip_edges()
	txt_forgot_contact.text = ""
	txt_forgot_new_pass.text = ""
	txt_forgot_confirm.text = ""
	if txt_forgot_user.text == "":
		txt_forgot_user.grab_focus()
	else:
		txt_forgot_contact.grab_focus()

# ==============================================================================
# XỬ LÝ ĐĂNG NHẬP (LOGIN)
# ==============================================================================

func _on_login_pressed() -> void:
	MuAudioManager.play_ui_click()
	var username = txt_user.text.strip_edges()
	var password = txt_pass.text.strip_edges()

	if username == "":
		_set_status("Vui lòng nhập tài khoản!", Color(1.0, 0.4, 0.4))
		txt_user.grab_focus()
		return
	if password == "":
		_set_status("Vui lòng nhập mật khẩu!", Color(1.0, 0.4, 0.4))
		txt_pass.grab_focus()
		return

	# Lưu hoặc bỏ ghi nhớ tài khoản
	if chk_remember.button_pressed:
		var f = FileAccess.open("user://mu_login_saved.json", FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"account": username, "remember": true}))
			f.close()
	else:
		if FileAccess.file_exists("user://mu_login_saved.json"):
			DirAccess.remove_absolute("user://mu_login_saved.json")

	MuAccountSession.server_gateway_url = txt_gateway.text.strip_edges()
	MuAccountSession.load_account_characters(username)

	_set_status("Đang kết nối tới máy chủ...", Color(1.0, 0.9, 0.4))
	btn_ok.disabled = true
	is_authenticating = true

	# Thử kết nối Gateway Server qua WebSocket
	var gateway_url = MuAccountSession.server_gateway_url
	if gateway_url != "":
		network_client.connect_to_gateway(gateway_url)
	else:
		_fallback_local_login(username, password)

func _fallback_local_login(username: String, password: String) -> void:
	# Bản phát hành KHÔNG được tự đăng nhập cục bộ khi mất kết nối (sẽ bỏ qua kiểm tra mật khẩu của máy chủ).
	if not OS.has_feature("editor"):
		_set_status("Không kết nối được máy chủ. Vui lòng thử lại sau.", Color(1.0, 0.4, 0.4))
		btn_ok.disabled = false
		is_authenticating = false
		return
	# (Chỉ trong editor) Xác thực với cơ sở dữ liệu tài khoản cục bộ
	var res = MuAccountManager.authenticate(username, password)
	if res.success:
		_set_status("Đăng nhập thành công! Đang tải danh sách máy chủ...", Color(0.4, 1.0, 0.4))
		MuAudioManager.play_ui_click()
		await get_tree().create_timer(0.35).timeout
		get_tree().change_scene_to_file("res://src/scenes/ServerSelectScene.tscn")
	else:
		_set_status(res.message, Color(1.0, 0.4, 0.4))
		btn_ok.disabled = false
		is_authenticating = false

func _on_connected() -> void:
	_set_status("Đã kết nối! Đang xác thực thông tin...", Color(0.6, 1.0, 0.6))
	var username = txt_user.text.strip_edges()
	var password = txt_pass.text.strip_edges()
	var login_packet = MuPackets.build_login_packet(username, password)
	network_client.send_packet(login_packet)

func _on_network_error(_msg: String) -> void:
	# Khi máy chủ Gateway chưa bật, tự động chuyển sang xác thực cục bộ mượt mà!
	var username = txt_user.text.strip_edges()
	var password = txt_pass.text.strip_edges()
	_fallback_local_login(username, password)

func _on_packet_received(_header: int, code: int, sub_code: int, data: PackedByteArray) -> void:
	if code == 0xF1 and sub_code == 0x01:
		var result = data[4] if data.size() > 4 else 1
		if result == 1:
			# Gateway có thể gửi kèm token phiên sau byte kết quả
			MuAccountSession.session_token = data.slice(5).get_string_from_ascii() if data.size() > 5 else ""
			_set_status("Đăng nhập thành công! Đang tải danh sách máy chủ...", Color(0.4, 1.0, 0.4))
			await get_tree().create_timer(0.3).timeout
			get_tree().change_scene_to_file("res://src/scenes/ServerSelectScene.tscn")
		elif result == 0:
			_set_status("Mật khẩu không chính xác!", Color(1.0, 0.4, 0.4))
			btn_ok.disabled = false
			is_authenticating = false
		elif result == 2:
			_set_status("Tài khoản đang online!", Color(1.0, 0.5, 0.2))
			btn_ok.disabled = false
			is_authenticating = false
		else:
			_set_status("Đăng nhập thành công!", Color(0.4, 1.0, 0.4))
			get_tree().change_scene_to_file("res://src/scenes/ServerSelectScene.tscn")

# ==============================================================================
# XỬ LÝ ĐĂNG KÝ (REGISTER)
# ==============================================================================

func _on_register_submit() -> void:
	MuAudioManager.play_ui_click()
	if not OS.has_feature("editor"):
		_set_status("Hãy đăng ký tài khoản tại muonline.viettheo.site", Color(1.0, 0.9, 0.4))
		return
	var user = txt_reg_user.text.strip_edges()
	var pwd = txt_reg_pass.text.strip_edges()
	var confirm = txt_reg_confirm.text.strip_edges()
	var contact = txt_reg_contact.text.strip_edges()

	var res = MuAccountManager.register_account(user, pwd, confirm, contact, contact)
	if res.success:
		_set_status(res.message, Color(0.4, 1.0, 0.4))
		# Tự động điền tài khoản vừa đăng ký vào ô đăng nhập
		txt_user.text = user
		txt_pass.text = pwd
		# Trở về giao diện đăng nhập
		register_box.visible = false
		login_box.visible = true
	else:
		_set_status(res.message, Color(1.0, 0.35, 0.35))
		if "tài khoản" in res.message.to_lower():
			txt_reg_user.grab_focus()
		elif "xác nhận" in res.message.to_lower():
			txt_reg_confirm.grab_focus()
		else:
			txt_reg_pass.grab_focus()

# ==============================================================================
# XỬ LÝ QUÊN MẬT KHẨU (FORGOT PASSWORD)
# ==============================================================================

func _on_forgot_submit() -> void:
	MuAudioManager.play_ui_click()
	if not OS.has_feature("editor"):
		_set_status("Liên hệ quản trị viên để đặt lại mật khẩu.", Color(1.0, 0.9, 0.4))
		return
	var user = txt_forgot_user.text.strip_edges()
	var contact = txt_forgot_contact.text.strip_edges()
	var new_pass = txt_forgot_new_pass.text.strip_edges()
	var confirm_new = txt_forgot_confirm.text.strip_edges()

	var res = MuAccountManager.reset_password(user, contact, new_pass, confirm_new)
	if res.success:
		_set_status(res.message, Color(0.4, 1.0, 0.4))
		txt_user.text = user
		txt_pass.text = new_pass
		forgot_box.visible = false
		login_box.visible = true
	else:
		_set_status(res.message, Color(1.0, 0.35, 0.35))
		if "mật khẩu" in res.message.to_lower():
			txt_forgot_new_pass.grab_focus()
		else:
			txt_forgot_contact.grab_focus()

func _set_status(msg: String, col: Color = Color.WHITE) -> void:
	lbl_status.text = msg
	lbl_status.modulate = col

func _on_exit_pressed() -> void:
	MuAudioManager.play_ui_click()
	get_tree().quit()

# ==============================================================================
# THIẾT LẬP GIAO DIỆN VÀ HÌNH ẢNH NÚT GỐC MU
# ==============================================================================

func _setup_authentic_ui() -> void:
	var top_logo: TextureRect = get_node_or_null("TopLogo")
	var box_texture: TextureRect = get_node_or_null("LoginBox/BoxTexture")
	var plate_acc: TextureRect = get_node_or_null("LoginBox/PlateAccount")
	var plate_pass: TextureRect = get_node_or_null("LoginBox/PlatePassword")

	var logo_tex = _load_external_tex("res://assets/textures/ui/login_classic/cr_mu_lo.png")
	if logo_tex and top_logo:
		top_logo.texture = logo_tex

	var box_tex = _load_external_tex("res://assets/textures/ui/login_classic/login_back.png")
	if box_tex:
		if box_texture: box_texture.texture = box_tex
		var reg_box_tex: TextureRect = get_node_or_null("RegisterBox/BoxTexture")
		if reg_box_tex: reg_box_tex.texture = box_tex
		var forgot_box_tex: TextureRect = get_node_or_null("ForgotBox/BoxTexture")
		if forgot_box_tex: forgot_box_tex.texture = box_tex

	var plate_tex = _load_external_tex("res://assets/textures/ui/login_classic/login_me.png")
	if plate_tex:
		if plate_acc: plate_acc.texture = plate_tex
		if plate_pass: plate_pass.texture = plate_tex
		for p in ["RegisterBox/PlateRegUser", "RegisterBox/PlateRegPass", "RegisterBox/PlateRegConfirm", "RegisterBox/PlateRegContact",
				  "ForgotBox/PlateForgotUser", "ForgotBox/PlateForgotContact", "ForgotBox/PlateForgotNewPass", "ForgotBox/PlateForgotConfirm"]:
			var node: TextureRect = get_node_or_null(p)
			if node: node.texture = plate_tex

	# Nạp 3 nút đã cắt từ ảnh gốc của người dùng (kích thước <= 80px)
	_apply_button_textures(btn_register, "btn_register")
	_apply_button_textures(btn_ok, "btn_login")
	_apply_button_textures(btn_exit, "btn_cancel")

	# Gán texture cho các nút trong Modal Đăng ký và Quên mật khẩu
	_apply_button_textures(btn_reg_submit, "btn_register")
	_apply_button_textures(btn_reg_back, "btn_cancel")
	_apply_button_textures(btn_forgot_submit, "btn_login")
	_apply_button_textures(btn_forgot_back, "btn_cancel")

func _apply_button_textures(btn: BaseButton, prefix: String) -> void:
	if not (btn is TextureButton):
		return
	var t_btn: TextureButton = btn as TextureButton
	var n_tex = _load_external_tex("res://assets/textures/ui/login_classic/%s_normal.png" % prefix)
	var h_tex = _load_external_tex("res://assets/textures/ui/login_classic/%s_hover.png" % prefix)
	var p_tex = _load_external_tex("res://assets/textures/ui/login_classic/%s_pressed.png" % prefix)
	if n_tex:
		t_btn.texture_normal = n_tex
	if h_tex:
		t_btn.texture_hover = h_tex
	if p_tex:
		t_btn.texture_pressed = p_tex

func _load_external_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res: return res
	var global_path = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path) or FileAccess.file_exists(res_path):
		var img = Image.new()
		var err = img.load(global_path if FileAccess.file_exists(global_path) else res_path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	return null

func _setup_login_bgm() -> void:
	if not bgm_player:
		return
	var bgm_path = "res://assets/mu/Music/login_theme.mp3"
	if FileAccess.file_exists(bgm_path):
		var f = FileAccess.open(bgm_path, FileAccess.READ)
		if f:
			var stream = AudioStreamMP3.new()
			stream.data = f.get_buffer(f.get_length())
			stream.loop = true
			bgm_player.stream = stream
			bgm_player.volume_db = -6.0
			bgm_player.play()

func _toggle_video_theme() -> void:
	if not video_bg:
		return
	MuAudioManager.play_ui_click()
	current_video_is_season9 = !current_video_is_season9
	var target_file = "res://assets/video/login_bg_season9.ogv" if current_video_is_season9 else "res://assets/video/login_bg.ogv"
	var theora_stream = VideoStreamTheora.new()
	theora_stream.file = target_file
	video_bg.stop()
	video_bg.stream = theora_stream
	video_bg.play()
	if btn_toggle_theme:
		btn_toggle_theme.text = "🎬 Đang dùng: Season 9" if current_video_is_season9 else "🎬 Đang dùng: Classic"
