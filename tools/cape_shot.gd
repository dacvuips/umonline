extends Node3D

## Chụp nhân vật mặc áo choàng / cánh ở các cấp khác nhau (kiểm tra ánh kim trên vải).
## godot --path MuGodot res://tools/cape_shot.tscn -- <thư_mục> <lớp> <nhóm:số[,nhóm:số]> [cấp,cấp]
## Ví dụ: ... -- C:/tmp/cape 4 12:130,12:49 0,15

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var cls := int(a[1])
	var capes: PackedStringArray = a[2].split(",")
	var levels: PackedStringArray = (a[3] if a.size() > 3 else "0,15").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(500, 600)
	MuCatalog.ensure_loaded()
	MuTerrain.change_world(1)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.9)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.15, -2.0)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.fov = 45.0
	cam.current = true
	await get_tree().create_timer(1.5).timeout
	for cp in capes:
		var gn := cp.split(":")
		for lv in levels:
			var m := MuCharacterModel.new()
			add_child(m)
			m.position = Vector3.ZERO
			m.rotation.y = PI   # quay lưng về camera để thấy áo choàng
			var eq := {"wings": {"group": int(gn[0]), "number": int(gn[1]), "level": int(lv), "excellent": false}}
			m.build_player(cls, eq)
			await get_tree().create_timer(1.6).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/cape_%s_%s_L%s.png" % [out, gn[0], gn[1], lv])
			print("[cape_shot] ", cp, " +", lv)
			m.queue_free()
			await get_tree().create_timer(0.2).timeout
	get_tree().quit()
