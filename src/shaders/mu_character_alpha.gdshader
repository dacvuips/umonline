shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

// Biến thể texture 32-bit (Components == 4): trộn alpha + bỏ điểm alpha <= 0.25, vẫn ghi depth.

// "Enhanced lighting" của client gốc (shaders/skinned_lit.frag.hlsl + Data/Render/Look.json):
//   objectLight = BodyLight = ánh sáng địa hình * màu theo cấp
//   diffuse  = rolloff(objectLight * max(dot(n, L) * 1.0 + 0.3, 0.15), knee 0.8)
//   rim      = 0.4 * (1 - |dot(n, v)|)^3 * objectLight          (viền sáng)
//   specular = specular_đồ (material.specular, vd 0.6) * pow(dot(n, h), 32) * objectLight  (độ BÓNG)
//   màu = texture * diffuse + rim + specular   (tính trong không gian gamma như GPU của client)
// L = (0, -1.5, 0) của MU * sun 0.8 (LightMood) = (0, 0, 1.2) trong Godot. Tính trong gamma (renderer GL Compatibility
// không đổi sang linear): không đổi ánh sáng / kết quả qua sRGB<->linear.

uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain_light : source_color, filter_linear, repeat_disable;
uniform float alpha_cut = -1.0;
uniform vec3 body_tint = vec3(1.0);
// Tăng sáng thân đồ (đồ +7 trở lên, MuModel.LEVEL_BODY_BRIGHT_*): nhân vào màu đồ sau khi tính ánh sáng
uniform float body_boost = 1.0;
// +3..+6: BodyLight = tint * g_Luminosity, g_Luminosity = sin(WorldTime*0.004)*0.15+0.6 (nhấp nháy)
uniform float tint_pulse = 0.0;
uniform float fixed_light = -1.0; // >= 0: bỏ ánh sáng địa hình (UI / xem trước)
uniform float specular = 0.0;
// độ sáng chung của nhân vật / đồ (chỉnh ở MuModel.BRIGHTNESS)
uniform float brightness = 1.0;     // 1 = như client gốc
uniform float diffuse_scale = 0.6;
uniform float ambient = 0.85;
uniform float diffuse_floor = 0.8;
uniform float knee = 0.8;
// Tăng sáng vượt màu texture gốc (sáng hơn client gốc): nhân sau bước nén sáng, rồi nén mềm phần vượt
// gain_knee để màu sáng sẵn (giáp đỏ / vàng) không bị cháy. 1.0 = như gốc.
uniform float body_gain = 1.0;
uniform float gain_knee = 0.75;
vec3 gain_shoulder(vec3 c) {
	vec3 g = c * body_gain;
	float r = 1.0 - gain_knee;
	vec3 over = max(g - vec3(gain_knee), vec3(0.0));
	return mix(g, vec3(gain_knee) + r * (vec3(1.0) - exp(-over / r)), step(vec3(gain_knee), g));
}
uniform float rim_strength = 0.4;
uniform float rim_power = 3.0;
uniform float specular_power = 32.0;
// Xem mu_character.gdshader: nâng bóng như nền + đường cong sRGB chuẩn thay cho pow 2.2
uniform float shadow_floor = 0.65;
uniform float shadow_lift = 0.75;
// viewport bloom (MuModelBloom): thân vẽ đen, chỉ lớp cộng sáng là nguồn bloom
global uniform vec2 mu_bloom_size;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
vec3 linear_to_srgb(vec3 c) {
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - vec3(0.055), c * 12.92, lessThan(c, vec3(0.0031308)));
}
vec3 lift_shadow(vec3 l) {
	return l + max(vec3(shadow_floor) - l, vec3(0.0)) * shadow_lift;
}

varying vec3 v_obj;      // objectLight (gamma) * brightness: chỉ dùng cho diffuse
varying vec3 v_lit;      // objectLight gốc (gamma, chưa nhân brightness): viền sáng + độ bóng như client gốc
varying vec3 v_lview;    // hướng sáng trong không gian camera

void vertex() {
	vec3 origin = NODE_POSITION_WORLD;
	vec3 tl;
	if (fixed_light >= 0.0) {
		tl = vec3(fixed_light);
	} else {
		vec2 luv = vec2(origin.x + 0.5, -origin.z + 0.5) / 256.0;
		// ảnh sáng địa hình lưu sRGB: đọc lại giá trị gamma của MU
		// như mu_object: client IGCN nâng chỗ tối (đo ở quán rượu Lorencia)
		tl = min(textureLod(terrain_light, luv, 0.0).rgb * 0.8 + vec3(0.35), vec3(1.0));
	}
	vec3 bt = body_tint;
	if (tint_pulse > 0.5) {
		bt *= sin(TIME * 4.0) * 0.15 + 0.6;
	}
	v_lit = tl * bt;
	v_obj = v_lit * brightness;
	v_lview = (VIEW_MATRIX * vec4(0.0, 0.0, 1.2, 0.0)).xyz;
}

float roll(float v) {
	if (knee > 0.0 && knee < 1.0 && v > knee) {
		float r = 1.0 - knee;
		return knee + r * (1.0 - exp(-(v - knee) / r));
	}
	return v;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a <= alpha_cut) {
		discard;
	}
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 v = normalize(VIEW);
	float ld = dot(n, v_lview);
	float lum = max(ld * diffuse_scale + ambient, diffuse_floor);
	vec3 dl = v_obj * lum;
	vec3 diffuse = clamp(vec3(roll(dl.r), roll(dl.g), roll(dl.b)), 0.0, 1.0);
	float facing = clamp(abs(dot(n, v)), 0.0, 1.0);
	// skinned_lit.frag.hlsl: rim = strength * (1-|n.v|)^power * objectLight. brightness (tăng sáng riêng
	// của bản Godot, quái / NPC x2.9) KHÔNG nhân vào đây, nếu không viền thành lớp ánh kim trắng quanh thân
	vec3 rim = rim_strength * pow(1.0 - facing, rim_power) * v_lit;
	vec3 spec = vec3(0.0);
	if (specular > 0.0 && ld > 0.0) {
		vec3 h = normalize(normalize(v_lview) + v);
		spec = specular * pow(clamp(dot(n, h), 0.0, 1.0), specular_power) * v_lit;
	}
	vec3 c = clamp((body_gain > 1.0001 ? gain_shoulder(t.rgb * diffuse * body_boost) : t.rgb * diffuse * body_boost) + rim + spec, 0.0, 1.0);
	ALBEDO = c;   // renderer GL Compatibility tính trong gamma: không đổi sang linear
	if (all(equal(VIEWPORT_SIZE, mu_bloom_size))) {
		ALBEDO = vec3(0.0);
	}
	ALPHA = t.a;
}
