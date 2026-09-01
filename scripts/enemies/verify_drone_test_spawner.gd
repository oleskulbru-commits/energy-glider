extends SceneTree

const ArenaScene := preload("res://scenes/test/crawler_test_arena.tscn")
const DroneTestSpawnerScript := preload("res://scripts/enemies/drone_test_spawner.gd")
const CombatDroneScript := preload("res://scripts/enemies/combat_drone.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: Node = ArenaScene.instantiate()
	root.add_child(arena)

	await process_frame
	await process_frame
	await process_frame

	var spawner: DroneTestSpawnerScript = arena.get_node_or_null("DroneTestSpawner") as DroneTestSpawnerScript
	_fail_unless(spawner != null, "Missing DroneTestSpawner")
	_fail_unless(spawner._active_laser != null, "Spawner did not spawn laser drone")
	_fail_unless(spawner._active_missile != null, "Spawner did not spawn missile drone")
	_fail_unless(is_instance_valid(spawner._active_laser), "Laser drone invalid")
	_fail_unless(is_instance_valid(spawner._active_missile), "Missile drone invalid")
	_fail_unless(
		spawner._active_laser.get_node_or_null("Visual") != null,
		"Laser drone missing Visual skin"
	)
	_fail_unless(
		spawner._active_missile.get_node_or_null("Visual") != null,
		"Missile drone missing Visual skin"
	)

	var first_laser: CombatDroneScript = spawner._active_laser
	first_laser.take_damage(999, first_laser.global_position)

	await create_timer(0.1).timeout
	_fail_unless(not is_instance_valid(first_laser) or first_laser.is_queued_for_deletion(), "Laser drone should die")

	var waited := 0.0
	var second_laser: CombatDroneScript = null
	while waited < 4.0:
		await create_timer(0.1).timeout
		waited += 0.1
		if (
			spawner._active_laser != null
			and is_instance_valid(spawner._active_laser)
			and spawner._active_laser != first_laser
		):
			second_laser = spawner._active_laser
			break

	_fail_unless(second_laser != null, "Spawner did not respawn laser drone after death")
	print("Drone test arena verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
