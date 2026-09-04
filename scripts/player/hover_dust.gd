class_name HoverDust
extends Node3D

## Hover sand trail. Tune the Stream CPUParticles3D child in glider.tscn — script only handles surface follow and intensity.

const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")

const GROUND_OFFSET := 0.05
const RAY_LENGTH := 24.0

@onready var _particles: CPUParticles3D = $Stream

var _velocity_min_base := 0.6
var _velocity_max_base := 1.8
var _alpha_base := 0.32


func _ready() -> void:
	top_level = true
	if _particles == null:
		push_error("HoverDust requires a CPUParticles3D child named Stream.")
		return
	_velocity_min_base = _particles.initial_velocity_min
	_velocity_max_base = _particles.initial_velocity_max
	_alpha_base = _particles.color.a
	_particles.emitting = false


func _sample_surface_contact(player: GliderPlayer) -> Dictionary:
	var terrain: TerrainManager = null
	if player.terrain_manager_path != NodePath():
		terrain = player.get_node_or_null(player.terrain_manager_path) as TerrainManager

	var world := get_world_3d()
	var space := world.direct_space_state if world != null else null
	return TerrainQuery.sample_surface(
		terrain,
		space,
		player.global_position.x,
		player.global_position.z,
		player.global_position.y,
		1.5,
		[player.get_rid()],
		2.0,
		RAY_LENGTH
	)


func _physics_process(_delta: float) -> void:
	if _particles == null:
		return
	var player := get_parent() as GliderPlayer
	if player == null:
		return

	if player.is_run_ended():
		_particles.emitting = false
		return

	var clearance := player.get_clearance()
	var in_hover_band := clearance <= GliderPhysicsScript.HOVER_ZONE
	var low_glide := player.is_gliding() and clearance < GliderPhysicsScript.GLIDE_EXIT_HEIGHT
	var should_emit := in_hover_band and (player.is_grounded() or low_glide)
	var surface := _sample_surface_contact(player)

	if not should_emit or surface.is_empty():
		_particles.emitting = false
		return

	var surface_normal: Vector3 = surface.normal
	global_position = surface.position + surface_normal * GROUND_OFFSET
	global_basis = TerrainQuery.basis_from_up(surface_normal)

	var height_strength := 1.0 - smoothstep(
		GliderPhysicsScript.GLIDE_ENTER_HEIGHT,
		GliderPhysicsScript.HOVER_ZONE,
		clearance
	)
	var compression := clampf(
		(GliderPhysicsScript.BASE_HEIGHT - clearance) / 0.15,
		0.0,
		1.0
	)
	var horizontal_speed := MathUtil.horizontal_speed(player.velocity)
	var speed_strength := clampf(horizontal_speed / 8.0, 0.35, 1.0)
	var intensity := clampf(height_strength * lerpf(0.55, 1.0, compression) * speed_strength, 0.0, 1.0)

	if intensity < 0.05:
		_particles.emitting = false
		return

	_particles.emitting = true
	_particles.initial_velocity_min = _velocity_min_base * lerpf(0.7, 1.15, intensity)
	_particles.initial_velocity_max = _velocity_max_base * lerpf(0.75, 1.25, intensity)
	var alpha := _alpha_base * intensity
	_particles.color = Color(_particles.color.r, _particles.color.g, _particles.color.b, alpha)
