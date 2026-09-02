extends SceneTree

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const TerrainProbesScript = preload("res://scripts/player/terrain_probes.gd")
const GliderInputScript = preload("res://scripts/input/glider_input.gd")
const TerrainManagerScript = preload("res://scripts/terrain/terrain_manager.gd")
const GliderScene = preload("res://scenes/player/glider.tscn")
const GliderCameraScript = preload("res://scripts/player/glider_camera.gd")
const GliderAnimControllerScript = preload("res://scripts/player/glider_anim_controller.gd")
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
	Input.action_release("strafe_left")
	Input.action_release("strafe_right")


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


func _flattest_xz(terrain: TerrainManager) -> Vector2:
	var best := Vector2(32.0, 32.0)
	var best_grade := 99.0
	var x := 0.0
	while x <= 64.0:
		var z := 0.0
		while z <= 64.0:
			var n: Vector3 = terrain.sample_normal(x, z)
			var grade := n.angle_to(Vector3.UP)
			if grade < best_grade:
				best_grade = grade
				best = Vector2(x, z)
			z += 8.0
		x += 8.0
	return best


func _min_board_clearance(glider: GliderPlayer) -> float:
	return glider.call("_live_min_board_probe_clearance")


func _yaw_travel_misalign_deg(glider: GliderPlayer) -> float:
	var travel := Vector2(glider.velocity.x, glider.velocity.z)
	if travel.length_squared() < 1.0:
		return 0.0
	var yaw_dir := Vector2(sin(glider.get_yaw()), cos(glider.get_yaw()))
	return absf(wrapf(travel.angle() - yaw_dir.angle(), -PI, PI))


func _run_tests() -> void:
	_verify_boost_steering_harder()
	_verify_steering_upgrade_scale()
	_verify_chase_camera_math()
	_verify_landing_recovery()
	await _verify_fall_pitch_moves_camera()
	_verify_brake_boost_time_scale()
	_verify_handheld_camera()
	_verify_boost_climb_target_speed()
	_verify_ground_boost_accel_rate()
	_verify_glider_speed_caps()
	_verify_momentum_retention()
	_verify_glide_upgrade_gravity()
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
	await _verify_flat_jump_airtime()
	await _verify_jump_preserves_turn_yaw()
	await _verify_jump_preserves_forward_yaw()
	await _verify_jump_to_glide_anim()
	await _verify_jump_to_glide_repair()
	await _verify_landing_forward_anim()
	await _verify_landing_turn_anim()
	await _verify_idle_to_forward_enter()
	await _verify_respawn_animation()
	await _verify_cruise_drift_align()
	await _verify_turn_bank_roll()
	await _verify_strafe_adds_lateral_speed()
	await _verify_strafe_while_thrusting()
	await _verify_air_steering_weaker()
	await _verify_touchdown_slope_momentum()
	await _verify_touchdown_soft()
	_verify_land_speed_keep_kernel()
	await _verify_soft_land_keeps_speed()
	await _verify_uphill_land_speed_tax()
	await _verify_boost_no_clip_crest()
	await _verify_boost_climb_no_clip()
	await _verify_boost_steep_climb_no_clip()
	await _verify_jump_while_boosting()
	print("Glider controller verification passed.")
	quit(0)


func _verify_boost_steering_harder() -> void:
	_fail_unless(
		GliderPlayerScript.BOOST_TURN_RATE < GliderPlayerScript.SAIL_TURN_RATE,
		"Boost yaw should be slower than cruise (boost %.2f cruise %.2f)"
		% [GliderPlayerScript.BOOST_TURN_RATE, GliderPlayerScript.SAIL_TURN_RATE]
	)
	_fail_unless(
		GliderPlayerScript.BOOST_STEER_GRIP_RATE < GliderPlayerScript.SAIL_STEER_GRIP_RATE,
		"Boost grip should be weaker than cruise (boost %.2f cruise %.2f)"
		% [GliderPlayerScript.BOOST_STEER_GRIP_RATE, GliderPlayerScript.SAIL_STEER_GRIP_RATE]
	)
	_fail_unless(
		is_equal_approx(GliderPlayerScript.AIR_STEER_SCALE, 0.50),
		"Air steering should be 50%% of ground (got %.2f)" % GliderPlayerScript.AIR_STEER_SCALE
	)
	_verify_strafe_ground_force()


func _verify_steering_upgrade_scale() -> void:
	_fail_unless(
		is_equal_approx(GliderPlayerScript.steering_mul(0.0), 1.0),
		"No Steering bonus should keep base yaw and grip"
	)
	_fail_unless(
		is_equal_approx(GliderPlayerScript.steering_mul(0.12), 1.12),
		"Rare Steering should scale yaw and grip by 1.12"
	)
	_fail_unless(
		is_equal_approx(GliderPlayerScript.steering_mul(0.80), 1.40),
		"Steering should cap at +40%"
	)
	_fail_unless(
		is_equal_approx(
			GliderPlayerScript.SAIL_TURN_RATE * GliderPlayerScript.steering_mul(0.20) * GliderPlayerScript.AIR_STEER_SCALE,
			GliderPlayerScript.SAIL_TURN_RATE * 1.20 * 0.50
		),
		"Air yaw should stay 50% of upgraded ground yaw"
	)
	_fail_unless(
		is_equal_approx(
			GliderPlayerScript.SAIL_STEER_GRIP_RATE * GliderPlayerScript.steering_mul(0.20) * GliderPlayerScript.AIR_STEER_SCALE,
			GliderPlayerScript.SAIL_STEER_GRIP_RATE * 1.20 * 0.50
		),
		"Air grip should stay 50% of upgraded ground grip"
	)


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


