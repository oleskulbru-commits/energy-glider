extends SceneTree

const HUDScene := preload("res://scenes/ui/glider_hud.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_stop_content_lists_vertically()
	if _failed:
		quit(1)
		return
	print("Stopped overlay verification passed.")
	quit(0)


func _verify_stop_content_lists_vertically() -> void:
	var hud: GliderHUD = HUDScene.instantiate() as GliderHUD
	_fail_unless(hud != null, "Glider HUD scene should instantiate")
	if _failed:
		return
	root.add_child(hud)
	await process_frame

	var panel: Control = hud.get_node("%DeathStatsPanel") as Control
	var distance: Control = hud.get_node("%StoppedDistance") as Control
	var summary: Control = hud.get_node("%StoppedSummary") as Control
	_fail_unless(panel != null, "DeathStatsPanel should exist")
	_fail_unless(distance != null, "StoppedDistance should exist")
	_fail_unless(summary != null, "StoppedSummary should exist")
	if _failed:
		hud.queue_free()
		return

	var stack := distance.get_parent()
	_fail_unless(stack is VBoxContainer, "Stop content should share a VBoxContainer")
	_fail_unless(
		panel.get_parent() == stack and summary.get_parent() == stack,
		"DeathStatsPanel, StoppedDistance, and StoppedSummary should be siblings in one stack"
	)
	_fail_unless(
		stack.get_parent() is CenterContainer,
		"The vertical stack should stay centered in the overlay"
	)
	_fail_unless(
		not (stack is CenterContainer),
		"Stop labels must not be direct CenterContainer children"
	)

	var overlay: Control = hud.get_node("%StoppedOverlay") as Control
	overlay.visible = true
	hud.call("_update_stopped_overlay")
	await process_frame
	await process_frame

	_fail_unless(panel.visible, "Non-death stop should keep the panel title")
	_fail_unless(distance.visible, "Non-death stop should show distance")
	_fail_unless(summary.visible, "Non-death stop should show score")
	_fail_unless(
		not _rects_overlap(panel, distance),
		"Stopped title and distance should not stack on top of each other"
	)
	_fail_unless(
		not _rects_overlap(distance, summary),
		"Distance and score should not stack on top of each other"
	)
	_fail_unless(
		distance.global_position.y >= panel.global_position.y + panel.size.y - 1.0,
		"Distance should list below the stop title"
	)
	_fail_unless(
		summary.global_position.y >= distance.global_position.y + distance.size.y - 1.0,
		"Score should list below distance"
	)

	hud.queue_free()


func _rects_overlap(a: Control, b: Control) -> bool:
	return a.get_global_rect().intersects(b.get_global_rect())


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
