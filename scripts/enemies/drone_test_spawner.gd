class_name DroneTestSpawner
extends Node3D

## Spawns green machine-gun drone ahead on lane; respawns after despawn.

const MachineGunDroneScene := preload("res://scenes/enemies/machine_gun_drone.tscn")
const CombatDroneScript := preload("res://scripts/enemies/combat_drone.gd")

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var spawn_distance_m := 100.0
@export var respawn_delay_sec := 2.0

var _rig: PlayerRig
var _terrain: TerrainManager
var _active_mg: MachineGunDrone
var _respawn_left := 0.0


func _ready() -> void:
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	call_deferred("_spawn_mg")


func _physics_process(delta: float) -> void:
	if _active_mg != null and is_instance_valid(_active_mg) and not _active_mg.is_queued_for_deletion():
		return
	_active_mg = null

	if _respawn_left <= 0.0:
		return
	_respawn_left = maxf(_respawn_left - delta, 0.0)
	if _respawn_left <= 0.0:
		_spawn_mg()


func _spawn_mg() -> void:
	if _terrain == null or _rig == null:
		return
	var track := _rig.get_active_body()
	if track == null:
		return
	if _active_mg != null and is_instance_valid(_active_mg) and not _active_mg.is_queued_for_deletion():
		return

	var drone := MachineGunDroneScene.instantiate() as MachineGunDrone
	add_child(drone)
	if not drone.tree_exited.is_connected(_on_drone_exited):
		drone.tree_exited.connect(_on_drone_exited)

	drone.global_position = _mg_spawn_position(track)
	drone.configure(
		_terrain,
		track,
		CombatDroneScript.move_speed_for_drone_level(CombatDroneScript.DRONE_MIN_LEVEL)
	)
	_active_mg = drone


func _facing_xz() -> Vector3:
	var flat_forward := Vector3(-1.0, 0.0, 0.0)
	var glider := _rig.get_glider()
	if glider != null:
		flat_forward = Vector3(-glider.global_transform.basis.z.x, 0.0, -glider.global_transform.basis.z.z)
		if flat_forward.length_squared() > 0.0001:
			flat_forward = flat_forward.normalized()
		else:
			flat_forward = Vector3(-1.0, 0.0, 0.0)
	return flat_forward


func _mg_spawn_position(track: Node3D) -> Vector3:
	var flat_forward := _facing_xz()
	var ahead_world := track.global_position + flat_forward * spawn_distance_m
	var world_y := track.global_position.y + CombatDroneScript.CRUISE_HEIGHT_M
	if _terrain != null:
		world_y = _terrain.sample_height(ahead_world.x, track.global_position.z) + CombatDroneScript.CRUISE_HEIGHT_M
	return Vector3(ahead_world.x, world_y, track.global_position.z)


func _on_drone_exited() -> void:
	_active_mg = null
	_respawn_left = respawn_delay_sec
