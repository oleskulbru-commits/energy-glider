class_name RocketMissile
extends Area3D

## Lofted homing capsule. Boosts up, then dives at the locked enemy.

const AutoRocketScript := preload("res://scripts/weapons/auto_rocket.gd")

const SPEED_MPS := 35.0
const LIFETIME_SEC := 8.0
const LOFT_M := 6.0
const BOOST_SEC := LOFT_M / SPEED_MPS
const HOMING := 0.85
const DAMAGE := 18
const KNOCKBACK_SPEED := 20.0
const AIM_UP_M := 0.7


var _target: Node3D
var _dir := Vector3.UP
## XZ facing at fire time — used for retarget (loft `_dir` is UP and has no XZ).
var _launch_facing := Vector3(-1.0, 0.0, 0.0)
var _life := LIFETIME_SEC
var _boost_left := BOOST_SEC
var _spent := false
var _damage := DAMAGE
var _speed := SPEED_MPS
var _crit_chance := 0.0
var _knockback_speed := KNOCKBACK_SPEED
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func launch(
	origin: Vector3,
	target: Node3D,
	amount: int = DAMAGE,
	speed_mps: float = SPEED_MPS,
	crit_chance: float = 0.0,
	knockback_speed: float = KNOCKBACK_SPEED,
	facing_xz: Vector3 = Vector3.ZERO
) -> void:
	global_position = origin
	_target = target
	_damage = maxi(amount, 1)
	_speed = maxf(speed_mps, 0.01)
	_crit_chance = clampf(crit_chance, 0.0, UpgradeCatalog.CRIT_CAP)
	_knockback_speed = maxf(knockback_speed, 0.0)
	_spent = false
	_life = LIFETIME_SEC
	_boost_left = BOOST_SEC
	_dir = Vector3.UP
	_launch_facing = _resolve_launch_facing(origin, target, facing_xz)
	_rng.randomize()
	_orient()


func _resolve_launch_facing(origin: Vector3, target: Node3D, facing_xz: Vector3) -> Vector3:
	var facing := Vector3(facing_xz.x, 0.0, facing_xz.z)
	if facing.length_squared() > 0.0001:
		return facing.normalized()
	if target != null and is_instance_valid(target):
		var to := Vector3(target.global_position.x - origin.x, 0.0, target.global_position.z - origin.z)
		if to.length_squared() > 0.0001:
			return to.normalized()
	return Vector3(-1.0, 0.0, 0.0)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_boost_left = maxf(_boost_left - delta, 0.0)
	if _boost_left > 0.0:
		_dir = Vector3.UP
	else:
		var aim := _aim_vector()
		if aim.length_squared() > 0.0001:
			_dir = _dir.lerp(aim.normalized(), HOMING).normalized()
	global_position += _dir * _speed * delta
	_orient()
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _aim_vector() -> Vector3:
	if not _is_lock_alive():
		_retarget()
	if _target == null or not is_instance_valid(_target):
		_target = null
		return Vector3.ZERO
	return _target.global_position + Vector3(0.0, AIM_UP_M, 0.0) - global_position


func _is_lock_alive() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if _target is SwarmPill:
		return (_target as SwarmPill).is_alive()
	return true


func _retarget() -> void:
	_target = null
	var tree := get_tree()
	if tree == null:
		return
	_target = AutoRocketScript.pick_best_target(
		tree.get_nodes_in_group("swarm_pill"),
		global_position,
		_retarget_facing(),
		AutoRocketScript.RANGE_M
	)


func _retarget_facing() -> Vector3:
	var launch := Vector3(_launch_facing.x, 0.0, _launch_facing.z)
	if launch.length_squared() > 0.0001:
		return launch.normalized()
	var motion := Vector3(_dir.x, 0.0, _dir.z)
	if motion.length_squared() > 0.0001:
		return motion.normalized()
	return Vector3(-1.0, 0.0, 0.0)


## Test/helper: clear a dead lock and pick a new living candidate.
func retarget_if_needed() -> Node3D:
	if not _is_lock_alive():
		_retarget()
	return _target


func _orient() -> void:
	if _dir.length_squared() < 0.0001:
		return
	if absf(_dir.dot(Vector3.UP)) > 0.98:
		look_at(global_position + _dir, Vector3.FORWARD)
	else:
		look_at(global_position + _dir, Vector3.UP)


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	var pill := body as SwarmPill
	if pill == null or not pill.is_alive():
		return
	var hit := _resolve_hit()
	pill.take_damage(hit.damage, _dir, hit.is_crit, _knockback_speed, UpgradeCatalog.FAMILY_ROCKET)
	RocketExplosion.spawn(get_tree(), global_position)
	_spent = true
	queue_free()


func _resolve_hit() -> Dictionary:
	var is_crit := AutoRifle.roll_crit(_crit_chance, _rng)
	return {
		"is_crit": is_crit,
		"damage": AutoRifle.crit_damage_for(_damage, is_crit)
	}
