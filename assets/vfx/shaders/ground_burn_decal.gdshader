shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D albedo_tex : filter_nearest, repeat_disable, source_color;
uniform float alpha_scale = 1.0;
uniform vec3 color_tint = vec3(1.15, 0.78, 0.58);
uniform float char_threshold = 0.04;
uniform float char_softness = 0.22;

void fragment() {
	vec4 col = texture(albedo_tex, UV);
	float lum = max(col.r, max(col.g, col.b));
	float alpha = col.a;
	// Fall back to luminance when the PNG has no real alpha (opaque black background export).
	if (alpha >= 0.99) {
		alpha = smoothstep(char_threshold, char_threshold + char_softness, lum);
	}
	alpha *= alpha_scale;
	ALBEDO = col.rgb * color_tint;
	ALPHA = alpha;
}
