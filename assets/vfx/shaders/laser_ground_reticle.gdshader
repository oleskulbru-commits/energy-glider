shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D frame_tex : filter_nearest, repeat_disable, source_color;
uniform vec3 color_tint : source_color = vec3(1.2, 0.06, 0.015);
uniform float glow_strength = 3.75;
uniform float alpha_scale = 0.92;
uniform float char_threshold = 0.04;
uniform float char_softness = 0.06;
uniform float bracket_visible = 1.0;

void fragment() {
	vec4 col = texture(frame_tex, UV);
	float lum = max(col.r, max(col.g, col.b));
	float bracket_alpha = col.a;
	if (bracket_alpha >= 0.99) {
		bracket_alpha = smoothstep(char_threshold, char_threshold + char_softness, lum);
	}
	bracket_alpha *= alpha_scale * bracket_visible;
	vec3 energy = color_tint * glow_strength * bracket_alpha;
	ALBEDO = energy;
	EMISSION = energy;
	ALPHA = bracket_alpha;
}
