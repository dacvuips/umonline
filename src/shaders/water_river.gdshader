shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// Shader Dòng Sông Nước Lorencia nguyên bản MU Online (Sóng nước cuộn chảy sống động)
uniform sampler2D water_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D caustics_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.12, 0.38, 0.65, 0.78);
uniform vec4 shallow_color : source_color = vec4(0.28, 0.68, 0.88, 0.60);
uniform float flow_speed : hint_range(0.01, 1.0) = 0.06;
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.005;

void vertex() {
	// Gợn sóng nhấp nhô nhẹ trên mặt sông
	float wave1 = sin(TIME * 2.0 + VERTEX.x * 1.5 + VERTEX.z * 1.0);
	float wave2 = cos(TIME * 1.6 + VERTEX.x * 1.0 - VERTEX.z * 1.5);
	VERTEX.y += (wave1 + wave2) * wave_amplitude;
}

void fragment() {
	// Hai lớp UV cuộn sóng ngược chiều nhau tạo dòng nước chảy tự nhiên
	vec2 uv1 = UV * 1.2 + vec2(TIME * flow_speed, TIME * flow_speed * 0.4);
	vec2 uv2 = UV * 1.6 - vec2(TIME * flow_speed * 0.7, TIME * flow_speed * 0.3);
	
	vec4 c1 = texture(caustics_texture, uv1);
	vec4 c2 = texture(caustics_texture, uv2);
	float caustic = (c1.r + c2.r) * 0.5;
	
	// Hòa trộn màu nước sâu và màu nông có phản quang ánh nắng
	vec3 water_rgb = mix(deep_color.rgb, shallow_color.rgb, caustic);
	ALBEDO = water_rgb + vec3(caustic * 0.35);
	ALPHA = mix(deep_color.a, shallow_color.a, caustic);
	
	ROUGHNESS = 0.05;
	METALLIC = 0.1;
	SPECULAR = 0.95;
}
