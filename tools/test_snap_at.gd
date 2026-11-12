extends SceneTree
## Chụp bản đồ tại ô cho trước: godot --path . --resolution 1280x720 -s tools/test_snap_at.gd -- <world> <x> <y> <out.png>
var _frames := 0
var _out := ""

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[3]
	MuTerrain.change_world(int(a[0]), Vector2i(int(a[1]), int(a[2])))
	change_scene_to_file("res://src/scenes/Main.tscn")

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 240:
		root.get_texture().get_image().save_png(_out)
		return true
	return false
