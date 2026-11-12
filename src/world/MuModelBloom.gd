extends Node
class_name MuModelBloom

## Bloom của client gốc (Render/Renderer/SdlGpuPostProcessing.cpp + Data/Render/Look.json):
##  - nguồn bloom = CHỈ các lớp vẽ cộng sáng (BloomSource.h: blend cộng) — chrome / glow theo cấp / excellent /
##    mesh Bright của đồ, thú cưỡi, quái. Thân model không loá.
##  - 5 tầng: tầng 0 = 1/2 màn hình, mỗi tầng sau 1/2 tầng trước (lọc dual: xuống 5 điểm, lên 8 điểm)
##  - tầng rộng góp ít hơn: trọng số 1, f, f^2... (bloom.levelFalloff = 0.6), chia tổng trọng số * bloom.strength
##  - trộn "screen" lên ảnh cảnh: 1 - (1 - cảnh) * (1 - glow)
## Bản Godot: một SubViewport (1/2 màn hình) chung World3D, camera chỉ vẽ layer model (MuModel.BLOOM_LAYER_MASK);
## trong viewport đó shader thân model / bóng đổ nhận ra qua global uniform mu_bloom_size và vẽ đen / bỏ,
## chỉ còn lớp cộng sáng. Không đụng Environment glow sẵn có của cảnh.

const LEVELS := 5
const STRENGTH := 1.0
const FALLOFF := 0.6

const DOWN_SHADER := """
shader_type canvas_item;
uniform sampler2D src : filter_linear, repeat_disable;
uniform vec2 texel;
void fragment() {
	vec2 h = texel * 0.5;
	vec3 s = texture(src, UV).rgb * 4.0;
	s += texture(src, UV - h).rgb;
	s += texture(src, UV + h).rgb;
	s += texture(src, UV + vec2(h.x, -h.y)).rgb;
	s += texture(src, UV - vec2(h.x, -h.y)).rgb;
	COLOR = vec4(s / 8.0, 1.0);
}
"""

const COMPOSITE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D l0 : filter_linear, repeat_disable;
uniform sampler2D l1 : filter_linear, repeat_disable;
uniform sampler2D l2 : filter_linear, repeat_disable;
uniform sampler2D l3 : filter_linear, repeat_disable;
uniform sampler2D l4 : filter_linear, repeat_disable;
uniform vec2 t0; uniform vec2 t1; uniform vec2 t2; uniform vec2 t3; uniform vec2 t4;
uniform float strength = 1.0;
uniform float falloff = 0.6;

vec3 up(sampler2D t, vec2 uv, vec2 tx) {
	vec2 h = tx * 0.5;
	vec3 s = texture(t, uv + vec2(-h.x * 2.0, 0.0)).rgb;
	s += texture(t, uv + vec2(h.x * 2.0, 0.0)).rgb;
	s += texture(t, uv + vec2(0.0, -h.y * 2.0)).rgb;
	s += texture(t, uv + vec2(0.0, h.y * 2.0)).rgb;
	s += texture(t, uv + vec2(-h.x, -h.y)).rgb * 2.0;
	s += texture(t, uv + vec2(h.x, -h.y)).rgb * 2.0;
	s += texture(t, uv + vec2(-h.x, h.y)).rgb * 2.0;
	s += texture(t, uv + vec2(h.x, h.y)).rgb * 2.0;
	return s / 12.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float w = 1.0;
	float sum = 0.0;
	vec3 g = vec3(0.0);
	g += up(l0, uv, t0) * w; sum += w; w *= falloff;
	g += up(l1, uv, t1) * w; sum += w; w *= falloff;
	g += up(l2, uv, t2) * w; sum += w; w *= falloff;
	g += up(l3, uv, t3) * w; sum += w; w *= falloff;
	g += up(l4, uv, t4) * w; sum += w;
	g = clamp(g * (strength / sum), 0.0, 1.0);
	vec3 s = texture(screen_tex, uv).rgb;
	COLOR = vec4(vec3(1.0) - (vec3(1.0) - s) * (vec3(1.0) - g), 1.0);
}
"""

var _src_vp: SubViewport
var _cam: Camera3D
var _levels: Array[SubViewport] = []
var _down_mats: Array[ShaderMaterial] = []
var _composite: ShaderMaterial
var _size := Vector2i.ZERO

func _ready() -> void:
	process_priority = 1000   # sau MuCamera: chép vị trí camera của khung hình này
	_src_vp = SubViewport.new()
	_src_vp.name = "BloomSource"
	_src_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_src_vp.transparent_bg = false
	_src_vp.msaa_3d = Viewport.MSAA_DISABLED
	_src_vp.positional_shadow_atlas_size = 0
	add_child(_src_vp)
	_cam = Camera3D.new()
	_cam.cull_mask = MuModel.BLOOM_LAYER_MASK
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	_cam.environment = env
	_src_vp.add_child(_cam)

	var down_shader := Shader.new()
	down_shader.code = DOWN_SHADER
	var prev: Texture2D = _src_vp.get_texture()
	_levels.append(_src_vp)
	for i in range(1, LEVELS):
		var vp := SubViewport.new()
		vp.name = "BloomLevel%d" % i
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m := ShaderMaterial.new()
		m.shader = down_shader
		m.set_shader_parameter("src", prev)
		rect.material = m
		vp.add_child(rect)
		_levels.append(vp)
		_down_mats.append(m)
		prev = vp.get_texture()

	var layer := CanvasLayer.new()
	layer.name = "BloomComposite"
	layer.layer = -1   # trên cảnh 3D, dưới HUD
	add_child(layer)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cs := Shader.new()
	cs.code = COMPOSITE_SHADER
	_composite = ShaderMaterial.new()
	_composite.shader = cs
	_composite.set_shader_parameter("strength", STRENGTH)
	_composite.set_shader_parameter("falloff", FALLOFF)
	for i in LEVELS:
		_composite.set_shader_parameter("l%d" % i, _levels[i].get_texture())
	cr.material = _composite
	layer.add_child(cr)
	_resize()

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("mu_bloom_size", Vector2(-1, -1))

func _resize() -> void:
	var win := get_viewport().get_window()
	var full := win.size if win else Vector2i(1280, 720)
	if full == _size:
		return
	_size = full
	var s := Vector2i(maxi(full.x / 2, 1), maxi(full.y / 2, 1))
	for i in LEVELS:
		_levels[i].size = s
		_composite.set_shader_parameter("t%d" % i, Vector2(1.0 / s.x, 1.0 / s.y))
		if i > 0:
			# texel của tầng trước (nguồn của lần lọc xuống)
			var ps: Vector2i = _levels[i - 1].size
			_down_mats[i - 1].set_shader_parameter("texel", Vector2(1.0 / ps.x, 1.0 / ps.y))
		s = Vector2i(maxi(s.x / 2, 1), maxi(s.y / 2, 1))
	RenderingServer.global_shader_parameter_set("mu_bloom_size", Vector2(_levels[0].size))

func _process(_delta: float) -> void:
	_resize()
	var main := get_viewport().get_camera_3d()
	if main == null:
		return
	_cam.global_transform = main.global_transform
	_cam.projection = main.projection
	_cam.fov = main.fov
	_cam.size = main.size
	_cam.near = main.near
	_cam.far = main.far
	_cam.keep_aspect = main.keep_aspect
	_cam.h_offset = main.h_offset
	_cam.v_offset = main.v_offset
	_cam.current = true
