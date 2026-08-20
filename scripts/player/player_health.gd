class_name PlayerHealth
extends Node

signal health_changed(current: int, max_health: int)
signal damaged(amount: int)

const MAX_HEALTH := 100
const CONTACT_DAMAGE := 2
const REGEN_LOCKOUT_SEC := 1.0

@export var glider_path: NodePath

var current: int = MAX_HEALTH

var _glider: Node
var _death_triggered := false
var _regen_lockout := 0.0
var _regen_accum := 0.0


func _ready() -> void:
	add_to_group("player_health")
	if glider_path != NodePath():
		_glider = get_node_or_null(glider_path)
	if _glider == null:
		var parent := get_parent()
		if parent != null and parent.has_method("get_glider"):
			_glider = parent.get_glider()
	current = MAX_HEALTH
	health_changed.emit(current, MAX_HEALTH)


func get_current() -> int:
	return current


func get_max() -> int:
	return MAX_HEALTH


func get_ratio() -> float:
	return float(current) / float(MAX_HEALTH)


func reset_full() -> void:
	_death_triggered = false
	_regen_lockout = 0.0
	_regen_accum = 0.0
	current = MAX_HEALTH
	health_changed.emit(current, MAX_HEALTH)


func _process(delta: float) -> void:
	if _is_run_ended():
		return
	var rate := 0.0 if current >= MAX_HEALTH else _regen_rate()
	var stepped := tick_regen(rate, delta, _regen_accum, _regen_lockout)
	_regen_lockout = float(stepped["lockout"])
	_regen_accum = float(stepped["accum"])
	var healed := int(stepped["heal"])
	if healed > 0:
		heal(healed)


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
	health_changed.emit(current, MAX_HEALTH)
	if current <= 0:
		_trigger_death()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	if _is_run_ended():
		return
	var next := mini(current + amount, MAX_HEALTH)
	if next == current:
		return
	current = next
	health_changed.emit(current, MAX_HEALTH)


func _is_run_ended() -> bool:
	return _glider != null and _glider.has_method("is_run_ended") and _glider.is_run_ended()


func _regen_rate() -> float:
	var tree := get_tree()
	if tree == null:
		return 0.0
	var state := tree.get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state == null:
		return 0.0
	return state.health_regen_per_sec


func _trigger_death() -> void:
	if _death_triggered:
		return
	_death_triggered = true
	if _glider != null and _glider.has_method("is_run_ended") and not _glider.is_run_ended():
		if _glider.has_method("end_run"):
			_glider.end_run("death")


## Pure helpers for verifies / tuning.
static func apply_damage(current_hp: int, amount: int, max_hp: int = MAX_HEALTH) -> int:
	return clampi(current_hp - maxi(amount, 0), 0, max_hp)


static func apply_heal(current_hp: int, amount: int, max_hp: int = MAX_HEALTH) -> int:
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
