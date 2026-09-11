class_name BossDirector
extends Node3D

## Westbound bosses at every 8th tower. One living encounter at a time.

signal boss_spawned(boss: Node)
signal boss_health_changed(current: int, max_hp: int)
signal boss_despawned

const SunEaterScene := preload("res://scenes/enemies/sun_eater.tscn")
const EonDirectorScript := preload("res://scripts/game/eon_director.gd")

## Westbound bosses. First is at tower 1 for testing; later fights stay on 16/24/32/40.
const BOSS_TOWER_INDEXES: Array[int] = [1, 16, 24, 32, 40]
const BOSS_INTERVAL := 8
const HP_PER_ORDINAL := 5000
const SPAWN_TRIGGER_EAST_M := 200.0
const SPAWN_EAST_OF_TOWER_M := 100.0

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var eon_director_path: NodePath
@export var tower_visit_path: NodePath

var _rig: PlayerRig
var _terrain: TerrainManager
var _eon: EonDirectorScript
var _visit: TowerVisitController
var _living: SunEater
var _living_tower_index := 0
var _defeated: Dictionary = {}


func _ready() -> void:
	add_to_group("boss_director")
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	if eon_director_path != NodePath():
		_eon = get_node_or_null(eon_director_path) as EonDirectorScript
	if tower_visit_path != NodePath():
		_visit = get_node_or_null(tower_visit_path) as TowerVisitController
	call_deferred("_bind_director")


func _bind_director() -> void:
	if _eon == null:
		_eon = get_tree().get_first_node_in_group("eon_director") as EonDirectorScript
	if _eon == null or not _eon.has_signal("attempt_started"):
		return
	if not _eon.attempt_started.is_connected(reset_living_boss):
		_eon.attempt_started.connect(reset_living_boss)


func _process(_delta: float) -> void:
	_try_spawn()


static func is_boss_tower(tower_index: int) -> bool:
	return boss_ordinal(tower_index) > 0


static func boss_ordinal(tower_index: int) -> int:
	var found := BOSS_TOWER_INDEXES.find(tower_index)
	if found < 0:
		return 0
	return found + 1


static func max_health_for_tower(tower_index: int) -> int:
	var ordinal := boss_ordinal(tower_index)
	if ordinal <= 0:
		return 0
	return HP_PER_ORDINAL * ordinal


static func spawn_x_for_tower(tower_x: float) -> float:
	return tower_x + SPAWN_EAST_OF_TOWER_M


static func has_reached_trigger(player_x: float, tower_x: float) -> bool:
	return player_x <= tower_x + SPAWN_TRIGGER_EAST_M


static func can_start_encounter(tower_index: int, has_living: bool, defeated: Dictionary) -> bool:
	if has_living or not is_boss_tower(tower_index):
		return false
	if bool(defeated.get(tower_index, false)):
		return false
	var ordinal := boss_ordinal(tower_index)
	for i in range(ordinal - 1):
		if not bool(defeated.get(BOSS_TOWER_INDEXES[i], false)):
			return false
	return true


func has_living_boss() -> bool:
	return _living != null and is_instance_valid(_living) and _living.is_alive()


func is_blocking_upgrades() -> bool:
	return has_living_boss()


func is_blocking_stream() -> bool:
	return has_living_boss() and _living.is_blocking_stream()


func is_defeated(tower_index: int) -> bool:
	return bool(_defeated.get(tower_index, false))


func living_boss() -> SunEater:
	if has_living_boss():
		return _living
	return null


func player_body() -> Node3D:
	return _player_body()


func reset_living_boss() -> void:
	_clear_living(false)
	boss_despawned.emit()


func _try_spawn() -> void:
	if has_living_boss():
		return
	var player := _player_body()
	if player == null:
		return
	if player.has_method("is_run_ended") and bool(player.call("is_run_ended")):
		return
	var tower := _next_spawn_tower(player.global_position.x)
	if tower == null:
		return
	_spawn_at_tower(tower, player)


func _next_spawn_tower(player_x: float) -> UpgradeTower:
	var living := has_living_boss()
	for index in BOSS_TOWER_INDEXES:
		if not can_start_encounter(index, living, _defeated):
			continue
		var tower := _tower_by_index(index)
		if tower == null:
			continue
		if has_reached_trigger(player_x, tower.global_position.x):
			return tower
	return null


func _spawn_at_tower(tower: UpgradeTower, player: Node3D) -> void:
	var spawn_x := spawn_x_for_tower(tower.global_position.x)
	var spawn_z := tower.global_position.z
	var ground_y := tower.global_position.y
	if _terrain != null:
		ground_y = _terrain.sample_height(spawn_x, spawn_z)
	var boss := SunEaterScene.instantiate() as SunEater
	add_child(boss)
	boss.global_position = Vector3(spawn_x, SunEater.buried_y(ground_y), spawn_z)
	boss.configure(_terrain, player, 0.0)
	boss.configure_encounter(tower.tower_index, max_health_for_tower(tower.tower_index))
	boss.begin_ascent(ground_y)
	if not boss.died.is_connected(_on_boss_died):
		boss.died.connect(_on_boss_died)
	if not boss.health_changed.is_connected(_on_boss_health_changed):
		boss.health_changed.connect(_on_boss_health_changed)
	_living = boss
	_living_tower_index = tower.tower_index
	boss_spawned.emit(boss)
	boss_health_changed.emit(boss.get_health(), boss.get_max_health())


func _on_boss_health_changed(current: int, max_hp: int) -> void:
	boss_health_changed.emit(current, max_hp)


func _on_boss_died() -> void:
	var index := _living_tower_index
	_defeated[index] = true
	_clear_living(true)
	boss_despawned.emit()
	var tower := _tower_by_index(index)
	if tower == null or _visit == null:
		return
	_visit.call_deferred("open_boss_reward", tower)


func _clear_living(already_dying: bool) -> void:
	if _living != null and is_instance_valid(_living):
		if _living.died.is_connected(_on_boss_died):
			_living.died.disconnect(_on_boss_died)
		if _living.health_changed.is_connected(_on_boss_health_changed):
			_living.health_changed.disconnect(_on_boss_health_changed)
		if not already_dying:
			_living.queue_free()
	_living = null
	_living_tower_index = 0


func _tower_by_index(index: int) -> UpgradeTower:
	if get_tree() == null:
		return null
	for node in get_tree().get_nodes_in_group("upgrade_tower"):
		var tower := node as UpgradeTower
		if tower != null and tower.tower_index == index:
			return tower
	return null


func _player_body() -> Node3D:
	if _rig == null and player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if _rig == null:
		return null
	var glider := _rig.get_glider()
	if glider != null:
		return glider
	return _rig.get_active_body()
