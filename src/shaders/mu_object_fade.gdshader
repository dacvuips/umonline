shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// Làm vùng đổ bóng bớt đen: ánh sáng (gamma) thấp hơn shadow_floor được kéo lên gần mức đó,
// tỉ lệ shadow_lift (0 = như MU gốc). Chỗ sáng hơn shadow_floor giữ nguyên.
uniform float shadow_floor = 0.65;
uniform float shadow_lift = 0.75;
uniform float brightness = 1.5;
vec3 lift_shadow(vec3 l) {
	return l + max(vec3(shadow_floor) - l, vec3(0.0)) * shadow_lift;
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
	v_light = pow(lift_shadow(pow(textureLod(terrain_light, luv, 0.0).rgb, vec3(1.0 / 2.2))), vec3(2.2)) * brightness;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a <= alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * v_light;
	ALPHA = fade;
}
