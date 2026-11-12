extends SceneTree

## Đặt vài quái cạnh nhân vật, cho chúng ra đòn và chụp màn hình (cần cửa sổ, không headless):
##   Godot --path . --script res://tools/test_snap_monsters.gd -- <world> <out.png> <số quái,...> [đòn: số quái]
var _frames := 0
var _out := "user://monsters.png"
var _ids: Array = [40, 35, 37]
var _attacker := 37
var _mons: Array = []

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	MuTerrain.world_id = int(a[0]) if a.size() > 0 else 5
	if a.size() > 1:
		_out = a[1]
	if a.size() > 2:
		_ids = Array(a[2].split(",")).map(func(x): return int(x))
	if a.size() > 3:
		_attacker = int(a[3])
	change_scene_to_file("res://src/scenes/Main.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	var player := root.get_tree().get_first_node_in_group("Player") if _frames > 5 else null
	if _frames == 60 and player:
		var MonsterScript = load("res://src/entities/MuMonster.gd")
		var i := 0
		for id in _ids:
			var m = MonsterScript.new()
			m.monster_id = id
			m.monster_name = str(MuCatalog.monster_stats(id).get("name", "x"))
			m.grid_x = player.grid_x + (6 if _attacker == -2 else 2) + i * 2
			m.grid_y = player.grid_y + 1 - i
			m.ai_enabled = _attacker == -2
			player.get_parent().add_child(m)
			_mons.append(m)
			i += 1
	if _frames in [150, 165, 180] and player:
		for m in _mons:
			if m.monster_id == _attacker or _attacker < 0:
				m._attack(player)
	if _frames == 186:
		root.get_texture().get_image().save_png(_out)
		return true
	return false
