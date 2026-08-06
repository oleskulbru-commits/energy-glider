class_name GliderCamera
extends Camera3D

const SURF_CAMERA_HEIGHT := 1.0
const SURF_CAMERA_DISTANCE := 7.5
const GLIDE_CAMERA_HEIGHT := 2.2
const GLIDE_CAMERA_DISTANCE := 10.0
const SURF_LOOK_HEIGHT := 1.6
const GLIDE_LOOK_HEIGHT := 2.4
const LOOK_AHEAD_DISTANCE := 16.0
const LOOK_AHEAD_BLEND := 0.35
const CAMERA_PIVOT_HEIGHT := 0.9
const CAMERA_POS_RATE := 4.5
const CAMERA_BLEND_RATE := 4.0
const FOCUS_RATE_XZ := 10.0
const FOCUS_RATE_Y := 7.0
const LOOK_RATE := 3.5
const VERTICAL_LEAD := 0.04
const CLEARANCE_FOCUS_BLEND := 0.06
const MIN_CAMERA_GROUND_CLEARANCE := 1.2
const MIN_CAMERA_ARM_LENGTH := 4.0
const CAMERA_COLLISION_BACKOFF := 0.6
const MIN_VELOCITY_YAW_SPEED := 1.5
const CAMERA_FOV := 78.0
const CAMERA_FOV_SPEED_BOOST := 6.0
const SPEED_ARM_REF := 22.0
const SPEED_ARM_SCALE_MAX := 1.18
const SPEED_BLEND_START := 5.0
const SPEED_BLEND_END := 18.0
const MAX_VELOCITY_YAW_BLEND := 0.65
const STEER_VELOCITY_YAW_BLEND := 0.3
const CRUISE_CHASE_STIFFNESS := 6.0
const STEER_CHASE_STIFFNESS := 3.5
const CHASE_DAMPING := 5.5
const STEER_LAG_SCALE := 0.6
const MAX_BANK_ANGLE := 7.0
const BANK_RATE := 3.5
const FOLLOW_PITCH_RATE := 6.5
const GROUND_PITCH_FOLLOW := 0.92
const AIR_PITCH_FOLLOW := 0.78
const PITCH_VELOCITY_BLEND := 0.32
const MAX_FOLLOW_PITCH_DEG := 24.0
const FOV_RATE := 4.0

const FOOT_CAMERA_HEIGHT := 1.2
const FOOT_CAMERA_DISTANCE := 5.0
const FOOT_LOOK_HEIGHT := 1.0
const FOOT_PIVOT_HEIGHT := 0.9
const MOUSE_YAW_SENSITIVITY := 0.0022
const MOUSE_PITCH_SENSITIVITY := 0.0018
const MAX_LOOK_PITCH_DEG := 35.0
const MAX_LOOK_YAW_OFFSET_DEG := 90.0
const LOOK_OFFSET_SPRING := 8.0
const LOOK_OFFSET_DAMPING := 6.0
const LOOK_RECENTER_DELAY := 1.0
const LOOK_RECENTER_RAMP_TIME := 1.4
const LOOK_STEER_RECENTER_SCALE := 0.45
const LOOK_SPEED_RECENTER_REF := 18.0

var _blend := 0.0
var _foot_blend := 0.0
var _focus := Vector3.ZERO
var _look_focus := Vector3.ZERO
var _focus_initialized := false
var _bank_angle := 0.0
var _chase_yaw := 0.0
var _chase_yaw_velocity := 0.0
var _chase_initialized := false
var _follow_pitch := 0.0
var _look_yaw_offset := 0.0
var _look_pitch_offset := 0.0
var _look_offset_yaw_velocity := 0.0
var _look_offset_pitch_velocity := 0.0
var _mouse_look_enabled := true
var _look_idle_time := 0.0
var _fov_blend := 0.0
var _hard_snap := false


func _ready() -> void:
	top_level = true
	current = true
	fov = CAMERA_FOV


