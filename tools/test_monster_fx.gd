extends SceneTree

## Kiểm tra nhanh (headless): dựng quái và đếm hiệu ứng trên người + skill đánh.
##   Godot --headless --path . --script res://tools/test_monster_fx.gd

const CharModel = preload("res://src/mu/MuCharacterModel.gd")
const MonsterRes = preload("res://src/entities/MuMonster.gd")

func _count(n: Node, cls: String) -> int:
	var c := 1 if n.is_class(cls) else 0
	for ch in n.get_children():
		c += _count(ch, cls)
	return c

func _initialize() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for num in [0, 4, 18, 22, 25, 28, 36, 40, 49, 63, 71, 304, 306, 309, 350, 356, 358, 360, 422, 441, 445, 449, 454, 458, 489, 505, 510, 569, 576, 144, 160, 292, 295]:
		var m = CharModel.new()
		holder.add_child(m)
		var mon := MuCatalog.find_monster(num, "")
		var nm: String = MuCatalog.find_monster(num, "").get("name", {}).get("en", "?") if mon.get("name") is Dictionary else str(mon.get("name", "?"))
		var ok: bool = m.build_monster(num, nm)
		var fx = m.get_node_or_null("MonsterFx")
		var sprites := _count(fx, "MeshInstance3D") if fx else 0
		var bone_fx := 0
		if m.skeleton:
			for c in m.skeleton.get_children():
				if c.name.begins_with("FxBone"):
					bone_fx += c.get_child_count()
		var atk: int = MonsterRes.ORIGINAL_ATTACK.get(num, -1)
		var blend := 0
		if m.skeleton:
			for c in m.skeleton.get_children():
				if c is MeshInstance3D and c.mesh:
					for si in c.mesh.get_surface_count():
						var om = c.get_surface_override_material(si)
						if om is ShaderMaterial and om.shader and om.shader.resource_path.ends_with("mu_object_blend.gdshader"):
							blend += 1
		print("  #%d %-24s slot=%-26s bone_fx=%d particles=%d blend=%d attack=%d" % [num, nm,
			str(mon.get("model", "")).replace("MONSTER_MODEL_", ""), bone_fx, _count(m, "CPUParticles3D"), blend, atk])
		m.free()
	quit()
