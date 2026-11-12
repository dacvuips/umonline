extends SceneTree

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")

func _init() -> void:
	print("--- TESTING ANGLES FOR BOW 06 ---")
	var path: String = MuCatalogRes.item_glb(4, 6)
	var inst := MuModelRes.instantiate(path)
	
	for y_deg in [0, 45, 90, 135, 180, 225, 270, 315]:
		var rot: Array = [180.0, float(y_deg), 25.0]
		var b: Basis = MuItemIconRes._basis(rot)
		var holder := Node3D.new()
		holder.basis = b
		holder.add_child(inst)
		
		var aabb := AABB()
		var first := true
		for mi in MuModelRes.find_all(inst, "MeshInstance3D", []):
			var m := mi as MeshInstance3D
			if m and m.mesh:
				var xf: Transform3D = holder.transform * MuItemIconRes._local(m, holder)
				var bb: AABB = xf * m.mesh.get_aabb()
				aabb = bb if first else aabb.merge(bb)
				first = false
		holder.remove_child(inst)
		holder.free()
		print("rot=[180, %3d, 25] => projected AABB size: X=%.3f, Y=%.3f, Z=%.3f" % [y_deg, aabb.size.x, aabb.size.y, aabb.size.z])
	
	inst.free()
	quit(0)
