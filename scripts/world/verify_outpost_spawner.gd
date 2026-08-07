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
	spawner.set("west_tower_count", 3)
	spawner.set("include_home", true)
	await process_frame
	await process_frame
	await process_frame

	var spawned := 0
	var home_found := false
	var west_ok := 0
	var expected_west := [5000.0, 10000.0, 15000.0]
	for node in get_nodes_in_group("upgrade_tower"):
		var s := node as Node3D
		if s == null or s == tower:
			continue
		spawned += 1
		var dx := s.global_position.x - terrain.run_origin.x
		var dz := s.global_position.z - terrain.run_origin.y
		if absf(dx) < 1.0 and absf(dz) < 1.0:
			home_found = true
			continue
		# West chain: −X, near expected spacing, little Z drift (ridge pick ≤ ~80 m).
		if dx >= -100.0:
			continue
		if absf(dz) > 300.0:
			continue
		for dist in expected_west:
			if absf(-dx - dist) < 300.0:
				west_ok += 1
				break

	_fail_unless(home_found, "Expected home tower at run origin")
	_fail_unless(spawned == 4, "Expected home+3 west towers, got %d spawned" % spawned)
	_fail_unless(west_ok == 3, "Expected 3 west towers on −X at 5/10/15 km, got %d" % west_ok)

	print("Outpost spawner verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
