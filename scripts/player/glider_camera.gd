class_name GliderCamera
extends Camera3D

@export var distance_presets: Array[float] = [3.8, 6.0, 9.5]
@export var pivot_height: float = 0.9
@export var look_height: float = 1.4
@export var look_ahead: float = 14.0
@export var height_distance_scale: float = 0.11
@export var air_height_bonus: float = 0.5
@export var follow_rate: float = 5.0
@export var look_rate: float = 4.0
@export var camera_fov: float = 78.0
@export var camera_fov_speed_boost: float = 6.0
@export var min_camera_ground_clearance: float = 1.2
@export var min_camera_arm_length: float = 2.5
@export var camera_collision_backoff: float = 0.6
@export var preset_blend_rate: float = 6.0
@export var max_look_yaw_deg: float = 180.0
@export var fall_pitch_max_deg: float = 28.0
@export var fall_pitch_speed_ref: float = 12.0
@export var fall_pitch_rate: float = 5.0
@export var air_focus_rate_scale: float = 2.8
@export var air_look_velocity_blend: float = 0.6
@export var land_pitch_recover_rate: float = 2.0
@export var land_recover_min_sec: float = 0.35
@export var land_recover_max_sec: float = 0.85
@export var handheld_enabled: bool = true
@export var handheld_rot_amplitude_deg: float = 0.4
@export var handheld_rot_frequency: float = 0.85
@export var handheld_speed_ref: float = 18.0
@export var handheld_idle_scale: float = 0.35
@export var handheld_smoothing: float = 10.0
@export var handheld_base_scale: float = 0.5
@export var handheld_high_speed_scale: float = 1.3
@export var handheld_boost_scale: float = 1.55
@export var handheld_speed_exponent: float = 1.4

const MIN_VELOCITY_YAW_SPEED := 1.5
const SPEED_BLEND_START := 5.0
const SPEED_BLEND_END := 18.0
const MAX_VELOCITY_YAW_BLEND := 0.65
const STEER_VELOCITY_YAW_BLEND := 0.3
const CRUISE_CHASE_STIFFNESS := 6.0
const STEER_CHASE_STIFFNESS := 3.5
const CHASE_DAMPING := 5.5
const STEER_LAG_SCALE := 0.6
const FOV_RATE := 4.0
const SPEED_FOV_REF := 22.0
const MOUSE_YAW_SENSITIVITY := 0.0022
const MOUSE_PITCH_SENSITIVITY := 0.0018
const MAX_LOOK_PITCH_DEG := 35.0
const LOOK_OFFSET_SPRING := 8.0
const LOOK_OFFSET_DAMPING := 6.0
const LOOK_RECENTER_DELAY := 1.0
const LOOK_RECENTER_RAMP_TIME := 1.4
const LOOK_STEER_RECENTER_SCALE := 0.45
const LOOK_SPEED_RECENTER_REF := 18.0

var _distance_index := 1
var _distance := 6.0
var _focus := Vector3.ZERO
var _look_focus := Vector3.ZERO
var _focus_initialized := false
var _chase_yaw := 0.0
var _chase_yaw_velocity := 0.0
var _chase_initialized := false
var _look_yaw_offset := 0.0
var _look_pitch_offset := 0.0
var _look_offset_yaw_velocity := 0.0
var _look_offset_pitch_velocity := 0.0
var _mouse_look_enabled := true
var _look_idle_time := 0.0
var _fov_blend := 0.0
var _fall_pitch := 0.0
var _was_airborne := false
var _land_recover_blend := 0.0
var _land_recover_strength := 0.0
var _land_recover_pitch_latch := 0.0
var _land_recover_vel_dir := Vector3.FORWARD
var _land_recover_look_blend := 0.0
var _hard_snap := false
var _handheld_time := 0.0
var _handheld_rot := Vector3.ZERO
var _handheld_rot_noise: FastNoiseLite


func _ready() -> void:
	top_level = true
	current = true
	fov = camera_fov
	_distance = _active_preset_distance()
	_setup_handheld_noise()


func get_camera_node() -> Camera3D:
	return self


