class_name HoverDust
extends Node3D

const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")

const GROUND_OFFSET := 0.05
const RAY_LENGTH := 24.0
const BASE_AMOUNT := 28
const BASE_LIFETIME := 0.65
const BASE_VELOCITY_MIN := 0.6
const BASE_VELOCITY_MAX := 1.8
const BASE_ALPHA := 0.45

var _particles: CPUParticles3D


static func configure_sand_mesh(particles: CPUParticles3D) -> void:
	SandParticleVfx.apply_to(particles, SandParticleVfx.GLIDER_QUAD_SIZE)


static func configure_hover_stream(particles: CPUParticles3D) -> void:
	configure_sand_mesh(particles)
	var fade_ramp: Gradient = SandParticleVfx.make_fade_ramp()
	particles.emitting = false
	particles.amount = BASE_AMOUNT
	particles.lifetime = BASE_LIFETIME
	particles.explosiveness = 0.12
	particles.randomness = 0.45
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 75.0
	particles.gravity = Vector3(0.0, -1.2, 0.0)
	particles.initial_velocity_min = BASE_VELOCITY_MIN
	particles.initial_velocity_max = BASE_VELOCITY_MAX
	particles.scale_amount_min = 0.15
	particles.scale_amount_max = 0.35
	particles.color = Color(1.0, 1.0, 1.0, BASE_ALPHA)
	particles.color_ramp = fade_ramp
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.425, 0.025, 0.85)


static func configure_impact_burst(particles: CPUParticles3D, intensity: float = 1.15) -> void:
	configure_sand_mesh(particles)
	var fade_ramp: Gradient = SandParticleVfx.make_fade_ramp()
	var clamped := clampf(intensity, 0.5, 2.0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = int(round(lerpf(float(BASE_AMOUNT), 56.0, clamped - 0.5)))
	particles.lifetime = BASE_LIFETIME
	particles.explosiveness = 0.92
	particles.randomness = 0.45
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 75.0
	particles.gravity = Vector3(0.0, -1.2, 0.0)
	var velocity_scale := lerpf(2.4, 4.8, clamped - 0.5)
	particles.initial_velocity_min = BASE_VELOCITY_MIN * velocity_scale
	particles.initial_velocity_max = BASE_VELOCITY_MAX * velocity_scale
	particles.scale_amount_min = 0.15
	particles.scale_amount_max = 0.35
	var alpha := lerpf(0.55, 0.82, clamped - 0.5)
	particles.color = Color(1.0, 1.0, 1.0, alpha)
	particles.color_ramp = fade_ramp
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.08


func _ready() -> void:
	top_level = true
	_particles = CPUParticles3D.new()
	configure_hover_stream(_particles)
	add_child(_particles)


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
	var player := get_parent() as GliderPlayer
	if player == null or _particles == null:
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
	_particles.initial_velocity_min = BASE_VELOCITY_MIN * lerpf(0.7, 1.15, intensity)
	_particles.initial_velocity_max = BASE_VELOCITY_MAX * lerpf(0.75, 1.25, intensity)
	_particles.color = Color(1.0, 1.0, 1.0, BASE_ALPHA * intensity)
