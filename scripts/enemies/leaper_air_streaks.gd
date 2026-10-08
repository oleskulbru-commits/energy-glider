class_name LeaperAirStreaks
extends Node3D

## Body streaks while the leaper is in its leap arc.

const SAND_PUFF_PATH := "res://assets/vfx/effect_textures/radial_smoke_puff.png"

const BASE_AMOUNT := 240
const BASE_LIFETIME := 0.95
const BASE_VELOCITY := 22.0
const STREAK_COLOR := Color(0.82, 0.52, 1.0, 0.92)
const EMISSION_EXTENTS := Vector3(1.1, 1.35, 1.6)
const STREAK_SIZE := Vector2(0.09, 1.65)

var _particles: CPUParticles3D
var _host: LeaperPill
var _last_pos := Vector3.ZERO
var _has_last := false


func _ready() -> void:
	_host = _find_host()
	_particles = CPUParticles3D.new()
	_particles.name = "Streaks"
	_particles.emitting = false
	_particles.amount = BASE_AMOUNT
	_particles.lifetime = BASE_LIFETIME
	_particles.explosiveness = 0.0
	_particles.randomness = 0.2
	_particles.direction = Vector3(0.0, -1.0, 0.0)
	_particles.spread = 2.0
	_particles.gravity = Vector3.ZERO
	_particles.initial_velocity_min = BASE_VELOCITY * 0.75
	_particles.initial_velocity_max = BASE_VELOCITY * 1.05
	_particles.scale_amount_min = 1.1
	_particles.scale_amount_max = 1.85
	_particles.particle_flag_align_y = true
	_particles.color = STREAK_COLOR
	_particles.local_coords = true
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = EMISSION_EXTENTS
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	_configure_particle_mesh()


func _process(_delta: float) -> void:
	_update_streaks()


func _physics_process(_delta: float) -> void:
	_update_streaks()


func _update_streaks() -> void:
	if _particles == null:
		return
	if _host == null or not is_instance_valid(_host):
		_host = _find_host()
	if _host == null:
		_particles.emitting = false
		return

	var airborne := _host.leap_state == LeaperPill.LeapState.LEAP
	if not airborne:
		_particles.emitting = false
		_has_last = false
		return

	var travel := _host.global_position - _last_pos if _has_last else Vector3.ZERO
	_last_pos = _host.global_position
	_has_last = true
	if travel.length_squared() < 0.0001:
		if _host.practice_in_place:
			travel = Vector3.UP
		else:
			var along := Vector3(
				_host._leap_impact.x - _host._leap_origin.x,
				0.0,
				_host._leap_impact.z - _host._leap_origin.z
			)
			if along.length_squared() < 0.0001:
				travel = Vector3.UP
			else:
				travel = along

	var local_travel := global_transform.basis.inverse() * travel
	if local_travel.length_squared() < 0.0001:
		local_travel = Vector3(0.0, 1.0, 0.0)

	_particles.emitting = true
	_particles.direction = -local_travel.normalized()
	var speed := travel.length() / maxf(get_physics_process_delta_time(), 0.001)
	var boost := clampf(speed / 40.0, 0.65, 2.5)
	_particles.amount = maxi(1, int(round(float(BASE_AMOUNT) * boost)))
	var alpha := clampf(STREAK_COLOR.a * boost, 0.45, 1.0)
	_particles.color = Color(STREAK_COLOR.r, STREAK_COLOR.g, STREAK_COLOR.b, alpha)


func _find_host() -> LeaperPill:
	var node: Node = self
	while node != null:
		if node is LeaperPill:
			return node as LeaperPill
		node = node.get_parent()
	return null


func _configure_particle_mesh() -> void:
	var quad := QuadMesh.new()
	quad.size = STREAK_SIZE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load(SAND_PUFF_PATH) as Texture2D
	quad.material = mat
	_particles.mesh = quad
	_particles.visibility_aabb = AABB(Vector3(-14.0, -10.0, -14.0), Vector3(28.0, 20.0, 28.0))
