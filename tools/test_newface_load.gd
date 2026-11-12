extends Node3D

func _ready() -> void:
	var glb_path = "res://assets/mu/Logo/NewFace02.glb"
	var res = load(glb_path)
	if not res:
		print("ERROR: Could not load ", glb_path)
		get_tree().quit()
		return
	
	var inst = res.instantiate()
	add_child(inst)
	print("Instantiated NewFace02 successfully!")
	
	# Find AnimationPlayer
	var anim_player: AnimationPlayer = null
	for child in inst.get_children():
		if child is AnimationPlayer:
			anim_player = child
			break
	if not anim_player:
		for child in inst.find_children("*", "AnimationPlayer"):
			anim_player = child
			break
			
	if anim_player:
		print("Found AnimationPlayer, list: ", anim_player.get_animation_list())
		if anim_player.has_animation("a000"):
			anim_player.play("a000")
			print("Playing a000")
	
	await get_tree().create_timer(0.3).timeout
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	img.save_png("res://test_newface02_snap.png")
	print("Saved test_newface02_snap.png")
	get_tree().quit()
