class_name OutpostSpawner
extends Node3D

const UPGRADE_TOWER_SCENE := preload("res://scenes/world/upgrade_tower.tscn")

@export var terrain_manager_path: NodePath
@export var include_home := true
@export var ridge_sample_radius_m := 80.0
@export var ridge_sample_steps := 8


func _ready() -> void:
	call_deferred("_spawn_outposts")


func _spawn_outposts() -> void:
	var terrain := _get_terrain_manager()
	var origin := Vector3.ZERO
	if terrain != null:
		origin = Vector3(terrain.run_origin.x, 0.0, terrain.run_origin.y)

	var planned: Array[Dictionary] = []
	if include_home:
		planned.append({ "pos": origin, "is_home": true })

	for offset_x in LevelLayout.tower_x_offsets_from_origin():
		var west := origin + Vector3(offset_x, 0.0, 0.0)
		planned.append({ "pos": west, "is_home": false })

	for entry in planned:
		_spawn_one(entry.pos as Vector3, terrain, bool(entry.is_home))


func _spawn_one(approx: Vector3, terrain: TerrainManager, is_home: bool) -> void:
	var placed_xz := Vector2(approx.x, approx.z)
	if not is_home:
		placed_xz = _pick_ridge_xz(approx, terrain)
	var tower: UpgradeTower = UPGRADE_TOWER_SCENE.instantiate() as UpgradeTower
	add_child(tower)
	if terrain != null:
		tower.terrain_manager_path = tower.get_path_to(terrain)
	tower.global_position = Vector3(placed_xz.x, 0.0, placed_xz.y)
	tower.snap_to_terrain()


func _pick_ridge_xz(approx: Vector3, terrain: TerrainManager) -> Vector2:
	var best := Vector2(approx.x, approx.z)
	if terrain == null:
		return best
	var best_h := terrain.sample_height(best.x, best.y)
	var steps := maxi(ridge_sample_steps, 1)
	for i in steps:
		var angle := float(i) / float(steps) * TAU
		var x := approx.x + cos(angle) * ridge_sample_radius_m
		var z := approx.z + sin(angle) * ridge_sample_radius_m
		var h := terrain.sample_height(x, z)
		if h > best_h:
			best_h = h
			best = Vector2(x, z)
	# Also try center.
	var center_h := terrain.sample_height(approx.x, approx.z)
	if center_h >= best_h:
		return Vector2(approx.x, approx.z)
	return best


func _get_terrain_manager() -> TerrainManager:
	if terrain_manager_path != NodePath():
		return get_node_or_null(terrain_manager_path) as TerrainManager
	return get_parent().get_node_or_null("TerrainManager") as TerrainManager
