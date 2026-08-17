class_name SwarmPill
extends CharacterBody3D

## Simple westbound stream enemy: red capsule that crawls toward the player.

const HOVER_OFFSET_M := 1.1
const BEHIND_MARGIN_M := 50.0
const KNOCKBACK_SPEED := 10.0
const KNOCKBACK_UP_SPEED := 1.5
const DAMAGE_INTERVAL_SEC := 0.5
const CONTACT_DAMAGE := 5
const CONTACT_RADIUS_M := 1.35
## Ignore hits when the player is clearly jumping/flying over the pill.
const CONTACT_MAX_ABOVE_M := 1.2
const DEFAULT_SPEED := 3.5

var move_speed := DEFAULT_SPEED
var contact_damage := CONTACT_DAMAGE
var contact_radius_m := CONTACT_RADIUS_M
var contact_max_above_m := CONTACT_MAX_ABOVE_M

var _target: Node3D
var _terrain: TerrainManager
var _in_contact := false
var _damage_timer := 0.0
var _last_seek_dir := Vector3.ZERO
## Subclasses (charger) multiply base move_speed while aggro'd.
var chase_speed_mult := 1.0


func _ready() -> void:
	add_to_group("swarm_pill")
	motion_mode = MOTION_MODE_FLOATING


func configure(terrain: TerrainManager, target: Node3D, speed: float = DEFAULT_SPEED) -> void:
	_terrain = terrain
	_target = target
	move_speed = speed
	_snap_to_terrain()


func set_target(target: Node3D) -> void:
	_target = target


func set_move_speed(speed: float) -> void:
	move_speed = speed


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	# Fallen behind (east of player past margin) — despawn.
	if global_position.x > _target.global_position.x + BEHIND_MARGIN_M:
		queue_free()
		return

	_update_chase(delta)

	var seek := Vector3(to_target.x, 0.0, to_target.z)
	if seek.length_squared() > 0.01:
		_last_seek_dir = seek.normalized()
		velocity = _last_seek_dir * _get_move_speed()
	elif _last_seek_dir.length_squared() > 0.01:
		# On top of / overlapping the player — keep charging; don't drop to a standstill.
		velocity = _last_seek_dir * _get_move_speed()
	else:
		velocity = Vector3.ZERO

	move_and_slide()
	_snap_to_terrain()
	_orient_to_velocity()
	_update_contact(delta)


## Subclasses adjust chase behavior (e.g. aggro speed ramp).
func _update_chase(_delta: float) -> void:
	pass


func _get_move_speed() -> float:
	return move_speed * chase_speed_mult


func _snap_to_terrain() -> void:
	if _terrain == null:
		return
	var ground_y := _terrain.sample_height(global_position.x, global_position.z)
	global_position.y = ground_y + HOVER_OFFSET_M


func _orient_to_velocity() -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.04:
		return
	rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 0.2)


## XZ proximity with a height gate so airborne flyovers don't clip/damage.
func _update_contact(delta: float) -> void:
	var touching := _is_touching_target()
	if touching:
		if not _in_contact:
			_tick_contact()
			_damage_timer = DAMAGE_INTERVAL_SEC
		else:
			_damage_timer = maxf(_damage_timer - delta, 0.0)
			if _damage_timer <= 0.0:
				_tick_contact()
				_damage_timer = DAMAGE_INTERVAL_SEC
	else:
		_damage_timer = 0.0
	_in_contact = touching


func _is_touching_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var delta := _target.global_position - global_position
	# Player jumping / gliding above the pill — no shove or damage.
	if delta.y > contact_max_above_m:
		return false
	var flat := Vector2(delta.x, delta.z)
	return flat.length() <= contact_radius_m


static func is_vertical_contact(player_y: float, pill_y: float, max_above_m: float = CONTACT_MAX_ABOVE_M) -> bool:
	return (player_y - pill_y) <= max_above_m


func _tick_contact() -> void:
	_apply_knockback()
	_apply_contact_damage()


func _apply_knockback() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var away := knockback_velocity_for(global_position, _target.global_position)
	if _target.has_method("queue_knockback"):
		_target.queue_knockback(away)
	elif _target is RigidBody3D:
		var rigid := _target as RigidBody3D
		rigid.apply_central_impulse(away * maxf(rigid.mass, 0.01))


func _apply_contact_damage() -> void:
	var health := get_tree().get_first_node_in_group("player_health")
	if health == null or not health.has_method("take_damage"):
		return
	health.take_damage(contact_damage)


## Horizontal shove (+ slight up) applied as velocity delta via GliderPlayer.queue_knockback.
static func knockback_velocity_for(
	pill_pos: Vector3,
	body_pos: Vector3,
	speed: float = KNOCKBACK_SPEED,
	up: float = KNOCKBACK_UP_SPEED
) -> Vector3:
	var away := body_pos - pill_pos
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(1.0, 0.0, 0.0)
	else:
		away = away.normalized()
	return Vector3(away.x * speed, up, away.z * speed)


## Legacy impulse helper (mass-scaled); prefer knockback_velocity_for + queue_knockback.
static func knockback_impulse_for(
	pill_pos: Vector3,
	body_pos: Vector3,
	body_mass: float,
	impulse_strength: float = 7.5,
	up: float = 0.22
) -> Vector3:
	var vel := knockback_velocity_for(pill_pos, body_pos, impulse_strength, up * impulse_strength)
	return vel * maxf(body_mass, 0.01)


## Westbound spawn X (more negative = ahead) and lateral Z offset.
static func spawn_offset_xz(
	ahead_min_m: float,
	ahead_max_m: float,
	spread_m: float,
	rng: RandomNumberGenerator
) -> Vector2:
	var ahead := rng.randf_range(ahead_min_m, ahead_max_m)
	var z_off := rng.randf_range(-spread_m, spread_m)
	return Vector2(-ahead, z_off)


static func active_cap_for_level(level: int, min_cap: int = 8, max_cap: int = 60) -> int:
	var t := clampf(float(level - 1) / 39.0, 0.0, 1.0)
	return int(roundf(lerpf(float(min_cap), float(max_cap), t)))


static func move_speed_for_level(level: int) -> float:
	var t := clampf(float(level - 1) / 39.0, 0.0, 1.0)
	return lerpf(3.0, 5.0, t)


static func ahead_range_for_level(level: int) -> Vector2:
	var t := clampf(float(level - 1) / 39.0, 0.0, 1.0)
	var min_ahead := lerpf(40.0, 30.0, t)
	var max_ahead := lerpf(90.0, 70.0, t)
	return Vector2(min_ahead, max_ahead)


static func z_spread_for_level(level: int) -> float:
	var t := clampf(float(level - 1) / 39.0, 0.0, 1.0)
	return lerpf(25.0, 55.0, t)
