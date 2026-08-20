extends SceneTree

const RunUpgradeStateScript = preload("res://scripts/game/run_upgrade_state.gd")
const UpgradeCatalogScript = preload("res://scripts/game/upgrade_catalog.gd")
const TowerVisitControllerScript = preload("res://scripts/game/tower_visit_controller.gd")
const PlayerRigScript = preload("res://scripts/player/player_rig.gd")
const UpgradeTowerScript = preload("res://scripts/world/upgrade_tower.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog()
	_verify_roll_shop()
	_verify_offers_and_visit_lock()
	_verify_empty_tower_confirm()
	_verify_attack_speed_stacking()
	_verify_damage_stacking()
	_verify_projectile_speed_stacking()
	_verify_glider_speed_stacking()
	_verify_hp_regen_stacking()
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
		and UpgradeCatalogScript.RARITY_WEIGHT_UNCOMMON == 20
		and UpgradeCatalogScript.RARITY_WEIGHT_RARE == 15
		and UpgradeCatalogScript.RARITY_WEIGHT_EPIC == 10
		and UpgradeCatalogScript.RARITY_WEIGHT_LEGENDARY == 5,
		"Rarity weights should be 50 / 20 / 15 / 10 / 5"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_COMMON, 0.04)
		and is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_UNCOMMON, 0.06)
		and is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_RARE, 0.09)
		and is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_EPIC, 0.12)
		and is_equal_approx(UpgradeCatalogScript.ATTACK_SPEED_LEGENDARY, 0.15),
		"Attack Speed percents should be 4 / 6 / 9 / 12 / 15"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.DAMAGE_COMMON, 0.04)
		and is_equal_approx(UpgradeCatalogScript.DAMAGE_UNCOMMON, 0.06)
		and is_equal_approx(UpgradeCatalogScript.DAMAGE_RARE, 0.09)
		and is_equal_approx(UpgradeCatalogScript.DAMAGE_EPIC, 0.12)
		and is_equal_approx(UpgradeCatalogScript.DAMAGE_LEGENDARY, 0.15),
		"Damage percents should be 4 / 6 / 9 / 12 / 15"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.PROJECTILE_SPEED_COMMON, 0.04)
		and is_equal_approx(UpgradeCatalogScript.PROJECTILE_SPEED_UNCOMMON, 0.06)
		and is_equal_approx(UpgradeCatalogScript.PROJECTILE_SPEED_RARE, 0.09)
		and is_equal_approx(UpgradeCatalogScript.PROJECTILE_SPEED_EPIC, 0.12)
		and is_equal_approx(UpgradeCatalogScript.PROJECTILE_SPEED_LEGENDARY, 0.15),
		"Projectile Speed percents should be 4 / 6 / 9 / 12 / 15"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.GLIDER_SPEED_COMMON, 0.08)
		and is_equal_approx(UpgradeCatalogScript.GLIDER_SPEED_UNCOMMON, 0.10)
		and is_equal_approx(UpgradeCatalogScript.GLIDER_SPEED_RARE, 0.12)
		and is_equal_approx(UpgradeCatalogScript.GLIDER_SPEED_EPIC, 0.16)
		and is_equal_approx(UpgradeCatalogScript.GLIDER_SPEED_LEGENDARY, 0.22),
		"Glider Speed percents should be 8 / 10 / 12 / 16 / 22"
	)
	_fail_unless(
		UpgradeCatalogScript.HP_REGEN_COMMON == 1
		and UpgradeCatalogScript.HP_REGEN_UNCOMMON == 2
		and UpgradeCatalogScript.HP_REGEN_RARE == 3
		and UpgradeCatalogScript.HP_REGEN_EPIC == 4
		and UpgradeCatalogScript.HP_REGEN_LEGENDARY == 5,
		"HP Regen rates should be 1 / 2 / 3 / 4 / 5 hp/s"
	)
	_fail_unless(
		UpgradeCatalogScript.PROJECTILE_COMMON == 1
		and UpgradeCatalogScript.PROJECTILE_UNCOMMON == 2
		and UpgradeCatalogScript.PROJECTILE_RARE == 3
		and UpgradeCatalogScript.PROJECTILE_EPIC == 4
		and UpgradeCatalogScript.PROJECTILE_LEGENDARY == 5,
		"Projectile bonuses should be +1 / +2 / +3 / +4 / +5"
	)
	_fail_unless(
		UpgradeCatalogScript.is_empty_offer(UpgradeCatalogScript.EMPTY_OFFER),
		"Empty shop slots should count as empty offers"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(UpgradeCatalogScript.EMPTY_OFFER) == "Empty",
		"Empty shop slots should be labeled Empty"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_display_name(UpgradeCatalogScript.EMPTY_OFFER) == "",
		"Empty shop slots should hide rarity"
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
		UpgradeCatalogScript.display_name(rare_proj) == "+3 projectiles",
		"Rare projectile should be labeled +3 projectiles"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PROJECTILE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "+4 projectiles",
		"Epic projectile should be labeled +4 projectiles"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PROJECTILE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "+5 projectiles",
		"Legendary projectile should be labeled +5 projectiles"
	)
	var rare_as := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_as) == "Attack Speed −9%",
		"Attack Speed rare should show −9%"
	)
	var uncommon_as := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
		UpgradeCatalogScript.RARITY_UNCOMMON
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(uncommon_as) == "Attack Speed −6%",
		"Attack Speed uncommon should show −6%"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_display_name(uncommon_as) == "UNCOMMON",
		"Uncommon cards should read UNCOMMON"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_color(uncommon_as) == UpgradeCatalogScript.COLOR_RARITY_UNCOMMON,
		"Uncommon should use the green rarity color"
	)
	var rare_dmg := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_DAMAGE,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_dmg) == "Damage +9%",
		"Damage rare should show +9%"
	)
	var rare_ps := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_ps) == "Projectile Speed +9%",
		"Projectile Speed rare should show +9%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_ps) == UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
		"projectile_speed_rare should parse as projectile_speed, not projectile"
	)
	var rare_gs := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_gs) == "Glider Speed +12%",
		"Glider Speed rare should show +12%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_gs) == UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
		"glider_speed_rare should parse as the glider_speed family"
	)
	var rare_regen := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_HP_REGEN,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_regen) == "HP Regen +3/s",
		"HP Regen rare should show +3/s"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_regen) == UpgradeCatalogScript.FAMILY_HP_REGEN,
		"hp_regen_rare should parse as the hp_regen family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HP_REGEN,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "HP Regen +1/s",
		"HP Regen common should show +1/s"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HP_REGEN,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "HP Regen +5/s",
		"HP Regen legendary should show +5/s"
	)
	var common_regen := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_HP_REGEN,
		UpgradeCatalogScript.RARITY_COMMON
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(common_regen) != null,
		"Common HP Regen should use hp_regen_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_regen) != null,
		"Rare HP Regen should use hp_regen_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HP_REGEN,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic HP Regen should use hp_regen_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HP_REGEN,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary HP Regen should use hp_regen_legendary.jpg"
	)
	var common_gs := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
		UpgradeCatalogScript.RARITY_COMMON
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(common_gs) != null,
		"Common Glider Speed should use glider_speed_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Glider Speed should use glider_speed_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_gs) != null,
		"Rare Glider Speed should use glider_speed_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Glider Speed should use glider_speed_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Glider Speed should use glider_speed_legendary.jpg"
	)
	var common_ps := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
		UpgradeCatalogScript.RARITY_COMMON
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(common_ps) != null,
		"Common Projectile Speed should use projectile_speed_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Projectile Speed should use projectile_speed_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_ps) != null,
		"Rare Projectile Speed should use projectile_speed_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Projectile Speed should use projectile_speed_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Projectile Speed should use projectile_speed_legendary.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_dmg) == UpgradeCatalogScript.FAMILY_DAMAGE,
		"damage_rare should parse as the damage family"
	)
	var common_dmg := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_DAMAGE,
		UpgradeCatalogScript.RARITY_COMMON
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(common_dmg) != null,
		"Common Damage should use damage_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DAMAGE,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Damage should use damage_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_dmg) != null,
		"Rare Damage should use damage_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DAMAGE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Damage should use damage_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DAMAGE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Damage should use damage_legendary.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_as) != null,
		"Attack Speed cards should have an icon"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_as) != UpgradeCatalogScript.ICON_ATTACK_SPEED,
		"Rare Attack Speed should use attack_speed_rare.jpg, not the family fallback"
	)
	var common_as := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
		UpgradeCatalogScript.RARITY_COMMON
	)
	var common_as_icon := UpgradeCatalogScript.icon_for(common_as)
	_fail_unless(common_as_icon != null, "Common Attack Speed should have an icon")
	_fail_unless(
		common_as_icon != UpgradeCatalogScript.ICON_ATTACK_SPEED,
		"Common Attack Speed should use attack_speed_common.jpg, not the family fallback"
	)
	var uncommon_as_icon := UpgradeCatalogScript.icon_for(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
			UpgradeCatalogScript.RARITY_UNCOMMON
		)
	)
	_fail_unless(uncommon_as_icon != null, "Uncommon Attack Speed should have an icon")
	_fail_unless(
		uncommon_as_icon != UpgradeCatalogScript.ICON_ATTACK_SPEED,
		"Uncommon Attack Speed should use attack_speed_uncommon.jpg, not the family fallback"
	)
	var epic_as := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
		UpgradeCatalogScript.RARITY_EPIC
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(epic_as) != UpgradeCatalogScript.ICON_ATTACK_SPEED,
		"Epic Attack Speed should use attack_speed_epic.jpg, not the family fallback"
	)
	var legendary_as_id := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
		UpgradeCatalogScript.RARITY_LEGENDARY
	)
	var legendary_as_tex := UpgradeCatalogScript.icon_for(legendary_as_id)
	_fail_unless(legendary_as_tex != null, "Legendary Attack Speed should have an icon")
	_fail_unless(
		legendary_as_tex != UpgradeCatalogScript.ICON_ATTACK_SPEED,
		"Legendary Attack Speed should use attack_speed_legendary.jpg, not the family fallback"
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
	var uncommon_proj := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_PROJECTILE,
		UpgradeCatalogScript.RARITY_UNCOMMON
	)
	var uncommon_proj_icon := UpgradeCatalogScript.icon_for(uncommon_proj)
	_fail_unless(uncommon_proj_icon != null, "Uncommon projectile should have an icon")
	_fail_unless(
		uncommon_proj_icon != UpgradeCatalogScript.ICON_EXTRA_PROJECTILE,
		"Uncommon projectile should use projectile_uncommon.jpg, not the family fallback"
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
	var legendary_icon := UpgradeCatalogScript.icon_for(legendary_proj)
	_fail_unless(legendary_icon != null, "Legendary projectile should have an icon")
	_fail_unless(
		legendary_icon != UpgradeCatalogScript.ICON_EXTRA_PROJECTILE,
		"Legendary projectile should use projectile_legendary.jpg, not the family fallback"
	)


func _verify_roll_shop() -> void:
	var first := UpgradeCatalogScript.roll_shop(7, 3)
	var again := UpgradeCatalogScript.roll_shop(7, 3)
	_fail_unless(first.size() == 5, "roll_shop should fill 5 slots")
	_fail_unless(first == again, "Same seed and tower should roll the same shop")
	var other_tower := UpgradeCatalogScript.roll_shop(7, 4)
	_fail_unless(other_tower.size() == 5, "Other towers should also roll 5 cards")
	for tower_index in range(1, 81):
		var shop := UpgradeCatalogScript.roll_shop(1, tower_index)
		_fail_unless(
			not _has_duplicate(shop),
			"Shop %d should not repeat a card" % tower_index
		)


func _verify_offers_and_visit_lock() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	_seed_offers(state, 1, _five_projectiles())
	_fail_unless(state.remaining_count(1) == 5, "Tower 1 should start with 5 offers")
	_fail_unless(state.extra_projectiles == 0, "Rifle stacks should start at 0")
	var picked := state.pick_offer(1, 0)
	_fail_unless(picked == UpgradeCatalogScript.ID_EXTRA_PROJECTILE, "Picking should grant extra projectile")
	_fail_unless(state.remaining_count(1) == 4, "Picked card should leave 4 offers")
	var after_pick := state.get_offers(1)
	_fail_unless(after_pick.size() == 5, "Picked card should leave an empty slot, not shrink the shop")
	_fail_unless(
		UpgradeCatalogScript.is_empty_offer(StringName(after_pick[0])),
		"Taken slot should become Empty"
	)
	_fail_unless(
		StringName(after_pick[1]) == UpgradeCatalogScript.ID_EXTRA_PROJECTILE,
		"Untaken slots should stay filled"
	)
	_fail_unless(state.pick_offer(1, 0) == &"", "Empty slots should not be pickable")
	_fail_unless(state.extra_projectiles == 1, "Pick should stack extra_projectiles")
	_fail_unless(state.remaining_count(2) == 5, "Other towers should keep a full pool")

	state.mark_visited_this_life(1)
	_fail_unless(state.has_visited_this_life(1), "Opening a tower should lock it this life")
	_fail_unless(not state.has_visited_this_life(2), "Unvisited towers stay unlocked")
	state.clear_visited_this_life()
	_fail_unless(not state.has_visited_this_life(1), "Death should clear visit locks")
	_fail_unless(state.remaining_count(1) == 4, "Death should not refill offers")
	_fail_unless(state.extra_projectiles == 1, "Death should keep projectile stacks until Try Again")
	state.reset_run()
	_fail_unless(state.extra_projectiles == 0, "Try Again should clear projectile stacks")
	_fail_unless(is_equal_approx(state.attack_speed_reduction, 0.0), "Try Again should clear Attack Speed")
	_fail_unless(is_equal_approx(state.damage_bonus, 0.0), "Try Again should clear Damage")
	_fail_unless(
		is_equal_approx(state.projectile_speed_bonus, 0.0),
		"Try Again should clear Projectile Speed"
	)
	_fail_unless(
		is_equal_approx(state.glider_speed_bonus, 0.0),
		"Try Again should clear Glider Speed"
	)
	_fail_unless(
		is_equal_approx(state.health_regen_per_sec, 0.0),
		"Try Again should clear HP Regen"
	)
	_fail_unless(state.remaining_count(1) == 4, "Try Again should not restore taken cards")
	_fail_unless(
		state.get_offers(1).size() == 5,
		"Try Again should keep the empty slot in the shop"
	)
	state.free()


func _verify_empty_tower_confirm() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	_seed_offers(state, 3, _five_projectiles())
	_pick_all_slots(state, 3)
	_fail_unless(state.remaining_count(3) == 0, "Taking all 5 should empty the tower")
	_fail_unless(state.get_offers(3).size() == 5, "Empty tower should still show 5 Empty slots")
	_fail_unless(state.extra_projectiles == 5, "Five projectile picks should stack five extra shots")
	var rare_id := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PROJECTILE,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	_seed_offers(state, 6, PackedStringArray([rare_id, rare_id, rare_id, rare_id, rare_id]))
	state.pick_offer(6, 0)
	_fail_unless(state.extra_projectiles == 8, "Rare projectile should add +3 extra shots")
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
	state.pick_offer(4, 1)
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
	_pick_all_slots(state, 5)
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


func _verify_damage_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_dmg := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_dmg := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var legendary_dmg := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_LEGENDARY
		)
	)
	_seed_offers(
		state,
		7,
		PackedStringArray([common_dmg, rare_dmg, legendary_dmg, legendary_dmg, legendary_dmg])
	)
	state.pick_offer(7, 0)
	state.pick_offer(7, 1)
	_fail_unless(
		is_equal_approx(state.damage_bonus, 0.13),
		"Common + rare Damage should sum to 13%"
	)
	_fail_unless(
		AutoRifleScript.damage_for(state.damage_bonus) == AutoRifleScript.damage_for(0.13),
		"Rifle should use the stacked damage bonus"
	)
	state.pick_offer(7, 2)
	state.pick_offer(7, 3)
	_fail_unless(
		is_equal_approx(state.damage_bonus, 0.43),
		"Damage bonus should keep stacking with no cap"
	)
	_fail_unless(state.extra_projectiles == 0, "Damage picks should not add projectiles")
	_fail_unless(
		is_equal_approx(state.attack_speed_reduction, 0.0),
		"Damage picks should not add Attack Speed"
	)
	state.free()


