class_name AutoRifle
extends Node

## Invisible Megabonk-style rifle. Only the tracer is visible.

const RifleBulletScene := preload("res://scenes/weapons/rifle_bullet.tscn")

const DAMAGE := 10
const RANGE_M := 100.0
const FIRE_INTERVAL_SEC := 3.0
const CDR_CAP := 0.80
const SPEED_CAP := 0.80
const BURST_GAP_SEC := 0.12
const MUZZLE_UP_M := 0.85

var _rig: PlayerRig
var _cooldown := 0.0
var _burst_remaining := 0
var _burst_gap := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rig = get_parent() as PlayerRig
	_rng.randomize()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_burst_gap = maxf(_burst_gap - delta, 0.0)
	if not _can_fire():
		_burst_remaining = 0
		_burst_gap = 0.0
		return
	if _burst_remaining > 0:
		_tick_burst()
		return
	if _cooldown > 0.0:
		return
	if not _try_start_burst():
		return


func get_projectile_count() -> int:
	return projectile_count_for(_extra_projectiles())


func _extra_projectiles() -> int:
	var state := _upgrade_state()
	if state == null:
		return 0
	return state.extra_projectiles


func _attack_speed_reduction() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.attack_speed_reduction


func _damage_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.damage_bonus


func _crit_chance() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return clampf(state.crit_chance, 0.0, UpgradeCatalog.CRIT_CAP)


func _projectile_speed_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.projectile_speed_bonus


func _pushback_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.pushback_bonus


func _upgrade_state() -> RunUpgradeState:
	return get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState


func _try_start_burst() -> bool:
	if not _fire_at_current_target():
		return false
	var remaining := get_projectile_count() - 1
	if remaining > 0:
		_burst_remaining = remaining
		_burst_gap = BURST_GAP_SEC
	else:
		_cooldown = fire_interval_for(_attack_speed_reduction())
	return true


func _tick_burst() -> void:
	if _burst_gap > 0.0:
		return
	_fire_at_current_target()
	_burst_remaining -= 1
	if _burst_remaining > 0:
		_burst_gap = BURST_GAP_SEC
	else:
		_cooldown = fire_interval_for(_attack_speed_reduction())


func _fire_at_current_target() -> bool:
	var origin := _muzzle_origin()
	var facing := _facing_xz()
	var target := pick_target(
		get_tree().get_nodes_in_group("swarm_pill"),
		origin,
		facing,
		RANGE_M,
		_rng
	)
	if target == null:
		return false
	_fire(origin, target)
	return true


func _can_fire() -> bool:
	if _rig == null:
		return false
	var glider := _rig.get_glider()
	return glider != null and not glider.is_run_ended()


func _muzzle_origin() -> Vector3:
	var glider := _rig.get_glider() if _rig != null else null
	if glider == null:
		return Vector3.ZERO
	return glider.global_position + Vector3.UP * MUZZLE_UP_M


func _facing_xz() -> Vector3:
	var glider := _rig.get_glider() if _rig != null else null
	if glider == null:
		return Vector3.ZERO
	return MathUtil.yaw_forward(glider.get_yaw())


func _fire(origin: Vector3, target: Node3D) -> void:
	var bullet: RifleBullet = RifleBulletScene.instantiate() as RifleBullet
	var parent := get_tree().current_scene
	if parent == null:
		parent = _rig
	parent.add_child(bullet)
	var aim := target.global_position + Vector3(0.0, 0.7, 0.0) - origin
	var is_crit := roll_crit(_crit_chance(), _rng)
	bullet.launch(
		origin,
		target,
		aim,
		crit_damage_for(damage_for(_damage_bonus()), is_crit),
		speed_for(_projectile_speed_bonus()),
		is_crit,
		knockback_speed_for(_pushback_bonus())
	)


static func xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## True if `pos` is in the front 180° hemisphere of `facing` (XZ).
static func is_in_front(origin: Vector3, facing: Vector3, pos: Vector3) -> bool:
	var to := Vector3(pos.x - origin.x, 0.0, pos.z - origin.z)
	var fwd := Vector3(facing.x, 0.0, facing.z)
	if to.length_squared() < 0.0001 or fwd.length_squared() < 0.0001:
		return false
	return to.dot(fwd) >= 0.0


static func collect_candidates(
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float
) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in pills:
		var pill := node as Node3D
		if pill == null or not is_instance_valid(pill):
			continue
		if pill is SwarmPill and not (pill as SwarmPill).is_alive():
			continue
		if xz_distance(origin, pill.global_position) > range_m:
			continue
		if not is_in_front(origin, facing, pill.global_position):
			continue
		found.append(pill)
	return found


static func pick_target(
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float,
	rng: RandomNumberGenerator
) -> Node3D:
	var candidates := collect_candidates(pills, origin, facing, range_m)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func fire_interval_for(reduction: float) -> float:
	return FIRE_INTERVAL_SEC * (1.0 - minf(reduction, CDR_CAP))


static func damage_for(bonus: float) -> int:
	return maxi(1, int(round(float(DAMAGE) * (1.0 + maxf(bonus, 0.0)))))


static func roll_crit(chance: float, rng: RandomNumberGenerator) -> bool:
	if rng == null:
		return false
	return rng.randf() < clampf(chance, 0.0, UpgradeCatalog.CRIT_CAP)


static func crit_damage_for(base: int, is_crit: bool) -> int:
	var amount := maxi(base, 1)
	if is_crit:
		return amount * 2
	return amount


static func speed_for(bonus: float) -> float:
	return RifleBullet.SPEED_MPS * (1.0 + minf(maxf(bonus, 0.0), SPEED_CAP))


static func knockback_speed_for(bonus: float) -> float:
	return SwarmPill.HIT_KNOCKBACK_SPEED * (1.0 + maxf(bonus, 0.0))


static func projectile_count_for(extra_projectiles: int) -> int:
	return 1 + maxi(extra_projectiles, 0)


static func burst_fire_times(projectile_count: int) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	var count := maxi(projectile_count, 1)
	for i in count:
		times.append(float(i) * BURST_GAP_SEC)
	return times


static func burst_cooldown_start_sec(projectile_count: int) -> float:
	return float(maxi(projectile_count, 1) - 1) * BURST_GAP_SEC
