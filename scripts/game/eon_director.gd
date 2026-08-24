class_name EonDirector
extends Node

signal eon_spawned(position: Vector3)
signal eon_collected
signal integrity_changed(integrity: int)
signal run_started
signal player_died(position: Vector3)
signal objective_changed(text: String)

enum Phase { AWAITING_EON, RUNNING }

const INTEGRITY_START := 100
const INTEGRITY_LOSS_PER_DEATH := 20
const EON_FIRST_SPAWN_MIN_M := 80.0
const EON_FIRST_SPAWN_MAX_M := 150.0
const EON_RIDGE_SAMPLE_RADIUS_M := 80.0
const EON_RIDGE_SAMPLE_STEPS := 8
const OBJECTIVE_RETRIEVE := "Retrieve the E.O.N"

const EonPickupScene := preload("res://scenes/game/eon_pickup.tscn")
const EonPickupScript := preload("res://scripts/game/eon_pickup.gd")
const LevelLayoutScript = preload("res://scripts/game/level_layout.gd")

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var run_score_path: NodePath
@export var expedition_state_path: NodePath
@export var day_night_path: NodePath
@export var death_overlay_delay_sec := 6.0
@export var death_fade_lead_sec := 1.0

## Next westbound upgrade tower (1 = first tower). Updated from LevelProgress.
var next_upgrade_tower_label := "1"

var phase: Phase = Phase.AWAITING_EON
var integrity: int = INTEGRITY_START
var death_position := Vector3.ZERO
var awaiting_death_choice := false
var death_fade_active := false

var _rig: PlayerRig
var _terrain: TerrainManager
var _run_score: RunScore
var _expedition: ExpeditionState
var _day_night: DayNightCycle
var _eon: EonPickupScript
var _spawn_position := Vector3.ZERO
var _spawn_yaw := 0.0
var _run_bootstrapped := false
var _respawn_eon_at_death := false
var _death_overlay_timer: SceneTreeTimer = null
var _death_fade_timer: SceneTreeTimer = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("eon_director")
	_rng.randomize()
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	if run_score_path != NodePath():
		_run_score = get_node_or_null(run_score_path) as RunScore
	if expedition_state_path != NodePath():
		_expedition = get_node_or_null(expedition_state_path) as ExpeditionState
	if day_night_path != NodePath():
		_day_night = get_node_or_null(day_night_path) as DayNightCycle
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night_cycle") as DayNightCycle
	call_deferred("_boot")


func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_spawn_pose()
	_connect_player()
	_connect_level_progress()
	_sync_next_tower_label()
	_spawn_eon_near_start()
	phase = Phase.AWAITING_EON
	objective_changed.emit(get_objective_text())


func _process(_delta: float) -> void:
	if _eon == null or phase != Phase.AWAITING_EON or _rig == null:
		return
	var glider := _get_glider()
	var run_ended := glider != null and glider.is_run_ended()
	if not can_collect_eon_while(awaiting_death_choice, run_ended):
		return
	var body := _rig.get_active_body()
	if body != null and _eon.try_collect(body):
		_on_eon_collected()


func _connect_player() -> void:
	var glider := _get_glider()
	if glider == null:
		return
	if not glider.run_ended.is_connected(_on_player_run_ended):
		glider.run_ended.connect(_on_player_run_ended)


func _connect_level_progress() -> void:
	var progress := get_tree().get_first_node_in_group("level_progress")
	if progress == null:
		return
	if progress.has_signal("level_changed") and not progress.level_changed.is_connected(_on_level_changed):
		progress.level_changed.connect(_on_level_changed)


func _on_level_changed(level: int) -> void:
	var previous := next_upgrade_tower_label
	_sync_next_tower_label(level)
	if phase == Phase.RUNNING and next_upgrade_tower_label != previous:
		objective_changed.emit(get_objective_text())


func _sync_next_tower_label(level: int = -1) -> void:
	var tower_n := level
	if tower_n < 1:
		var progress := get_tree().get_first_node_in_group("level_progress")
		if progress != null and progress.has_method("get_current_level"):
			tower_n = int(progress.get_current_level())
		else:
			tower_n = 1
	var max_tower := maxi(LevelLayoutScript.segment_count(), 1)
	next_upgrade_tower_label = str(clampi(tower_n, 1, max_tower))


