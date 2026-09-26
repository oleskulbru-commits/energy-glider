shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D frame_tex : filter_nearest, repeat_disable, source_color;
uniform vec3 color_tint : source_color = vec3(0.45483235, 0.7983809, 1.5999943);
uniform float glow_strength = 2.25;
uniform float alpha_scale = 0.75;
uniform float char_threshold = 0.04;
uniform float char_softness = 0.22;

void fragment() {
	vec4 col = texture(frame_tex, UV);
	float lum = max(col.r, max(col.g, col.b));
	float alpha = col.a;
	if (alpha >= 0.99) {
		alpha = smoothstep(char_threshold, char_threshold + char_softness, lum);
	}
	alpha *= alpha_scale;
	vec3 energy = color_tint * glow_strength * alpha;
	ALBEDO = energy;
	EMISSION = energy;
	ALPHA = alpha;
}
