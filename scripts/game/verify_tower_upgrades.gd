extends SceneTree

const RunUpgradeStateScript = preload("res://scripts/game/run_upgrade_state.gd")
const UpgradeCatalogScript = preload("res://scripts/game/upgrade_catalog.gd")
const TowerVisitControllerScript = preload("res://scripts/game/tower_visit_controller.gd")
const PlayerRigScript = preload("res://scripts/player/player_rig.gd")
const UpgradeTowerScript = preload("res://scripts/world/upgrade_tower.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog()
	_verify_roll_shop()
	_verify_offers_and_visit_lock()
	_verify_empty_tower_confirm()
	_verify_attack_speed_stacking()
	_verify_dawn_pose()
	await _verify_visit_radius()
	print("Tower upgrade verification passed.")
	quit(0)


func _verify_catalog() -> void:
	_fail_unless(
		UpgradeCatalogScript.SLOTS_PER_TOWER == 5,
		"Each tower should offer 5 slots"
	)
	_fail_unless(
		UpgradeCatalogScript.RARITY_WEIGHT_COMMON == 50
		and UpgradeCatalogScript.RARITY_WEIGHT_RARE == 25
		and UpgradeCatalogScript.RARITY_WEIGHT_EPIC == 15
		and UpgradeCatalogScript.RARITY_WEIGHT_LEGENDARY == 10,
		"Rarity weights should be 50 / 25 / 15 / 10"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_COMMON, 0.05)
		and is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_RARE, 0.08)
		and is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_EPIC, 0.11)
		and is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_LEGENDARY, 0.15),
		"Attack Speed percents should be 5 / 8 / 11 / 15"
	)
	_fail_unless(
		UpgradeCatalogScript.PROJECTILE_COMMON == 1
		and UpgradeCatalogScript.PROJECTILE_RARE == 2
		and UpgradeCatalogScript.PROJECTILE_EPIC == 3
		and UpgradeCatalogScript.PROJECTILE_LEGENDARY == 4,
		"Projectile bonuses should be +1 / +2 / +3 / +4"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(UpgradeCatalogScript.ID_EXTRA_PROJECTILE) == "+1 projectile",
		"Extra projectile should be labeled +1 projectile"
	)
	var rare_proj := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_PROJECTILE,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_proj) == "+2 projectiles",
		"Rare projectile should be labeled +2 projectiles"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PROJECTILE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "+3 projectiles",
		"Epic projectile should be labeled +3 projectiles"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PROJECTILE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "+4 projectiles",
		"Legendary projectile should be labeled +4 projectiles"
	)
	var rare_as := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_as) == "Attack Speed −8%",
		"Attack Speed rare should show −8%"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_as) != null,
		"Attack Speed cards should have an icon"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_display_name(UpgradeCatalogScript.ID_EXTRA_PROJECTILE) == "COMMON",
		"Common projectile should read COMMON"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_display_name(rare_as) == "RARE",
		"Rare Attack Speed should read RARE"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PROJECTILE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "EPIC",
		"Epic projectile should read EPIC"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "LEGENDARY",
		"Legendary Attack Speed should read LEGENDARY"
	)
	var common_icon := UpgradeCatalogScript.icon_for(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_fail_unless(common_icon != null, "Common projectile should have an icon")
	_fail_unless(
		common_icon != UpgradeCatalogScript.ICON_EXTRA_PROJECTILE,
		"Common projectile should use projectile_common.jpg, not the family fallback"
	)
	var rare_proj_icon := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_PROJECTILE,
		UpgradeCatalogScript.RARITY_RARE
	)
	var rare_icon := UpgradeCatalogScript.icon_for(rare_proj_icon)
	_fail_unless(rare_icon != null, "Rare projectile should have an icon")
	_fail_unless(
		rare_icon != UpgradeCatalogScript.ICON_EXTRA_PROJECTILE,
		"Rare projectile should use projectile_rare.jpg, not the family fallback"
	)
	var epic_proj := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_PROJECTILE,
		UpgradeCatalogScript.RARITY_EPIC
	)
	var epic_icon := UpgradeCatalogScript.icon_for(epic_proj)
	_fail_unless(epic_icon != null, "Epic projectile should have an icon")
	_fail_unless(
		epic_icon != UpgradeCatalogScript.ICON_EXTRA_PROJECTILE,
		"Epic projectile should use projectile_epic.jpg, not the family fallback"
	)
	var legendary_proj := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_PROJECTILE,
		UpgradeCatalogScript.RARITY_LEGENDARY
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(legendary_proj) == UpgradeCatalogScript.ICON_EXTRA_PROJECTILE,
		"Legendary projectile should fall back to the generic projectile icon"
	)


func _verify_roll_shop() -> void:
	var first := UpgradeCatalogScript.roll_shop(7, 3)
	var again := UpgradeCatalogScript.roll_shop(7, 3)
	_fail_unless(first.size() == 5, "roll_shop should fill 5 slots")
	_fail_unless(first == again, "Same seed and tower should roll the same shop")
	var other_tower := UpgradeCatalogScript.roll_shop(7, 4)
	_fail_unless(other_tower.size() == 5, "Other towers should also roll 5 cards")
	var saw_duplicate := false
	for tower_index in range(1, 81):
		var shop := UpgradeCatalogScript.roll_shop(1, tower_index)
		if _has_duplicate(shop):
			saw_duplicate = true
			break
	_fail_unless(saw_duplicate, "Shop rolls should allow duplicate cards")


