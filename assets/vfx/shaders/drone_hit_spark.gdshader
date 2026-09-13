shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 ColorParameter : source_color = vec4(1.6, 0.75, 0.2, 1.0);
uniform float GlowStrength = 5.0;
uniform sampler2D Base_Texture : repeat_disable, filter_nearest;
uniform sampler2D Streak_Mask : repeat_disable, filter_nearest;

void fragment() {
	// sparks_texture.png is 32x16 (wide); rotate UV so streak length follows align_y (+Y).
	vec2 streak_uv = vec2(UV.y, UV.x);
	vec4 base_tex = texture(Base_Texture, streak_uv);
	vec4 mask_tex = texture(Streak_Mask, streak_uv);
	vec3 energy = base_tex.rgb * mask_tex.rgb * ColorParameter.rgb * GlowStrength;
	float alpha = base_tex.a * mask_tex.a * ColorParameter.a;
	ALBEDO = energy;
	EMISSION = energy;
	ALPHA = alpha;
}
