extends SceneTree

const ArenaScene := preload("res://scenes/test/crawler_test_arena.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: Node = ArenaScene.instantiate()
	root.add_child(arena)

	await process_frame
	await process_frame
	await process_frame

	var spawner := arena.get_node_or_null("CrawlerTestSpawner") as CrawlerTestSpawner
	_fail_unless(spawner != null, "Missing CrawlerTestSpawner")
	_fail_unless(spawner._active != null, "Spawner did not spawn an enemy")

	var first := spawner._active
	_fail_unless(is_instance_valid(first), "First enemy invalid")
	first.take_damage(999, first.global_position)

	await create_timer(0.1).timeout
	_fail_unless(not is_instance_valid(first) or first.is_queued_for_deletion(), "Enemy should die")

	var waited := 0.0
	var second: SwarmPill = null
	while waited < 3.0:
		await create_timer(0.1).timeout
		waited += 0.1
		if spawner._active != null and is_instance_valid(spawner._active) and spawner._active != first:
			second = spawner._active
			break

	_fail_unless(second != null, "Spawner did not respawn after death")
	print("Crawler test arena verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
