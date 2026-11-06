shader_type spatial;
render_mode blend_mix, cull_disabled;

// Shader đập cánh chim bồ câu Lorencia chuẩn kinematics tự nhiên
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float flap_speed : hint_range(5.0, 40.0) = 22.0;
uniform float flap_amplitude : hint_range(0.0, 2.5) = 1.2;
uniform float is_flying : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// X là sải cánh (từ -0.34m bên trái đến +0.33m bên phải)
	// Thân chim nằm ở abs(VERTEX.x) <= 0.05
	float wing_dist = max(0.0, abs(VERTEX.x) - 0.05);
	if (wing_dist > 0.0 && is_flying > 0.01) {
		// Nhịp đập cánh lên xuống tự nhiên theo quán tính
		float flap = sin(TIME * flap_speed) * flap_amplitude * wing_dist * is_flying;
		VERTEX.y += flap;
		// Đầu cánh uốn cong theo lực cản của không khí
		VERTEX.z += cos(TIME * flap_speed) * flap * 0.15;
	}
}

void fragment() {
	vec4 c = texture(albedo_texture, UV);
	if (c.a < 0.4) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.8;
}
