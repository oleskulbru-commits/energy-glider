class_name LevelTerrainBand
extends RefCounted

var id: String = ""
var display_name: String = ""
## 0..1 sort key for progression (TUTORIAL low, EXTREME high).
var intensity: float = 0.0


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_intensity: float = 0.0
) -> void:
	id = p_id
	display_name = p_display_name
	intensity = p_intensity
