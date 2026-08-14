class_name UpgradeTower
extends Node3D

const GROUND_OFFSET := 0.05

@export var terrain_manager_path: NodePath


func _ready() -> void:
	add_to_group("upgrade_tower")
	call_deferred("snap_to_terrain")


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
