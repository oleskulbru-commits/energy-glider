class_name GliderPlayer
extends RigidBody3D

const GliderCameraScript = preload("res://scripts/player/glider_camera.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const GliderInputScript = preload("res://scripts/input/glider_input.gd")
const TerrainProbesScript = preload("res://scripts/player/terrain_probes.gd")

enum State { GROUNDED, GLIDING }

# Steering — A/D yaw the nose; boost turns a little slower. Q/E strafe.
# Air uses AIR_STEER_SCALE so jumps stay mostly ballistic.
const SAIL_TURN_RATE := 1.05
const BOOST_TURN_RATE := 0.79
const TURN_RESPONSE := 3.0
const SAIL_STEER_GRIP_RATE := 1.85
const BOOST_STEER_GRIP_RATE := 1.35
const AIR_STEER_SCALE := 0.20
const MIN_STEER_SPEED := 0.5
const YAW_DAMPING := 3.2
const MAX_YAW_VELOCITY := 1.8
const STRAFE_ACCEL := 14.0


static func steering_mul(bonus: float) -> float:
	return 1.0 + clampf(bonus, 0.0, UpgradeCatalog.STEERING_CAP)

# Visual / terrain
const BANK_ANGLE := 15.0
const SLIDE_BANK_ANGLE := 8.0
const SLIDE_BANK_MIN_MISALIGN_DEG := 10.0
const BOARD_BOTTOM_OFFSET := 0.005
const BOARD_HALF_LENGTH := 1.0
const BOARD_HALF_EXTENTS := Vector3(0.4, 0.075, 1.0)
const COLLISION_SHAPE_OFFSET := Vector3(0.0, 0.08, 0.0)
const CONTACT_MAX_DROP := 1.2
const TERRAIN_NORMAL_EPSILON := 1.2
const TERRAIN_ALIGN_RATE := 10.0
const AIR_TERRAIN_ALIGN_RATE := 16.0
const VISUAL_TILT_RATE := 12.0
const PREDICT_BLEND_RATE := 4.0
const PREDICT_BLEND_RELEASE_RATE := 2.5
const PREDICT_NORMAL_RATE := 8.0
const GROUND_NORMAL_MAX_STEP_DEG := 6.0
const BOOST_CLIMB_NORMAL_MAX_STEP_DEG := 12.0
const AHEAD_RISE_NORMAL_MAX_STEP_DEG := 18.0
const BOOST_CLIMB_CLIP_MAX := -0.02
const FLOOR_CORRECT_MAX_STEP := 0.06
const BOOST_CLIMB_FLOOR_CORRECT_MAX_STEP := 0.18
const VISUAL_ALIGN_MAX_STEP_DEG := 4.5
const AHEAD_RISE_VISUAL_ALIGN_MAX_STEP_DEG := 7.0
const BOARD_PITCH_RATE := 6.0
const PITCH_NORMAL_RATE := 5.5
const PITCH_NORMAL_MAX_STEP_DEG := 3.5
const AHEAD_RISE_PITCH_RATE := 12.0
const AHEAD_RISE_PITCH_MAX_STEP_DEG := 10.0
const AIR_VELOCITY_PITCH_BLEND := 0.55
const AHEAD_NORMAL_MIN_SPEED := 3.5
const AHEAD_RISE_TRIGGER := 0.34
const AHEAD_RISE_FULL := 0.65
const AHEAD_RISE_WEIGHT_SCALE := 2.8
const PREDICT_PROBE_FORWARD_DISTANCE_NEAR := 1.5
const PREDICT_PROBE_FORWARD_DISTANCE_MID := 3.0
const PREDICT_PROBE_FORWARD_DISTANCE_FAR := 5.0
const PREDICT_PROBE_LATERAL := 0.35
const PREDICT_PROBE_VELOCITY_LOOKAHEAD := 3.0
const LAND_ALIGN_START_HEIGHT := 5.0
const LAND_ALIGN_DONE_HEIGHT := 1.0
const DESCENT_MOMENTUM_START := 0.92
const DESCENT_MOMENTUM_FULL := 1.08
const CREST_LIP_AHEAD_DROP := 0.48
const CREST_LIP_NOSE_DROP := 0.32
const CREST_LIP_MIN_SPEED := 3.5
const LANDING_STABILIZE_DURATION := 0.3
const LANDING_FEEDBACK_DURATION := 0.6
const GROUNDED_LOCK_DURATION := 0.4

# Hover clearance smoothing — physics reads eased clearance, state machine stays raw.
const CLEARANCE_SMOOTH_RATE_UP := 8.0
const CLEARANCE_SMOOTH_RATE_DOWN := 5.0
const CLEARANCE_MAX_RISE_RATE := 4.5
const CLEARANCE_MAX_DROP_RATE := 2.8
const CLEARANCE_PROBE_BLEND := 0.55
const CLEARANCE_PROBE_TRIGGER := 0.12
const CLEARANCE_SETTLE_BAND := 0.05
const CLEARANCE_SETTLE_RATE := 12.0
const HOVER_DECK_PLANE_BLEND := 0.5
const HOVER_DECK_PLANE_BLEND_MIN := 0.18
const DECK_PLANE_DISAGREE_REF_DEG := 14.0
const RISE_FACE_GRADE := 0.12
const CREST_LIP_MIN_GRADE := 0.08
const AHEAD_FAR_RISE_SCALE := 0.28
const GROUND_RAY_UP := 8.0
const GROUND_RAY_DOWN := 24.0

# Charge / boost
const CHARGE_MAX := 1.0
const CHARGE_MIN_BOOST := 0.05
const CHARGE_BOOST_DRAIN := 0.2
const CHARGE_SOLAR_RECHARGE := 0.04
const BATTERY_MAX := CHARGE_MAX * 10.0
const THRUSTER_OVERHEAT_DURATION := 4.0
const BOOST_MULTIPLIER := GliderPhysicsScript.BOOST_MULTIPLIER
const BRAKE_RAMP_SEC := 0.55
const COAST_DURATION := GliderPhysicsScript.COAST_DURATION
const HOVER_IDLE_SETTLE_SPEED := 0.35

@export var terrain_manager_path: NodePath

signal run_ended

var _terrain_manager: TerrainManager
var _input: GliderInputScript
var _visual: Node3D
var _camera: GliderCameraScript
var _contact_dust: CPUParticles3D
var _impact_dust: CPUParticles3D
var _contact_sparks: CPUParticles3D

var _state: State = State.GROUNDED
var _yaw: float = 0.0
var _yaw_velocity: float = 0.0
var _turn_rate: float = 0.0
var _ground_normal := Vector3.UP
var _predictive_surface: TerrainProbesScript.SurfaceResult = null
var _predictive_normal := Vector3.UP
var _predictive_pitch_normal := Vector3.UP
var _smoothed_pitch_normal := Vector3.UP
var _smoothed_predict_blend := 0.0
var _smoothed_predictive_normal := Vector3.UP
var _smoothed_center_normal := Vector3.UP
var _smoothed_visual_basis := Basis.IDENTITY
var _smoothed_clearance := GliderPhysicsScript.BASE_HEIGHT
var _prev_raw_clearance := GliderPhysicsScript.BASE_HEIGHT
var _clearance_change_rate := 0.0
var _board_pitch := 0.0
var _board_roll := 0.0

var _charge := CHARGE_MAX
var _battery := 0.0
var _boost_unlocked := true
var _overheat_timer := 0.0
var _day_night: DayNightCycle
var _run_ended := false
var _end_reason := ""
var _piloted := true
var _pending_knockback := Vector3.ZERO
var _coast_timer := 0.0
var _brake_hold_time := 0.0
var _landing_feedback_timer := 0.0
var _landing_feedback_label := ""
var _landing_stabilize_timer := 0.0
var _hull_integrity := 1.0
var _grounded_lock_timer := 0.0
var _airborne_time := 0.0
var _jump_cooldown := 0.0
var _jump_anim_pending := false
var _boost_anim_pending := false
var _was_boost_active := false
var _brake_anim_pending := false
var _was_brake_active := false
var _air_hold_horizontal_speed := 0.0
var _saved_collision_layer := 2
var _physics_ctx: GliderPhysicsScript.Context = null
var _last_physics_delta := 1.0 / 60.0


var velocity: Vector3:
	get:
		return linear_velocity
	set(value):
		linear_velocity = value


func _ready() -> void:
	_terrain_manager = get_node_or_null(terrain_manager_path) as TerrainManager if terrain_manager_path != NodePath() else null
	_input = _resolve_input()
	_visual = get_node_or_null("Visual") as Node3D
	_camera = get_node_or_null("GliderCamera") as GliderCameraScript
	if _camera == null:
		_camera = get_node_or_null("Camera3D") as GliderCameraScript
	_contact_dust = get_node_or_null("ContactDust") as CPUParticles3D
	_impact_dust = get_node_or_null("ImpactDust") as CPUParticles3D
	_setup_contact_sparks()
	_yaw = rotation.y

	if _terrain_manager != null:
		var spawn_x := global_position.x
		var spawn_z := global_position.z
		var spawn_y := _terrain_manager.sample_height(spawn_x, spawn_z) + GliderPhysicsScript.BASE_HEIGHT + 0.05
		global_position.y = spawn_y
		_ground_normal = _terrain_manager.sample_normal(spawn_x, spawn_z)
		_smoothed_predictive_normal = _ground_normal
		_smoothed_center_normal = _ground_normal
		_smoothed_pitch_normal = _ground_normal
		_smoothed_predict_blend = 1.0
		_sync_visual_basis_from_ground()
		_smoothed_clearance = _get_raw_clearance()
		_prev_raw_clearance = _smoothed_clearance

	if _input != null:
		_input.set_boost_input_enabled(_boost_unlocked)
	_day_night = get_tree().get_first_node_in_group("day_night_cycle") as DayNightCycle


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("kill_player") and not _run_ended:
		end_run("death")


func _physics_process(delta: float) -> void:
	if _input == null:
		_input = _resolve_input()
	if _input == null or not _piloted:
		return

	if _run_ended:
		if not _uses_external_camera():
			_update_camera(delta)
		return

	_sample_terrain(delta)
	_apply_steering(delta)
	if _jump_cooldown > 0.0:
		_jump_cooldown = maxf(_jump_cooldown - delta, 0.0)
	_try_jump()
	_update_state(delta)
	if _state == State.GLIDING:
		_airborne_time += delta
	else:
		_airborne_time = 0.0
	_update_charge(delta)
	_update_overheat(delta)
	_update_coast(delta)
	_update_landing_feedback(delta)
	_update_brake_ramp(delta)
	_update_orientation(delta)

	if not _uses_external_camera():
		_update_camera(delta)

	var boost_active := _is_boost_active()
	if boost_active and not _was_boost_active:
		_boost_anim_pending = true
	_was_boost_active = boost_active

	var brake_active := is_braking()
	if brake_active and not _was_brake_active:
		_brake_anim_pending = true
	_was_brake_active = brake_active

	_last_physics_delta = delta
	_physics_ctx = _build_physics_context()
	_update_contact_dust()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _physics_ctx == null or _input == null or not _piloted or _run_ended:
		return

	var ctx := _physics_ctx
	ctx.velocity = state.linear_velocity
	## Live input — ctx may be one physics frame stale vs IntegrateForces order.
	ctx.forward_held = _input.is_forward_held()
	ctx.boost_active = _is_boost_active()
	ctx.braking = is_braking()
	ctx.brake_strength = _brake_strength()
	var delta := maxf(_last_physics_delta, 0.0001)
	var mass := maxf(self.mass, 0.001)
	var force := Vector3.ZERO
	var air_hold_speed := MathUtil.horizontal_speed(state.linear_velocity)

	if _state == State.GROUNDED:
		_air_hold_horizontal_speed = 0.0
		force += GliderPhysicsScript.compute_ground_force(ctx, mass, delta)
		_apply_hover_forces(state, ctx, mass, delta)
		force += GliderPhysicsScript.compute_ground_scrape_force(ctx, mass)
	else:
		force += GliderPhysicsScript.compute_air_force(ctx, mass, delta)

	var constraint_mode := (
		GliderPhysicsScript.MODE_GROUNDED
		if _state == State.GROUNDED
		else GliderPhysicsScript.MODE_GLIDING
	)

	state.apply_central_force(force)
	GliderPhysicsScript.apply_velocity_constraints(
		ctx,
		state.linear_velocity,
		constraint_mode,
		state
	)
	_enforce_floor_contact(state)
	_apply_pending_knockback(state)
	if _state == State.GLIDING:
		_preserve_air_horizontal_speed(state, air_hold_speed)
	_apply_strafe(state, delta)
	state.angular_velocity = Vector3(0.0, _yaw_velocity, 0.0)


func _apply_strafe(state: PhysicsDirectBodyState3D, delta: float) -> void:
	if _input == null:
		return
	var strafe := _input.get_strafe()
	if absf(strafe) <= 0.01:
		return
	var air := _state == State.GLIDING
	var axis := Vector3.UP if air else _ground_normal
	var nose := _flat_yaw_forward()
	if not air:
		var slid := nose.slide(axis)
		if slid.length_squared() > 0.0001:
			nose = slid.normalized()
	var right := axis.cross(nose)
	if right.length_squared() < 0.0001:
		return
	var scale := AIR_STEER_SCALE if air else 1.0
	var slip := right.normalized() * strafe * STRAFE_ACCEL * scale * delta
	var vel := state.linear_velocity
	if air:
		vel.x += slip.x
		vel.z += slip.z
	else:
		vel += slip.slide(axis)
	state.linear_velocity = vel


func _preserve_air_horizontal_speed(state: PhysicsDirectBodyState3D, speed_before: float) -> void:
	## Holding W in air: lock XZ to the speed when hold started (capped). No ratchet.
	## Boost accelerates via compute_air_force — do not freeze XZ while boosting.
	if is_braking():
		_air_hold_horizontal_speed = 0.0
		return
	if _is_boost_active():
		## Clear lock so releasing boost while W is held re-locks at the new speed.
		_air_hold_horizontal_speed = 0.0
		return
	if not _input.is_forward_held():
		_air_hold_horizontal_speed = 0.0
		return
	var cap := GliderPhysicsScript.hard_speed_cap(_glider_speed_bonus())
	if _air_hold_horizontal_speed < 0.1:
		_air_hold_horizontal_speed = minf(maxf(speed_before, 0.0), cap)
	if _air_hold_horizontal_speed < 0.1:
		return
	var keep := minf(_air_hold_horizontal_speed, cap)
	var h := MathUtil.horizontal(state.linear_velocity)
	var dir := h
	if dir.length_squared() < 0.0001:
		dir = MathUtil.horizontal(_board_forward_on_ground())
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	state.linear_velocity.x = dir.x * keep
	state.linear_velocity.z = dir.z * keep


func _corner_hover_samples() -> Array:
	var points: Array = []
	if _predictive_surface == null:
		return points
	var climbing := _is_climbing(_downhill_dir(), _board_forward_on_ground())
	var include_nose := _is_boost_climb_active() or climbing
	var use_deck := climbing or _is_boost_climb_active()
	for sample in _predictive_surface.samples:
		if not sample.valid:
			continue
		if sample.tag == "corner" or (include_nose and TerrainProbesScript.is_nose_tag(sample.tag)):
			pass
		else:
			continue
		var point := GliderPhysicsScript.HoverPointSample.new()
		point.local_offset = sample.local_offset
		point.clearance = (
			_deck_probe_clearance_at(sample.local_offset)
			if use_deck
			else sample.clearance
		)
		point.normal = sample.normal
		point.valid = true
		points.append(point)
	return points


func _corner_clearance_spread() -> float:
	if _predictive_surface == null:
		return 0.0
	return TerrainProbesScript.clearance_spread(_predictive_surface.samples)


func _apply_hover_forces(
	state: PhysicsDirectBodyState3D,
	ctx: GliderPhysicsScript.Context,
	mass: float,
	delta: float,
	strength_scale: float = 1.0
) -> void:
	if (
		not ctx.climbing
		and not ctx.boost_active
		and _corner_clearance_spread() > CLEARANCE_PROBE_TRIGGER
	):
		state.apply_central_force(
			GliderPhysicsScript.compute_hover_force(ctx, mass, delta) * strength_scale
		)
		return

	var corner_forces := GliderPhysicsScript.compute_corner_hover_forces(
		ctx, mass, delta, _corner_hover_samples()
	)
	if corner_forces.is_empty():
		state.apply_central_force(
			GliderPhysicsScript.compute_hover_force(ctx, mass, delta) * strength_scale
		)
		return

	for hover_force in corner_forces:
		state.apply_force(
			hover_force.force * strength_scale,
			state.transform * hover_force.local_offset
		)


func _sample_terrain(delta: float) -> void:
	_update_predictive_probes()
	_update_smoothed_pitch_normal(delta)

	var normal_step := clampf(PREDICT_NORMAL_RATE * delta, 0.0, 1.0)
	_smoothed_predictive_normal = _slerp_normal(
		_smoothed_predictive_normal, _predictive_normal, normal_step
	)

	var raw_blend := _predictive_align_blend()
	var blend_rate := PREDICT_BLEND_RATE
	if raw_blend < _smoothed_predict_blend:
		blend_rate = PREDICT_BLEND_RELEASE_RATE
	var blend_step := clampf(blend_rate * delta, 0.0, 1.0)
	_smoothed_predict_blend = lerpf(_smoothed_predict_blend, raw_blend, blend_step)

	var center_normal := _sample_terrain_normal(global_position.x, global_position.z)
	_smoothed_center_normal = _slerp_normal(_smoothed_center_normal, center_normal, normal_step)

	var target_normal := _target_terrain_normal(_smoothed_predict_blend)

	var align_rate := TERRAIN_ALIGN_RATE
	if _state == State.GLIDING:
		align_rate = lerpf(TERRAIN_ALIGN_RATE * 0.5, AIR_TERRAIN_ALIGN_RATE, _smoothed_predict_blend)

	var align_step := clampf(align_rate * delta, 0.0, 1.0)
	var normal_turn := _ground_normal.angle_to(target_normal)
	var rise_lead := _ahead_rise_lead()
	var max_normal_step_deg := GROUND_NORMAL_MAX_STEP_DEG
	if (
		_is_boost_active()
		and _slope_grade() > GliderPhysicsScript.CLIMB_DRAG_MIN_GRADE
	):
		max_normal_step_deg = BOOST_CLIMB_NORMAL_MAX_STEP_DEG
	# Only accelerate normal tracking on clear rising faces — avoid flat-noise false crest launches.
	if rise_lead > 0.0 and (
		_is_climbing(_downhill_dir(), _board_forward_on_ground())
		or _slope_grade() > RISE_FACE_GRADE
	):
		max_normal_step_deg = lerpf(
			max_normal_step_deg,
			AHEAD_RISE_NORMAL_MAX_STEP_DEG,
			rise_lead
		)
	if normal_turn > 0.0001:
		align_step = minf(align_step, deg_to_rad(max_normal_step_deg) / normal_turn)
	_ground_normal = _slerp_normal(_ground_normal, target_normal, align_step)
	_update_clearance_smooth(delta)


func _update_predictive_probes() -> void:
	var horizontal := _horizontal_velocity()
	var vel_local_x := 0.0
	var vel_local_z := 0.0
	if horizontal.length_squared() > 0.01:
		var vel_local: Vector3 = Basis.from_euler(Vector3(0.0, -_yaw, 0.0)) * horizontal
		vel_local_x = vel_local.x
		vel_local_z = vel_local.z

	var specs := TerrainProbesScript.build_default_specs(
		BOARD_HALF_EXTENTS,
		BOARD_HALF_LENGTH,
		PackedFloat32Array([
			PREDICT_PROBE_FORWARD_DISTANCE_NEAR,
			PREDICT_PROBE_FORWARD_DISTANCE_MID,
			PREDICT_PROBE_FORWARD_DISTANCE_FAR,
		]),
		PREDICT_PROBE_LATERAL,
		PREDICT_PROBE_VELOCITY_LOOKAHEAD,
		true,
		vel_local_x,
		vel_local_z
	)

	var clamp_cb := Callable()
	if _state == State.GROUNDED and not _is_boost_climb_active():
		clamp_cb = Callable(self, "_clamp_contact_height")

	_predictive_surface = TerrainProbesScript.build_surface(
		global_position,
		_yaw,
		_probe_bottom_y_offset(),
		specs,
		Callable(self, "_sample_height_at"),
		Callable(self, "_sample_normal_at"),
		clamp_cb,
		_ground_normal
	)
	_predictive_normal = _derive_probe_normal()


func _ahead_rise_amount() -> float:
	## How much the board nose digs vs center (positive = face coming up under the deck).
	## Board-local by default — far ahead probes read whole dune faces as multi-meter walls.
	if _predictive_surface == null:
		return 0.0
	var center_c := NAN
	var nose_c := INF
	var far_c := INF
	for sample in _predictive_surface.samples:
		if not sample.valid:
			continue
		match sample.tag:
			"center":
				center_c = sample.clearance
			_:
				if TerrainProbesScript.is_nose_tag(sample.tag):
					nose_c = minf(nose_c, sample.clearance)
				elif TerrainProbesScript.is_ahead_tag(sample.tag):
					far_c = minf(far_c, sample.clearance)
	if is_nan(center_c) or nose_c == INF:
		return 0.0

	var board_rise := 0.0
	if _state == State.GROUNDED:
		var deck_center := _deck_probe_clearance_at(Vector3.ZERO)
		var deck_nose := INF
		for sample in _predictive_surface.samples:
			if not sample.valid:
				continue
			if TerrainProbesScript.is_nose_tag(sample.tag):
				deck_nose = minf(deck_nose, _deck_probe_clearance_at(sample.local_offset))
		if deck_nose != INF:
			board_rise = maxf(deck_center - deck_nose, 0.0)
		else:
			board_rise = maxf(center_c - nose_c, 0.0)
	else:
		board_rise = maxf(center_c - nose_c, 0.0)

	# True thruster climbs need foresight up the face; damp far probes so they don't saturate lead.
	if _is_boost_active() and far_c != INF:
		var far_rise := maxf(center_c - far_c, 0.0) * AHEAD_FAR_RISE_SCALE
		return maxf(board_rise, far_rise)
	return board_rise


func _ahead_rise_lead() -> float:
	return smoothstep(AHEAD_RISE_TRIGGER, AHEAD_RISE_FULL, _ahead_rise_amount())


func _derive_probe_normal() -> Vector3:
	if _predictive_surface == null:
		return _ground_normal

	var tangent_speed := velocity.slide(_ground_normal).length()
	var ahead_weight := smoothstep(
		AHEAD_NORMAL_MIN_SPEED - 1.2,
		AHEAD_NORMAL_MIN_SPEED + 0.8,
		tangent_speed
	)
	var rise_lead := _ahead_rise_lead()
	if rise_lead > 0.0 and (
		_is_climbing(_downhill_dir(), _board_forward_on_ground())
		or _slope_grade() > RISE_FACE_GRADE
	):
		ahead_weight *= lerpf(1.0, AHEAD_RISE_WEIGHT_SCALE, rise_lead)
		ahead_weight = maxf(ahead_weight, rise_lead)
	var velocity_weight := smoothstep(0.8, 2.8, tangent_speed)

	var weighted_sum := Vector3.ZERO
	var weight_total := 0.0
	for sample in _predictive_surface.samples:
		if not sample.valid:
			continue
		var weight := 0.0
		if TerrainProbesScript.is_board_tag(sample.tag):
			weight = 1.0
		elif TerrainProbesScript.is_ahead_tag(sample.tag):
			weight = ahead_weight
		elif sample.tag == "velocity":
			weight = velocity_weight
		if weight <= 0.0001:
			continue
		var aligned := sample.normal
		if weighted_sum.length_squared() > 0.0001 and weighted_sum.dot(aligned) < 0.0:
			aligned = -aligned
		weighted_sum += aligned * weight
		weight_total += weight

	if weight_total <= 0.0001:
		return _predictive_surface.avg_normal
	return (weighted_sum / weight_total).normalized()


func _update_smoothed_pitch_normal(delta: float) -> void:
	if _predictive_surface == null:
		return
	var target := _predictive_surface.board_plane_normal
	if target.length_squared() < 0.0001:
		target = _ground_normal
	if target.dot(_ground_normal) < 0.0:
		target = -target
	var rise_lead := _ahead_rise_lead()
	var pitch_rate := lerpf(PITCH_NORMAL_RATE, AHEAD_RISE_PITCH_RATE, rise_lead)
	var max_step_deg := lerpf(PITCH_NORMAL_MAX_STEP_DEG, AHEAD_RISE_PITCH_MAX_STEP_DEG, rise_lead)
	var step := clampf(pitch_rate * delta, 0.0, 1.0)
	var turn := _smoothed_pitch_normal.angle_to(target)
	if turn > 0.0001:
		step = minf(step, deg_to_rad(max_step_deg) / turn)
	_smoothed_pitch_normal = _slerp_normal(_smoothed_pitch_normal, target, step)
	_predictive_pitch_normal = _smoothed_pitch_normal


func _deck_plane_blend() -> float:
	if _predictive_pitch_normal.length_squared() < 0.0001:
		return HOVER_DECK_PLANE_BLEND_MIN
	var disagree_deg := rad_to_deg(_ground_normal.angle_to(_predictive_pitch_normal))
	var sharpness := clampf(disagree_deg / DECK_PLANE_DISAGREE_REF_DEG, 0.0, 1.0)
	return lerpf(HOVER_DECK_PLANE_BLEND, HOVER_DECK_PLANE_BLEND_MIN, sharpness)


func _slerp_normal(from: Vector3, to: Vector3, t: float) -> Vector3:
	var target := to
	if from.dot(target) < 0.0:
		target = -target
	return from.slerp(target, clampf(t, 0.0, 1.0)).normalized()


func _slerp_basis_capped(from: Basis, to: Basis, t: float, max_rad: float) -> Basis:
	var q_from := from.get_rotation_quaternion()
	var q_to := to.get_rotation_quaternion()
	if q_from.dot(q_to) < 0.0:
		q_to = Quaternion(-q_to.x, -q_to.y, -q_to.z, -q_to.w)
	var angle := q_from.angle_to(q_to)
	var blend := clampf(t, 0.0, 1.0)
	if angle > 0.0001 and angle * blend > max_rad:
		blend = max_rad / angle
	return Basis(q_from.slerp(q_to, blend))


func _probe_bottom_y_offset() -> float:
	return COLLISION_SHAPE_OFFSET.y - BOARD_HALF_EXTENTS.y


func _sample_height_at(world_x: float, world_z: float) -> float:
	return _get_ground_y(world_x, world_z)


func _sample_normal_at(world_x: float, world_z: float) -> Vector3:
	return _sample_terrain_normal(world_x, world_z)


func _clamp_contact_height(raw_y: float) -> float:
	var center_y := _get_ground_y(global_position.x, global_position.z)
	if is_nan(center_y):
		return raw_y
	return maxf(raw_y, center_y - CONTACT_MAX_DROP)


func _min_board_probe_clearance() -> float:
	var min_clearance := _get_raw_clearance()
	if _predictive_surface == null:
		return min_clearance
	return TerrainProbesScript.min_tagged_clearance(_predictive_surface.samples, min_clearance)


func _live_min_board_probe_clearance_at(origin: Vector3) -> float:
	## Live underside clearance at a physics-state origin (not stale probe cache).
	var center_ground := _get_ground_y(origin.x, origin.z)
	var min_clearance := origin.y - BOARD_BOTTOM_OFFSET - center_ground
	if is_nan(center_ground):
		return min_clearance
	if _predictive_surface == null:
		return min_clearance
	var probe_bottom_y := _probe_bottom_y_offset()
	var yaw_basis := Basis.from_euler(Vector3(0.0, _yaw, 0.0))
	return TerrainProbesScript.min_tagged_clearance(
		_predictive_surface.samples,
		min_clearance,
		Callable(TerrainProbesScript, "is_board_tag"),
		func(sample) -> float:
			var world_offset: Vector3 = yaw_basis * sample.local_offset
			var probe_y := origin.y + probe_bottom_y
			var ground_y := _get_ground_y(
				origin.x + world_offset.x,
				origin.z + world_offset.z
			)
			if is_nan(ground_y):
				return min_clearance
			return probe_y - ground_y
	)


func _live_min_board_probe_clearance() -> float:
	return _live_min_board_probe_clearance_at(global_position)


func _live_min_deck_probe_clearance() -> float:
	## Underside clearance with deck tilt (body upright, visual pitched to terrain).
	var min_clearance := _get_raw_clearance()
	if _predictive_surface == null:
		return min_clearance
	return TerrainProbesScript.min_tagged_clearance(
		_predictive_surface.samples,
		min_clearance,
		Callable(TerrainProbesScript, "is_board_tag"),
		func(sample) -> float:
			return _deck_probe_clearance_at(sample.local_offset)
	)


func _deck_probe_clearance_at(local_offset: Vector3) -> float:
	var deck := _build_deck_world_basis(_ground_normal, 0.0)
	var local := Vector3(local_offset.x, _probe_bottom_y_offset(), local_offset.z)
	var world: Vector3 = global_position + deck * local
	var ground_y := _get_ground_y(world.x, world.z)
	if is_nan(ground_y):
		return _get_raw_clearance()
	return world.y - ground_y


func _enforce_floor_contact(state: PhysicsDirectBodyState3D) -> void:
	if _state != State.GROUNDED:
		return
	var boost_climb := _is_boost_climb_active()
	var climbing := _is_climbing(_downhill_dir(), _board_forward_on_ground())
	## Live-sample from the integrate-forces origin — cached probes lag one frame.
	var origin := state.transform.origin
	var min_clearance := _live_min_board_probe_clearance_at(origin)
	if climbing:
		min_clearance = minf(min_clearance, _live_min_deck_probe_clearance())
	var clip_max := (
		BOOST_CLIMB_CLIP_MAX
		if boost_climb or climbing
		else GliderPhysicsScript.GROUND_CLIP_MAX
	)
	var ny := maxf(_ground_normal.y, 0.2)
	var max_step := (
		BOOST_CLIMB_FLOOR_CORRECT_MAX_STEP if boost_climb else FLOOR_CORRECT_MAX_STEP
	)
	if min_clearance < clip_max:
		var needed := (clip_max - min_clearance) / ny
		var correction := minf(needed, max_step)
		var xf := state.transform
		xf.origin += _ground_normal * correction
		state.transform = xf
		# Climbing: leave normal speed to hover/alignment — zeroing it bleeds crest carry.
		if not climbing:
			var vel := state.linear_velocity
			var inward := vel.dot(_ground_normal)
			if inward < 0.0:
				state.linear_velocity = vel - _ground_normal * inward
		return
	var min_allowed := GliderPhysicsScript.TOUCH_CLEARANCE
	if min_clearance >= min_allowed:
		return
	var correction := minf((min_allowed - min_clearance) / ny, max_step)
	var xf := state.transform
	xf.origin += _ground_normal * correction
	state.transform = xf
	# Soft settle: nudge origin only — killing normal speed here tugs crest momentum.


func _setup_contact_sparks() -> void:
	_contact_sparks = CPUParticles3D.new()
	_contact_sparks.name = "ContactSparks"
	_contact_sparks.emitting = false
	_contact_sparks.amount = 18
	_contact_sparks.lifetime = 0.28
	_contact_sparks.one_shot = true
	_contact_sparks.explosiveness = 0.95
	_contact_sparks.randomness = 0.65
	_contact_sparks.direction = Vector3(0.0, 0.35, 0.2)
	_contact_sparks.spread = 48.0
	_contact_sparks.gravity = Vector3(0.0, -8.0, 0.0)
	_contact_sparks.initial_velocity_min = 3.0
	_contact_sparks.initial_velocity_max = 7.5
	_contact_sparks.scale_amount_min = 0.04
	_contact_sparks.scale_amount_max = 0.09
	_contact_sparks.color = Color(1.0, 0.72, 0.22, 0.9)
	_contact_sparks.transform = Transform3D.IDENTITY.translated(Vector3(0.0, 0.03, 0.0))
	add_child(_contact_sparks)


func _has_predictive_surface() -> bool:
	return _predictive_surface != null and not _predictive_surface.samples.is_empty()


func _predictive_align_blend() -> float:
	if _state == State.GROUNDED:
		return 1.0 if _has_predictive_surface() else 0.0

	var forward_speed := _horizontal_velocity().length()
	var descent_speed := maxf(0.0, -velocity.dot(_ground_normal))
	descent_speed = maxf(descent_speed, maxf(0.0, -velocity.y))

	var momentum_blend := 0.0
	if forward_speed > 0.15 or descent_speed > 0.15:
		var ratio := descent_speed / maxf(forward_speed, 0.25)
		momentum_blend = smoothstep(DESCENT_MOMENTUM_START, DESCENT_MOMENTUM_FULL, ratio)

	var clearance := _get_clearance()
	var height_blend := 0.0
	if clearance > GliderPhysicsScript.HOVER_ZONE and clearance <= LAND_ALIGN_START_HEIGHT:
		var span := maxf(LAND_ALIGN_START_HEIGHT - LAND_ALIGN_DONE_HEIGHT, 0.01)
		height_blend = smoothstep(
			0.0, 1.0, 1.0 - (clearance - LAND_ALIGN_DONE_HEIGHT) / span
		)

	return clampf(maxf(momentum_blend, height_blend), 0.0, 1.0)


func _target_terrain_normal(predict_blend: float) -> Vector3:
	if _state == State.GLIDING and predict_blend <= 0.001:
		return Vector3.UP
	if predict_blend <= 0.001:
		return _smoothed_center_normal
	return _slerp_normal(_smoothed_center_normal, _smoothed_predictive_normal, predict_blend)


func _sample_terrain_normal(world_x: float, world_z: float) -> Vector3:
	return TerrainQuery.sample_normal(
		_terrain_manager,
		get_world_3d().direct_space_state if get_world_3d() != null else null,
		world_x,
		world_z,
		global_position.y,
		TERRAIN_NORMAL_EPSILON,
		[get_rid()],
		GROUND_RAY_UP,
		GROUND_RAY_DOWN
	)


func _get_ground_y(world_x: float, world_z: float) -> float:
	return TerrainQuery.sample_height(
		_terrain_manager,
		get_world_3d().direct_space_state if get_world_3d() != null else null,
		world_x,
		world_z,
		global_position.y,
		[get_rid()],
		GROUND_RAY_UP,
		GROUND_RAY_DOWN
	)


func _raycast_ground(world_x: float, world_z: float) -> Dictionary:
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	return TerrainQuery.raycast_ground(
		space,
		world_x,
		world_z,
		global_position.y,
		GROUND_RAY_UP,
		GROUND_RAY_DOWN,
		[get_rid()]
	)


func _get_raw_clearance() -> float:
	var ground_y := _get_ground_y(global_position.x, global_position.z)
	if is_nan(ground_y):
		return 0.0
	return global_position.y - BOARD_BOTTOM_OFFSET - ground_y


func _sample_hover_clearance_target() -> float:
	var center := _get_raw_clearance()
	if _state != State.GROUNDED or _predictive_surface == null:
		return center

	var min_clearance := _predictive_surface.min_clearance
	var avg_clearance := _predictive_surface.avg_clearance
	if min_clearance == INF or is_nan(min_clearance):
		return center
	if _is_boost_climb_active():
		return minf(center, min_clearance)
	if center - min_clearance >= CLEARANCE_PROBE_TRIGGER:
		return lerpf(center, avg_clearance, CLEARANCE_PROBE_BLEND)
	return center


func _update_clearance_smooth(delta: float) -> void:
	var raw := _get_raw_clearance()
	_clearance_change_rate = absf(raw - _prev_raw_clearance) / maxf(delta, 0.0001)
	var target := _sample_hover_clearance_target()
	var smooth_rate := (
		CLEARANCE_SMOOTH_RATE_DOWN
		if target < _smoothed_clearance
		else CLEARANCE_SMOOTH_RATE_UP
	)
	var max_step := (
		CLEARANCE_MAX_DROP_RATE * delta
		if target < _smoothed_clearance
		else CLEARANCE_MAX_RISE_RATE * delta
	)
	var step_target := _smoothed_clearance + clampf(target - _smoothed_clearance, -max_step, max_step)
	var blend_rate := smooth_rate
	if absf(target - _smoothed_clearance) <= CLEARANCE_SETTLE_BAND:
		blend_rate = CLEARANCE_SETTLE_RATE
	_smoothed_clearance = lerpf(
		_smoothed_clearance,
		step_target,
		clampf(blend_rate * delta, 0.0, 1.0)
	)
	_prev_raw_clearance = raw


func _get_clearance() -> float:
	return _get_raw_clearance()


func _update_state(delta: float) -> void:
	var clearance := _get_clearance()

	if _state == State.GROUNDED:
		if _forward_support_lost():
			_detach_from_crest_lip()
			return
		return

	if _state != State.GLIDING or clearance > GliderPhysicsScript.GLIDE_EXIT_HEIGHT:
		return

	# Rising out of a hop — stay ballistic until apex passes.
	if velocity.y > 0.2:
		return

	var world_fall := -velocity.y
	var into_ground := -velocity.dot(_ground_normal)
	if world_fall < 0.2 and into_ground < 0.2:
		return

	_land()


func _try_jump() -> void:
	if _input == null:
		_input = _resolve_input()
	if _run_ended or _state != State.GROUNDED:
		return
	if _jump_cooldown > 0.0 or _grounded_lock_timer > 0.0:
		return
	if _input == null or not _input.is_jump_just_pressed():
		return
	if is_braking():
		return

	var tangent_speed := velocity.slide(_ground_normal).length()
	velocity = GliderPhysicsScript.apply_inertia_jump(
		velocity, _ground_normal, tangent_speed
	)
	_airborne_time = 0.0
	_state = State.GLIDING
	_jump_cooldown = GliderPhysicsScript.JUMP_COOLDOWN
	_jump_anim_pending = true
	if not _should_preserve_yaw_on_jump():
		_align_yaw_to_travel_direction(1.0)


func _should_preserve_yaw_on_jump() -> bool:
	if absf(get_steer_axis()) > 0.01:
		return true
	if is_forward_held() or _is_boost_active():
		return true
	return false


func _crest_board_clearances() -> Vector3:
	if _predictive_surface == null:
		return Vector3(NAN, NAN, NAN)
	var center_clearance := NAN
	var nose_clearance := NAN
	var tail_clearance := NAN
	for sample in _predictive_surface.samples:
		if not sample.valid:
			continue
		match sample.tag:
			"center":
				center_clearance = sample.clearance
			"nose":
				nose_clearance = sample.clearance
			"tail":
				tail_clearance = sample.clearance
	return Vector3(center_clearance, nose_clearance, tail_clearance)


func _forward_support_lost() -> bool:
	if _grounded_lock_timer > 0.0:
		return false
	if _predictive_surface == null:
		return false
	# Climbing faces dig the nose — that is alignment work, not a lip launch.
	if _is_climbing(_downhill_dir(), _board_forward_on_ground()):
		return false
	if velocity.slide(_ground_normal).length() < CREST_LIP_MIN_SPEED:
		return false
	if _slope_grade() < CREST_LIP_MIN_GRADE:
		return false

	var probes := _crest_board_clearances()
	if is_nan(probes.x) or is_nan(probes.y) or is_nan(probes.z):
		return false
	# Nose/ahead see a void (higher clearance) while the board still has support under center/tail.
	var nose_air := probes.y - probes.x
	if nose_air < CREST_LIP_AHEAD_DROP:
		return false
	if probes.x > GliderPhysicsScript.HOVER_ZONE:
		return false
	# Tail still on the hill while the nose hangs over the lip.
	return probes.y - probes.z >= CREST_LIP_NOSE_DROP


func _detach_from_crest_lip() -> void:
	_airborne_time = 0.0
	_state = State.GLIDING
	_align_yaw_to_travel_direction(1.0)


func _land() -> void:
	var ctx := _build_touchdown_context()
	var result := GliderPhysicsScript.apply_touchdown(ctx, is_braking())
	velocity = result.velocity
	_state = State.GROUNDED
	var raw := _get_raw_clearance()
	_smoothed_clearance = raw
	_prev_raw_clearance = raw
	_landing_stabilize_timer = LANDING_STABILIZE_DURATION
	_grounded_lock_timer = GROUNDED_LOCK_DURATION
	var keep: float = result.get("keep", 1.0)
	if keep < 0.995:
		_landing_feedback_timer = LANDING_FEEDBACK_DURATION
		_landing_feedback_label = "HEAVY"
	else:
		_landing_feedback_timer = 0.0
		_landing_feedback_label = ""
	_play_touchdown_juice(result.approach, keep)


func _play_touchdown_juice(approach: float, keep: float) -> void:
	if approach < 3.0 and keep >= 0.995:
		return
	if _impact_dust != null:
		_impact_dust.restart()
		_impact_dust.emitting = true
	if keep < 0.995 and _contact_sparks != null:
		_contact_sparks.restart()
		_contact_sparks.emitting = true


func _apply_steering(delta: float) -> void:
	var air := _state == State.GLIDING
	var axis := Vector3.UP if air else _ground_normal
	var steer := _input.get_steer()
	var boost := _is_boost_active()
	var air_scale := AIR_STEER_SCALE if air else 1.0
	var mul := steering_mul(_steering_bonus())
	var turn_rate_max := (BOOST_TURN_RATE if boost else SAIL_TURN_RATE) * mul * air_scale
	var grip_rate := (BOOST_STEER_GRIP_RATE if boost else SAIL_STEER_GRIP_RATE) * mul * air_scale

	var target_turn_rate := -steer * turn_rate_max if absf(steer) > 0.01 else 0.0
	_turn_rate = lerpf(_turn_rate, target_turn_rate, TURN_RESPONSE * delta)
	var turn := _turn_rate * delta

	if absf(turn) > 0.0001:
		_yaw += turn
		_yaw_velocity = lerpf(_yaw_velocity, _turn_rate, 4.5 * delta)
	else:
		_yaw_velocity = lerpf(_yaw_velocity, 0.0, YAW_DAMPING * delta)
	_yaw_velocity = clampf(_yaw_velocity, -MAX_YAW_VELOCITY, MAX_YAW_VELOCITY)

	var planar_vel := _horizontal_velocity() if air else velocity.slide(_ground_normal)
	var nose := _flat_yaw_forward()
	if not air:
		var slid := nose.slide(_ground_normal)
		if slid.length_squared() > 0.0001:
			nose = slid.normalized()

	var speed := planar_vel.length()
	var planar_changed := false
	if absf(turn) > 0.0001 and speed > MIN_STEER_SPEED:
		var grip := clampf(grip_rate * delta, 0.0, 1.0)
		planar_vel = planar_vel.lerp(nose * speed, grip)
		planar_changed = true

	if planar_changed:
		if air:
			velocity.x = planar_vel.x
			velocity.z = planar_vel.z
		else:
			velocity = planar_vel + axis * velocity.dot(axis)


func _travel_direction() -> Vector3:
	if _state == State.GLIDING:
		return _horizontal_velocity()
	return velocity.slide(_ground_normal)


func _align_yaw_to_travel_direction(blend: float) -> void:
	var travel := _travel_direction()
	if travel.length_squared() < 0.01:
		return
	var flat := Vector3(travel.x, 0.0, travel.z)
	if flat.length_squared() < 0.01:
		return
	_yaw = lerp_angle(_yaw, _yaw_from_horizontal(flat), blend)


func _update_orientation(delta: float) -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	_update_visual_tilt(delta)


func _align_air_attitude() -> Vector3:
	var up := Vector3.UP
	if velocity.length_squared() > 4.0:
		var vel_dir := velocity.normalized()
		var pitch_amount := clampf(-vel_dir.y, -0.2, 0.85) * AIR_VELOCITY_PITCH_BLEND
		up = _slerp_normal(Vector3.UP, vel_dir, pitch_amount)
	return up


func _deck_world_up() -> Vector3:
	if _state == State.GROUNDED:
		if _predictive_pitch_normal.length_squared() > 0.0001:
			return _slerp_normal(
				_ground_normal,
				_predictive_pitch_normal,
				_deck_plane_blend()
			)
		return _ground_normal
	return _slerp_normal(_align_air_attitude(), _ground_normal, _smoothed_predict_blend)


func _build_deck_world_basis(world_up: Vector3, bank: float) -> Basis:
	var up := world_up
	if up.dot(Vector3.UP) < 0.0:
		up = -up

	var forward := _flat_yaw_forward().slide(up)
	if forward.length_squared() < 0.0001:
		forward = MathUtil.yaw_forward(_yaw).slide(up)
	forward = forward.normalized()
	var right := up.cross(forward).normalized()
	forward = right.cross(up).normalized()

	var basis := Basis(right, up, forward).orthonormalized()
	if absf(bank) > 0.0001:
		basis = Basis(Quaternion(forward, bank)) * basis
	return basis


func _sync_visual_basis_from_ground() -> void:
	if _visual == null:
		_smoothed_visual_basis = Basis.IDENTITY
		return
	var target_world := _build_deck_world_basis(_ground_normal, 0.0)
	_smoothed_visual_basis = Basis.from_euler(Vector3(0.0, -_yaw, 0.0)) * target_world
	_visual.basis = _smoothed_visual_basis


func _deck_forward_from_basis(deck_world: Basis) -> Vector3:
	return deck_world.z.normalized()


func _update_visual_tilt(delta: float) -> void:
	if _visual == null:
		return

	var bank := clampf(-_yaw_velocity / MAX_YAW_VELOCITY, -1.0, 1.0) * deg_to_rad(BANK_ANGLE)
	if _state == State.GROUNDED and (_input == null or not _input.is_steering()):
		var travel := _travel_direction()
		var travel_flat := Vector3(travel.x, 0.0, travel.z)
		var forward_flat := Vector3(_flat_yaw_forward().x, 0.0, _flat_yaw_forward().z)
		if travel_flat.length_squared() > 1.0 and forward_flat.length_squared() > 0.01:
			forward_flat = forward_flat.normalized()
			travel_flat = travel_flat.normalized()
			var signed_misalign := forward_flat.cross(travel_flat).y
			var misalign_angle := atan2(signed_misalign, forward_flat.dot(travel_flat))
			if absf(misalign_angle) >= deg_to_rad(SLIDE_BANK_MIN_MISALIGN_DEG):
				bank += clampf(misalign_angle / PI, -1.0, 1.0) * deg_to_rad(SLIDE_BANK_ANGLE)

	var target_world := _build_deck_world_basis(_deck_world_up(), bank)
	var target_basis := Basis.from_euler(Vector3(0.0, -_yaw, 0.0)) * target_world
	var rise_lead := _ahead_rise_lead() if _state == State.GROUNDED else 0.0
	var tilt_rate := lerpf(VISUAL_TILT_RATE, VISUAL_TILT_RATE * 1.75, rise_lead)
	var visual_step_deg := lerpf(
		VISUAL_ALIGN_MAX_STEP_DEG,
		AHEAD_RISE_VISUAL_ALIGN_MAX_STEP_DEG,
		rise_lead
	)

	_smoothed_visual_basis = _slerp_basis_capped(
		_smoothed_visual_basis,
		target_basis,
		clampf(tilt_rate * delta, 0.0, 1.0),
		deg_to_rad(visual_step_deg)
	)
	_visual.basis = _smoothed_visual_basis

	var deck_world := Basis.from_euler(Vector3(0.0, _yaw, 0.0)) * _smoothed_visual_basis
	var deck_forward := _deck_forward_from_basis(deck_world)
	var raw_pitch := asin(clampf(-deck_forward.y, -1.0, 1.0))
	var raw_roll := atan2(deck_forward.x, deck_forward.z)
	var pitch_step := clampf(BOARD_PITCH_RATE * delta, 0.0, 1.0)
	_board_pitch = lerpf(_board_pitch, raw_pitch, pitch_step)
	_board_roll = lerpf(_board_roll, raw_roll, pitch_step)


func _build_physics_context() -> GliderPhysicsScript.Context:
	var ctx := GliderPhysicsScript.Context.new()
	var raw_clearance := _get_raw_clearance()

	ctx.velocity = velocity
	ctx.ground_normal = _ground_normal
	ctx.board_forward = _board_forward_on_ground()
	ctx.clearance = _smoothed_clearance
	## Trust raw when already above rest — lagged smoothed clearance invents
	## phantom compression after crests (ground drops, smoothed still low) and
	## pushes the board further up. Only blend smoothed in while compressed.
	if raw_clearance >= GliderPhysicsScript.BASE_HEIGHT:
		ctx.hover_clearance = raw_clearance
	else:
		ctx.hover_clearance = minf(_smoothed_clearance, raw_clearance)
	if _state == State.GROUNDED:
		var board_min := _min_board_probe_clearance()
		var climbing := _is_climbing(_downhill_dir(), ctx.board_forward)
		if climbing:
			var deck_min := _live_min_deck_probe_clearance()
			var underside := minf(board_min, deck_min)
			ctx.hover_clearance = underside
			ctx.clearance = minf(_smoothed_clearance, underside)
		elif (
			_is_boost_climb_active()
			or raw_clearance - board_min <= CLEARANCE_PROBE_TRIGGER
		):
			ctx.hover_clearance = minf(ctx.hover_clearance, board_min)
	ctx.clearance_change_rate = _clearance_change_rate
	ctx.downhill = _downhill_dir()
	ctx.slope_grade = _slope_grade()
	ctx.climbing = _is_climbing(ctx.downhill, ctx.board_forward)
	ctx.forward_held = _input.is_forward_held()
	ctx.sail_deployed = is_sail_deployed()
	ctx.boost_active = _is_boost_active()
	ctx.thrust_forward = ctx.board_forward
	ctx.braking = is_braking()
	ctx.brake_strength = _brake_strength()
	ctx.coast_blend = _coast_blend()
	ctx.hover_at_rest = _is_hover_at_rest()
	ctx.steering = _input != null and _input.is_steering()
	ctx.strafe = _input.get_strafe() if _input != null else 0.0
	if _state == State.GLIDING:
		ctx.air_gravity_scale = smoothstep(
			0.0,
			GliderPhysicsScript.AIR_GRAVITY_RAMP_DURATION,
			_airborne_time
		)
	else:
		ctx.air_gravity_scale = 1.0
	ctx.thruster_accel = _thruster_accel(ctx.forward_held)
	ctx.air_thruster_accel = ctx.thruster_accel * GliderPhysicsScript.AIR_BOOST_EXTRA_SCALE
	ctx.speed_bonus = _glider_speed_bonus()
	ctx.momentum_retention = _momentum_retention()
	ctx.glide_bonus = _glide_bonus()
	return ctx


func _glider_speed_bonus() -> float:
	var state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state == null:
		return 0.0
	return state.glider_speed_bonus


func _momentum_retention() -> float:
	var state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state == null:
		return 0.0
	return clampf(state.momentum_retention, 0.0, UpgradeCatalog.MOMENTUM_RETENTION_CAP)


func _glide_bonus() -> float:
	var state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state == null:
		return 0.0
	return clampf(state.glide_bonus, 0.0, UpgradeCatalog.GLIDE_CAP)


func _steering_bonus() -> float:
	var state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state == null:
		return 0.0
	return clampf(state.steering_bonus, 0.0, UpgradeCatalog.STEERING_CAP)


func _build_touchdown_context() -> GliderPhysicsScript.Context:
	var ctx := _build_physics_context()
	ctx.ground_normal = _smoothed_center_normal
	return ctx


func _board_forward_on_ground() -> Vector3:
	var forward := _flat_yaw_forward().slide(_ground_normal)
	if forward.length_squared() < 0.01:
		return _travel_direction().slide(_ground_normal).normalized()
	return forward.normalized()


func _downhill_dir() -> Vector3:
	return TerrainQuery.downhill_dir(_terrain_manager, global_position.x, global_position.z)


func _slope_grade() -> float:
	return _ground_normal.angle_to(Vector3.UP)


func _is_climbing(downhill: Vector3, forward: Vector3) -> bool:
	if downhill == Vector3.ZERO or _slope_grade() < GliderPhysicsScript.CLIMB_DRAG_MIN_GRADE:
		return false
	var facing := forward
	if _input != null and _input.is_steering():
		var tangent := velocity.slide(_ground_normal)
		if tangent.length_squared() > 0.25:
			facing = tangent.normalized()
	return facing.dot(downhill) < GliderPhysicsScript.CLIMB_FACING_THRESHOLD


func _is_hover_at_rest() -> bool:
	if _state != State.GROUNDED:
		return false
	if _input.is_forward_held() or _is_boost_active() or is_braking():
		return false
	return velocity.slide(_ground_normal).length() <= HOVER_IDLE_SETTLE_SPEED


func _update_charge(delta: float) -> void:
	if _run_ended:
		return
	if _is_boost_active():
		_charge = maxf(_charge - CHARGE_BOOST_DRAIN * delta, 0.0)
		if _charge <= 0.0:
			_overheat_timer = THRUSTER_OVERHEAT_DURATION
		return
	var solar := CHARGE_SOLAR_RECHARGE * delta
	if _is_daytime():
		if _charge < CHARGE_MAX:
			_charge = minf(_charge + solar, CHARGE_MAX)
		else:
			_battery = minf(_battery + solar, BATTERY_MAX)
		return
	if _battery > 0.0 and _charge < CHARGE_MAX:
		var transfer := minf(solar, _battery)
		transfer = minf(transfer, CHARGE_MAX - _charge)
		_battery -= transfer
		_charge += transfer


func _update_overheat(delta: float) -> void:
	if _overheat_timer > 0.0:
		_overheat_timer = maxf(_overheat_timer - delta, 0.0)


func _update_coast(delta: float) -> void:
	if _coast_timer > 0.0 and not _input.is_forward_held() and not _is_boost_active():
		_coast_timer = maxf(_coast_timer - delta, 0.0)
	elif not _input.is_forward_held() and not _is_boost_active() and velocity.slide(_ground_normal).length() > 1.0:
		_coast_timer = COAST_DURATION


func _update_brake_ramp(delta: float) -> void:
	if is_braking():
		_brake_hold_time = minf(_brake_hold_time + delta, BRAKE_RAMP_SEC)
	else:
		_brake_hold_time = 0.0


func _update_landing_feedback(delta: float) -> void:
	if _landing_feedback_timer > 0.0:
		_landing_feedback_timer = maxf(_landing_feedback_timer - delta, 0.0)
	if _landing_stabilize_timer > 0.0:
		_landing_stabilize_timer = maxf(_landing_stabilize_timer - delta, 0.0)
	if _grounded_lock_timer > 0.0:
		_grounded_lock_timer = maxf(_grounded_lock_timer - delta, 0.0)


func _update_contact_dust() -> void:
	if _contact_dust == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var min_clearance := _min_board_probe_clearance()
	var scraping := min_clearance <= GliderPhysicsScript.HOVER_COMPRESS_START
	_contact_dust.emitting = _state == State.GROUNDED and speed > 1.5 and scraping


func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	_camera.follow(
		self, _yaw, velocity, delta,
		is_grounded(), _terrain_manager,
		_input != null and _input.is_steering(),
		_is_boost_active()
	)


func _flat_yaw_forward() -> Vector3:
	return MathUtil.yaw_forward(_yaw)


func _horizontal_velocity() -> Vector3:
	return MathUtil.horizontal(velocity)


func _yaw_from_horizontal(horizontal: Vector3) -> float:
	return atan2(horizontal.x, horizontal.z)


func _coast_blend() -> float:
	if _coast_timer > 0.0:
		return clampf(_coast_timer / COAST_DURATION, 0.0, 1.0)
	return 0.0


func _brake_strength() -> float:
	if is_braking():
		var t := clampf(_brake_hold_time / BRAKE_RAMP_SEC, 0.0, 1.0)
		return t * t
	return 0.0


func _thruster_accel(forward_held: bool) -> float:
	var base := GliderPhysicsScript.CRUISE_GROUND_ACCEL * BOOST_MULTIPLIER
	return base if forward_held else base * 0.65


func _is_boost_active() -> bool:
	return _boost_unlocked and _input != null and _input.is_boost_held() and has_propulsion() and not is_overheated()


func _is_boost_climb_active() -> bool:
	if _is_boost_active():
		return true
	if not _is_climbing(_downhill_dir(), _board_forward_on_ground()):
		return false
	return _horizontal_velocity().length() >= AHEAD_NORMAL_MIN_SPEED


func _resolve_input() -> GliderInputScript:
	var input := get_node_or_null("GliderInput") as GliderInputScript
	if input != null:
		return input
	var parent := get_parent()
	if parent != null:
		return parent.get_node_or_null("GliderInput") as GliderInputScript
	return null


func _uses_external_camera() -> bool:
	return get_parent() is PlayerRig


# --- Public API ---

func is_grounded() -> bool:
	return _state == State.GROUNDED


func is_gliding() -> bool:
	return _state == State.GLIDING


func is_landing() -> bool:
	return _landing_stabilize_timer > 0.0


func consume_jump_anim_trigger() -> bool:
	if not _jump_anim_pending:
		return false
	_jump_anim_pending = false
	return true


func consume_boost_anim_trigger() -> bool:
	if not _boost_anim_pending:
		return false
	_boost_anim_pending = false
	return true


func consume_brake_anim_trigger() -> bool:
	if not _brake_anim_pending:
		return false
	_brake_anim_pending = false
	return true


func is_boost_active() -> bool:
	return _is_boost_active()


func is_forward_held() -> bool:
	return _input != null and _input.is_forward_held()


func get_horizontal_speed() -> float:
	return _horizontal_velocity().length()


func get_steer_axis() -> float:
	if _input == null:
		return 0.0
	return clampf(_input.get_steer(), -1.0, 1.0)


func get_anim_steer() -> float:
	return get_steer_axis()


func is_run_ended() -> bool:
	return _run_ended


## Swarm / hazard shove. Applied after surf constraints so ground surf doesn't wipe it
## the same tick. Air W/boost hold re-locks XZ afterward so knockback cannot ratchet air speed.
func queue_knockback(velocity_delta: Vector3) -> void:
	if _run_ended or not _piloted:
		return
	_pending_knockback += velocity_delta


func _apply_pending_knockback(state: PhysicsDirectBodyState3D) -> void:
	if _pending_knockback.length_squared() < 0.0001:
		return
	state.linear_velocity += _pending_knockback
	_pending_knockback = Vector3.ZERO


func end_run(reason: String = "") -> void:
	if _run_ended:
		return
	_end_reason = reason
	_run_ended = true
	linear_velocity = Vector3.ZERO
	_yaw_velocity = 0.0
	_turn_rate = 0.0
	angular_velocity = Vector3.ZERO
	run_ended.emit()


func reset_for_respawn() -> void:
	_run_ended = false
	_end_reason = ""
	_state = State.GROUNDED
	velocity = Vector3.ZERO
	_pending_knockback = Vector3.ZERO
	_yaw_velocity = 0.0
	_turn_rate = 0.0
	_charge = CHARGE_MAX
	_battery = 0.0
	_overheat_timer = 0.0
	_coast_timer = 0.0
	_brake_hold_time = 0.0
	_landing_feedback_timer = 0.0
	_landing_stabilize_timer = 0.0
	_grounded_lock_timer = 0.0
	_airborne_time = 0.0
	_jump_cooldown = 0.0
	_jump_anim_pending = false
	_boost_anim_pending = false
	_was_boost_active = false
	_brake_anim_pending = false
	_was_brake_active = false
	_air_hold_horizontal_speed = 0.0
	_hull_integrity = 1.0
	_landing_feedback_label = ""
	if _terrain_manager != null:
		var spawn_x := global_position.x
		var spawn_z := global_position.z
		var spawn_y := (
			_terrain_manager.sample_height(spawn_x, spawn_z)
			+ GliderPhysicsScript.BASE_HEIGHT
			+ 0.05
		)
		teleport_to(Vector3(spawn_x, spawn_y, spawn_z), _yaw)
		_ground_normal = _terrain_manager.sample_normal(spawn_x, spawn_z)
		_smoothed_predictive_normal = _ground_normal
		_smoothed_center_normal = _ground_normal
		_smoothed_pitch_normal = _ground_normal
		_smoothed_clearance = _get_raw_clearance()
		_prev_raw_clearance = _smoothed_clearance
		_sync_visual_basis_from_ground()
	_reset_animation_controllers()


func _reset_animation_controllers() -> void:
	var skin := get_node_or_null("Visual/GliderSkin")
	if skin == null:
		return
	var body_anim := skin.get_node_or_null("GliderAnimController")
	if body_anim != null and body_anim.has_method("reset_animation_state"):
		body_anim.reset_animation_state()
	var sail_anim := skin.get_node_or_null("SailAnimController")
	if sail_anim != null and sail_anim.has_method("reset_animation_state"):
		sail_anim.reset_animation_state()


## RigidBody3D teleports must sync PhysicsServer or the body snaps back next tick.
func teleport_to(world_pos: Vector3, yaw: float) -> void:
	_yaw = yaw
	_yaw_velocity = 0.0
	_turn_rate = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var xf := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), world_pos)
	global_transform = xf
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer3D.body_set_state(
		get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO
	)
	PhysicsServer3D.body_set_state(
		get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO
	)


