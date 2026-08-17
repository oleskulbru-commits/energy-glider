extends SceneTree

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const TerrainProbesScript = preload("res://scripts/player/terrain_probes.gd")
const GliderInputScript = preload("res://scripts/input/glider_input.gd")
const TerrainManagerScript = preload("res://scripts/terrain/terrain_manager.gd")
const GliderScene = preload("res://scenes/player/glider.tscn")
const GliderCameraScript = preload("res://scripts/player/glider_camera.gd")
const DayNightCycleScript = preload("res://scripts/world/day_night_cycle.gd")
const SandMaterial = preload("res://assets/materials/sand.tres")

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
	_verify_boost_climb_target_speed()
	_verify_ground_boost_accel_rate()
	await _verify_hover_rest()
	await _verify_hover_settle_from_high()
	await _verify_terrain_probes_math()
	await _verify_predictive_surface_sampling()
	await _verify_hover_kernel()
	await _verify_corner_hover_forces()
	await _verify_ground_cruise()
	await _verify_climb_no_clip()
	await _verify_solar_battery_charge()
	await _verify_glide_gravity()
	await _verify_air_hold_w_keeps_horizontal_speed()
	await _verify_air_boost_increases_horizontal_speed()
	await _verify_brake_stop()
	await _verify_no_false_launch_cruise()
	await _verify_hover_no_clip_crest()
	await _verify_cruise_momentum_crest()
	await _verify_crest_air_gravity_ramp()
	await _verify_inertia_jump()
	await _verify_cruise_drift_align()
	await _verify_touchdown_slope_momentum()
	await _verify_touchdown_soft()
	_verify_land_speed_keep_kernel()
	await _verify_soft_land_keeps_speed()
	await _verify_uphill_land_speed_tax()
	await _verify_boost_no_clip_crest()
	await _verify_boost_climb_no_clip()
	await _verify_boost_steep_climb_no_clip()
	await _verify_boost_hover_no_soften()
	await _verify_jump_while_boosting()
	print("Glider controller verification passed.")
	quit(0)


func _verify_boost_climb_target_speed() -> void:
	var ctx := GliderPhysicsScript.Context.new()
	ctx.forward_held = true
	ctx.boost_active = false
	ctx.velocity = Vector3(0.0, 0.0, 2.0)
	ctx.board_forward = Vector3(0.0, 0.0, 1.0)
	ctx.downhill = Vector3(0.0, 0.0, -1.0)
	ctx.slope_grade = GliderPhysicsScript.UPHILL_GRADE_REF
	var cruise := GliderPhysicsScript.target_horizontal_speed(ctx)
	_fail_unless(
		is_equal_approx(cruise, GliderPhysicsScript.CLIMB_MIN_SPEED),
		"Steep cruise climb should sit on climb min floor (got %.2f)" % cruise
	)
	ctx.boost_active = true
	var boosted := GliderPhysicsScript.target_horizontal_speed(ctx)
	var boost_flat := GliderPhysicsScript.flat_max_speed(true)
	_fail_unless(
		is_equal_approx(boosted, boost_flat),
		"Boost on a steep climb should still target flat boost max (got %.2f, want %.2f)" % [
			boosted, boost_flat
		]
	)
	_fail_unless(
		boosted > cruise + 10.0,
		"Boost climb escape should far exceed crawl (cruise %.2f boost %.2f)" % [cruise, boosted]
	)


func _verify_ground_boost_accel_rate() -> void:
	## Far from boost max, ground force must apply full BOOST_ACCEL (m/s²), not speed-error.
	var ctx := GliderPhysicsScript.Context.new()
	ctx.ground_normal = Vector3.UP
	ctx.forward_held = true
	ctx.boost_active = true
	ctx.board_forward = Vector3(0.0, 0.0, 1.0)
	ctx.thrust_forward = Vector3(0.0, 0.0, 1.0)
	ctx.downhill = Vector3.ZERO
	ctx.slope_grade = 0.0
	var cruise := GliderPhysicsScript.flat_max_speed(false)
	ctx.velocity = Vector3(0.0, 0.0, cruise)
	var force := GliderPhysicsScript.compute_ground_force(ctx, 90.0, PHYSICS_DT)
	var accel := force.length() / 90.0
	_fail_unless(
		absf(accel - GliderPhysicsScript.BOOST_ACCEL) < 0.05,
		"Ground boost from cruise should apply BOOST_ACCEL (got %.2f, want %.2f)" % [
			accel, GliderPhysicsScript.BOOST_ACCEL
		]
	)


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


