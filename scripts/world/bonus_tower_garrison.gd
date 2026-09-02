class_name BonusTowerGarrison
extends Node3D

## Lazy camps around bonus towers. Must be wiped before the upgrade visit.

const BonusTowerPlannerScript := preload("res://scripts/game/bonus_tower_planner.gd")
const SwarmPillScene := preload("res://scenes/enemies/swarm_pill.tscn")
const ChargerPillScene := preload("res://scenes/enemies/charger_pill.tscn")
const LaserDroneScene := preload("res://scenes/enemies/laser_drone.tscn")
const MissileDroneScene := preload("res://scenes/enemies/missile_drone.tscn")
const SwarmPillScript := preload("res://scripts/enemies/swarm_pill.gd")
const CombatDroneScript := preload("res://scripts/enemies/combat_drone.gd")
const EonDirectorScript := preload("res://scripts/game/eon_director.gd")

const SPAWN_RANGE_M := 500.0
const RING_RADIUS_MIN_M := 25.0
const RING_RADIUS_MAX_M := 40.0

@export var player_rig_path: NodePath
@export var terrain_manager_path: NodePath
@export var eon_director_path: NodePath

var _rig: PlayerRig
var _terrain: TerrainManager
var _director: EonDirectorScript
var _rng := RandomNumberGenerator.new()
var _camps: Dictionary = {} # tower_index -> Dictionary


func _ready() -> void:
	add_to_group("bonus_tower_garrison")
	_rng.randomize()
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if terrain_manager_path != NodePath():
		_terrain = get_node_or_null(terrain_manager_path) as TerrainManager
	if eon_director_path != NodePath():
		_director = get_node_or_null(eon_director_path) as EonDirectorScript


func _process(_delta: float) -> void:
	var player := _player_body()
	if player == null:
		return
	for node in get_tree().get_nodes_in_group("upgrade_tower"):
		var tower := node as UpgradeTower
		if tower == null or not tower.is_bonus:
			continue
		_tick_tower(tower, player.global_position)


func is_visit_locked(tower: UpgradeTower) -> bool:
	if tower == null or not tower.is_bonus:
		return false
	var camp: Dictionary = _camps.get(tower.tower_index, {})
	var cleared := bool(camp.get("cleared", false))
	var spawned := bool(camp.get("spawned", false))
	var alive := _alive_count(camp)
	return BonusTowerPlannerScript.visit_locked(cleared, spawned, alive)


func _tick_tower(tower: UpgradeTower, player_pos: Vector3) -> void:
	var index := tower.tower_index
	if not _camps.has(index):
		_camps[index] = {
			"spawned": false,
			"cleared": false,
			"units": [],
		}
	var camp: Dictionary = _camps[index]
	if bool(camp.get("cleared", false)):
		return
	_prune_units(camp)
	if bool(camp.get("spawned", false)):
		if _alive_count(camp) <= 0:
			camp["cleared"] = true
			_camps[index] = camp
			return
		if BonusTowerPlannerScript.should_skip_despawn(player_pos, tower.global_position):
			_despawn_camp(camp)
			camp["spawned"] = false
			_camps[index] = camp
		return
	if BonusTowerPlannerScript.should_spawn_garrison(
		player_pos,
		tower.global_position,
		false,
		false,
		SPAWN_RANGE_M
	):
		_spawn_camp(tower, camp)


func _spawn_camp(tower: UpgradeTower, camp: Dictionary) -> void:
	var world_seed := LevelRun.world_seed()
	if world_seed < 0:
		world_seed = 42
	var level := tower.source_level if tower.source_level > 0 else BonusTowerPlannerScript.source_level_for_index(tower.tower_index)
	var plan := BonusTowerPlannerScript.garrison_plan(world_seed, level)
	var count := int(plan.get("count", 0))
	if count <= 0:
		camp["cleared"] = true
		camp["spawned"] = true
		return
	var player := _player_body()
	var units: Array = []
	var laser_left := int(plan.get("laser_count", 0))
	var charger_left := int(plan.get("charger_count", 0))
	var kind := String(plan.get("kind", BonusTowerPlannerScript.KIND_GROUND))
	_rng.seed = int(world_seed) * 881 + tower.tower_index * 443
	for i in count:
		var radius := _rng.randf_range(RING_RADIUS_MIN_M, RING_RADIUS_MAX_M)
		var pos := tower.global_position + BonusTowerPlannerScript.ring_offset(i, count, radius)
		if _terrain != null:
			pos.y = _terrain.sample_height(pos.x, pos.z)
		var unit: Node3D
		if kind == BonusTowerPlannerScript.KIND_DRONE:
			var use_laser := laser_left > 0
			if use_laser:
				laser_left -= 1
			unit = _spawn_drone(pos, player, use_laser, level)
		else:
			var use_charger := charger_left > 0
			if use_charger:
				charger_left -= 1
			unit = _spawn_ground(pos, player, use_charger)
		if unit == null:
			continue
		if unit.has_method("bind_garrison"):
			unit.bind_garrison(tower.global_position)
		units.append(unit)
	camp["units"] = units
	camp["spawned"] = true
	camp["cleared"] = units.is_empty()


func _spawn_ground(pos: Vector3, track: Node3D, charger: bool) -> Node3D:
	var scene: PackedScene = ChargerPillScene if charger else SwarmPillScene
	var pill: SwarmPillScript = scene.instantiate() as SwarmPillScript
	add_child(pill)
	pill.global_position = pos
	pill.configure(_terrain, track, SwarmPillScript.DEFAULT_SPEED)
	_apply_difficulty(pill)
	return pill


func _spawn_drone(pos: Vector3, track: Node3D, laser: bool, level: int) -> Node3D:
	var scene: PackedScene = LaserDroneScene if laser else MissileDroneScene
	var drone: CombatDroneScript = scene.instantiate() as CombatDroneScript
	add_child(drone)
	drone.global_position = pos
	drone.configure(_terrain, track, CombatDroneScript.move_speed_for_drone_level(maxi(level, CombatDroneScript.DRONE_MIN_LEVEL)))
	_apply_difficulty(drone)
	return drone


func _apply_difficulty(unit: Node) -> void:
	if unit == null or not unit.has_method("apply_difficulty"):
		return
	var bonus := 0.0
	if _director != null:
		bonus = _director.difficulty_bonus()
	unit.apply_difficulty(bonus)


func _despawn_camp(camp: Dictionary) -> void:
	for unit in camp.get("units", []):
		if unit != null and is_instance_valid(unit):
			unit.queue_free()
	camp["units"] = []


func _prune_units(camp: Dictionary) -> void:
	var living: Array = []
	for unit in camp.get("units", []):
		if unit != null and is_instance_valid(unit):
			living.append(unit)
	camp["units"] = living


func _alive_count(camp: Dictionary) -> int:
	var n := 0
	for unit in camp.get("units", []):
		if unit != null and is_instance_valid(unit):
			n += 1
	return n


func _player_body() -> Node3D:
	if _rig == null:
		if player_rig_path != NodePath():
			_rig = get_node_or_null(player_rig_path) as PlayerRig
	if _rig == null:
		return null
	return _rig.get_active_body()
