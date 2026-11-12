extends SceneTree

func _init() -> void:
	for i in range(1, 8):
		var path = "res://assets/mu/Logo/NewFace%02d.glb" % i
		var inst: Node3D = load(path).instantiate()
		var aabb = AABB()
		var first = true
		for mesh in inst.find_children("*", "MeshInstance3D"):
			if first:
				aabb = mesh.get_aabb()
				first = false
			else:
				aabb = aabb.merge(mesh.get_aabb())
		print("NewFace%02d: AABB Center=%s, Size=%s" % [i, aabb.get_center(), aabb.size])
		inst.free()
	quit(0)
