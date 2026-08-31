class_name MissileDrone
extends "res://scripts/enemies/combat_drone.gd"

## Blue cube. Fires a staggered lofted hail with player-rocket visuals.

const GroundReticleScript = preload("res://scripts/enemies/ground_reticle.gd")
const DroneRocketScript = preload("res://scripts/enemies/drone_rocket.gd")

const ROCKET_COUNT_MIN := 30
const ROCKET_COUNT_MAX := 40
const ROCKET_DAMAGE := 10
const LEAD_SEC := DroneRocketScript.FLIGHT_SEC
const SPREAD_RADIUS_GROUND_M := 4.0
const SPREAD_RADIUS_AIR_M := 4.0
const AIR_VOLLEY_CENTER_JITTER_MIN_M := 2.0
const AIR_VOLLEY_CENTER_JITTER_MAX_M := 4.0
const HAIL_COOLDOWN_SEC := 7.0
const FALL_TELEGRAPH_SEC := DroneRocketScript.FLIGHT_SEC
const STAGGER_SEC := 0.1
const SPAWN_SLOT_COUNT := 6

var _cooldown_left := 1.5
var _rng_hail := RandomNumberGenerator.new()
var _pending_offsets: Array[Vector3] = []
var _stagger_left := 0.0
var _firing_hail := false
var _hail_center_bias := Vector3.ZERO
var _hail_rockets_fired := 0


func _ready() -> void:
	_cube_color = Color(0.15, 0.45, 0.95)
	super._ready()
	add_to_group("missile_drone")
	_rng_hail.randomize()


func _update_weapons(delta: float) -> void:
	if _firing_hail:
		_tick_stagger(delta)
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left > 0.0:
		return
	# Hail while within weapon range (including after the player passes).
	if not can_fire_weapons():
		return
	_begin_hail()
	_cooldown_left = HAIL_COOLDOWN_SEC


func _begin_hail() -> void:
	var count := _rng_hail.randi_range(ROCKET_COUNT_MIN, ROCKET_COUNT_MAX)
	_pending_offsets = impact_offsets_around(count, SPREAD_RADIUS_GROUND_M, _rng_hail)
	var bias_angle := _rng_hail.randf() * TAU
	var bias_dist := _rng_hail.randf_range(
		AIR_VOLLEY_CENTER_JITTER_MIN_M,
		AIR_VOLLEY_CENTER_JITTER_MAX_M
	)
	_hail_center_bias = Vector3(cos(bias_angle) * bias_dist, 0.0, sin(bias_angle) * bias_dist)
	_firing_hail = true
	_stagger_left = 0.0
	_hail_rockets_fired = 0
	_fire_next_rocket()


func _tick_stagger(delta: float) -> void:
	if _pending_offsets.is_empty():
		_firing_hail = false
		return
	_stagger_left = maxf(_stagger_left - delta, 0.0)
	if _stagger_left > 0.0:
		return
	_fire_next_rocket()


func _fire_next_rocket() -> void:
	if _pending_offsets.is_empty():
		_firing_hail = false
		return
	var offset: Vector3 = _pending_offsets.pop_front()
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	var rocket = DroneRocketScript.new()
	parent.add_child(rocket)
	var slot_index := _hail_rockets_fired % SPAWN_SLOT_COUNT
	var spawn_slot := _get_spawn_slot(slot_index)
	var spawn_transform := _get_spawn_slot_transform(slot_index)
	_hail_rockets_fired += 1
	if uses_air_targeting():
		var lead := _lead_point_3d()
		var air_offset := air_offset_from_ground(offset, _rng_hail)
		var impact := lead + _hail_center_bias + air_offset
		rocket.launch_to_air_point(
			spawn_transform.origin,
			impact,
			spawn_transform,
			spawn_slot
		)
	else:
		var lead := _lead_point()
		var impact := lead + offset
		var ground := impact
		if _terrain != null:
			ground.y = _terrain.sample_height(impact.x, impact.z)
		var reticle = GroundReticleScript.new()
		parent.add_child(reticle)
		reticle.place(ground, FALL_TELEGRAPH_SEC)
		rocket.launch_from_drone(
			spawn_transform.origin,
			ground,
			_terrain,
			spawn_transform,
			spawn_slot
		)
	_stagger_left = STAGGER_SEC
	if _pending_offsets.is_empty():
		_firing_hail = false