func follow(
	target: Node3D,
	yaw: float,
	velocity: Vector3,
	delta: float,
	clearance: float = 0.0,
	grounded: bool = true,
	terrain_manager: TerrainManager = null,
	yaw_velocity: float = 0.0,
	foot_mode: bool = false,
	air_blend: float = -1.0,
	steering: bool = false
) -> void:
	var snap := _hard_snap
	_hard_snap = false

	var foot_target := 1.0 if foot_mode else 0.0
	var blend_t := 1.0 if snap else clampf(CAMERA_BLEND_RATE * delta, 0.0, 1.0)
	_foot_blend = lerpf(_foot_blend, foot_target, blend_t)

	var target_blend := 0.0 if grounded else 1.0
	if air_blend >= 0.0:
		target_blend = clampf(air_blend, 0.0, 1.0)
	_blend = lerpf(_blend, target_blend, blend_t)

	var surf_height := lerpf(GLIDE_CAMERA_HEIGHT, SURF_CAMERA_HEIGHT, _blend)
	var surf_distance := lerpf(GLIDE_CAMERA_DISTANCE, SURF_CAMERA_DISTANCE, _blend)
	var surf_look := lerpf(GLIDE_LOOK_HEIGHT, SURF_LOOK_HEIGHT, _blend)
	var camera_height := lerpf(surf_height, FOOT_CAMERA_HEIGHT, _foot_blend)
	var camera_distance := lerpf(surf_distance, FOOT_CAMERA_DISTANCE, _foot_blend)
	var look_height := lerpf(surf_look, FOOT_LOOK_HEIGHT, _foot_blend)
	var pivot_height := lerpf(CAMERA_PIVOT_HEIGHT, FOOT_PIVOT_HEIGHT, _foot_blend)

	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_vel.length()
	var speed_t := clampf(speed / SPEED_ARM_REF, 0.0, 1.0)
	camera_distance *= lerpf(1.0, SPEED_ARM_SCALE_MAX, speed_t)

	var player_pos := target.global_position
	var focus_lift := lerpf(
		clearance * CLEARANCE_FOCUS_BLEND,
		velocity.y * VERTICAL_LEAD,
		clampf(_blend, 0.0, 1.0)
	)
	player_pos.y += focus_lift
	var pivot := player_pos + Vector3(0.0, pivot_height, 0.0)

	if snap or not _focus_initialized:
		_focus = pivot
		_look_focus = pivot + Vector3(0.0, look_height, 0.0)
		_focus_initialized = true

	var xz_rate := 1.0 if snap else clampf(FOCUS_RATE_XZ * delta, 0.0, 1.0)
	var y_rate := 1.0 if snap else clampf(FOCUS_RATE_Y * delta, 0.0, 1.0)
	_focus.x = lerpf(_focus.x, pivot.x, xz_rate)
	_focus.z = lerpf(_focus.z, pivot.z, xz_rate)
	_focus.y = lerpf(_focus.y, pivot.y, y_rate)

	if snap or not _chase_initialized:
		_chase_yaw = yaw
		_chase_yaw_velocity = 0.0
		_chase_initialized = true

	if foot_mode:
		_chase_yaw = yaw if snap else lerp_angle(_chase_yaw, yaw, clampf(10.0 * delta, 0.0, 1.0))
		_chase_yaw_velocity = 0.0
		if not snap:
			_decay_look_offsets(horizontal_vel, steering, delta)
	else:
		if _mouse_look_enabled and not snap:
			_decay_look_offsets(horizontal_vel, steering, delta)
		if snap:
			_chase_yaw = yaw
			_chase_yaw_velocity = 0.0
		else:
			var chase_target := _compute_chase_target_yaw(yaw, horizontal_vel, steering)
			_update_chase_yaw(chase_target, speed, steering, delta)

	var aim_yaw := _chase_yaw + _look_yaw_offset
	var boom_forward := MathUtil.yaw_forward(aim_yaw)
	var boom_right := Vector3.UP.cross(boom_forward).normalized()

	if foot_mode:
		_follow_pitch = _look_pitch_offset
	elif snap:
		_follow_pitch = 0.0
	else:
		_update_follow_pitch(target, velocity, grounded, foot_mode, delta)

	var boom_pitch := _follow_pitch
	var pitched_up := Vector3.UP.rotated(boom_right, boom_pitch).normalized()
	var arm := -boom_forward * camera_distance + pitched_up * camera_height

	var desired_pos := pivot + arm
	desired_pos = _resolve_camera_collision(pivot, desired_pos, target)
	desired_pos = _enforce_camera_floor(desired_pos, terrain_manager)

	var pos_t := 1.0 if snap else clampf(CAMERA_POS_RATE * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired_pos, pos_t)
	_snap_camera_above_floor(terrain_manager)

	var aim_forward := boom_forward
	var low_speed_blend := 1.0 - clampf(
		(speed - MIN_VELOCITY_YAW_SPEED) / maxf(SPEED_BLEND_END - SPEED_BLEND_START, 0.001),
		0.0,
		1.0
	)
	var lead_dir := aim_forward
	if speed > MIN_VELOCITY_YAW_SPEED:
		var velocity_dir := horizontal_vel / speed
		lead_dir = velocity_dir.lerp(aim_forward, low_speed_blend).normalized()

	var look_pitch := _follow_pitch + _look_pitch_offset * 0.35
	var look_forward := aim_forward.rotated(boom_right, look_pitch * 0.7).normalized()
	var look_target := _focus + lead_dir * LOOK_AHEAD_DISTANCE + pitched_up * look_height
	if _blend > 0.01 and terrain_manager != null:
		var ahead_x := _focus.x + lead_dir.x * LOOK_AHEAD_DISTANCE
		var ahead_z := _focus.z + lead_dir.z * LOOK_AHEAD_DISTANCE
		var ahead_y := terrain_manager.sample_height(ahead_x, ahead_z)
		var ground_ahead := Vector3(ahead_x, ahead_y + 0.5, ahead_z)
		look_target = look_target.lerp(ground_ahead, _blend * LOOK_AHEAD_BLEND)

	var look_t := 1.0 if snap else clampf(LOOK_RATE * delta, 0.0, 1.0)
	_look_focus = _look_focus.lerp(look_target, look_t)

	var bank_scale := lerpf(1.0, 1.35, speed_t)
	var target_bank := 0.0
	if _foot_blend <= 0.5:
		target_bank = clampf(-yaw_velocity * 2.0, -1.0, 1.0) * MAX_BANK_ANGLE * bank_scale
	var bank_t := 1.0 if snap else clampf(BANK_RATE * delta, 0.0, 1.0)
	_bank_angle = lerpf(_bank_angle, target_bank, bank_t)
	_apply_look_with_bank(_look_focus, _bank_angle)

	var target_fov_blend := speed_t if _foot_blend < 0.5 else 0.0
	var fov_t := 1.0 if snap else clampf(FOV_RATE * delta, 0.0, 1.0)
	_fov_blend = lerpf(_fov_blend, target_fov_blend, fov_t)
	fov = lerpf(CAMERA_FOV, CAMERA_FOV + CAMERA_FOV_SPEED_BOOST, _fov_blend)


