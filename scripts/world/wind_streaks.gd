class_name WindStreaks
extends Node3D

const WindFieldScript = preload("res://scripts/world/wind_field.gd")

const BASE_AMOUNT := 80
const BASE_LIFETIME := 1.2
const STREAK_COLOR := Color(0.78, 0.62, 0.4, 0.15)
const VISUAL_WIND_SPEED := 5.5
const FOLLOW_HEIGHT := 3.0
const EMISSION_EXTENTS := Vector3(20.0, 4.0, 20.0)

@export var track_node_path: NodePath

var _particles: CPUParticles3D
var _wind_field: WindFieldScript
var _track_node: Node3D


func _ready() -> void:
	top_level = true
	_particles = CPUParticles3D.new()
	_particles.emitting = true
	_particles.amount = BASE_AMOUNT
	_particles.lifetime = BASE_LIFETIME
	_particles.explosiveness = 0.0
	_particles.randomness = 0.35
	_particles.direction = Vector3(1.0, 0.0, 0.0)
	_particles.spread = 6.0
	_particles.gravity = Vector3.ZERO
	_particles.initial_velocity_min = VISUAL_WIND_SPEED * 0.85
	_particles.initial_velocity_max = VISUAL_WIND_SPEED * 1.15
	_particles.scale_amount_min = 0.35
	_particles.scale_amount_max = 0.9
	_particles.color = STREAK_COLOR
	_particles.local_coords = false
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = EMISSION_EXTENTS
	add_child(_particles)
	_configure_particle_mesh()

	if track_node_path != NodePath():
		_track_node = get_node_or_null(track_node_path) as Node3D


func _configure_particle_mesh() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.04)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	_particles.mesh = quad
	_particles.visibility_aabb = AABB(Vector3(-25.0, -6.0, -25.0), Vector3(50.0, 12.0, 50.0))


func _physics_process(_delta: float) -> void:
	if _wind_field == null and is_inside_tree():
		_wind_field = get_tree().get_first_node_in_group("wind_field") as WindFieldScript

	if _track_node == null and is_inside_tree():
		var glider := get_tree().get_first_node_in_group("glider") as Node3D
		if glider != null:
			_track_node = glider

	if _track_node != null:
		var anchor := _track_node.global_position
		anchor.y += FOLLOW_HEIGHT
		global_position = anchor

	if _wind_field == null or _particles == null:
		return

	var wind := _wind_field.get_wind_at(global_position)
	var horizontal := Vector3(wind.x, 0.0, wind.z)
	if horizontal.length_squared() < 0.0001:
		return

	var wind_dir := horizontal.normalized()
	_particles.direction = wind_dir
	var speed_scale := clampf(_wind_field.wind_strength / 8.0, 0.6, 1.4)
	_particles.initial_velocity_min = VISUAL_WIND_SPEED * 0.85 * speed_scale
	_particles.initial_velocity_max = VISUAL_WIND_SPEED * 1.15 * speed_scale