func _get_spawn_slot(slot_index: int) -> Node3D:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return null
	var slot_name := "Missile_Projectile_%d" % (slot_index + 1)
	return visual.find_child(slot_name, true, false) as Node3D


func _get_spawn_slot_transform(slot_index: int) -> Transform3D:
	var slot := _get_spawn_slot(slot_index)
	if slot != null:
		return slot.global_transform
	return global_transform


func _target_velocity() -> Vector3:
	if _target is GliderPlayer:
		return (_target as GliderPlayer).linear_velocity
	if _target is CharacterBody3D:
		return (_target as CharacterBody3D).velocity
	if _target is RigidBody3D:
		return (_target as RigidBody3D).linear_velocity
	return Vector3.ZERO


func _lead_point() -> Vector3:
	var player := _target.global_position
	var facing := _target_facing_xz()
	var vel := _target_velocity()
	var horiz := Vector3(vel.x, 0.0, vel.z)
	var lead := player + horiz * LEAD_SEC
	# Keep the volley ahead of the player so rockets don't land behind.
	var ahead := Vector3(lead.x - player.x, 0.0, lead.z - player.z)
	if ahead.dot(facing) < 4.0:
		lead = player + facing * maxf(horiz.length() * LEAD_SEC, 10.0)
	if _terrain != null:
		lead.y = _terrain.sample_height(lead.x, lead.z)
	else:
		lead.y = player.y
	return lead


func _lead_point_3d() -> Vector3:
	var player := _target.global_position
	var facing := _target_facing_xz()
	var vel := _target_velocity()
	var lead := player + vel * LEAD_SEC
	var ahead := Vector3(lead.x - player.x, 0.0, lead.z - player.z)
	if ahead.dot(facing) < 4.0:
		var horiz := Vector3(vel.x, 0.0, vel.z)
		lead = player + facing * maxf(horiz.length() * LEAD_SEC, 10.0)
		lead.y = player.y + vel.y * LEAD_SEC
	return lead


## Wide ring/ellipse offsets with jitter so the player can slip between hits.
static func impact_offsets_around(
	count: int,
	radius_m: float,
	rng: RandomNumberGenerator
) -> Array[Vector3]:
	var offsets: Array[Vector3] = []
	var n := maxi(count, 1)
	for i in n:
		var angle := TAU * float(i) / float(n) + rng.randf_range(-0.08, 0.08)
		var radial := radius_m * rng.randf_range(0.35, 1.0)
		# Elliptical stretch along Z so the pattern is wide but not a solid disc.
		var x := cos(angle) * radial
		var z := sin(angle) * radial * 0.75
		offsets.append(Vector3(x, 0.0, z))
	return offsets


static func air_offset_from_ground(offset: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var air_scale := SPREAD_RADIUS_AIR_M / SPREAD_RADIUS_GROUND_M
	var y := rng.randf_range(-0.5, 0.5) * SPREAD_RADIUS_AIR_M
	return Vector3(offset.x * air_scale, y, offset.z * air_scale)


static func air_impact_offsets_around(
	count: int,
	radius_m: float,
	rng: RandomNumberGenerator
) -> Array[Vector3]:
	var offsets: Array[Vector3] = []
	for offset in impact_offsets_around(count, SPREAD_RADIUS_GROUND_M, rng):
		var air := air_offset_from_ground(offset, rng)
		var flat := Vector3(air.x, 0.0, air.z)
		if flat.length() > radius_m + 0.01:
			air = air * (radius_m / flat.length())
		offsets.append(air)
	return offsets


static func impact_points_around(
	center: Vector3,
	count: int,
	radius_m: float,
	rng: RandomNumberGenerator
) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for offset in impact_offsets_around(count, radius_m, rng):
		points.append(center + offset)
	return points