func get_follow_yaw() -> float:
	return _get_aim_yaw()


func get_forward_flat() -> Vector3:
	return MathUtil.yaw_forward(_get_aim_yaw())


func apply_look_input(rel_x: float, rel_y: float) -> void:
	if not _mouse_look_enabled:
		return
	_look_idle_time = 0.0
	_look_yaw_offset -= rel_x * MOUSE_YAW_SENSITIVITY
	_look_pitch_offset -= rel_y * MOUSE_PITCH_SENSITIVITY
	var max_pitch := deg_to_rad(MAX_LOOK_PITCH_DEG)
	_look_pitch_offset = clampf(_look_pitch_offset, -max_pitch, max_pitch)
	var max_yaw := deg_to_rad(MAX_LOOK_YAW_OFFSET_DEG)
	_look_yaw_offset = clampf(_look_yaw_offset, -max_yaw, max_yaw)


func set_mouse_look_enabled(enabled: bool) -> void:
	_mouse_look_enabled = enabled


func is_mouse_look_enabled() -> bool:
	return _mouse_look_enabled


func snap_follow_yaw(yaw: float) -> void:
	_chase_yaw = yaw
	_chase_yaw_velocity = 0.0
	_look_yaw_offset = 0.0
	_look_pitch_offset = 0.0
	_look_offset_yaw_velocity = 0.0
	_look_offset_pitch_velocity = 0.0
	_chase_initialized = true
	_look_idle_time = 0.0