func _verify_glider_speed_caps() -> void:
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.flat_max_speed(false), GliderPhysicsScript.FLAT_MAX_SPEED),
		"Base cruise should stay ~26.6 m/s"
	)
	_fail_unless(
		is_equal_approx(
			GliderPhysicsScript.flat_max_speed(true),
			GliderPhysicsScript.FLAT_MAX_SPEED * GliderPhysicsScript.BOOST_SPEED_FACTOR
		),
		"Base boost should stay cruise × 1.3"
	)
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.cruise_speed_for(0.20), GliderPhysicsScript.FLAT_MAX_SPEED * 1.20),
		"8% + 12% should raise cruise to 26.6 × 1.20"
	)
	_fail_unless(
		is_equal_approx(
			GliderPhysicsScript.flat_max_speed(true, 0.20),
			GliderPhysicsScript.FLAT_MAX_SPEED * 1.20 * GliderPhysicsScript.BOOST_SPEED_FACTOR
		),
		"8% + 12% boost should be cruise × 1.3"
	)
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.cruise_speed_for(3.0), GliderPhysicsScript.CRUISE_ABSOLUTE_MAX),
		"Huge Glider Speed bonus should cap cruise at ~76.9 m/s"
	)
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.flat_max_speed(true, 3.0), GliderPhysicsScript.BOOST_ABSOLUTE_MAX),
		"Huge Glider Speed bonus should cap boost at 100 m/s"
	)
	var ctx := GliderPhysicsScript.Context.new()
	ctx.forward_held = true
	ctx.boost_active = false
	ctx.speed_bonus = 0.20
	ctx.velocity = Vector3(0.0, 0.0, 2.0)
	ctx.board_forward = Vector3(0.0, 0.0, 1.0)
	ctx.downhill = Vector3(0.0, 0.0, -1.0)
	ctx.slope_grade = GliderPhysicsScript.UPHILL_GRADE_REF
	var climb := GliderPhysicsScript.target_horizontal_speed(ctx)
	_fail_unless(
		is_equal_approx(climb, GliderPhysicsScript.CLIMB_MIN_SPEED),
		"Upgraded cruise should still floor a full climb at climb min (got %.2f)" % climb
	)


func _verify_momentum_retention() -> void:
	var ctx := GliderPhysicsScript.Context.new()
	ctx.forward_held = true
	ctx.boost_active = false
	ctx.velocity = Vector3(0.0, 0.0, 2.0)
	ctx.board_forward = Vector3(0.0, 0.0, 1.0)
	ctx.downhill = Vector3(0.0, 0.0, -1.0)
	ctx.slope_grade = GliderPhysicsScript.UPHILL_GRADE_REF
	ctx.momentum_retention = 0.25
	var kept := GliderPhysicsScript.target_horizontal_speed(ctx)
	var want_kept := maxf(
		GliderPhysicsScript.FLAT_MAX_SPEED * 0.25,
		GliderPhysicsScript.CLIMB_MIN_SPEED
	)
	_fail_unless(
		is_equal_approx(kept, want_kept),
		"Legendary Momentum Retention should keep 25%% of cruise on a full climb (got %.2f, want %.2f)" % [
			kept, want_kept
		]
	)
	ctx.momentum_retention = 1.0
	var full := GliderPhysicsScript.target_horizontal_speed(ctx)
	_fail_unless(
		is_equal_approx(full, GliderPhysicsScript.FLAT_MAX_SPEED),
		"100%% Momentum Retention should keep full cruise uphill (got %.2f)" % full
	)
	ctx.speed_bonus = 0.20
	var upgraded := GliderPhysicsScript.target_horizontal_speed(ctx)
	_fail_unless(
		is_equal_approx(upgraded, GliderPhysicsScript.cruise_speed_for(0.20)),
		"100%% retention should keep upgraded cruise uphill (got %.2f)" % upgraded
	)
	ctx.boost_active = true
	var boosted := GliderPhysicsScript.target_horizontal_speed(ctx)
	_fail_unless(
		is_equal_approx(boosted, GliderPhysicsScript.flat_max_speed(true, 0.20)),
		"Boost on a climb should still target flat boost max (got %.2f)" % boosted
	)
	ctx.boost_active = false
	ctx.speed_bonus = 0.0
	ctx.momentum_retention = 0.0
	ctx.slope_grade = 0.0
	ctx.downhill = Vector3.ZERO
	var flat := GliderPhysicsScript.target_horizontal_speed(ctx)
	_fail_unless(
		is_equal_approx(flat, GliderPhysicsScript.FLAT_MAX_SPEED),
		"Momentum Retention should not change flat cruise"
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

	var fall_pitch := GliderCameraScript.compute_fall_pitch(12.0, 28.0, 12.0)
	_fail_unless(fall_pitch > 0.0, "Fall pitch should raise the boom to look down while descending (got %.3f)" % fall_pitch)
	_fail_unless(
		absf(GliderCameraScript.compute_fall_pitch(0.0, 28.0, 12.0)) < 0.001,
		"No descent should yield zero fall pitch"
	)

	var rest_pitch := deg_to_rad(12.0)
	var max_look := deg_to_rad(35.0)
	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_boom_pitch(rest_pitch, fall_pitch, rest_pitch, max_look),
			rest_pitch + fall_pitch
		),
		"Rest look should apply full fall pitch to the boom"
	)
	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_fall_pitch_weight(rest_pitch + max_look, rest_pitch, max_look),
			0.0
		),
		"Full mouse pitch should zero fall-pitch weight"
	)
	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_boom_pitch(rest_pitch + max_look, fall_pitch, rest_pitch, max_look),
			rest_pitch + max_look
		),
		"Full mouse pitch should overrule fall dip"
	)
	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_boom_pitch(
				rest_pitch + max_look * 0.5,
				fall_pitch,
				rest_pitch,
				max_look
			),
			rest_pitch + max_look * 0.5 + fall_pitch * 0.5
		),
		"Partial mouse pitch should blend fall dip"
	)

	_fail_unless(
		is_equal_approx(GliderCameraScript.compute_effective_look_ahead(14.0, 0.0, 180.0), 14.0),
		"Zero orbit offset should keep full look-ahead"
	)
	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_effective_look_ahead(14.0, deg_to_rad(180.0), 180.0),
			0.0
		),
		"Full orbit should zero look-ahead"
	)
	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_effective_look_ahead(14.0, deg_to_rad(90.0), 180.0),
			7.0
		),
		"Mid orbit should halve look-ahead"
	)


