class_name DamageFloat
extends RefCounted

## Shared falling "-N" hit numbers for the player bar and enemies.

const GROUP := &"damage_float"
const DURATION_SEC := 0.75
const FALL_M := 0.85
const SPREAD_X := 0.55
const FONT_SIZE := 72
const PIXEL_SIZE := 0.018
const COLOR := Color(1.0, 0.18, 0.16, 1.0)
const OUTLINE_COLOR := Color(0.15, 0.02, 0.02, 0.9)
const CRIT_COLOR := Color(1.0, 0.84, 0.22, 1.0)
const CRIT_OUTLINE_COLOR := Color(0.28, 0.14, 0.02, 0.9)


static func text_for(amount: int) -> String:
	return "-%d" % amount


static func spawn(
	parent: Node,
	amount: int,
	rng: RandomNumberGenerator,
	free_parent := false,
	is_crit := false
) -> Label3D:
	if parent == null or amount <= 0:
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var label := Label3D.new()
	label.text = text_for(amount)
	label.modulate = CRIT_COLOR if is_crit else COLOR
	label.outline_modulate = CRIT_OUTLINE_COLOR if is_crit else OUTLINE_COLOR
	label.font_size = FONT_SIZE
	label.pixel_size = PIXEL_SIZE
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.add_to_group(GROUP)
	label.position = Vector3(
		rng.randf_range(-SPREAD_X * 0.35, SPREAD_X * 0.35),
		0.12,
		0.02
	)
	parent.add_child(label)

	var end_x := label.position.x + rng.randf_range(-SPREAD_X, SPREAD_X)
	var end_y := label.position.y - FALL_M
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:x", end_x, DURATION_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", end_y, DURATION_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 0.0, DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "outline_modulate:a", 0.0, DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if free_parent:
		tween.chain().tween_callback(parent.queue_free)
	else:
		tween.chain().tween_callback(label.queue_free)
	return label


static func spawn_world(
	anchor: Node3D,
	amount: int,
	rng: RandomNumberGenerator,
	height_m: float,
	is_crit := false
) -> Label3D:
	if anchor == null or not anchor.is_inside_tree() or amount <= 0:
		return null
	var tree := anchor.get_tree()
	if tree == null:
		return null
	var parent: Node = tree.current_scene
	if parent == null:
		parent = anchor.get_parent()
	if parent == null:
		return null
	var host := Node3D.new()
	host.name = "DamageFloatHost"
	parent.add_child(host)
	host.global_position = anchor.global_position + Vector3(0.0, height_m, 0.0)
	return spawn(host, amount, rng, true, is_crit)
