shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

// như mu_item_icon nhưng texture 32 bit: trộn theo alpha (kiếm lửa, lông vũ, cánh...)
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform float tint_pulse = 0.0;   // +3..+6 nhấp nháy theo g_Luminosity
uniform float icon_tint_mix = 0.5; // 0 = màu gốc, 1 = sắc theo cấp đầy đủ

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a <= 0.02) {
		discard;
	}
	// Giữ màu texture tươi sáng gốc của MU, hòa trộn sắc thái theo cấp (+3/+4 đỏ nhẹ, +5/+6 xanh)
	vec3 bt = mix(vec3(1.0), tint / max(max(tint.r, tint.g), max(tint.b, 0.001)), icon_tint_mix);
	if (tint_pulse > 0.5) {
		bt *= sin(TIME * 4.0) * 0.08 + 0.94;
	}
	ALBEDO = t.rgb * bt;
	ALPHA = t.a;
}
