extends SceneTree

## Chạy scene chính ở một bản đồ khác Lorencia (headless) để bắt lỗi runtime.
##   Godot --headless --path . --script res://tools/test_run_world.gd -- 9

var _frames := 0

func _initialize() -> void:
	var w := 9
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		w = int(args[0])
	MuTerrain.world_id = w
	change_scene_to_file("res://src/scenes/Main.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	return _frames > 400
