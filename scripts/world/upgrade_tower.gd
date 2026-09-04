class_name UpgradeTower
extends Node3D

const GROUND_OFFSET := 0.05
const BonusTowerPlannerScript := preload("res://scripts/game/bonus_tower_planner.gd")

@export var terrain_manager_path: NodePath
@export var tower_index := 0
@export var is_home := false
@export var is_bonus := false
@export var source_level := 0


func _ready() -> void:
	add_to_group("upgrade_tower")
	call_deferred("snap_to_terrain")


func is_upgrade_stop() -> bool:
	return not is_home and tower_index >= 1


## West tower N and a bonus that appears on level N both heal N * 5.
func visit_heal_level() -> int:
	if is_home:
		return 0
	if is_bonus or BonusTowerPlannerScript.is_bonus_index(tower_index):
		if source_level > 0:
			return source_level
		return BonusTowerPlannerScript.source_level_for_index(tower_index)
	return maxi(tower_index, 0)


func snap_to_terrain() -> void:
	var terrain := _get_terrain_manager()
	if terrain == null:
		return

	var world_x := global_position.x
	var world_z := global_position.z
	var ground_y := terrain.sample_height(world_x, world_z)
	global_position = Vector3(world_x, ground_y + GROUND_OFFSET, world_z)


func _get_terrain_manager() -> TerrainManager:
	if terrain_manager_path != NodePath():
		return get_node_or_null(terrain_manager_path) as TerrainManager

	var parent := get_parent()
	if parent != null:
		return parent.get_node_or_null("TerrainManager") as TerrainManager

	return null
