class_name AutoLaser
extends Node

## Always-on second weapon. Independent clock from the rifle.

const DAMAGE := 5
const RANGE_M := 45.0
const FIRE_SEC := 2.0
const CHARGE_SEC := 2.0
const CHARGE_FLOOR := 0.5
const TICK_SEC := 0.5

var _rig: PlayerRig
var _charge := 0.0
var _pending := 0
var _stagger := 0.0
var _in_volley := false
var _beams: Array[LaserBeam] = []
var _beam_locks: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rig = get_parent() as PlayerRig
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if not _can_fire():
		_abort()
		return
	_tick_beams(delta)
	_prune_finished()
	_tick_stagger(delta)
	if _in_volley:
		if _pending <= 0 and _beams.is_empty():
			_charge = charge_for(_attack_speed_reduction())
			_in_volley = false
		return
	_charge = maxf(_charge - delta, 0.0)
	if _charge > 0.0:
		return
	_try_start_volley()


func _try_start_volley() -> bool:
	if not _spawn_beam():
		return false
	_in_volley = true
	_pending = AutoRifle.projectile_count_for(_extra_projectiles()) - 1
	_stagger = AutoRifle.BURST_GAP_SEC if _pending > 0 else 0.0
	return true


func _tick_stagger(delta: float) -> void:
	if _pending <= 0:
		return
	_stagger = maxf(_stagger - delta, 0.0)
	if _stagger > 0.0:
		return
	# Keep leftover beams chambered until they fire. Charge waits until the volley empties.
	if not _spawn_beam():
		return
	_pending -= 1
	if _pending > 0:
		_stagger = AutoRifle.BURST_GAP_SEC


func _spawn_beam() -> bool:
	var origin := _muzzle_origin()
	var facing := _facing_xz()
	var range_m := _current_range()
	var target := pick_unique_target(
		_pills(),
		origin,
		facing,
		range_m,
		_claimed_lock_ids(),
		_rng
	)
	if target == null:
		return false
	var beam := LaserBeam.new()
	add_child(beam)
	_claim_primary(beam, target)
	beam.begin(
		fire_time_for(_duration_bonus()),
		target,
		_damage_bonus(),
		_crit_chance(),
		_rng,
		_bounce_count(),
		AutoRifle.bounce_range_for(range_m),
		_pills(),
		range_m
	)
	_beams.append(beam)
	return true


func _claimed_lock_ids() -> Dictionary:
	var exclude: Dictionary = {}
	for id in _beam_locks:
		exclude[id] = true
	return exclude


func _claim_primary(beam: LaserBeam, target: Node3D) -> void:
	if target == null:
		return
	_beam_locks[target.get_instance_id()] = beam


func _release_primary(beam: LaserBeam) -> void:
	var drop: Array = []
	for id in _beam_locks:
		if _beam_locks[id] == beam:
			drop.append(id)
	for id in drop:
		_beam_locks.erase(id)


func _tick_beams(delta: float) -> void:
	var origin := _muzzle_origin()
	var facing := _facing_xz()
	var pills := _pills()
	var bonus := _damage_bonus()
	var crit := _crit_chance()
	for beam in _beams:
		if not is_instance_valid(beam) or beam.finished:
			continue
		beam.advance(delta, origin, facing, pills, _rng, bonus, crit, _current_range())


func _prune_finished() -> void:
	var keep: Array[LaserBeam] = []
	for beam in _beams:
		if is_instance_valid(beam) and not beam.finished:
			keep.append(beam)
		else:
			_release_primary(beam)
	_beams = keep


func _abort() -> void:
	for beam in _beams:
		if is_instance_valid(beam):
			beam.queue_free()
	_beams.clear()
	_beam_locks.clear()
	_pending = 0
	_stagger = 0.0
	_in_volley = false
	_charge = 0.0


func _can_fire() -> bool:
	if _rig == null:
		return false
	var state := _upgrade_state()
	if state == null or not state.has_laser:
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
	return state.extra_projectiles_for(UpgradeCatalog.FAMILY_LASER)


func _attack_speed_reduction() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.attack_speed_reduction_for(UpgradeCatalog.FAMILY_LASER)


func _damage_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.damage_bonus_for(UpgradeCatalog.FAMILY_LASER)


func _duration_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.duration_bonus_for(UpgradeCatalog.FAMILY_LASER)


func _bounce_count() -> int:
	var state := _upgrade_state()
	if state == null:
		return 0
	return state.bounce_count_for(UpgradeCatalog.FAMILY_LASER)


func _range_bonus() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.range_bonus_for(UpgradeCatalog.FAMILY_LASER)


func _current_range() -> float:
	return AutoRifle.range_for(RANGE_M, _range_bonus())


func _crit_chance() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return clampf(state.crit_chance_for(UpgradeCatalog.FAMILY_LASER), 0.0, UpgradeCatalog.CRIT_CAP)


func _upgrade_state() -> RunUpgradeState:
	return get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState


static func fire_time_for(duration_bonus: float) -> float:
	return FIRE_SEC * (1.0 + maxf(duration_bonus, 0.0))


static func tick_count_for(fire_time: float) -> int:
	return maxi(0, int(floor(maxf(fire_time, 0.0) / TICK_SEC)))


static func charge_for(reduction: float) -> float:
	return maxf(CHARGE_SEC * (1.0 - maxf(reduction, 0.0)), CHARGE_FLOOR)


static func damage_for(bonus: float) -> int:
	return maxi(1, int(round(float(DAMAGE) * (1.0 + maxf(bonus, 0.0)))))


## Primary lock only. Bounce hops may still overlap other beams' targets.
static func pick_unique_target(
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float,
	exclude: Dictionary,
	rng: RandomNumberGenerator
) -> Node3D:
	var magnet := WeaponTargeting.find_laser_drone_magnet(pills, origin, facing, range_m)
	if magnet != null:
		return magnet
	var candidates: Array[Node3D] = []
	for pill in AutoRifle.collect_candidates(pills, origin, facing, range_m):
		if exclude.has(pill.get_instance_id()):
			continue
		candidates.append(pill)
	if candidates.is_empty():
		return null
	if rng == null:
		return candidates[0]
	return candidates[rng.randi_range(0, candidates.size() - 1)]
