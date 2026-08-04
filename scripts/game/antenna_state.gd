class_name AntennaState
extends Node

signal parts_changed(installed_parts: int, total_parts: int)

const HUB_RADIUS_M: float = 30.0
const BOOST_UNLOCK_AT_PART := 3

@export var total_parts: int = 5

var installed_parts: int = 0


func _ready() -> void:
	add_to_group("antenna_state")


func get_signal_ratio() -> float:
	if total_parts <= 0:
		return 0.0
	return float(installed_parts) / float(total_parts)


func get_signal_percent() -> int:
	return int(roundf(get_signal_ratio() * 100.0))


func format_signal() -> String:
	return "%d%%" % get_signal_percent()


func install_part() -> bool:
	if installed_parts >= total_parts:
		return false
	installed_parts += 1
	parts_changed.emit(installed_parts, total_parts)
	return true


func is_within_hub(world_pos: Vector3, hub_origin: Vector3) -> bool:
	var xz := Vector2(world_pos.x - hub_origin.x, world_pos.z - hub_origin.z)
	return xz.length() <= HUB_RADIUS_M