func _capture_spawn_pose() -> void:
	if _rig == null:
		return
	_spawn_position = _rig.get_spawn_position()
	_spawn_yaw = _rig.get_spawn_yaw()


func _get_glider() -> GliderPlayer:
	if _rig == null:
		return null
	return _rig.get_glider()


func is_awaiting_eon() -> bool:
	return phase == Phase.AWAITING_EON


func is_run_active() -> bool:
	return phase == Phase.RUNNING


func can_try_again() -> bool:
	return integrity > 0


func has_collected_eon() -> bool:
	return _run_bootstrapped


func get_objective_text() -> String:
	if phase == Phase.AWAITING_EON:
		return OBJECTIVE_RETRIEVE
	return "Travel west and get to upgrade tower %s" % next_upgrade_tower_label


func get_eon_position() -> Vector3:
	if _eon == null or not is_instance_valid(_eon):
		return Vector3.ZERO
	return _eon.get_world_position()


func get_eon_distance(from: Vector3) -> float:
	var eon_pos := get_eon_position()
	if eon_pos == Vector3.ZERO:
		return INF
	return MathUtil.horizontal_distance(from, eon_pos)


func should_show_eon_tracker(_from: Vector3) -> bool:
	return should_show_eon_tracker_for(
		phase == Phase.AWAITING_EON,
		get_eon_position() != Vector3.ZERO
	)


func get_eon_bearing(from: Vector3) -> float:
	var eon_pos := get_eon_position()
	if eon_pos == Vector3.ZERO:
		return NAN
	return MathUtil.bearing_to(from, eon_pos)


func request_try_again() -> void:
	if not awaiting_death_choice or not can_try_again():
		return
	_cancel_death_overlay_timer()
	awaiting_death_choice = false
	_soft_retry()


const RUN_SESSION_PATH := "user://run_session.cfg"


func request_restart() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("terrain", "world_seed", randi())
	cfg.save(RUN_SESSION_PATH)
	get_tree().reload_current_scene()


func kill_player_for_debug() -> void:
	var glider := _get_glider()
	if glider != null and not glider.is_run_ended():
		glider.end_run("death")


func _on_eon_collected() -> void:
	_despawn_eon()
	phase = Phase.RUNNING
	eon_collected.emit()
	_bootstrap_run()
	_sync_next_tower_label()
	run_started.emit()
	objective_changed.emit(get_objective_text())


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
	if awaiting_death_choice:
		return
	death_position = _rig.get_tracking_position() if _rig != null else Vector3.ZERO
	# Only re-drop at death if the E.O.N was collected this attempt (despawned).
	# If it is already on the ground awaiting pickup, leave it where it is.
	# Integrity still deteriorates after the first-ever pickup for this run.
	_respawn_eon_at_death = should_respawn_eon_at_death(phase == Phase.RUNNING)
	phase = Phase.AWAITING_EON
	if should_apply_integrity_loss_on_death(_run_bootstrapped):
		integrity = apply_death_integrity_loss(integrity)
		integrity_changed.emit(integrity)
	if death_overlay_delay_sec <= 0.0:
		death_fade_active = true
		_show_death_overlay()
		return
	_cancel_death_timers()
	death_fade_active = false
	var fade_delay := maxf(death_overlay_delay_sec - death_fade_lead_sec, 0.0)
	if fade_delay <= 0.0:
		death_fade_active = true
	else:
		_death_fade_timer = get_tree().create_timer(fade_delay)
		_death_fade_timer.timeout.connect(_on_death_fade_timer_timeout)
	_death_overlay_timer = get_tree().create_timer(death_overlay_delay_sec)
	_death_overlay_timer.timeout.connect(_on_death_overlay_timer_timeout)


func _on_death_fade_timer_timeout() -> void:
	_death_fade_timer = null
	if awaiting_death_choice:
		return
	var glider := _get_glider()
	if glider == null or not glider.is_run_ended() or glider.get_end_reason() != "death":
		return
	death_fade_active = true


func _on_death_overlay_timer_timeout() -> void:
	_death_overlay_timer = null
	if awaiting_death_choice:
		return
	var glider := _get_glider()
	if glider == null or not glider.is_run_ended() or glider.get_end_reason() != "death":
		return
	_show_death_overlay()


