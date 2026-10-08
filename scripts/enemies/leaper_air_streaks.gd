class_name LeaperAirStreaks
extends Node3D

## Body streaks while the leaper is in its leap arc.

const SAND_PUFF_PATH := "res://assets/vfx/effect_textures/radial_smoke_puff.png"

const BASE_AMOUNT := 240
const BASE_LIFETIME := 0.95
const BASE_VELOCITY := 22.0
const STREAK_COLOR := Color(0.86, 0.68, 0.32, 0.88)
const EMISSION_EXTENTS := Vector3(1.1, 1.35, 1.6)
const STREAK_SIZE := Vector2(0.09, 3.3)

var _particles: CPUParticles3D
var _host: LeaperPill
var _anim: LeaperAnimController
var _last_pos := Vector3.ZERO
var _has_last := false
var _was_emitting := false


func _ready() -> void:
	_host = _find_host()
	_anim = _find_anim()
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


func _physics_process(_delta: float) -> void:
	_update_streaks(_delta)


func _update_streaks(delta: float) -> void:
	if _particles == null:
		return
	if _host == null or not is_instance_valid(_host):
		_host = _find_host()
	if _anim == null or not is_instance_valid(_anim):
		_anim = _find_anim()
	if _host == null:
		_stop_streaks()
		return

	var streak_window := (
		_host.leap_state == LeaperPill.LeapState.LEAP
		and _anim != null
		and _anim.is_air_streak_active()
	)
	if not streak_window:
		_stop_streaks()
		return

	var world_motion := _host.leap_motion_direction()
	if world_motion.length_squared() < 0.0001:
		world_motion = Vector3.UP

	var pos := _host.global_position
	var speed := 0.0
	if _has_last and delta > 0.0:
		speed = pos.distance_to(_last_pos) / delta
	elif _host._leap_sec > 0.001:
		speed = _host._leap_origin.distance_to(_host._leap_impact) / _host._leap_sec
	_last_pos = pos
	_has_last = true

	var local_motion := global_transform.basis.inverse() * world_motion
	if local_motion.length_squared() < 0.0001:
		local_motion = Vector3(0.0, 1.0, 0.0)

	_particles.emitting = true
	_was_emitting = true
	_particles.direction = -local_motion.normalized()
	var boost := clampf(speed / 40.0, 0.65, 2.5)
	_particles.amount = maxi(1, int(round(float(BASE_AMOUNT) * boost)))
	var alpha := clampf(STREAK_COLOR.a * boost, 0.45, 1.0)
	_particles.color = Color(STREAK_COLOR.r, STREAK_COLOR.g, STREAK_COLOR.b, alpha)


func _stop_streaks() -> void:
	_has_last = false
	if _particles == null:
		return
	if _was_emitting or _particles.emitting:
		_particles.emitting = false
	_was_emitting = false


func _find_host() -> LeaperPill:
	var node: Node = self
	while node != null:
		if node is LeaperPill:
			return node as LeaperPill
		node = node.get_parent()
	return null


func _find_anim() -> LeaperAnimController:
	var skin := get_parent()
	if skin == null:
		return null
	return skin.get_node_or_null("LeaperAnimController") as LeaperAnimController


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
	_particles.visibility_aabb = AABB(Vector3(-18.0, -14.0, -18.0), Vector3(36.0, 28.0, 36.0))
