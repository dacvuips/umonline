shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Làm vùng đổ bóng bớt đen: ánh sáng (gamma) thấp hơn shadow_floor được kéo lên gần mức đó,
// tỉ lệ shadow_lift (0 = như MU gốc). Chỗ sáng hơn shadow_floor giữ nguyên.
uniform float shadow_floor = 0.65;
uniform float shadow_lift = 0.75;
uniform float brightness = 1.45;
vec3 lift_shadow(vec3 l) {
	return l + max(vec3(shadow_floor) - l, vec3(0.0)) * shadow_lift;
}

// Địa hình Lorencia dựng lại đúng thuật toán RenderTerrainFace() của ZzzLodTerrain.cpp:
//  - 2 lớp tile (EncTerrain1.map: Layer1/Layer2) + alpha theo từng đỉnh
//  - Ô có alpha 4 góc >= 1 chỉ vẽ Layer2, ngược lại vẽ Layer1 rồi trộn Layer2 theo alpha
//  - Mỗi texture lặp lại sau (width / 64) ô, lọc GL_NEAREST như bản gốc
//  - Tile nước (index 5) trôi theo WaterMove + gió TerrainGrassWind
//  - Ánh sáng = TerrainLight.OZJ * (N . Sun + 0.5)  (đã bake vào màu đỉnh COLOR.rgb)

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D layers : filter_nearest, repeat_disable; // R = layer1, G = layer2, B = cờ "4 góc alpha = 1"

const float TILE_SCALE[14] = float[](0.25, 0.5, 0.25, 0.5, 0.5, 0.25, 0.5, 0.25, 0.5, 0.25, 0.25, 0.25, 0.5, 0.25);

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

vec3 sample_tile(int layer, vec2 tile_uv, float tile_x) {
	layer = clamp(layer, 0, 13);
	vec2 p = tile_uv * TILE_SCALE[layer];
	if (layer == 5) {
		// WaterMove = (WorldTime % 20000) * 0.00005  ; TerrainGrassWind * 0.002
		p.x += mod(TIME * 50.0, 1000.0) * 0.001;
		p.y += sin(TIME * 2.0 + tile_x * 5.0) * 10.0 * 0.002;
	}
	vec2 cell = vec2(float(layer % 4), float(layer / 4));
	vec2 auv = (cell + fract(p)) * 0.25;
	return textureLod(atlas, auv, 0.0).rgb;
}

void fragment() {
	vec2 tuv = UV; // toạ độ ô (x, y) liên tục
	ivec2 ti = clamp(ivec2(floor(tuv)), ivec2(0), ivec2(255));
	vec3 d = texelFetch(layers, ti, 0).rgb;
	int l1 = int(d.r * 255.0 + 0.5);
	int l2 = int(d.g * 255.0 + 0.5);
	bool all_opaque = d.b > 0.5;
	vec3 col;
	if (all_opaque) {
		col = sample_tile(l2, tuv, float(ti.x));
	} else {
		col = sample_tile(l1, tuv, float(ti.x));
		if (l2 != 255) {
			col = mix(col, sample_tile(l2, tuv, float(ti.x)), clamp(COLOR.a, 0.0, 1.0));
		}
	}
	ALBEDO = col * srgb_to_linear(lift_shadow(COLOR.rgb)) * brightness;
}
