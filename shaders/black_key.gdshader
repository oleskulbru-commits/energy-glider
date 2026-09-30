shader_type canvas_item;

uniform float cutoff : hint_range(0.0, 1.0, 0.01) = 0.07;
uniform float softness : hint_range(0.0, 0.5, 0.01) = 0.09;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float luma = max(color.r, max(color.g, color.b));
	float alpha = smoothstep(cutoff, cutoff + softness, luma);
	COLOR = vec4(color.rgb, color.a * alpha);
}
