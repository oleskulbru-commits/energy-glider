class_name PlayerRig
extends Node3D

const MOUNT_MAX_SPEED := 2.5
const MOUNT_MAX_DISTANCE := 2.5
const DISMOUNT_SIDE_OFFSET := 1.2
const ON_FOOT_FOOT_OFFSET := 0.05
const ON_FOOT_SPAWN_LIFT := 0.1
const DISMOUNT_RAY_UP := 20.0
const DISMOUNT_RAY_DOWN := 200.0

@export var terrain_manager_path: NodePath

var _glider: GliderPlayer
var _on_foot: OnFootController
const GliderInputScript = preload("res://scripts/input/glider_input.gd")

var _input: GliderInputScript
var _camera: GliderCamera
var _interactor: PlayerInteractor
var _loot_overlay: LootOverlay
var _terrain_manager: TerrainManager
var _mounted := true
var _mount_toggle_queued := false
var _mouse_captured := false


func _ready() -> void:
	_glider = get_node_or_null("Glider") as GliderPlayer
	_on_foot = get_node_or_null("OnFoot") as OnFootController
	_input = get_node_or_null("GliderInput") as GliderInputScript
	_interactor = get_node_or_null("PlayerInteractor") as PlayerInteractor
	_loot_overlay = get_node_or_null("LootOverlay") as LootOverlay
	if _loot_overlay != null:
		_loot_overlay.opened.connect(_on_loot_overlay_opened)
		_loot_overlay.closed.connect(_on_loot_overlay_closed)

	if _glider != null:
		_camera = _glider.get_node_or_null("Camera3D") as GliderCamera

	if terrain_manager_path != NodePath():
		_terrain_manager = get_node_or_null(terrain_manager_path) as TerrainManager

	if _on_foot != null:
		_on_foot.set_active(false)

	_set_mounted(true, true)


func _physics_process(delta: float) -> void:
	if _camera == null:
		return

	if _mounted:
		_update_glider_camera(delta)
	else:
		_update_on_foot_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _blocks_mount_toggle():
			return
		_try_mount_toggle()
		return

	if _is_loot_ui_open():
		return

	if event.is_action_pressed("ui_cancel"):
		_release_mouse()
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			if _mounted or (_on_foot != null and _on_foot.visible):
				_capture_mouse()
		return

	if event is InputEventMouseMotion and _mouse_captured and _camera != null and not _is_loot_ui_open():
		var motion := event as InputEventMouseMotion
		_camera.apply_look_input(motion.relative.x, motion.relative.y)


func request_mount_toggle() -> void:
	_mount_toggle_queued = true


func _process(_delta: float) -> void:
	if _mount_toggle_queued:
		_mount_toggle_queued = false
		_try_mount_toggle()


func is_mounted() -> bool:
	return _mounted


func get_glider() -> GliderPlayer:
	if _glider == null:
		_glider = get_node_or_null("Glider") as GliderPlayer
	return _glider


func get_terrain_manager() -> TerrainManager:
	if _terrain_manager == null and terrain_manager_path != NodePath():
		_terrain_manager = get_node_or_null(terrain_manager_path) as TerrainManager
	return _terrain_manager


func get_active_body() -> PhysicsBody3D:
	if _mounted and _glider != null:
		return _glider
	return _on_foot


func get_tracking_position() -> Vector3:
	var body := get_active_body()
	if body != null:
		return body.global_position
	return global_position


func can_dismount() -> bool:
	if not _mounted or _glider == null:
		return false
	if _glider.is_run_ended():
		return false
	if not _glider.is_grounded():
		return false
	return MathUtil.horizontal_speed(_glider.velocity) <= MOUNT_MAX_SPEED


func can_mount() -> bool:
	if _mounted or _glider == null or _on_foot == null:
		return false
	if _glider.is_run_ended():
		return false
	if MathUtil.horizontal_speed(_on_foot.velocity) > MOUNT_MAX_SPEED:
		return false
	var offset: Vector3 = _on_foot.global_position - _glider.global_position
	offset.y = 0.0
	return offset.length() <= MOUNT_MAX_DISTANCE


