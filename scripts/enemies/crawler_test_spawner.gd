class_name CrawlerTestSpawner
extends Node3D

## Spawns a single crawler ahead of the player; respawns after death.

const SwarmPillScene := preload("res://scenes/enemies/crawler/swarm_pill.tscn")

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var spawn_distance_m := 15.0
@export var respawn_delay_sec := 0.0

var _rig: PlayerRig
var _terrain: TerrainManager
var _active: SwarmPill
var _respawn_seq := 0
var _respawn_pending := false


func _ready() -> void:
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	call_deferred("_spawn_one")


func _physics_process(_delta: float) -> void:
	if _active != null and is_instance_valid(_active) and not _active.is_queued_for_deletion():
		return
	_active = null


func _spawn_one() -> void:
	_respawn_pending = false
	if _terrain == null or _rig == null:
		return
	var track := _rig.get_active_body()
	if track == null:
		return
	if _active != null and is_instance_valid(_active) and not _active.is_queued_for_deletion():
		return

	var pill: SwarmPill = SwarmPillScene.instantiate() as SwarmPill
	add_child(pill)
	if not pill.died.is_connected(_on_enemy_died):
		pill.died.connect(_on_enemy_died)
	if not pill.tree_exiting.is_connected(_on_enemy_tree_exiting):
		pill.tree_exiting.connect(_on_enemy_tree_exiting.bind(pill), CONNECT_ONE_SHOT)

	var spawn_xz := _spawn_position_xz(track)
	pill.global_position = Vector3(spawn_xz.x, track.global_position.y, spawn_xz.y)
	pill.configure(_terrain, track, SwarmPill.DEFAULT_SPEED)
	_active = pill


func _spawn_position_xz(track: Node3D) -> Vector2:
	var flat_forward := Vector3(-1.0, 0.0, 0.0)
	var glider := _rig.get_glider()
	if glider != null:
		flat_forward = Vector3(-glider.global_transform.basis.z.x, 0.0, -glider.global_transform.basis.z.z)
		if flat_forward.length_squared() > 0.0001:
			flat_forward = flat_forward.normalized()
		else:
			flat_forward = Vector3(-1.0, 0.0, 0.0)
	return Vector2(
		track.global_position.x + flat_forward.x * spawn_distance_m,
		track.global_position.z + flat_forward.z * spawn_distance_m
	)


func _on_enemy_died() -> void:
	_clear_active()
	_schedule_respawn()


func _on_enemy_tree_exiting(pill: SwarmPill) -> void:
	if _active != pill:
		return
	_clear_active()
	_schedule_respawn()


func _clear_active() -> void:
	_active = null


func _schedule_respawn() -> void:
	if _respawn_pending:
		return
	_respawn_pending = true
	_respawn_seq += 1
	if respawn_delay_sec <= 0.0:
		call_deferred("_spawn_one")
		return
	var seq := _respawn_seq
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(respawn_delay_sec)
	timer.timeout.connect(func() -> void: _spawn_one_after_death(seq), CONNECT_ONE_SHOT)


func _spawn_one_after_death(seq: int) -> void:
	if seq != _respawn_seq:
		return
	_spawn_one()