func _verify_landing_recovery() -> void:
	var min_sec := 0.35
	var max_sec := 0.85
	_fail_unless(
		is_equal_approx(GliderCameraScript.compute_land_recover_duration(0.0, min_sec, max_sec), min_sec),
		"Min strength should use min recovery duration"
	)
	_fail_unless(
		is_equal_approx(GliderCameraScript.compute_land_recover_duration(1.0, min_sec, max_sec), max_sec),
		"Max strength should use max recovery duration"
	)

	var blend := 1.0
	var duration := GliderCameraScript.compute_land_recover_duration(1.0, min_sec, max_sec)
	var elapsed := 0.0
	while blend > 0.0 and elapsed < duration + PHYSICS_DT * 2.0:
		blend = GliderCameraScript.step_land_recover_blend(blend, PHYSICS_DT, duration)
		elapsed += PHYSICS_DT
	_fail_unless(blend < 0.01, "Blend should decay to ~0 after recovery duration (got %.3f)" % blend)

	var start_pitch := deg_to_rad(-28.0)
	var build_pitch := 0.0
	var recover_pitch := start_pitch
	var build_step_total := 0.0
	var recover_step_total := 0.0
	var target_build := GliderCameraScript.compute_fall_pitch(12.0, 28.0, 12.0)
	var fall_rate := 5.0
	var recover_rate := 2.0
	for i in 30:
		var prev := build_pitch
		build_pitch = lerpf(build_pitch, target_build, clampf(fall_rate * PHYSICS_DT, 0.0, 1.0))
		build_step_total += absf(build_pitch - prev)

		prev = recover_pitch
		recover_pitch = lerpf(recover_pitch, 0.0, clampf(recover_rate * PHYSICS_DT, 0.0, 1.0))
		recover_step_total += absf(recover_pitch - prev)
	_fail_unless(
		recover_step_total < build_step_total,
		"Recovery should unwind slower than building (recover %.4f build %.4f)" % [
			recover_step_total, build_step_total
		]
	)


func _verify_fall_pitch_moves_camera() -> void:
	var cam := GliderCameraScript.new()
	cam.speed_shake_enabled = false
	root.add_child(cam)
	var target := Node3D.new()
	root.add_child(target)
	target.global_position = Vector3(0.0, 10.0, 0.0)
	await process_frame

	cam.reset_follow_state()
	cam.request_hard_snap()
	cam.follow(target, 0.0, Vector3.ZERO, PHYSICS_DT, true, null)
	var rest_y := cam.global_position.y
	for i in 30:
		cam.follow(target, 0.0, Vector3(0.0, -12.0, 6.0), PHYSICS_DT, false, null)
	_fail_unless(
		cam.global_position.y > rest_y + 0.2,
		"Fall pitch should raise the camera to look down (rest %.2f now %.2f)" % [rest_y, cam.global_position.y]
	)

	cam.reset_follow_state()
	cam.request_hard_snap()
	cam.follow(target, 0.0, Vector3.ZERO, PHYSICS_DT, true, null)
	cam.apply_look_input(0.0, 20000.0)
	cam.request_hard_snap()
	cam.follow(target, 0.0, Vector3.ZERO, PHYSICS_DT, true, null)
	var look_y := cam.global_position.y
	for i in 30:
		cam.follow(target, 0.0, Vector3(0.0, -12.0, 6.0), PHYSICS_DT, false, null)
	_fail_unless(
		absf(cam.global_position.y - look_y) < 0.01,
		"Mouse look pitch should overrule fall dip (look %.2f now %.2f)" % [look_y, cam.global_position.y]
	)

	cam.queue_free()
	target.queue_free()


func _verify_brake_boost_time_scale() -> void:
	var boost_scale := 1.35
	var brake_loop_scale := 0.25
	_fail_unless(
		is_equal_approx(
			GliderAnimControllerScript.compute_brake_loop_time_scale(
				boost_scale, brake_loop_scale, true
			),
			boost_scale * brake_loop_scale
		),
		"Brake loop should run at 25%% of boost time scale (75%% less shake)"
	)
	_fail_unless(
		is_equal_approx(
			GliderAnimControllerScript.compute_brake_loop_time_scale(
				boost_scale, brake_loop_scale, false
			),
			1.0
		),
		"Brake loop time scale should reset outside brake root state"
	)
	_fail_unless(
		is_equal_approx(
			GliderAnimControllerScript.compute_boost_loop_time_scale(
				boost_scale, brake_loop_scale, true, true, true
			),
			boost_scale
		),
		"Shift boost should keep full boost time scale even if brake is held"
	)
	_fail_unless(
		is_equal_approx(
			GliderAnimControllerScript.compute_boost_loop_time_scale(
				boost_scale, brake_loop_scale, false, false, true
			),
			1.0
		),
		"Boost loop time scale should reset outside boost root state"
	)


func _verify_handheld_camera() -> void:
	var cruise_max := GliderPhysicsScript.cruise_speed_for(0.0)
	var strength_at_max := 1.0

	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_speed_shake_ratio(0.0, cruise_max),
			0.0
		),
		"Stationary speed shake ratio should be zero"
	)
	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_speed_shake_ratio(cruise_max * 0.5, cruise_max),
			0.5
		),
		"Half cruise speed should yield half shake ratio"
	)
	_fail_unless(
		is_equal_approx(
			GliderCameraScript.compute_speed_shake_intensity(cruise_max, cruise_max, strength_at_max),
			strength_at_max
		),
		"Full cruise speed should yield full shake intensity"
	)
	var over_max_speed := cruise_max * 1.3
	var over_max_intensity := GliderCameraScript.compute_speed_shake_intensity(
		over_max_speed, cruise_max, strength_at_max
	)
	_fail_unless(
		is_equal_approx(over_max_intensity, strength_at_max * 1.3),
		"Speed above cruise max should scale shake proportionally (got %.3f)" % over_max_intensity
	)
	_fail_unless(
		over_max_intensity > strength_at_max,
		"Boost/over-max speed shake should exceed cruise-max shake"
	)

	var rot_noise := FastNoiseLite.new()
	rot_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rot_noise.seed = 9031
	rot_noise.frequency = 0.85

	var rot_amp := deg_to_rad(0.4)
	var intensity := 1.0
	for i in 120:
		var sample_rot := GliderCameraScript.sample_handheld_rotation(
			float(i) * 0.05,
			rot_noise,
			rot_amp,
			intensity
		)
		var rot_limit := rot_amp * intensity + 0.0001
		_fail_unless(
			absf(sample_rot.x) <= rot_limit and absf(sample_rot.y) <= rot_limit and absf(sample_rot.z) <= rot_limit,
			"Handheld rotation offset should stay within amplitude bounds"
		)


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

	_release_forward()
	Input.action_press("brake")
	var saw_brake := false
	var brake_sub := &""
	for i in 30:
		await physics_frame
		var tree: AnimationTree = glider.get_node("Visual/GliderSkin/AnimationTree") as AnimationTree
		var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
		if root_playback.get_current_node() == &"brake":
			saw_brake = true
			var brake_playback := tree.get("parameters/body/brake/playback") as AnimationNodeStateMachinePlayback
			brake_sub = brake_playback.get_current_node()
			if brake_sub == &"loop":
				break
	_fail_unless(saw_brake, "Brake while moving should enter brake animation")
	_fail_unless(brake_sub == &"loop", "Brake should snap to loop, not enter (state=%s)" % brake_sub)

	for i in 180:
		await physics_frame
		if Vector2(glider.velocity.x, glider.velocity.z).length() < 0.25:
			break

	for i in 24:
		await physics_frame

	var tree: AnimationTree = glider.get_node("Visual/GliderSkin/AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	_fail_unless(
		root_playback.get_current_node() == &"grounded",
		"Brake held at rest should idle (state=%s)" % root_playback.get_current_node()
	)

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