func request_hard_snap() -> void:
	_hard_snap = true


func reset_follow_state() -> void:
	_focus_initialized = false
	_chase_initialized = false
	_blend = 0.0
	_foot_blend = 0.0
	_bank_angle = 0.0
	_follow_pitch = 0.0
	_chase_yaw_velocity = 0.0
	_look_yaw_offset = 0.0
	_look_pitch_offset = 0.0
	_look_offset_yaw_velocity = 0.0
	_look_offset_pitch_velocity = 0.0
	_look_idle_time = 0.0
	_fov_blend = 0.0
	fov = CAMERA_FOV


static func angle_diff(from_yaw: float, to_yaw: float) -> float:
	return MathUtil.angle_diff(from_yaw, to_yaw)


static func step_chase_yaw(
	chase_yaw: float,
	chase_yaw_velocity: float,
	target_yaw: float,
	delta: float,
	stiffness: float,
	damping: float
) -> Dictionary:
	var yaw_error := angle_diff(chase_yaw, target_yaw)
	var next_velocity := chase_yaw_velocity + yaw_error * stiffness * delta
	next_velocity *= exp(-damping * delta)
	var next_yaw := chase_yaw + next_velocity * delta
	return {
		"chase_yaw": next_yaw,
		"chase_yaw_velocity": next_velocity,
	}


func _get_aim_yaw() -> float:
	return _chase_yaw + _look_yaw_offset


func _compute_chase_target_yaw(body_yaw: float, horizontal_vel: Vector3, steering: bool) -> float:
	var speed := horizontal_vel.length()
	if speed <= MIN_VELOCITY_YAW_SPEED:
		return body_yaw

	var velocity_yaw := atan2(horizontal_vel.x, horizontal_vel.z)
	var speed_blend := clampf(
		(speed - SPEED_BLEND_START) / maxf(SPEED_BLEND_END - SPEED_BLEND_START, 0.001),
		0.0,
		1.0
	)
	var max_blend := MAX_VELOCITY_YAW_BLEND if not steering else STEER_VELOCITY_YAW_BLEND
	return lerp_angle(body_yaw, velocity_yaw, speed_blend * max_blend)


func _update_chase_yaw(target_yaw: float, speed: float, steering: bool, delta: float) -> void:
	var cruise_factor := clampf(
		(speed - MIN_VELOCITY_YAW_SPEED) / maxf(SPEED_BLEND_END - MIN_VELOCITY_YAW_SPEED, 0.001),
		0.0,
		1.0
	)
	var stiffness := lerpf(STEER_CHASE_STIFFNESS, CRUISE_CHASE_STIFFNESS, cruise_factor)
	if steering:
		stiffness *= STEER_LAG_SCALE

	var result := step_chase_yaw(
		_chase_yaw,
		_chase_yaw_velocity,
		target_yaw,
		delta,
		stiffness,
		CHASE_DAMPING
	)
	_chase_yaw = result.chase_yaw
	_chase_yaw_velocity = result.chase_yaw_velocity


func _decay_look_offsets(horizontal_vel: Vector3, steering: bool, delta: float) -> void:
	_look_idle_time += delta
	if _look_idle_time < LOOK_RECENTER_DELAY:
		return

	var speed_factor := clampf(horizontal_vel.length() / LOOK_SPEED_RECENTER_REF, 0.2, 1.0)
	var ramp := clampf(
		(_look_idle_time - LOOK_RECENTER_DELAY) / LOOK_RECENTER_RAMP_TIME,
		0.0,
		1.0
	)
	var spring := lerpf(LOOK_OFFSET_SPRING * 0.35, LOOK_OFFSET_SPRING, ramp)
	spring *= lerpf(0.75, 1.1, speed_factor)
	if steering:
		spring *= LOOK_STEER_RECENTER_SCALE

	_spring_offset_toward_zero(spring, LOOK_OFFSET_DAMPING, delta)