func get_end_reason() -> String:
	return _end_reason


func is_piloted() -> bool:
	return _piloted


func set_piloted(active: bool) -> void:
	_piloted = active
	if active:
		collision_layer = _saved_collision_layer
	else:
		_saved_collision_layer = collision_layer
		collision_layer = 0


func get_clearance() -> float:
	return _get_clearance()


func get_raw_clearance() -> float:
	return _get_raw_clearance()


func get_smoothed_clearance() -> float:
	return _smoothed_clearance


func get_yaw() -> float:
	return _yaw


func get_yaw_velocity() -> float:
	return _yaw_velocity


func get_board_pitch() -> float:
	return _board_pitch


func get_board_roll() -> float:
	return _board_roll


func get_deck_world_basis() -> Basis:
	return Basis.from_euler(Vector3(0.0, _yaw, 0.0)) * _smoothed_visual_basis


func get_predictive_normal() -> Vector3:
	return _smoothed_predictive_normal


func get_predictive_pitch_normal() -> Vector3:
	return _predictive_pitch_normal


func get_predictive_align_blend() -> float:
	return _smoothed_predict_blend


func get_base_height_offset() -> float:
	return 0.0


func get_camera_air_blend() -> float:
	return clampf(
		(_get_clearance() - GliderPhysicsScript.BASE_HEIGHT)
		/ maxf(GliderPhysicsScript.GLIDE_ENTER_HEIGHT - GliderPhysicsScript.BASE_HEIGHT, 0.01),
		0.0, 1.0
	)


