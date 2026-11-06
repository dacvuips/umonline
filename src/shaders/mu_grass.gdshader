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

// Cỏ mọc trên địa hình (TERRAIN_MAP_GRASS trong RenderTerrainFace):
// mỗi ô cỏ là một tấm đứng, 2 đỉnh trên lay theo gió
// TerrainGrassWind = sin(WorldTime*0.002 + x*5) * 10  (đơn vị MU, cộng vào trục Y của MU = -Z Godot)

uniform sampler2D grass_atlas : source_color, filter_nearest, repeat_enable;

varying vec3 v_light;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	// COLOR.a = 1 với 2 đỉnh trên, UV2.x = chỉ số cột x của ô (để tính gió)
	float wind = sin(TIME * 2.0 + UV2.x * 5.0) * 10.0 * 0.01;
	VERTEX.z -= wind * COLOR.a;
	v_light = srgb_to_linear(lift_shadow(COLOR.rgb));
}

void fragment() {
	// UV.x lặp theo chiều ngang; UV.y đã nằm trong vùng atlas của loại cỏ tương ứng
	vec4 t = texture(grass_atlas, UV);
	if (t.a <= 0.25) {
		discard;
	}
	ALBEDO = t.rgb * v_light * brightness;
}
