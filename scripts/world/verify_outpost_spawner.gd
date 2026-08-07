extends SceneTree

const OutpostSpawnerScript = preload("res://scripts/world/outpost_spawner.gd")
const UpgradeTowerScript = preload("res://scripts/world/upgrade_tower.gd")
const TerrainManagerScript = preload("res://scripts/terrain/terrain_manager.gd")
const SandMaterial = preload("res://materials/sand.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_node := Node.new()
	root_node.name = "VerifyOutpostRoot"
	root.add_child(root_node)

	var terrain: TerrainManager = TerrainManagerScript.new()
	terrain.sand_material = SandMaterial
	terrain.name = "TerrainManager"
	root_node.add_child(terrain)
	await process_frame

	var tower: UpgradeTower = UpgradeTowerScript.new()
	tower.name = "OffsetTower"
	root_node.add_child(tower)
	tower.terrain_manager_path = tower.get_path_to(terrain)
	tower.global_position = Vector3(250.0, 0.0, -180.0)
	tower.snap_to_terrain()
	_fail_unless(
		absf(tower.global_position.x - 250.0) < 0.01
		and absf(tower.global_position.z + 180.0) < 0.01,
		"Tower snap should keep XZ (got %s)" % tower.global_position
	)
	var expected_y := terrain.sample_height(250.0, -180.0) + 0.05
	_fail_unless(
		absf(tower.global_position.y - expected_y) < 0.05,
		"Tower should snap Y to terrain height"
	)

	var spawner: Node = OutpostSpawnerScript.new()
	spawner.name = "OutpostSpawner"
	root_node.add_child(spawner)
	spawner.set("terrain_manager_path", spawner.get_path_to(terrain))
	spawner.set("outpost_spacing_m", 5000.0)
	spawner.set("ring_count", 1)
	spawner.set("include_home", true)
	await process_frame
	await process_frame
	await process_frame

	var spawned := 0
	var home_found := false
	var ring_ok := 0
	for node in get_nodes_in_group("upgrade_tower"):
		var s := node as Node3D
		if s == null or s == tower:
			continue
		spawned += 1
		var flat := Vector2(
			s.global_position.x - terrain.run_origin.x,
			s.global_position.z - terrain.run_origin.y
		)
		if flat.length() < 200.0:
			home_found = true
		elif absf(flat.length() - 5000.0) < 300.0:
			ring_ok += 1

	_fail_unless(home_found, "Expected a home outpost near run origin")
	_fail_unless(spawned >= 7, "Expected home+6 outposts, got %d spawned" % spawned)
	_fail_unless(ring_ok >= 5, "Expected ~6 ring outposts near 5 km, got %d" % ring_ok)

	print("Outpost spawner verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
