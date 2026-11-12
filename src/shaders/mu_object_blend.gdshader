shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// "BlendMesh" của MU: mesh phát sáng cộng màu (EnableAlphaBlend = GL_ONE, GL_ONE)
// màu = texture * BlendMeshLight ; có thể trôi UV (BlendMeshTexCoordU/V) và chập chờn / nhịp sin

uniform sampler2D albedo_tex : source_color, filter_linear, repeat_enable;
uniform float blend_light = 1.0;
// Tốc độ trôi UV (vòng texture / giây). MU: BlendMeshTexCoordV = -(WorldTime % 1000) * 0.001 -> scroll_v = 1.0
// (dấu trừ trong MU = số dương ở đây; dấu cộng = số âm)
uniform float scroll_u = 0.0;
uniform float scroll_v = 0.0;
// BlendMeshLight = (rand % n + base) * 0.1 mỗi frame -> chập chờn giữa flicker_min..flicker_max
uniform float flicker_min = 1.0;
uniform float flicker_max = 1.0;
uniform float flicker_seed = 0.0;
// BlendMeshLight = sin(WorldTime * k) * amp + base  (k ms -> sine_freq = k * 1000 rad/giây)
uniform float sine_amp = 0.0;
uniform float sine_base = 1.0;
uniform float sine_freq = 2.0;
uniform float sine_phase = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	uv.x -= fract(TIME * scroll_u);
	uv.y -= fract(TIME * scroll_v);
	vec3 t = texture(albedo_tex, uv).rgb;
	float f;
	if (sine_amp > 0.0) {
		f = sin(TIME * sine_freq + sine_phase) * sine_amp + sine_base;
	} else {
		f = mix(flicker_min, flicker_max, hash(floor(TIME * 25.0) + flicker_seed * 13.0));
	}
	// MU nhân trong không gian gamma; renderer GL Compatibility cũng tính trong gamma -> nhân thẳng
	vec3 c = t * max(blend_light * f, 0.0);
	float a = clamp(max(max(c.r, c.g), c.b), 0.0, 1.0);
	if (a < 0.03) {
		discard;
	}
	ALPHA = a;
	ALBEDO = c / max(a, 0.001);
}
