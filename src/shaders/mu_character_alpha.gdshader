shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

// Biến thể texture 32-bit (Components == 4): trộn alpha + bỏ điểm alpha <= 0.25, vẫn ghi depth.

// "Enhanced lighting" của client gốc (shaders/skinned_lit.frag.hlsl + Data/Render/Look.json):
//   objectLight = BodyLight = ánh sáng địa hình * màu theo cấp
//   diffuse  = rolloff(objectLight * max(dot(n, L) * 1.0 + 0.3, 0.15), knee 0.8)
//   rim      = 0.4 * (1 - |dot(n, v)|)^3 * objectLight          (viền sáng)
//   specular = specular_đồ (material.specular, vd 0.6) * pow(dot(n, h), 32) * objectLight  (độ BÓNG)
//   màu = texture * diffuse + rim + specular   (tính trong không gian gamma như GPU của client)
// L = (0, -1.5, 0) của MU * sun 0.8 (LightMood) = (0, 0, 1.2) trong Godot.

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
uniform float brightness = 1.6;     // Items/Models "material.specular"
uniform float diffuse_scale = 1.0;
uniform float ambient = 0.75;
uniform float diffuse_floor = 0.55;
uniform float knee = 0.8;
uniform float rim_strength = 0.4;
uniform float rim_power = 3.0;
uniform float specular_power = 32.0;

varying vec3 v_obj;      // objectLight (gamma)
varying vec3 v_lview;    // hướng sáng trong không gian camera

void vertex() {
	vec3 origin = NODE_POSITION_WORLD;
	vec3 tl;
	if (fixed_light >= 0.0) {
		tl = vec3(fixed_light);
	} else {
		vec2 luv = vec2(origin.x + 0.5, -origin.z + 0.5) / 256.0;
		// ảnh sáng địa hình lưu sRGB: đọc lại giá trị gamma của MU
		tl = pow(textureLod(terrain_light, luv, 0.0).rgb, vec3(1.0 / 2.2));
	}
	vec3 bt = body_tint;
	if (tint_pulse > 0.5) {
		bt *= sin(TIME * 4.0) * 0.15 + 0.6;
	}
	v_obj = tl * bt * brightness;
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
	vec3 rim = rim_strength * pow(1.0 - facing, rim_power) * v_obj;
	vec3 spec = vec3(0.0);
	if (specular > 0.0 && ld > 0.0) {
		vec3 h = normalize(normalize(v_lview) + v);
		spec = specular * pow(clamp(dot(n, h), 0.0, 1.0), specular_power) * v_obj;
	}
	vec3 c = clamp(t.rgb * diffuse * body_boost + rim + spec, 0.0, 1.0);
	ALBEDO = pow(c, vec3(2.2));
	ALPHA = t.a;
}
