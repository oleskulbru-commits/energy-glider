extends SceneTree

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const TerrainProbesScript = preload("res://scripts/player/terrain_probes.gd")
const GliderInputScript = preload("res://scripts/input/glider_input.gd")
const TerrainManagerScript = preload("res://scripts/terrain/terrain_manager.gd")
const GliderScene = preload("res://scenes/player/glider.tscn")
const GliderCameraScript = preload("res://scripts/player/glider_camera.gd")
const SandMaterial = preload("res://materials/sand.tres")

const PHYSICS_DT := 1.0 / 60.0
const HOVER_SETTLE_FRAMES := 120
const HOVER_TOLERANCE := 0.12


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _init() -> void:
	call_deferred("_run_tests")


func _get_input(glider: GliderPlayer) -> GliderInputScript:
	var input := glider.get_node_or_null("GliderInput") as GliderInputScript
	if input != null:
		return input
	var parent := glider.get_parent()
	if parent != null:
		input = parent.get_node_or_null("GliderInput") as GliderInputScript
		if input != null:
			return input
	input = GliderInputScript.new()
	input.name = "GliderInput"
	glider.add_child(input)
	return input


func _hold_forward() -> void:
	Input.action_press("move_forward")


func _release_forward() -> void:
	Input.action_release("move_forward")


func _hold_boost() -> void:
	Input.action_press("move_forward")
	Input.action_press("boost")


func _release_boost() -> void:
	Input.action_release("boost")
	Input.action_release("move_forward")


func _release_all_input() -> void:
	Input.action_release("move_forward")
	Input.action_release("boost")
	Input.action_release("brake")
	Input.action_release("jump")
	Input.action_release("steer_left")
	Input.action_release("steer_right")


func _spawn_terrain(name_suffix: String) -> TerrainManager:
	var terrain: TerrainManager = TerrainManagerScript.new()
	terrain.sand_material = SandMaterial
	terrain.name = "VerifyTerrain_%s" % name_suffix
	root.add_child(terrain)
	return terrain


func _spawn_glider(terrain: TerrainManager) -> GliderPlayer:
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	root.add_child(glider)
	return glider


func _hover_spawn_y(terrain: TerrainManager, world_x: float = 0.0, world_z: float = 0.0) -> float:
	return terrain.sample_height(world_x, world_z) + GliderPhysicsScript.BASE_HEIGHT + 0.05


func _min_board_clearance(glider: GliderPlayer) -> float:
	return glider.call("_live_min_board_probe_clearance")


func _yaw_travel_misalign_deg(glider: GliderPlayer) -> float:
	var travel := Vector2(glider.velocity.x, glider.velocity.z)
	if travel.length_squared() < 1.0:
		return 0.0
	var yaw_dir := Vector2(sin(glider.get_yaw()), cos(glider.get_yaw()))
	return absf(wrapf(travel.angle() - yaw_dir.angle(), -PI, PI))


func _run_tests() -> void:
	_verify_chase_camera_math()
	await _verify_hover_rest()
	await _verify_terrain_probes_math()
	await _verify_predictive_surface_sampling()
	await _verify_hover_kernel()
	await _verify_corner_hover_forces()
	await _verify_ground_cruise()
	await _verify_climb_no_clip()
	await _verify_sail_recharge_in_air()
	await _verify_glide_gravity()
	await _verify_brake_stop()
	await _verify_no_false_launch_cruise()
	await _verify_hover_no_clip_crest()
	await _verify_cruise_momentum_crest()
	await _verify_crest_air_gravity_ramp()
	await _verify_inertia_jump()
	await _verify_cruise_drift_align()
	await _verify_touchdown_slope_momentum()
	await _verify_touchdown_soft()
	await _verify_hover_yield_kernel()
	await _verify_hard_landing_contact()
	await _verify_boost_no_clip_crest()
	await _verify_boost_climb_no_clip()
	await _verify_boost_steep_climb_no_clip()
	await _verify_boost_hover_no_soften()
	await _verify_jump_while_boosting()
	print("Glider controller verification passed.")
	quit(0)


