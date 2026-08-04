class_name OnFootController
extends CharacterBody3D

const WALK_SPEED := 4.5
const WALK_ACCEL := 18.0
const WALK_DECEL := 22.0
const GRAVITY := 20.0
const ROTATION_RATE := 14.0
const CAPSULE_FOOT_OFFSET := 0.05
const GROUND_SNAP_DISTANCE := 0.75
const GROUND_RAY_START_ABOVE := 8.0
const GROUND_RAY_LENGTH := 24.0

var _camera_yaw := 0.0
var _move_forward := Vector3.BACK
var _move_right := Vector3.RIGHT
var _locomotion_enabled := false
var _rig: PlayerRig


func _ready() -> void:
	motion_mode = MOTION_MODE_GROUNDED
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.08
	visible = false
	set_physics_process(false)
	_rig = get_parent() as PlayerRig


func set_active(active: bool) -> void:
	visible = active
	set_physics_process(active)
	if not active:
		velocity = Vector3.ZERO


func set_locomotion_enabled(enabled: bool) -> void:
	_locomotion_enabled = enabled


func set_camera_yaw(yaw: float) -> void:
	_camera_yaw = yaw
	_move_forward = MathUtil.yaw_forward(yaw)
	_move_right = Vector3.UP.cross(_move_forward).normalized()


func sync_camera_movement_axes(camera: Camera3D) -> void:
	if camera == null:
		return

	var basis := camera.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	else:
		forward = MathUtil.yaw_forward(_camera_yaw)
	if right.length_squared() > 0.0001:
		right = right.normalized()
	else:
		right = Vector3.UP.cross(forward).normalized()

	_move_forward = forward
	_move_right = right
	_camera_yaw = atan2(forward.x, forward.z)


func get_move_velocity() -> Vector3:
	return velocity


func _physics_process(delta: float) -> void:
	if not _locomotion_enabled:
		velocity.x = move_toward(velocity.x, 0.0, WALK_DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, WALK_DECEL * delta)
	else:
		var cam_forward := _move_forward
		var cam_right := _move_right
		var wish := Vector3.ZERO
		wish += cam_forward * Input.get_action_strength("move_forward")
		wish -= cam_forward * Input.get_action_strength("brake")
		wish += cam_right * Input.get_action_strength("steer_right")
		wish -= cam_right * Input.get_action_strength("steer_left")
		wish.y = 0.0

		var target_vel := Vector3.ZERO
		if wish.length_squared() > 0.0001:
			target_vel = wish.normalized() * WALK_SPEED

		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var rate := WALK_ACCEL if target_vel.length_squared() > 0.0001 else WALK_DECEL
		horizontal = horizontal.move_toward(target_vel, rate * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

		if horizontal.length_squared() > 0.04:
			var face_yaw := atan2(horizontal.x, horizontal.z)
			rotation.y = lerp_angle(rotation.y, face_yaw, clampf(ROTATION_RATE * delta, 0.0, 1.0))

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	move_and_slide()
	_snap_to_ground()


func _snap_to_ground() -> void:
	if is_on_floor():
		return

	var ground_y := _query_ground_y(global_position.x, global_position.z)
	if is_nan(ground_y):
		return

	var foot_y := global_position.y + CAPSULE_FOOT_OFFSET
	var gap := foot_y - ground_y
	if gap < -0.05:
		global_position.y = ground_y - CAPSULE_FOOT_OFFSET
		velocity.y = minf(velocity.y, 0.0)
		return
	if velocity.y > 0.5 or gap > GROUND_SNAP_DISTANCE:
		return

	global_position.y = ground_y - CAPSULE_FOOT_OFFSET
	velocity.y = minf(velocity.y, 0.0)


func _query_ground_y(world_x: float, world_z: float) -> float:
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	var terrain := _rig.get_terrain_manager() if _rig != null else null
	# Prefer collision mesh when available so foot placement matches walkable geometry.
	var ray_y := TerrainQuery.sample_height(
		null,
		space,
		world_x,
		world_z,
		global_position.y,
		[],
		GROUND_RAY_START_ABOVE,
		GROUND_RAY_LENGTH
	)
	if not is_nan(ray_y):
		return ray_y
	if terrain != null:
		return terrain.sample_height(world_x, world_z)
	return NAN
