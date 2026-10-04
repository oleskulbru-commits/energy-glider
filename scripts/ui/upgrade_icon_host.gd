extends Control

## Keeps a square rarity frame centered on the card, with the upgrade icon inside the opening.
## The opening was measured on the 256px frames: the metal starts about 0.06 in from each edge.

const INSET := 0.08


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var side := minf(size.x, size.y)
	if side <= 1.0:
		return
	var origin := (size - Vector2(side, side)) * 0.5
	var frame := get_node_or_null("Frame") as Control
	var icon := get_node_or_null("Icon") as Control
	if frame != null:
		frame.position = origin
		frame.size = Vector2(side, side)
	if icon != null:
		var inset := side * INSET
		icon.position = origin + Vector2(inset, inset)
		icon.size = Vector2(side - inset * 2.0, side - inset * 2.0)
