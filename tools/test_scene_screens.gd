extends SceneTree
## Chụp các màn đăng nhập / chọn máy chủ / chọn & tạo nhân vật có nền 3D:
## godot --path . --resolution 1280x720 -s tools/test_scene_screens.gd -- <out_prefix>
const SCENES := ["LoginScene", "ServerSelectScene", "CharacterSelectScene", "CharacterCreateScene"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://screen"
	for s in SCENES:
		var inst: Node = load("res://src/scenes/%s.tscn" % s).instantiate()
		root.add_child(inst)
		await create_timer(3.0).timeout
		await process_frame
		root.get_texture().get_image().save_png("%s_%s.png" % [out, s])
		print("SNAP ", s, " bg=", inst.get_node_or_null("SceneBackground3D") != null)
		inst.queue_free()
		await process_frame
		await process_frame
	print("MuTerrain.world_id sau cùng = ", MuTerrain.world_id)
	quit(0)