func _verify_chase_camera_math() -> void:
	var diff := GliderCameraScript.angle_diff(0.0, PI * 0.5)
	_fail_unless(absf(diff - PI * 0.5) < 0.001, "angle_diff should return shortest delta (got %.3f)" % diff)

	var wrapped := GliderCameraScript.angle_diff(0.1, -PI + 0.2)
	_fail_unless(absf(wrapped) < PI, "angle_diff should wrap to [-PI, PI] (got %.3f)" % wrapped)

	var chase_yaw := 0.0
	var chase_velocity := 0.0
	var target_yaw := deg_to_rad(45.0)
	for i in 240:
		var step := GliderCameraScript.step_chase_yaw(
			chase_yaw,
			chase_velocity,
			target_yaw,
			PHYSICS_DT,
			GliderCameraScript.CRUISE_CHASE_STIFFNESS,
			GliderCameraScript.CHASE_DAMPING
		)
		chase_yaw = step.chase_yaw
		chase_velocity = step.chase_yaw_velocity

	var error := absf(GliderCameraScript.angle_diff(chase_yaw, target_yaw))
	_fail_unless(error < deg_to_rad(5.0), "Chase spring should converge (error %.2f deg)" % rad_to_deg(error))
	_fail_unless(absf(chase_velocity) < 0.5, "Chase spring should settle with low velocity (got %.3f)" % chase_velocity)


func _verify_hover_rest() -> void:
	var terrain := _spawn_terrain("hover")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	var settled := false
	for i in HOVER_SETTLE_FRAMES:
		await physics_frame
		if absf(glider.get_clearance() - GliderPhysicsScript.BASE_HEIGHT) <= HOVER_TOLERANCE:
			settled = true
			break

	_fail_unless(settled, "Idle grounded should settle near %.2f m (got %.2f)" % [
		GliderPhysicsScript.BASE_HEIGHT, glider.get_clearance()
	])
	_fail_unless(glider.is_grounded(), "Hover rest should stay grounded")
	glider.queue_free()
	terrain.queue_free()


func _hover_ctx(clearance: float, normal_vel: float = 0.0) -> GliderPhysicsScript.Context:
	var ctx := GliderPhysicsScript.Context.new()
	ctx.ground_normal = Vector3.UP
	ctx.clearance = clearance
	ctx.hover_clearance = clearance
	ctx.velocity = Vector3.UP * normal_vel
	return ctx


func _verify_hover_kernel() -> void:
	var target := GliderPhysicsScript.BASE_HEIGHT
	var above := _hover_ctx(target + 0.35)
	var below := _hover_ctx(target - 0.08, -0.4)
	var force_above := GliderPhysicsScript.compute_hover_force(above, 90.0, PHYSICS_DT)
	var force_below := GliderPhysicsScript.compute_hover_force(below, 90.0, PHYSICS_DT)
	_fail_unless(force_above.y <= 0.0, "Above target should not push up")
	_fail_unless(force_below.y > 0.0, "Below target should push up")


