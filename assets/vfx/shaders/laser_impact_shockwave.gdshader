shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 color_tint : source_color = vec4(1.6, 0.21, 0.064, 1.0);
uniform float glow_strength = 2.5;
uniform float fade = 1.0;
uniform float ring_progress = 0.0;
uniform float ring_width = 0.14;
uniform float ring_softness = 0.035;
uniform float radial_tiles = 4.0;
uniform float scroll_speed = 6.0;
uniform sampler2D fire_tex : repeat_enable, filter_nearest;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float radius = length(centered);
	if (radius > 1.0) {
		discard;
	}

	float angle = atan(centered.y, centered.x);
	float dist_to_ring = abs(radius - ring_progress);
	float ring_mask = 1.0 - smoothstep(ring_width, ring_width + ring_softness, dist_to_ring);

	vec2 fire_uv = vec2(
		fract(radius * radial_tiles - TIME * scroll_speed),
		fract(angle / TAU * 2.0 + 0.5)
	);
	vec4 fire = texture(fire_tex, fire_uv);
	float lum = max(fire.r, max(fire.g, fire.b));
	float energy_mask = ring_mask * lum * fade;
	vec3 energy = color_tint.rgb * glow_strength * energy_mask;

	ALBEDO = energy;
	EMISSION = energy;
	ALPHA = energy_mask * color_tint.a;
}
