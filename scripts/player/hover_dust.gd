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
const DUST_COLOR := Color(0.78, 0.62, 0.4, BASE_ALPHA)

var _particles: CPUParticles3D


func _ready() -> void:
	top_level = true
	_particles = CPUParticles3D.new()
	_particles.emitting = false
	_particles.amount = BASE_AMOUNT
	_particles.lifetime = BASE_LIFETIME
	_particles.explosiveness = 0.12
	_particles.randomness = 0.45
	_particles.direction = Vector3(0.0, 1.0, 0.0)
	_particles.spread = 75.0
	_particles.gravity = Vector3(0.0, -1.2, 0.0)
	_particles.initial_velocity_min = BASE_VELOCITY_MIN
	_particles.initial_velocity_max = BASE_VELOCITY_MAX
	_particles.scale_amount_min = 0.1
	_particles.scale_amount_max = 0.22
	_particles.color = DUST_COLOR
	_particles.local_coords = false
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(0.425, 0.025, 0.85)
	add_child(_particles)
	_configure_particle_mesh()


func _configure_particle_mesh() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	_particles.mesh = quad
	_particles.visibility_aabb = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 3.0, 4.0))


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
	_particles.color = Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, BASE_ALPHA * intensity)
