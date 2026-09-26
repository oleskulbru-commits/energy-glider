shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 color_tint : source_color = vec4(1.6, 0.21, 0.064, 1.0);
uniform float glow_strength = 2.5;
uniform float scroll_speed = 12.0;
uniform float tile_count = 3.0;
uniform float displacement_strength = 0.09;
uniform sampler2D fire_tex : repeat_enable, filter_nearest;

varying vec2 v_scroll_uv;

void vertex() {
	v_scroll_uv = vec2(UV.x * tile_count, UV.y * tile_count - TIME * scroll_speed);
	float height = texture(fire_tex, v_scroll_uv).r;
	VERTEX += NORMAL * height * displacement_strength;
}

void fragment() {
	vec4 fire = texture(fire_tex, v_scroll_uv);
	vec3 energy = fire.rgb * color_tint.rgb * glow_strength;
	float alpha = fire.a * color_tint.a;

	ALBEDO = energy;
	EMISSION = energy;
	ALPHA = alpha;
}
