class_name DroneTestSpawner
extends Node3D

## Spawns laser and missile combat drones ahead of the player; respawns after death.

const LaserDroneScene := preload("res://scenes/enemies/laser_drone.tscn")
const MissileDroneScene := preload("res://scenes/enemies/missile_drone.tscn")
const CombatDroneScript := preload("res://scripts/enemies/combat_drone.gd")

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var spawn_distance_m := 45.0
@export var lateral_offset_m := 12.0
@export var respawn_delay_sec := 2.0

var _rig: PlayerRig
var _terrain: TerrainManager
var _active_laser: CombatDrone
var _active_missile: CombatDrone
var _laser_respawn_left := 0.0
var _missile_respawn_left := 0.0


func _ready() -> void:
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	call_deferred("_spawn_both")


func _physics_process(delta: float) -> void:
	_tick_respawn(delta, true)
	_tick_respawn(delta, false)


func _tick_respawn(delta: float, laser: bool) -> void:
	var active := _active_laser if laser else _active_missile
	if active != null and is_instance_valid(active) and not active.is_queued_for_deletion():
		return
	if laser:
		_active_laser = null
	else:
		_active_missile = null

	var respawn_left := _laser_respawn_left if laser else _missile_respawn_left
	if respawn_left <= 0.0:
		return
	respawn_left = maxf(respawn_left - delta, 0.0)
	if laser:
		_laser_respawn_left = respawn_left
	else:
		_missile_respawn_left = respawn_left
	if respawn_left <= 0.0:
		_spawn_one(laser)


func _spawn_both() -> void:
	_spawn_one(true)
	_spawn_one(false)


func _spawn_one(laser: bool) -> void:
	if _terrain == null or _rig == null:
		return
	var track := _rig.get_active_body()
	if track == null:
		return
	var active := _active_laser if laser else _active_missile
	if active != null and is_instance_valid(active) and not active.is_queued_for_deletion():
		return

	var drone: CombatDrone
	if laser:
		drone = LaserDroneScene.instantiate() as CombatDrone
	else:
		drone = MissileDroneScene.instantiate() as CombatDrone
	add_child(drone)
	if not drone.died.is_connected(_on_drone_died.bind(laser)):
		drone.died.connect(_on_drone_died.bind(laser))

	var lateral := -lateral_offset_m if laser else lateral_offset_m
	drone.global_position = _spawn_position(track, lateral)
	drone.never_despawn = true
	drone.configure(
		_terrain,
		track,
		CombatDroneScript.move_speed_for_drone_level(CombatDroneScript.DRONE_MIN_LEVEL)
	)
	if laser:
		_active_laser = drone
	else:
		_active_missile = drone


func _spawn_position(track: Node3D, lateral_m: float) -> Vector3:
	var flat_forward := Vector3(-1.0, 0.0, 0.0)
	var glider := _rig.get_glider()
	if glider != null:
		flat_forward = Vector3(-glider.global_transform.basis.z.x, 0.0, -glider.global_transform.basis.z.z)
		if flat_forward.length_squared() > 0.0001:
			flat_forward = flat_forward.normalized()
		else:
			flat_forward = Vector3(-1.0, 0.0, 0.0)
	var right := Vector3(flat_forward.z, 0.0, -flat_forward.x)
	var world := (
		track.global_position
		+ flat_forward * spawn_distance_m
		+ right * lateral_m
	)
	var world_y := track.global_position.y + CombatDroneScript.CRUISE_HEIGHT_M
	if _terrain != null:
		world_y = _terrain.sample_height(world.x, world.z) + CombatDroneScript.CRUISE_HEIGHT_M
	return Vector3(world.x, world_y, world.z)


func _on_drone_died(laser: bool) -> void:
	if laser:
		_active_laser = null
		_laser_respawn_left = respawn_delay_sec
	else:
		_active_missile = null
		_missile_respawn_left = respawn_delay_sec