func _verify_corner_hover_forces() -> void:
	var ctx := _hover_ctx(GliderPhysicsScript.BASE_HEIGHT - 0.08)
	var flat_points: Array = []
	for offset in [
		Vector3(-0.4, 0.0, -1.0),
		Vector3(0.4, 0.0, -1.0),
		Vector3(-0.4, 0.0, 1.0),
		Vector3(0.4, 0.0, 1.0),
	]:
		var point := GliderPhysicsScript.HoverPointSample.new()
		point.local_offset = offset
		point.clearance = GliderPhysicsScript.BASE_HEIGHT - 0.08
		point.normal = Vector3.UP
		point.valid = true
		flat_points.append(point)

	var front_low: Array = []
	for offset in [
		Vector3(-0.4, 0.0, -1.0),
		Vector3(0.4, 0.0, -1.0),
		Vector3(-0.4, 0.0, 1.0),
		Vector3(0.4, 0.0, 1.0),
	]:
		var point := GliderPhysicsScript.HoverPointSample.new()
		point.local_offset = offset
		point.clearance = (
			GliderPhysicsScript.BASE_HEIGHT - 0.16
			if offset.z > 0.0
			else GliderPhysicsScript.BASE_HEIGHT - 0.08
		)
		point.normal = Vector3.UP
		point.valid = true
		front_low.append(point)

	var flat_forces := GliderPhysicsScript.compute_corner_hover_forces(
		ctx, 90.0, PHYSICS_DT, flat_points
	)
	var low_front_forces := GliderPhysicsScript.compute_corner_hover_forces(
		ctx, 90.0, PHYSICS_DT, front_low
	)
	_fail_unless(flat_forces.size() == 4, "Flat hover should drive all four corners")
	_fail_unless(low_front_forces.size() == 4, "Uneven hover should still drive all corners")

	var flat_up := 0.0
	var low_front_up := 0.0
	var front_corner_up := 0.0
	for hover_force in flat_forces:
		flat_up += hover_force.force.y
	for i in low_front_forces.size():
		var hover_force: GliderPhysicsScript.AppliedHoverForce = low_front_forces[i]
		low_front_up += hover_force.force.y
		if front_low[i].local_offset.z > 0.0:
			front_corner_up += hover_force.force.y
	_fail_unless(flat_up > 0.0, "Corner hover should lift when compressed")
	_fail_unless(
		low_front_up > flat_up * 1.05,
		"Lower front corners should add more total lift (%.1f vs %.1f)" % [low_front_up, flat_up]
	)
	var flat_front_up := 0.0
	for i in flat_forces.size():
		if flat_points[i].local_offset.z > 0.0:
			flat_front_up += flat_forces[i].force.y
	_fail_unless(
		front_corner_up > flat_front_up * 1.2,
		"Compressed front corners should lift harder than flat case (%.1f vs %.1f)" % [
			front_corner_up, flat_front_up
		]
	)


func _verify_terrain_probes_math() -> void:
	var left := Vector3(0.12, 0.99, 0.0).normalized()
	var right := Vector3(-0.12, 0.99, 0.0).normalized()
	var avg := TerrainProbesScript.average_normals([left, right])
	_fail_unless(avg.dot(Vector3.UP) > 0.98, "Averaged normals should point mostly up (got %s)" % avg)
	_fail_unless(absf(avg.x) < 0.05, "Averaged normals should cancel lateral bias (got %s)" % avg)

	var ramp_points: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 2.0),
		Vector3(2.0, 1.0, 2.0),
	]
	var plane := TerrainProbesScript.fit_plane_normal(ramp_points)
	_fail_unless(plane.y > 0.4, "Plane fit should tilt with ramp (got %s)" % plane)
	_fail_unless(plane.z < -0.2, "Ramp plane should pitch nose-up toward +Z (got %s)" % plane)

	var board_points: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.4, 0.0, 1.0),
		Vector3(-0.4, 0.0, 1.0),
		Vector3(0.0, 0.0, -1.0),
	]
	var board_plane := TerrainProbesScript.fit_plane_normal(board_points)
	_fail_unless(board_plane.y > 0.4, "Board plane should tilt with ramp (got %s)" % board_plane)


