shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D color_tex : filter_nearest, repeat_disable, source_color;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 color_tint = vec3(1.0);
uniform vec3 smoke_tint = vec3(0.22, 0.20, 0.18);
uniform float smoke_mix = 0.28;
uniform float emission_strength = 2.5;
uniform float alpha_scale = 1.0;
uniform bool proximity_fade_enabled = true;
uniform float proximity_fade_distance = 1.0;

void fragment() {
	vec4 col = texture(color_tex, UV);
	float hot = max(col.r, max(col.g, col.b));
	float glow = smoothstep(0.25, 0.6, hot);

	vec3 fire = col.rgb * color_tint;
	vec3 textured = col.rgb * color_tint;
	float smoke_weight = col.a * max(hot, 0.12);
	vec3 cold = mix(textured, smoke_tint * smoke_weight, smoke_mix);
	vec3 base = mix(cold, fire, glow);

	ALBEDO = base;
	EMISSION = base * emission_strength * glow;
	ALPHA = col.a * alpha_scale;

	if (proximity_fade_enabled && proximity_fade_distance > 0.0) {
		float proximity_depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec4 proximity_view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, proximity_depth_tex * 2.0 - 1.0, 1.0);
		#else
		vec4 proximity_view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, proximity_depth_tex, 1.0);
		#endif
		proximity_view_pos.xyz /= proximity_view_pos.w;
		ALPHA *= clamp(1.0 - smoothstep(proximity_view_pos.z + proximity_fade_distance, proximity_view_pos.z, VERTEX.z), 0.0, 1.0);
	}
}