func get_mount_prompt() -> Dictionary:
	if can_dismount():
		return { "visible": true, "label": "DISMOUNT", "tap_action": true }
	if can_mount():
		return { "visible": true, "label": "MOUNT", "tap_action": true }
	return { "visible": false, "label": "", "tap_action": false }


func _try_mount_toggle() -> bool:
	if can_dismount():
		_dismount()
		return true
	if can_mount():
		_mount()
		return true
	return false


func _dismount() -> void:
	if not can_dismount():
		return

	var side := _glider.global_transform.basis.x
	side.y = 0.0
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()

	var spawn := _glider.global_position + side * DISMOUNT_SIDE_OFFSET
	var terrain := get_terrain_manager()
	if terrain != null:
		terrain.ensure_loaded_at(spawn)
	spawn.y = _dismount_spawn_y(spawn.x, spawn.z)

	_on_foot.global_position = spawn
	_on_foot.velocity = Vector3.ZERO
	_on_foot.rotation.y = _glider.rotation.y
	if _camera != null:
		_camera.snap_follow_yaw(_glider.rotation.y)

	_glider.velocity = Vector3.ZERO
	_set_mounted(false)


func _mount() -> void:
	if not can_mount():
		return

	_on_foot.velocity = Vector3.ZERO
	_set_mounted(true)


func _set_mounted(mounted: bool, instant: bool = false) -> void:
	_mounted = mounted

	if _input != null:
		_input.set_locomotion_enabled(mounted)

	if _on_foot != null:
		_on_foot.set_active(not mounted)
		_on_foot.set_locomotion_enabled(not mounted)

	if _glider != null:
		_glider.set_piloted(mounted)

	_update_terrain_track_node()

	if instant and _camera != null:
		_camera.reset_follow_state()

	if mounted:
		_capture_mouse()
	else:
		_release_mouse()


func get_follow_camera() -> GliderCamera:
	return _camera


func _update_glider_camera(delta: float) -> void:
	if _glider == null or _camera == null:
		return
	var steering := _input != null and _input.is_steering()
	_camera.follow(
		_glider,
		_glider.get_yaw(),
		_glider.velocity,
		delta,
		_glider.get_smoothed_clearance(),
		_glider.is_grounded(),
		_terrain_manager,
		_glider.get_yaw_velocity(),
		false,
		_glider.get_camera_air_blend(),
		steering
	)


func _update_on_foot_camera(delta: float) -> void:
	if _on_foot == null or _camera == null:
		return

	_camera.follow(
		_on_foot,
		_on_foot.rotation.y,
		_on_foot.velocity,
		delta,
		0.0,
		true,
		_terrain_manager,
		0.0,
		true
	)
	_on_foot.sync_camera_movement_axes(_camera)


func _is_loot_ui_open() -> bool:
	return _loot_overlay != null and _loot_overlay.is_open()


func _blocks_mount_toggle() -> bool:
	if _is_loot_ui_open():
		return true
	if _interactor != null:
		return _interactor.blocks_mount_toggle()
	return false


func _on_loot_overlay_opened() -> void:
	_release_mouse()


func _on_loot_overlay_closed() -> void:
	if _mounted:
		_capture_mouse()


func _capture_mouse() -> void:
	if _mouse_captured:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true


func _release_mouse() -> void:
	if not _mouse_captured and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_captured = false


func _update_terrain_track_node() -> void:
	var terrain := get_terrain_manager()
	if terrain == null:
		return
	if _mounted and _glider != null:
		terrain.set_track_node(_glider)
	elif _on_foot != null:
		terrain.set_track_node(_on_foot)


func _dismount_spawn_y(world_x: float, world_z: float) -> float:
	var origin_y := _glider.global_position.y if _glider != null else global_position.y
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	var ground_y := TerrainQuery.sample_height(
		null,
		space,
		world_x,
		world_z,
		origin_y,
		[],
		DISMOUNT_RAY_UP,
		DISMOUNT_RAY_DOWN
	)
	if is_nan(ground_y):
		var terrain := get_terrain_manager()
		if terrain != null:
			ground_y = terrain.sample_height(world_x, world_z)
		elif _glider != null:
			ground_y = _glider.global_position.y
		else:
			ground_y = global_position.y
	return ground_y - ON_FOOT_FOOT_OFFSET + ON_FOOT_SPAWN_LIFT
