class_name DroneTestSpawner
extends Node3D

## Spawns MG, laser, and missile drones ahead on lane; respawns each after despawn.

enum DroneKind { MG, LASER, MISSILE }

const MachineGunDroneScene := preload("res://scenes/enemies/machine_gun_drone.tscn")
const LaserDroneScene := preload("res://scenes/enemies/laser_drone.tscn")
const MissileDroneScene := preload("res://scenes/enemies/missile_drone.tscn")
const CombatDroneScript := preload("res://scripts/enemies/combat_drone.gd")

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var spawn_distance_m := 100.0
@export var respawn_delay_sec := 2.0

var _rig: PlayerRig
var _terrain: TerrainManager
var _active_mg: MachineGunDrone
var _active_laser: LaserDrone
var _active_missile: MissileDrone
var _respawn_left := {
	DroneKind.MG: 0.0,
	DroneKind.LASER: 0.0,
	DroneKind.MISSILE: 0.0,
}


func _ready() -> void:
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	call_deferred("_spawn_all")


func _physics_process(delta: float) -> void:
	_sync_active_slots()
	for kind: DroneKind in _respawn_left.keys():
		if _is_kind_active(kind):
			continue
		var left: float = _respawn_left[kind]
		if left <= 0.0:
			continue
		left = maxf(left - delta, 0.0)
		_respawn_left[kind] = left
		if left <= 0.0:
			_spawn_kind(kind)


func _spawn_all() -> void:
	_spawn_kind(DroneKind.MG)
	_spawn_kind(DroneKind.LASER)
	_spawn_kind(DroneKind.MISSILE)


func _spawn_kind(kind: DroneKind) -> void:
	if _terrain == null or _rig == null:
		return
	var track := _rig.get_active_body()
	if track == null:
		return
	if _is_kind_active(kind):
		return

	var drone := _spawn_drone(_scene_for(kind), track)
	match kind:
		DroneKind.MG:
			_active_mg = drone as MachineGunDrone
		DroneKind.LASER:
			_active_laser = drone as LaserDrone
		DroneKind.MISSILE:
			_active_missile = drone as MissileDrone


func _spawn_drone(scene: PackedScene, track: Node3D) -> CombatDrone:
	var drone := scene.instantiate() as CombatDrone
	add_child(drone)
	drone.global_position = _drone_spawn_position(track)
	drone.configure(
		_terrain,
		track,
		CombatDroneScript.move_speed_for_drone_level(CombatDroneScript.DRONE_MIN_LEVEL)
	)
	if not drone.tree_exited.is_connected(_on_drone_exited):
		drone.tree_exited.connect(_on_drone_exited.bind(drone))
	return drone


func _scene_for(kind: DroneKind) -> PackedScene:
	match kind:
		DroneKind.LASER:
			return LaserDroneScene
		DroneKind.MISSILE:
			return MissileDroneScene
		_:
			return MachineGunDroneScene


func _kind_for_drone(drone: CombatDrone) -> DroneKind:
	if drone is MachineGunDrone:
		return DroneKind.MG
	if drone is LaserDrone:
		return DroneKind.LASER
	return DroneKind.MISSILE


func _is_kind_active(kind: DroneKind) -> bool:
	var drone := _drone_for_kind(kind)
	return drone != null and is_instance_valid(drone) and not drone.is_queued_for_deletion()


func _drone_for_kind(kind: DroneKind) -> CombatDrone:
	match kind:
		DroneKind.LASER:
			return _active_laser
		DroneKind.MISSILE:
			return _active_missile
		_:
			return _active_mg


func _sync_active_slots() -> void:
	if _active_mg != null and (not is_instance_valid(_active_mg) or _active_mg.is_queued_for_deletion()):
		_active_mg = null
	if _active_laser != null and (not is_instance_valid(_active_laser) or _active_laser.is_queued_for_deletion()):
		_active_laser = null
	if _active_missile != null and (not is_instance_valid(_active_missile) or _active_missile.is_queued_for_deletion()):
		_active_missile = null


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


func _drone_spawn_position(track: Node3D) -> Vector3:
	var flat_forward := _facing_xz()
	var ahead_world := track.global_position + flat_forward * spawn_distance_m
	var world_y := track.global_position.y + CombatDroneScript.CRUISE_HEIGHT_M
	if _terrain != null:
		world_y = _terrain.sample_height(ahead_world.x, track.global_position.z) + CombatDroneScript.CRUISE_HEIGHT_M
	return Vector3(ahead_world.x, world_y, track.global_position.z)


func _on_drone_exited(drone: CombatDrone) -> void:
	var kind := _kind_for_drone(drone)
	match kind:
		DroneKind.LASER:
			_active_laser = null
		DroneKind.MISSILE:
			_active_missile = null
		_:
			_active_mg = null
	_respawn_left[kind] = respawn_delay_sec
