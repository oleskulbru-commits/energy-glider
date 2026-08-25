extends SceneTree

const CrawlerDeathBurstScript := preload("res://scripts/enemies/crawler_death_burst.gd")

const EXPECTED_MIN_SHARDS := 10


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	CrawlerDeathBurstScript.spawn(self, Transform3D.IDENTITY, Vector3(-2.0, 0.5, 0.0))
	await create_timer(0.05).timeout
	var bodies := _count_rigid_bodies(get_root())
	_fail_unless(bodies >= EXPECTED_MIN_SHARDS, "Death burst should spawn rigid shard bodies (got %d, need >= %d)" % [bodies, EXPECTED_MIN_SHARDS])
	print("Crawler death burst verified with %d rigid bodies." % bodies)
	quit(0)


func _count_rigid_bodies(node: Node) -> int:
	var count := 0
	if node is RigidBody3D:
		count += 1
	for child in node.get_children():
		count += _count_rigid_bodies(child)
	return count


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