func follow(
	target: Node3D,
	body_yaw: float,
	velocity: Vector3,
	delta: float,
	grounded: bool,
	terrain_manager: TerrainManager,
	steering: bool = false,
	boosting: bool = false
) -> void:
	var snap := _hard_snap
	_hard_snap = false

	var preset_distance := _active_preset_distance()
	var preset_t := 1.0 if snap else clampf(preset_blend_rate * delta, 0.0, 1.0)
	_distance = lerpf(_distance, preset_distance, preset_t)

	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_vel.length()
	var speed_3d := velocity.length()
	var descent_speed := maxf(0.0, -velocity.y)

	var player_pos := target.global_position
	var pivot := player_pos + Vector3(0.0, pivot_height, 0.0)

	if snap or not _focus_initialized:
		_focus = pivot
		_look_focus = pivot + Vector3(0.0, look_height, 0.0)
		_focus_initialized = true

	_update_landing_recovery(grounded, speed_3d, velocity, delta, snap)
	var air_blend := _air_effect_blend(grounded)

	var focus_t := 1.0 if snap else clampf(follow_rate * delta, 0.0, 1.0)
	if snap:
		_focus = pivot
	else:
		var focus_y_scale := lerpf(1.0, air_focus_rate_scale, air_blend)
		var focus_y_t := clampf(follow_rate * focus_y_scale * delta, 0.0, 1.0)
		_focus.x = lerpf(_focus.x, pivot.x, focus_t)
		_focus.z = lerpf(_focus.z, pivot.z, focus_t)
		_focus.y = lerpf(_focus.y, pivot.y, focus_y_t)

	if snap:
		_fall_pitch = 0.0
	else:
		_update_fall_pitch(descent_speed, grounded, delta)

	if snap or not _chase_initialized:
		_chase_yaw = body_yaw
		_chase_yaw_velocity = 0.0
		_chase_initialized = true

	if _mouse_look_enabled and not snap:
		_decay_look_offsets(horizontal_vel, steering, delta)

	if snap:
		_chase_yaw = body_yaw
		_chase_yaw_velocity = 0.0
	else:
		var chase_target := _compute_chase_target_yaw(body_yaw, horizontal_vel, steering)
		_update_chase_yaw(chase_target, speed, steering, delta)

	var aim_yaw := _chase_yaw + _look_yaw_offset
	var boom_forward := MathUtil.yaw_forward(aim_yaw)
	var boom_right := Vector3.UP.cross(boom_forward).normalized()

	var height_scale := 1.0 + _distance * height_distance_scale
	var camera_height := height_scale + air_height_bonus * air_blend
	var boom_pitch := _look_pitch_offset + _fall_pitch
	var pitched_up := Vector3.UP.rotated(boom_right, boom_pitch).normalized()
	var arm := -boom_forward * _distance + pitched_up * camera_height

	var desired_pos := pivot + arm
	desired_pos = _resolve_camera_collision(pivot, desired_pos, target)
	desired_pos = _enforce_camera_floor(desired_pos, terrain_manager)

	var pos_t := 1.0 if snap else clampf(follow_rate * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired_pos, pos_t)
	_snap_camera_above_floor(terrain_manager)

	var low_speed_blend := 1.0 - clampf(
		(speed - MIN_VELOCITY_YAW_SPEED) / maxf(SPEED_BLEND_END - SPEED_BLEND_START, 0.001),
		0.0,
		1.0
	)
	var lead_dir := boom_forward
	if speed > MIN_VELOCITY_YAW_SPEED:
		var velocity_dir := horizontal_vel / speed
		lead_dir = velocity_dir.lerp(boom_forward, low_speed_blend).normalized()

	var look_offset := lead_dir * look_ahead + Vector3.UP * look_height
	if speed_3d > 3.0:
		if not grounded:
			_land_recover_vel_dir = velocity / speed_3d
		var vel_offset := _land_recover_vel_dir * look_ahead + Vector3.UP * look_height * 0.35
		var look_blend := 0.0
		if not grounded:
			var fall_blend := clampf(descent_speed / maxf(fall_pitch_speed_ref, 0.001), 0.0, 1.0)
			look_blend = lerpf(air_look_velocity_blend * 0.35, air_look_velocity_blend, fall_blend)
		elif _land_recover_blend > 0.0:
			look_blend = _land_recover_look_blend * _land_recover_blend
		if look_blend > 0.0:
			look_offset = look_offset.lerp(vel_offset, look_blend)
	var look_target := _focus + look_offset
	var look_t := 1.0 if snap else clampf(look_rate * delta, 0.0, 1.0)
	_look_focus = _look_focus.lerp(look_target, look_t)
	look_at(_look_focus, Vector3.UP)
	_apply_handheld_offset(delta, speed, snap, boosting)

	var speed_t := clampf(speed / SPEED_FOV_REF, 0.0, 1.0)
	var fov_t := 1.0 if snap else clampf(FOV_RATE * delta, 0.0, 1.0)
	_fov_blend = lerpf(_fov_blend, speed_t, fov_t)
	fov = lerpf(camera_fov, camera_fov + camera_fov_speed_boost, _fov_blend)


