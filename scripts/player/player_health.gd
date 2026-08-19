class_name PlayerHealth
extends Node

signal health_changed(current: int, max_health: int)
signal damaged(amount: int)

const MAX_HEALTH := 100
const CONTACT_DAMAGE := 2
const TOWER_HEAL := 50

@export var glider_path: NodePath

var current: int = MAX_HEALTH

var _glider: Node
var _death_triggered := false


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
	current = MAX_HEALTH
	health_changed.emit(current, MAX_HEALTH)


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	if _glider != null and _glider.has_method("is_run_ended") and _glider.is_run_ended():
		return
	var next := maxi(current - amount, 0)
	var dealt := current - next
	if dealt <= 0:
		return
	current = next
	damaged.emit(dealt)
	health_changed.emit(current, MAX_HEALTH)
	if current <= 0:
		_trigger_death()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	if _glider != null and _glider.has_method("is_run_ended") and _glider.is_run_ended():
		return
	var next := mini(current + amount, MAX_HEALTH)
	if next == current:
		return
	current = next
	health_changed.emit(current, MAX_HEALTH)


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


static func should_heal_on_hub_edge(was_inside: bool, is_inside: bool) -> bool:
	return is_inside and not was_inside


## Same window as enemy spawning: first E.O.N. starts the run; Try Again can
## fight (and reach towers) before picking the E.O.N. up again.
static func should_process_hub_heal(run_active: bool, run_bootstrapped: bool, run_ended: bool) -> bool:
	if run_ended:
		return false
	return run_active or run_bootstrapped
