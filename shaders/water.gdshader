// Mặt nước: hai lớp sóng pháp tuyến cuộn ngược chiều, độ đục theo độ sâu, bọt ven bờ,
// váng bẩn tan dần theo tiến độ xử lý (purity 0 → 1).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

uniform vec3 dirty_color : source_color = vec3(0.26, 0.28, 0.13);
uniform vec3 clean_color : source_color = vec3(0.05, 0.33, 0.42);
uniform vec3 scum_color : source_color = vec3(0.22, 0.2, 0.08);
uniform float purity : hint_range(0.0, 1.0) = 0.0;
uniform float wave : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D normal_a : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_b : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D scum_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(wpos.x * 0.6 + TIME * 1.3) * 0.025 + cos(wpos.z * 0.9 + TIME * 1.1) * 0.02) * wave;
}

void fragment() {
	float t = TIME * wave;
	vec3 na = texture(normal_a, wpos.xz * 0.07 + vec2(t * 0.025, t * 0.01)).rgb;
	vec3 nb = texture(normal_b, wpos.xz * 0.13 - vec2(t * 0.012, t * 0.03)).rgb;
	NORMAL_MAP = normalize(mix(na, nb, 0.5));
	NORMAL_MAP_DEPTH = mix(0.6, 1.0, purity);

	// Độ sâu nước dưới điểm này (để làm đục và bọt ven bờ)
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float depth = clamp(VERTEX.z - view.z, 0.0, 10.0);

	float s = texture(scum_noise, wpos.xz * 0.045 + vec2(t * 0.004, 0.0)).r;
	float scum = smoothstep(0.52, 0.68, s) * (1.0 - purity);
	float foam = (1.0 - smoothstep(0.0, 0.35, depth)) * (0.4 + 0.6 * s);

	vec3 col = mix(dirty_color, clean_color, purity);
	col = mix(col * 0.6, col, exp(-depth * 0.6));
	col = mix(col, scum_color, scum * 0.9);
	col += foam * mix(0.15, 0.45, purity);

	ALBEDO = col;
	ROUGHNESS = mix(0.06, 0.7, scum);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(mix(0.85, 0.55, purity) + depth * mix(0.6, 0.25, purity) + scum, 0.0, 1.0);
}