func _spring_offset_toward_zero(stiffness: float, damping: float, delta: float) -> void:
	var yaw_result := step_chase_yaw(
		_look_yaw_offset,
		_look_offset_yaw_velocity,
		0.0,
		delta,
		stiffness,
		damping
	)
	_look_yaw_offset = yaw_result.chase_yaw
	_look_offset_yaw_velocity = yaw_result.chase_yaw_velocity

	var pitch_error := -_look_pitch_offset
	_look_offset_pitch_velocity += pitch_error * stiffness * delta
	_look_offset_pitch_velocity *= exp(-damping * delta)
	_look_pitch_offset += _look_offset_pitch_velocity * delta


func _update_follow_pitch(
	target: Node3D,
	velocity: Vector3,
	grounded: bool,
	foot_mode: bool,
	delta: float
) -> void:
	if foot_mode:
		_follow_pitch = lerpf(_follow_pitch, 0.0, clampf(FOLLOW_PITCH_RATE * delta, 0.0, 1.0))
		return

	var board_pitch := 0.0
	if target.has_method("get_board_pitch"):
		board_pitch = float(target.call("get_board_pitch"))

	var pitch_follow := lerpf(AIR_PITCH_FOLLOW, GROUND_PITCH_FOLLOW, _blend)
	var velocity_pitch := 0.0
	if not grounded and velocity.length_squared() > 4.0:
		velocity_pitch = clampf(-velocity.normalized().y, -0.25, 0.85) * PITCH_VELOCITY_BLEND

	var target_pitch := clampf(
		(board_pitch + velocity_pitch) * pitch_follow,
		-deg_to_rad(MAX_FOLLOW_PITCH_DEG),
		deg_to_rad(MAX_FOLLOW_PITCH_DEG)
	)
	_follow_pitch = lerpf(_follow_pitch, target_pitch, clampf(FOLLOW_PITCH_RATE * delta, 0.0, 1.0))


func _apply_look_with_bank(look_target: Vector3, bank_degrees: float) -> void:
	var to_target := look_target - global_position
	if to_target.length_squared() < 0.0001:
		return

	var forward := to_target.normalized()
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		look_at(look_target, Vector3.UP)
		return
	right = right.normalized()
	var up := right.cross(forward).normalized()
	if absf(bank_degrees) > 0.01:
		up = up.rotated(forward, deg_to_rad(bank_degrees))
	look_at(look_target, up)


func _enforce_camera_floor(pos: Vector3, terrain_manager: TerrainManager) -> Vector3:
	if terrain_manager == null:
		return pos

	var floor_y := terrain_manager.sample_height(pos.x, pos.z) + MIN_CAMERA_GROUND_CLEARANCE
	pos.y = maxf(pos.y, floor_y)
	return pos


func _snap_camera_above_floor(terrain_manager: TerrainManager) -> void:
	if terrain_manager == null:
		return

	var floor_y := terrain_manager.sample_height(global_position.x, global_position.z) + MIN_CAMERA_GROUND_CLEARANCE
	if global_position.y < floor_y:
		global_position.y = floor_y


func _resolve_camera_collision(pivot: Vector3, desired: Vector3, target: Node3D) -> Vector3:
	var to_camera := desired - pivot
	var arm_length := to_camera.length()
	if arm_length < 0.001:
		return desired

	var direction := to_camera / arm_length
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pivot, desired)
	query.collision_mask = 1
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return desired

	var hit_dist := pivot.distance_to(hit.position) - CAMERA_COLLISION_BACKOFF
	arm_length = clampf(hit_dist, MIN_CAMERA_ARM_LENGTH, arm_length)
	return pivot + direction * arm_length
