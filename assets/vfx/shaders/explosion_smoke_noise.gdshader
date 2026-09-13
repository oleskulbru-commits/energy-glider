shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : filter_nearest, repeat_disable, source_color;
uniform sampler2D normal_tex : filter_nearest, repeat_disable, hint_normal;
uniform bool use_normal_map = true;
uniform float mask_threshold = 0.04;
uniform float mask_softness = 0.25;
uniform vec3 smoke_tint : source_color = vec3(0.55, 0.48, 0.42);
uniform float alpha_scale = 1.0;
uniform float rim_strength = 0.18;

varying mat3 v_tbn;


float luminance(vec3 rgb) {
	return max(rgb.r, max(rgb.g, rgb.b));
}


float shaped_mask(float lum) {
	return smoothstep(mask_threshold, mask_threshold + mask_softness, lum);
}


void vertex() {
	vec3 world_tangent = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_bitangent = normalize(cross(world_normal, world_tangent));
	v_tbn = mat3(world_tangent, world_bitangent, world_normal);
}


void fragment() {
	vec4 noise = texture(noise_tex, UV);
	float mask = shaped_mask(luminance(noise.rgb));
	vec3 albedo = smoke_tint * mask;
	float alpha = mask * alpha_scale;

	if (use_normal_map) {
		vec3 normal_sample = texture(normal_tex, UV).rgb * 2.0 - 1.0;
		NORMAL_MAP = normal_sample;
		NORMAL_MAP_DEPTH = 1.0;
	}

	ALBEDO = albedo + smoke_tint * rim_strength * mask;
	EMISSION = vec3(0.0);
	ALPHA = alpha;
}
