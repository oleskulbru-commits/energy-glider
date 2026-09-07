class_name SpeedWindStreaks
extends Node3D

## Camera-attached wind streaks that fade in near the current mode speed cap.

const GliderPhysicsScript := preload("res://scripts/player/glider_physics.gd")

const BASE_AMOUNT := 96
const BASE_LIFETIME := 0.85
const BASE_VELOCITY := 28.0
const STREAK_COLOR := Color(0.78, 0.62, 0.4, 0.22)
const EMISSION_EXTENTS := Vector3(14.0, 5.0, 10.0)
const MIN_SPEED_MPS := 8.0
const BLEND_START := 0.88
const BLEND_END := 0.98

var _particles: CPUParticles3D
var _player: GliderPlayer
var _amount_base := BASE_AMOUNT


func _ready() -> void:
	_particles = CPUParticles3D.new()
	_particles.name = "Streaks"
	_particles.emitting = false
	_particles.amount = BASE_AMOUNT
	_particles.lifetime = BASE_LIFETIME
	_particles.explosiveness = 0.0
	_particles.randomness = 0.4
	_particles.direction = Vector3(0.0, 0.0, -1.0)
	_particles.spread = 8.0
	_particles.gravity = Vector3.ZERO
	_particles.initial_velocity_min = BASE_VELOCITY * 0.9
	_particles.initial_velocity_max = BASE_VELOCITY * 1.1
	_particles.scale_amount_min = 0.45
	_particles.scale_amount_max = 1.05
	_particles.color = STREAK_COLOR
	_particles.local_coords = false
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = EMISSION_EXTENTS
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	_configure_particle_mesh()
	_amount_base = _particles.amount


func _physics_process(_delta: float) -> void:
	if _particles == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()
	if _player == null:
		_particles.emitting = false
		return
	if _player.is_run_ended():
		_particles.emitting = false
		return

	var speed := _player.get_horizontal_speed()
	if speed < MIN_SPEED_MPS:
		_particles.emitting = false
		return
	if not _player.is_grounded() and not _player.is_gliding():
		_particles.emitting = false
		return

	var cap := GliderPhysicsScript.flat_max_speed(
		_player.is_boost_active(),
		_player.get_speed_bonus()
	)
	var blend := compute_speed_streak_blend(speed, cap, BLEND_START, BLEND_END)
	if blend <= 0.02:
		_particles.emitting = false
		return

	var travel := MathUtil.horizontal(_player.velocity)
	if travel.length_squared() < 0.01:
		_particles.emitting = false
		return

	_particles.emitting = true
	_particles.direction = -travel.normalized()
	_particles.amount = maxi(1, int(round(float(_amount_base) * blend)))
	_particles.lifetime = BASE_LIFETIME * lerpf(0.65, 1.0, blend)
	_particles.initial_velocity_min = BASE_VELOCITY * lerpf(0.75, 1.0, blend)
	_particles.initial_velocity_max = BASE_VELOCITY * lerpf(0.85, 1.15, blend)
	var alpha := STREAK_COLOR.a * blend
	_particles.color = Color(STREAK_COLOR.r, STREAK_COLOR.g, STREAK_COLOR.b, alpha)


static func compute_speed_streak_blend(
	speed: float,
	cap: float,
	start: float = BLEND_START,
	end: float = BLEND_END
) -> float:
	if cap <= 0.0 or speed <= 0.0:
		return 0.0
	return smoothstep(start, end, speed / cap)


func _resolve_player() -> GliderPlayer:
	var camera := get_parent()
	if camera == null:
		return null
	return camera.get_parent() as GliderPlayer


func _configure_particle_mesh() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.045)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	_particles.mesh = quad
	_particles.visibility_aabb = AABB(Vector3(-18.0, -8.0, -14.0), Vector3(36.0, 16.0, 28.0))
