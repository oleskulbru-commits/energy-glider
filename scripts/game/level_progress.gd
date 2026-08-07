class_name LevelProgress
extends Node

signal level_changed(level: int)

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath

var current_level := 1

var _rig: PlayerRig
var _terrain: TerrainManager


func _ready() -> void:
	add_to_group("level_progress")
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	call_deferred("_refresh_level")


func _physics_process(_delta: float) -> void:
	_refresh_level()


func get_current_level() -> int:
	return current_level


func _refresh_level() -> void:
	var body := _get_track_body()
	if body == null:
		return
	var origin_x := 0.0
	if _terrain != null:
		origin_x = _terrain.run_origin.x
	var next_level: int = LevelLayout.level_at_world_x(body.global_position.x, origin_x)
	if next_level == current_level:
		return
	current_level = next_level
	level_changed.emit(current_level)


func _get_track_body() -> Node3D:
	if _rig == null or not is_instance_valid(_rig):
		if player_rig_path != NodePath():
			_rig = get_node_or_null(player_rig_path) as PlayerRig
	if _rig == null:
		return null
	return _rig.get_active_body()