func _verify_predictive_surface_sampling() -> void:
	var terrain := _spawn_terrain("predictive")
	await physics_frame

	var glider := _spawn_glider(terrain)
	glider.global_position = Vector3(32.0, _hover_spawn_y(terrain, 32.0, 32.0), 32.0)
	glider.velocity = Vector3(0.0, 0.0, 6.0)
	await physics_frame

	_fail_unless(glider.is_grounded(), "Predictive probe test should start grounded")
	var predictive_normal: Vector3 = glider.get_predictive_normal()
	_fail_unless(predictive_normal.length() > 0.9, "Predictive normal should be unit length")
	_fail_unless(predictive_normal.dot(Vector3.UP) > 0.5, "Predictive normal should face up on sand")

	var input := _get_input(glider)
	_hold_forward()
	var max_basis_step := 0.0
	var prev_basis := glider.get_deck_world_basis()
	for i in 90:
		await physics_frame
		var basis := glider.get_deck_world_basis()
		var step := basis.get_rotation_quaternion().angle_to(prev_basis.get_rotation_quaternion())
		max_basis_step = maxf(max_basis_step, step)
		prev_basis = basis

	_fail_unless(
		max_basis_step < deg_to_rad(18.0),
		"Predictive alignment should not pop deck basis (max step %.1f deg)" % rad_to_deg(max_basis_step)
	)

	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_ground_cruise() -> void:
	var terrain := _spawn_terrain("cruise")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + GliderPhysicsScript.BASE_HEIGHT + 0.05, 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	_hold_forward()
	var clearance_sum := 0.0
	var samples := 0
	for i in 150:
		await physics_frame
		_fail_unless(glider.is_grounded(), "Flat cruise should stay grounded (frame %d)" % i)
		if i >= 120:
			clearance_sum += glider.get_clearance()
			samples += 1

	var speed := Vector2(glider.velocity.x, glider.velocity.z).length()
	_fail_unless(speed > 3.6, "Cruise should build speed (got %.2f)" % speed)
	_fail_unless(clearance_sum / float(samples) > 0.55, "Cruise should maintain hover height")
	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_climb_no_clip() -> void:
	var terrain := _spawn_terrain("climb")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	var world_x := 40.0
	var world_z := 40.0
	glider.global_position = Vector3(
		world_x,
		_hover_spawn_y(terrain, world_x, world_z),
		world_z
	)
	glider.velocity = Vector3(0.0, 0.0, 5.0)
	await physics_frame

	_hold_forward()
	var min_clearance := INF
	for i in 180:
		await physics_frame
		if glider.is_gliding():
			break
		if glider.is_grounded() or glider.get("_state") == GliderPlayerScript.State.LANDING:
			min_clearance = minf(min_clearance, glider.get_raw_clearance())

	_fail_unless(
		min_clearance >= -0.04,
		"Uphill thrust should not clip sand (min clearance %.2f)" % min_clearance
	)
	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_sail_recharge_in_air() -> void:
	var terrain := _spawn_terrain("air_recharge")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + 4.0, 0.0)
	glider.velocity = Vector3(0.0, 0.0, 8.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	glider.set("_charge", 0.3)
	await physics_frame

	_fail_unless(glider.is_gliding(), "Air recharge test needs gliding state")
	_fail_unless(
		glider.get_clearance() > GliderPhysicsScript.HOVER_ZONE,
		"Air recharge test needs clearance above hover zone"
	)

	_hold_forward()
	var start_charge := glider.get_charge_ratio()
	for i in 90:
		await physics_frame
	var end_charge := glider.get_charge_ratio()
	_fail_unless(
		end_charge > start_charge + 0.05,
		"Sail should recharge in air (%.2f -> %.2f)" % [start_charge, end_charge]
	)

	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_glide_gravity() -> void:
	var terrain := _spawn_terrain("glide")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + 3.0, 0.0)
	glider.velocity = Vector3(0.0, -2.0, 0.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	var start_y := glider.global_position.y
	for i in 60:
		await physics_frame
	_fail_unless(glider.global_position.y < start_y - 0.2, "Passive glide should lose altitude")
	glider.queue_free()
	terrain.queue_free()


func _verify_brake_stop() -> void:
	var terrain := _spawn_terrain("brake")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + GliderPhysicsScript.BASE_HEIGHT + 0.1, 0.0)
	glider.velocity = Vector3(0.0, 0.0, 10.0)
	await physics_frame

	_hold_forward()
	for i in 30:
		await physics_frame
	var start_speed := Vector2(glider.velocity.x, glider.velocity.z).length()

	Input.action_press("brake")
	for i in 90:
		await physics_frame
	Input.action_release("brake")

	var end_speed := Vector2(glider.velocity.x, glider.velocity.z).length()
	_fail_unless(end_speed < start_speed * 0.5, "Brake should reduce speed")
	_fail_unless(glider.is_grounded(), "Brake should keep glider grounded")
	glider.queue_free()
	terrain.queue_free()


