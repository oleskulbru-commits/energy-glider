class_name SpeedWindStreaks
extends Node3D

## Wind streaks that ramp with speed. Camera volume plus optional hull emitter.

const GliderPhysicsScript := preload("res://scripts/player/glider_physics.gd")
const SAND_PUFF_PATH := "res://assets/vfx/effect_textures/radial_smoke_puff.png"

const BASE_AMOUNT := 128
const HULL_AMOUNT := 48
const BASE_LIFETIME := 0.55
const BASE_VELOCITY := 38.0
const STREAK_COLOR := Color(0.86, 0.72, 0.48, 0.55)
const EMISSION_EXTENTS := Vector3(10.0, 4.0, 8.0)
const HULL_EXTENTS := Vector3(1.4, 0.55, 2.2)
const MIN_SPEED_MPS := 8.0
const BLEND_START := 0.32
const BLEND_END := 0.82
const CAMERA_DIRECTION := Vector3(0.0, 0.0, 1.0)
const PUFF_SIZE := Vector2(0.1, 0.1)
const HULL_STREAK_SIZE := Vector2(0.06, 0.85)

@export var hull_mode := false

var _particles: CPUParticles3D
var _player: GliderPlayer
var _amount_base := BASE_AMOUNT


func _ready() -> void:
	_particles = CPUParticles3D.new()
	_particles.name = "Streaks"
	_particles.emitting = false
	_amount_base = HULL_AMOUNT if hull_mode else BASE_AMOUNT
	_particles.amount = _amount_base
	_particles.lifetime = BASE_LIFETIME
	_particles.explosiveness = 0.0
	_particles.randomness = 0.25
	_particles.direction = CAMERA_DIRECTION
	_particles.spread = 2.0 if hull_mode else 3.0
	_particles.gravity = Vector3.ZERO
	_particles.initial_velocity_min = BASE_VELOCITY * 0.9
	_particles.initial_velocity_max = BASE_VELOCITY * 1.15
	_particles.scale_amount_min = 0.75 if hull_mode else 0.1
	_particles.scale_amount_max = 1.25 if hull_mode else 0.22
	_particles.particle_flag_align_y = hull_mode
	_particles.color = STREAK_COLOR
	_particles.local_coords = not hull_mode
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = HULL_EXTENTS if hull_mode else EMISSION_EXTENTS
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	_configure_particle_mesh()


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
	if hull_mode:
		_particles.direction = -travel.normalized()
	else:
		_particles.direction = CAMERA_DIRECTION
	_particles.amount = maxi(1, int(round(float(_amount_base) * blend)))
	_particles.lifetime = BASE_LIFETIME * lerpf(0.65, 1.0, blend)
	_particles.initial_velocity_min = BASE_VELOCITY * lerpf(0.75, 1.0, blend)
	_particles.initial_velocity_max = BASE_VELOCITY * lerpf(0.85, 1.2, blend)
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
	var node: Node = self
	while node != null:
		if node is GliderPlayer:
			return node as GliderPlayer
		node = node.get_parent()
	return null


func _configure_particle_mesh() -> void:
	var quad := QuadMesh.new()
	quad.size = HULL_STREAK_SIZE if hull_mode else PUFF_SIZE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = (
		BaseMaterial3D.BILLBOARD_DISABLED if hull_mode else BaseMaterial3D.BILLBOARD_PARTICLES
	)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load(SAND_PUFF_PATH) as Texture2D
	quad.material = mat
	_particles.mesh = quad
	_particles.visibility_aabb = AABB(Vector3(-18.0, -8.0, -14.0), Vector3(36.0, 16.0, 28.0))
