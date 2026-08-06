class_name GodJuiceDirector
extends Node

signal juice_spawned(position: Vector3)
signal juice_collected
signal integrity_changed(integrity: int)
signal run_started
signal player_died(position: Vector3)

enum Phase { AWAITING_JUICE, RUNNING }

const INTEGRITY_START := 100
const INTEGRITY_LOSS_PER_DEATH := 20
const JUICE_REVEAL_DISTANCE_M := 1000.0
const JUICE_FIRST_SPAWN_MIN_M := 80.0
const JUICE_FIRST_SPAWN_MAX_M := 150.0
const JUICE_RIDGE_SAMPLE_RADIUS_M := 80.0
const JUICE_RIDGE_SAMPLE_STEPS := 8

const GodJuicePickupScene := preload("res://scenes/game/god_juice_pickup.tscn")
const GodJuicePickupScript := preload("res://scripts/game/god_juice_pickup.gd")

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var run_score_path: NodePath
@export var expedition_state_path: NodePath

var phase: Phase = Phase.AWAITING_JUICE
var integrity: int = INTEGRITY_START
var death_position := Vector3.ZERO
var awaiting_death_choice := false

var _rig: PlayerRig
var _terrain: TerrainManager
var _run_score: RunScore
var _expedition: ExpeditionState
var _juice: GodJuicePickupScript
var _spawn_position := Vector3.ZERO
var _spawn_yaw := 0.0
var _run_bootstrapped := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("god_juice_director")
	_rng.randomize()
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	if run_score_path != NodePath():
		_run_score = get_node_or_null(run_score_path) as RunScore
	if expedition_state_path != NodePath():
		_expedition = get_node_or_null(expedition_state_path) as ExpeditionState
	call_deferred("_boot")


func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_spawn_pose()
	_connect_player()
	_spawn_juice_near_start()
	phase = Phase.AWAITING_JUICE


func _process(_delta: float) -> void:
	if _juice == null or phase != Phase.AWAITING_JUICE or _rig == null:
		return
	var body := _rig.get_active_body()
	if body != null and _juice.try_collect(body):
		_on_juice_collected()


func _connect_player() -> void:
	var glider := _get_glider()
	if glider == null:
		return
	if not glider.run_ended.is_connected(_on_player_run_ended):
		glider.run_ended.connect(_on_player_run_ended)


func _capture_spawn_pose() -> void:
	if _rig == null:
		return
	_spawn_position = _rig.get_spawn_position()
	_spawn_yaw = _rig.get_spawn_yaw()


func _get_glider() -> GliderPlayer:
	if _rig == null:
		return null
	return _rig.get_glider()


func is_awaiting_juice() -> bool:
	return phase == Phase.AWAITING_JUICE


func is_run_active() -> bool:
	return phase == Phase.RUNNING


func can_try_again() -> bool:
	return integrity > 0


func get_juice_position() -> Vector3:
	if _juice == null or not is_instance_valid(_juice):
		return Vector3.ZERO
	return _juice.get_world_position()


func get_juice_distance(from: Vector3) -> float:
	var juice_pos := get_juice_position()
	if juice_pos == Vector3.ZERO:
		return INF
	return MathUtil.horizontal_distance(from, juice_pos)


func should_show_juice_tracker(from: Vector3) -> bool:
	return (
		phase == Phase.AWAITING_JUICE
		and get_juice_distance(from) <= JUICE_REVEAL_DISTANCE_M
	)


func get_juice_bearing(from: Vector3) -> float:
	var juice_pos := get_juice_position()
	if juice_pos == Vector3.ZERO:
		return NAN
	return MathUtil.bearing_to(from, juice_pos)


func request_try_again() -> void:
	if not awaiting_death_choice or not can_try_again():
		return
	awaiting_death_choice = false
	_soft_retry()


func request_restart() -> void:
	get_tree().reload_current_scene()


func kill_player_for_debug() -> void:
	var glider := _get_glider()
	if glider != null and not glider.is_run_ended():
		glider.end_run("death")


func _on_juice_collected() -> void:
	_despawn_juice()
	phase = Phase.RUNNING
	juice_collected.emit()
	_bootstrap_run()
	run_started.emit()


func _bootstrap_run() -> void:
	if _run_bootstrapped:
		if _run_score != null:
			_run_score.set_scoring_enabled(true)
			_run_score.reset_after_death()
		return
	_run_bootstrapped = true
	if _run_score != null:
		_run_score.set_scoring_enabled(true)
	if _expedition != null:
		_expedition.bootstrap_day()


func _on_player_run_ended() -> void:
	var glider := _get_glider()
	if glider == null or glider.get_end_reason() != "death":
		return
	if phase != Phase.RUNNING:
		return
	death_position = _rig.get_tracking_position()
	phase = Phase.AWAITING_JUICE
	integrity = apply_death_integrity_loss(integrity)
	integrity_changed.emit(integrity)
	awaiting_death_choice = true
	player_died.emit(death_position)


func _soft_retry() -> void:
	if _rig != null:
		_rig.reset_to_spawn()
	var glider := _get_glider()
	if glider != null:
		glider.reset_for_respawn()
	if _run_score != null:
		_run_score.reset_after_death()
	_spawn_juice_at(death_position)
	phase = Phase.AWAITING_JUICE


func _spawn_juice_near_start() -> void:
	var bearing := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(JUICE_FIRST_SPAWN_MIN_M, JUICE_FIRST_SPAWN_MAX_M)
	var offset := MathUtil.yaw_forward(bearing) * distance
	var approx := _spawn_position + offset
	_spawn_juice_at(approx)


func _spawn_juice_at(world_pos: Vector3) -> void:
	_despawn_juice()
	var placed_xz := _pick_ridge_xz(world_pos)
	var height := _sample_ground_y(placed_xz.x, placed_xz.y)
	var spawn_pos := Vector3(placed_xz.x, height + 1.2, placed_xz.y)

	_juice = GodJuicePickupScene.instantiate() as GodJuicePickupScript
	add_child(_juice)
	_juice.global_position = spawn_pos
	juice_spawned.emit(spawn_pos)


func _despawn_juice() -> void:
	if _juice != null and is_instance_valid(_juice):
		_juice.queue_free()
	_juice = null


func _pick_ridge_xz(approx: Vector3) -> Vector2:
	var best := Vector2(approx.x, approx.z)
	if _terrain == null:
		return best
	var best_h := _terrain.sample_height(best.x, best.y)
	var steps := maxi(JUICE_RIDGE_SAMPLE_STEPS, 1)
	for i in steps:
		var angle := float(i) / float(steps) * TAU
		var x := approx.x + cos(angle) * JUICE_RIDGE_SAMPLE_RADIUS_M
		var z := approx.z + sin(angle) * JUICE_RIDGE_SAMPLE_RADIUS_M
		var h := _terrain.sample_height(x, z)
		if h > best_h:
			best_h = h
			best = Vector2(x, z)
	var center_h := _terrain.sample_height(approx.x, approx.z)
	if center_h >= best_h:
		return Vector2(approx.x, approx.z)
	return best


func _sample_ground_y(world_x: float, world_z: float) -> float:
	if _terrain != null:
		return _terrain.sample_height(world_x, world_z)
	return 0.0


static func apply_death_integrity_loss(current: int, loss: int = INTEGRITY_LOSS_PER_DEATH) -> int:
	return maxi(current - loss, 0)


static func can_try_again_with_integrity(current: int) -> bool:
	return current > 0