func _show_death_overlay() -> void:
	if awaiting_death_choice:
		return
	awaiting_death_choice = true
	player_died.emit(death_position)
	objective_changed.emit(get_objective_text())


func _cancel_death_timers() -> void:
	if _death_fade_timer != null:
		if _death_fade_timer.timeout.is_connected(_on_death_fade_timer_timeout):
			_death_fade_timer.timeout.disconnect(_on_death_fade_timer_timeout)
		_death_fade_timer = null
	if _death_overlay_timer != null:
		if _death_overlay_timer.timeout.is_connected(_on_death_overlay_timer_timeout):
			_death_overlay_timer.timeout.disconnect(_on_death_overlay_timer_timeout)
		_death_overlay_timer = null
	death_fade_active = false


func _cancel_death_overlay_timer() -> void:
	_cancel_death_timers()


func _soft_retry() -> void:
	_cancel_death_overlay_timer()
	# Teleport first while the run is still ended so proximity pickup cannot fire
	# against a death-spot E.O.N before the player is back at start.
	if _rig != null:
		_rig.reset_to_spawn()
	if _run_score != null:
		_run_score.reset_after_death()
	if _respawn_eon_at_death:
		_spawn_eon_at_ground(death_position)
	elif _eon == null or not is_instance_valid(_eon):
		_spawn_eon_near_start()
	_respawn_eon_at_death = false
	var glider := _get_glider()
	if glider != null:
		glider.reset_for_respawn()
	if _rig != null:
		# Snap again after respawn height correction so the camera does not lerp.
		_rig.snap_camera_now()
	if _day_night != null:
		_day_night.skip_to_dawn()
	phase = Phase.AWAITING_EON
	objective_changed.emit(get_objective_text())


func _spawn_eon_near_start() -> void:
	var bearing := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(EON_FIRST_SPAWN_MIN_M, EON_FIRST_SPAWN_MAX_M)
	var offset := MathUtil.yaw_forward(bearing) * distance
	var approx := _spawn_position + offset
	_spawn_eon_at(approx, true)


func _spawn_eon_at_ground(world_pos: Vector3) -> void:
	_spawn_eon_at(world_pos, false)


func _spawn_eon_at(world_pos: Vector3, snap_to_ridge: bool = true) -> void:
	_despawn_eon()
	if _terrain != null:
		_terrain.ensure_loaded_at(world_pos)
	var placed_xz := (
		_pick_ridge_xz(world_pos) if snap_to_ridge else Vector2(world_pos.x, world_pos.z)
	)
	var height := _sample_ground_y(placed_xz.x, placed_xz.y)
	var spawn_pos := Vector3(placed_xz.x, height + 0.08, placed_xz.y)

	_eon = EonPickupScene.instantiate() as EonPickupScript
	add_child(_eon)
	_eon.global_position = spawn_pos
	eon_spawned.emit(spawn_pos)


func _despawn_eon() -> void:
	if _eon != null and is_instance_valid(_eon):
		_eon.queue_free()
	_eon = null


func _pick_ridge_xz(approx: Vector3) -> Vector2:
	var best := Vector2(approx.x, approx.z)
	if _terrain == null:
		return best
	var best_h := _terrain.sample_height(best.x, best.y)
	var steps := maxi(EON_RIDGE_SAMPLE_STEPS, 1)
	for i in steps:
		var angle := float(i) / float(steps) * TAU
		var x := approx.x + cos(angle) * EON_RIDGE_SAMPLE_RADIUS_M
		var z := approx.z + sin(angle) * EON_RIDGE_SAMPLE_RADIUS_M
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


static func should_apply_integrity_loss_on_death(has_collected_eon: bool) -> bool:
	return has_collected_eon


static func should_respawn_eon_at_death(was_carrying_eon: bool) -> bool:
	return was_carrying_eon


static func should_show_eon_tracker_for(phase_awaiting: bool, eon_exists: bool) -> bool:
	return phase_awaiting and eon_exists


static func can_collect_eon_while(awaiting_death: bool, run_ended: bool) -> bool:
	return not awaiting_death and not run_ended
