class_name LevelRunSegment
extends RefCounted

var index: int = 1
var length_m: float = 1000.0
var intensity: float = 0.08
var band_id: String = "TUTORIAL"
var profile_id: String = "tutorial_flow"


func _init(
	p_index: int = 1,
	p_length_m: float = 1000.0,
	p_intensity: float = 0.08,
	p_band_id: String = "TUTORIAL",
	p_profile_id: String = "tutorial_flow"
) -> void:
	index = p_index
	length_m = p_length_m
	intensity = p_intensity
	band_id = p_band_id
	profile_id = p_profile_id
