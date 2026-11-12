extends SceneTree
## Chẩn đoán độ sáng địa hình Lorencia: thay shader bằng các biến thể rồi chụp
## godot --path . --resolution 1280x720 -s tools/test_terrain_probe.gd -- <out_prefix> [x y]
var _out := ""
var _frames := 0
var _variant := 0
const VARIANTS := {
	"orig": "",
	"tex": "ALBEDO = col;",
	"light_raw": "ALBEDO = COLOR.rgb;",
	"mu_exact": "ALBEDO = col * COLOR.rgb;",
}
var _names: Array = VARIANTS.keys()
var _base_code := ""
var _mat: ShaderMaterial

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	if a.size() >= 3:
		MuTerrain.change_world(1, Vector2i(int(a[1]), int(a[2])))
	else:
		MuTerrain.world_id = 1
	change_scene_to_file("res://src/scenes/Main.tscn")

func _find_mat(n: Node) -> ShaderMaterial:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m = (n as MeshInstance3D).mesh.surface_get_material(0)
		if m is ShaderMaterial and m.shader and m.shader.code.contains("sample_tile"):
			return m
	for c in n.get_children():
		var r := _find_mat(c)
		if r:
			return r
	return null

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 200:
		_mat = _find_mat(root)
		_base_code = _mat.shader.code
	if _frames >= 200 and (_frames - 200) % 30 == 0:
		var idx := (_frames - 200) / 30
		if idx > 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [_out, _names[idx - 1]])
		if idx >= _names.size():
			return true
		var repl: String = VARIANTS[_names[idx]]
		var sh := Shader.new()
		if repl == "":
			sh.code = _base_code
		else:
			var i := _base_code.rfind("ALBEDO =")
			var j := _base_code.find(";", i)
			sh.code = _base_code.substr(0, i) + repl + _base_code.substr(j + 1)
		_mat.shader = sh
	return false
