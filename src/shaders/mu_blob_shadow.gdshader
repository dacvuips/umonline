shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Vệt bóng tối mờ dưới chân nhân vật (thay cho bóng chiếu RenderBodyShadow của MU)
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = clamp(1.0 - d, 0.0, 1.0) * 0.45;
}
