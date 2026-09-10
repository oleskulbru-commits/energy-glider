class_name RifleBullet
extends Area3D

## Visible tracer; no gun mesh. Homes on the lock's hitbox center.

const SPEED_MPS := 60.0
const LIFETIME_SEC := 2.4
const HOMING_RATE := 8.0
const HOMING_COMMIT_M := 2.0
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
	if dist > 0.0001:
		var desired := aim / dist
		var center := global_position + aim
		var radius := hit_radius_for(_target)
		if (
			should_snap_home(dist)
			or not heading_hits_sphere(global_position, _dir, center, radius)
		):
			_dir = desired
		elif should_home(dist):
			_dir = _dir.lerp(desired, homing_blend(delta)).normalized()
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
	return aim_point_for(_target) - global_position


static func aim_point_for(target: Node3D) -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	if target is SwarmPill:
		return (target as SwarmPill).hit_center()
	return target.global_position


static func hit_radius_for(target: Node3D) -> float:
	var radius := HIT_RADIUS_M
	if target is SwarmPill:
		radius = maxf(radius, (target as SwarmPill).hit_radius())
	return radius


static func should_home(distance_m: float) -> bool:
	return distance_m > HOMING_COMMIT_M


static func should_snap_home(distance_m: float) -> bool:
	return distance_m > 0.0 and distance_m <= HOMING_COMMIT_M


## True if flying `dir` from `origin` will pass through the hit sphere.
static func heading_hits_sphere(
	origin: Vector3, dir: Vector3, center: Vector3, radius: float
) -> bool:
	var rad := maxf(radius, 0.0)
	if dir.length_squared() < 0.0001:
		return origin.distance_to(center) <= rad
	var n := dir.normalized()
	var to := center - origin
	var along := to.dot(n)
	var closest := origin if along <= 0.0 else origin + n * along
	return closest.distance_to(center) <= rad


static func homing_blend(delta: float) -> float:
	return 1.0 - exp(-HOMING_RATE * maxf(delta, 0.0))


func _try_proximity_hit_along(from: Vector3, to: Vector3) -> void:
	var pill := _target as SwarmPill
	if pill == null or not pill.is_alive():
		return
	var aim := pill.hit_center()
	var radius := hit_radius_for(pill)
	if from.distance_to(aim) <= radius or to.distance_to(aim) <= radius:
		_on_body_entered(pill)
		return
	var closest := Geometry3D.get_closest_point_to_segment(aim, from, to)
	if closest.distance_to(aim) > radius:
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
