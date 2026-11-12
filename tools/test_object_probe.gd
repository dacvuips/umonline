extends SceneTree
## Chẩn đoán ánh sáng vật thể: thay dòng v_light của mu_object bằng các biến thể rồi chụp
## godot --path . --resolution 1280x720 -s tools/test_object_probe.gd -- <out_prefix> <x> <y>
var _out := ""
var _frames := 0
const LINE := "	v_light = mu_body_light(textureLod(terrain_light, luv, 0.0).rgb * light_scale, (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz) + extra_light;"
const VARIANTS := {
	"cur": LINE,
	"one": "	v_light = vec3(1.0);",
	"body_only": "	v_light = textureLod(terrain_light, luv, 0.0).rgb;",
	"lum_only": "	v_light = vec3(max(dot(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz), vec3(0.0, 0.0, 1.5)) * 0.8 + 0.4, 0.2) / 1.6);",
	"lum_flip": "	v_light = vec3(max(dot(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz), vec3(0.0, 0.0, -1.5)) * 0.8 + 0.4, 0.2) / 1.6);",
}
var _names: Array = VARIANTS.keys()
var _shader: Shader
var _base := ""

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	MuTerrain.change_world(1, Vector2i(int(a[1]), int(a[2])))
	_shader = load("res://src/shaders/mu_object.gdshader")
	_base = _shader.code
	change_scene_to_file("res://src/scenes/Main.tscn")

func _process(_d: float) -> bool:
	_frames += 1
	if _frames >= 200 and (_frames - 200) % 30 == 0:
		var idx := (_frames - 200) / 30
		if idx > 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [_out, _names[idx - 1]])
		if idx >= _names.size():
			_shader.code = _base
			return true
		_shader.code = _base.replace(LINE, VARIANTS[_names[idx]])
	return false
