class_name NightVolume
extends Node3D

## Bring the Night sphere. Center sits on standing terrain; visual only.

const DIAMETER_M := 160.0
const RADIUS_M := DIAMETER_M * 0.5
const EDGE_FADE_M := 14.0
const DENSITY := 0.022
const NIGHT_COLOR := Color(0.02, 0.03, 0.07)

const _SHADER := preload("res://shaders/night_volume.gdshader")

var fade := 0.0
var radius_m := RADIUS_M
var follow_host := true

var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _fade_t := 0.0
var _fade_duration := 0.0
var _self_fading := false
var _visuals_enabled := true


func _ready() -> void:
	add_to_group("night_volume")
	top_level = true
	_ensure_mesh()
	_apply_shader_params()


func _process(_delta: float) -> void:
	if follow_host:
		_follow_host()


func configure(p_radius_m: float, p_follow_host: bool) -> void:
	radius_m = maxf(p_radius_m, 0.01)
	follow_host = p_follow_host
	_ensure_mesh()
	_apply_shader_params()


func begin_self_fade(duration_sec: float) -> void:
	follow_host = false
	_fade_duration = maxf(duration_sec, 0.001)
	_fade_t = 0.0
	_self_fading = true
	set_fade(0.0)


func advance_fade(delta: float) -> void:
	if not _self_fading:
		return
	_fade_t = minf(_fade_t + delta, _fade_duration)
	set_fade(_fade_t / _fade_duration)
	if _fade_t >= _fade_duration:
		_self_fading = false


func snap_to_standing(origin: Vector3, ground_y: float) -> void:
	global_position = Vector3(origin.x, ground_y, origin.z)
	global_rotation = Vector3.ZERO


func set_fade(value: float) -> void:
	fade = clampf(value, 0.0, 1.0)
	_apply_mesh_visibility()
	if _mat != null:
		_mat.set_shader_parameter("alpha_mul", fade)


func set_visuals_enabled(on: bool) -> void:
	_visuals_enabled = on
	_apply_mesh_visibility()


func visuals_enabled() -> bool:
	return _visuals_enabled


func is_formed() -> bool:
	return fade >= 1.0


func contains_xz(world_pos: Vector3) -> bool:
	var dx := world_pos.x - global_position.x
	var dz := world_pos.z - global_position.z
	return dx * dx + dz * dz <= radius_m * radius_m


func random_point_xz(rng: RandomNumberGenerator, margin_m: float = 2.0) -> Vector3:
	var max_r := maxf(radius_m - maxf(margin_m, 0.0), 0.5)
	var dist := max_r * sqrt(rng.randf())
	var ang := rng.randf() * TAU
	return Vector3(
		global_position.x + cos(ang) * dist,
		global_position.y,
		global_position.z + sin(ang) * dist
	)


func clamp_xz(world_pos: Vector3, margin_m: float = 1.0) -> Vector3:
	var center := Vector2(global_position.x, global_position.z)
	var point := Vector2(world_pos.x, world_pos.z)
	var max_r := maxf(radius_m - maxf(margin_m, 0.0), 0.5)
	var delta := point - center
	if delta.length() <= max_r:
		return world_pos
	delta = delta.normalized() * max_r
	return Vector3(center.x + delta.x, world_pos.y, center.y + delta.y)


## 0 outside the sphere, 1 when `EDGE_FADE_M` inside, times Bring the Night opacity.
func blend_at_world(world_pos: Vector3) -> float:
	var local := to_local(world_pos)
	var sdf := local.length() - radius_m
	if sdf >= 0.0:
		return 0.0
	return smoothstep(0.0, -EDGE_FADE_M, sdf) * fade


func camera_night_blend() -> float:
	if not _visuals_enabled:
		return 0.0
	var camera := _current_camera()
	if camera == null:
		return 0.0
	return blend_at_world(camera.global_position)


func _follow_host() -> void:
	var host := get_parent()
	if host == null or not host.has_method("standing_ground_y"):
		return
	snap_to_standing(host.global_position, host.standing_ground_y())
	if host.has_method("bring_the_night_fade"):
		set_fade(host.bring_the_night_fade())


func _current_camera() -> Camera3D:
	var viewport := get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()


func _ensure_mesh() -> void:
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		add_child(_mesh)
	var sphere := SphereMesh.new()
	sphere.radius = radius_m
	sphere.height = radius_m * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_mesh.mesh = sphere
	_mesh.position = Vector3.ZERO
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if _mat == null:
		_mat = ShaderMaterial.new()
		# Dummy renderer (--script / headless tests) cannot compile screen-depth builtins.
		if RenderingServer.get_rendering_device() != null:
			_mat.shader = _SHADER
		_mesh.material_override = _mat
	_apply_mesh_visibility()


func _apply_mesh_visibility() -> void:
	if _mesh == null:
		return
	_mesh.visible = _visuals_enabled and fade > 0.01


func _apply_shader_params() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("radius_m", radius_m)
	_mat.set_shader_parameter("density", DENSITY)
	_mat.set_shader_parameter("edge_fade_m", EDGE_FADE_M)
	_mat.set_shader_parameter("night_color", NIGHT_COLOR)
	_mat.set_shader_parameter("alpha_mul", fade)
