class_name DamageFloat
extends RefCounted

## Shared floating hit numbers for the player bar and enemies.

const GROUP := &"damage_float"
const DURATION_SEC := 1.0
const RISE_M := 0.85
const RISE_VARIANCE_M := 0.18
const CRIT_RISE_M := 1.4
const CRIT_RISE_VARIANCE_M := 0.22
const SPREAD_X_MIN := 0.22
const SPREAD_X_MAX := 0.7
const BULGE_X_MIN := 0.12
const BULGE_X_MAX := 0.4
const WORLD_SPREAD_X_MIN := 0.7
const WORLD_SPREAD_X_MAX := 1.8
const WORLD_BULGE_X_MIN := 0.35
const WORLD_BULGE_X_MAX := 0.95
const FONT_SIZE := 72
const PIXEL_SIZE := 0.018
const FONT := preload("res://assets/fonts/bungee/Bungee-Regular.ttf")
const COLOR := Color(1.0, 0.18, 0.16, 1.0)
const OUTLINE_COLOR := Color(0.15, 0.02, 0.02, 0.9)
const CRIT_COLOR := Color(1.0, 0.84, 0.22, 1.0)
const CRIT_OUTLINE_COLOR := Color(0.28, 0.14, 0.02, 0.9)
const CRIT_SCALE := 1.5
const OUTLINE_SIZE := 12
const CRIT_OUTLINE_SIZE := 18
const POP_START_SCALE := 0.18
const POP_IN_SEC := 0.22
const CRIT_POP_IN_SEC := 0.28


static func text_for(amount: int) -> String:
	return "%d" % amount


static func camera_right(from: Node) -> Vector3:
	if from == null or not from.is_inside_tree():
		return Vector3.RIGHT
	var viewport := from.get_viewport()
	if viewport == null:
		return Vector3.RIGHT
	var cam := viewport.get_camera_3d()
	if cam == null:
		return Vector3.RIGHT
	var right := cam.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		return Vector3.RIGHT
	return right.normalized()


static func roll_path(
	start: Vector3,
	rng: RandomNumberGenerator,
	world := false,
	is_crit := false
) -> Dictionary:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var spread_min := WORLD_SPREAD_X_MIN if world else SPREAD_X_MIN
	var spread_max := WORLD_SPREAD_X_MAX if world else SPREAD_X_MAX
	var bulge_min := WORLD_BULGE_X_MIN if world else BULGE_X_MIN
	var bulge_max := WORLD_BULGE_X_MAX if world else BULGE_X_MAX
	var rise := CRIT_RISE_M if is_crit else RISE_M
	var rise_var := CRIT_RISE_VARIANCE_M if is_crit else RISE_VARIANCE_M
	return {
		"end_x": start.x + side * rng.randf_range(spread_min, spread_max),
		"end_y": start.y + rng.randf_range(rise - rise_var, rise + rise_var),
		"bulge_x": side * rng.randf_range(bulge_min, bulge_max),
	}


static func float_point(
	t: float,
	start: Vector3,
	end_x: float,
	end_y: float,
	bulge_x: float
) -> Vector3:
	t = clampf(t, 0.0, 1.0)
	var mid := Vector3(
		lerpf(start.x, end_x, 0.5) + bulge_x,
		lerpf(start.y, end_y, 0.5),
		start.z
	)
	var end := Vector3(end_x, end_y, start.z)
	var omt := 1.0 - t
	return omt * omt * start + 2.0 * omt * t * mid + t * t * end


static func _apply_path(
	t: float,
	label: Label3D,
	start: Vector3,
	end_x: float,
	end_y: float,
	bulge_x: float
) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.position = float_point(t, start, end_x, end_y, bulge_x)


static func _apply_screen_path(
	t: float,
	label: Label3D,
	origin: Vector3,
	start: Vector3,
	end_x: float,
	end_y: float,
	bulge_x: float
) -> void:
	if label == null or not is_instance_valid(label):
		return
	var point := float_point(t, start, end_x, end_y, bulge_x)
	label.global_position = origin + camera_right(label) * point.x + Vector3.UP * point.y


static func spawn(
	parent: Node,
	amount: int,
	rng: RandomNumberGenerator,
	free_parent := false,
	is_crit := false,
	screen_path := false
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
	label.font = FONT
	label.font_size = FONT_SIZE
	label.pixel_size = PIXEL_SIZE
	label.outline_size = CRIT_OUTLINE_SIZE if is_crit else OUTLINE_SIZE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.add_to_group(GROUP)
	label.scale = Vector3.ONE * POP_START_SCALE
	label.position = Vector3(
		rng.randf_range(-SPREAD_X_MIN, SPREAD_X_MIN),
		0.12,
		0.02
	)
	parent.add_child(label)

	var start := label.position
	var path := roll_path(start, rng, screen_path, is_crit)
	var world_origin := Vector3.ZERO
	if parent is Node3D:
		world_origin = (parent as Node3D).global_position
	var tween := parent.create_tween()
	tween.set_parallel(true)
	if screen_path:
		tween.tween_method(
			_apply_screen_path.bind(
				label, world_origin, start, path.end_x, path.end_y, path.bulge_x
			),
			0.0,
			1.0,
			DURATION_SEC
		)
	else:
		tween.tween_method(
			_apply_path.bind(label, start, path.end_x, path.end_y, path.bulge_x),
			0.0,
			1.0,
			DURATION_SEC
		)
	tween.tween_property(label, "modulate:a", 0.0, DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "outline_modulate:a", 0.0, DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var pop := parent.create_tween()
	var pop_scale := Vector3.ONE * (CRIT_SCALE if is_crit else 1.0)
	var pop_sec := CRIT_POP_IN_SEC if is_crit else POP_IN_SEC
	pop.tween_property(label, "scale", pop_scale, pop_sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var stop_motion := func() -> void:
		if tween.is_valid():
			tween.kill()
		if pop.is_valid():
			pop.kill()
	label.tree_exiting.connect(stop_motion, CONNECT_ONE_SHOT)
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
	return spawn(host, amount, rng, true, is_crit, true)