func _verify_hover_settle_from_high() -> void:
	## After crests, clearance can sit above rest; pull-down must settle without
	## inventing compression from lagged smoothed clearance.
	var terrain := _spawn_terrain("hover_high")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	var high_clearance := GliderPhysicsScript.BASE_HEIGHT + 0.35
	glider.global_position = Vector3(
		0.0,
		ground_y + high_clearance + 0.05,
		0.0
	)
	glider.velocity = Vector3.ZERO
	await physics_frame

	var start_clearance := glider.get_raw_clearance()
	_fail_unless(
		start_clearance > GliderPhysicsScript.BASE_HEIGHT + 0.2,
		"Settle-from-high needs elevated start (got %.2f)" % start_clearance
	)
	var peak := start_clearance
	var settled := false
	for i in HOVER_SETTLE_FRAMES:
		await physics_frame
		var clearance := glider.get_raw_clearance()
		peak = maxf(peak, clearance)
		if absf(clearance - GliderPhysicsScript.BASE_HEIGHT) <= HOVER_TOLERANCE:
			settled = true
			break

	_fail_unless(
		peak <= start_clearance + 0.08,
		"High hover should not push further up (peak %.2f from %.2f)" % [peak, start_clearance]
	)
	_fail_unless(
		settled,
		"High hover should settle near %.2f m (got %.2f)" % [
			GliderPhysicsScript.BASE_HEIGHT, glider.get_raw_clearance()
		]
	)
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
	var above_near := _hover_ctx(target + 0.06)
	var below := _hover_ctx(target - 0.08, -0.4)
	var force_above := GliderPhysicsScript.compute_hover_force(above, 90.0, PHYSICS_DT)
	var force_above_near := GliderPhysicsScript.compute_hover_force(above_near, 90.0, PHYSICS_DT)
	var force_below := GliderPhysicsScript.compute_hover_force(below, 90.0, PHYSICS_DT)
	_fail_unless(force_above.y <= 0.0, "Above target should not push up")
	_fail_unless(force_below.y > 0.0, "Below target should push up")
	_fail_unless(
		force_above.y < force_above_near.y,
		"Excess height should recover harder (%.1f vs %.1f)" % [force_above.y, force_above_near.y]
	)


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
		if glider.is_grounded():
			min_clearance = minf(min_clearance, glider.get_raw_clearance())

	_fail_unless(
		min_clearance >= -0.04,
		"Uphill thrust should not clip sand (min clearance %.2f)" % min_clearance
	)
	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _spawn_day_night(is_night: bool) -> DayNightCycle:
	var cycle: DayNightCycle = DayNightCycleScript.new()
	cycle.name = "VerifyDayNight"
	root.add_child(cycle)
	cycle.set_process(false)
	cycle.time_normalized = 0.75 if is_night else 0.1
	return cycle


func _verify_solar_battery_charge() -> void:
	_release_all_input()
	await _verify_day_fills_boost_before_battery()
	await _verify_night_does_not_solar_charge()
	await _verify_day_fills_battery_when_boost_full()
	await _verify_night_battery_trickles_into_boost()


