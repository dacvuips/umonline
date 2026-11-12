extends SceneTree

func _init() -> void:
	print("--- TEST NEW ACCOUNT HAS 0 CHARACTERS ---")
	var res = MuAccountManager.register_account("newplayer1", "123456", "123456")
	print("Register newplayer1: ", res.message)
	
	MuAccountSession.load_account_characters("newplayer1")
	var count = MuAccountSession.get_live_character_count()
	print("Live character count for newplayer1: ", count)
	assert(count == 0, "New account must have 0 characters!")
	
	print("SUCCESS: New account is completely empty with 0 characters!")
	quit()
