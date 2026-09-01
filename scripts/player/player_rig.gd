class_name PlayerRig
extends Node3D

## East of home tower so the tower sits behind when facing west (−X).
const SPAWN_EAST_OFFSET_M := 40.0
## West of a visited tower so Wait until dawn continues the run, not behind it.
const SPAWN_WEST_OFFSET_M := 40.0
const SPAWN_YAW_WEST := -PI / 2.0

@export var terrain_manager_path: NodePath

var _glider: GliderPlayer
const GliderInputScript = preload("res://scripts/input/glider_input.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")

var _input: GliderInputScript
var _camera: GliderCamera
var _terrain_manager: TerrainManager
var _look_input_enabled := false
var _spawn_position := Vector3.ZERO
var _spawn_yaw := 0.0
var _spawn_pose_ready := false


func _ready() -> void:
	_glider = get_node_or_null("Glider") as GliderPlayer
	_input = get_node_or_null("GliderInput") as GliderInputScript

	if _glider != null:
		_camera = _glider.get_node_or_null("GliderCamera") as GliderCamera
		if _camera == null:
			_camera = _glider.get_node_or_null("Camera3D") as GliderCamera
		_glider.set_piloted(true)

	if terrain_manager_path != NodePath():
		_terrain_manager = get_node_or_null(terrain_manager_path) as TerrainManager

	_update_terrain_track_node()
	call_deferred("_setup_west_start_pose")


func _setup_west_start_pose() -> void:
	if _glider == null:
		return

	var origin_x := 0.0
	var origin_z := 0.0
	if _terrain_manager != null:
		origin_x = _terrain_manager.run_origin.x
		origin_z = _terrain_manager.run_origin.y

	var spawn_x := origin_x + SPAWN_EAST_OFFSET_M
	var spawn_z := origin_z
	var spawn_y := _glider.global_position.y
	if _terrain_manager != null:
		spawn_y = (
			_terrain_manager.sample_height(spawn_x, spawn_z)
			+ GliderPhysicsScript.BASE_HEIGHT
			+ 0.05
		)
		_terrain_manager.ensure_loaded_at(Vector3(spawn_x, spawn_y, spawn_z))

	_glider.teleport_to(Vector3(spawn_x, spawn_y, spawn_z), SPAWN_YAW_WEST)
	_glider.velocity = Vector3.ZERO
	if _camera != null:
		_camera.reset_follow_state()
		_camera.snap_follow_yaw(SPAWN_YAW_WEST)
		snap_camera_now()
	_capture_spawn_pose()
	capture_look_mouse()


func _capture_spawn_pose() -> void:
	if _glider == null:
		return
	_spawn_position = _glider.global_position
	_spawn_yaw = _glider.get_yaw()
	_spawn_pose_ready = true


func get_spawn_position() -> Vector3:
	if not _spawn_pose_ready:
		_capture_spawn_pose()
	return _spawn_position


func get_spawn_yaw() -> float:
	if not _spawn_pose_ready:
		_capture_spawn_pose()
	return _spawn_yaw


func reset_to_spawn() -> void:
	if _glider == null:
		return
	if not _spawn_pose_ready:
		_capture_spawn_pose()

	if _terrain_manager != null:
		_terrain_manager.ensure_loaded_at(_spawn_position)
	_glider.teleport_to(_spawn_position, _spawn_yaw)
	_glider.velocity = Vector3.ZERO
	var health := get_node_or_null("PlayerHealth")
	if health != null and health.has_method("reset_full"):
		health.reset_full()
	if _camera != null:
		_camera.reset_follow_state()
		_camera.snap_follow_yaw(_spawn_yaw)
		snap_camera_now()
	capture_look_mouse()


func snap_camera_now() -> void:
	if _camera == null:
		return
	_camera.request_hard_snap()
	_update_glider_camera(1.0)


func _physics_process(delta: float) -> void:
	if _camera == null:
		return
	_update_glider_camera(delta)


func _process(_delta: float) -> void:
	if not _look_input_enabled or get_tree().paused:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if event.is_action_pressed("cycle_camera") and _camera != null:
		_camera.cycle_distance_preset()
		return

	if event is InputEventMouseButton and _look_input_enabled and _camera != null:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and (
			mouse.button_index == MOUSE_BUTTON_WHEEL_UP
			or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			var direction := 1.0 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			_camera.apply_zoom(direction)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and _look_input_enabled and _camera != null:
		var motion := event as InputEventMouseMotion
		_camera.apply_look_input(motion.relative.x, motion.relative.y)


func get_glider() -> GliderPlayer:
	if _glider == null:
		_glider = get_node_or_null("Glider") as GliderPlayer
	return _glider


func get_terrain_manager() -> TerrainManager:
	if _terrain_manager == null and terrain_manager_path != NodePath():
		_terrain_manager = get_node_or_null(terrain_manager_path) as TerrainManager
	return _terrain_manager


func get_active_body() -> PhysicsBody3D:
	return _glider


func get_tracking_position() -> Vector3:
	if _glider != null:
		return _glider.global_position
	return global_position


func get_follow_camera() -> GliderCamera:
	return _camera


func _update_glider_camera(delta: float) -> void:
	if _glider == null or _camera == null:
		return
	var steering := _input != null and _input.is_steering() and not _glider.is_run_ended()
	_camera.follow(
		_glider.get_camera_follow_target(),
		_glider.get_camera_follow_yaw(),
		_glider.get_camera_follow_velocity(),
		delta,
		_glider.get_camera_follow_grounded(),
		_terrain_manager,
		steering,
		_glider.get_speed_bonus()
	)


func capture_look_mouse() -> void:
	if not _should_enable_look_input():
		return
	_look_input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_look_mouse() -> void:
	_look_input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_look_input_enabled() -> bool:
	return _look_input_enabled


func _should_enable_look_input() -> bool:
	if get_tree().paused:
		return false
	var weapon := get_tree().get_first_node_in_group("weapon_select_menu") as WeaponSelectMenu
	if weapon != null and weapon.is_open():
		return false
	var upgrade := get_tree().get_first_node_in_group("upgrade_tower_menu") as UpgradeTowerMenu
	if upgrade != null and upgrade.is_open():
		return false
	var pause_menu := PauseMenu.find_menu(get_tree())
	if pause_menu != null and pause_menu.is_open():
		return false
	return true


func teleport_in_front_of(tower_pos: Vector3) -> void:
	if _glider == null:
		return
	var spawn_xz := in_front_xz(tower_pos)
	var spawn_y := _glider.global_position.y
	if _terrain_manager != null:
		spawn_y = (
			_terrain_manager.sample_height(spawn_xz.x, spawn_xz.y)
			+ GliderPhysicsScript.BASE_HEIGHT
			+ 0.05
		)
		_terrain_manager.ensure_loaded_at(Vector3(spawn_xz.x, spawn_y, spawn_xz.y))
	_glider.teleport_to(Vector3(spawn_xz.x, spawn_y, spawn_xz.y), SPAWN_YAW_WEST)
	_glider.velocity = Vector3.ZERO
	if _camera != null:
		_camera.reset_follow_state()
		_camera.snap_follow_yaw(SPAWN_YAW_WEST)
		snap_camera_now()


static func in_front_xz(tower_pos: Vector3) -> Vector2:
	return Vector2(tower_pos.x - SPAWN_WEST_OFFSET_M, tower_pos.z)


func _update_terrain_track_node() -> void:
	var terrain := get_terrain_manager()
	if terrain == null or _glider == null:
		return
	terrain.set_track_node(_glider)
