shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 color_tint : source_color = vec4(1.6, 0.21, 0.064, 1.0);
uniform float glow_strength = 3.0;
uniform float scroll_speed = 4.0;
uniform float beam_tile_count = 4.0;
uniform float beam_width_scale = 1.0;
uniform float uv_length_scale = 1.0;
uniform float uv_width_scale = 1.0;
uniform sampler2D streak_tex : repeat_enable, filter_nearest;

void fragment() {
	// Quad U = across beam, V = along beam. Texture U = along streak, V = across profile.
	// Profile V must stay in 0-1 — repeat on the sampler would tile the bright core if we zoom UV.
	float across_uv = clamp(0.5 + (UV.x - 0.5) * uv_width_scale, 0.0, 1.0);
	vec2 streak_uv = vec2(
		UV.y * beam_tile_count * uv_length_scale - TIME * scroll_speed,
		across_uv
	);
	vec4 streak = texture(streak_tex, streak_uv);

	// >1 narrows the visible beam without repeating the profile texture.
	float width_mask = 1.0 - smoothstep(0.0, 1.0 / max(beam_width_scale, 0.001), abs(UV.x - 0.5) * 2.0);

	float end_fade = smoothstep(0.0, 0.06, UV.y) * smoothstep(1.0, 0.88, UV.y);
	vec3 energy = streak.rgb * width_mask * end_fade * color_tint.rgb * glow_strength;
	float alpha = streak.a * width_mask * end_fade * color_tint.a;

	ALBEDO = energy;
	EMISSION = energy;
	ALPHA = alpha;
}
