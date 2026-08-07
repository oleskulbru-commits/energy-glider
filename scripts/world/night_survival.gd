class_name NightSurvival
extends Node

signal night_warning
signal safe_changed(is_safe: bool)

const UNPROTECTED_KILL_SEC := 30.0
const NIGHT_WARNING_TEXT := "Night has arrived. Get to an upgrade tower or face the darkness."

@export var day_night_path: NodePath
@export var player_rig_path: NodePath

var _day_night: DayNightCycle
var _rig: PlayerRig
var _unprotected_sec := 0.0
var _is_safe := false
var _killed_this_night := false


func _ready() -> void:
	add_to_group("night_survival")
	if day_night_path != NodePath():
		_day_night = get_node_or_null(day_night_path) as DayNightCycle
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if _day_night != null:
		_day_night.dusk.connect(_on_dusk)
		_day_night.dawn.connect(_on_dawn)
		if _day_night.is_night():
			_on_dusk()


func _process(delta: float) -> void:
	if _day_night == null or not _day_night.is_night():
		return

	var glider := _get_glider()
	if _killed_this_night and glider != null and not glider.is_run_ended():
		# Soft retry / respawn while night remains — re-arm the unprotected timer.
		_killed_this_night = false
		_unprotected_sec = 0.0

	var safe_now := is_safe_in_hub()
	if safe_now != _is_safe:
		_set_safe(safe_now)
		if not safe_now:
			# Left the hub while still night — kill timer restarts.
			_unprotected_sec = 0.0
			_killed_this_night = false

	if _is_safe or _killed_this_night:
		return

	_unprotected_sec += delta
	if _unprotected_sec >= UNPROTECTED_KILL_SEC:
		_kill_player()


func is_safe() -> bool:
	return _is_safe


func get_unprotected_sec() -> float:
	return _unprotected_sec


func is_safe_in_hub() -> bool:
	var body := _get_track_body()
	if body == null:
		return false
	return _any_hub_contains(body.global_position)


func _any_hub_contains(world_pos: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("upgrade_tower"):
		if not (node is Node3D):
			continue
		var hub := node as Node3D
		var xz := Vector2(world_pos.x - hub.global_position.x, world_pos.z - hub.global_position.z)
		if xz.length() <= AntennaState.HUB_RADIUS_M:
			return true
	return false


static func should_kill_unprotected(unprotected_sec: float, kill_sec: float = UNPROTECTED_KILL_SEC) -> bool:
	return unprotected_sec >= kill_sec


func _on_dusk() -> void:
	_unprotected_sec = 0.0
	_killed_this_night = false
	night_warning.emit()
	_set_safe(is_safe_in_hub())


func _on_dawn() -> void:
	_unprotected_sec = 0.0
	_killed_this_night = false
	_set_safe(false)


func _set_safe(value: bool) -> void:
	if _is_safe == value:
		return
	_is_safe = value
	if _is_safe:
		_unprotected_sec = 0.0
	safe_changed.emit(_is_safe)


func _kill_player() -> void:
	var glider := _get_glider()
	if glider == null or glider.is_run_ended():
		return
	_killed_this_night = true
	glider.end_run("death")


func _get_glider() -> GliderPlayer:
	if _rig == null:
		return null
	return _rig.get_glider()


func _get_track_body() -> Node3D:
	if _rig == null:
		return null
	return _rig.get_active_body()