func _verify_glide_upgrade_gravity() -> void:
	var ctx := GliderPhysicsScript.Context.new()
	ctx.air_gravity_scale = 1.0
	var base := GliderPhysicsScript.air_gravity_force(ctx, 90.0)
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.air_gravity_mul(0.0), 1.0),
		"Zero Glide should keep full air gravity"
	)
	ctx.glide_bonus = 0.15
	var reduced := GliderPhysicsScript.air_gravity_force(ctx, 90.0)
	_fail_unless(
		is_equal_approx(reduced.y, base.y * 0.85),
		"15%% Glide should cut air gravity to 85%% (got %.1f want %.1f)" % [reduced.y, base.y * 0.85]
	)
	ctx.glide_bonus = 0.80
	var capped := GliderPhysicsScript.air_gravity_force(ctx, 90.0)
	_fail_unless(
		is_equal_approx(capped.y, base.y * 0.50),
		"Over-cap Glide should still leave 50%% air gravity (got %.1f want %.1f)" % [
			capped.y, base.y * 0.50
		]
	)
	ctx.velocity = Vector3(0.0, 0.0, 40.0)
	ctx.glide_bonus = 0.50
	var force := GliderPhysicsScript.compute_air_force(ctx, 90.0, 0.016)
	_fail_unless(force.y < -1.0, "Capped Glide should still fall (got %.1f)" % force.y)


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
	var flat := GliderPhysicsScript.apply_inertia_jump(
		Vector3.ZERO, Vector3.UP, 0.0, GliderPhysicsScript.BASE_HEIGHT
	)
	var min_up := GliderPhysicsScript.jump_up_speed_for_clearance(GliderPhysicsScript.BASE_HEIGHT)
	_fail_unless(
		flat.y >= min_up - 0.01,
		"Flat jump should meet clearance floor (got %.2f min %.2f)" % [flat.y, min_up]
	)

	var slow := GliderPhysicsScript.apply_inertia_jump(
		Vector3(0.0, 0.0, 4.0), Vector3.UP, 4.0, GliderPhysicsScript.JUMP_MAX_CLEARANCE
	)
	var fast := GliderPhysicsScript.apply_inertia_jump(
		Vector3(0.0, 0.0, 14.0), Vector3.UP, 14.0, GliderPhysicsScript.JUMP_MAX_CLEARANCE
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


func _verify_flat_jump_airtime() -> void:
	var terrain := _spawn_terrain("flat_jump")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	for i in 60:
		await physics_frame

	var skin: Node3D = glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	var anim_player := tree.get_node(tree.anim_player) as AnimationPlayer
	var jump_time_scale: float = tree.get("parameters/body/jump/time_scale/scale")
	var jump_duration := 0.0
	if anim_player != null and anim_player.has_animation("Eve_Jump") and jump_time_scale > 0.0:
		jump_duration = anim_player.get_animation("Eve_Jump").length / jump_time_scale
	var min_jump_frames := int(ceil(jump_duration * 0.85 / (1.0 / 60.0))) if jump_duration > 0.0 else 30

	_fail_unless(glider.is_grounded(), "Flat jump airtime test needs grounded start")

	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame

	_fail_unless(glider.is_gliding(), "Flat jump should enter gliding state")

	var gliding_frames := 0
	var jump_frames := 0
	var saw_landing_before_jump_done := false
	for i in 90:
		await physics_frame
		if glider.is_gliding():
			gliding_frames += 1
		var root_node := root_playback.get_current_node()
		if root_node == &"jump":
			jump_frames += 1
		elif root_node == &"landing" and jump_frames < min_jump_frames:
			saw_landing_before_jump_done = true
			break

	_fail_unless(
		gliding_frames >= 15,
		"Flat jump should stay gliding for at least 15 frames (got %d)" % gliding_frames
	)
	_fail_unless(
		not saw_landing_before_jump_done,
		"Flat jump should not enter landing before jump clip mostly finishes (jump_frames=%d min=%d)"
		% [jump_frames, min_jump_frames]
	)
	_fail_unless(
		jump_frames >= mini(min_jump_frames, 15),
		"Flat jump should play jump anim (frames=%d min=%d)"
		% [jump_frames, mini(min_jump_frames, 15)]
	)

	glider.queue_free()
	terrain.queue_free()
	_release_all_input()


func _verify_jump_preserves_turn_yaw() -> void:
	var terrain := _spawn_terrain("jump_turn_yaw")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3(0.0, 0.0, 10.0)
	glider.set("_yaw", deg_to_rad(18.0))
	await physics_frame

	Input.action_press("steer_right")
	_fail_unless(
		absf(glider.get_steer_axis()) > 0.01,
		"Turn jump test needs active steer input"
	)

	var misalign_before := _yaw_travel_misalign_deg(glider)
	var yaw_before := glider.get_yaw()
	_fail_unless(
		misalign_before >= deg_to_rad(8.0),
		"Turn jump test needs yaw/velocity misalign (got %.1f deg)" % rad_to_deg(misalign_before)
	)

	# Mirror _try_jump yaw policy: preserve heading while steering or holding W/boost.
	if not glider.call("_should_preserve_yaw_on_jump"):
		glider.call("_align_yaw_to_travel_direction", 1.0)

	var misalign_after := _yaw_travel_misalign_deg(glider)
	var yaw_after := glider.get_yaw()
	Input.action_release("steer_right")
	_release_all_input()

	_fail_unless(
		misalign_after >= misalign_before * 0.99,
		"Jump while turning should preserve yaw/velocity misalign (%.1f -> %.1f deg)"
		% [rad_to_deg(misalign_before), rad_to_deg(misalign_after)]
	)
	var yaw_delta := absf(wrapf(yaw_after - yaw_before, -PI, PI))
	_fail_unless(
		yaw_delta < deg_to_rad(1.0),
		"Jump while turning should not snap yaw to travel (delta %.1f deg)" % rad_to_deg(yaw_delta)
	)

	glider.queue_free()
	terrain.queue_free()


func _verify_jump_preserves_forward_yaw() -> void:
	var terrain := _spawn_terrain("jump_forward_yaw")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3(0.0, 0.0, 10.0)
	glider.set("_yaw", deg_to_rad(18.0))
	await physics_frame

	_hold_forward()
	_fail_unless(glider.is_forward_held(), "Forward jump test needs W held")

	var misalign_before := _yaw_travel_misalign_deg(glider)
	var yaw_before := glider.get_yaw()
	_fail_unless(
		misalign_before >= deg_to_rad(8.0),
		"Forward jump test needs yaw/velocity misalign (got %.1f deg)" % rad_to_deg(misalign_before)
	)

	if not glider.call("_should_preserve_yaw_on_jump"):
		glider.call("_align_yaw_to_travel_direction", 1.0)

	var misalign_after := _yaw_travel_misalign_deg(glider)
	var yaw_after := glider.get_yaw()
	_release_forward()

	_fail_unless(
		misalign_after >= misalign_before * 0.99,
		"Jump while holding W should preserve yaw/velocity misalign (%.1f -> %.1f deg)"
		% [rad_to_deg(misalign_before), rad_to_deg(misalign_after)]
	)
	var yaw_delta := absf(wrapf(yaw_after - yaw_before, -PI, PI))
	_fail_unless(
		yaw_delta < deg_to_rad(1.0),
		"Jump while holding W should not snap yaw to travel (delta %.1f deg)" % rad_to_deg(yaw_delta)
	)

	glider.queue_free()
	terrain.queue_free()


func _verify_jump_to_glide_anim() -> void:
	var terrain := _spawn_terrain("jump_glide")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	for i in 60:
		await physics_frame

	var skin: Node3D = glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	var anim_player := tree.get_node(tree.anim_player) as AnimationPlayer

	_fail_unless(glider.is_grounded(), "Jump-to-glide test needs grounded start")

	glider.velocity = Vector3(0.0, 0.0, 14.0)
	_hold_forward()
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame

	_fail_unless(glider.is_gliding(), "Jump-to-glide test needs gliding after jump")

	var jump_time_scale: float = tree.get("parameters/body/jump/time_scale/scale")
	var jump_duration := 0.0
	if anim_player != null and anim_player.has_animation("Eve_Jump") and jump_time_scale > 0.0:
		jump_duration = anim_player.get_animation("Eve_Jump").length / jump_time_scale
	var min_jump_frames := int(ceil(jump_duration * 0.9 / (1.0 / 60.0))) if jump_duration > 0.0 else 30
	var max_wait_frames := int(ceil((jump_duration + 0.25) / (1.0 / 60.0))) + 30

	var saw_jump := false
	var saw_glide := false
	var frames_in_jump := 0
	for i in maxi(max_wait_frames, 180):
		await physics_frame
		if not glider.is_gliding():
			continue
		var root_node := root_playback.get_current_node()
		if root_node == &"jump":
			saw_jump = true
			frames_in_jump += 1
		elif root_node == &"glide":
			var min_before_glide := maxi(1, int(min_jump_frames * 0.85))
			_fail_unless(
				saw_jump and frames_in_jump >= min_before_glide,
				"Jump-to-glide should finish jump before glide (frames_in_jump=%d min=%d)"
				% [frames_in_jump, min_before_glide]
			)
			saw_glide = true
			break

	_fail_unless(saw_jump, "Jump-to-glide should play jump on takeoff (root=%s)" % root_playback.get_current_node())
	_fail_unless(
		saw_glide or frames_in_jump >= min_jump_frames,
		"Jump-to-glide should finish most of jump before glide (frames_in_jump=%d min=%d)"
		% [frames_in_jump, min_jump_frames]
	)
	_fail_unless(saw_glide, "Jump-to-glide should transition to glide while airborne (root=%s)" % root_playback.get_current_node())

	_release_forward()
	glider.queue_free()
	terrain.queue_free()
	_release_all_input()


func _verify_jump_to_glide_repair() -> void:
	var terrain := _spawn_terrain("jump_glide_repair")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	for i in 60:
		await physics_frame

	var skin: Node3D = glider.get_node("Visual/GliderSkin")
	var anim_controller: GliderAnimControllerScript = skin.get_node("GliderAnimController") as GliderAnimControllerScript
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	var anim_player := tree.get_node(tree.anim_player) as AnimationPlayer

	_fail_unless(glider.is_grounded(), "Jump-to-glide repair test needs grounded start")

	glider.velocity = Vector3(0.0, 0.0, 14.0)
	_hold_forward()
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame

	_fail_unless(glider.is_gliding(), "Jump-to-glide repair test needs gliding after jump")

	var ground_y := terrain.sample_height(glider.global_position.x, glider.global_position.z)
	glider.global_position.y = ground_y + 12.0
	glider.velocity = Vector3(0.0, -0.5, 14.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await physics_frame

	var on_jump := false
	for i in 120:
		await physics_frame
		if not glider.is_gliding():
			continue
		if root_playback.get_current_node() == &"jump":
			on_jump = true
			break

	_fail_unless(
		on_jump,
		"Jump-to-glide repair test needs jump playing while gliding (root=%s)"
		% root_playback.get_current_node()
	)

	var jump_time_scale: float = tree.get("parameters/body/jump/time_scale/scale")
	var jump_duration := 0.0
	if anim_player != null and anim_player.has_animation("Eve_Jump") and jump_time_scale > 0.0:
		jump_duration = anim_player.get_animation("Eve_Jump").length / jump_time_scale
	_fail_unless(jump_duration > 0.0, "Jump-to-glide repair test needs Eve_Jump duration")

	# Simulate missed handoff: controller considers jump finished and wants glide,
	# but playback is still on jump with no active root blend.
	_fail_unless(
		root_playback.get_current_node() == &"jump",
		"Jump-to-glide repair desync setup needs playback on jump (root=%s)"
		% root_playback.get_current_node()
	)
	anim_controller.set("_jump_elapsed", jump_duration)
	anim_controller.set("_root_state", &"glide")
	anim_controller.set("_root_blend_time", 0.0)
	anim_controller.set("_root_blend_target", &"")

	await physics_frame

	_fail_unless(
		anim_controller.get("_root_state") == &"glide",
		"Jump-to-glide repair should keep root_state glide (got %s)"
		% anim_controller.get("_root_state")
	)
	_fail_unless(
		float(anim_controller.get("_jump_elapsed")) > 0.0,
		"Jump-to-glide repair should not restart jump via glide→jump state change"
	)

	var recovered := root_playback.get_current_node() == &"glide"
	for i in 89:
		if recovered:
			break
		await physics_frame
		if not glider.is_gliding():
			continue
		if root_playback.get_current_node() == &"glide":
			recovered = true
			break

	_fail_unless(
		recovered,
		"Jump-to-glide repair should recover to glide after desync (root=%s)"
		% root_playback.get_current_node()
	)

	_release_forward()
	glider.queue_free()
	terrain.queue_free()
	_release_all_input()


func _verify_landing_forward_anim() -> void:
	var terrain := _spawn_terrain("land_forward_anim")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	for i in 60:
		await physics_frame

	var skin: Node3D = glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	var locomotion_playback := tree.get("parameters/body/locomotion/playback") as AnimationNodeStateMachinePlayback
	var hero_skel: Skeleton3D = skin.get_node("Model/GliderRoot/Hero_Rig/Skeleton3D") as Skeleton3D
	var spine_idx := maxi(0, hero_skel.find_bone("spine"))

	_fail_unless(glider.is_grounded(), "Landing forward anim test needs grounded start")
	_hold_forward()
	glider.velocity = Vector3(0.0, 0.0, 8.0)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame

	_fail_unless(glider.is_gliding(), "Landing forward anim test needs jump into glide")

	var was_airborne := false
	var resumed_forward := false
	var saw_warmed_locomotion := false
	var prev_spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
	var saw_landing_blend := false
	for i in 240:
		await physics_frame
		var spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
		if glider.is_gliding() or not glider.is_grounded():
			was_airborne = true
		var root_node := root_playback.get_current_node()
		var loco_node := locomotion_playback.get_current_node()
		if was_airborne and root_node in [&"landing", &"locomotion"]:
			if loco_node != &"Start" and loco_node != StringName():
				saw_warmed_locomotion = true
			elif root_node == &"locomotion":
				_fail_unless(
					false,
					"Landing to forward should warm locomotion during crossfade (loco=%s root=%s)"
					% [loco_node, root_node]
				)
			if absf(prev_spine_rot.dot(spine_rot)) < 0.995:
				_fail_unless(
					saw_landing_blend,
					"Landing to forward should not snap spine (root=%s loco=%s dot=%.3f)"
					% [root_node, locomotion_playback.get_current_node(), absf(prev_spine_rot.dot(spine_rot))]
				)
			saw_landing_blend = true
		prev_spine_rot = spine_rot
		if was_airborne and glider.is_grounded() and not glider.is_gliding():
			if root_node == &"locomotion" and locomotion_playback.get_current_node() == &"forward":
				resumed_forward = true
				break

	_fail_unless(was_airborne, "Landing forward anim test never left the ground")
	_fail_unless(
		resumed_forward,
		"Locomotion should resume forward after landing with W (root=%s, loco=%s)"
		% [root_playback.get_current_node(), locomotion_playback.get_current_node()]
	)
	_fail_unless(
		saw_warmed_locomotion,
		"Landing to forward should warm locomotion before/during crossfade (loco=%s)"
		% locomotion_playback.get_current_node()
	)

	var spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
	_fail_unless(
		not spine_rot.is_equal_approx(Quaternion.IDENTITY),
		"Hero skeleton T-pose after landing with W held"
	)

	glider.queue_free()
	terrain.queue_free()
	_release_all_input()


func _verify_landing_turn_anim() -> void:
	var terrain := _spawn_terrain("land_turn_anim")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	for i in 60:
		await physics_frame

	var skin: Node3D = glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	var locomotion_playback := tree.get("parameters/body/locomotion/playback") as AnimationNodeStateMachinePlayback
	var hero_skel: Skeleton3D = skin.get_node("Model/GliderRoot/Hero_Rig/Skeleton3D") as Skeleton3D
	var spine_idx := maxi(0, hero_skel.find_bone("spine"))

	_fail_unless(glider.is_grounded(), "Landing turn anim test needs grounded start")
	_hold_forward()
	Input.action_press("steer_left")
	glider.velocity = Vector3(0.0, 0.0, 8.0)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame

	_fail_unless(glider.is_gliding(), "Landing turn anim test needs jump into glide")

	var was_airborne := false
	var resumed_turn := false
	var saw_warmed_locomotion := false
	var prev_spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
	var saw_landing_blend := false
	for i in 240:
		await physics_frame
		var spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
		if glider.is_gliding() or not glider.is_grounded():
			was_airborne = true
		var root_node := root_playback.get_current_node()
		var loco_node := locomotion_playback.get_current_node()
		if was_airborne and root_node in [&"landing", &"locomotion"]:
			if loco_node != &"Start" and loco_node != StringName():
				saw_warmed_locomotion = true
			elif root_node == &"locomotion":
				_fail_unless(
					false,
					"Landing to turn_left should warm locomotion during crossfade (loco=%s root=%s)"
					% [loco_node, root_node]
				)
			if absf(prev_spine_rot.dot(spine_rot)) < 0.995:
				_fail_unless(
					saw_landing_blend,
					"Landing to turn_left should not snap spine (root=%s loco=%s dot=%.3f)"
					% [root_node, locomotion_playback.get_current_node(), absf(prev_spine_rot.dot(spine_rot))]
				)
			saw_landing_blend = true
		prev_spine_rot = spine_rot
		if was_airborne and glider.is_grounded() and not glider.is_gliding():
			if root_node == &"locomotion" and locomotion_playback.get_current_node() == &"turn_left":
				resumed_turn = true
				break

	_fail_unless(was_airborne, "Landing turn anim test never left the ground")
	_fail_unless(
		resumed_turn,
		"Locomotion should resume turn_left after landing with W+A (root=%s, loco=%s)"
		% [root_playback.get_current_node(), locomotion_playback.get_current_node()]
	)
	_fail_unless(
		saw_warmed_locomotion,
		"Landing to turn_left should warm locomotion before/during crossfade (loco=%s)"
		% locomotion_playback.get_current_node()
	)

	Input.action_release("steer_left")
	_release_forward()
	glider.queue_free()
	terrain.queue_free()
	_release_all_input()


func _verify_idle_to_forward_enter() -> void:
	var terrain := _spawn_terrain("idle_enter")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame

	var skin: Node3D = glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	var locomotion_playback := tree.get("parameters/body/locomotion/playback") as AnimationNodeStateMachinePlayback
	var hero_skel: Skeleton3D = skin.get_node("Model/GliderRoot/Hero_Rig/Skeleton3D") as Skeleton3D
	var spine_idx := maxi(0, hero_skel.find_bone("spine"))

	for i in 60:
		await physics_frame

	_fail_unless(glider.is_grounded(), "Idle enter test needs grounded start")
	_fail_unless(
		root_playback.get_current_node() == &"grounded",
		"Idle enter test needs grounded root (root=%s)" % root_playback.get_current_node()
	)

	var idle_spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
	_fail_unless(
		not idle_spine_rot.is_equal_approx(Quaternion.IDENTITY),
		"Idle enter test needs non-bind idle pose before W"
	)

	_hold_forward()
	await physics_frame
	_fail_unless(glider.is_forward_held(), "Idle enter test needs forward input after W press")
	var saw_enter := false
	var saw_spine_motion := false
	for i in 30:
		await physics_frame
		if locomotion_playback.get_current_node() == &"enter":
			saw_enter = true
		var spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
		if not spine_rot.is_equal_approx(idle_spine_rot):
			saw_spine_motion = true
		if saw_enter and saw_spine_motion:
			break

	_fail_unless(
		saw_enter,
		"Idle to forward should play enter (loco=%s root=%s)"
		% [locomotion_playback.get_current_node(), root_playback.get_current_node()]
	)
	_fail_unless(saw_spine_motion, "Idle to forward enter should move hero skeleton")

	glider.queue_free()
	terrain.queue_free()
	_release_all_input()


func _verify_respawn_animation() -> void:
	var terrain := _spawn_terrain("respawn_anim")
	await physics_frame

	var glider := _spawn_glider(terrain)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame

	var skin: Node3D = glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	var locomotion_playback := tree.get("parameters/body/locomotion/playback") as AnimationNodeStateMachinePlayback
	var hero_skel: Skeleton3D = skin.get_node("Model/GliderRoot/Hero_Rig/Skeleton3D") as Skeleton3D
	var spine_idx := maxi(0, hero_skel.find_bone("spine"))

	glider.end_run("test")
	_fail_unless(glider.is_run_ended(), "Respawn anim test needs run ended")

	var reached_death := false
	for i in 30:
		await physics_frame
		if root_playback.get_current_node() == &"death":
			reached_death = true
			break
	_fail_unless(reached_death, "Death animation should play after end_run (root=%s)" % root_playback.get_current_node())

	glider.reset_for_respawn()
	_fail_unless(not glider.is_run_ended(), "Respawn should clear run ended flag")

	for i in 3:
		await physics_frame

	var root_node := root_playback.get_current_node()
	_fail_unless(
		root_node != &"death",
		"Root playback should leave death after respawn (root=%s)" % root_node
	)
	_fail_unless(
		root_node == &"grounded" or root_node == &"locomotion",
		"Root playback should be grounded or locomotion after respawn (root=%s)" % root_node
	)
	if root_node == &"locomotion":
		_fail_unless(
			locomotion_playback.get_current_node() == &"forward",
			"Locomotion should be forward after respawn (loco=%s)" % locomotion_playback.get_current_node()
		)

	var spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
	_fail_unless(
		not spine_rot.is_equal_approx(Quaternion.IDENTITY),
		"Hero skeleton T-pose after respawn"
	)

	glider.queue_free()
	terrain.queue_free()


func _verify_cruise_drift_align() -> void:
	_release_all_input()
	var terrain := _spawn_terrain("drift_align")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
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
	var yaw_before := glider.get_yaw()

	for i in 90:
		await physics_frame

	var yaw_delta := absf(wrapf(glider.get_yaw() - yaw_before, -PI, PI))
	_fail_unless(
		yaw_delta < deg_to_rad(2.0),
		"Holding W must not pull yaw onto velocity (yaw moved %.1f deg)" % rad_to_deg(yaw_delta)
	)

	_release_forward()
	glider.queue_free()
	terrain.queue_free()


func _verify_turn_bank_roll() -> void:
	const BANK_MIN_ROLL_DEG := 3.0
	const STEER_FRAMES := 42

	_release_all_input()
	var terrain := _spawn_terrain("turn_bank")
	await physics_frame

	for steer_action: String in ["steer_left", "steer_right"]:
		var glider := _spawn_glider(terrain)
		_get_input(glider)
		glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
		glider.set("_yaw", 0.0)
		glider.velocity = Vector3(0.0, 0.0, 8.0)
		await physics_frame

		_hold_forward()
		Input.action_press(steer_action)
		for i in STEER_FRAMES:
			await physics_frame
		var roll := glider.get_board_roll()
		Input.action_release(steer_action)
		_release_forward()

		if steer_action == "steer_left":
			_fail_unless(
				roll >= deg_to_rad(BANK_MIN_ROLL_DEG),
				"Steer left should bank into turn (roll %.1f deg, want >= %.1f)"
				% [rad_to_deg(roll), BANK_MIN_ROLL_DEG]
			)
		else:
			_fail_unless(
				roll <= -deg_to_rad(BANK_MIN_ROLL_DEG),
				"Steer right should bank into turn (roll %.1f deg, want <= -%.1f)"
				% [rad_to_deg(roll), BANK_MIN_ROLL_DEG]
			)

		glider.queue_free()
		await physics_frame

	_release_all_input()
	terrain.queue_free()


func _verify_strafe_adds_lateral_speed() -> void:
	_release_all_input()
	var terrain := _spawn_terrain("strafe")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.set("_yaw", 0.0)
	glider.velocity = Vector3(0.0, 0.0, 6.0)
	await physics_frame

	var yaw_before := glider.get_yaw()
	var x_before := glider.velocity.x
	Input.action_press("strafe_left")
	for i in 20:
		await physics_frame
	Input.action_release("strafe_left")

	_fail_unless(
		glider.velocity.x > x_before + 0.35,
		"Strafe left (Q) at yaw 0 should add +X speed (%.2f -> %.2f)" % [x_before, glider.velocity.x]
	)
	var yaw_delta := absf(wrapf(glider.get_yaw() - yaw_before, -PI, PI))
	_fail_unless(
		yaw_delta < deg_to_rad(1.0),
		"Strafe should not yaw (delta %.1f deg)" % rad_to_deg(yaw_delta)
	)

	_release_all_input()
	glider.queue_free()
	terrain.queue_free()


func _verify_strafe_ground_force() -> void:
	var ctx := GliderPhysicsScript.Context.new()
	ctx.ground_normal = Vector3.UP
	ctx.forward_held = true
	ctx.board_forward = Vector3(0.0, 0.0, 1.0)
	ctx.thrust_forward = Vector3(0.0, 0.0, 1.0)
	ctx.velocity = Vector3(0.0, 0.0, 10.0)
	ctx.strafe = 0.0
	var straight := GliderPhysicsScript.compute_ground_force(ctx, 90.0, PHYSICS_DT)
	_fail_unless(
		absf(straight.x) < 0.5,
		"Thrust with no strafe should not shove sideways (got %s)" % straight
	)
	ctx.strafe = -1.0
	var slipped := GliderPhysicsScript.compute_ground_force(ctx, 90.0, PHYSICS_DT)
	_fail_unless(
		slipped.x < -1.0,
		"Thrust + strafe right (E) should request -X slip (got %s)" % slipped
	)


func _verify_strafe_while_thrusting() -> void:
	_release_all_input()
	var terrain := _spawn_terrain("strafe_thrust")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
	glider.set("_yaw", 0.0)
	glider.velocity = Vector3(0.0, 0.0, 8.0)
	await physics_frame

	var x_before := glider.velocity.x
	_hold_forward()
	Input.action_press("strafe_left")
	for i in 24:
		await physics_frame
	Input.action_release("strafe_left")
	_release_forward()

	_fail_unless(
		glider.velocity.x > x_before + 0.35,
		"Q must slip left while holding W (%.2f -> %.2f)" % [x_before, glider.velocity.x]
	)

	_release_all_input()
	glider.queue_free()
	terrain.queue_free()


func _verify_air_steering_weaker() -> void:
	_release_all_input()
	var ground_yaw := await _measure_steer_yaw(false)
	var air_yaw := await _measure_steer_yaw(true)
	_fail_unless(
		air_yaw < ground_yaw * 0.75,
		"Air steering should still be weaker than ground (air %.3f ground %.3f)" % [air_yaw, ground_yaw]
	)
	_fail_unless(
		air_yaw > ground_yaw * 0.30,
		"Air steering should be about half of ground (air %.3f ground %.3f)" % [air_yaw, ground_yaw]
	)


func _measure_steer_yaw(airborne: bool) -> float:
	var tag := "air_steer" if airborne else "ground_steer"
	var terrain := _spawn_terrain(tag)
	await physics_frame
	var glider := _spawn_glider(terrain)
	_get_input(glider)
	if airborne:
		var ground_y := terrain.sample_height(0.0, 0.0)
		glider.global_position = Vector3(0.0, ground_y + 14.0, 0.0)
		glider.velocity = Vector3(0.0, 0.0, 18.0)
		glider.set("_state", GliderPlayerScript.State.GLIDING)
	else:
		glider.global_position = Vector3(0.0, _hover_spawn_y(terrain), 0.0)
		glider.velocity = Vector3(0.0, 0.0, 10.0)
		glider.set("_yaw", 0.0)
	await physics_frame
	var yaw_before := glider.get_yaw()
	Input.action_press("steer_right")
	for i in 36:
		await physics_frame
		if airborne:
			_fail_unless(glider.is_gliding(), "Air steering test should stay airborne")
	Input.action_release("steer_right")
	var yaw_delta := absf(wrapf(glider.get_yaw() - yaw_before, -PI, PI))
	_release_all_input()
	glider.queue_free()
	terrain.queue_free()
	return yaw_delta


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
	_release_all_input()
	var terrain := _spawn_terrain("soft_land_keep")
	await physics_frame

	var glider := _spawn_glider(terrain)
	_get_input(glider)
	var xz := _flattest_xz(terrain)
	var world_x := xz.x
	var world_z := xz.y
	var ground_y := terrain.sample_height(world_x, world_z)
	var n: Vector3 = terrain.sample_normal(world_x, world_z)
	var downhill_h := Vector3(-n.x, 0.0, -n.z)
	var dir := Vector3(0.0, 0.0, 1.0)
	if downhill_h.length_squared() > 0.0001:
		dir = downhill_h.normalized()
	glider.global_position = Vector3(world_x, ground_y + 2.2, world_z)
	glider.set("_yaw", atan2(dir.x, dir.z))
	glider.velocity = Vector3(dir.x * 18.0, -3.0, dir.z * 18.0)
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
	_release_all_input()
	var xz := _flattest_xz(terrain)
	var world_x := xz.x
	var world_z := xz.y
	var ground_y := terrain.sample_height(world_x, world_z)
	var n: Vector3 = terrain.sample_normal(world_x, world_z)
	var downhill_h := Vector3(-n.x, 0.0, -n.z)
	var dir := Vector3(0.0, 0.0, 1.0)
	if downhill_h.length_squared() > 0.0001:
		dir = downhill_h.normalized()
	glider.global_position = Vector3(world_x, ground_y + 8.0, world_z)
	glider.set("_yaw", atan2(dir.x, dir.z))
	glider.velocity = Vector3(dir.x * 20.0, -16.0, dir.z * 20.0)
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
	var tree: AnimationTree = glider.get_node("Visual/GliderSkin/AnimationTree") as AnimationTree
	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	_fail_unless(
		root_playback.get_current_node() == &"jump",
		"Jump while boosting should snap body to jump (state=%s)" % root_playback.get_current_node()
	)
	glider.queue_free()
	terrain.queue_free()
	_release_all_input()
