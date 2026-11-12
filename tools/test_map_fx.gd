extends SceneTree

## Kiểm tra nhanh (headless): dựng vật thể của các bản đồ và đếm hiệu ứng đã gắn.
##   Godot --headless --path . --script res://tools/test_map_fx.gd

const MapObjects = preload("res://src/world/MuMapObjects.gd")

func _count(n: Node, cls: String) -> int:
	var c := 1 if n.is_class(cls) else 0
	for ch in n.get_children():
		c += _count(ch, cls)
	return c

func _sprites(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D and (n as MeshInstance3D).material_override is ShaderMaterial:
		var sm := (n as MeshInstance3D).material_override as ShaderMaterial
		if sm.shader and sm.shader.resource_path.ends_with("mu_sprite.gdshader"):
			c = 1
	for ch in n.get_children():
		c += _sprites(ch)
	return c

func _initialize() -> void:
	for w in [2, 3, 4, 5, 7, 8, 9, 11, 12]:
		MuTerrain.world_id = w
		MuTerrain.ensure_loaded()
		var mo = MapObjects.new()
		root.add_child(mo)
		mo.build(w)
		print("  -> World%d: sprite=%d, particles=%d, timed=%d" % [w, _sprites(mo), _count(mo, "CPUParticles3D"), mo._timed_fx.size()])
		mo.free()
	quit()