func _verify_no_false_launch_cruise() -> void:
	var terrain := _spawn_terrain("no_launch")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + GliderPhysicsScript.BASE_HEIGHT + 0.05, 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	_hold_forward()
	for i in 150:
		await physics_frame
		_fail_unless(glider.is_grounded(), "Flat cruise should not enter gliding (frame %d)" % i)

	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_hover_no_clip_crest() -> void:
	var terrain := _spawn_terrain("crest")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	glider.global_position = Vector3(32.0, _hover_spawn_y(terrain, 32.0, 32.0), 32.0)
	glider.velocity = Vector3(0.0, 0.0, 6.0)
	await physics_frame

	_hold_forward()
	var min_clearance := INF
	for i in 120:
		await physics_frame
		min_clearance = minf(min_clearance, glider.get_raw_clearance())

	_fail_unless(
		min_clearance >= -0.06,
		"Crest cruise should not clip sand (min clearance %.2f)" % min_clearance
	)
	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_cruise_momentum_crest() -> void:
	var terrain := _spawn_terrain("momentum")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	glider.global_position = Vector3(32.0, _hover_spawn_y(terrain, 32.0, 32.0), 32.0)
	glider.velocity = Vector3(0.0, 0.0, 6.0)
	await physics_frame

	_hold_forward()
	var speeds: Array[float] = []
	for i in 120:
		await physics_frame
		_fail_unless(glider.is_grounded(), "Crest momentum cruise should stay grounded (frame %d)" % i)
		speeds.append(Vector2(glider.velocity.x, glider.velocity.z).length())

	var peak := 0.0
	for i in range(60, speeds.size()):
		peak = maxf(peak, speeds[i])
		_fail_unless(
			speeds[i] >= peak * 0.82,
			"Cruise momentum should not tug sharply on crests (%.2f vs peak %.2f at frame %d)" % [
				speeds[i], peak, i
			]
		)

	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_crest_air_gravity_ramp() -> void:
	var ctx := GliderPhysicsScript.Context.new()
	ctx.air_gravity_scale = 0.0
	var zero_gravity := GliderPhysicsScript.air_gravity_force(ctx, 90.0)
	_fail_unless(absf(zero_gravity.y) < 1.0, "Ramped air start should not pull down (got %.1f)" % zero_gravity.y)

	ctx.air_gravity_scale = 1.0
	var full_gravity := GliderPhysicsScript.air_gravity_force(ctx, 90.0)
	_fail_unless(full_gravity.y < -1000.0, "Full air gravity should pull down (got %.1f)" % full_gravity.y)

	var ramped := smoothstep(0.0, GliderPhysicsScript.AIR_GRAVITY_RAMP_DURATION, 0.125)
	ctx.air_gravity_scale = ramped
	var mid_gravity := GliderPhysicsScript.air_gravity_force(ctx, 90.0)
	_fail_unless(
		absf(mid_gravity.y) < absf(full_gravity.y),
		"Mid-ramp gravity should be weaker than full gravity"
	)


func _verify_inertia_jump() -> void:
	var slow := GliderPhysicsScript.apply_inertia_jump(
		Vector3(0.0, 0.0, 4.0), Vector3.UP, 4.0
	)
	var fast := GliderPhysicsScript.apply_inertia_jump(
		Vector3(0.0, 0.0, 14.0), Vector3.UP, 14.0
	)
	_fail_unless(
		fast.y > slow.y + 0.5,
		"Faster travel should add more jump height (slow %.2f vs fast %.2f)" % [slow.y, fast.y]
	)
	_fail_unless(
		Vector2(fast.x, fast.z).length() >= 13.5,
		"Jump should preserve horizontal inertia (got %.2f)" % Vector2(fast.x, fast.z).length()
	)

	var terrain := _spawn_terrain("jump")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	for i in 60:
		await physics_frame

	_fail_unless(glider.is_grounded(), "Jump test needs grounded glider before jump")
	glider.velocity = Vector3(0.0, 0.0, 10.0)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame

	_fail_unless(glider.is_gliding(), "Jump should enter gliding state")
	_fail_unless(glider.velocity.y > 0.4, "Jump should leave ground with upward speed (vy %.2f)" % glider.velocity.y)
	var horiz := Vector2(glider.velocity.x, glider.velocity.z).length()
	_fail_unless(horiz >= 5.5, "Jump should carry horizontal inertia (horiz %.2f)" % horiz)

	glider.queue_free()
	terrain.queue_free()