func cycle_distance_preset() -> void:
	if distance_presets.is_empty():
		return
	_distance_index = (_distance_index + 1) % distance_presets.size()


func get_follow_yaw() -> float:
	return _chase_yaw + _look_yaw_offset


func get_forward_flat() -> Vector3:
	return MathUtil.yaw_forward(get_follow_yaw())


func apply_look_input(rel_x: float, rel_y: float) -> void:
	if not _mouse_look_enabled:
		return
	_look_idle_time = 0.0
	_look_yaw_offset -= rel_x * MOUSE_YAW_SENSITIVITY
	_look_pitch_offset -= rel_y * MOUSE_PITCH_SENSITIVITY
	var max_pitch := deg_to_rad(MAX_LOOK_PITCH_DEG)
	_look_pitch_offset = clampf(_look_pitch_offset, -max_pitch, max_pitch)
	var max_yaw := deg_to_rad(max_look_yaw_deg)
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
	_distance_index = 1
	_distance = _active_preset_distance()
	_chase_yaw_velocity = 0.0
	_look_yaw_offset = 0.0
	_look_pitch_offset = 0.0
	_look_offset_yaw_velocity = 0.0
	_look_offset_pitch_velocity = 0.0
	_look_idle_time = 0.0
	_fov_blend = 0.0
	_fall_pitch = 0.0
	_reset_landing_recovery()
	_reset_handheld()
	fov = camera_fov


func _setup_handheld_noise() -> void:
	_handheld_rot_noise = FastNoiseLite.new()
	_handheld_rot_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_handheld_rot_noise.seed = 9031
	_handheld_rot_noise.frequency = handheld_rot_frequency


func _reset_handheld() -> void:
	_handheld_time = 0.0
	_handheld_rot = Vector3.ZERO


func _apply_handheld_offset(delta: float, speed: float, snap: bool, boosting: bool) -> void:
	if snap or not handheld_enabled:
		_reset_handheld()
		return

	_handheld_time += delta
	var intensity := compute_handheld_intensity(
		speed,
		handheld_speed_ref,
		handheld_idle_scale,
		handheld_base_scale,
		handheld_high_speed_scale,
		handheld_boost_scale,
		handheld_speed_exponent,
		boosting
	)
	var sample_rot := sample_handheld_rotation(
		_handheld_time,
		_handheld_rot_noise,
		deg_to_rad(handheld_rot_amplitude_deg),
		intensity
	)
	var smooth_t := clampf(handheld_smoothing * delta, 0.0, 1.0)
	_handheld_rot = _handheld_rot.lerp(sample_rot, smooth_t)

	rotate_object_local(Vector3.UP, _handheld_rot.y)
	rotate_object_local(Vector3.RIGHT, _handheld_rot.x)
	rotate_object_local(Vector3.FORWARD, _handheld_rot.z)


func _reset_landing_recovery() -> void:
	_was_airborne = false
	_land_recover_blend = 0.0
	_land_recover_strength = 0.0
	_land_recover_pitch_latch = 0.0
	_land_recover_vel_dir = Vector3.FORWARD
	_land_recover_look_blend = 0.0


