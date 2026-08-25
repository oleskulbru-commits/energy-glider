class_name AutoRocket
extends Node

## Lofted homing missiles. Burst clock matches the rifle.

const RocketMissileScene := preload("res://scenes/weapons/rocket_missile.tscn")

const DAMAGE := 20
const RANGE_M := 50.0
const FIRE_INTERVAL_SEC := 4.0
const BURST_GAP_SEC := 0.12
const KNOCKBACK_SPEED := 20.0
const AIM_AHEAD_BIAS := 0.35
const AIM_FAR_BIAS := 0.65


var _rig: PlayerRig
var _cooldown := 0.0
var _burst_gap := 0.0
var _burst_queue: Array[Node3D] = []


func _ready() -> void:
	_rig = get_parent() as PlayerRig


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_burst_gap = maxf(_burst_gap - delta, 0.0)
	if not _can_fire():
		_burst_queue.clear()
		_burst_gap = 0.0
		return
	if _burst_gap > 0.0:
		return
	if not _burst_queue.is_empty():
		_tick_burst()
		return
	if _cooldown > 0.0:
		return
	if not _try_start_burst():
		return


func get_projectile_count() -> int:
	return AutoRifle.projectile_count_for(_extra_projectiles())


func _extra_projectiles() -> int:
	var state := _upgrade_state()
	if state == null:
		return 0
	return state.extra_projectiles_for(UpgradeCatalog.FAMILY_ROCKET)


func _attack_speed_reduction() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.attack_speed_reduction_for(UpgradeCatalog.FAMILY_ROCKET)


func _damage_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.damage_bonus_for(UpgradeCatalog.FAMILY_ROCKET)


func _crit_chance() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return clampf(state.crit_chance_for(UpgradeCatalog.FAMILY_ROCKET), 0.0, UpgradeCatalog.CRIT_CAP)


func _projectile_speed_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.projectile_speed_bonus_for(UpgradeCatalog.FAMILY_ROCKET)


func _pushback_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.pushback_bonus_for(UpgradeCatalog.FAMILY_ROCKET)


func _range_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.range_bonus_for(UpgradeCatalog.FAMILY_ROCKET)


func _current_range() -> float:
	return AutoRifle.range_for(RANGE_M, _range_bonus())


func _upgrade_state() -> RunUpgradeState:
	return get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState


func _try_start_burst() -> bool:
	var origin := _muzzle_origin()
	var facing := _facing_xz()
	var ranked := rank_targets(
		get_tree().get_nodes_in_group("swarm_pill"),
		origin,
		facing,
		_current_range(),
		get_projectile_count()
	)
	if ranked.is_empty():
		return false
	_fire(origin, ranked[0])
	_burst_queue.clear()
	for i in range(1, ranked.size()):
		_burst_queue.append(ranked[i])
	if _burst_queue.is_empty():
		_cooldown = fire_interval_for(_attack_speed_reduction())
	else:
		_burst_gap = BURST_GAP_SEC
	return true


func _tick_burst() -> void:
	var origin := _muzzle_origin()
	while not _burst_queue.is_empty():
		var next: Node3D = _burst_queue.pop_front()
		if next != null and is_instance_valid(next):
			_fire(origin, next)
			break
	if _burst_queue.is_empty():
		_cooldown = fire_interval_for(_attack_speed_reduction())
	else:
		_burst_gap = BURST_GAP_SEC


func _can_fire() -> bool:
	if _rig == null:
		return false
	var state := _upgrade_state()
	if state == null or not state.has_rocket:
		return false
	var glider := _rig.get_glider()
	return glider != null and not glider.is_run_ended()


func _muzzle_origin() -> Vector3:
	var glider := _rig.get_glider() if _rig != null else null
	if glider == null:
		return Vector3.ZERO
	return glider.global_position + Vector3.UP * AutoRifle.MUZZLE_UP_M


func _facing_xz() -> Vector3:
	var glider := _rig.get_glider() if _rig != null else null
	if glider == null:
		return Vector3.ZERO
	return MathUtil.yaw_forward(glider.get_yaw())


func _fire(origin: Vector3, target: Node3D) -> void:
	var missile: RocketMissile = RocketMissileScene.instantiate() as RocketMissile
	var parent := get_tree().current_scene
	if parent == null:
		parent = _rig
	parent.add_child(missile)
	missile.launch(
		origin,
		target,
		damage_for(_damage_bonus()),
		speed_for(_projectile_speed_bonus()),
		_crit_chance(),
		knockback_speed_for(_pushback_bonus())
	)


static func aim_score(origin: Vector3, facing: Vector3, pos: Vector3, range_m: float) -> float:
	var to := Vector3(pos.x - origin.x, 0.0, pos.z - origin.z)
	var dist := to.length()
	var fwd := Vector3(facing.x, 0.0, facing.z)
	if dist < 0.0001 or fwd.length_squared() < 0.0001:
		return 0.0
	var forward_dot := to.dot(fwd.normalized()) / dist
	if forward_dot <= 0.0:
		return 0.0
	var dist_norm := 0.0
	if range_m > 0.0001:
		dist_norm = clampf(dist / range_m, 0.0, 1.0)
	return forward_dot * forward_dot * (AIM_AHEAD_BIAS + AIM_FAR_BIAS * dist_norm)


static func rank_targets(
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float,
	count: int
) -> Array[Node3D]:
	var ranked: Array[Node3D] = []
	var want := maxi(count, 0)
	if want <= 0:
		return ranked
	var candidates := AutoRifle.collect_candidates(pills, origin, facing, range_m)
	candidates.sort_custom(
		func(a: Node3D, b: Node3D) -> bool:
			return (
				aim_score(origin, facing, a.global_position, range_m)
				> aim_score(origin, facing, b.global_position, range_m)
			)
	)
	var take := mini(want, candidates.size())
	for i in take:
		ranked.append(candidates[i])
	return ranked


static func fire_interval_for(reduction: float) -> float:
	return FIRE_INTERVAL_SEC * (1.0 - minf(reduction, AutoRifle.CDR_CAP))


static func damage_for(bonus: float) -> int:
	return maxi(1, int(round(float(DAMAGE) * (1.0 + maxf(bonus, 0.0)))))


static func speed_for(bonus: float) -> float:
	return RocketMissile.SPEED_MPS * (1.0 + minf(maxf(bonus, 0.0), AutoRifle.SPEED_CAP))


static func knockback_speed_for(bonus: float) -> float:
	return KNOCKBACK_SPEED * (1.0 + maxf(bonus, 0.0))