func get_charge_ratio() -> float:
	return _charge / CHARGE_MAX


func get_battery_ratio() -> float:
	return _battery / BATTERY_MAX


func get_power_ratio() -> float:
	return get_charge_ratio()


func is_solar_charging() -> bool:
	if _run_ended or _is_boost_active() or not _is_daytime():
		return false
	return _charge < CHARGE_MAX or _battery < BATTERY_MAX


func is_sail_deployed() -> bool:
	return _input != null and _input.is_sail_deployed()


func is_boost_unlocked() -> bool:
	return _boost_unlocked


func set_boost_unlocked(enabled: bool) -> void:
	_boost_unlocked = enabled
	if _input != null:
		_input.set_boost_input_enabled(enabled)


func is_boost_available() -> bool:
	return has_propulsion() and _charge > CHARGE_MIN_BOOST


func has_propulsion() -> bool:
	return _charge > 0.0 and not is_overheated() and not _run_ended


func is_overheated() -> bool:
	return _overheat_timer > 0.0


func get_overheat_cooldown_ratio() -> float:
	if is_overheated():
		return clampf(_overheat_timer / THRUSTER_OVERHEAT_DURATION, 0.0, 1.0)
	return 0.0


func is_braking() -> bool:
	return _input != null and _input.is_brake_held()


func _is_daytime() -> bool:
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night_cycle") as DayNightCycle
	if _day_night == null:
		return true
	return not _day_night.is_night()


func get_landing_feedback() -> Dictionary:
	return {"timer": _landing_feedback_timer, "label": _landing_feedback_label}


func get_hull_integrity() -> float:
	return _hull_integrity
