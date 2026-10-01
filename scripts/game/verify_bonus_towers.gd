extends SceneTree

const BonusTowerPlannerScript := preload("res://scripts/game/bonus_tower_planner.gd")
const LevelRunScript := preload("res://scripts/game/level_run.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")
const UpgradeTowerScript := preload("res://scripts/world/upgrade_tower.gd")
const TowerVisitControllerScript := preload("res://scripts/game/tower_visit_controller.gd")
const OutpostSpawnerScript := preload("res://scripts/world/outpost_spawner.gd")
const BonusTowerGarrisonScript := preload("res://scripts/world/bonus_tower_garrison.gd")
const BonusTowerShieldScript := preload("res://scripts/world/bonus_tower_shield.gd")
const SwarmPillScript := preload("res://scripts/enemies/swarm_pill.gd")
const CombatDroneScript := preload("res://scripts/enemies/combat_drone.gd")
const LaserDroneScript := preload("res://scripts/enemies/laser_drone.gd")
const MissileDroneScript := preload("res://scripts/enemies/missile_drone.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_spawn_chance()
	_verify_no_early_levels()
	_verify_deterministic()
	_verify_window_cap()
	_verify_pity_carries_across_windows()
	_verify_placement_and_tiers()
	_verify_offer_counts()
	_verify_radar_copy()
	_verify_scan_copy()
	_verify_tower_flags()
	_verify_garrison_plan()
	await _verify_garrison_visit_lock()
	await _verify_shield_and_pack_aggro()
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
	LevelRunScript.ensure(1)
	var levels := LevelRunScript.segment_count()
	var span := BonusTowerPlannerScript.WINDOW_SIZE
	var cap := BonusTowerPlannerScript.MAX_PER_WINDOW
	for seed in range(1, 81):
		var planned: Array[Dictionary] = BonusTowerPlannerScript.plan(seed)
		for entry in planned:
			var level := int(entry.get("level", 0))
			if level < 25:
				_fail_unless(
					int(entry.get("tier", 0)) < 6,
					"Tier 6 should not appear before level 25 (seed %d level %d)" % [seed, level]
				)
		for start in range(1, levels - span + 2):
			var n := BonusTowerPlannerScript.count_in_span(planned, start, start + span - 1)
			_fail_unless(
				n <= cap,
				"Sliding window [%d, %d] seed %d had %d bonus towers" % [start, start + span - 1, seed, n]
			)


func _verify_pity_carries_across_windows() -> void:
	_fail_unless(
		is_equal_approx(BonusTowerPlannerScript.spawn_chance(5), 0.52),
		"Five misses (levels 4-8) should raise spawn chance to 52%"
	)
	var empty_then_nine := 0
	var samples := 400
	for world_seed in range(1, samples + 1):
		var planned: Array[Dictionary] = BonusTowerPlannerScript.plan(world_seed)
		var first_window := 0
		var spawned_nine := false
		for entry in planned:
			var level := int(entry.get("level", 0))
			if level <= BonusTowerPlannerScript.WINDOW_SIZE:
				first_window += 1
			if level == BonusTowerPlannerScript.WINDOW_SIZE + 1:
				spawned_nine = true
		if first_window == 0 and spawned_nine:
			empty_then_nine += 1
	_fail_unless(
		empty_then_nine >= 20,
		"Pity should carry into the next window so level 9 can spawn after a dry first window (%d of %d)"
		% [empty_then_nine, samples]
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


func _verify_scan_copy() -> void:
	_fail_unless(BonusTowerPlannerScript.distance_label(1) == "Close", "Tier 1 should be Close")
	_fail_unless(BonusTowerPlannerScript.distance_label(2) == "Close", "Tier 2 should be Close")
	_fail_unless(BonusTowerPlannerScript.distance_label(3) == "Distant", "Tier 3 should be Distant")
	_fail_unless(BonusTowerPlannerScript.distance_label(4) == "Distant", "Tier 4 should be Distant")
	_fail_unless(BonusTowerPlannerScript.distance_label(5) == "Far away", "Tier 5 should be Far away")
	_fail_unless(BonusTowerPlannerScript.distance_label(6) == "Far away", "Tier 6 should be Far away")
	_fail_unless(
		BonusTowerPlannerScript.attacker_label(BonusTowerPlannerScript.KIND_GROUND) == "Monsters",
		"Ground camps should scan as Monsters"
	)
	_fail_unless(
		BonusTowerPlannerScript.attacker_label(BonusTowerPlannerScript.KIND_DRONE) == "Rebels",
		"Drone camps should scan as Rebels"
	)
	_fail_unless(
		BonusTowerPlannerScript.scan_failed(42, 8) == BonusTowerPlannerScript.scan_failed(42, 8),
		"Same seed and level should keep the same scan fail result"
	)
	var fails := 0
	var samples := 400
	for world_seed in range(1, samples + 1):
		if BonusTowerPlannerScript.scan_failed(world_seed, 10):
			fails += 1
	var rate := float(fails) / float(samples)
	_fail_unless(
		rate > 0.25 and rate < 0.45,
		"Scan fail rate should be near 35%%, got %.3f" % rate
	)
	var fail_seed := -1
	var ok_seed := -1
	for world_seed in range(1, 200):
		if BonusTowerPlannerScript.scan_failed(world_seed, 10):
			if fail_seed < 0:
				fail_seed = world_seed
		elif ok_seed < 0:
			ok_seed = world_seed
		if fail_seed >= 0 and ok_seed >= 0:
			break
	_fail_unless(fail_seed >= 0 and ok_seed >= 0, "Should find both failed and successful scan seeds")
	var entry := {
		"level": 10,
		"tier": 2,
		"offer_count": 4,
		"north": true,
	}
	var failed_lines := BonusTowerPlannerScript.scan_report_lines(fail_seed, entry, true)
	_fail_unless(failed_lines.size() == 4, "Failed scan should still type four report lines")
	_fail_unless(failed_lines[0] == "Tower under attack: YES", "Failed scan should still report the tower")
	_fail_unless(failed_lines[1] == "By: No data", "Failed scan By should be No data")
	_fail_unless(failed_lines[2] == "Upgrades: No data", "Failed scan Upgrades should be No data")
	_fail_unless(failed_lines[3] == "Distance: No data", "Failed scan Distance should be No data")
	var ok_lines := BonusTowerPlannerScript.scan_report_lines(ok_seed, entry, false)
	var plan: Dictionary = BonusTowerPlannerScript.garrison_plan(ok_seed, 10)
	var expected_by := "By: %s" % BonusTowerPlannerScript.attacker_label(String(plan.get("kind", "")))
	_fail_unless(ok_lines[0] == "Tower under attack: YES", "Successful scan should report the tower")
	_fail_unless(ok_lines[1] == expected_by, "Successful scan By should match garrison kind")
	_fail_unless(ok_lines[2] == "Upgrades: 4", "Successful scan should use offer_count")
	_fail_unless(ok_lines[3] == "Distance: Close", "Successful scan should use distance_label")
	var north_obj := BonusTowerPlannerScript.bonus_objective_text(true, "Close", 4, false)
	_fail_unless(north_obj.contains("north-west"), "Bonus objective should name north-west")
	_fail_unless(north_obj.contains("Distance: Close"), "Successful objective should keep distance")
	_fail_unless(north_obj.contains("Upgrades: 4"), "Successful objective should keep upgrades")
	var south_fail := BonusTowerPlannerScript.bonus_objective_text(false, "Distant", 3, true)
	_fail_unless(south_fail.contains("south-west"), "Bonus objective should name south-west")
	_fail_unless(south_fail.contains("Distance: No data"), "Failed objective distance should be No data")
	_fail_unless(south_fail.contains("Upgrades: No data"), "Failed objective upgrades should be No data")


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
	_fail_unless(
		BonusTowerPlannerScript.should_leave_despawn(Vector3(600.0, 0.0, 0.0), Vector3.ZERO),
		"Leaving the 500 m bubble should despawn the pack"
	)
	_fail_unless(
		not BonusTowerPlannerScript.should_leave_despawn(Vector3(100.0, 0.0, 0.0), Vector3.ZERO),
		"Inside 500 m should not leave-despawn"
	)
	_fail_unless(
		BonusTowerPlannerScript.should_reset_camp(Vector3(-400.0, 0.0, 0.0), Vector3.ZERO),
		"Skip-west should reset the camp"
	)
	_fail_unless(
		BonusTowerPlannerScript.should_reset_camp(Vector3(0.0, 0.0, 600.0), Vector3.ZERO),
		"Far in Z should reset the camp"
	)
	var ring := BonusTowerPlannerScript.ring_offset(0, 4, 32.0)
	_fail_unless(is_equal_approx(ring.length(), 32.0), "Ring offset should sit on the spawn radius")
	_fail_unless(
		is_equal_approx(BonusTowerGarrisonScript.DRONE_RING_RADIUS_M, 20.0),
		"Drone packs should ring 20 m from the tower"
	)
	var drone_a := BonusTowerPlannerScript.ring_offset(0, 4, BonusTowerGarrisonScript.DRONE_RING_RADIUS_M)
	var drone_b := BonusTowerPlannerScript.ring_offset(1, 4, BonusTowerGarrisonScript.DRONE_RING_RADIUS_M)
	_fail_unless(is_equal_approx(drone_a.length(), 20.0), "Even drone ring should be 20 m out")
	_fail_unless(is_equal_approx(drone_a.dot(drone_b), 0.0), "Even drone ring should space drones around the tower")


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
	garrison._camps[bonus.tower_index] = {
		"cleared": true,
		"spawned": true,
		"units": [],
	}
	_fail_unless(not garrison.is_visit_locked(bonus), "Cleared flag should keep the visit open this life")
	garrison.reset_camps()
	_fail_unless(garrison.is_visit_locked(bonus), "Try Again should restore the garrison lock")
	var restored = BonusTowerShieldScript.ensure_on(bonus)
	_fail_unless(restored != null and restored.is_shield_active(), "Try Again should restore the bonus shield")
	root_node.queue_free()
	await process_frame
	await process_frame


func _verify_shield_and_pack_aggro() -> void:
	_fail_unless(is_equal_approx(SwarmPillScript.GARRISON_AGGRO_M, 30.0), "Garrison aggro should be 30 m")
	_fail_unless(is_equal_approx(SwarmPillScript.GARRISON_LEASH_M, 180.0), "Garrison leash should stay 180 m")
	var root_node := Node.new()
	root_node.name = "ShieldAggroRoot"
	root.add_child(root_node)
	var tower: UpgradeTower = UpgradeTowerScript.new()
	tower.is_bonus = true
	tower.tower_index = BonusTowerPlannerScript.index_for_level(7)
	tower.source_level = 7
	root_node.add_child(tower)
	var shield = BonusTowerShieldScript.ensure_on(tower)
	await process_frame
	_fail_unless(shield != null, "Bonus towers should get a laser shield")
	_fail_unless(is_equal_approx(shield.position.y, BonusTowerShieldScript.CENTER_Y_M), "Shield should be centered on the tower shaft")
	var mid := shield.aim_mid_from(Vector3(20.0, 8.0, 0.0))
	_fail_unless(
		is_equal_approx(mid.y, shield.global_position.y),
		"Siege aim should hit halfway up the sphere"
	)
	_fail_unless(
		is_equal_approx(
			Vector2(mid.x - shield.global_position.x, mid.z - shield.global_position.z).length(),
			BonusTowerShieldScript.RADIUS_M
		),
		"Siege aim should sit on the dome equator facing the shooter"
	)
	_fail_unless(is_equal_approx(BonusTowerShieldScript.RADIUS_M, 52.0), "Shield radius should cover the 100 m tower")
	_fail_unless(shield.is_shield_active(), "Uncleared bonus should keep the shield up")
	var mesh: MeshInstance3D = shield.get_node_or_null("Visual") as MeshInstance3D
	_fail_unless(mesh != null and mesh.mesh is SphereMesh, "Shield should be a sphere")
	var sphere := mesh.mesh as SphereMesh
	_fail_unless(is_equal_approx(sphere.radius, BonusTowerShieldScript.RADIUS_M), "Shield mesh radius should match collision")
	var mat := mesh.material_override as StandardMaterial3D
	_fail_unless(mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Shield should be transparent")
	_fail_unless(mat.albedo_color.a < 0.5, "Shield should be see-through")
	_fail_unless(mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "Shield should show the tower inside")
	var body: StaticBody3D = shield.get_node_or_null("Collision") as StaticBody3D
	_fail_unless(body != null, "Shield should have collision")
	_fail_unless(body.collision_layer == BonusTowerShieldScript.COLLISION_LAYER, "Shield collision should use layer 16")
	_fail_unless(body.collision_mask == 0, "Shield should not scan other bodies")
	shield.set_shield_active(false)
	_fail_unless(not shield.is_shield_active(), "Cleared camps should drop the shield")
	_fail_unless(body.collision_layer == 0, "Dropped shield should not block")
	shield.set_shield_active(true)

	var dummy_player := Node3D.new()
	root_node.add_child(dummy_player)
	dummy_player.global_position = Vector3(1000.0, 0.0, 0.0)
	var crawler: SwarmPillScript = SwarmPillScript.new()
	root_node.add_child(crawler)
	crawler.global_position = Vector3(32.0, 0.0, 0.0)
	crawler.configure(null, dummy_player)
	crawler.bind_garrison(Vector3.ZERO, tower.tower_index, shield)
	await process_frame
	var crawler_dot := crawler.get_node_or_null("GarrisonLockDot") as Sprite3D
	_fail_unless(crawler_dot != null, "Garrison units should show a red lock dot")
	_fail_unless(crawler_dot.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Lock dot should face the camera")
	_fail_unless(crawler_dot.no_depth_test, "Lock dot should stay readable through the shield")
	_fail_unless(
		crawler_dot.global_position.y > crawler.global_position.y + 0.5,
		"Lock dot should sit above the enemy"
	)
	_fail_unless((crawler.collision_mask & BonusTowerShieldScript.COLLISION_LAYER) != 0, "Crawlers should collide with the shield")
	var idle := crawler._garrison_goal_xz()
	_fail_unless(
		is_equal_approx(idle.x, 0.0) and is_equal_approx(idle.z, 0.0),
		"Unaggroed crawlers should walk into the tower/shield"
	)

	var drone: CombatDroneScript = CombatDroneScript.new()
	root_node.add_child(drone)
	drone.global_position = Vector3(32.0, 8.0, 0.0)
	drone.configure(null, dummy_player)
	drone.bind_garrison(Vector3.ZERO, tower.tower_index, shield)
	await process_frame
	_fail_unless(drone.collision_mask == 0, "Drones should not physically collide with the shield")
	var drone_dot := drone.get_node_or_null("GarrisonLockDot") as Sprite3D
	_fail_unless(drone_dot != null, "Garrison drones should show a red lock dot")
	_fail_unless(
		drone_dot.global_position.y > drone.global_position.y + 0.5,
		"Drone lock dot should sit above the cube"
	)
	var drone_idle := drone._garrison_idle_goal_xz()
	_fail_unless(
		is_equal_approx(drone_idle.x, 32.0) and is_equal_approx(drone_idle.z, 0.0),
		"Unaggroed drones should hold the spawn ring"
	)

	var garrison = BonusTowerGarrisonScript.new()
	garrison.name = "BonusTowerGarrison"
	root_node.add_child(garrison)
	await process_frame
	var other: SwarmPillScript = SwarmPillScript.new()
	root_node.add_child(other)
	other.global_position = Vector3(-32.0, 0.0, 0.0)
	other.configure(null, dummy_player)
	other.bind_garrison(Vector3.ZERO, tower.tower_index, shield)
	garrison._camps[tower.tower_index] = {
		"cleared": false,
		"spawned": true,
		"units": [crawler, other],
	}
	_fail_unless(not crawler.is_garrison_aggroed() and not other.is_garrison_aggroed(), "Pack should start in shield-attack")
	crawler.take_damage(1)
	_fail_unless(crawler.is_garrison_aggroed() and other.is_garrison_aggroed(), "Damaging one unit should aggro the pack")
	garrison._set_pack_aggro(garrison._camps[tower.tower_index], false)
	dummy_player.global_position = Vector3(40.0, 0.0, 0.0)
	garrison._tick_pack_combat(garrison._camps[tower.tower_index], dummy_player.global_position, Vector3.ZERO)
	_fail_unless(crawler.is_garrison_aggroed() and other.is_garrison_aggroed(), "Closing within 30 m should aggro the pack")
	garrison._tick_pack_combat(garrison._camps[tower.tower_index], Vector3(0.0, 0.0, 200.0), Vector3.ZERO)
	_fail_unless(not crawler.is_garrison_aggroed() and not other.is_garrison_aggroed(), "Leash should return the pack to the shield")

	var laser: LaserDroneScript = LaserDroneScript.new()
	laser._reload_left = 4.0
	laser._telegraph_armed = true
	laser.reset_garrison_weapons()
	_fail_unless(is_equal_approx(laser._reload_left, 0.0), "Laser cooldown should reset on player aggro")
	_fail_unless(not laser._telegraph_armed, "Laser telegraph should clear on player aggro")
	var missile: MissileDroneScript = MissileDroneScript.new()
	missile._cooldown_left = 6.0
	missile._firing_hail = true
	missile.reset_garrison_weapons()
	_fail_unless(is_equal_approx(missile._cooldown_left, 0.0), "Missile cooldown should reset on player aggro")
	_fail_unless(not missile._firing_hail, "Missile hail should stop when resetting for the player")
	laser.free()
	missile.free()
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
