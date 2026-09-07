shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D color_tex : filter_nearest, repeat_disable;
uniform sampler2D normal_tex : filter_nearest, repeat_disable;
uniform vec3 light_dir = vec3(0.3, 0.85, 0.4);
uniform float normal_strength = 0.65;
uniform float emission_strength = 2.5;
uniform vec3 color_tint = vec3(1.0);
uniform float alpha_scale = 1.0;
uniform float lighting_dark = 0.85;
uniform float lighting_bright = 1.15;

void fragment() {
	vec4 col = texture(color_tex, UV);
	vec3 nmap = texture(normal_tex, UV).rgb * 2.0 - 1.0;

	vec2 xy = nmap.xy * normal_strength;
	vec3 n = normalize(vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy)))));
	float ndl = max(dot(n, normalize(light_dir)), 0.0);
	float lighting = mix(lighting_dark, lighting_bright, ndl);

	vec3 energy = col.rgb * color_tint * lighting * emission_strength;

	ALBEDO = energy;
	EMISSION = energy;
	ALPHA = max(col.r, max(col.g, col.b)) * alpha_scale;
}