func _verify_projectile_speed_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_ps := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_ps := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var legendary_ps := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
			UpgradeCatalogScript.RARITY_LEGENDARY
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		8,
		PackedStringArray([common_ps, rare_ps, leftover, leftover, leftover])
	)
	state.pick_offer(8, 0)
	state.pick_offer(8, 1)
	_fail_unless(
		is_equal_approx(state.projectile_speed_bonus, 0.13),
		"Common + rare Projectile Speed should sum to 13%"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.speed_for(state.projectile_speed_bonus), 60.0 * 1.13),
		"Additive projectile speed should be 60 × 1.13"
	)
	_fail_unless(state.remaining_count(8) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Projectile Speed picks should not add projectiles")

	_seed_offers(
		state,
		9,
		PackedStringArray([legendary_ps, legendary_ps, legendary_ps, legendary_ps, legendary_ps])
	)
	_pick_all_slots(state, 9)
	_fail_unless(
		is_equal_approx(state.projectile_speed_bonus, 0.13 + 0.75),
		"Picks past the rifle cap should still add their percent"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.speed_for(state.projectile_speed_bonus), 108.0),
		"Rifle bullet speed should cap at 108 m/s"
	)
	_fail_unless(state.remaining_count(9) == 0, "Over-cap pick should still remove the card")
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.projectile_speed_bonus, 0.0),
		"Try Again should clear Projectile Speed"
	)
	state.free()


