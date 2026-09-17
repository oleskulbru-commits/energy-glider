shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : source_color;
uniform float strength = 0.03;
uniform float speed = 2.0;

void fragment() {
    vec2 n = texture(noise_tex, UV + vec2(TIME * speed, TIME * speed * 0.7)).rg;
    vec2 offset = (n - 0.5) * strength;
    ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV + offset).rgb;
    ALPHA = smoothstep(0.0, 1.0, 1.0 - UV.y); // fade at edges
}