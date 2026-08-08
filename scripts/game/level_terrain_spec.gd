class_name LevelTerrainSpec
extends RefCounted

var level_index: int = 1
var band_id: String = ""
var profile_id: String = ""
var notes: String = ""


func _init(
	p_level_index: int = 1,
	p_band_id: String = "",
	p_profile_id: String = "",
	p_notes: String = ""
) -> void:
	level_index = p_level_index
	band_id = p_band_id
	profile_id = p_profile_id
	notes = p_notes


func describe() -> String:
	var text := "Level %d, %s (%s)" % [level_index, band_id, profile_id]
	if not notes.is_empty():
		text += " — %s" % notes
	return text
