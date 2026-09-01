class_name PlayerHealth
extends Node

signal health_changed(current: int, max_health: int)
signal damaged(amount: int)

const BASE_HEALTH := 50
const CONTACT_DAMAGE := 2
const REGEN_LOCKOUT_SEC := 4.0
const LASER_BURN_DURATION_SEC := 3.0
const LASER_BURN_TICK_SEC := 0.5
const LASER_BURN_DAMAGE := 2

@export var glider_path: NodePath

var current: int = BASE_HEALTH

var _glider: Node
var _death_triggered := false
var _regen_lockout := 0.0
var _regen_accum := 0.0
var _burn_left := 0.0
var _burn_tick_accum := 0.0
var _prev_glider_pos := Vector3.ZERO


func _ready() -> void:
	add_to_group("player_health")
	if glider_path != NodePath():
		_glider = get_node_or_null(glider_path)
	if _glider == null:
		var parent := get_parent()
		if parent != null and parent.has_method("get_glider"):
			_glider = parent.get_glider()
	current = BASE_HEALTH
	health_changed.emit(current, get_max())
	process_physics_priority = -10


func get_current() -> int:
	return current


func get_max() -> int:
	return BASE_HEALTH + _max_health_bonus()


func get_ratio() -> float:
	var cap := get_max()
	if cap <= 0:
		return 0.0
	return float(current) / float(cap)


func reset_full() -> void:
	_death_triggered = false
	_regen_lockout = 0.0
	_regen_accum = 0.0
	_burn_left = 0.0
	_burn_tick_accum = 0.0
	_prev_glider_pos = _glider_world_pos()
	current = get_max()
	health_changed.emit(current, get_max())


func add_bonus_health(amount: int) -> void:
	if amount <= 0:
		return
	current += amount
	var cap := get_max()
	if current > cap:
		current = cap
	health_changed.emit(current, cap)


func _process(delta: float) -> void:
	if _is_run_ended():
		return
	var cap := get_max()
	var rate := 0.0 if current >= cap else _regen_rate()
	var stepped := tick_regen(rate, delta, _regen_accum, _regen_lockout)
	_regen_lockout = float(stepped["lockout"])
	_regen_accum = float(stepped["accum"])
	var healed := int(stepped["heal"])
	if healed > 0:
		heal(healed)


func _physics_process(delta: float) -> void:
	if _is_run_ended():
		return
	var burn_step := tick_burn(_burn_left, _burn_tick_accum, delta)
	_burn_left = float(burn_step["burn_left"])
	_burn_tick_accum = float(burn_step["tick_accum"])
	var burn_damage := int(burn_step["damage"])
	if burn_damage > 0:
		take_damage(burn_damage)
	_prev_glider_pos = _glider_world_pos()


func apply_laser_burn() -> void:
	_burn_left = LASER_BURN_DURATION_SEC
	_burn_tick_accum = LASER_BURN_TICK_SEC


func movement_chord() -> Dictionary:
	var to_pos := _glider_world_pos()
	return {"from": _prev_glider_pos, "to": to_pos}


func get_burn_left() -> float:
	return _burn_left


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	if _is_run_ended():
		return
	var next := maxi(current - amount, 0)
	var dealt := current - next
	if dealt <= 0:
		return
	current = next
	_regen_lockout = lockout_on_hit(_regen_lockout)
	damaged.emit(dealt)
	health_changed.emit(current, get_max())
	if current <= 0:
		_trigger_death()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	if _is_run_ended():
		return
	var cap := get_max()
	var next := mini(current + amount, cap)
	if next == current:
		return
	current = next
	health_changed.emit(current, cap)


func _is_run_ended() -> bool:
	return _glider != null and _glider.has_method("is_run_ended") and _glider.is_run_ended()


func _max_health_bonus() -> int:
	var state := _upgrade_state()
	if state == null:
		return 0
	return maxi(state.max_health_bonus, 0)


func _regen_rate() -> float:
	var state := _upgrade_state()
	if state == null:
		return 0.0
	return state.health_regen_per_sec


func _upgrade_state() -> RunUpgradeState:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("run_upgrade_state") as RunUpgradeState


func _trigger_death() -> void:
	if _death_triggered:
		return
	_death_triggered = true
	if _glider != null and _glider.has_method("is_run_ended") and not _glider.is_run_ended():
		if _glider.has_method("end_run"):
			_glider.end_run("death")


func _glider_world_pos() -> Vector3:
	if _glider != null and is_instance_valid(_glider) and _glider is Node3D:
		return (_glider as Node3D).global_position
	return Vector3.ZERO


## Pure helpers for verifies / tuning.
static func apply_damage(current_hp: int, amount: int, max_hp: int = BASE_HEALTH) -> int:
	return clampi(current_hp - maxi(amount, 0), 0, max_hp)


static func apply_heal(current_hp: int, amount: int, max_hp: int = BASE_HEALTH) -> int:
	return clampi(current_hp + maxi(amount, 0), 0, max_hp)


static func lockout_on_hit(_current_lockout: float = 0.0, delay: float = REGEN_LOCKOUT_SEC) -> float:
	return delay


## Tick one regen step. Incoming lockout blocks accumulation for the whole
## frame, even if the pause expires during it.
static func tick_regen(rate: float, dt: float, accum: float, lockout: float) -> Dictionary:
	var step := maxf(dt, 0.0)
	if lockout > 0.0:
		return {"lockout": maxf(lockout - step, 0.0), "accum": accum, "heal": 0}
	if rate <= 0.0:
		return {"lockout": 0.0, "accum": 0.0, "heal": 0}
	var next_accum := accum + rate * step
	var healed := int(floor(next_accum))
	next_accum -= float(healed)
	return {"lockout": 0.0, "accum": next_accum, "heal": healed}


static func tick_burn(burn_left: float, tick_accum: float, dt: float) -> Dictionary:
	var step := maxf(dt, 0.0)
	if burn_left <= 0.0:
		return {"burn_left": 0.0, "tick_accum": 0.0, "damage": 0}
	var next_left := maxf(burn_left - step, 0.0)
	var next_accum := tick_accum - step
	var damage := 0
	while next_accum < 0.0:
		damage += LASER_BURN_DAMAGE
		next_accum += LASER_BURN_TICK_SEC
	return {"burn_left": next_left, "tick_accum": next_accum, "damage": damage}
