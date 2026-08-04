class_name PlayerCargo
extends Node

signal cargo_changed(used_slots: int, capacity: int)

@export var capacity: int = 6

var slots: Array[LootItem] = []


func _ready() -> void:
	add_to_group("player_cargo")


func has_cargo() -> bool:
	return not slots.is_empty()


func is_full() -> bool:
	return slots.size() >= capacity


func get_used_slots() -> int:
	return slots.size()


func try_add_item(item: LootItem) -> bool:
	if item == null or is_full():
		return false
	slots.append(item)
	cargo_changed.emit(slots.size(), capacity)
	return true


func count_items_of_type(type: CargoTypes.Type) -> int:
	var count := 0
	for item in slots:
		if item != null and item.cargo_type == type:
			count += 1
	return count


func consume_first_of_type(type: CargoTypes.Type) -> bool:
	for i in slots.size():
		var item := slots[i]
		if item != null and item.cargo_type == type:
			slots.remove_at(i)
			cargo_changed.emit(slots.size(), capacity)
			return true
	return false


func clear_cargo() -> int:
	var cleared := slots.size()
	slots.clear()
	if cleared > 0:
		cargo_changed.emit(slots.size(), capacity)
	return cleared


func get_cargo_label() -> String:
	if slots.is_empty():
		return ""
	return "%d/%d" % [slots.size(), capacity]


func get_summary_label() -> String:
	if slots.is_empty():
		return ""
	var first := slots[0]
	if first == null:
		return get_cargo_label()
	if slots.size() == 1:
		return first.display_name
	return "%s +%d" % [first.display_name, slots.size() - 1]
