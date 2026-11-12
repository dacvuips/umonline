extends SceneTree

func _init() -> void:
	var root_node = Control.new()
	root_node.size = Vector2(1280, 720)
	root.add_child(root_node)
	
	var vp_container = SubViewportContainer.new()
	vp_container.size = Vector2(410, 335)
	vp_container.position = Vector2(100, 100)
	root_node.add_child(vp_container)
	
	var vp = SubViewport.new()
	vp.size = Vector2i(410, 335)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(vp)
	
	var cam = Camera3D.new()
	# In MU: camera is framed at the bust
	# The bust model has bounds: Y from 0.06 to 0.125 -> center is ~0.092. X is -0.025 to 0.027.
	cam.position = Vector3(0, 0.092, 0.15)
	cam.fov = 28.0
	vp.add_child(cam)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-20, 25, 0)
	light.light_energy = 1.3
	vp.add_child(light)

	var fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(15, -145, 0)
	fill_light.light_energy = 0.6
	fill_light.light_color = Color(0.8, 0.85, 1.0)
	vp.add_child(fill_light)
	
	var res = load("res://assets/mu/Logo/NewFace02.glb")
	var inst: Node3D = res.instantiate()
	inst.rotation_degrees = Vector3(0, 0, 0)
	vp.add_child(inst)
	
	for child in inst.find_children("*", "AnimationPlayer"):
		child.play("a000")
		
	await create_timer(0.4).timeout
	await process_frame
	
	var img = vp.get_texture().get_image()
	img.save_png("E:/MuMain/test_bust_render.png")
	print("Saved E:/MuMain/test_bust_render.png")
	quit(0)
