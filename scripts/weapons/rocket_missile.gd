class_name RocketMissile
extends Area3D

## Lofted homing capsule. Boosts up, then dives at the locked pill.

const SPEED_MPS := 20.0
const LIFETIME_SEC := 8.0
const BOOST_SEC := 0.3
const HOMING := 0.85
const DAMAGE := 20
const KNOCKBACK_SPEED := 20.0
const AIM_UP_M := 0.7


var _target: Node3D
var _dir := Vector3.UP
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
	knockback_speed: float = KNOCKBACK_SPEED
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
	_rng.randomize()
	_orient()


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
	if _target == null or not is_instance_valid(_target):
		_target = null
		return Vector3.ZERO
	return _target.global_position + Vector3(0.0, AIM_UP_M, 0.0) - global_position


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
	pill.take_damage(hit.damage, _dir, hit.is_crit, _knockback_speed)
	RocketExplosion.spawn(get_tree(), global_position)
	_spent = true
	queue_free()


func _resolve_hit() -> Dictionary:
	var is_crit := AutoRifle.roll_crit(_crit_chance, _rng)
	return {
		"is_crit": is_crit,
		"damage": AutoRifle.crit_damage_for(_damage, is_crit)
	}