func _verify_day_fills_boost_before_battery() -> void:
	var terrain := _spawn_terrain("day_boost_charge")
	await physics_frame
	var cycle := _spawn_day_night(false)
	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.set("_charge", 0.3)
	glider.set("_battery", 5.0)
	await physics_frame

	var start_charge := glider.get_charge_ratio()
	var start_battery := glider.get_battery_ratio()
	for i in 90:
		await physics_frame
	var end_charge := glider.get_charge_ratio()
	var end_battery := glider.get_battery_ratio()
	_fail_unless(
		end_charge > start_charge + 0.05,
		"Day should recharge boost without sail (%.2f -> %.2f)" % [start_charge, end_charge]
	)
	_fail_unless(
		is_equal_approx(end_battery, start_battery),
		"Day must not charge battery until boost is full (%.2f -> %.2f)" % [start_battery, end_battery]
	)

	glider.queue_free()
	cycle.queue_free()
	terrain.queue_free()
	await physics_frame


func _verify_night_does_not_solar_charge() -> void:
	var terrain := _spawn_terrain("night_no_solar")
	await physics_frame
	var cycle := _spawn_day_night(true)
	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.set("_charge", 0.3)
	glider.set("_battery", 0.0)
	await physics_frame

	var start_charge := glider.get_charge_ratio()
	var start_battery := glider.get_battery_ratio()
	for i in 90:
		await physics_frame
	_fail_unless(
		is_equal_approx(glider.get_charge_ratio(), start_charge),
		"Night must not solar-charge boost (%.2f -> %.2f)" % [start_charge, glider.get_charge_ratio()]
	)
	_fail_unless(
		is_equal_approx(glider.get_battery_ratio(), start_battery),
		"Night must not solar-charge battery (%.2f -> %.2f)" % [start_battery, glider.get_battery_ratio()]
	)

	glider.queue_free()
	cycle.queue_free()
	terrain.queue_free()
	await physics_frame


func _verify_day_fills_battery_when_boost_full() -> void:
	var terrain := _spawn_terrain("day_battery_charge")
	await physics_frame
	var cycle := _spawn_day_night(false)
	var glider := _spawn_glider(terrain)
	_get_input(glider)
	_fail_unless(
		is_equal_approx(glider.get_battery_ratio(), 0.0),
		"Battery should spawn empty (got %.3f)" % glider.get_battery_ratio()
	)
	_fail_unless(
		is_equal_approx(glider.get_charge_ratio(), 1.0),
		"Boost should spawn full so daytime surplus can fill the battery"
	)
	await physics_frame

	var start_battery := glider.get_battery_ratio()
	for i in 90:
		await physics_frame
	var end_battery := glider.get_battery_ratio()
	_fail_unless(
		is_equal_approx(glider.get_charge_ratio(), 1.0),
		"Boost should stay full while battery solar-charges"
	)
	_fail_unless(
		end_battery > start_battery + 0.004,
		"Day should charge battery when boost is full (%.3f -> %.3f)" % [start_battery, end_battery]
	)

	glider.queue_free()
	cycle.queue_free()
	terrain.queue_free()
	await physics_frame


func _verify_night_battery_trickles_into_boost() -> void:
	var terrain := _spawn_terrain("night_battery_trickle")
	await physics_frame
	var cycle := _spawn_day_night(true)
	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.set("_charge", 0.3)
	glider.set("_battery", 5.0)
	await physics_frame

	var start_charge := glider.get_charge_ratio()
	var start_battery := glider.get_battery_ratio()
	for i in 90:
		await physics_frame
	var end_charge := glider.get_charge_ratio()
	var end_battery := glider.get_battery_ratio()
	_fail_unless(
		end_charge > start_charge + 0.05,
		"Night should trickle battery into boost (%.2f -> %.2f)" % [start_charge, end_charge]
	)
	_fail_unless(
		end_battery < start_battery - 0.004,
		"Night trickle should drain battery (%.3f -> %.3f)" % [start_battery, end_battery]
	)

	glider.queue_free()
	cycle.queue_free()
	terrain.queue_free()
	await physics_frame


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