func _verify_cruise_drift_align() -> void:
	var terrain := _spawn_terrain("drift_align")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	glider.global_position = Vector3(32.0, _hover_spawn_y(terrain, 32.0, 32.0), 32.0)
	glider.set("_yaw", 0.0)
	glider.velocity = Vector3(2.0, 0.0, 6.0)
	await physics_frame

	_hold_forward()
	var initial_misalign := _yaw_travel_misalign_deg(glider)
	_fail_unless(
		initial_misalign >= deg_to_rad(10.0),
		"Drift test needs meaningful initial misalign (got %.1f deg)" % rad_to_deg(initial_misalign)
	)

	var early_misalign := initial_misalign
	for i in 10:
		await physics_frame
		early_misalign = minf(early_misalign, _yaw_travel_misalign_deg(glider))
	_fail_unless(
		early_misalign > initial_misalign * 0.55,
		"Cruise drift should not snap yaw instantly (%.1f -> %.1f deg in 10 frames)" % [
			rad_to_deg(initial_misalign), rad_to_deg(early_misalign)
		]
	)

	for i in 80:
		await physics_frame

	var final_misalign := _yaw_travel_misalign_deg(glider)
	_fail_unless(
		final_misalign <= initial_misalign * 0.6,
		"Cruise drift should align yaw toward travel (%.1f -> %.1f deg)" % [
			rad_to_deg(initial_misalign), rad_to_deg(final_misalign)
		]
	)

	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_touchdown_slope_momentum() -> void:
	var terrain := _spawn_terrain("slope_land")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var world_x := 48.0
	var world_z := 48.0
	var ground_y := terrain.sample_height(world_x, world_z)
	var pre_land_vel := Vector3(0.0, -4.0, 12.0)
	glider.global_position = Vector3(world_x, ground_y + 2.5, world_z)
	glider.velocity = pre_land_vel
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	var pre_h := Vector2(pre_land_vel.x, pre_land_vel.z).normalized()
	var pre_speed := Vector2(pre_land_vel.x, pre_land_vel.z).length()
	var landed := false
	for i in 180:
		await physics_frame
		if glider.is_grounded() and not landed:
			landed = true
			var post_h := Vector2(glider.velocity.x, glider.velocity.z)
			var post_speed := post_h.length()
			if pre_h.length_squared() > 0.01 and post_h.length_squared() > 0.01:
				var angle := absf(pre_h.angle_to(post_h.normalized()))
				_fail_unless(
					angle < deg_to_rad(35.0),
					"Slope landing redirected too far (%.1f deg)" % rad_to_deg(angle)
				)
			_fail_unless(
				post_speed <= pre_speed * 1.15,
				"Slope landing boosted speed (%.2f -> %.2f)" % [pre_speed, post_speed]
			)
			break

	_fail_unless(landed, "Slope touchdown test should land")
	glider.queue_free()
	terrain.queue_free()


