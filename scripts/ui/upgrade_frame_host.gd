extends Container

## Holds the upgrade panel at the frame artwork's size.
## The side diamonds sit in the vertical middle of the art, so a taller
## panel would stretch them. Children are fitted to this rect instead.


func _get_minimum_size() -> Vector2:
	return custom_minimum_size


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var rect := Rect2(Vector2.ZERO, size)
	for child in get_children():
		fit_child_in_rect(child, rect)
