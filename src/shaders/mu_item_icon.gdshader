shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Đồ vẽ trong ô túi đồ / cửa hàng (RenderItem3D -> RenderObjectScreen): không đổ bóng, màu texture phẳng.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_cut = -1.0;
uniform vec3 tint = vec3(1.0);
uniform float tint_pulse = 0.0;   // +3..+6 nhấp nháy theo g_Luminosity
uniform float icon_tint_mix = 0.5; // 0 = màu gốc, 1 = sắc theo cấp đầy đủ

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a <= alpha_cut) {
		discard;
	}
	// RenderObjectScreen: o->LightEnable = false, Light = (1,1,1) -> màu texture phẳng, chỉ nhân màu theo cấp
	// Ảnh đồ trong ô: giữ sắc theo cấp (+3/+4 đỏ, +5/+6 xanh) nhưng không làm tối món đồ —
	// kênh mạnh nhất của màu = 1, trộn icon_tint_mix với màu gốc, nhấp nháy nhẹ 0.8..1.0
	// (MU: nhân thẳng, nhấp nháy 0.45..0.75 -> đồ đỏ / cam dưới sắc xanh gần như đen)
	vec3 bt = mix(vec3(1.0), tint / max(max(tint.r, tint.g), max(tint.b, 0.001)), icon_tint_mix);
	if (tint_pulse > 0.5) {
		bt *= sin(TIME * 4.0) * 0.1 + 0.9;
	}
	ALBEDO = t.rgb * pow(bt, vec3(2.2));
}