func _verify_touchdown_soft() -> void:
	_release_all_input()
	var terrain := _spawn_terrain("land")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + GliderPhysicsScript.BASE_HEIGHT + 0.05, 0.0)
	glider.velocity = Vector3(0.0, -0.8, 2.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	var landed := false
	for i in 180:
		await physics_frame
		if glider.get("_state") == GliderPlayerScript.State.GROUNDED:
			landed = true
			break
	_fail_unless(landed, "Should land from small hop")

	for i in HOVER_SETTLE_FRAMES:
		await physics_frame
	var clearance := glider.get_raw_clearance() if glider.has_method("get_raw_clearance") else glider.get_clearance()
	_fail_unless(
		absf(clearance - GliderPhysicsScript.BASE_HEIGHT) < 0.35,
		"After landing should settle near hover rest (clearance %.2f)" % clearance
	)
	glider.queue_free()
	terrain.queue_free()


func _verify_hover_yield_kernel() -> void:
	var cruise := _hover_ctx(GliderPhysicsScript.BASE_HEIGHT - 0.05)
	var compressed := _hover_ctx(GliderPhysicsScript.HOVER_COMPRESS_START * 0.5)
	compressed.landing_approach = 9.0
	compressed.landing_impact = 1.0
	compressed.ground_contact = true
	compressed.contact_recover = 0.0

	var cruise_force := GliderPhysicsScript.compute_hover_force(cruise, 90.0, PHYSICS_DT)
	var compressed_force := GliderPhysicsScript.compute_hover_force(compressed, 90.0, PHYSICS_DT)
	_fail_unless(
		compressed_force.y < cruise_force.y * 0.35,
		"Hover should yield on hard ground contact (%.1f vs %.1f)" % [
			compressed_force.y, cruise_force.y
		]
	)
	_fail_unless(
		GliderPhysicsScript.compute_contact_damage(5.0) <= 0.0,
		"Soft contact should not damage"
	)
	_fail_unless(
		GliderPhysicsScript.compute_contact_damage(10.0) > 0.0,
		"Hard contact should damage"
	)


func _verify_hard_landing_contact() -> void:
	var terrain := _spawn_terrain("hard_land")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + 4.5, 0.0)
	glider.velocity = Vector3(0.0, -11.0, 6.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	var min_clearance := INF
	var touched_ground := false
	var landed := false
	for i in 240:
		await physics_frame
		var clearance := glider.get_clearance()
		min_clearance = minf(min_clearance, clearance)
		if glider.is_ground_contact():
			touched_ground = true
		if glider.get("_state") == GliderPlayerScript.State.GROUNDED:
			landed = true
			break

	_fail_unless(landed, "Hard landing test should reach grounded state")
	_fail_unless(
		min_clearance < 0.25,
		"Hard landing should compress below hover rest (min %.2f)" % min_clearance
	)
	_fail_unless(touched_ground, "Hard landing should register ground contact")
	if GliderPlayerScript.FALL_DAMAGE_ENABLED:
		_fail_unless(
			glider.get_hull_integrity() < 1.0,
			"Hard landing should damage hull"
		)

	for i in HOVER_SETTLE_FRAMES:
		await physics_frame
	_fail_unless(
		absf(glider.get_clearance() - GliderPhysicsScript.BASE_HEIGHT) < 0.2,
		"After hard landing should recover to hover rest (clearance %.2f)" % glider.get_clearance()
	)
	glider.queue_free()
	terrain.queue_free()


func _verify_boost_no_clip_crest() -> void:
	var terrain := _spawn_terrain("boost_crest")
	await physics_frame

	var glider := _spawn_glider(terrain)
	var input := _get_input(glider)
	glider.global_position = Vector3(32.0, _hover_spawn_y(terrain, 32.0, 32.0), 32.0)
	glider.velocity = Vector3(0.0, 0.0, 11.0)
	await physics_frame

	_hold_boost()
	var min_clearance := INF
	for i in 120:
		await physics_frame
		min_clearance = minf(min_clearance, glider.get_raw_clearance())

	_fail_unless(
		min_clearance >= -0.04,
		"Boost crest should not clip sand (min clearance %.2f)" % min_clearance
	)
	_release_boost()
	glider.queue_free()
	terrain.queue_free()


func _verify_boost_climb_no_clip() -> void:
	var terrain := _spawn_terrain("boost_climb")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var world_x := 40.0
	var world_z := 40.0
	glider.global_position = Vector3(
		world_x,
		_hover_spawn_y(terrain, world_x, world_z),
		world_z
	)
	glider.velocity = Vector3(0.0, 0.0, 18.0)
	await physics_frame

	_hold_boost()
	var min_center := INF
	var min_board := INF
	for i in 240:
		await physics_frame
		if glider.is_grounded() or glider.get("_state") == GliderPlayerScript.State.LANDING:
			min_center = minf(min_center, glider.get_raw_clearance())
			min_board = minf(min_board, _min_board_clearance(glider))

	_fail_unless(
		min_center >= -0.04,
		"Boost uphill should not clip sand at center (min clearance %.2f)" % min_center
	)
	_fail_unless(
		min_board >= -0.04,
		"Boost uphill should not clip sand at board probes (min clearance %.2f)" % min_board
	)
	_fail_unless(glider.is_grounded(), "Boost uphill should stay grounded")
	_release_boost()
	glider.queue_free()
	terrain.queue_free()


func _verify_boost_steep_climb_no_clip() -> void:
	var terrain := _spawn_terrain("boost_steep_climb")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var world_x := 55.0
	var world_z := 55.0
	glider.global_position = Vector3(
		world_x,
		_hover_spawn_y(terrain, world_x, world_z),
		world_z
	)
	glider.velocity = Vector3(0.0, 0.0, 12.0)
	await physics_frame

	_hold_boost()
	var min_center := INF
	var min_board := INF
	for i in 240:
		await physics_frame
		if glider.is_grounded() or glider.get("_state") == GliderPlayerScript.State.LANDING:
			min_center = minf(min_center, glider.get_raw_clearance())
			min_board = minf(min_board, _min_board_clearance(glider))

	_fail_unless(
		min_center >= -0.04,
		"Steep boost uphill should not clip sand at center (min clearance %.2f)" % min_center
	)
	_fail_unless(
		min_board >= -0.04,
		"Steep boost uphill should not clip sand at board probes (min clearance %.2f)" % min_board
	)
	_fail_unless(glider.is_grounded(), "Steep boost uphill should stay grounded")
	_release_boost()
	glider.queue_free()
	terrain.queue_free()


func _verify_boost_hover_no_soften() -> void:
	var penetration := 0.08
	var cruise_ctx := _hover_ctx(GliderPhysicsScript.BASE_HEIGHT - penetration)
	cruise_ctx.clearance_change_rate = 4.0
	cruise_ctx.boost_active = false
	cruise_ctx.climbing = false

	var boost_ctx := _hover_ctx(GliderPhysicsScript.BASE_HEIGHT - penetration)
	boost_ctx.clearance_change_rate = 4.0
	boost_ctx.boost_active = true
	boost_ctx.climbing = false

	var cruise_scale := GliderPhysicsScript._hover_point_repulsion_scale(cruise_ctx, penetration)
	var boost_scale := GliderPhysicsScript._hover_point_repulsion_scale(boost_ctx, penetration)
	_fail_unless(
		boost_scale > cruise_scale * 1.2,
		"Boost should keep stronger corner repulsion on fast crest changes (%.2f vs %.2f)" % [
			boost_scale, cruise_scale
		]
	)
	_fail_unless(
		boost_scale >= 0.95,
		"Boost repulsion scale should stay near full strength (%.2f)" % boost_scale
	)


func _verify_jump_while_boosting() -> void:
	var terrain := _spawn_terrain("jump_boost")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	for i in 60:
		await physics_frame

	_fail_unless(glider.is_grounded(), "Jump-while-boost test needs grounded glider")
	_hold_boost()
	glider.velocity = Vector3(0.0, 0.0, 9.0)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	_release_boost()
	await physics_frame

	_fail_unless(glider.is_gliding(), "Should jump while boosting")
	_fail_unless(
		glider.velocity.y > 0.1,
		"Boost jump should add upward velocity (got %.2f)" % glider.velocity.y
	)
	glider.queue_free()
	terrain.queue_free()
	_release_all_input()
