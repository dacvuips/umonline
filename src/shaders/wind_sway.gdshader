shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Shader chuyển động gió tự nhiên (Wind Sway) cho Cây cối, Cành lá và Hoa lá cỏ MU Online
// Đỉnh ở gốc bám đất cố định, đỉnh càng lên cao càng uốn lượn mềm mại theo nhịp gió

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float wind_speed : hint_range(0.5, 8.0) = 2.4;
uniform float wind_strength : hint_range(0.01, 0.5) = 0.08;
uniform float leaf_flutter : hint_range(0.0, 0.2) = 0.03;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.4;

void vertex() {
	// Tính cao độ từ mặt đất
	float height = max(0.0, VERTEX.y);
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	
	// Sóng gió lớn (Sway)
	float time_offset = TIME * wind_speed + world_pos.x * 0.35 + world_pos.z * 0.35;
	float sway_main = sin(time_offset) * (height * 0.35 + height * height * 0.15) * wind_strength;
	float sway_cross = cos(time_offset * 0.85 + 1.2) * (height * 0.25) * wind_strength;
	
	// Sóng xào xạc lá cây tần số cao (Leaf Flutter)
	float flutter = sin(TIME * 6.5 + VERTEX.x * 3.0 + VERTEX.z * 3.0) * leaf_flutter * min(height, 1.5);
	
	VERTEX.x += sway_main + flutter;
	VERTEX.z += sway_cross + flutter * 0.5;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
