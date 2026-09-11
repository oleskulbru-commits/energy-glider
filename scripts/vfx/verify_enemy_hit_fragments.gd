extends SceneTree

const EnemyHitFragmentVfxScript := preload("res://scripts/vfx/enemy_hit_fragment_vfx.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")
const CrawlerDebrisSandScript := preload("res://scripts/enemies/crawler_debris_sand.gd")
const DroneDebrisSparkVfxScript := preload("res://scripts/enemies/drone_debris_spark_vfx.gd")
const CRAWLER_KIT := preload("res://assets/vfx/meshes/enemy_fragments/crawler_fragments.glb")
const DRONE_KIT := preload("res://assets/vfx/meshes/enemy_fragments/drone_fragments.glb")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cache_size := EnemyHitFragmentVfxScript.get_kit_mesh_count(CRAWLER_KIT)
	_fail_unless(
		cache_size == 8,
		"Crawler hit fragment kit should cache 8 meshes (got %d)" % cache_size
	)
	var drone_cache_size := EnemyHitFragmentVfxScript.get_kit_mesh_count(DRONE_KIT)
	_fail_unless(
		drone_cache_size == 6,
		"Drone hit fragment kit should cache 6 meshes (got %d)" % drone_cache_size
	)
	_fail_unless(
		EnemyHitFragmentVfxScript.KILL_LIFETIME_SEC == 3.0,
		"Kill fragment lifetime should match death debris fall time (got %s)"
		% str(EnemyHitFragmentVfxScript.KILL_LIFETIME_SEC)
	)
	_fail_unless(
		not UpgradeCatalogScript.weapon_causes_debris_sand(UpgradeCatalogScript.FAMILY_RIFLE),
		"Rifle should not cause debris landing sand"
	)
	_fail_unless(
		UpgradeCatalogScript.weapon_causes_debris_sand(UpgradeCatalogScript.FAMILY_ROCKET),
		"Rocket should cause debris landing sand"
	)
	_fail_unless(
		UpgradeCatalogScript.weapon_causes_debris_sand(UpgradeCatalogScript.FAMILY_TESLA),
		"Tesla should cause debris landing sand"
	)

	var wrapper := EnemyHitFragmentVfxScript.spawn(
		self,
		CRAWLER_KIT,
		Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		2,
		1.0,
		null,
		false,
		UpgradeCatalogScript.FAMILY_RIFLE
	)
	_fail_unless(wrapper != null, "Hit fragment spawn should return a wrapper node")
	await create_timer(0.05).timeout
	_fail_unless(
		_count_rigid_bodies(wrapper) == 2,
		"Normal hit should spawn 2 rigid bodies (got %d)" % _count_rigid_bodies(wrapper)
	)
	_fail_unless(
		_count_debris_sand_nodes(wrapper) == 0,
		"Rifle hit fragments should not attach landing sand (got %d)"
		% _count_debris_sand_nodes(wrapper)
	)
	wrapper.queue_free()

	var tesla_wrapper := EnemyHitFragmentVfxScript.spawn(
		self,
		CRAWLER_KIT,
		Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		2,
		1.0,
		null,
		false,
		UpgradeCatalogScript.FAMILY_TESLA
	)
	await create_timer(0.05).timeout
	_fail_unless(
		_count_debris_sand_nodes(tesla_wrapper) == 2,
		"Tesla hit fragments should attach landing sand (got %d)"
		% _count_debris_sand_nodes(tesla_wrapper)
	)
	tesla_wrapper.queue_free()

	var crit_wrapper := EnemyHitFragmentVfxScript.spawn(
		self,
		CRAWLER_KIT,
		Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		3,
		1.0,
		null
	)
	await create_timer(0.05).timeout
	_fail_unless(
		_count_rigid_bodies(crit_wrapper) == 3,
		"Crit hit should spawn 3 rigid bodies (got %d)" % _count_rigid_bodies(crit_wrapper)
	)
	crit_wrapper.queue_free()

	var kill_wrapper := EnemyHitFragmentVfxScript.spawn(
		self,
		CRAWLER_KIT,
		Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		12,
		1.75,
		null,
		true
	)
	await create_timer(0.05).timeout
	_fail_unless(
		_count_rigid_bodies(kill_wrapper) == 12,
		"Kill hit should spawn 12 rigid bodies (got %d)" % _count_rigid_bodies(kill_wrapper)
	)
	kill_wrapper.queue_free()

	var spark_wrapper := EnemyHitFragmentVfxScript.spawn(
		self,
		CRAWLER_KIT,
		Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		2,
		1.0,
		null,
		true,
		UpgradeCatalogScript.FAMILY_RIFLE,
		Color(2.0, 0.45, 0.08, 1.0),
		true
	)
	await create_timer(0.05).timeout
	_fail_unless(spark_wrapper != null, "Sparked kill fragment spawn should return a wrapper")
	var spark_body := spark_wrapper.get_child(0) as RigidBody3D
	_fail_unless(spark_body != null, "Sparked kill fragment wrapper should contain a rigid body")
	_fail_unless(spark_body.contact_monitor, "Sparked kill fragments should monitor contacts")
	_fail_unless(
		spark_body.get_node_or_null("DebrisSparks") != null,
		"Sparked kill fragments should attach DebrisSparks"
	)
	_fail_unless(
		_count_nodes_with_script(spark_wrapper, DroneDebrisSparkVfxScript) >= 1,
		"Sparked kill fragments should attach DroneDebrisSparkVfx"
	)
	_fail_unless(
		_count_debris_sand_nodes(spark_wrapper) == 2,
		"Sparked kill fragments with death sand should attach landing sand (got %d)"
		% _count_debris_sand_nodes(spark_wrapper)
	)
	spark_wrapper.queue_free()

	print("Enemy hit fragment verification passed.")
	quit(0)


func _count_nodes_with_script(node: Node, script: Script) -> int:
	var count := 0
	if node.get_script() == script:
		count += 1
	for child in node.get_children():
		count += _count_nodes_with_script(child, script)
	return count


func _count_debris_sand_nodes(node: Node) -> int:
	var count := 0
	if node.get_script() == CrawlerDebrisSandScript:
		count += 1
	for child in node.get_children():
		count += _count_debris_sand_nodes(child)
	return count


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
