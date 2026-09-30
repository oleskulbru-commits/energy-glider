shader_type canvas_item;
render_mode blend_add;

uniform float cutoff : hint_range(0.0, 1.0, 0.01) = 0.07;
uniform float softness : hint_range(0.0, 0.5, 0.01) = 0.09;
uniform float strength : hint_range(0.0, 3.0, 0.01) = 1.25;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float luma = max(color.r, max(color.g, color.b));
	float alpha = smoothstep(cutoff, cutoff + softness, luma);
	COLOR = vec4(color.rgb * alpha * strength, alpha);
}
