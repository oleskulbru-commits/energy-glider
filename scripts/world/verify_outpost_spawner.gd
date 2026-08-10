extends SceneTree

const OutpostSpawnerScript = preload("res://scripts/world/outpost_spawner.gd")
const UpgradeTowerScript = preload("res://scripts/world/upgrade_tower.gd")
const TerrainManagerScript = preload("res://scripts/terrain/terrain_manager.gd")
const LevelLayoutScript = preload("res://scripts/game/level_layout.gd")
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

	var LevelRunScript = preload("res://scripts/game/level_run.gd")
	var LevelRunGeneratorScript = preload("res://scripts/game/level_run_generator.gd")
	LevelRunScript.ensure(42)

	var expected_offsets: Array[float] = LevelLayoutScript.tower_x_offsets_from_origin()
	_fail_unless(expected_offsets.size() == 40, "Expected 40 west tower offsets")
	var journey := LevelRunGeneratorScript.total_journey_m()
	_fail_unless(
		is_equal_approx(expected_offsets[0], -1000.0)
		and is_equal_approx(expected_offsets[1], -2000.0)
		and is_equal_approx(expected_offsets[4], -7000.0)
		and is_equal_approx(expected_offsets[39], -journey),
		"Unexpected level tower offsets: %s" % str(expected_offsets)
	)
	_fail_unless(LevelLayoutScript.level_at_world_x(40.0) == 1, "Spawn X should be level 1")
	_fail_unless(LevelLayoutScript.level_at_world_x(-1000.0) == 2, "At first west tower should be level 2")
	_fail_unless(LevelLayoutScript.level_at_world_x(-journey) == 40, "At last tower should be level 40")

	var spawner: Node = OutpostSpawnerScript.new()
	spawner.name = "OutpostSpawner"
	root_node.add_child(spawner)
	spawner.set("terrain_manager_path", spawner.get_path_to(terrain))
	spawner.set("include_home", true)
	await process_frame
	await process_frame
	await process_frame

	var spawned := 0
	var home_found := false
	var west_ok := 0
	var matched_offsets: Dictionary = {}
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
		if absf(dz) > 100.0:
			continue
		for offset_x in expected_offsets:
			# X must stay on the planned west distance (ridge snap is Z-only).
			if absf(dx - offset_x) < 0.5 and not matched_offsets.has(offset_x):
				matched_offsets[offset_x] = true
				west_ok += 1
				break

	_fail_unless(home_found, "Expected home tower at run origin")
	_fail_unless(spawned == 41, "Expected home+40 west towers, got %d spawned" % spawned)
	_fail_unless(west_ok == 40, "Expected 40 west towers on planned X, got %d" % west_ok)

	print("Outpost spawner verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
