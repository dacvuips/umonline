shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

// CreateSprite() của MU: quad luôn quay mặt về camera, vẽ cộng màu.
//  - rot_speed: xoay quanh trục nhìn (Rotation = WorldTime * 0.1 % 360 -> 100 độ/giây)
//  - Luminosity: nhịp sin (sin(WorldTime*k)*amp + base) hoặc chập chờn ngẫu nhiên (rand%30+70)*0.01

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec4 color : source_color = vec4(1.0);
uniform float rot_speed = 0.0;      // độ / giây (âm = ngược chiều)
uniform float sine_amp = 0.0;
uniform float sine_base = 1.0;
uniform float sine_freq = 2.0;
uniform float sine_phase = 0.0;
uniform float flicker = 0.0;        // 0.3 = độ sáng ngẫu nhiên 0.7..1.0 mỗi tick 25fps
uniform float seed = 0.0;
uniform float scale_pulse = 0.0;    // kích thước nhân theo độ sáng (Scale = Luminosity * k)

varying float v_lum;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void vertex() {
	float lum = 1.0;
	if (sine_amp > 0.0) {
		lum = sin(TIME * sine_freq + sine_phase) * sine_amp + sine_base;
	}
	if (flicker > 0.0) {
		lum *= 1.0 - flicker * hash(floor(TIME * 25.0) + seed * 17.0);
	}
	v_lum = lum;
	float s = mix(1.0, lum, scale_pulse);
	float a = radians(rot_speed) * TIME;
	vec2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy * s;
	// Billboard: dựng quad trong không gian nhìn ; kích thước tuyệt đối như CreateSprite
	// (không nhân tỉ lệ của quái / vật thể mà sprite gắn vào)
	vec4 center = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	center.xy += r;
	POSITION = PROJECTION_MATRIX * center;
}

void fragment() {
	vec3 t = texture(tex, UV).rgb;
	vec3 c = t * color.rgb * max(v_lum, 0.0) * color.a;
	float a = clamp(max(max(c.r, c.g), c.b), 0.0, 1.0);
	if (a < 0.03) {
		discard;
	}
	ALPHA = a;
	ALBEDO = c / max(a, 0.001);
}
