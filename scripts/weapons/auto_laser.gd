class_name AutoLaser
extends Node

## Always-on second weapon. Independent clock from the rifle.

const DAMAGE := 3
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
	_spawn_beam()
	_pending -= 1
	if _pending > 0:
		_stagger = AutoRifle.BURST_GAP_SEC


func _spawn_beam() -> bool:
	var origin := _muzzle_origin()
	var facing := _facing_xz()
	var target := AutoRifle.pick_target(
		_pills(),
		origin,
		facing,
		AutoRifle.RANGE_M,
		_rng
	)
	if target == null:
		return false
	var beam := LaserBeam.new()
	add_child(beam)
	beam.begin(
		fire_time_for(_duration_bonus()),
		target,
		_damage_bonus(),
		_crit_chance(),
		_rng,
		_bounce_count(),
		AutoRifle.bounce_range_for(AutoRifle.RANGE_M),
		_pills()
	)
	_beams.append(beam)
	return true


func _tick_beams(delta: float) -> void:
	var origin := _muzzle_origin()
	var facing := _facing_xz()
	var pills := _pills()
	var bonus := _damage_bonus()
	var crit := _crit_chance()
	for beam in _beams:
		if not is_instance_valid(beam) or beam.finished:
			continue
		beam.advance(delta, origin, facing, pills, _rng, bonus, crit)


func _prune_finished() -> void:
	var keep: Array[LaserBeam] = []
	for beam in _beams:
		if is_instance_valid(beam) and not beam.finished:
			keep.append(beam)
	_beams = keep


func _abort() -> void:
	for beam in _beams:
		if is_instance_valid(beam):
			beam.queue_free()
	_beams.clear()
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


static func closest_in_front(
	pills: Array, origin: Vector3, facing: Vector3, range_m: float
) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for pill in AutoRifle.collect_candidates(pills, origin, facing, range_m):
		var d := AutoRifle.xz_distance(origin, pill.global_position)
		if d < best_d:
			best_d = d
			best = pill
	return best
