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
	if player.terrain_manager_path != NodePath():
		var terrain := player.get_node_or_null(player.terrain_manager_path) as TerrainManager
		if terrain != null:
			var world_x := player.global_position.x
			var world_z := player.global_position.z
			var height := terrain.sample_height(world_x, world_z)
			return {
				"position": Vector3(world_x, height, world_z),
				"normal": terrain.sample_normal(world_x, world_z, 1.5),
			}

	var world := get_world_3d()
	if world == null:
		return {}

	var from := player.global_position + Vector3(0.0, 2.0, 0.0)
	var to := from + Vector3.DOWN * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}

	return {
		"position": hit.position,
		"normal": hit.normal.normalized(),
	}


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
	var basis := Basis()
	basis.y = surface_normal
	basis.x = Vector3.UP.cross(surface_normal)
	if basis.x.length_squared() < 0.0001:
		basis.x = Vector3.RIGHT.cross(surface_normal)
	basis.x = basis.x.normalized()
	basis.z = basis.x.cross(basis.y)
	global_basis = basis

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
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var speed_strength := clampf(horizontal_speed / 8.0, 0.35, 1.0)
	var intensity := clampf(height_strength * lerpf(0.55, 1.0, compression) * speed_strength, 0.0, 1.0)

	if intensity < 0.05:
		_particles.emitting = false
		return

	_particles.emitting = true
	_particles.initial_velocity_min = BASE_VELOCITY_MIN * lerpf(0.7, 1.15, intensity)
	_particles.initial_velocity_max = BASE_VELOCITY_MAX * lerpf(0.75, 1.25, intensity)
	_particles.color = Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, BASE_ALPHA * intensity)
