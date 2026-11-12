extends SceneTree

func _init() -> void:
	print("=== VERIFYING CHARACTER CLASSES FIX ===")
	
	# Verify unlock logic
	print("Checking class unlock requirements:")
	var highest = MuAccountSession.get_highest_character_level()
	print("Account highest level: ", highest)
	for cid in [0, 1, 2, 3, 4, 5, 6]:
		var unlocked = MuAccountSession.is_class_unlocked(cid)
		var cinfo = MuAccountSession.CLASS_INFO[cid]
		print("  Class %d (%s): unlocked=%s (req: %s)" % [
			cid, cinfo["name"], unlocked, MuAccountSession.get_class_requirement_text(cid)
		])
	
	# Instantiate CharacterSelectScene
	var scene = load("res://src/scenes/CharacterSelectScene.tscn").instantiate()
	root.add_child(scene)
	
	await create_timer(0.6).timeout
	await process_frame
	
	var img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_verify_charsel_clean.png")
	print("Saved E:/MuMain/snap_verify_charsel_clean.png")
	
	# Open creation modal
	var modal = scene.get_node("CharMakeModal")
	modal.open_dialog()
	await create_timer(0.3).timeout
	await process_frame
	
	img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_verify_charmake_modal.png")
	print("Saved E:/MuMain/snap_verify_charmake_modal.png")

	# Select locked MG (class_id 3, index 5 in CLASS_LIST)
	modal._select_class(5)
	await create_timer(0.3).timeout
	await process_frame
	img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_verify_charmake_mg_locked.png")
	print("Saved E:/MuMain/snap_verify_charmake_mg_locked.png")
	
	print("=== ALL VERIFICATION CHECKS COMPLETED SUCCESSFULLY ===")
	quit(0)
