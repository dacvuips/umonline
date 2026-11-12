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

// Địa hình MU dùng chung cho mọi bản đồ (terrain.mumap), giống RenderTerrainFace() của ZzzLodTerrain.cpp:
//  - tile 0..13 (TileGrass01..TileRock07) + 14..29 (ExtTile01..16), lọc GL_NEAREST
//  - texture lặp sau (width / 64) ô ; tile nước (5) trôi theo WaterMove + gió
//  - ô có alpha 4 góc >= 1 chỉ vẽ Layer2 ; ngược lại Layer1 rồi trộn Layer2 theo alpha
//  - ánh sáng = TerrainLight * clamp(N·Sun + 0.5) (màu đỉnh)

uniform sampler2DArray tiles : source_color, filter_nearest, repeat_enable;
uniform sampler2D layers : filter_nearest, repeat_disable;
uniform float tile_scale[30];
uniform int tile_count = 30;
uniform float water_speed = 0.05;


vec3 sample_tile(int layer, vec2 tile_uv, float tile_x) {
	layer = clamp(layer, 0, tile_count - 1);
	vec2 p = tile_uv * tile_scale[layer];
	if (layer == 5) {
		p.x += fract(TIME * water_speed);
		p.y += sin(TIME * 2.0 + tile_x * 5.0) * 10.0 * 0.002;
	}
	return textureLod(tiles, vec3(fract(p), float(layer)), 0.0).rgb;
}

void fragment() {
	vec2 tuv = UV;
	ivec2 ti = clamp(ivec2(floor(tuv)), ivec2(0), ivec2(255));
	vec3 d = texelFetch(layers, ti, 0).rgb;
	int l1 = int(d.r * 255.0 + 0.5);
	int l2 = int(d.g * 255.0 + 0.5);
	vec3 col;
	if (d.b > 0.5) {
		col = sample_tile(l2, tuv, float(ti.x));
	} else {
		col = sample_tile(l1, tuv, float(ti.x));
		if (l2 != 255) {
			col = mix(col, sample_tile(l2, tuv, float(ti.x)), clamp(COLOR.a, 0.0, 1.0));
		}
	}
	ALBEDO = col * mu_light(COLOR.rgb);
}
