extends SceneTree

func _init() -> void:
	MuAccountSession.load_account_characters("dacvuip")
	var scene = load("res://src/scenes/CharacterSelectScene.tscn").instantiate()
	root.add_child(scene)

	for i in range(10):
		await process_frame

	var img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_charsel_empty.png")
	print("Saved snap_charsel_empty.png")
	quit()
