extends SceneTree

func _init() -> void:
	print("==================================================")
	print("TESTING MU ONLINE ACCOUNT MANAGEMENT")
	print("==================================================")

	# 1. Test Load Default Accounts
	var all = MuAccountManager.load_all_accounts()
	print("[1] Loaded accounts count: ", all.get("accounts", {}).size())
	assert(all.get("accounts", {}).has("test1"), "Default account test1 missing!")

	# 2. Test Register
	var reg_res = MuAccountManager.register_account("hero99", "pass123", "pass123", "hero99@mu.vn", "0912345678")
	print("[2] Register 'hero99': ", reg_res.message, " (success=", reg_res.success, ")")
	assert(reg_res.success, "Registration failed!")

	# Test Duplicate Register
	var dup_res = MuAccountManager.register_account("HERO99", "pass123", "pass123", "hero99@mu.vn")
	print("[2b] Register duplicate 'HERO99': ", dup_res.message, " (success=", not dup_res.success, ")")
	assert(not dup_res.success, "Duplicate check failed!")

	# 3. Test Authentication
	var auth_ok = MuAccountManager.authenticate("hero99", "pass123")
	print("[3a] Login 'hero99' with correct pass: ", auth_ok.message, " (success=", auth_ok.success, ")")
	assert(auth_ok.success, "Valid authentication failed!")

	var auth_fail = MuAccountManager.authenticate("hero99", "wrongpass")
	print("[3b] Login 'hero99' with wrong pass: ", auth_fail.message, " (success=", not auth_fail.success, ")")
	assert(not auth_fail.success, "Wrong pass should fail!")

	# 4. Test Forgot / Reset Password
	var reset_fail = MuAccountManager.reset_password("hero99", "wrongemail@mu.vn", "newpass888", "newpass888")
	print("[4a] Reset with wrong contact: ", reset_fail.message, " (success=", not reset_fail.success, ")")
	assert(not reset_fail.success, "Wrong email reset should fail!")

	var reset_ok = MuAccountManager.reset_password("hero99", "hero99@mu.vn", "newpass888", "newpass888")
	print("[4b] Reset with correct email: ", reset_ok.message, " (success=", reset_ok.success, ")")
	assert(reset_ok.success, "Reset password failed!")

	var auth_new = MuAccountManager.authenticate("hero99", "newpass888")
	print("[4c] Login with new password: ", auth_new.message, " (success=", auth_new.success, ")")
	assert(auth_new.success, "Login with new password failed!")

	print("==================================================")
	print("ALL ACCOUNT LOGIC TESTS PASSED SUCCESSFULLY! 100%")
	print("==================================================")
	quit()
