extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" KIỂM THỬ HỆ THỐNG DATA THẬT MU GODOT ONLINE")
	print("==================================================")

	# 1. KIỂM THỬ TẠO TÀI KHOẢN VÀ LƯU DATA THẬT
	print("\n--- [1] Kiểm thử Tạo Tài Khoản & Lưu Thật ---")
	var test_user = "hero%04d" % (randi() % 9000 + 1000)
	var test_pass = "mupass777"
	var reg_res = MuAccountManager.register_account(test_user, test_pass, test_pass, test_user + "@mu.vn", "0912345678")
	assert(reg_res.success, "Đăng ký tài khoản thất bại: " + reg_res.get("message", ""))
	print("-> Đăng ký thành công tài khoản: ", test_user)

	# Kiểm tra dữ liệu file accounts
	var acc_data = MuAccountManager.load_all_accounts()
	assert(acc_data.has("accounts") and acc_data["accounts"].has(test_user), "Tài khoản không được lưu trong user://mu_accounts.json!")
	print("-> Dữ liệu tài khoản đã được lưu thật vào user://mu_accounts.json thành công!")

	# Kiểm tra xác thực (Đăng nhập đúng & sai mật khẩu)
	var auth_ok = MuAccountManager.authenticate(test_user, test_pass)
	assert(auth_ok.success, "Đăng nhập với mật khẩu đúng bị thất bại!")
	var auth_fail = MuAccountManager.authenticate(test_user, "wrong_pass")
	assert(not auth_fail.success, "Đăng nhập với mật khẩu sai lại thành công!")
	print("-> Xác thực đăng nhập chính xác 100%!")

	# 2. KIỂM THỬ SERVER & TÊN SERVER THẬT
	print("\n--- [2] Kiểm thử Server & Tên Server Thật ---")
	assert(MuAccountSession.SERVER_DATA.size() >= 3, "Danh sách cụm server không đủ!")
	var grp_names = []
	for g in MuAccountSession.SERVER_DATA:
		grp_names.append(g["group_name"])
	print("-> Danh sách Cụm Server Thật: ", grp_names)
	assert("Lorencia" in grp_names, "Thiếu server Lorencia!")
	assert("Noria" in grp_names, "Thiếu server Noria!")
	assert("Devias" in grp_names, "Thiếu server Devias!")

	MuAccountSession.selected_server_group = "Lorencia"
	MuAccountSession.selected_server_channel = "Lorencia-1"
	MuAccountSession.selected_server_code = 1
	print("-> Đã chọn Server: %s - Kênh: %s" % [MuAccountSession.selected_server_group, MuAccountSession.selected_server_channel])

	# 3. KIỂM THỬ TẠO NHÂN VẬT & LƯU DATA THẬT
	print("\n--- [3] Kiểm thử Tạo Nhân Vật Mới & Lưu Thật ---")
	MuAccountSession.load_account_characters(test_user)
	assert(MuAccountSession.get_live_character_count() == 0, "Tài khoản mới tạo không được có nhân vật sẵn!")
	print("-> Tài khoản mới ban đầu có đúng 0 nhân vật (5 slot rỗng)")

	var char_dk = MuAccountSession.create_character("DKReal", 1, 0, 1)
	assert(not char_dk.is_empty(), "Không thể tạo nhân vật Dark Knight!")
	assert(char_dk["level"] == 1, "Level nhân vật mới tạo phải là 1!")
	assert(char_dk["equipment"].is_empty(), "Nhân vật mới tạo KHÔNG ĐƯỢC có trang bị nào!")
	assert(char_dk["inventory"].is_empty(), "Nhân vật mới tạo túi đồ phải rỗng!")
	assert(char_dk["zen"] == 0, "Nhân vật mới tạo zen phải là 0!")
	assert(char_dk["stat_points"] == 0, "Nhân vật mới tạo point phải là 0!")
	print("-> Nhân vật 'DKReal' tạo thành công: Level 1, Equipment rỗng {}, Zen 0, Point 0")

	# Kiểm tra lưu thật vào file json của tài khoản
	var char_file_path = MuAccountSession.SAVE_PATH_TEMPLATE % test_user
	assert(FileAccess.file_exists(char_file_path), "File nhân vật của tài khoản không tồn tại trên ổ đĩa!")
	print("-> File dữ liệu nhân vật lưu thật tại: ", char_file_path)

	# 4. KIỂM THỬ VÀO GAME KHÔNG BỊ CHO ĐỒ CẤP CAO (KHÔNG CÓ ĐỒ RỒNG ĐỎ)
	print("\n--- [4] Kiểm thử Vào Game Không Bị Ép Đồ Cao Cấp (Set Rồng) ---")
	var player = MuPlayer.new()
	root.add_child(player)
	player._ready()

	print("-> Player equipment sau khi vào game: ", player.equipment)
	assert(player.equipment.is_empty(), "LỖI NGUY HIỂM: Player vẫn bị gán đồ khi vào game! Equipment: " + str(player.equipment))
	assert(not player.equipment.has("helm"), "Lỗi: Vẫn bị mặc Mũ Rồng!")
	assert(not player.equipment.has("armor"), "Lỗi: Vẫn bị mặc Áo Rồng!")
	assert(not player.equipment.has("right"), "Lỗi: Vẫn bị cầm Vũ khí cao cấp!")
	print("-> XÁC NHẬN: Nhân vật hoàn toàn KHÔNG CÓ ĐỒ RỒNG ĐỎ hay trang bị cao cấp nào!")

	# 5. KIỂM THỬ THAY ĐỔI DỮ LIỆU & LƯU THẬT VÀO DISK
	print("\n--- [5] Kiểm thử Thay Đổi & Lưu Tiến Trình Nhân Vật ---")
	player.add_zen(500)
	player.add_exp(300) # Lên cấp
	player.add_stat_point("str", 2)
	player.equip("right", 0, 0, 0) # Tự trang bị Dao găm cùi (Small Dagger)
	player.sync_to_session()

	# Tải lại từ file để kiểm tra tính bền vững (Persistence)
	MuAccountSession.load_account_characters(test_user)
	var loaded_char = MuAccountSession.get_character_at(0)
	assert(loaded_char["level"] >= 2, "Level không được lưu vào file!")
	assert(loaded_char["zen"] == 500, "Zen không được lưu vào file!")
	assert(loaded_char["stat_str"] == 30, "Điểm Sức mạnh không được lưu vào file!")
	assert(loaded_char["equipment"].has("right"), "Trang bị mới không được lưu vào file!")
	print("-> Tiến trình chơi game (Level: %d, Zen: %d, Str: %d) đã được lưu thật vào disk thành công 100%%!" % [
		loaded_char["level"], loaded_char["zen"], loaded_char["stat_str"]
	])

	# 6. KIỂM THỬ XÓA NHÂN VẬT THẬT
	print("\n--- [6] Kiểm thử Xóa Nhân Vật Thật ---")
	var del_ok = MuAccountSession.delete_character_at(0)
	assert(del_ok, "Xóa nhân vật thất bại!")
	MuAccountSession.load_account_characters(test_user)
	assert(MuAccountSession.get_live_character_count() == 0, "Nhân vật đã xóa vẫn còn tồn tại trong file!")
	print("-> Xóa nhân vật đã được lưu thật vào disk thành công (Slot 0 đã rỗng)!")

	player.queue_free()

	print("\n==================================================")
	print(" TẤT CẢ KIỂM THỬ THÀNH CÔNG RỰC RỠ 100%!")
	print("==================================================")
	quit()
