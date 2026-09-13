shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : filter_nearest, repeat_enable, source_color;
uniform float uv_scale = 2.0;
uniform float mask_threshold = 0.04;
uniform float mask_softness = 0.22;
uniform float displacement_strength = 0.0;
uniform vec3 cold_color : source_color = vec3(0.35, 0.08, 0.02);
uniform vec3 hot_color : source_color = vec3(1.4, 0.85, 0.25);
uniform float emission_strength = 4.0;
uniform float alpha_scale = 1.0;
uniform float heat_bias = 0.0;

varying float v_mask;


vec4 triplanar_sample(sampler2D tex, vec3 position, vec3 normal, float scale) {
	vec3 blend = abs(normal);
	blend = max(blend, vec3(0.00001));
	blend /= blend.x + blend.y + blend.z;
	vec4 sample_x = texture(tex, position.yz * scale);
	vec4 sample_y = texture(tex, position.xz * scale);
	vec4 sample_z = texture(tex, position.xy * scale);
	return sample_x * blend.x + sample_y * blend.y + sample_z * blend.z;
}


float luminance(vec3 rgb) {
	return max(rgb.r, max(rgb.g, rgb.b));
}


float shaped_mask(float lum) {
	return smoothstep(mask_threshold, mask_threshold + mask_softness, lum);
}


void vertex() {
	vec4 noise = triplanar_sample(noise_tex, VERTEX, NORMAL, uv_scale);
	float mask = shaped_mask(luminance(noise.rgb));
	VERTEX += NORMAL * mask * displacement_strength;
	v_mask = mask;
}


void fragment() {
	vec4 noise = triplanar_sample(noise_tex, VERTEX, NORMAL, uv_scale);
	float mask = shaped_mask(luminance(noise.rgb));
	mask = max(mask, v_mask * 0.85);
	mask = clamp(mask + heat_bias, 0.0, 1.0);
	vec3 fire_color = mix(cold_color, hot_color, mask);
	float alpha = mask * alpha_scale;
	ALBEDO = fire_color * alpha;
	EMISSION = fire_color * emission_strength * mask;
	ALPHA = alpha;
}
