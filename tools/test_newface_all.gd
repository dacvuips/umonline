extends SceneTree

func _init() -> void:
	print("--- TESTING ALL 7 NEWFACE GLB MODELS ---")
	for i in range(1, 8):
		var path = "res://assets/mu/Logo/NewFace%02d.glb" % i
		var res = load(path)
		if not res:
			print("FAIL: ", path)
			continue
		var inst = res.instantiate()
		var mesh_count = 0
		var anim_names = []
		for node in inst.find_children("*", "MeshInstance3D"):
			mesh_count += 1
		for node in inst.find_children("*", "AnimationPlayer"):
			anim_names = node.get_animation_list()
		print("SUCCESS: ", path, " Meshes=", mesh_count, " Anims=", anim_names)
		inst.free()
	quit(0)