func _verify_air_hold_w_keeps_horizontal_speed() -> void:
	var terrain := _spawn_terrain("air_hold_w")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + 12.0, 0.0)
	glider.velocity = Vector3(0.0, 0.0, 24.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	_hold_forward()
	await physics_frame
	var start_speed := Vector2(glider.velocity.x, glider.velocity.z).length()
	for i in 45:
		await physics_frame
		_fail_unless(glider.is_gliding(), "Air hold-W test should stay airborne")
	var end_speed := Vector2(glider.velocity.x, glider.velocity.z).length()
	_fail_unless(
		end_speed >= start_speed - 0.2,
		"Holding W in air should keep horizontal speed (%.2f -> %.2f)" % [start_speed, end_speed]
	)
	## Knockback must not ratchet the air-hold lock upward.
	glider.queue_knockback(Vector3(0.0, 0.0, 40.0))
	await physics_frame
	await physics_frame
	var after_kb := Vector2(glider.velocity.x, glider.velocity.z).length()
	_fail_unless(
		after_kb <= start_speed + 0.5,
		"Air hold must not ratchet past locked speed after knockback (locked ~%.2f got %.2f)" % [
			start_speed, after_kb
		]
	)
	_fail_unless(
		after_kb <= GliderPhysicsScript.hard_speed_cap() + 0.01,
		"Air hold must respect hard_speed_cap"
	)
	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_air_boost_increases_horizontal_speed() -> void:
	var terrain := _spawn_terrain("air_boost")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + 14.0, 0.0)
	glider.velocity = Vector3(0.0, 0.0, 18.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	_hold_boost()
	await physics_frame
	var start_speed := Vector2(glider.velocity.x, glider.velocity.z).length()
	for i in 40:
		await physics_frame
		_fail_unless(glider.is_gliding(), "Air boost test should stay airborne")
	var end_speed := Vector2(glider.velocity.x, glider.velocity.z).length()
	_fail_unless(
		end_speed > start_speed + 2.0,
		"Air boost should increase horizontal speed (%.2f -> %.2f)" % [start_speed, end_speed]
	)
	_fail_unless(
		end_speed <= GliderPhysicsScript.hard_speed_cap() + 0.05,
		"Air boost must respect hard_speed_cap (got %.2f)" % end_speed
	)
	_release_boost()
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


func _verify_land_speed_keep_kernel() -> void:
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.land_speed_keep_from_grade(0.0), 1.0),
		"Flat grade should keep full speed"
	)
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.land_speed_keep_from_grade(0.2), 1.0),
		"Downhill grade should keep full speed"
	)
	_fail_unless(
		is_equal_approx(
			GliderPhysicsScript.land_speed_keep_from_grade(-GliderPhysicsScript.LAND_UPHILL_FREE),
			1.0
		),
		"Uphill free deadband should keep full speed"
	)
	_fail_unless(
		GliderPhysicsScript.land_speed_keep_from_grade(-GliderPhysicsScript.LAND_UPHILL_FULL)
		<= GliderPhysicsScript.LAND_STEEP_KEEP + 0.001,
		"Full uphill grade should reach steep keep"
	)
	var mid_g := -lerpf(
		GliderPhysicsScript.LAND_UPHILL_FREE,
		GliderPhysicsScript.LAND_UPHILL_FULL,
		0.5
	)
	var mid_keep := GliderPhysicsScript.land_speed_keep_from_grade(mid_g)
	_fail_unless(
		mid_keep < 1.0 and mid_keep > GliderPhysicsScript.LAND_STEEP_KEEP,
		"Mid uphill band should partially tax (got %.2f)" % mid_keep
	)

	## Flat + hard fall: no tax (airtime / approach alone does not punish).
	var flat_ctx := GliderPhysicsScript.Context.new()
	flat_ctx.ground_normal = Vector3.UP
	flat_ctx.slope_grade = 0.0
	flat_ctx.downhill = Vector3.ZERO
	flat_ctx.board_forward = Vector3(0.0, 0.0, 1.0)
	flat_ctx.velocity = Vector3(0.0, -16.0, 20.0)
	var flat := GliderPhysicsScript.apply_touchdown(flat_ctx)
	_fail_unless(
		absf(Vector2(flat.velocity.x, flat.velocity.z).length() - 20.0) < 0.05,
		"Flat hard fall should keep horizontal speed"
	)
	_fail_unless(absf(flat.velocity.y) < 0.01, "Touchdown should kill vertical")

	## Downhill face along travel: no tax.
	var down_n := Vector3(0.0, 0.9, -0.435).normalized()
	var down_ctx := GliderPhysicsScript.Context.new()
	down_ctx.ground_normal = down_n
	down_ctx.slope_grade = down_n.angle_to(Vector3.UP)
	down_ctx.downhill = Vector3(0.0, 0.0, 1.0)
	down_ctx.board_forward = Vector3(0.0, 0.0, 1.0)
	down_ctx.velocity = Vector3(0.0, -8.0, 20.0)
	var down := GliderPhysicsScript.apply_touchdown(down_ctx)
	_fail_unless(
		absf(Vector2(down.velocity.x, down.velocity.z).length() - 20.0) < 0.05,
		"Downhill land should keep horizontal speed"
	)

	## Into rising terrain: tax.
	var up_n := Vector3(0.0, 0.9, 0.435).normalized()
	var up_ctx := GliderPhysicsScript.Context.new()
	up_ctx.ground_normal = up_n
	up_ctx.slope_grade = up_n.angle_to(Vector3.UP)
	up_ctx.downhill = Vector3(0.0, 0.0, -1.0)
	up_ctx.board_forward = Vector3(0.0, 0.0, 1.0)
	up_ctx.velocity = Vector3(0.0, -8.0, 20.0)
	var up := GliderPhysicsScript.apply_touchdown(up_ctx)
	var up_h := Vector2(up.velocity.x, up.velocity.z).length()
	_fail_unless(
		up_h < 20.0 * 0.9,
		"Uphill land should tax horizontal speed (got %.2f)" % up_h
	)


