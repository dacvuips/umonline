shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;

// Shader Ánh Sáng Xuyên Ô Cửa Sổ / Tia Nắng Lorencia chuẩn Webzen MU Online
// Khắc phục triệt để lỗi vệt đa giác đen sì bằng kỹ thuật Additive Blending & Cutoff
uniform sampler2D light_texture : source_color, filter_linear_mipmap;
uniform vec4 light_color : source_color = vec4(1.0, 0.9, 0.65, 1.0);
uniform float intensity : hint_range(0.1, 5.0) = 1.6;
uniform float cutoff : hint_range(0.0, 0.25) = 0.04;

void fragment() {
	vec4 tex = texture(light_texture, UV);
	
	// Lấy độ sáng max của RGB để loại bỏ nền đen tối của texture MU gốc
	float lum = max(tex.r, max(tex.g, tex.b));
	if (lum <= cutoff) {
		discard;
	}
	
	float smooth_val = (lum - cutoff) / (1.0 - cutoff);
	ALBEDO = tex.rgb * light_color.rgb * intensity * smooth_val;
}
