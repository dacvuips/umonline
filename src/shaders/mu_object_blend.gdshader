shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// "BlendMesh" của MU: mesh phát sáng cộng màu (EnableAlphaBlend = GL_ONE, GL_ONE)
// màu = texture * BlendMeshLight ; có thể trôi UV (BlendMeshTexCoordV) và chập chờn (Random)

uniform sampler2D albedo_tex : source_color, filter_linear, repeat_enable;
uniform float blend_light = 1.0;
// BlendMeshTexCoordV = -(WorldTime % 1000) * 0.001  -> tốc độ 1 vòng / giây
uniform float scroll_v = 0.0;
// BlendMeshLight = (rand % n + base) * 0.1 mỗi frame -> chập chờn giữa flicker_min..flicker_max
uniform float flicker_min = 1.0;
uniform float flicker_max = 1.0;
uniform float flicker_seed = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	uv.y += -fract(TIME) * scroll_v;
	vec3 t = texture(albedo_tex, uv).rgb;
	float f = mix(flicker_min, flicker_max, hash(floor(TIME * 25.0) + flicker_seed * 13.0));
	// MU nhân trong không gian gamma -> đổi hệ số sang tuyến tính
	ALBEDO = t * pow(max(blend_light * f, 0.0), 2.2);
	ALPHA = 1.0;
}
