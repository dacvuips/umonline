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

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

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
	ALBEDO = col * srgb_to_linear(lift_shadow(COLOR.rgb)) * brightness;
}
