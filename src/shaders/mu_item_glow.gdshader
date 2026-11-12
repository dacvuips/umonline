shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Lớp phát sáng của đồ theo cấp (RenderPartObjectEffect trong ZzzObject.cpp):
//   +7, +8  : RENDER_CHROME  | BRIGHT  (Chrome01, màu glow)
//   +9, +10 : + RENDER_METAL | BRIGHT  (Shiny01, màu glow)
//   +11, +12: + RENDER_CHROME2         (Chrome02, màu shine)
//   +13..15 : RENDER_CHROME4 thay CHROME2
//   Excellent: RENDER_TEXTURE | BRIGHT, màu (L, 0.3L, 1-L), L = sin(t*2)*0.5+0.5
// Toạ độ chrome lấy từ normal thế giới theo hệ MU: n_mu = (x, -z, y) của Godot

uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D chrome_tex : filter_linear, repeat_enable;
// ZzzOpenData.cpp: Chrome02/03 = GL_NEAREST + GL_CLAMP_TO_EDGE, Shiny01 = GL_CLAMP_TO_EDGE
// (KHÔNG lặp: toạ độ chạy ra ngoài [0,1] chỉ lấy màu viền -> vệt sáng quét qua rồi tắt, không phủ kín đồ)
uniform sampler2D chrome2_tex : filter_nearest, repeat_disable;
uniform sampler2D chrome3_tex : filter_nearest, repeat_disable;
uniform sampler2D shiny_tex : filter_linear, repeat_disable;
// shine (+11..) và excellent nhân BodyLight hiện tại = 0.9 * ánh sáng địa hình (PartObjectColor2)
uniform sampler2D terrain_light : source_color, filter_linear, repeat_disable;
uniform float fixed_light = -1.0;
uniform float brightness = 1.0;
uniform float alpha_cut = -1.0;
// Độ mạnh lớp phủ theo cấp (1 = như client gốc)
uniform float glow_gain_7 = 1.0;    // +7 .. +10
uniform float glow_gain_11 = 1.0;   // +11, +12
uniform float glow_gain_13 = 1;   // +13 .. +15
uniform int level = 0;
uniform bool excellent = false;
uniform vec3 glow_color = vec3(1.0, 0.5, 0.0);
uniform vec3 shine_color = vec3(1.0);
// Ancient (set): RENDER_CHROME3 | BRIGHT màu ancientColor, alpha = sin(t*1)*0.5+0.4
uniform bool ancient = false;
uniform vec3 ancient_color = vec3(0.0, 0.5, 1.0);

varying vec3 v_nmu;
varying vec3 v_body;

void vertex() {
	vec3 tl;
	if (fixed_light >= 0.0) {
		tl = vec3(fixed_light);
	} else {
		vec3 origin = NODE_POSITION_WORLD;
		tl = textureLod(terrain_light, vec2(origin.x + 0.5, -origin.z + 0.5) / 256.0, 0.0).rgb;
	}
	v_body = tl * 0.9;   // PartObjectColor2: 0.9 * ánh sáng, giá trị gamma
	vec3 nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_nmu = vec3(nw.x, -nw.z, nw.y);
}

// MU cộng các lớp này (ONE, ONE) trên bộ đệm 8-bit gamma: texture, màu và ánh sáng đều là giá trị gamma.
// Godot cộng trong bộ đệm HDR tuyến tính -> cộng thẳng giá trị gamma (không đổi sang tuyến tính) để
// nhiều lớp cam chồng nhau ngả vàng / trắng như client gốc thay vì đỏ rực.
vec3 lin(vec3 c) { return max(c, vec3(0.0)); }

void fragment() {
	vec4 base = texture(albedo_tex, UV);
	if (base.a <= alpha_cut) {
		discard;
	}
	vec3 n = normalize(v_nmu);
	float ms = TIME * 1000.0;
	float wave = mod(ms, 10000.0) * 0.0001;
	float wave2 = mod(ms, 5000.0) * 0.00024 - 0.4;
	vec3 col = vec3(0.0);
	float gain = level >= 13 ? glow_gain_13 : (level >= 11 ? glow_gain_11 : glow_gain_7);
	if (level >= 7) {
		vec2 uv = vec2(n.z * 0.5 + wave, n.y * 0.5 + wave * 2.0);
		col += texture(chrome_tex, uv).rgb * lin(glow_color) * gain;
	}
	if (level >= 9) {
		vec2 uv = vec2(n.z * 0.5 + 0.2, n.y * 0.5 + 0.5);
		col += texture(shiny_tex, uv).rgb * lin(glow_color) * gain;
	}
	// Chrome02 cộng thẳng như client gốc (bộ đệm gamma)
	if (level >= 11 && level < 13) {
		vec2 uv = vec2((n.z + n.x) * 0.8 + wave2 * 2.0, (n.y + n.x) + wave2 * 3.0);
		col += texture(chrome2_tex, uv).rgb * lin(shine_color * v_body) * gain;
	}
	if (level >= 13) {
		// RENDER_CHROME4 (ZzzBMD.cpp): toạ độ chạy ra ngoài [0,1] theo thời gian (L.y * 3) -> CLAMP lấy mép đen
		// -> vệt sáng quét qua rồi tắt, không sáng liên tục
		vec3 L = vec3(cos(TIME), sin(TIME * 2.0), 1.0);
		float cx = dot(n, L);
		vec2 uv = vec2(cx + n.y * 0.5 + L.y * 3.0, 1.0 - cx - (n.z * 0.5 + wave * 3.0));
		col += texture(chrome2_tex, uv).rgb * lin(shine_color * v_body) * gain;
	}
	if (ancient && !excellent) {
		float aa = clamp(sin(TIME) * 0.5 + 0.4, 0.0, 1.0);
		vec2 uv = vec2((n.z + n.x) * 0.8 + wave2 * 2.0, (n.y + n.x) + wave2 * 3.0);
		// RENDER_CHROME3: Chrome03, toạ độ = dot(n, LightVector), 1 - dot
		float d = dot(n, vec3(0.0, -0.1, -0.8));   // LightVector của ZzzBMD.cpp
		col += texture(chrome3_tex, vec2(d, 1.0 - d)).rgb * lin(ancient_color) * aa;
	}
	if (excellent) {
		float l = sin(TIME * 2.0) * 0.5 + 0.5;
		col += base.rgb * lin(vec3(l, l * 0.3, 1.0 - l));
	}
	// Alpha = độ sáng (rồi bù màu để kết quả cộng không đổi): ALPHA = 1.0 làm phần đen của lớp phủ thành
	// khung đen đặc khi vẽ trên nền trong suốt (SubViewport chọn / tạo nhân vật, ảnh đồ)
	float ga = clamp(max(max(col.r, col.g), col.b), 0.0, 1.0);
	if (ga < 0.01) {
		discard;
	}
	ALPHA = ga;
	ALBEDO = col / max(ga, 0.001);
}
