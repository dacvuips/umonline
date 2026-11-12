shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// Ánh sáng vật thể, hiệu chỉnh theo ảnh chụp client IGCN Season 9 (quán rượu Lorencia: thùng gỗ, tường,
// quầy, sàn): màu = texture * min(TerrainLight tại gốc vật thể * 0.8 + 0.35, 1). Client nâng chỗ tối và gần
// như không phụ thuộc hướng mặt (công thức cổ BodyLight * (N.L*0.8+0.4) cho tối hơn 2-3 lần ảnh thật).
// Tính thẳng trong gamma: renderer GL Compatibility không đổi sang linear, không được dùng sRGB->linear / mũ 2.2.
uniform float light_scale = 0.8;
uniform float light_ambient = 0.35;
vec3 mu_light(vec3 l) {
	return min(l * light_scale + vec3(light_ambient), vec3(1.0));
}
// Hướng mặt: mặt quay về nguồn sáng (L = (0, -1.5, 0) MU = +Z Godot) giữ nguyên, mặt ngang / quay đi x0.85
// (sàn thảm quán rượu: client 0.86 * texture khi TerrainLight ~ 1)
uniform float facing_dim = 0.15;
float mu_facing(vec3 n_world) {
	return 1.0 - facing_dim + facing_dim * clamp(dot(normalize(n_world), vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
}

// Như mu_object.gdshader nhưng có độ mờ (o->Alpha / AlphaTarget của MU)
// Dùng cho mái nhà HouseWall05/06 ở Lorencia: mờ đi khi nhân vật vào trong nhà (HeroTile == 4)

uniform sampler2D albedo_tex : source_color, filter_linear, repeat_enable;
uniform sampler2D terrain_light : source_color, filter_linear, repeat_disable;
uniform float alpha_cut = 0.0;
uniform float fade = 1.0;

varying vec3 v_light;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 luv = vec2(origin.x + 0.5, -origin.z + 0.5) / 256.0;
	v_light = mu_light(textureLod(terrain_light, luv, 0.0).rgb) * mu_facing((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a <= alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * v_light;
	ALPHA = fade;
}
