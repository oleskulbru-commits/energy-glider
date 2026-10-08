class_name LeaperMovesetDirector
extends Node3D

## Drives a leaper through in-game hop timing on a dummy, ignoring the player.

const LeaperPillScene := preload("res://scenes/enemies/leaper_pill.tscn")

const EAST := Vector3(1.0, 0.0, 0.0)
const RUN_LEAD_M := 50.0
const HOPS_PER_DIR := 2
const FACING_DISTANCE_M := 30.0

@export var terrain_manager_path: NodePath
@export var hops_per_dir := HOPS_PER_DIR
@export var run_lead_m := RUN_LEAD_M

var _terrain: TerrainManager
var _dummy: Marker3D
var _leaper: LeaperPill
var _heading := EAST
var _hops_in_dir := 0


func _ready() -> void:
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	_dummy = Marker3D.new()
	_dummy.name = "LeapDummy"
	add_child(_dummy)
	call_deferred("_spawn_leaper")


func _physics_process(_delta: float) -> void:
	if _leaper == null or not is_instance_valid(_leaper) or _leaper.is_queued_for_deletion():
		return
	if _leaper._is_spawn_active():
		return
	if not _leaper._has_leapt or _leaper.leap_state != LeaperPill.LeapState.CHASE:
		return
	_hops_in_dir += 1
	if _hops_in_dir >= hops_per_dir:
		_heading = -_heading
		_hops_in_dir = 0
	_leaper.set_practice_facing(_heading)
	_place_dummy_for_facing()
	_leaper.reset_for_next_hop(run_lead_m)


func _spawn_leaper() -> void:
	if _terrain == null or _dummy == null:
		return
	if _leaper != null and is_instance_valid(_leaper):
		return
	var pill: LeaperPill = LeaperPillScene.instantiate() as LeaperPill
	add_child(pill)
	pill.enable_practice_lane(true, _heading, run_lead_m)
	pill.global_position = Vector3.ZERO
	_place_dummy_for_facing_from(pill.global_position)
	pill.configure(_terrain, _dummy)
	_leaper = pill
	if _terrain != null:
		_terrain.set_track_node(pill)


func _place_dummy_for_facing() -> void:
	if _leaper == null or not is_instance_valid(_leaper):
		return
	_place_dummy_for_facing_from(_leaper.global_position)


func _place_dummy_for_facing_from(from: Vector3) -> void:
	var aim := from + _heading * FACING_DISTANCE_M
	var y := aim.y
	if _terrain != null:
		y = _terrain.sample_height(aim.x, aim.z)
	_dummy.global_position = Vector3(aim.x, y, aim.z)
