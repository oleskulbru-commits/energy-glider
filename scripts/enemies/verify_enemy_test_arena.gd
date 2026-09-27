extends SceneTree

const ArenaScene := preload("res://scenes/test/enemy_test_arena.tscn")
const CrawlerTestSpawnerScript := preload("res://scripts/enemies/crawler_test_spawner.gd")
const DroneTestSpawnerScript := preload("res://scripts/enemies/drone_test_spawner.gd")
const MissileDroneScript := preload("res://scripts/enemies/missile_drone.gd")
const SwarmPillScript := preload("res://scripts/enemies/swarm_pill.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = ArenaScene.instantiate()
	root.add_child(main)

	var arena := main.get_node_or_null("SubViewport/EnemyTestArena") as Node3D
	_fail_unless(arena != null, "Missing SubViewport/EnemyTestArena")

	var spawner := arena.get_node_or_null("CrawlerTestSpawner") as CrawlerTestSpawnerScript
	_fail_unless(spawner != null, "Missing CrawlerTestSpawner")

	var state := arena.get_node_or_null("RunUpgradeState") as RunUpgradeState
	_fail_unless(state != null, "Missing RunUpgradeState in test arena")
	state.grant_starter(UpgradeCatalogScript.FAMILY_RIFLE)

	_fail_unless(
		arena.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"EnemyTestArena should use PROCESS_MODE_PAUSABLE so pause freezes enemies"
	)

	await process_frame
	await process_frame
	await process_frame

	spawner = arena.get_node_or_null("CrawlerTestSpawner") as CrawlerTestSpawnerScript
	_fail_unless(spawner != null, "Missing CrawlerTestSpawner after arena ready")
	_assert_crawler_spawned(spawner._active)

	var drone_spawner := arena.get_node_or_null("DroneTestSpawner") as DroneTestSpawnerScript
	_fail_unless(drone_spawner != null, "Missing DroneTestSpawner")
	_fail_unless(not drone_spawner.spawn_mg, "Test arena should not spawn MG drones")
	_fail_unless(not drone_spawner.spawn_laser, "Test arena should not spawn laser drones")
	_fail_unless(drone_spawner.spawn_missile, "Test arena should spawn missile drones")
	_assert_missile_spawned(drone_spawner._active_missile)

	var first_id := spawner._active.get_instance_id()
	_fail_unless(
		spawner._active.take_damage(999, Vector3(1.0, 0.0, 0.0)),
		"Lethal damage should kill test crawler"
	)
	for _i in 4:
		await process_frame

	var second: SwarmPillScript = await _await_respawn(spawner, first_id)
	if second == null:
		push_error("Spawner did not respawn crawler after despawn")
		quit(1)
		return
	_assert_crawler_spawned(second)

	print("Enemy test arena verification passed.")
	quit(0)


func _assert_missile_spawned(drone: MissileDroneScript) -> void:
	_fail_unless(drone != null, "Spawner did not spawn missile drone")
	_fail_unless(is_instance_valid(drone), "Missile drone invalid")
	_fail_unless(drone.is_alive(), "Spawned missile drone should be alive")


func _assert_crawler_spawned(pill: SwarmPillScript) -> void:
	_fail_unless(pill != null, "Spawner did not spawn crawler")
	_fail_unless(is_instance_valid(pill), "Crawler invalid")
	_fail_unless(pill.is_alive(), "Spawned crawler should be alive")


func _await_respawn(spawner: CrawlerTestSpawnerScript, first_id: int) -> SwarmPillScript:
	for _i in 120:
		await process_frame
		var active := spawner._active
		if active != null and is_instance_valid(active) and active.get_instance_id() != first_id:
			return active
	return null


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
