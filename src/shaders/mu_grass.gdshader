shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Ánh sáng địa hình đúng công thức client MU (ZzzLodTerrain.cpp): màu = texture * min(TerrainLight * light_scale, 1),
// light_scale = 1. Đối chiếu ảnh chụp client IGCN: quảng trường Lorencia ~1.1, trong quán rượu ~0.6-0.7 (client làm
// tối trong nhà bằng cơ chế không có trong TerrainLight) -> giữ 1 như mã nguồn.
// Tính thẳng trong gamma: renderer GL Compatibility của dự án KHÔNG đổi sang linear (128 * 0.5 = 64), nên không
// được đổi ánh sáng sang linear (sRGB -> linear / mũ 2.2) — lỗi cũ đó làm mọi cảnh tối hơn client.
uniform float light_scale = 1.0;
vec3 mu_light(vec3 l) {
	return min(l * light_scale, vec3(1.0));
}

// Cỏ mọc trên địa hình (TERRAIN_MAP_GRASS):
// mỗi khóm cỏ gồm các tấm đan chéo (crossed quads), 2 đỉnh trên lay theo gió
// TerrainGrassWind = sin(WorldTime*0.002 + x*5)

uniform sampler2D grass_atlas : source_color, filter_nearest, repeat_enable;

varying vec3 v_light;


void vertex() {
	// COLOR.a = 1 với 2 đỉnh trên, UV2.x = toạ độ x của đám cỏ (để tính gió)
	float wind_z = sin(TIME * 2.0 + UV2.x * 5.0) * 10.0 * 0.01;
	float wind_x = cos(TIME * 1.6 + UV2.x * 3.5) * 4.0 * 0.01;
	VERTEX.z -= wind_z * COLOR.a;
	VERTEX.x += wind_x * COLOR.a;
	v_light = mu_light(COLOR.rgb);
}

void fragment() {
	// UV.x lặp theo chiều ngang; UV.y đã nằm trong vùng atlas của loại cỏ tương ứng
	vec4 t = texture(grass_atlas, UV);
	if (t.a <= 0.25) {
		discard;
	}
	ALBEDO = t.rgb * v_light;
}
