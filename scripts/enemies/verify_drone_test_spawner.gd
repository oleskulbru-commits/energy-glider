extends SceneTree

const ArenaScene := preload("res://scenes/test/crawler_test_arena.tscn")
const DroneTestSpawnerScript := preload("res://scripts/enemies/drone_test_spawner.gd")
const MachineGunDroneScript := preload("res://scripts/enemies/machine_gun_drone.gd")


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
	_fail_unless(spawner._active_mg != null, "Spawner did not spawn machine gun drone")
	_fail_unless(is_instance_valid(spawner._active_mg), "Machine gun drone invalid")
	_fail_unless(
		spawner._active_mg is MachineGunDroneScript,
		"Active drone should be MachineGunDrone"
	)
	_fail_unless(
		spawner._active_mg.get_node_or_null("Visual") != null,
		"Machine gun drone missing Visual skin"
	)

	var first_mg: MachineGunDroneScript = spawner._active_mg
	first_mg.queue_free()

	await create_timer(0.1).timeout
	_fail_unless(
		not is_instance_valid(first_mg) or first_mg.is_queued_for_deletion(),
		"Machine gun drone should despawn"
	)

	var waited := 0.0
	var second_mg: MachineGunDroneScript = null
	while waited < 4.0:
		await create_timer(0.1).timeout
		waited += 0.1
		if (
			spawner._active_mg != null
			and is_instance_valid(spawner._active_mg)
			and spawner._active_mg != first_mg
		):
			second_mg = spawner._active_mg
			break

	_fail_unless(second_mg != null, "Spawner did not respawn machine gun drone after despawn")
	print("Drone test arena verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
