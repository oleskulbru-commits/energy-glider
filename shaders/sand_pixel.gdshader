shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float pixel_size : hint_range(0.1, 2.0, 0.05) = 0.35;
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float palette_steps : hint_range(2.0, 8.0, 1.0) = 5.0;
uniform vec3 sand_dark : source_color = vec3(0.04, 0.04, 0.05);
uniform vec3 sand_mid : source_color = vec3(0.09, 0.09, 0.10);
uniform vec3 sand_light : source_color = vec3(0.15, 0.15, 0.16);
uniform vec3 sand_highlight : source_color = vec3(0.22, 0.22, 0.24);

varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bayer4(ivec2 p) {
	int x = abs(p.x) % 4;
	int y = abs(p.y) % 4;
	int index = x + y * 4;
	if (index == 0) return 0.0;
	if (index == 1) return 8.0;
	if (index == 2) return 2.0;
	if (index == 3) return 10.0;
	if (index == 4) return 12.0;
	if (index == 5) return 4.0;
	if (index == 6) return 14.0;
	if (index == 7) return 6.0;
	if (index == 8) return 3.0;
	if (index == 9) return 11.0;
	if (index == 10) return 1.0;
	if (index == 11) return 9.0;
	if (index == 12) return 15.0;
	if (index == 13) return 7.0;
	if (index == 14) return 13.0;
	return 5.0;
}

vec3 sample_palette(float t) {
	if (t < 0.33) {
		return mix(sand_dark, sand_mid, t / 0.33);
	}
	if (t < 0.66) {
		return mix(sand_mid, sand_light, (t - 0.33) / 0.33);
	}
	return mix(sand_light, sand_highlight, (t - 0.66) / 0.34);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	COLOR = COLOR;
}

void fragment() {
	vec3 lit = max(COLOR.rgb, vec3(0.05));
	vec2 cell = floor(world_pos.xz / pixel_size);
	float grain = hash21(cell) * 0.14 - 0.07;

	vec3 base = lit + vec3(grain);
	float luma = dot(base, vec3(0.299, 0.587, 0.114));

	float dither = bayer4(ivec2(cell)) / 16.0 - 0.5;
	luma += dither * dither_strength;
	luma = clamp(luma / 1.05, 0.0, 1.0);

	float steps = max(palette_steps, 2.0);
	float t = floor(luma * steps) / (steps - 1.0);
	vec3 palette = sample_palette(t);
	float lit_luma = max(dot(lit, vec3(0.299, 0.587, 0.114)), 0.05);
	vec3 tint = lit / lit_luma;
	ALBEDO = palette * clamp(tint, 0.75, 1.25);
}
