class_name EnemyStreamSpawner
extends Node3D

## Spawns crawlers and chargers ahead of the glider after the run has started.
## New game waits for the first E.O.N. pickup. Try Again keeps spawning even
## before the E.O.N. is collected again.

const SwarmPillScene := preload("res://scenes/enemies/swarm_pill.tscn")
const ChargerPillScene := preload("res://scenes/enemies/charger_pill.tscn")
const SwarmPillScript := preload("res://scripts/enemies/swarm_pill.gd")
const EonDirectorScript := preload("res://scripts/game/eon_director.gd")

const SPAWN_GRACE_SEC := 3.0
const DAWN_SPAWN_GRACE_SEC := 2.0
## 1 charger per 5 crawlers → one sixth of spawns.
const CHARGER_SPAWN_CHANCE := 1.0 / 6.0
## Chargers unlock after crossing tower 3 (level 4+).
const CHARGER_MIN_LEVEL := 4

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var eon_director_path: NodePath

@export var spawn_interval_sec := 0.35
@export var spawns_per_tick_max := 2

var _rig: PlayerRig
var _terrain: TerrainManager
var _director: EonDirectorScript
var _rng := RandomNumberGenerator.new()
var _spawn_cooldown := 0.0
var _grace_left := 0.0
var _active: Array[Node] = []


func _ready() -> void:
	add_to_group("enemy_stream_spawner")
	_rng.randomize()
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	if eon_director_path != NodePath():
		_director = get_node_or_null(eon_director_path) as EonDirectorScript
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	var glider := _get_glider()
	if glider != null and not glider.run_ended.is_connected(_on_run_ended):
		glider.run_ended.connect(_on_run_ended)
	if _director != null and _director.has_signal("run_started"):
		if not _director.run_started.is_connected(_on_run_started):
			_director.run_started.connect(_on_run_started)
	if _director != null and _director.has_signal("attempt_started"):
		if not _director.attempt_started.is_connected(_on_run_started):
			_director.attempt_started.connect(_on_run_started)


func _on_run_started() -> void:
	_grace_left = SPAWN_GRACE_SEC


func _on_run_ended() -> void:
	clear_stream()
	_grace_left = 0.0


func _physics_process(delta: float) -> void:
	_cull_active()
	_spawn_cooldown = maxf(_spawn_cooldown - delta, 0.0)
	if _grace_left > 0.0:
		_grace_left = maxf(_grace_left - delta, 0.0)

	if not _should_spawn():
		return

	var level := _current_level()
	var cap := SwarmPillScript.active_cap_for_level(level)
	if _active.size() >= cap:
		return
	if _spawn_cooldown > 0.0:
		return

	var track := _track_body()
	if track == null:
		return

	var ahead := SwarmPillScript.ahead_range_for_level(level)
	var spread := SwarmPillScript.z_spread_for_level(level)
	var speed := SwarmPillScript.move_speed_for_level(level)
	var to_spawn := mini(spawns_per_tick_max, cap - _active.size())
	for _i in to_spawn:
		_spawn_one(track, ahead, spread, speed, level)

	_spawn_cooldown = spawn_interval_sec


func clear_stream() -> void:
	for node in _active:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_active.clear()


func reset_after_dawn() -> void:
	clear_stream()
	_grace_left = DAWN_SPAWN_GRACE_SEC
	_spawn_cooldown = 0.0


func _should_spawn() -> bool:
	var glider := _get_glider()
	var run_ended := glider == null or glider.is_run_ended()
	var run_active := _director != null and _director.is_run_active()
	var bootstrapped := _director != null and _director.has_collected_eon()
	if not should_spawn_stream(run_active, bootstrapped, run_ended):
		return false
	if _grace_left > 0.0:
		return false
	return true


static func should_spawn_stream(run_active: bool, run_bootstrapped: bool, run_ended: bool) -> bool:
	if run_ended:
		return false
	return run_active or run_bootstrapped


func _current_level() -> int:
	var progress := get_tree().get_first_node_in_group("level_progress")
	if progress != null and progress.has_method("get_current_level"):
		return maxi(int(progress.get_current_level()), 1)
	return 1


func _track_body() -> Node3D:
	if _rig == null:
		return null
	return _rig.get_active_body()


func _get_glider() -> GliderPlayer:
	if _rig == null:
		return null
	return _rig.get_glider()


func _spawn_one(track: Node3D, ahead: Vector2, spread: float, speed: float, level: int) -> void:
	var offset := spawn_offset_along_facing(ahead.x, ahead.y, spread, _rng, _facing_xz())
	var world_x := track.global_position.x + offset.x
	var world_z := track.global_position.z + offset.y
	var world_y := track.global_position.y
	if _terrain != null:
		world_y = _terrain.sample_height(world_x, world_z)

	var scene: PackedScene = SwarmPillScene
	if level >= CHARGER_MIN_LEVEL and _rng.randf() < CHARGER_SPAWN_CHANCE:
		scene = ChargerPillScene
	var pill: SwarmPillScript = scene.instantiate() as SwarmPillScript
	add_child(pill)
	pill.global_position = Vector3(world_x, world_y, world_z)
	pill.configure(_terrain, track, speed)
	var bonus := 0.0
	if _director != null:
		bonus = _director.difficulty_bonus()
	pill.apply_difficulty(bonus)
	_active.append(pill)


func _facing_xz() -> Vector3:
	var glider := _get_glider()
	if glider == null:
		return Vector3(-1.0, 0.0, 0.0)
	var fwd := MathUtil.yaw_forward(glider.get_yaw())
	if fwd.length_squared() < 0.0001:
		return Vector3(-1.0, 0.0, 0.0)
	return fwd.normalized()


## Ahead + lateral in the player's facing frame → world XZ offset.
static func spawn_offset_along_facing(
	ahead_min_m: float,
	ahead_max_m: float,
	spread_m: float,
	rng: RandomNumberGenerator,
	facing_xz: Vector3
) -> Vector2:
	var fwd := Vector3(facing_xz.x, 0.0, facing_xz.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(-1.0, 0.0, 0.0)
	else:
		fwd = fwd.normalized()
	## +lateral matches westbound +Z when facing −X.
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	var ahead_m := rng.randf_range(ahead_min_m, ahead_max_m)
	var lat := rng.randf_range(-spread_m, spread_m)
	var world := fwd * ahead_m + right * lat
	return Vector2(world.x, world.z)


func _cull_active() -> void:
	var alive: Array[Node] = []
	for node in _active:
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			alive.append(node)
	_active = alive
