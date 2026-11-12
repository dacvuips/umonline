extends Node3D

## Mô phỏng trong thế giới (có địa hình Lorencia) để xem bóng nhân vật: godot --path MuMain res://tools/world_shadow.tscn -- <thư_mục> <lớp> <bộ> <cấp|-1 = trần>
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]; var cls := int(a[1]); var sn := int(a[2]); var lv := int(a[3])
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(900, 600)
	MuCatalog.ensure_loaded()
	MuTerrain.change_world(1)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -30, 0); add_child(sun)
	var terrain := MuTerrain.new()
	add_child(terrain)
	var tx := 135.5; var ty := 125.5
	var gy := MuTerrain.height_at(tx, ty)
	var eq := {}
	if lv >= 0:
		for sl in [["helm", 7], ["armor", 8], ["pants", 9], ["gloves", 10], ["boots", 11]]:
			if MuCatalog.item_glb(sl[1], sn) != "":
				eq[sl[0]] = {"group": sl[1], "number": sn, "level": lv, "excellent": lv > 0}
	var holder := Node3D.new()
	add_child(holder)
	holder.position = Vector3(tx, gy, -ty)
	var m := MuCharacterModel.new()
	holder.add_child(m)
	m.build_player(cls, eq)
	m.play_idle(false)
	var cam := Camera3D.new(); cam.fov = 35.0; add_child(cam)
	cam.position = holder.position + Vector3(4.5, 6.0, 4.5)
	cam.look_at(holder.position + Vector3(0, 0.6, 0))
	cam.current = true
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/w_%d_%d.png" % [out, cls, lv])
	print("WORLDSHOT ok ", gy)
	get_tree().quit()
