shader_type canvas_item;
render_mode blend_add;

uniform vec4 color_tint : source_color = vec4(1.6, 0.21, 0.064, 1.0);
uniform float glow_strength = 3.0;
uniform float char_threshold = 0.04;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float lum = max(col.r, max(col.g, col.b));
	float mask = step(char_threshold, lum);
	if (col.a < 0.5) {
		mask = 0.0;
	}
	vec3 energy = color_tint.rgb * glow_strength * mask;
	COLOR = vec4(energy, mask);
}