func _verify_offers_and_visit_lock() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	_seed_offers(state, 1, _five_projectiles())
	_fail_unless(state.remaining_count(1) == 5, "Tower 1 should start with 5 offers")
	_fail_unless(state.extra_projectiles == 0, "Rifle stacks should start at 0")
	var picked := state.pick_offer(1, 0)
	_fail_unless(picked == UpgradeCatalogScript.ID_EXTRA_PROJECTILE, "Picking should grant extra projectile")
	_fail_unless(state.remaining_count(1) == 4, "Picked card should leave 4 offers")
	_fail_unless(state.extra_projectiles == 1, "Pick should stack extra_projectiles")
	_fail_unless(state.remaining_count(2) == 5, "Other towers should keep a full pool")

	state.mark_visited_this_life(1)
	_fail_unless(state.has_visited_this_life(1), "Opening a tower should lock it this life")
	_fail_unless(not state.has_visited_this_life(2), "Unvisited towers stay unlocked")
	state.clear_visited_this_life()
	_fail_unless(not state.has_visited_this_life(1), "Death should clear visit locks")
	_fail_unless(state.remaining_count(1) == 4, "Death should not refill offers")
	_fail_unless(state.extra_projectiles == 1, "Death should keep projectile stacks")
	state.free()


func _verify_empty_tower_confirm() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	_seed_offers(state, 3, _five_projectiles())
	for _i in 5:
		state.pick_offer(3, 0)
	_fail_unless(state.remaining_count(3) == 0, "Taking all 5 should empty the tower")
	_fail_unless(state.extra_projectiles == 5, "Five projectile picks should stack five extra shots")
	var rare_id := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PROJECTILE,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	_seed_offers(state, 6, PackedStringArray([rare_id, rare_id, rare_id, rare_id, rare_id]))
	state.pick_offer(6, 0)
	_fail_unless(state.extra_projectiles == 7, "Rare projectile should add +2 extra shots")
	state.free()


func _verify_attack_speed_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_as := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_as := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var legendary_as := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
			UpgradeCatalogScript.RARITY_LEGENDARY
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		4,
		PackedStringArray([common_as, rare_as, leftover, leftover, leftover])
	)
	state.pick_offer(4, 0)
	state.pick_offer(4, 0)
	_fail_unless(
		is_equal_approx(state.attack_speed_reduction, 0.13),
		"Common + rare Attack Speed should sum to 13%"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(state.attack_speed_reduction), 3.0 * 0.87),
		"Additive CDR should be 3.0 × 0.87"
	)
	_fail_unless(state.remaining_count(4) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Attack Speed picks should not add projectiles")

	_seed_offers(
		state,
		5,
		PackedStringArray([legendary_as, legendary_as, legendary_as, legendary_as, legendary_as])
	)
	for _i in 5:
		state.pick_offer(5, 0)
	_fail_unless(
		is_equal_approx(state.attack_speed_reduction, 0.13 + 0.75),
		"Picks past the rifle cap should still add their percent"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(state.attack_speed_reduction), 0.60),
		"Rifle wait should cap at 0.60 s"
	)
	_fail_unless(state.remaining_count(5) == 0, "Over-cap pick should still remove the card")
	state.free()


func _verify_dawn_pose() -> void:
	var tower_pos := Vector3(-1000.0, 12.0, 8.0)
	var xz: Vector2 = PlayerRigScript.in_front_xz(tower_pos)
	_fail_unless(
		is_equal_approx(xz.x, tower_pos.x + PlayerRigScript.SPAWN_EAST_OFFSET_M),
		"Wait until dawn should spawn east of the tower, not at home"
	)
	_fail_unless(is_equal_approx(xz.y, tower_pos.z), "Wait until dawn should keep the tower Z")
	_fail_unless(not is_equal_approx(xz.x, 40.0) or not is_equal_approx(tower_pos.x, 0.0), "Pose must be relative to this tower")


func _verify_visit_radius() -> void:
	var tower: UpgradeTower = UpgradeTowerScript.new()
	tower.tower_index = 1
	tower.is_home = false
	root.add_child(tower)
	tower.global_position = Vector3(-1000.0, 0.0, 0.0)
	await process_frame
	var inside := TowerVisitControllerScript.find_visit_tower(
		self, Vector3(-1000.0 + 19.0, 0.0, 0.0)
	)
	var outside := TowerVisitControllerScript.find_visit_tower(
		self, Vector3(-1000.0 + 21.0, 0.0, 0.0)
	)
	var home: UpgradeTower = UpgradeTowerScript.new()
	home.tower_index = 0
	home.is_home = true
	root.add_child(home)
	home.global_position = Vector3(0.0, 0.0, 0.0)
	await process_frame
	var at_home := TowerVisitControllerScript.find_visit_tower(self, Vector3(1.0, 0.0, 0.0))
	_fail_unless(inside == tower, "20 m should trigger a west tower")
	_fail_unless(outside == null, "Beyond 20 m should not trigger")
	_fail_unless(at_home == null, "Home tower should not open the upgrade menu")
	tower.free()
	home.free()


func _seed_offers(state: RunUpgradeState, tower_index: int, ids: PackedStringArray) -> void:
	state._offers[tower_index] = ids


func _five_projectiles() -> PackedStringArray:
	return UpgradeCatalogScript.default_offers()


func _has_duplicate(shop: PackedStringArray) -> bool:
	var seen: Dictionary = {}
	for id in shop:
		if seen.has(id):
			return true
		seen[id] = true
	return false


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
