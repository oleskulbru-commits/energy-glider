class_name ExpeditionState
extends Node

signal day_started(day: int)
signal day_ended(summary: Dictionary)
signal score_changed(total: int)

@export var player_rig_path: NodePath
@export var run_score_path: NodePath
@export var day_night_path: NodePath

var current_day := 1
var total_score := 0
var last_day_score := 0
var last_day_summary: Dictionary = {}

var _run_score: RunScore
var _day_night: DayNightCycle
var _rig: Node3D
var _bootstrapped := false


func _ready() -> void:
	add_to_group("expedition_state")
	if run_score_path != NodePath():
		_run_score = get_node_or_null(run_score_path) as RunScore
	if day_night_path != NodePath():
		_day_night = get_node_or_null(day_night_path) as DayNightCycle
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as Node3D


func bootstrap_day() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true
	if _run_score != null:
		_run_score.begin_new_day()
	day_started.emit(current_day)


func end_day() -> void:
	last_day_summary = _build_day_summary()
	last_day_score = int(last_day_summary.get("score", 0))
	total_score += last_day_score
	score_changed.emit(total_score)
	day_ended.emit(last_day_summary)

	if _run_score != null:
		_run_score.begin_new_day()

	current_day += 1
	if _day_night != null:
		_day_night.skip_to_dawn()
	day_started.emit(current_day)


func _build_day_summary() -> Dictionary:
	var daily_distance := 0.0
	if _run_score != null:
		daily_distance = _run_score.get_daily_distance_m()

	var score := int(roundf(daily_distance * 0.5))

	return {
		"day": current_day,
		"distance_m": daily_distance,
		"score": score,
		"total_score": total_score + score,
	}
