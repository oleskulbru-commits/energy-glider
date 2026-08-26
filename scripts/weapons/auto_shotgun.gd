class_name AutoShotgun
extends Node

## Instant cone blast. Pellets are visual only.

const ShotgunPelletScene := preload("res://scenes/weapons/shotgun_pellet.tscn")

const DAMAGE := 17
const RANGE_M := 15.0
const FIRE_INTERVAL_SEC := 2.5
const BURST_GAP_SEC := 0.5
const BURST_GAP_AS_SCALE := 0.20
const BURST_GAP_MIN_SEC := 0.2
const KNOCKBACK_SPEED := 28.0
const CONE_HALF_DEG := 22.0
const PELLET_COUNT := 16
const PELLET_SPEED_MPS := 50.0
const PELLET_TRAVEL_M := 32.0
## Aim at torso so crest jumps pitch the cone down at sand-level enemies.
const AIM_UP_M := 0.7
## XZ radius treated as "directly below" for acquire (still needs 3D range).
const BELOW_XZ_EPS_M := 0.05


var _rig: PlayerRig
var _cooldown := 0.0
var _burst_gap := 0.0
var _burst_remaining := 0
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


func _extra_projectiles() -> int:
	var state := _upgrade_state()
	if state == null:
		return 0
	return state.extra_projectiles_for(UpgradeCatalog.FAMILY_SHOTGUN)


func _attack_speed_reduction() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.attack_speed_reduction_for(UpgradeCatalog.FAMILY_SHOTGUN)


func _damage_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.damage_bonus_for(UpgradeCatalog.FAMILY_SHOTGUN)


func _crit_chance() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return clampf(state.crit_chance_for(UpgradeCatalog.FAMILY_SHOTGUN), 0.0, UpgradeCatalog.CRIT_CAP)


func _pushback_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.pushback_bonus_for(UpgradeCatalog.FAMILY_SHOTGUN)


func _range_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.range_bonus_for(UpgradeCatalog.FAMILY_SHOTGUN)


func _current_range() -> float:
	return AutoRifle.range_for(RANGE_M, _range_bonus())


func _upgrade_state() -> RunUpgradeState:
	return get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState


func _try_start_burst() -> bool:
	if not _fire_volley():
		return false
	_burst_remaining = get_projectile_count() - 1
	if _burst_remaining <= 0:
		_cooldown = fire_interval_for(_attack_speed_reduction())
	else:
		_burst_gap = burst_gap_for(_attack_speed_reduction())
	return true


func _tick_burst() -> void:
	# Keep leftover volleys chambered until they fire. Cooldown starts only when empty.
	if not _fire_volley():
		return
	_burst_remaining -= 1
	if _burst_remaining <= 0:
		_cooldown = fire_interval_for(_attack_speed_reduction())
	else:
		_burst_gap = burst_gap_for(_attack_speed_reduction())


func _can_fire() -> bool:
	if _rig == null:
		return false
	var state := _upgrade_state()
	if state == null or not state.has_shotgun:
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


func _fire_volley() -> bool:
	var origin := _muzzle_origin()
	var facing := _facing_xz()
	var range_m := _current_range()
	var pills := get_tree().get_nodes_in_group("swarm_pill")
	var target := pick_target(pills, origin, facing, range_m, _rng)
	if target == null:
		return false
	var aim := aim_vector(origin, target.global_position, facing)
	var amount := damage_for(_damage_bonus())
	var knock := knockback_speed_for(_pushback_bonus())
	var crit := _crit_chance()
	for pill in pills_in_cone(origin, aim, range_m, deg_to_rad(CONE_HALF_DEG), pills):
		_hit_pill(origin, pill, amount, crit, knock)
	_spawn_visuals(origin, aim, range_m)
	return true


func _hit_pill(
	origin: Vector3,
	pill: Node3D,
	amount: int,
	crit_chance: float,
	knock: float
) -> void:
	var swarm := pill as SwarmPill
	if swarm == null or not swarm.is_alive():
		return
	var hit_dir := Vector3(
		pill.global_position.x - origin.x,
		0.0,
		pill.global_position.z - origin.z
	)
	if hit_dir.length_squared() < 0.0001:
		hit_dir = _facing_xz()
	var is_crit := AutoRifle.roll_crit(crit_chance, _rng)
	var dealt := AutoRifle.crit_damage_for(amount, is_crit)
	var killed := swarm.take_damage(dealt, hit_dir.normalized(), is_crit, knock)
	if killed:
		KillSparks.spawn(get_tree(), pill.global_position)


