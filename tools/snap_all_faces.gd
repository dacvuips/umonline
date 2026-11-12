extends SceneTree

func _init() -> void:
	var root_node = Control.new()
	root_node.size = Vector2(1280, 720)
	root.add_child(root_node)
	
	var vp_container = SubViewportContainer.new()
	vp_container.size = Vector2(410, 335)
	root_node.add_child(vp_container)
	
	var vp = SubViewport.new()
	vp.size = Vector2i(410, 335)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(vp)
	
	var cam = Camera3D.new()
	cam.position = Vector3(0, 0.088, 0.32)
	cam.fov = 30.0
	vp.add_child(cam)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, 30, 0)
	light.light_energy = 1.4
	vp.add_child(light)

	var fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(20, -150, 0)
	fill_light.light_energy = 0.7
	fill_light.light_color = Color(0.8, 0.85, 1.0)
	vp.add_child(fill_light)
	
	var anchor = Node3D.new()
	vp.add_child(anchor)
	
	# Test all 7
	for i in range(1, 8):
		for ch in anchor.get_children():
			ch.queue_free()
		
		var res = load("res://assets/mu/Logo/NewFace%02d.glb" % i)
		var inst: Node3D = res.instantiate()
		anchor.add_child(inst)
		
		# Apply scaling according to GetRenderParameters
		match i:
			1: # Wizard
				inst.position = Vector3(0, -0.015, 0)
				inst.rotation_degrees = Vector3(0, -25, 0)
				inst.scale = Vector3.ONE * 1.0
			2: # Knight
				inst.position = Vector3(0, -0.012, 0)
				inst.rotation_degrees = Vector3(0, -10, 0)
				inst.scale = Vector3.ONE * 1.0
			3: # Elf
				inst.position = Vector3(0, -0.005, 0)
				inst.rotation_degrees = Vector3(5, 5, 0)
				inst.scale = Vector3.ONE * 1.45
			4: # Magic Gladiator
				inst.position = Vector3(0, -0.012, 0)
				inst.rotation_degrees = Vector3(0, -12, 0)
				inst.scale = Vector3.ONE * 1.0
			5: # Dark Lord
				inst.position = Vector3(0, -0.015, 0)
				inst.rotation_degrees = Vector3(0, -14, 0)
				inst.scale = Vector3.ONE * 1.0
			6: # Summoner
				inst.position = Vector3(0, 0.002, 0)
				inst.rotation_degrees = Vector3(2, 2, 0)
				inst.scale = Vector3.ONE * 1.45
			7: # Rage Fighter
				inst.position = Vector3(0, -0.015, 0)
				inst.rotation_degrees = Vector3(0, 0, 0)
				inst.scale = Vector3.ONE * 0.95
		
		for child in inst.find_children("*", "AnimationPlayer"):
			child.play("a000")
			
		await create_timer(0.15).timeout
		await process_frame
		
		var img = vp.get_texture().get_image()
		img.save_png("E:/MuMain/snap_face_%d.png" % i)
		print("Saved snap_face_%d.png" % i)
		
	quit(0)
