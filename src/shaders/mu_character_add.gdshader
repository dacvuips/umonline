shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Mesh "Bright" của MU (texture có hậu tố _R, hoặc BlendMesh): EnableAlphaBlend() = cộng (ONE, ONE),
// không nhân ánh sáng của địa hình, không ghi depth.
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;
uniform float intensity = 1.0;
uniform vec3 light = vec3(1.0);        // BodyLight của kiểu vẽ (vd kiếm lửa (1, 0, 0.2))
uniform vec2 uv_scroll = vec2(0.0);    // đơn vị / giây
uniform float flame = 0.0;             // > 0.5: lật 4 khung texture lửa mỗi 80 ms (fV của RenderFlamberge)
uniform float pulse = 0.0;             // > 0.5: độ sáng sin(t*0.8)*0.7+0.5 (RenderKnightBlade)

void fragment() {
	vec2 uv = UV + uv_scroll * TIME;
	if (flame > 0.5) {
		uv.y += floor(mod(floor(TIME * 1000.0 * 0.05), 16.0) / 4.0) * 0.25;
	}
	vec4 t = texture(albedo_tex, uv);
	float k = intensity;
	if (pulse > 0.5) {
		k *= max(sin(TIME * 800.0 * 0.001) * 0.7 + 0.5, 0.0);
	}
	// cộng thẳng giá trị gamma như bộ đệm 8-bit của MU (xem mu_item_glow.gdshader)
	ALBEDO = t.rgb * k * light;
}
