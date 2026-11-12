extends SceneTree

## Chạy bản đồ N và chụp màn hình sau vài giây:  Godot --path . --script res://tools/test_snap_world.gd -- 4 out.png
var _frames := 0
var _out := "user://snap.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	MuTerrain.world_id = int(args[0]) if args.size() > 0 else 4
	if args.size() > 1:
		_out = args[1]
	change_scene_to_file("res://src/scenes/Main.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 240:
		root.get_texture().get_image().save_png(_out)
		return true
	return false
