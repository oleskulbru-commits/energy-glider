extends SceneTree

const ArenaScene := preload("res://scenes/test/enemy_test_arena.tscn")
const CrawlerTestSpawnerScript := preload("res://scripts/enemies/crawler_test_spawner.gd")
const LeaperTestSpawnerScript := preload("res://scripts/enemies/leaper_test_spawner.gd")
const SwarmPillScript := preload("res://scripts/enemies/swarm_pill.gd")
const LeaperPillScript := preload("res://scripts/enemies/leaper_pill.gd")
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

	_fail_unless(
		arena.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"EnemyTestArena should use PROCESS_MODE_PAUSABLE so pause freezes enemies"
	)
	_fail_unless(
		arena.get_node_or_null("DroneTestSpawner") == null,
		"Test arena should not spawn drones"
	)

	var leaper_spawner := arena.get_node_or_null("LeaperTestSpawner") as LeaperTestSpawnerScript
	_fail_unless(leaper_spawner != null, "Missing LeaperTestSpawner")
	_fail_unless(
		is_equal_approx(leaper_spawner.spawn_distance_m, LeaperPillScript.LEAP_RANGE_MAX_M),
		"Test leaper should spawn at leap range"
	)

	for _i in 60:
		await process_frame
		if spawner._active != null and leaper_spawner._active != null:
			break

	_assert_crawler_spawned(spawner._active)
	_assert_leaper_spawned(leaper_spawner._active)
	if spawner._active == null or leaper_spawner._active == null:
		return

	state.grant_starter(UpgradeCatalogScript.FAMILY_RIFLE)

	var crawler_id := spawner._active.get_instance_id()
	_fail_unless(
		spawner._active.take_damage(999, Vector3(1.0, 0.0, 0.0)),
		"Lethal damage should kill test crawler"
	)
	var crawler_again: SwarmPillScript = await _await_active(spawner, crawler_id)
	if crawler_again == null:
		push_error("Spawner did not respawn crawler after despawn")
		quit(1)
		return
	_assert_crawler_spawned(crawler_again)

	var leaper_id := leaper_spawner._active.get_instance_id()
	_fail_unless(
		leaper_spawner._active.take_damage(999, Vector3(1.0, 0.0, 0.0)),
		"Lethal damage should kill test leaper"
	)
	var leaper_again: LeaperPillScript = await _await_active(leaper_spawner, leaper_id)
	if leaper_again == null:
		push_error("Spawner did not respawn leaper after despawn")
		quit(1)
		return
	_assert_leaper_spawned(leaper_again)

	print("Enemy test arena verification passed.")
	quit(0)


func _assert_leaper_spawned(pill: LeaperPillScript) -> void:
	if not _fail_unless(pill != null, "Spawner did not spawn leaper"):
		return
	if not _fail_unless(is_instance_valid(pill), "Leaper invalid"):
		return
	_fail_unless(pill.is_alive(), "Spawned leaper should be alive")
	_fail_unless(pill.is_in_group("leaper_pill"), "Test leaper should join leaper_pill")
	_fail_unless(pill.get_node_or_null("Visual") != null, "Test leaper should keep the skinned visual")


func _assert_crawler_spawned(pill: SwarmPillScript) -> void:
	if not _fail_unless(pill != null, "Spawner did not spawn crawler"):
		return
	if not _fail_unless(is_instance_valid(pill), "Crawler invalid"):
		return
	_fail_unless(pill.is_alive(), "Spawned crawler should be alive")


func _await_active(spawner: Node, first_id: int) -> SwarmPillScript:
	var deadline_msec := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline_msec:
		await process_frame
		var active: SwarmPillScript = spawner.get("_active") as SwarmPillScript
		if active != null and is_instance_valid(active) and active.get_instance_id() != first_id:
			return active
	return null


func _fail_unless(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
