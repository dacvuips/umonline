extends SceneTree

func _init() -> void:
	var scene = load("res://src/scenes/LoginScene.tscn").instantiate()
	root.add_child(scene)

	for i in range(10):
		await process_frame

	var img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_login_main.png")
	print("Saved snap_login_main.png")

	scene.call("_show_register_modal")
	for i in range(5):
		await process_frame
	img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_login_register.png")
	print("Saved snap_login_register.png")

	scene.call("_show_forgot_modal")
	for i in range(5):
		await process_frame
	img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_login_forgot.png")
	print("Saved snap_login_forgot.png")

	quit()
