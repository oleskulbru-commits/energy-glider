extends SceneTree

const LaserGroundReticleScript := preload("res://scripts/enemies/laser_ground_reticle.gd")
const LaserDroneTelegraphScript := preload("res://scripts/enemies/laser_drone_telegraph.gd")
const ReticleShader := preload("res://assets/vfx/shaders/laser_ground_reticle.gdshader")


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
		source.find("laser_ground_reticle.gdshader") != -1,
		"Laser ground reticle should use laser_ground_reticle shader"
	)
	_fail_unless(
		source.find("TerrainQueryScript.sample_surface") != -1,
		"Laser ground reticle should align to terrain under the target"
	)
	_fail_unless(
		source.find("circle_trace") == -1,
		"Ground reticle should not use circle trace shader wiring"
	)
	_fail_unless(
		source.find("frame_index_for_telegraph") != -1,
		"Ground reticle should spread flipbook frames across the full telegraph"
	)
	_fail_unless(
		source.find("get_deck_world_basis") != -1,
		"Ground reticle should align to deck forward on the ground"
	)
	_fail_unless(
		source.find("_build_conforming_mesh") != -1,
		"Ground reticle should use a terrain-conforming mesh grid"
	)
	_fail_unless(
		source.find("ReticleLight") != -1,
		"Ground reticle should include a red omni light"
	)
	_fail_unless(
		is_equal_approx(LaserGroundReticleScript.QUAD_SIZE_M, 8.4),
		"Laser ground reticle should be 8.4 m across"
	)

	var shader_source := FileAccess.get_file_as_string("res://assets/vfx/shaders/laser_ground_reticle.gdshader")
	_fail_unless(
		shader_source.find("circle_trace") == -1,
		"Ground reticle shader should not draw a circle ring"
	)

	var drone_source := FileAccess.get_file_as_string("res://scripts/enemies/laser_drone.gd")
	_fail_unless(
		drone_source.find("LaserGroundReticleScript") != -1,
		"Laser drone should drive a ground reticle"
	)
	_fail_unless(
		drone_source.find("set_laser_target_telegraph_active") == -1,
		"Laser drone should no longer drive the HUD reticle"
	)


func _verify_spawn() -> void:
	var root := Node3D.new()
	root.name = "VerifyRoot"
	get_root().add_child(root)

	var target := Node3D.new()
	root.add_child(target)
	target.global_position = Vector3(2.0, 5.0, -1.0)

	var reticle: Node3D = LaserGroundReticleScript.spawn(self, target, null)
	await process_frame
	_fail_unless(is_instance_valid(reticle), "Laser ground reticle should spawn")
	_fail_unless(
		reticle.get_node_or_null("ReticleQuad") != null,
		"Laser ground reticle should expose ReticleQuad"
	)
	_fail_unless(
		reticle.get_node_or_null("ReticleLight") is OmniLight3D,
		"Laser ground reticle should expose ReticleLight"
	)

	reticle.update_telegraph(LaserDroneTelegraphScript.SHRINK_SEC * 0.5)
	var mesh := reticle.get_node("ReticleQuad") as MeshInstance3D
	var mat := mesh.material_override as ShaderMaterial
	_fail_unless(mat != null, "Laser ground reticle should use ShaderMaterial")
	_fail_unless(mat.shader == ReticleShader, "Laser ground reticle should use laser_ground_reticle shader")
	_fail_unless(
		mat.get_shader_parameter("frame_tex") != null,
		"Laser ground reticle should bind a flipbook frame"
	)

	var mid_frame := LaserDroneTelegraphScript.frame_index_for_telegraph(
		LaserDroneTelegraphScript.SHRINK_SEC * 0.5,
		LaserGroundReticleScript.FRAME_COUNT
	)
	_fail_unless(mid_frame > 0, "Ground reticle should advance flipbook frames during shrink")

	reticle.update_telegraph(LaserDroneTelegraphScript.SHRINK_SEC + 0.5)
	var blink_frame := LaserDroneTelegraphScript.frame_index_for_telegraph(
		LaserDroneTelegraphScript.SHRINK_SEC + 0.5,
		LaserGroundReticleScript.FRAME_COUNT
	)
	_fail_unless(
		blink_frame < LaserGroundReticleScript.FRAME_COUNT - 1,
		"Ground reticle should keep animating during blink phase"
	)
	_fail_unless(
		blink_frame > mid_frame,
		"Ground reticle flipbook should progress into the blink phase"
	)

	var basis_before := reticle.global_basis
	target.rotation.y = PI * 0.5
	reticle.update_telegraph(LaserDroneTelegraphScript.SHRINK_SEC + 0.5)
	_fail_unless(
		not reticle.global_basis.is_equal_approx(basis_before),
		"Ground reticle should rotate when the target facing changes"
	)

	reticle.queue_free()
	target.queue_free()
	root.queue_free()
