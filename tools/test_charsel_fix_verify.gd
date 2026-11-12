extends SceneTree

func _init() -> void:
	print("--- VERIFYING CHARSEL BUTTONS & BUST ISOLATION ---")
	var scene = load("res://src/scenes/CharacterSelectScene.tscn").instantiate()
	root.add_child(scene)
	
	# Chờ load xong
	await create_timer(0.4).timeout
	await process_frame
	
	var btn_create = scene.get_node("BottomLeft/BtnCreate")
	var btn_menu = scene.get_node("BottomLeft/BtnMenu")
	var modal = scene.get_node("CharMakeModal")
	
	# 1. Idle screen
	var img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_verify_1_idle.png")
	print("Saved 1: snap_verify_1_idle.png")
	
	# 2. Hover on Menu
	var ev_menu = InputEventMouseMotion.new()
	ev_menu.position = btn_menu.global_position + Vector2(20, 15)
	btn_menu._gui_input(ev_menu)
	# Trigger mouse entered
	btn_menu.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await create_timer(0.1).timeout
	await process_frame
	
	img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_verify_2_menu_hover.png")
	print("Saved 2: snap_verify_2_menu_hover.png")
	
	btn_menu.notification(Control.NOTIFICATION_MOUSE_EXIT)
	
	# 3. Hover on Create
	btn_create.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await create_timer(0.1).timeout
	await process_frame
	img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_verify_3_create_hover.png")
	print("Saved 3: snap_verify_3_create_hover.png")
	btn_create.notification(Control.NOTIFICATION_MOUSE_EXIT)

	# 4. Open Modal & Select Tiên Nữ (Elf)
	modal.open_dialog()
	await create_timer(0.1).timeout
	modal._select_class(2) # Elf
	await create_timer(0.4).timeout
	await process_frame
	img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_verify_4_modal_elf.png")
	print("Saved 4: snap_verify_4_modal_elf.png")

	# 5. Close Modal & check if bust is completely gone from character select ground
	modal.close_dialog()
	await create_timer(0.4).timeout
	await process_frame
	img = root.get_texture().get_image()
	img.save_png("E:/MuMain/snap_verify_5_after_close.png")
	print("Saved 5: snap_verify_5_after_close.png")
	
	quit(0)
