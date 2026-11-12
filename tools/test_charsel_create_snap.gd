extends SceneTree

func _init() -> void:
	print("--- TESTING CHAR SEL CREATE UI SNAP ---")
	var scene = load("res://src/scenes/CharacterSelectScene.tscn").instantiate()
	root.add_child(scene)
	
	# Wait for scene to load
	await create_timer(0.4).timeout
	await process_frame
	
	# Open creation dialog
	var modal = scene.get_node_or_null("CharMakeModal")
	if modal:
		modal.open_dialog()
		print("Opened CharMakeModal successfully!")
	else:
		print("ERROR: CharMakeModal not found!")
		
	# Wait for bust model and UI to render
	await create_timer(0.5).timeout
	await process_frame
	
	var img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_charsel_create_ui.png")
	print("Saved E:/MuMain/snap_charsel_create_ui.png")
	quit(0)
