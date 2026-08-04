class_name LootContainer
extends Node

signal contents_changed
signal breached

const INTERACT_RADIUS := 4.5

@export var container_name: String = "CONTAINER"
@export var breach_duration: float = 0.75

var _breached := false
var _contents: Array[LootItem] = []
var _loot_roll: Callable


func _ready() -> void:
	add_to_group("loot_container")


func set_loot_roll(roll_fn: Callable) -> void:
	_loot_roll = roll_fn


func is_breached() -> bool:
	return _breached


func is_empty() -> bool:
	return _contents.is_empty()


func can_interact(body: Node3D) -> bool:
	if body == null or is_empty() and _breached:
		return false
	var host := _host_node()
	if host == null:
		return false
	return host.global_position.distance_to(body.global_position) <= INTERACT_RADIUS


func get_breach_duration() -> float:
	return breach_duration


func get_prompt_label() -> String:
	if is_empty() and _breached:
		return ""
	if _breached:
		return "LOOT"
	return "BREACH"


func get_display_name() -> String:
	return container_name


func breach() -> void:
	if _breached:
		return
	_breached = true
	if _loot_roll.is_valid():
		_contents = _loot_roll.call()
	else:
		_contents = []
	breached.emit()
	contents_changed.emit()


func get_contents() -> Array[LootItem]:
	return _contents.duplicate()


func take_at(index: int, cargo: PlayerCargo) -> bool:
	if index < 0 or index >= _contents.size() or cargo == null:
		return false
	var item := _contents[index]
	if not cargo.try_add_item(item):
		return false
	_contents.remove_at(index)
	contents_changed.emit()
	return true


func take_all(cargo: PlayerCargo) -> int:
	if cargo == null:
		return 0
	var taken := 0
	var i := 0
	while i < _contents.size():
		if cargo.try_add_item(_contents[i]):
			_contents.remove_at(i)
			taken += 1
		else:
			i += 1
	if taken > 0:
		contents_changed.emit()
	return taken


func _host_node() -> Node3D:
	var parent := get_parent()
	return parent as Node3D if parent is Node3D else self as Node3D
