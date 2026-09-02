extends SceneTree

const BonusTowerPlannerScript := preload("res://scripts/game/bonus_tower_planner.gd")
const LevelRunScript := preload("res://scripts/game/level_run.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")
const UpgradeTowerScript := preload("res://scripts/world/upgrade_tower.gd")
const TowerVisitControllerScript := preload("res://scripts/game/tower_visit_controller.gd")
const OutpostSpawnerScript := preload("res://scripts/world/outpost_spawner.gd")
const BonusTowerGarrisonScript := preload("res://scripts/world/bonus_tower_garrison.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_spawn_chance()
	_verify_no_early_levels()
	_verify_deterministic()
	_verify_window_cap()
	_verify_placement_and_tiers()
	_verify_offer_counts()
	_verify_radar_copy()
	_verify_tower_flags()
	_verify_garrison_plan()
	await _verify_garrison_visit_lock()
	await _verify_spawner_bonus_flags()
	if _failed:
		quit(1)
		return
	print("Bonus tower verification passed.")
	quit(0)


func _verify_spawn_chance() -> void:
	_fail_unless(
		is_equal_approx(BonusTowerPlannerScript.spawn_chance(0), 0.12),
		"Base spawn chance should be 12%"
	)
	_fail_unless(
		is_equal_approx(BonusTowerPlannerScript.spawn_chance(1), 0.20),
		"One miss should raise spawn chance to 20%"
	)
	_fail_unless(
		is_equal_approx(BonusTowerPlannerScript.spawn_chance(6), 0.60),
		"Spawn chance should cap at 60%"
	)
	_fail_unless(
		is_equal_approx(BonusTowerPlannerScript.spawn_chance(20), 0.60),
		"Spawn chance should stay capped"
	)


func _verify_no_early_levels() -> void:
	for seed in [1, 42, 99, 2026]:
		var planned: Array[Dictionary] = BonusTowerPlannerScript.plan(seed)
		for entry in planned:
			_fail_unless(
				int(entry.get("level", 0)) >= BonusTowerPlannerScript.MIN_LEVEL,
				"Levels 1-3 should never get a bonus tower"
			)


func _verify_deterministic() -> void:
	var a: Array[Dictionary] = BonusTowerPlannerScript.plan(42)
	var b: Array[Dictionary] = BonusTowerPlannerScript.plan(42)
	_fail_unless(a.size() == b.size(), "Same seed should plan the same number of bonus towers")
	for i in a.size():
		_fail_unless(
			int(a[i].get("level", -1)) == int(b[i].get("level", -2))
			and int(a[i].get("tier", -1)) == int(b[i].get("tier", -2))
			and bool(a[i].get("north", false)) == bool(b[i].get("north", true))
			and is_equal_approx(float(a[i].get("z_offset", 0.0)), float(b[i].get("z_offset", 1.0))),
			"Same seed should repeat level, tier, and side"
		)


func _verify_window_cap() -> void:
	for seed in range(1, 81):
		var planned: Array[Dictionary] = BonusTowerPlannerScript.plan(seed)
		var counts: Dictionary = {}
		for entry in planned:
			var level := int(entry.get("level", 0))
			var window := int(floor(float(level - 1) / float(BonusTowerPlannerScript.WINDOW_SIZE)))
			counts[window] = int(counts.get(window, 0)) + 1
			if level < 25:
				_fail_unless(
					int(entry.get("tier", 0)) < 6,
					"Tier 6 should not appear before level 25 (seed %d level %d)" % [seed, level]
				)
		for window in counts.keys():
			_fail_unless(
				int(counts[window]) <= BonusTowerPlannerScript.MAX_PER_WINDOW,
				"Window %d seed %d exceeded max bonus towers" % [window, seed]
			)


func _verify_placement_and_tiers() -> void:
	LevelRunScript.ensure(42)
	var planned: Array[Dictionary] = BonusTowerPlannerScript.plan(42)
	_fail_unless(not planned.is_empty(), "Seed 42 should still place some bonus towers over 40 levels")
	for entry in planned:
		var level := int(entry.get("level", 0))
		var span := LevelRunScript.segment_east_west_x(level)
		var mid := (span.x + span.y) * 0.5
		_fail_unless(
			is_equal_approx(float(entry.get("x_offset", 0.0)), mid),
			"Bonus X should be the midpoint of level %d" % level
		)
		var z_abs := absf(float(entry.get("z_offset", 0.0)))
		var z_ok := false
		for allowed_z in BonusTowerPlannerScript.TIER_Z_M:
			if is_equal_approx(z_abs, allowed_z):
				z_ok = true
				break
		_fail_unless(z_ok, "Bonus |Z| %.0f is not a valid tier" % z_abs)
		var tier := int(entry.get("tier", 0))
		_fail_unless(tier >= 1 and tier <= BonusTowerPlannerScript.max_unlocked_tier(level), "Tier locked for level %d" % level)
		if level < 25:
			_fail_unless(tier <= 5, "Tier 6 should not appear before level 25")
		_fail_unless(
			int(entry.get("tower_index", 0)) == BonusTowerPlannerScript.index_for_level(level),
			"Bonus tower_index should be 1000 + level"
		)
		var north := bool(entry.get("north", false))
		var z_offset := float(entry.get("z_offset", 0.0))
		_fail_unless(
			(north and z_offset > 0.0) or (not north and z_offset < 0.0),
			"North should be +Z, south should be -Z"
		)


func _verify_offer_counts() -> void:
	var seen: Dictionary = {}
	for seed in range(1, 40):
		for level in range(4, 12):
			var index := BonusTowerPlannerScript.index_for_level(level)
			var n := BonusTowerPlannerScript.offer_count_for(seed, index)
			_fail_unless(n >= 2 and n <= 6, "Offer count should be 2-6, got %d" % n)
			_fail_unless(
				BonusTowerPlannerScript.offer_count_for(seed, index) == n,
				"Offer count should be deterministic"
			)
			seen[n] = true
			var shop := UpgradeCatalogScript.roll_shop(seed, index, 0, true, false, false, false, false, 0, n)
			_fail_unless(shop.size() == n, "roll_shop should honor slot_count %d" % n)
	for expected in range(2, 7):
		_fail_unless(seen.has(expected), "Binomial helper should be able to roll %d offers" % expected)


func _verify_radar_copy() -> void:
	_fail_unless(
		BonusTowerPlannerScript.radar_text(true)
		== "Your radar has picked up a bonus tower to the north-west.",
		"North bonus should use north-west radar copy"
	)
	_fail_unless(
		BonusTowerPlannerScript.radar_text(false)
		== "Your radar has picked up a bonus tower to the south-west.",
		"South bonus should use south-west radar copy"
	)


func _verify_tower_flags() -> void:
	var tower: UpgradeTower = UpgradeTowerScript.new()
	tower.is_bonus = true
	tower.source_level = 5
	tower.tower_index = BonusTowerPlannerScript.index_for_level(5)
	_fail_unless(tower.is_upgrade_stop(), "Bonus towers should still be upgrade stops")
	_fail_unless(tower.visit_heal_level() == 5, "Level 5 bonus should heal like west tower 5")
	_fail_unless(
		TowerVisitControllerScript.visit_heal_amount(tower.visit_heal_level()) == 25,
		"Bonus heal should use source level, not 1000+N"
	)
	var untagged: UpgradeTower = UpgradeTowerScript.new()
	untagged.tower_index = BonusTowerPlannerScript.index_for_level(7)
	_fail_unless(untagged.visit_heal_level() == 7, "Bonus index 1007 should heal like tower 7")
	_fail_unless(
		TowerVisitControllerScript.visit_heal_amount(untagged.visit_heal_level())
		== TowerVisitControllerScript.visit_heal_amount(7),
		"Level 7 bonus heal should match tower 7"
	)
	untagged.free()
	tower.free()


func _verify_garrison_plan() -> void:
	var empty: Dictionary = BonusTowerPlannerScript.garrison_plan(42, 3)
	_fail_unless(int(empty.get("count", -1)) == 0, "Levels 1-3 should have no garrison")
	for seed in [1, 42, 99]:
		var p4: Dictionary = BonusTowerPlannerScript.garrison_plan(seed, 4)
		_fail_unless(
			String(p4.get("kind", "")) == BonusTowerPlannerScript.KIND_GROUND,
			"Level 4 garrison should always be ground"
		)
		_assert_in_band(int(p4.get("count", 0)), 6, 7, "Level 4 ground count")
		_fail_unless(int(p4.get("laser_count", -1)) == 0, "Ground packs should have no lasers")
	var a: Dictionary = BonusTowerPlannerScript.garrison_plan(42, 10)
	var b: Dictionary = BonusTowerPlannerScript.garrison_plan(42, 10)
	_fail_unless(
		String(a.get("kind", "")) == String(b.get("kind", ""))
		and int(a.get("count", 0)) == int(b.get("count", 0))
		and int(a.get("laser_count", 0)) == int(b.get("laser_count", 0))
		and int(a.get("charger_count", 0)) == int(b.get("charger_count", 0)),
		"Same seed should repeat garrison kind and counts"
	)
	var seen_ground := false
	var seen_drone := false
	for seed in range(1, 81):
		var plan: Dictionary = BonusTowerPlannerScript.garrison_plan(seed, 10)
		var kind := String(plan.get("kind", ""))
		var count := int(plan.get("count", 0))
		if kind == BonusTowerPlannerScript.KIND_GROUND:
			seen_ground = true
			_assert_in_band(count, 7, 9, "Level 10 ground count")
			_fail_unless(int(plan.get("laser_count", -1)) == 0, "Ground garrison should not include lasers")
			_fail_unless(int(plan.get("charger_count", 0)) <= count, "Chargers cannot exceed pack size")
		else:
			seen_drone = true
			_fail_unless(kind == BonusTowerPlannerScript.KIND_DRONE, "Kind should be ground or drone")
			_assert_in_band(count, 2, 2, "Level 10 drone count")
			_fail_unless(
				int(plan.get("laser_count", -1)) == BonusTowerPlannerScript.laser_count_for(count),
				"Laser count should be floor(n/4)"
			)
			_fail_unless(int(plan.get("charger_count", -1)) == 0, "Drone packs should have no chargers")
	_fail_unless(seen_ground and seen_drone, "Level 5+ should roll both ground and drone camps")
	_fail_unless(BonusTowerPlannerScript.laser_count_for(1) == 0, "1 drone should have 0 lasers")
	_fail_unless(BonusTowerPlannerScript.laser_count_for(3) == 0, "3 drones should have 0 lasers")
	_fail_unless(BonusTowerPlannerScript.laser_count_for(4) == 1, "4 drones should have 1 laser")
	_fail_unless(BonusTowerPlannerScript.laser_count_for(7) == 1, "7 drones should have 1 laser")
	_fail_unless(BonusTowerPlannerScript.laser_count_for(8) == 2, "8 drones should have 2 lasers")
	_fail_unless(BonusTowerPlannerScript.laser_count_for(11) == 2, "11 drones should have 2 lasers")
	_fail_unless(BonusTowerPlannerScript.laser_count_for(12) == 3, "12 drones should have 3 lasers")
	_fail_unless(BonusTowerPlannerScript.laser_count_for(13) == 3, "13 drones should have 3 lasers")
	_verify_garrison_bands()
	var late: Dictionary = BonusTowerPlannerScript.garrison_plan(3, 40)
	if String(late.get("kind", "")) == BonusTowerPlannerScript.KIND_GROUND:
		_fail_unless(int(late.get("count", 0)) == 25, "Level 36-40 ground pack is 25")
	else:
		_fail_unless(int(late.get("count", 0)) == 13, "Level 36-40 drone pack is 13")
	_fail_unless(BonusTowerPlannerScript.visit_locked(true, true, 3) == false, "Cleared garrison should unlock visit")
	_fail_unless(BonusTowerPlannerScript.visit_locked(false, false, 0), "Unspawned garrison should lock visit")
	_fail_unless(BonusTowerPlannerScript.visit_locked(false, true, 2), "Living garrison should lock visit")
	_fail_unless(BonusTowerPlannerScript.visit_locked(false, true, 0) == false, "Wiped spawned camp should unlock")
	_fail_unless(
		BonusTowerPlannerScript.should_spawn_garrison(Vector3.ZERO, Vector3(100.0, 0.0, 0.0), false, false, 500.0),
		"Approach within 500 m should spawn the camp"
	)
	_fail_unless(
		not BonusTowerPlannerScript.should_spawn_garrison(Vector3.ZERO, Vector3(100.0, 0.0, 0.0), false, false, 50.0),
		"Far approach should not spawn yet"
	)
	_fail_unless(
		BonusTowerPlannerScript.should_skip_despawn(Vector3(-400.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)),
		"West and far from the tower should skip-despawn"
	)
	_fail_unless(
		not BonusTowerPlannerScript.should_skip_despawn(Vector3(-50.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)),
		"Still near the tower should not skip-despawn"
	)
	var ring := BonusTowerPlannerScript.ring_offset(0, 4, 32.0)
	_fail_unless(is_equal_approx(ring.length(), 32.0), "Ring offset should sit on the spawn radius")


func _verify_garrison_bands() -> void:
	var cases: Array = [
		[4, 6, 7, 1, 1],
		[7, 6, 7, 1, 1],
		[8, 7, 9, 2, 2],
		[11, 7, 9, 2, 2],
		[12, 10, 12, 3, 4],
		[15, 10, 12, 3, 4],
		[16, 13, 16, 5, 7],
		[25, 13, 16, 5, 7],
		[26, 17, 21, 8, 10],
		[35, 17, 21, 8, 10],
		[36, 25, 25, 13, 13],
		[40, 25, 25, 13, 13],
	]
	for row in cases:
		var band: Dictionary = BonusTowerPlannerScript.garrison_band(int(row[0]))
		_fail_unless(int(band.get("gmin", 0)) == int(row[1]), "Band %d ground min" % int(row[0]))
		_fail_unless(int(band.get("gmax", 0)) == int(row[2]), "Band %d ground max" % int(row[0]))
		_fail_unless(int(band.get("dmin", 0)) == int(row[3]), "Band %d drone min" % int(row[0]))
		_fail_unless(int(band.get("dmax", 0)) == int(row[4]), "Band %d drone max" % int(row[0]))
		for seed in [1, 8, 42]:
			var plan: Dictionary = BonusTowerPlannerScript.garrison_plan(seed, int(row[0]))
			var kind := String(plan.get("kind", ""))
			_fail_unless(
				kind == BonusTowerPlannerScript.KIND_GROUND or kind == BonusTowerPlannerScript.KIND_DRONE,
				"Garrison kind should be ground or drone, never MG"
			)
			var count := int(plan.get("count", 0))
			if kind == BonusTowerPlannerScript.KIND_DRONE:
				_assert_in_band(count, int(row[3]), int(row[4]), "Level %d drone count" % int(row[0]))
				_fail_unless(
					int(plan.get("laser_count", -1)) == BonusTowerPlannerScript.laser_count_for(count),
					"Laser count should be floor(n/4)"
				)
			else:
				_assert_in_band(count, int(row[1]), int(row[2]), "Level %d ground count" % int(row[0]))
				_fail_unless(int(plan.get("laser_count", -1)) == 0, "Ground packs should have no lasers")


func _verify_garrison_visit_lock() -> void:
	var root_node := Node.new()
	root_node.name = "GarrisonVisitRoot"
	root.add_child(root_node)
	var garrison = BonusTowerGarrisonScript.new()
	garrison.name = "BonusTowerGarrison"
	root_node.add_child(garrison)
	var bonus: UpgradeTower = UpgradeTowerScript.new()
	bonus.is_bonus = true
	bonus.source_level = 7
	bonus.tower_index = BonusTowerPlannerScript.index_for_level(7)
	root_node.add_child(bonus)
	bonus.global_position = Vector3(-500.0, 0.0, 0.0)
	var west: UpgradeTower = UpgradeTowerScript.new()
	west.tower_index = 7
	west.is_home = false
	west.is_bonus = false
	root_node.add_child(west)
	west.global_position = Vector3(-800.0, 0.0, 0.0)
	await process_frame
	_fail_unless(
		garrison.is_visit_locked(bonus),
		"Unspawned bonus garrison should lock the visit"
	)
	_fail_unless(
		TowerVisitControllerScript.find_visit_tower(self, bonus.global_position) == null,
		"find_visit_tower should skip a bonus with a live garrison"
	)
	_fail_unless(
		TowerVisitControllerScript.find_visit_tower(self, west.global_position) == west,
		"Night hub / west towers should stay visitable with garrisons present"
	)
	var dummy := Node.new()
	root_node.add_child(dummy)
	garrison._camps[bonus.tower_index] = {
		"cleared": false,
		"spawned": true,
		"units": [dummy],
	}
	_fail_unless(garrison.is_visit_locked(bonus), "Living garrison units should keep the visit locked")
	garrison._camps[bonus.tower_index] = {
		"cleared": false,
		"spawned": true,
		"units": [],
	}
	_fail_unless(not garrison.is_visit_locked(bonus), "Wiped camp should open the bonus visit")
	_fail_unless(
		TowerVisitControllerScript.find_visit_tower(self, bonus.global_position) == bonus,
		"Cleared garrison should allow the 20 m bonus visit"
	)
	root_node.queue_free()
	await process_frame
	await process_frame


func _verify_spawner_bonus_flags() -> void:
	var root_node := Node.new()
	root_node.name = "BonusSpawnRoot"
	root.add_child(root_node)
	LevelRunScript.ensure(42)
	var planned: Array[Dictionary] = BonusTowerPlannerScript.plan(42)
	var spawner: Node = OutpostSpawnerScript.new()
	spawner.name = "OutpostSpawner"
	spawner.set("include_home", true)
	spawner.set("include_bonus", true)
	root_node.add_child(spawner)
	await process_frame
	await process_frame
	await process_frame
	var bonus_by_index: Dictionary = {}
	var west_count := 0
	for node in get_nodes_in_group("upgrade_tower"):
		var tower := node as UpgradeTower
		if tower == null or not is_instance_valid(tower):
			continue
		if tower.is_bonus:
			bonus_by_index[tower.tower_index] = tower
			continue
		if not tower.is_home:
			west_count += 1
			_fail_unless(not tower.is_bonus, "West tower %d should not be marked bonus" % tower.tower_index)
	_fail_unless(west_count == 40, "Expected 40 west towers alongside bonuses, got %d" % west_count)
	_fail_unless(bonus_by_index.size() == planned.size(), "Spawner should place every planned bonus tower")
	for entry in planned:
		var index := int(entry.get("tower_index", 0))
		_fail_unless(bonus_by_index.has(index), "Missing spawned bonus tower %d" % index)
		var tower: UpgradeTower = bonus_by_index[index]
		_fail_unless(tower.is_bonus, "Planned bonus %d should set is_bonus" % index)
		_fail_unless(tower.source_level == int(entry.get("source_level", 0)), "Bonus source_level should match planner")
		_fail_unless(tower.is_upgrade_stop(), "Spawned bonus should be an upgrade stop")
		_fail_unless(
			is_equal_approx(tower.global_position.x, float(entry.get("x_offset", 0.0))),
			"Bonus X should stay on the planned midpoint"
		)
		_fail_unless(
			is_equal_approx(tower.global_position.z, float(entry.get("z_offset", 0.0))),
			"Bonus Z should not use westbound ridge snap"
		)
	root_node.queue_free()
	await process_frame


func _assert_in_band(value: int, lo: int, hi: int, label: String) -> void:
	_fail_unless(value >= lo and value <= hi, "%s %d should be %d-%d" % [label, value, lo, hi])


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
