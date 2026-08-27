class_name MissileDrone
extends "res://scripts/enemies/combat_drone.gd"

## Blue cube. Fires a wide, dodgeable 20-rocket hail with ground reticles.

const GroundReticleScript = preload("res://scripts/enemies/ground_reticle.gd")
const DroneRocketScript = preload("res://scripts/enemies/drone_rocket.gd")

const ROCKET_COUNT := 20
const ROCKET_DAMAGE := 10
const LEAD_SEC := 1.4
const SPREAD_RADIUS_M := 22.0
const HAIL_COOLDOWN_SEC := 7.0
const FALL_TELEGRAPH_SEC := 1.35

var _cooldown_left := 1.5
var _rng_hail := RandomNumberGenerator.new()


func _ready() -> void:
	_cube_color = Color(0.15, 0.45, 0.95)
	super._ready()
	add_to_group("missile_drone")
	_rng_hail.randomize()


func _update_weapons(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left > 0.0:
		return
	# Hail only while kiting inside weapon range and still in front.
	if fly_state != FlyState.KITE:
		return
	if not can_fire_weapons():
		return
	if xz_distance_to_target() > WEAPON_RANGE_M + 1.0:
		return
	_fire_hail()
	_cooldown_left = HAIL_COOLDOWN_SEC


func _fire_hail() -> void:
	var lead := _lead_point()
	var impacts := impact_points_around(lead, ROCKET_COUNT, SPREAD_RADIUS_M, _rng_hail)
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	for impact in impacts:
		var ground: Vector3 = impact
		if _terrain != null:
			ground.y = _terrain.sample_height(impact.x, impact.z)
		var reticle = GroundReticleScript.new()
		parent.add_child(reticle)
		reticle.place(ground, FALL_TELEGRAPH_SEC)
		var rocket = DroneRocketScript.new()
		parent.add_child(rocket)
		rocket.launch(ground, _terrain)


func _lead_point() -> Vector3:
	var player := _target.global_position
	var facing := _target_facing_xz()
	var vel := Vector3.ZERO
	if _target is GliderPlayer:
		vel = (_target as GliderPlayer).linear_velocity
	elif _target is CharacterBody3D:
		vel = (_target as CharacterBody3D).velocity
	elif _target is RigidBody3D:
		vel = (_target as RigidBody3D).linear_velocity
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


## Wide ring/ellipse samples with jitter so the player can slip between hits.
static func impact_points_around(
	center: Vector3,
	count: int,
	radius_m: float,
	rng: RandomNumberGenerator
) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var n := maxi(count, 1)
	for i in n:
		var angle := TAU * float(i) / float(n) + rng.randf_range(-0.08, 0.08)
		var radial := radius_m * rng.randf_range(0.35, 1.0)
		# Elliptical stretch along Z so the pattern is wide but not a solid disc.
		var x := cos(angle) * radial
		var z := sin(angle) * radial * 0.75
		points.append(center + Vector3(x, 0.0, z))
	return points
