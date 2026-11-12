extends Node3D

## Đếm điểm ảnh bóng (đen thuần) khi chụp nhìn từ trên xuống: godot --path MuMain res://tools/shadow_test.tscn -- <thư_mục> <lớp> <bộ> <cấp|-1 = trần>
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]; var cls := int(a[1]); var sn := int(a[2]); var lv := int(a[3])
	DirAccess.make_dir_recursive_absolute(out)
	MuCatalog.ensure_loaded()
	MuTerrain.change_world(1)
	var vp := SubViewport.new()
	vp.size = Vector2i(500, 500)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	var cam := Camera3D.new(); cam.fov = 40.0; vp.add_child(cam)
	cam.position = Vector3(0, 5.0, 4.0); cam.look_at(Vector3(-0.5, 0.0, 0.0)); cam.current = true
	var eq := {}
	if lv >= 0:
		for sl in [["helm", 7], ["armor", 8], ["pants", 9], ["gloves", 10], ["boots", 11]]:
			if MuCatalog.item_glb(sl[1], sn) != "":
				eq[sl[0]] = {"group": sl[1], "number": sn, "level": lv, "excellent": lv > 0}
	var m := MuCharacterModel.new()
	vp.add_child(m)
	m.build_player(cls, eq)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var dark := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.2 and c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				dark += 1
	img.save_png("%s/s_%d_%d.png" % [out, cls, lv])
	print("SHADOWPIX cls=%d set=%d lv=%d dark=%d" % [cls, sn, lv, dark])
	get_tree().quit()
