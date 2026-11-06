shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Làm vùng đổ bóng bớt đen: ánh sáng (gamma) thấp hơn shadow_floor được kéo lên gần mức đó,
// tỉ lệ shadow_lift (0 = như MU gốc). Chỗ sáng hơn shadow_floor giữ nguyên.
uniform float shadow_floor = 0.58;
uniform float shadow_lift = 0.68;
uniform float brightness = 1.15;
vec3 lift_shadow(vec3 l) {
	return l + max(vec3(shadow_floor) - l, vec3(0.0)) * shadow_lift;
}

// Cỏ địa hình cho mọi bản đồ: UV2.x = cột x (gió), UV2.y = loại cỏ (TileGrass01..03.tga)
uniform sampler2DArray grass : source_color, filter_nearest, repeat_enable;

varying vec3 v_light;
varying float v_layer;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	float wind = sin(TIME * 2.0 + UV2.x * 5.0) * 10.0 * 0.01;
	VERTEX.z -= wind * COLOR.a;
	v_light = srgb_to_linear(lift_shadow(COLOR.rgb));
	v_layer = UV2.y;
}

void fragment() {
	vec4 t = texture(grass, vec3(fract(UV.x), clamp(UV.y, 0.0, 1.0), floor(v_layer + 0.5)));
	if (t.a <= 0.25) {
		discard;
	}
	ALBEDO = t.rgb * v_light * brightness;
}
