class_name AutoTesla
extends Node

## Instant sky-strikes. Chamber clock matches the shotgun; hops are lightning-fast.

const DAMAGE := 23
const RANGE_M := 20.0
const FIRE_INTERVAL_SEC := 3.0
const BURST_GAP_SEC := 0.12
const STUN_SEC := 1.0


var _rig: PlayerRig
var _cooldown := 0.0
var _burst_gap := 0.0
var _burst_remaining := 0
var _volley_exclude: Dictionary = {}
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
		_volley_exclude.clear()
		return
	if _burst_remaining > 0:
		if _burst_gap > 0.0:
			return
		_tick_burst()
		return
	if _cooldown > 0.0:
		return
	if not _try_start_burst():
		return


func get_projectile_count() -> int:
	return AutoRifle.projectile_count_for(_extra_projectiles())


func _try_start_burst() -> bool:
	_volley_exclude.clear()
	if not _fire_one():
		return false
	_burst_remaining = get_projectile_count() - 1
	if _burst_remaining <= 0:
		_cooldown = fire_interval_for(_attack_speed_reduction())
	else:
		_burst_gap = BURST_GAP_SEC
	return true


func _tick_burst() -> void:
	# Keep leftover strikes chambered until they fire. Cooldown starts only when empty.
	if not _fire_one():
		return
	_burst_remaining -= 1
	if _burst_remaining <= 0:
		_cooldown = fire_interval_for(_attack_speed_reduction())
	else:
		_burst_gap = BURST_GAP_SEC


func _fire_one() -> bool:
	var origin := _muzzle_origin()
	var facing := _facing_xz()
	var range_m := _current_range()
	var pills := _pills()
	var targets := pick_unique_targets(pills, origin, facing, range_m, 1, _rng, _volley_exclude)
	if targets.is_empty():
		return false
	var target := targets[0]
	var bounce_n := _bounce_count()
	var bounce_range := AutoRifle.bounce_range_for(range_m)
	var bonus := _damage_bonus()
	var crit := _crit_chance()
	_strike_chain(target, pills, bounce_n, bounce_range, bonus, crit)
	_volley_exclude[target.get_instance_id()] = true
	return true


func _strike_chain(
	start: Node3D,
	pills: Array,
	bounce_n: int,
	bounce_range: float,
	bonus: float,
	crit: float
) -> void:
	_strike(start, bonus, crit)
	var hops := AutoRifle.build_bounce_chain(start, pills, bounce_n, bounce_range, _rng)
	var prev := start
	for hop in hops:
		TeslaStrike.spawn_link(
			get_tree(),
			TeslaStrike.aim_point_for(prev),
			TeslaStrike.aim_point_for(hop)
		)
		_hurt(hop, bonus, crit)
		prev = hop


func _strike(target: Node3D, bonus: float, crit: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	TeslaStrike.spawn(get_tree(), TeslaStrike.aim_point_for(target))
	_hurt(target, bonus, crit)


func _hurt(target: Node3D, bonus: float, crit: float) -> void:
	var pill := target as SwarmPill
	if pill == null or not pill.is_alive():
		return
	var is_crit := AutoRifle.roll_crit(crit, _rng)
	var amount := AutoRifle.crit_damage_for(damage_for(bonus), is_crit)
	var died := pill.take_damage(amount, Vector3.ZERO, is_crit, 0.0, UpgradeCatalog.FAMILY_TESLA)
	if not died:
		pill.apply_stun(STUN_SEC)


func _can_fire() -> bool:
	if _rig == null:
		return false
	var state := _upgrade_state()
	if state == null or not state.has_tesla:
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


func _pills() -> Array:
	return get_tree().get_nodes_in_group("swarm_pill")


func _extra_projectiles() -> int:
	var state := _upgrade_state()
	if state == null:
		return 0
	return state.extra_projectiles_for(UpgradeCatalog.FAMILY_TESLA)


func _attack_speed_reduction() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.attack_speed_reduction_for(UpgradeCatalog.FAMILY_TESLA)


func _damage_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.damage_bonus_for(UpgradeCatalog.FAMILY_TESLA)


func _bounce_count() -> int:
	var state := _upgrade_state()
	if state == null:
		return 0
	return state.bounce_count_for(UpgradeCatalog.FAMILY_TESLA)


func _range_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.range_bonus_for(UpgradeCatalog.FAMILY_TESLA)


func _current_range() -> float:
	return AutoRifle.range_for(RANGE_M, _range_bonus())


func _crit_chance() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return clampf(state.crit_chance_for(UpgradeCatalog.FAMILY_TESLA), 0.0, UpgradeCatalog.CRIT_CAP)


func _upgrade_state() -> RunUpgradeState:
	return get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState


static func fire_interval_for(reduction: float) -> float:
	return FIRE_INTERVAL_SEC * (1.0 - minf(reduction, AutoRifle.CDR_CAP))


static func damage_for(bonus: float) -> int:
	return maxi(1, int(round(float(DAMAGE) * (1.0 + maxf(bonus, 0.0)))))


static func pick_unique_targets(
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float,
	count: int,
	rng: RandomNumberGenerator,
	exclude: Dictionary = {}
) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var want := maxi(count, 0)
	if want <= 0 or rng == null:
		return found
	var magnet := WeaponTargeting.find_laser_drone_magnet(pills, origin, facing, range_m)
	if magnet != null:
		for _i in want:
			found.append(magnet)
		return found
	var candidates: Array[Node3D] = []
	for pill in AutoRifle.collect_candidates(pills, origin, facing, range_m):
		if exclude.has(pill.get_instance_id()):
			continue
		candidates.append(pill)
	var n := candidates.size()
	for i in n:
		var j := rng.randi_range(i, n - 1)
		var swap: Node3D = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var take := mini(want, n)
	for i in take:
		found.append(candidates[i])
	return found
