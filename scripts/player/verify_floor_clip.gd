extends SceneTree

const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.hover_compression_scale(-0.2), 1.0),
		"Under the sand, hover repulsion must stay at full strength"
	)
	var rest := _ctx(GliderPhysicsScript.BASE_HEIGHT)
	var buried := _ctx(-0.25, Vector3(0.0, -3.0, 16.0))
	var force_rest := GliderPhysicsScript.compute_hover_force(rest, 90.0, 1.0 / 60.0)
	var force_buried := GliderPhysicsScript.compute_hover_force(buried, 90.0, 1.0 / 60.0)
	_fail_unless(force_rest.y <= 0.0, "At hover height should not push up")
	_fail_unless(force_buried.y > 0.0, "Buried board should push out of the sand")
	_fail_unless(
		force_buried.y > absf(force_rest.y),
		"Buried repulsion should exceed rest recovery"
	)
	print("Floor clip kernel verification passed.")
	quit(0)


func _ctx(clearance: float, velocity: Vector3 = Vector3.ZERO) -> GliderPhysicsScript.Context:
	var ctx := GliderPhysicsScript.Context.new()
	ctx.ground_normal = Vector3.UP
	ctx.clearance = clearance
	ctx.hover_clearance = clearance
	ctx.velocity = velocity
	return ctx


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
