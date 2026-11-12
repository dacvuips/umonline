extends SceneTree
## Chụp nền 3D màn login/chọn nhân vật: godot --path . -s tools/test_scene_bg.gd -- <world> <out_prefix> [times...]
const Bg = preload("res://src/scenes/MuSceneBackground3D.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 74
	var out: String = args[1] if args.size() > 1 else "user://bg"
	var times: Array = []
	for i in range(2, args.size()):
		times.append(float(args[i]))
	if times.is_empty():
		times = [1.0]
	root.size = Vector2i(1280, 720)
	var bg = Bg.new()
	bg.world = w
	root.add_child(bg)
	var t0 := 0.0
	for t in times:
		await create_timer(t - t0).timeout
		t0 = t
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s_%d_%05.1f.png" % [out, w, t])
		print("SNAP ", t)
	quit(0)