func _update_landing_recovery(
	grounded: bool,
	speed_3d: float,
	velocity: Vector3,
	delta: float,
	snap: bool
) -> void:
	if snap:
		_reset_landing_recovery()
		return

	if grounded and _was_airborne:
		var max_pitch_rad := deg_to_rad(fall_pitch_max_deg)
		_land_recover_strength = clampf(
			absf(_fall_pitch) / maxf(max_pitch_rad, 0.001),
			0.0,
			1.0
		)
		_land_recover_blend = 1.0
		_land_recover_pitch_latch = _fall_pitch
		if speed_3d > 3.0:
			_land_recover_vel_dir = velocity / speed_3d
		_land_recover_look_blend = lerpf(
			air_look_velocity_blend * 0.35,
			air_look_velocity_blend,
			_land_recover_strength
		)

	if grounded and _land_recover_blend > 0.0:
		var duration := compute_land_recover_duration(
			_land_recover_strength,
			land_recover_min_sec,
			land_recover_max_sec
		)
		_land_recover_blend = step_land_recover_blend(_land_recover_blend, delta, duration)
	elif not grounded:
		_land_recover_blend = 0.0
		_land_recover_strength = 0.0

	_was_airborne = not grounded


func _air_effect_blend(grounded: bool) -> float:
	if not grounded:
		return 1.0
	return _land_recover_blend * _land_recover_strength


func _update_fall_pitch(descent_speed: float, grounded: bool, delta: float) -> void:
	var target_fall_pitch := 0.0
	var pitch_rate := fall_pitch_rate
	if not grounded:
		target_fall_pitch = compute_fall_pitch(
			descent_speed,
			fall_pitch_max_deg,
			fall_pitch_speed_ref
		)
	elif _land_recover_blend > 0.0:
		target_fall_pitch = _land_recover_pitch_latch * _land_recover_blend
		pitch_rate = land_pitch_recover_rate
	var pitch_t := clampf(pitch_rate * delta, 0.0, 1.0)
	_fall_pitch = lerpf(_fall_pitch, target_fall_pitch, pitch_t)


static func angle_diff(from_yaw: float, to_yaw: float) -> float:
	return MathUtil.angle_diff(from_yaw, to_yaw)


static func compute_fall_pitch(
	descent_speed: float,
	max_deg: float,
	speed_ref: float
) -> float:
	if descent_speed <= 0.5:
		return 0.0
	var t := clampf(descent_speed / maxf(speed_ref, 0.001), 0.0, 1.0)
	return -deg_to_rad(max_deg) * t


static func compute_land_recover_duration(
	strength: float,
	min_sec: float,
	max_sec: float
) -> float:
	return lerpf(min_sec, max_sec, clampf(strength, 0.0, 1.0))


static func step_land_recover_blend(blend: float, delta: float, duration: float) -> float:
	return maxf(0.0, blend - delta / maxf(duration, 0.001))


static func compute_handheld_intensity(
	speed: float,
	speed_ref: float,
	idle_scale: float,
	base_scale: float,
	high_speed_scale: float,
	boost_scale: float,
	speed_exponent: float,
	boosting: bool = false
) -> float:
	var speed_t := clampf(speed / maxf(speed_ref, 0.001), 0.0, 1.0)
	var speed_curve := lerpf(idle_scale, high_speed_scale, pow(speed_t, speed_exponent))
	var boost_mult := boost_scale if boosting else 1.0
	return base_scale * speed_curve * boost_mult


static func sample_handheld_rotation(
	time: float,
	rot_noise: FastNoiseLite,
	rot_amp: float,
	intensity: float
) -> Vector3:
	var rot_scale := rot_amp * intensity
	return Vector3(
		rot_noise.get_noise_1d(time + 300.0),
		rot_noise.get_noise_1d(time + 400.0),
		rot_noise.get_noise_1d(time + 500.0)
	) * rot_scale


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


func _active_preset_distance() -> float:
	if distance_presets.is_empty():
		return 6.0
	return distance_presets[_distance_index % distance_presets.size()]


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


func _enforce_camera_floor(pos: Vector3, terrain_manager: TerrainManager) -> Vector3:
	if terrain_manager == null:
		return pos

	var floor_y := terrain_manager.sample_height(pos.x, pos.z) + min_camera_ground_clearance
	pos.y = maxf(pos.y, floor_y)
	return pos


func _snap_camera_above_floor(terrain_manager: TerrainManager) -> void:
	if terrain_manager == null:
		return

	var floor_y := terrain_manager.sample_height(global_position.x, global_position.z) + min_camera_ground_clearance
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

	var hit_dist := pivot.distance_to(hit.position) - camera_collision_backoff
	arm_length = clampf(hit_dist, min_camera_arm_length, arm_length)
	return pivot + direction * arm_length
