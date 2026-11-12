shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Đồ vẽ trong ô túi đồ / cửa hàng (RenderItem3D -> RenderObjectScreen): không đổ bóng, màu texture phẳng.
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;
uniform float alpha_cut = -1.0;
uniform vec3 tint = vec3(1.0);
uniform float tint_pulse = 0.0;   // +3..+6 nhấp nháy theo g_Luminosity
uniform float icon_tint_mix = 0.5; // 0 = màu gốc, 1 = sắc theo cấp đầy đủ

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a <= alpha_cut) {
		discard;
	}
	// Giữ màu texture tươi sáng gốc của MU, hòa trộn sắc thái theo cấp (+3/+4 đỏ nhẹ, +5/+6 xanh)
	vec3 bt = mix(vec3(1.0), tint / max(max(tint.r, tint.g), max(tint.b, 0.001)), icon_tint_mix);
	if (tint_pulse > 0.5) {
		bt *= sin(TIME * 4.0) * 0.08 + 0.94;
	}
	vec3 col = pow(t.rgb, vec3(0.92)) * 1.12;
	ALBEDO = min(col * bt, vec3(1.0));
	// KHÔNG ghi ALPHA: ghi ALPHA làm vật liệu thành trong suốt -> vẽ sau và đè mất lớp ánh kim (next_pass mu_item_glow)
}

