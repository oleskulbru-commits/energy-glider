class_name TestPlayer
extends CharacterBody3D

const BASE_SPEED := 28.0
const BOOST_SPEED := 48.0
const STEER_SPEED := 1.8
const GRAVITY := 20.0
const GROUND_RAY_LENGTH := 8.0
const GROUND_SNAP_SPEED := 12.0

@export var terrain_manager_path: NodePath

var _terrain_manager: TerrainManager
var _camera_pivot: Node3D
var _camera: Camera3D


func _ready() -> void:
	if terrain_manager_path != NodePath():
		_terrain_manager = get_node_or_null(terrain_manager_path) as TerrainManager

	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	add_child(_camera_pivot)
	_camera_pivot.position = Vector3(0.0, 2.5, 0.0)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.position = Vector3(0.0, 4.0, 10.0)
	_camera.rotation_degrees = Vector3(-15.0, 0.0, 0.0)
	_camera.current = true
	_camera_pivot.add_child(_camera)

	if _terrain_manager != null:
		var spawn_x := global_position.x
		var spawn_z := global_position.z
		global_position.y = _terrain_manager.sample_height(spawn_x, spawn_z) + 2.0


func _physics_process(delta: float) -> void:
	var steer_input := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	rotate_y(-steer_input * STEER_SPEED * delta)

	var speed := BOOST_SPEED if Input.is_action_pressed("boost") else BASE_SPEED
	var forward := global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	velocity.x = forward.x * speed
	velocity.z = forward.z * speed

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	move_and_slide()
	_snap_to_terrain(delta)
	_update_camera()


func _snap_to_terrain(delta: float) -> void:
	if _terrain_manager == null:
		return

	var ground_y := _sample_ground_height()
	if is_nan(ground_y):
		return

	var target_y := ground_y + 1.0
	if global_position.y < target_y or is_on_floor():
		global_position.y = lerpf(global_position.y, target_y, GROUND_SNAP_SPEED * delta)


func _sample_ground_height() -> float:
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	var ray_y := TerrainQuery.sample_height(
		null,
		space,
		global_position.x,
		global_position.z,
		global_position.y,
		[],
		3.0,
		GROUND_RAY_LENGTH
	)
	if not is_nan(ray_y):
		return ray_y
	if _terrain_manager != null:
		return _terrain_manager.sample_height(global_position.x, global_position.z)
	return NAN


func _update_camera() -> void:
	if _camera_pivot == null:
		return
	_camera_pivot.global_position = global_position + Vector3(0.0, 2.5, 0.0)
	_camera_pivot.rotation.y = rotation.y
