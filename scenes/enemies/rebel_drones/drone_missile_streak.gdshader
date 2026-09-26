shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 ColorParameter : source_color = vec4(0.45, 0.8, 1.6, 0.9);
uniform float GlowStrength = 3.0;
uniform vec2 SpeedXY = vec2(0.0, 1.0);
uniform sampler2D Base_Texture : repeat_enable, filter_linear;
uniform sampler2D Streak_Mask : repeat_enable, filter_linear;

void fragment() {
	vec4 base_tex = texture(Base_Texture, UV + SpeedXY * TIME);
	vec4 mask_tex = texture(Streak_Mask, UV);
	vec3 energy = base_tex.rgb * mask_tex.rgb * ColorParameter.rgb * GlowStrength;
	float alpha = base_tex.a * mask_tex.a * ColorParameter.a;
	ALBEDO = energy;
	EMISSION = energy;
	ALPHA = alpha;
}
