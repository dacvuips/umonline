shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Vật trang trí đồ +15 (Data/Item/class15_*.bmd) — RenderModelWithoutStyle (ZzzObject.cpp), mesh 0 vẽ 3 lớp CỘNG:
//   fLight = 0.8 - |sin(t*1.8) * 0.5|
//   1) texture của mesh, sáng fLight - 0.1
//   2) Item/rgb_mix, U lệch |sin(t*0.5)|, sáng fLight - 0.3
//   3) CHROME4 (Effect/Chrome02, clamp) theo pháp tuyến
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rgb_mix_tex : source_color, filter_linear, repeat_enable;
uniform sampler2D chrome2_tex : source_color, filter_nearest, repeat_disable;

varying vec3 v_nmu;

void vertex() {
	vec3 nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_nmu = vec3(nw.x, -nw.z, nw.y);
}

void fragment() {
	float f = 0.8 - abs(sin(TIME * 1.8) * 0.5);
	vec3 c = texture(albedo_tex, UV).rgb * pow(max(f - 0.1, 0.0), 2.2);
	c += texture(rgb_mix_tex, UV + vec2(abs(sin(TIME * 0.5)), 0.0)).rgb * pow(max(f - 0.3, 0.0), 2.2);
	vec3 n = normalize(v_nmu);
	float wave = mod(TIME * 1000.0, 10000.0) * 0.0001;
	vec3 L = vec3(cos(TIME), sin(TIME * 2.0), 1.0);
	float cx = dot(n, L);
	vec2 uv = vec2(cx + n.y * 0.5 + L.y * 3.0, 1.0 - cx - n.z * 0.5 - wave * 3.0);
	c += texture(chrome2_tex, uv).rgb;
	ALBEDO = c;
}
