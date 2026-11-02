// Bờ đất: bùn chuyển dần sang cỏ theo tỉ lệ rác đã dọn (clean 0 → 1), viền chuyển có nhiễu tự nhiên.
shader_type spatial;

uniform sampler2D mud_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mask_noise : repeat_enable, filter_linear_mipmap;
uniform float clean : hint_range(0.0, 1.0) = 0.0;
uniform float scale = 0.35;
uniform float wet_height = -1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * scale;
	float n = texture(mask_noise, wpos.xz * 0.05).r;
	// Cỏ mọc từ mép lối đi xuống phía nước
	float reach = clean * 1.25 - (1.0 - smoothstep(-1.4, 0.0, wpos.y)) * 0.35;
	float g = smoothstep(n - 0.08, n + 0.08, reach);
	vec3 mud = texture(mud_albedo, uv).rgb;
	vec3 grass = texture(grass_albedo, uv * 1.6).rgb;
	float wet = 1.0 - smoothstep(wet_height - 0.25, wet_height + 0.2, wpos.y);
	mud *= mix(1.0, 0.55, wet);
	ALBEDO = mix(mud, grass, g);
	NORMAL_MAP = mix(texture(mud_normal, uv).rgb, texture(grass_normal, uv * 1.6).rgb, g);
	ROUGHNESS = mix(mix(0.85, 0.35, wet), 0.9, g);
}
