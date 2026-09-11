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

var _mesh: MeshInstance3D
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("night_volume")
	top_level = true
	_ensure_mesh()
	_apply_shader_params()


func _process(_delta: float) -> void:
	_follow_host()


func snap_to_standing(origin: Vector3, ground_y: float) -> void:
	global_position = Vector3(origin.x, ground_y, origin.z)
	global_rotation = Vector3.ZERO


func set_fade(value: float) -> void:
	fade = clampf(value, 0.0, 1.0)
	if _mesh != null:
		_mesh.visible = fade > 0.01
	if _mat != null:
		_mat.set_shader_parameter("alpha_mul", fade)


## 0 outside the sphere, 1 when `EDGE_FADE_M` inside, times Bring the Night opacity.
func blend_at_world(world_pos: Vector3) -> float:
	var local := to_local(world_pos)
	var sdf := local.length() - RADIUS_M
	if sdf >= 0.0:
		return 0.0
	return smoothstep(0.0, -EDGE_FADE_M, sdf) * fade


func camera_night_blend() -> float:
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
	sphere.radius = RADIUS_M
	sphere.height = DIAMETER_M
	sphere.radial_segments = 32
	sphere.rings = 16
	_mesh.mesh = sphere
	_mesh.position = Vector3.ZERO
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_mat = ShaderMaterial.new()
	# Dummy renderer (--script / headless tests) cannot compile screen-depth builtins.
	if RenderingServer.get_rendering_device() != null:
		_mat.shader = _SHADER
	_mesh.material_override = _mat
	_mesh.visible = false


func _apply_shader_params() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("radius_m", RADIUS_M)
	_mat.set_shader_parameter("density", DENSITY)
	_mat.set_shader_parameter("edge_fade_m", EDGE_FADE_M)
	_mat.set_shader_parameter("night_color", NIGHT_COLOR)
	_mat.set_shader_parameter("alpha_mul", fade)
