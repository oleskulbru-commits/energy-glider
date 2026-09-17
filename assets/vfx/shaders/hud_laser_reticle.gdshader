shader_type canvas_item;
render_mode blend_mix;

uniform vec4 color_tint : source_color = vec4(1.2, 0.06, 0.015, 1.0);
uniform float glow_strength = 2.0;
uniform float char_threshold = 0.04;
uniform float char_softness = 0.06;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float lum = max(col.r, max(col.g, col.b));
	float mask = smoothstep(char_threshold, char_threshold + char_softness, lum);
	if (col.a < 0.5) {
		mask = 0.0;
	}
	vec3 energy = color_tint.rgb * glow_strength * mask;
	COLOR = vec4(energy, mask * color_tint.a);
}
