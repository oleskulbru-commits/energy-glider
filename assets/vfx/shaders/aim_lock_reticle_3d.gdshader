shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque, fog_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear;
uniform vec4 color_tint : source_color = vec4(0.35, 1.15, 0.45, 0.5);
uniform float glow_strength = 1.6;
uniform float char_threshold = 0.04;
uniform float char_softness = 0.06;

void fragment() {
	vec4 col = texture(albedo_tex, UV);
	float lum = max(col.r, max(col.g, col.b));
	float mask = smoothstep(char_threshold, char_threshold + char_softness, lum);
	if (col.a < 0.5) {
		mask = 0.0;
	}
	ALBEDO = color_tint.rgb * glow_strength * mask;
	ALPHA = mask * color_tint.a;
}