func _spawn_visuals(origin: Vector3, aim: Vector3, range_m: float) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = _rig
	ShotgunFlash.spawn(get_tree(), origin, aim)
	var travel := maxf(PELLET_TRAVEL_M, range_m)
	var life := travel / PELLET_SPEED_MPS
	for _i in PELLET_COUNT:
		var pellet: ShotgunPellet = ShotgunPelletScene.instantiate() as ShotgunPellet
		parent.add_child(pellet)
		pellet.launch(origin, _pellet_dir(aim), PELLET_SPEED_MPS, life)


func _pellet_dir(aim: Vector3) -> Vector3:
	var yaw := deg_to_rad(_rng.randf_range(-CONE_HALF_DEG, CONE_HALF_DEG))
	var pitch := deg_to_rad(_rng.randf_range(-6.0, 8.0))
	var fwd := aim
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()
	var up := Vector3.UP
	if absf(fwd.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var basis := Basis.looking_at(fwd, up)
	return (basis * Vector3(sin(yaw), sin(pitch), -cos(yaw))).normalized()


## 3D aim at the target (includes downward pitch when airborne above sand).
static func aim_vector(origin: Vector3, target_pos: Vector3, facing_fallback: Vector3) -> Vector3:
	var aim := target_pos + Vector3(0.0, AIM_UP_M, 0.0) - origin
	if aim.length_squared() >= 0.0001:
		return aim.normalized()
	var flat := Vector3(facing_fallback.x, 0.0, facing_fallback.z)
	if flat.length_squared() >= 0.0001:
		return flat.normalized()
	return Vector3.FORWARD


## Acquire by true 3D range. Front hemisphere stays XZ; directly-below still counts.
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
		var pos := pill.global_position
		if origin.distance_to(pos) > range_m:
			continue
		var xz := AutoRifle.xz_distance(origin, pos)
		if xz > BELOW_XZ_EPS_M and not AutoRifle.is_in_front(origin, facing, pos):
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
	if rng == null:
		return candidates[0]
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Cone + range in full 3D so a pitched-down blast still catches sand-level pills.
static func pills_in_cone(
	origin: Vector3,
	aim: Vector3,
	range_m: float,
	half_angle_rad: float,
	pills: Array
) -> Array[Node3D]:
	var hit: Array[Node3D] = []
	if aim.length_squared() < 0.0001:
		return hit
	var fwd := aim.normalized()
	var min_dot := cos(maxf(half_angle_rad, 0.0))
	for node in pills:
		var pill := node as Node3D
		if pill == null or not is_instance_valid(pill):
			continue
		if pill is SwarmPill and not (pill as SwarmPill).is_alive():
			continue
		var to := pill.global_position + Vector3(0.0, AIM_UP_M, 0.0) - origin
		var dist := to.length()
		if dist > range_m:
			continue
		if dist < 0.0001:
			hit.append(pill)
			continue
		if to.dot(fwd) / dist >= min_dot:
			hit.append(pill)
	return hit


static func fire_interval_for(reduction: float) -> float:
	return FIRE_INTERVAL_SEC * (1.0 - minf(reduction, AutoRifle.CDR_CAP))


static func burst_gap_for(reduction: float) -> float:
	var scaled := minf(maxf(reduction, 0.0), AutoRifle.CDR_CAP) * BURST_GAP_AS_SCALE
	return maxf(BURST_GAP_SEC * (1.0 - scaled), BURST_GAP_MIN_SEC)


static func damage_for(bonus: float) -> int:
	return maxi(1, int(round(float(DAMAGE) * (1.0 + maxf(bonus, 0.0)))))


static func knockback_speed_for(bonus: float) -> float:
	return KNOCKBACK_SPEED * (1.0 + maxf(bonus, 0.0))
