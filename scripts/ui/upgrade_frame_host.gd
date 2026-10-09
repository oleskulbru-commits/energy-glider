extends Container

## Fits the frame art and the panel contents to one rect.
## The frame script stretches only the straight edges, so this rect can be
## taller than the source artwork without squashing the side diamonds.


func _get_minimum_size() -> Vector2:
	return custom_minimum_size


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var rect := Rect2(Vector2.ZERO, size)
	for child in get_children():
		fit_child_in_rect(child, rect)
