class_name RifleBullet
extends Area3D

## Visible tracer; no gun mesh. Homes lightly on the locked pill.

const SPEED_MPS := 60.0
const LIFETIME_SEC := 2.4
const HOMING_RATE := 8.0
const HOMING_COMMIT_M := 2.0
const AIM_UP_M := 0.32
const HIT_RADIUS_M := 0.7
const DAMAGE := 20

var _target: Node3D
var _dir := Vector3.FORWARD
var _life := LIFETIME_SEC
var _spent := false
var _damage := DAMAGE
var _speed := SPEED_MPS
var _crit_chance := 0.0
var _knockback_speed := SwarmPill.HIT_KNOCKBACK_SPEED
var _bounces_left := 0
var _bounce_range := 0.0
var _hit_ids: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func launch(
	origin: Vector3,
	target: Node3D,
	initial_dir: Vector3,
	amount: int = DAMAGE,
	speed_mps: float = SPEED_MPS,
	crit_chance: float = 0.0,
	knockback_speed: float = SwarmPill.HIT_KNOCKBACK_SPEED,
	bounces: int = 0,
	bounce_range: float = 0.0
) -> void:
	global_position = origin
	_target = target
	_damage = maxi(amount, 1)
	_speed = maxf(speed_mps, 0.01)
	_crit_chance = clampf(crit_chance, 0.0, UpgradeCatalog.CRIT_CAP)
	_knockback_speed = maxf(knockback_speed, 0.0)
	_bounces_left = maxi(bounces, 0)
	_bounce_range = maxf(bounce_range, 0.0)
	_hit_ids.clear()
	_spent = false
	_life = LIFETIME_SEC
	_rng.randomize()
	if initial_dir.length_squared() > 0.0001:
		_dir = initial_dir.normalized()
	elif _aim_vector().length_squared() > 0.0001:
		_dir = _aim_vector().normalized()
	_orient()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var aim := _aim_vector()
	var dist := aim.length()
	if should_home(dist):
		_dir = _dir.lerp(aim / dist, homing_blend(delta)).normalized()
	var from := global_position
	global_position += _dir * _speed * delta
	_orient()
	_try_proximity_hit_along(from, global_position)
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _aim_vector() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		_target = null
		return Vector3.ZERO
	return aim_point_for(_target.global_position) - global_position


static func aim_point_for(target_pos: Vector3) -> Vector3:
	return target_pos + Vector3(0.0, AIM_UP_M, 0.0)


static func should_home(distance_m: float) -> bool:
	return distance_m > HOMING_COMMIT_M


static func homing_blend(delta: float) -> float:
	return 1.0 - exp(-HOMING_RATE * maxf(delta, 0.0))


func _try_proximity_hit_along(from: Vector3, to: Vector3) -> void:
	var pill := _target as SwarmPill
	if pill == null or not pill.is_alive():
		return
	var aim := aim_point_for(pill.global_position)
	var closest := Geometry3D.get_closest_point_to_segment(aim, from, to)
	if closest.distance_to(aim) > HIT_RADIUS_M:
		return
	_on_body_entered(pill)


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
	var id := pill.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true
	var hit := _resolve_hit()
	var killed := pill.take_damage(
		hit.damage, _dir, hit.is_crit, _knockback_speed, UpgradeCatalog.FAMILY_RIFLE
	)
	if killed:
		KillSparks.spawn(get_tree(), pill.global_position)
	if _try_bounce(pill.global_position):
		return
	_spent = true
	queue_free()


func _resolve_hit() -> Dictionary:
	var is_crit := AutoRifle.roll_crit(_crit_chance, _rng)
	return {
		"is_crit": is_crit,
		"damage": AutoRifle.crit_damage_for(_damage, is_crit)
	}


func _try_bounce(from: Vector3) -> bool:
	if _bounces_left <= 0:
		return false
	var pills: Array = []
	if is_inside_tree():
		pills = get_tree().get_nodes_in_group("swarm_pill")
	var next := AutoRifle.pick_bounce_target(pills, from, _bounce_range, _hit_ids, _rng)
	if next == null:
		return false
	_bounces_left -= 1
	_target = next
	_life = LIFETIME_SEC
	var aim := _aim_vector()
	if aim.length_squared() > 0.0001:
		_dir = aim.normalized()
		_orient()
	return true