func _verify_soft_land_keeps_speed() -> void:
	var terrain := _spawn_terrain("soft_land_keep")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + 2.2, 0.0)
	glider.velocity = Vector3(0.0, -3.0, 18.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	var pre_speed := 18.0
	var landed_speed := -1.0
	var min_clearance := INF
	for i in 240:
		await physics_frame
		min_clearance = minf(min_clearance, glider.get_raw_clearance())
		if glider.is_grounded():
			landed_speed = Vector2(glider.velocity.x, glider.velocity.z).length()
			break

	_fail_unless(landed_speed >= 0.0, "Soft land should reach grounded")
	_fail_unless(
		landed_speed >= pre_speed - 1.0,
		"Flat land should keep speed (%.2f -> %.2f)" % [pre_speed, landed_speed]
	)
	_fail_unless(
		min_clearance >= -0.02,
		"Soft land must not tunnel (min %.2f)" % min_clearance
	)
	glider.queue_free()
	terrain.queue_free()


func _verify_uphill_land_speed_tax() -> void:
	## Kernel-proven uphill tax; integration checks flat long-fall still free.
	var terrain := _spawn_terrain("flat_long_fall")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + 8.0, 0.0)
	glider.velocity = Vector3(0.0, -16.0, 20.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	var pre_speed := 20.0
	var landed_speed := -1.0
	var min_clearance := INF
	for i in 300:
		await physics_frame
		min_clearance = minf(min_clearance, glider.get_raw_clearance())
		if glider.is_grounded():
			landed_speed = Vector2(glider.velocity.x, glider.velocity.z).length()
			break

	_fail_unless(landed_speed >= 0.0, "Long flat fall should reach grounded")
	_fail_unless(
		landed_speed >= pre_speed - 1.5,
		"Long flat fall must not tax for airtime (%.2f -> %.2f)" % [pre_speed, landed_speed]
	)
	_fail_unless(
		min_clearance >= -0.02,
		"Long flat fall must not tunnel (min %.2f)" % min_clearance
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
		if glider.is_grounded():
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
		if glider.is_grounded():
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
