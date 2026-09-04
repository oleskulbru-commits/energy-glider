extends SceneTree

const ArenaScene := preload("res://scenes/test/crawler_test_arena.tscn")
const DroneTestSpawnerScript := preload("res://scripts/enemies/drone_test_spawner.gd")
const MachineGunDroneScript := preload("res://scripts/enemies/machine_gun_drone.gd")
const LaserDroneScript := preload("res://scripts/enemies/laser_drone.gd")
const MissileDroneScript := preload("res://scripts/enemies/missile_drone.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: Node = ArenaScene.instantiate()
	root.add_child(arena)

	var state := arena.get_node_or_null("RunUpgradeState") as RunUpgradeState
	_fail_unless(state != null, "Missing RunUpgradeState in test arena")
	state.grant_starter(UpgradeCatalogScript.FAMILY_RIFLE)

	_fail_unless(
		arena.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"CrawlerTestArena should use PROCESS_MODE_PAUSABLE so pause freezes enemies"
	)

	await process_frame
	await process_frame
	await process_frame

	var spawner: DroneTestSpawnerScript = arena.get_node_or_null("DroneTestSpawner") as DroneTestSpawnerScript
	_fail_unless(spawner != null, "Missing DroneTestSpawner")
	_assert_drone_spawned(spawner._active_mg, "machine gun", spawner._active_mg is MachineGunDroneScript)
	_assert_drone_spawned(spawner._active_laser, "laser", spawner._active_laser is LaserDroneScript)
	_assert_drone_spawned(spawner._active_missile, "missile", spawner._active_missile is MissileDroneScript)

	var first_mg_id := spawner._active_mg.get_instance_id()
	spawner._active_mg.queue_free()

	await create_timer(0.1).timeout

	var second_mg: MachineGunDroneScript = await _await_respawn(
		func() -> CombatDrone:
			return spawner._active_mg,
		first_mg_id
	) as MachineGunDroneScript
	_fail_unless(second_mg != null, "Spawner did not respawn machine gun drone after despawn")

	var first_laser_id := spawner._active_laser.get_instance_id()
	spawner._active_laser.queue_free()

	await create_timer(0.1).timeout
	var second_laser: LaserDroneScript = await _await_respawn(
		func() -> CombatDrone:
			return spawner._active_laser,
		first_laser_id
	) as LaserDroneScript
	_fail_unless(second_laser != null, "Spawner did not respawn laser drone after despawn")

	print("Drone test arena verification passed.")
	quit(0)


func _assert_drone_spawned(drone: CombatDrone, label: String, type_ok: bool) -> void:
	_fail_unless(drone != null, "Spawner did not spawn %s drone" % label)
	_fail_unless(is_instance_valid(drone), "%s drone invalid" % label.capitalize())
	_fail_unless(type_ok, "Active drone should be %s" % label)
	_fail_unless(drone.get_node_or_null("Visual") != null, "%s drone missing Visual skin" % label.capitalize())


func _await_respawn(get_active: Callable, first_id: int) -> CombatDrone:
	var waited := 0.0
	while waited < 4.0:
		await create_timer(0.1).timeout
		waited += 0.1
		var active: CombatDrone = get_active.call()
		if active != null and is_instance_valid(active) and active.get_instance_id() != first_id:
			return active
	return null


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