func _verify_glider_speed_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_gs := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_gs := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var legendary_gs := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_GLIDER_SPEED,
			UpgradeCatalogScript.RARITY_LEGENDARY
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		10,
		PackedStringArray([common_gs, rare_gs, leftover, leftover, leftover])
	)
	state.pick_offer(10, 0)
	state.pick_offer(10, 1)
	_fail_unless(
		is_equal_approx(state.glider_speed_bonus, 0.20),
		"Common + rare Glider Speed should sum to 20%"
	)
	_fail_unless(
		is_equal_approx(
			GliderPhysicsScript.cruise_speed_for(state.glider_speed_bonus),
			GliderPhysicsScript.FLAT_MAX_SPEED * 1.20
		),
		"Additive cruise should be 26.6 × 1.20"
	)
	_fail_unless(
		is_equal_approx(
			GliderPhysicsScript.flat_max_speed(true, state.glider_speed_bonus),
			GliderPhysicsScript.FLAT_MAX_SPEED * 1.20 * GliderPhysicsScript.BOOST_SPEED_FACTOR
		),
		"Boost should stay cruise × 1.3"
	)
	_fail_unless(state.remaining_count(10) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Glider Speed picks should not add projectiles")

	_seed_offers(
		state,
		11,
		PackedStringArray([legendary_gs, legendary_gs, legendary_gs, legendary_gs, legendary_gs])
	)
	_pick_all_slots(state, 11)
	_seed_offers(
		state,
		12,
		PackedStringArray([legendary_gs, legendary_gs, legendary_gs, legendary_gs, legendary_gs])
	)
	_pick_all_slots(state, 12)
	_fail_unless(
		is_equal_approx(state.glider_speed_bonus, 0.20 + 2.20),
		"Picks past the cruise cap should still add their percent"
	)
	_fail_unless(
		is_equal_approx(
			GliderPhysicsScript.cruise_speed_for(state.glider_speed_bonus),
			GliderPhysicsScript.CRUISE_ABSOLUTE_MAX
		),
		"Cruise should cap at CRUISE_ABSOLUTE_MAX"
	)
	_fail_unless(
		is_equal_approx(
			GliderPhysicsScript.flat_max_speed(true, state.glider_speed_bonus),
			GliderPhysicsScript.BOOST_ABSOLUTE_MAX
		),
		"Boost should cap at 100 m/s"
	)
	_fail_unless(state.remaining_count(12) == 0, "Over-cap pick should still remove the card")
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.glider_speed_bonus, 0.0),
		"Try Again should clear Glider Speed"
	)
	state.free()


func _verify_hp_regen_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_regen := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_HP_REGEN,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_regen := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_HP_REGEN,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		13,
		PackedStringArray([common_regen, rare_regen, leftover, leftover, leftover])
	)
	state.pick_offer(13, 0)
	state.pick_offer(13, 1)
	_fail_unless(
		is_equal_approx(state.health_regen_per_sec, 4.0),
		"Common + rare HP Regen should sum to 4 hp/s"
	)
	_fail_unless(state.remaining_count(13) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "HP Regen picks should not add projectiles")
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.health_regen_per_sec, 0.0),
		"Try Again should clear HP Regen"
	)
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


func _pick_all_slots(state: RunUpgradeState, tower_index: int) -> void:
	for slot in UpgradeCatalogScript.SLOTS_PER_TOWER:
		state.pick_offer(tower_index, slot)


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
