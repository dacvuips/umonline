shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled;

// Bóng chiếu thân hình của nhân vật / quái / NPC — BMD::RenderBodyShadow (ZzzBMD.cpp):
// từng đỉnh (đã skin) được ép xuống mặt đất và kéo xiên theo CalcShadowPosition:
//   dx' = dx + dz * (dx + sx) / (dz - sy)   (MU: sx = 2000, sy = 4000 ; đổi sang mét Godot: /100)
//   z   = mặt đất + 5
// Toạ độ MU (x, y, z lên) = Godot (x, -z, y) -> dx MU = dx Godot, dz MU = dy Godot.
// Lớp này được nối vào cuối chuỗi next_pass của mỗi mesh (MuCharacterModel._add_body_shadow).

// gốc nhân vật (mặt đất dưới chân), MuCharacterModel cập nhật mỗi khung hình
// Uniform THƯỜNG (mỗi nhân vật một vật liệu riêng) chứ không phải instance uniform: trên bản web instance uniform không tới được
// shader nên gốc bóng rơi về (0,0,0) -> trong thế giới (toạ độ lớn) bóng bị kéo xiên đi xa và chìm dưới mặt đất.
uniform vec3 shadow_origin = vec3(0.0);
uniform float shadow_alpha = 0.5;
uniform float shadow_sx = 20.0;
uniform float shadow_sy = 40.0;
uniform float ground_offset = 0.05;
// kích thước viewport bloom (MuModelBloom): bóng không phải nguồn bloom
global uniform vec2 mu_bloom_size;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 d = w - shadow_origin;
	float h = max(d.y, 0.0);
	d.x += h * (d.x + shadow_sx) / (h - shadow_sy);
	w = vec3(shadow_origin.x + d.x, shadow_origin.y + ground_offset, shadow_origin.z + d.z);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}

void fragment() {
	if (all(equal(VIEWPORT_SIZE, mu_bloom_size))) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = shadow_alpha;
}
