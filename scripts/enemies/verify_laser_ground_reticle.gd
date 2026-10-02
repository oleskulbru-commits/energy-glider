extends SceneTree

const LaserGroundReticleScript := preload("res://scripts/enemies/laser_ground_reticle.gd")
const LaserDroneTelegraphScript := preload("res://scripts/enemies/laser_drone_telegraph.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_constants()
	await _verify_spawn()
	print("Laser ground reticle verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _verify_constants() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/enemies/laser_ground_reticle.gd")
	_fail_unless(
		source.find("reticle_1_frame_") != -1,
		"Laser ground reticle should use reticle_1 flipbook"
	)
	_fail_unless(
		source.find("_update_world_anchor") != -1,
		"Laser ground reticle should anchor in world space"
	)
	_fail_unless(
		source.find("top_level = true") != -1,
		"Laser ground reticle should use top_level for world anchoring"
	)
	_fail_unless(
		source.find("ReticleProjector") != -1,
		"Ground reticle should include a spot light projector"
	)
	_fail_unless(
		is_equal_approx(LaserGroundReticleScript.QUAD_SIZE_M, 8.4),
		"Laser ground reticle should keep 8.4 m footprint reference"
	)


func _verify_spawn() -> void:
	var root := Node3D.new()
	root.name = "VerifyRoot"
	get_root().add_child(root)

	var ground_body := StaticBody3D.new()
	root.add_child(ground_body)
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(80.0, 1.0, 80.0)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0.0, -0.5, 0.0)
	ground_body.add_child(ground_col)

	var target := Node3D.new()
	root.add_child(target)
	target.global_position = Vector3(2.0, 5.0, -1.0)

	var reticle: Node3D = LaserGroundReticleScript.spawn(self, target, null)
	await process_frame
	_fail_unless(is_instance_valid(reticle), "Laser ground reticle should spawn")
	_fail_unless(reticle.top_level, "Laser ground reticle should be top_level")
	_fail_unless(
		reticle.get_parent() == get_root(),
		"Laser ground reticle should live under the scene root, not the glider"
	)

	var spot := reticle.get_node_or_null("ReticleProjector") as SpotLight3D
	_fail_unless(spot != null, "Laser ground reticle should expose ReticleProjector")
	_fail_unless(spot.shadow_enabled, "Laser ground reticle spot should cast shadows")
	_fail_unless(
		is_equal_approx(spot.spot_angle, LaserGroundReticleScript.SPOT_ANGLE_DEG),
		"Laser ground reticle should use tuned spot angle"
	)

	_fail_unless(
		not LaserDroneTelegraphScript.reticle_lit(0.04),
		"Ground reticle should start with power-on glitch (off at 0.04 s)"
	)
	reticle.update_telegraph(0.5)
	await process_frame
	_fail_unless(
		LaserDroneTelegraphScript.reticle_lit(0.5),
		"Ground reticle should be lit after power-on glitch"
	)
	reticle.update_telegraph(0.5)
	await process_frame
	var shine_dir := -spot.global_transform.basis.z.normalized()
	_fail_unless(
		shine_dir.dot(Vector3.DOWN) > 0.85,
		"Reticle spot should shine toward the ground (got %s)" % shine_dir
	)

	reticle.update_telegraph(LaserDroneTelegraphScript.SHRINK_SEC * 0.5)
	_fail_unless(spot.light_projector != null, "Laser ground reticle should bind a flipbook frame")

	var y_before := reticle.global_position.y
	target.global_position.y += 12.0
	reticle.update_telegraph(LaserDroneTelegraphScript.SHRINK_SEC * 0.5)
	_fail_unless(
		absf(reticle.global_position.y - y_before) < 0.05,
		"Laser ground reticle Y should stay on hover height when the glider jumps"
	)

	var basis_before := reticle.global_basis
	target.rotation.y = PI * 0.5
	reticle.update_telegraph(LaserDroneTelegraphScript.SHRINK_SEC + 0.5)
	_fail_unless(
		not reticle.global_basis.is_equal_approx(basis_before),
		"Ground reticle should yaw with the target"
	)

	reticle.queue_free()
	target.queue_free()
	root.queue_free()
