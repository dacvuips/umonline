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

// Cỏ địa hình cho mọi bản đồ: UV2.x = cột x (gió), UV2.y = loại cỏ (TileGrass01..03.tga)
uniform sampler2DArray grass : source_color, filter_nearest, repeat_enable;

varying vec3 v_light;
varying float v_layer;


void vertex() {
	float wind_z = sin(TIME * 2.0 + UV2.x * 5.0) * 10.0 * 0.01;
	float wind_x = cos(TIME * 1.6 + UV2.x * 3.5) * 4.0 * 0.01;
	VERTEX.z -= wind_z * COLOR.a;
	VERTEX.x += wind_x * COLOR.a;
	v_light = mu_light(COLOR.rgb);
	v_layer = UV2.y;
}

void fragment() {
	vec4 t = texture(grass, vec3(fract(UV.x), clamp(UV.y, 0.0, 1.0), floor(v_layer + 0.5)));
	if (t.a <= 0.25) {
		discard;
	}
	ALBEDO = t.rgb * v_light;
}
