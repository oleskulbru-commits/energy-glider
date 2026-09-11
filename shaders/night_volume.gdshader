shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled,
	shadows_disabled, ambient_light_disabled, fog_disabled;

uniform float radius_m = 80.0;
uniform float density = 0.022;
uniform float edge_fade_m = 14.0;
uniform vec3 night_color : source_color = vec3(0.02, 0.03, 0.07);
uniform float alpha_mul = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

bool intersect_sphere(vec3 ro, vec3 rd, float r, out float t_enter, out float t_exit) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float disc = b * b - c;
	if (disc < 0.0) {
		return false;
	}
	float s = sqrt(max(disc, 0.0));
	t_enter = -b - s;
	t_exit = -b + s;
	return t_exit >= max(t_enter, 0.0);
}

vec3 world_from_depth(vec2 screen_uv, float depth, mat4 inv_proj, mat4 inv_view) {
	vec4 ndc = vec4(screen_uv * 2.0 - 1.0, depth, 1.0);
	vec4 view = inv_proj * ndc;
	view.xyz /= max(view.w, 1e-6);
	vec4 world = inv_view * vec4(view.xyz, 1.0);
	return world.xyz;
}

void fragment() {
	if (alpha_mul <= 0.001) {
		discard;
	}

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec3 scene_world = world_from_depth(SCREEN_UV, depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 cam_world = CAMERA_POSITION_WORLD;
	mat4 inv_model = inverse(MODEL_MATRIX);
	vec3 cam_local = (inv_model * vec4(cam_world, 1.0)).xyz;
	vec3 scene_local = (inv_model * vec4(scene_world, 1.0)).xyz;
	vec3 to_scene = scene_local - cam_local;
	float scene_t = length(to_scene);
	if (scene_t < 0.001) {
		discard;
	}
	vec3 rd = to_scene / scene_t;

	float t_enter = 0.0;
	float t_exit = 0.0;
	if (!intersect_sphere(cam_local, rd, max(radius_m, 0.001), t_enter, t_exit)) {
		discard;
	}

	t_enter = max(t_enter, 0.0);
	t_exit = min(t_exit, scene_t);
	float travel = t_exit - t_enter;
	if (travel <= 0.001) {
		discard;
	}

	vec3 mid = cam_local + rd * ((t_enter + t_exit) * 0.5);
	float sdf = length(mid) - radius_m;
	float edge = smoothstep(0.0, -max(edge_fade_m, 0.001), sdf);
	float fog = 1.0 - exp(-max(density, 0.0) * travel);
	float alpha = clamp(fog * edge * alpha_mul, 0.0, 1.0);
	if (alpha <= 0.002) {
		discard;
	}

	ALBEDO = night_color;
	ALPHA = alpha;
}
