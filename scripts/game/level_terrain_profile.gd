class_name LevelTerrainProfile
extends RefCounted

var id: String = ""
var display_name: String = ""
var category: String = ""
var description: String = ""
## Atomic profile ids this hybrid is built from (empty for atomics).
var composed_of: Array[String] = []


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_category: String = "",
	p_description: String = "",
	p_composed_of: Array[String] = []
) -> void:
	id = p_id
	display_name = p_display_name
	category = p_category
	description = p_description
	composed_of = p_composed_of.duplicate()


func is_hybrid() -> bool:
	return not composed_of.is_empty()
