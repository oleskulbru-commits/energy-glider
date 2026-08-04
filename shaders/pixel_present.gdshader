shader_type canvas_item;
render_mode unshaded;

uniform float present_dither_strength : hint_range(0.0, 1.0, 0.01) = 0.12;

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

void fragment() {
	vec3 color = texture(TEXTURE, UV).rgb;
	float dither = (bayer4(ivec2(FRAGCOORD.xy)) / 16.0 - 0.5) * present_dither_strength / 255.0;
	COLOR = vec4(clamp(color + vec3(dither), 0.0, 1.0), 1.0);
}
