extends SceneTree

const BonusTowerPlannerScript := preload("res://scripts/game/bonus_tower_planner.gd")
const LevelRunScript := preload("res://scripts/game/level_run.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")
const UpgradeTowerScript := preload("res://scripts/world/upgrade_tower.gd")
const TowerVisitControllerScript := preload("res://scripts/game/tower_visit_controller.gd")
const OutpostSpawnerScript := preload("res://scripts/world/outpost_spawner.gd")

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


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
