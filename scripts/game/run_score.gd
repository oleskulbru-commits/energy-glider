class_name RunScore
extends Node

@export var player_path: NodePath
@export var terrain_manager_path: NodePath

var _player: GliderPlayer
var _rig: PlayerRig
var _terrain_manager: TerrainManager
var _distance_m := 0.0
var _day_start_distance_m := 0.0
var _ended := false
var _final_distance_m := 0.0


func _ready() -> void:
	add_to_group("run_score")

	if player_path != NodePath():
		var node := get_node_or_null(player_path)
		_rig = node as PlayerRig
		if _rig != null:
			_player = _rig.get_node_or_null("Glider") as GliderPlayer
		else:
			_player = node as GliderPlayer
	if terrain_manager_path != NodePath():
		_terrain_manager = get_node_or_null(terrain_manager_path) as TerrainManager

	if _player != null:
		_player.run_ended.connect(_on_run_ended)


func _process(_delta: float) -> void:
	if _ended or _terrain_manager == null:
		return

	var track_pos := _get_track_position()
	if track_pos == null:
		return

	var player_xz := Vector2(track_pos.x, track_pos.z)
	_distance_m = player_xz.distance_to(_terrain_manager.run_origin)


func _get_track_position() -> Vector3:
	if _rig != null:
		return _rig.get_tracking_position()
	if _player != null:
		return _player.global_position
	return Vector3.ZERO


func _on_run_ended() -> void:
	if _ended:
		return
	_ended = true
	_final_distance_m = _distance_m


func is_ended() -> bool:
	return _ended


func get_distance_m() -> float:
	return _final_distance_m if _ended else _distance_m


func get_daily_distance_m() -> float:
	return maxf(get_distance_m() - _day_start_distance_m, 0.0)


func begin_new_day() -> void:
	_day_start_distance_m = get_distance_m()


func get_final_distance_m() -> float:
	return _final_distance_m


func format_distance() -> String:
	return MathUtil.format_distance_m(get_distance_m())
