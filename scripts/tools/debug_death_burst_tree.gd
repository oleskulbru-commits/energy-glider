extends SceneTree

const CrawlerDeathBurstScript := preload("res://scripts/enemies/crawler_death_burst.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	CrawlerDeathBurstScript.spawn(self, Transform3D.IDENTITY, Vector3(-2.0, 0.5, 0.0))
	await create_timer(0.05).timeout
	print("root children: ", get_root().get_child_count())
	for child in get_root().get_children():
		print(" ", child.name, " (", child.get_class(), ") children=", child.get_child_count())
		for grand in child.get_children():
			print("   ", grand.name, " (", grand.get_class(), ") children=", grand.get_child_count())
			for gg in grand.get_children():
				print("      ", gg.name, " (", gg.get_class(), ")")
	var bodies := _count_rigid_bodies(get_root())
	print("bodies=", bodies)
	quit(0)


func _count_rigid_bodies(node: Node) -> int:
	var count := 1 if node is RigidBody3D else 0
	for child in node.get_children():
		count += _count_rigid_bodies(child)
	return count
