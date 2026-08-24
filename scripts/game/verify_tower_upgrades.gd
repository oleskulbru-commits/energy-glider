extends SceneTree

const RunUpgradeStateScript = preload("res://scripts/game/run_upgrade_state.gd")
const UpgradeCatalogScript = preload("res://scripts/game/upgrade_catalog.gd")
const TowerVisitControllerScript = preload("res://scripts/game/tower_visit_controller.gd")
const PlayerRigScript = preload("res://scripts/player/player_rig.gd")
const UpgradeTowerScript = preload("res://scripts/world/upgrade_tower.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")


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
	_verify_glide_stacking()
	_verify_steering_stacking()
	_verify_hp_regen_stacking()
	_verify_luck_stacking()
	_verify_luck_weights()
	_verify_momentum_retention_stacking()
	_verify_crit_stacking()
	_verify_health_stacking()
	_verify_duration_stacking()
	_verify_pushback_stacking()
	_verify_bounce_stacking()
	_verify_range_stacking()
	_verify_weapon_cards()
	_verify_weapon_hud_levels()
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
		is_equal_approx(UpgradeCatalogScript.GLIDE_COMMON, 0.08)
		and is_equal_approx(UpgradeCatalogScript.GLIDE_UNCOMMON, 0.11)
		and is_equal_approx(UpgradeCatalogScript.GLIDE_RARE, 0.15)
		and is_equal_approx(UpgradeCatalogScript.GLIDE_EPIC, 0.20)
		and is_equal_approx(UpgradeCatalogScript.GLIDE_LEGENDARY, 0.25)
		and is_equal_approx(UpgradeCatalogScript.GLIDE_CAP, 0.50),
		"Glide percents should be 8 / 11 / 15 / 20 / 25 with a 50% cap"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.STEERING_COMMON, 0.06)
		and is_equal_approx(UpgradeCatalogScript.STEERING_UNCOMMON, 0.08)
		and is_equal_approx(UpgradeCatalogScript.STEERING_RARE, 0.12)
		and is_equal_approx(UpgradeCatalogScript.STEERING_EPIC, 0.16)
		and is_equal_approx(UpgradeCatalogScript.STEERING_LEGENDARY, 0.20)
		and is_equal_approx(UpgradeCatalogScript.STEERING_CAP, 0.40),
		"Steering percents should be 6 / 8 / 12 / 16 / 20 with a 40% cap"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.HP_REGEN_PERIOD_SEC, 3.0)
		and is_equal_approx(UpgradeCatalogScript.HP_REGEN_COMMON, 0.5)
		and is_equal_approx(UpgradeCatalogScript.HP_REGEN_UNCOMMON, 1.0)
		and is_equal_approx(UpgradeCatalogScript.HP_REGEN_RARE, 1.5)
		and is_equal_approx(UpgradeCatalogScript.HP_REGEN_EPIC, 2.0)
		and is_equal_approx(UpgradeCatalogScript.HP_REGEN_LEGENDARY, 3.0),
		"HP Regen should be 0.5 / 1 / 1.5 / 2 / 3 hp per 3s"
	)
	_fail_unless(
		UpgradeCatalogScript.HEALTH_COMMON == 10
		and UpgradeCatalogScript.HEALTH_UNCOMMON == 15
		and UpgradeCatalogScript.HEALTH_RARE == 25
		and UpgradeCatalogScript.HEALTH_EPIC == 35
		and UpgradeCatalogScript.HEALTH_LEGENDARY == 45,
		"Health bonuses should be +10 / +15 / +25 / +35 / +45"
	)
	_fail_unless(
		UpgradeCatalogScript.LUCK_COMMON == 1
		and UpgradeCatalogScript.LUCK_UNCOMMON == 2
		and UpgradeCatalogScript.LUCK_RARE == 3
		and UpgradeCatalogScript.LUCK_EPIC == 4
		and UpgradeCatalogScript.LUCK_LEGENDARY == 5,
		"Luck points should be 1 / 2 / 3 / 4 / 5"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.MOMENTUM_RETENTION_COMMON, 0.08)
		and is_equal_approx(UpgradeCatalogScript.MOMENTUM_RETENTION_UNCOMMON, 0.11)
		and is_equal_approx(UpgradeCatalogScript.MOMENTUM_RETENTION_RARE, 0.15)
		and is_equal_approx(UpgradeCatalogScript.MOMENTUM_RETENTION_EPIC, 0.20)
		and is_equal_approx(UpgradeCatalogScript.MOMENTUM_RETENTION_LEGENDARY, 0.25)
		and is_equal_approx(UpgradeCatalogScript.MOMENTUM_RETENTION_CAP, 1.0),
		"Momentum Retention percents should be 8 / 11 / 15 / 20 / 25 with a 100% cap"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.CRIT_COMMON, 0.04)
		and is_equal_approx(UpgradeCatalogScript.CRIT_UNCOMMON, 0.06)
		and is_equal_approx(UpgradeCatalogScript.CRIT_RARE, 0.10)
		and is_equal_approx(UpgradeCatalogScript.CRIT_EPIC, 0.13)
		and is_equal_approx(UpgradeCatalogScript.CRIT_LEGENDARY, 0.17)
		and is_equal_approx(UpgradeCatalogScript.CRIT_CAP, 1.0),
		"Crit chances should be 4 / 6 / 10 / 13 / 17 with a 100% cap"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.DURATION_COMMON, 0.10)
		and is_equal_approx(UpgradeCatalogScript.DURATION_UNCOMMON, 0.15)
		and is_equal_approx(UpgradeCatalogScript.DURATION_RARE, 0.25)
		and is_equal_approx(UpgradeCatalogScript.DURATION_EPIC, 0.35)
		and is_equal_approx(UpgradeCatalogScript.DURATION_LEGENDARY, 0.50),
		"Duration percents should be 10 / 15 / 25 / 35 / 50"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.PUSHBACK_COMMON, 0.10)
		and is_equal_approx(UpgradeCatalogScript.PUSHBACK_UNCOMMON, 0.15)
		and is_equal_approx(UpgradeCatalogScript.PUSHBACK_RARE, 0.25)
		and is_equal_approx(UpgradeCatalogScript.PUSHBACK_EPIC, 0.35)
		and is_equal_approx(UpgradeCatalogScript.PUSHBACK_LEGENDARY, 0.50),
		"Pushback percents should be 10 / 15 / 25 / 35 / 50"
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
		UpgradeCatalogScript.BOUNCE_COMMON == 1
		and UpgradeCatalogScript.BOUNCE_UNCOMMON == 2
		and UpgradeCatalogScript.BOUNCE_RARE == 3
		and UpgradeCatalogScript.BOUNCE_EPIC == 4
		and UpgradeCatalogScript.BOUNCE_LEGENDARY == 5,
		"Bounce counts should be 1 / 2 / 3 / 4 / 5"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.RANGE_COMMON, 0.06)
		and is_equal_approx(UpgradeCatalogScript.RANGE_UNCOMMON, 0.09)
		and is_equal_approx(UpgradeCatalogScript.RANGE_RARE, 0.12)
		and is_equal_approx(UpgradeCatalogScript.RANGE_EPIC, 0.16)
		and is_equal_approx(UpgradeCatalogScript.RANGE_LEGENDARY, 0.20),
		"Range percents should be 6 / 9 / 12 / 16 / 20"
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
	var rare_glide := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_GLIDE,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_glide) == "Glide +15%",
		"Glide rare should show +15%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_glide) == UpgradeCatalogScript.FAMILY_GLIDE,
		"glide_rare should parse as the glide family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDE,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Glide +8%",
		"Glide common should show +8%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDE,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Glide +11%",
		"Glide uncommon should show +11%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Glide +25%",
		"Glide legendary should show +25%"
	)
	var rare_steering := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_STEERING,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_steering) == "Steering +12%",
		"Steering rare should show +12%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_steering) == UpgradeCatalogScript.FAMILY_STEERING,
		"steering_rare should parse as the steering family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_STEERING,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Steering +6%",
		"Steering common should show +6%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_STEERING,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Steering +8%",
		"Steering uncommon should show +8%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_STEERING,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "Steering +16%",
		"Steering epic should show +16%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_STEERING,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Steering +20%",
		"Steering legendary should show +20%"
	)
	var rare_regen := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_HP_REGEN,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_regen) == "HP Regen +1.5/3s",
		"HP Regen rare should show +1.5/3s"
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
		) == "HP Regen +0.5/3s",
		"HP Regen common should show +0.5/3s"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HP_REGEN,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "HP Regen +1/3s",
		"HP Regen uncommon should show +1/3s"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HP_REGEN,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "HP Regen +3/3s",
		"HP Regen legendary should show +3/3s"
	)
	var rare_hp := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_HEALTH,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_hp) == "Health +25",
		"Health rare should show +25"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_hp) == UpgradeCatalogScript.FAMILY_HEALTH,
		"health_rare should parse as the health family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HEALTH,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Health +10",
		"Health common should show +10"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HEALTH,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Health +15",
		"Health uncommon should show +15"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HEALTH,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Health +45",
		"Health legendary should show +45"
	)
	var rare_luck := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_LUCK,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_luck) == "Luck +3",
		"Luck rare should show +3"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_luck) == UpgradeCatalogScript.FAMILY_LUCK,
		"luck_rare should parse as the luck family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_LUCK,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Luck +1",
		"Luck common should show +1"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_LUCK,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Luck +5",
		"Luck legendary should show +5"
	)
	var rare_mr := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_mr) == "Momentum Retention +15%",
		"Momentum Retention rare should show +15%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_mr) == UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
		"momentum_retention_rare should parse as the momentum_retention family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Momentum Retention +8%",
		"Momentum Retention common should show +8%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Momentum Retention +11%",
		"Momentum Retention uncommon should show +11%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Momentum Retention +25%",
		"Momentum Retention legendary should show +25%"
	)
	var rare_crit := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_CRIT,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_crit) == "Crit +10%",
		"Crit rare should show +10%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_crit) == UpgradeCatalogScript.FAMILY_CRIT,
		"crit_rare should parse as the crit family"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(&"crit_common") == UpgradeCatalogScript.FAMILY_CRIT,
		"crit_ should not parse as the damage family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Crit +4%",
		"Crit common should show +4%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Crit +6%",
		"Crit uncommon should show +6%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "Crit +13%",
		"Crit epic should show +13%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Crit +17%",
		"Crit legendary should show +17%"
	)
	var rare_duration := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_DURATION,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_duration) == "Duration +25%",
		"Duration rare should show +25%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_duration) == UpgradeCatalogScript.FAMILY_DURATION,
		"duration_rare should parse as the duration family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Duration +10%",
		"Duration common should show +10%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Duration +15%",
		"Duration uncommon should show +15%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "Duration +35%",
		"Duration epic should show +35%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Duration +50%",
		"Duration legendary should show +50%"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Duration should use duration_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Duration should use duration_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_RARE
			)
		) != null,
		"Rare Duration should use duration_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Duration should use duration_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_DURATION,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Duration should use duration_legendary.jpg"
	)
	var rare_pushback := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_PUSHBACK,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_pushback) == "Pushback +25%",
		"Pushback rare should show +25%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_pushback) == UpgradeCatalogScript.FAMILY_PUSHBACK,
		"pushback_rare should parse as the pushback family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Pushback +10%",
		"Pushback common should show +10%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Pushback +15%",
		"Pushback uncommon should show +15%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "Pushback +35%",
		"Pushback epic should show +35%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Pushback +50%",
		"Pushback legendary should show +50%"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Pushback should use pushback_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Pushback should use pushback_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_RARE
			)
		) != null,
		"Rare Pushback should use pushback_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Pushback should use pushback_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_PUSHBACK,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Pushback should use pushback_legendary.jpg"
	)
	var rare_bounce := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_BOUNCE,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_bounce) == "Bounce +3",
		"Bounce rare should show +3"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_bounce) == UpgradeCatalogScript.FAMILY_BOUNCE,
		"bounce_rare should parse as the bounce family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_BOUNCE,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Bounce +1",
		"Bounce common should show +1"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_BOUNCE,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Bounce +2",
		"Bounce uncommon should show +2"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_BOUNCE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "Bounce +4",
		"Bounce epic should show +4"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_BOUNCE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Bounce +5",
		"Bounce legendary should show +5"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_BOUNCE,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Bounce should use bounce_common.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_BOUNCE,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Bounce should use bounce_uncommon.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_bounce) != null,
		"Rare Bounce should use bounce_rare.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_BOUNCE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Bounce should use bounce_epic.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_BOUNCE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Bounce should use bounce_legendary.png"
	)
	var rare_range := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_RANGE,
		UpgradeCatalogScript.RARITY_RARE
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(rare_range) == "Range +12%",
		"Range rare should show +12%"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(rare_range) == UpgradeCatalogScript.FAMILY_RANGE,
		"range_rare should parse as the range family"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_RANGE,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Range +6%",
		"Range common should show +6%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_RANGE,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) == "Range +9%",
		"Range uncommon should show +9%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_RANGE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) == "Range +16%",
		"Range epic should show +16%"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_RANGE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) == "Range +20%",
		"Range legendary should show +20%"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_RANGE,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Range should use range_common.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_RANGE,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Range should use range_uncommon.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_range) != null,
		"Rare Range should use range_rare.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_RANGE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Range should use range_epic.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_RANGE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Range should use range_legendary.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Crit should use crit_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Crit should use crit_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_RARE
			)
		) != null,
		"Rare Crit should use crit_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Crit should use crit_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_CRIT,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Crit should use crit_legendary.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Momentum Retention should use momentum_retention_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Momentum Retention should use momentum_retention_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
				UpgradeCatalogScript.RARITY_RARE
			)
		) != null,
		"Rare Momentum Retention should use momentum_retention_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Momentum Retention should use momentum_retention_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Momentum Retention should use momentum_retention_legendary.jpg"
	)
	var common_luck := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_LUCK,
		UpgradeCatalogScript.RARITY_COMMON
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(common_luck) != null,
		"Common Luck should use luck_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_LUCK,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Luck should use luck_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_LUCK,
				UpgradeCatalogScript.RARITY_RARE
			)
		) != null,
		"Rare Luck should use luck_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_LUCK,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Luck should use luck_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_LUCK,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Luck should use luck_legendary.jpg"
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
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HP_REGEN,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon HP Regen should use hp_regen_uncommon.jpg"
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
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HEALTH,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Health should use health_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HEALTH,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Health should use health_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HEALTH,
				UpgradeCatalogScript.RARITY_RARE
			)
		) != null,
		"Rare Health should use health_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HEALTH,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Health should use health_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_HEALTH,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Health should use health_legendary.jpg"
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
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDE,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Glide should use glide_common.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDE,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Glide should use glide_uncommon.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_glide) != null,
		"Rare Glide should use glide_rare.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDE,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Glide should use glide_epic.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_GLIDE,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Glide should use glide_legendary.jpg"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_STEERING,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) != null,
		"Common Steering should use steering_common.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_STEERING,
				UpgradeCatalogScript.RARITY_UNCOMMON
			)
		) != null,
		"Uncommon Steering should use steering_uncommon.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(rare_steering) != null,
		"Rare Steering should use steering_rare.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_STEERING,
				UpgradeCatalogScript.RARITY_EPIC
			)
		) != null,
		"Epic Steering should use steering_epic.png"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_STEERING,
				UpgradeCatalogScript.RARITY_LEGENDARY
			)
		) != null,
		"Legendary Steering should use steering_legendary.png"
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
	var first := UpgradeCatalogScript.roll_shop(7, 3, 0, true, false)
	var again := UpgradeCatalogScript.roll_shop(7, 3, 0, true, false)
	_fail_unless(first.size() == 5, "roll_shop should fill 5 slots")
	_fail_unless(first == again, "Same seed and tower should roll the same shop")
	var other_tower := UpgradeCatalogScript.roll_shop(7, 4, 0, true, false)
	_fail_unless(other_tower.size() == 5, "Other towers should also roll 5 cards")
	for tower_index in range(1, 81):
		var shop := UpgradeCatalogScript.roll_shop(1, tower_index, 0, true, false)
		_fail_unless(
			not _has_duplicate(shop),
			"Shop %d should not repeat a card" % tower_index
		)
	var lucky := UpgradeCatalogScript.roll_shop(7, 3, 8, true, false)
	var lucky_again := UpgradeCatalogScript.roll_shop(7, 3, 8, true, false)
	_fail_unless(lucky == lucky_again, "Same seed, tower, and luck should roll the same shop")
	_fail_unless(lucky.size() == 5, "Lucky shops should still fill 5 slots")
	for tower_index in range(1, 81):
		var shop := UpgradeCatalogScript.roll_shop(1, tower_index, 20, true, false)
		_fail_unless(
			not _has_duplicate(shop),
			"Lucky shop %d should not repeat a card" % tower_index
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
		is_equal_approx(state.glide_bonus, 0.0),
		"Try Again should clear Glide"
	)
	_fail_unless(
		is_equal_approx(state.health_regen_per_sec, 0.0),
		"Try Again should clear HP Regen"
	)
	_fail_unless(state.luck_bonus == 0, "Try Again should clear Luck")
	_fail_unless(
		is_equal_approx(state.momentum_retention, 0.0),
		"Try Again should clear Momentum Retention"
	)
	_fail_unless(
		is_equal_approx(state.crit_chance, 0.0),
		"Try Again should clear Crit"
	)
	_fail_unless(state.max_health_bonus == 0, "Try Again should clear Health")
	_fail_unless(
		is_equal_approx(state.duration_bonus, 0.0),
		"Try Again should clear Duration"
	)
	_fail_unless(
		is_equal_approx(state.pushback_bonus, 0.0),
		"Try Again should clear Pushback"
	)
	_fail_unless(state.bounce_count == 0, "Try Again should clear Bounce")
	_fail_unless(
		is_equal_approx(state.range_bonus, 0.0),
		"Try Again should clear Range"
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


func _verify_glide_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_glide := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_GLIDE,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_glide := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_GLIDE,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		21,
		PackedStringArray([common_glide, rare_glide, leftover, leftover, leftover])
	)
	state.pick_offer(21, 0)
	state.pick_offer(21, 1)
	_fail_unless(
		is_equal_approx(state.glide_bonus, 0.23),
		"Common + rare Glide should sum to 23%"
	)
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.air_gravity_mul(state.glide_bonus), 0.77),
		"23% Glide should cut air gravity to 77%"
	)
	_fail_unless(state.remaining_count(21) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Glide picks should not add projectiles")
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.air_gravity_mul(0.80), 0.50),
		"Glide over the cap should still leave half air gravity"
	)
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.glide_bonus, 0.0),
		"Try Again should clear Glide"
	)
	state.free()


func _verify_steering_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_steer := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_STEERING,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_steer := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_STEERING,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		32,
		PackedStringArray([common_steer, rare_steer, leftover, leftover, leftover])
	)
	state.pick_offer(32, 0)
	state.pick_offer(32, 1)
	_fail_unless(
		is_equal_approx(state.steering_bonus, 0.18),
		"Common + rare Steering should sum to 18%"
	)
	_fail_unless(
		is_equal_approx(GliderPlayerScript.steering_mul(state.steering_bonus), 1.18),
		"18% Steering should multiply yaw and grip by 1.18"
	)
	_fail_unless(state.remaining_count(32) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Steering picks should not add projectiles")
	var legendary_steer := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_STEERING,
			UpgradeCatalogScript.RARITY_LEGENDARY
		)
	)
	_seed_offers(
		state,
		33,
		PackedStringArray([legendary_steer, legendary_steer, leftover, leftover, leftover])
	)
	state.pick_offer(33, 0)
	state.pick_offer(33, 1)
	_fail_unless(
		is_equal_approx(state.steering_bonus, 0.58),
		"Stacks past the cap should still add their percent"
	)
	_fail_unless(
		is_equal_approx(GliderPlayerScript.steering_mul(state.steering_bonus), 1.40),
		"Steering should cap at +40%"
	)
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.steering_bonus, 0.0),
		"Try Again should clear Steering"
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
		is_equal_approx(state.health_regen_per_sec, 2.0 / 3.0),
		"Common + rare HP Regen should sum to 2 hp/3s"
	)
	_fail_unless(state.remaining_count(13) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "HP Regen picks should not add projectiles")
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.health_regen_per_sec, 0.0),
		"Try Again should clear HP Regen"
	)
	state.free()


func _verify_luck_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_luck := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_LUCK,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_luck := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_LUCK,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		14,
		PackedStringArray([common_luck, rare_luck, leftover, leftover, leftover])
	)
	state.pick_offer(14, 0)
	state.pick_offer(14, 1)
	_fail_unless(state.luck_bonus == 4, "Common + rare Luck should sum to 4")
	_fail_unless(state.remaining_count(14) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Luck picks should not add projectiles")
	state.reset_run()
	_fail_unless(state.luck_bonus == 0, "Try Again should clear Luck")
	state.free()


func _verify_luck_weights() -> void:
	var base := UpgradeCatalogScript.rarity_weights_for_luck(0)
	_fail_unless(
		base.size() == 5
		and int(base[0]) == 50
		and int(base[1]) == 20
		and int(base[2]) == 15
		and int(base[3]) == 10
		and int(base[4]) == 5,
		"Luck 0 should keep base rarity weights"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_luck_for(UpgradeCatalogScript.FAMILY_LUCK, 20) == 0,
		"Luck cards should ignore luck_bonus when rolling rarity"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_luck_for(UpgradeCatalogScript.FAMILY_DAMAGE, 20) == 20,
		"Non-luck families should use luck_bonus when rolling rarity"
	)
	var at_zero_common := UpgradeCatalogScript.rarity_weights_for_luck(13)
	_fail_unless(int(at_zero_common[0]) == 0, "Luck 13 should drive Common to 0%")
	_fail_unless(
		_weights_valid(at_zero_common),
		"Luck 13 weights should stay non-negative and sum to 100"
	)
	var after_common := UpgradeCatalogScript.rarity_weights_for_luck(14)
	_fail_unless(int(after_common[0]) == 0, "Further luck should keep Common at 0%")
	_fail_unless(
		int(after_common[1]) == int(at_zero_common[1]) - 1,
		"After Common is gone, next luck should take 1 from Uncommon"
	)
	_fail_unless(
		int(after_common[2]) == int(at_zero_common[2]) + 1,
		"After Common is gone, next luck should add 1 to Rare"
	)
	_fail_unless(
		int(after_common[3]) == int(at_zero_common[3])
		and int(after_common[4]) == int(at_zero_common[4]),
		"After Common is gone, leftover chips should not dump into Epic/Legendary"
	)
	_fail_unless(
		_weights_valid(after_common),
		"Luck 14 weights should stay non-negative and sum to 100"
	)
	var reached_legendary := false
	for luck in range(0, 400):
		var weights := UpgradeCatalogScript.rarity_weights_for_luck(luck)
		_fail_unless(
			_weights_valid(weights),
			"Luck %d weights should stay non-negative and sum to 100" % luck
		)
		if int(weights[4]) == 100:
			reached_legendary = true
			_fail_unless(luck > 80, "All-legendary should take a large luck stack")
			break
	_fail_unless(reached_legendary, "Enough luck should make Legendary 100%")


func _weights_valid(weights: PackedInt32Array) -> bool:
	if weights.size() != 5:
		return false
	var total := 0
	for weight in weights:
		if int(weight) < 0:
			return false
		total += int(weight)
	return total == 100


func _verify_momentum_retention_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_mr := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_mr := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_MOMENTUM_RETENTION,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		15,
		PackedStringArray([common_mr, rare_mr, leftover, leftover, leftover])
	)
	state.pick_offer(15, 0)
	state.pick_offer(15, 1)
	_fail_unless(
		is_equal_approx(state.momentum_retention, 0.23),
		"Common + rare Momentum Retention should sum to 23%"
	)
	_fail_unless(state.remaining_count(15) == 3, "Leftover cards should stay in the shop")
	_fail_unless(
		state.extra_projectiles == 0,
		"Momentum Retention picks should not add projectiles"
	)
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.momentum_retention, 0.0),
		"Try Again should clear Momentum Retention"
	)
	state.free()


func _verify_crit_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_crit := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_CRIT,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_crit := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_CRIT,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		16,
		PackedStringArray([common_crit, rare_crit, leftover, leftover, leftover])
	)
	state.pick_offer(16, 0)
	state.pick_offer(16, 1)
	_fail_unless(
		is_equal_approx(state.crit_chance, 0.14),
		"Common + rare Crit should sum to 14%"
	)
	_fail_unless(state.remaining_count(16) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Crit picks should not add projectiles")
	_fail_unless(
		is_equal_approx(state.damage_bonus, 0.0),
		"Crit picks should not add Damage"
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_fail_unless(not AutoRifleScript.roll_crit(0.0, rng), "0% crit chance should never crit")
	_fail_unless(AutoRifleScript.roll_crit(1.0, rng), "100% crit chance should always crit")
	_fail_unless(
		AutoRifleScript.crit_damage_for(10, true) == 20,
		"A crit should double base 10 damage to 20"
	)
	_fail_unless(
		AutoRifleScript.crit_damage_for(10, false) == 10,
		"A non-crit should keep base damage"
	)
	_fail_unless(
		AutoRifleScript.crit_damage_for(AutoRifleScript.damage_for(0.13), true) == 22,
		"Crit should double after Damage rounding (11 -> 22)"
	)
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.crit_chance, 0.0),
		"Try Again should clear Crit"
	)
	state.free()


func _verify_health_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_hp := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_HEALTH,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_hp := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_HEALTH,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		17,
		PackedStringArray([common_hp, rare_hp, leftover, leftover, leftover])
	)
	state.pick_offer(17, 0)
	state.pick_offer(17, 1)
	_fail_unless(state.max_health_bonus == 35, "Common + rare Health should sum to +35")
	_fail_unless(state.remaining_count(17) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Health picks should not add projectiles")
	state.reset_run()
	_fail_unless(state.max_health_bonus == 0, "Try Again should clear Health")
	state.free()


func _verify_duration_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_duration := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DURATION,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_duration := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DURATION,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		18,
		PackedStringArray([common_duration, rare_duration, leftover, leftover, leftover])
	)
	state.pick_offer(18, 0)
	state.pick_offer(18, 1)
	_fail_unless(
		is_equal_approx(state.duration_bonus, 0.35),
		"Common + rare Duration should sum to 35%"
	)
	_fail_unless(state.remaining_count(18) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Duration picks should not add projectiles")
	_fail_unless(
		is_equal_approx(state.damage_bonus, 0.0),
		"Duration picks should not add Damage"
	)
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.duration_bonus, 0.0),
		"Try Again should clear Duration"
	)
	state.free()


func _verify_pushback_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_pushback := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PUSHBACK,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_pushback := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PUSHBACK,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		19,
		PackedStringArray([common_pushback, rare_pushback, leftover, leftover, leftover])
	)
	state.pick_offer(19, 0)
	state.pick_offer(19, 1)
	_fail_unless(
		is_equal_approx(state.pushback_bonus, 0.35),
		"Common + rare Pushback should sum to 35%"
	)
	_fail_unless(state.remaining_count(19) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Pushback picks should not add projectiles")
	_fail_unless(
		is_equal_approx(state.duration_bonus, 0.0),
		"Pushback picks should not add Duration"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.knockback_speed_for(state.pushback_bonus), 12.0 * 1.35),
		"35% Pushback should shove at 12 × 1.35"
	)
	state.reset_run()
	_fail_unless(
		is_equal_approx(state.pushback_bonus, 0.0),
		"Try Again should clear Pushback"
	)
	state.free()


func _verify_bounce_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_bounce := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_BOUNCE,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_bounce := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_BOUNCE,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		23,
		PackedStringArray([common_bounce, rare_bounce, leftover, leftover, leftover])
	)
	state.pick_offer(23, 0)
	state.pick_offer(23, 1)
	_fail_unless(state.bounce_count == 4, "Common + rare Bounce should sum to 4")
	_fail_unless(state.remaining_count(23) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Bounce picks should not add projectiles")
	_fail_unless(
		state.bounce_count_for(UpgradeCatalogScript.FAMILY_RIFLE) == 4
		and state.bounce_count_for(UpgradeCatalogScript.FAMILY_LASER) == 4
		and state.bounce_count_for(UpgradeCatalogScript.FAMILY_TESLA) == 4,
		"Shop Bounce should apply to every owned projectile weapon"
	)
	state.reset_run()
	_fail_unless(state.bounce_count == 0, "Try Again should clear Bounce")
	state.grant_starter(UpgradeCatalogScript.FAMILY_RIFLE)
	var rifle_bounce := UpgradeCatalogScript.encode_weapon_offer(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RIFLE,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_BOUNCE,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	_seed_offers(
		state,
		24,
		PackedStringArray([rifle_bounce, leftover, leftover, leftover, leftover])
	)
	state.pick_offer(24, 0)
	_fail_unless(
		state.bounce_count == 0
		and state.bounce_count_for(UpgradeCatalogScript.FAMILY_RIFLE) == 1
		and state.bounce_count_for(UpgradeCatalogScript.FAMILY_LASER) == 0,
		"Rifle bundle Bounce should stay on the Rifle"
	)
	state.free()


func _verify_range_stacking() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var common_range := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RANGE,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var rare_range := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RANGE,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		25,
		PackedStringArray([common_range, rare_range, leftover, leftover, leftover])
	)
	state.pick_offer(25, 0)
	state.pick_offer(25, 1)
	_fail_unless(
		is_equal_approx(state.range_bonus, 0.18),
		"Common + rare Range should sum to 18%"
	)
	_fail_unless(state.remaining_count(25) == 3, "Leftover cards should stay in the shop")
	_fail_unless(state.extra_projectiles == 0, "Range picks should not add projectiles")
	_fail_unless(
		is_equal_approx(state.range_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE), 0.18)
		and is_equal_approx(state.range_bonus_for(UpgradeCatalogScript.FAMILY_LASER), 0.18)
		and is_equal_approx(state.range_bonus_for(UpgradeCatalogScript.FAMILY_TESLA), 0.18),
		"Shop Range should apply to every owned projectile weapon"
	)
	state.reset_run()
	_fail_unless(is_equal_approx(state.range_bonus, 0.0), "Try Again should clear Range")
	state.grant_starter(UpgradeCatalogScript.FAMILY_RIFLE)
	var rifle_range := UpgradeCatalogScript.encode_weapon_offer(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RIFLE,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RANGE,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	_seed_offers(
		state,
		26,
		PackedStringArray([rifle_range, leftover, leftover, leftover, leftover])
	)
	state.pick_offer(26, 0)
	_fail_unless(
		is_equal_approx(state.range_bonus, 0.0)
		and is_equal_approx(state.range_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE), 0.06)
		and is_equal_approx(state.range_bonus_for(UpgradeCatalogScript.FAMILY_LASER), 0.0),
		"Rifle bundle Range should stay on the Rifle"
	)
	state.free()


func _verify_weapon_cards() -> void:
	var rifle_common := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_RIFLE,
		UpgradeCatalogScript.RARITY_COMMON
	)
	var laser_legendary := UpgradeCatalogScript.make_id(
		UpgradeCatalogScript.FAMILY_LASER,
		UpgradeCatalogScript.RARITY_LEGENDARY
	)
	var encoded := UpgradeCatalogScript.encode_weapon_offer(
		rifle_common,
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	_fail_unless(
		encoded == "rifle_common|damage_common|attack_speed_common",
		"Weapon offers should encode as base|part|part"
	)
	_fail_unless(
		UpgradeCatalogScript.weapon_base_id(StringName(encoded)) == rifle_common,
		"weapon_base_id should strip the pair payload"
	)
	_fail_unless(
		UpgradeCatalogScript.family_of(StringName(encoded)) == UpgradeCatalogScript.FAMILY_RIFLE,
		"Encoded rifle cards should parse as the rifle family"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_of(StringName(encoded)) == UpgradeCatalogScript.RARITY_COMMON,
		"Encoded rifle cards should keep COMMON rarity"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(StringName(encoded)) == "Rifle",
		"Rifle cards should be labeled Rifle"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(laser_legendary) == "Laser",
		"Laser cards should be labeled Laser"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(
			UpgradeCatalogScript.make_id(
				UpgradeCatalogScript.FAMILY_TESLA,
				UpgradeCatalogScript.RARITY_COMMON
			)
		) == "Tesla Coil",
		"Tesla cards should be labeled Tesla Coil"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_display_name(StringName(encoded)) == "COMMON",
		"Weapon rarity line should stay COMMON–LEGENDARY"
	)
	var bonus_lines := UpgradeCatalogScript.weapon_bonus_lines(StringName(encoded))
	_fail_unless(
		bonus_lines.size() == 2
		and bonus_lines[0] == "Damage +4%"
		and bonus_lines[1] == "Attack Speed −4%",
		"Weapon bonus lines should use child catalog display names"
	)
	var tesla_families := UpgradeCatalogScript.eligible_families(UpgradeCatalogScript.FAMILY_TESLA)
	var laser_families := UpgradeCatalogScript.eligible_families(UpgradeCatalogScript.FAMILY_LASER)
	var rifle_families := UpgradeCatalogScript.eligible_families(UpgradeCatalogScript.FAMILY_RIFLE)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_PUSHBACK not in tesla_families
		and UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED not in tesla_families
		and UpgradeCatalogScript.FAMILY_DURATION not in tesla_families
		and UpgradeCatalogScript.FAMILY_CRIT in tesla_families
		and UpgradeCatalogScript.FAMILY_BOUNCE in tesla_families
		and UpgradeCatalogScript.FAMILY_RANGE in tesla_families
		and UpgradeCatalogScript.FAMILY_PROJECTILE in tesla_families,
		"Tesla should roll projectiles, crit, bounce, and range, not duration, pushback, or projectile speed"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_PUSHBACK not in laser_families
		and UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED not in laser_families
		and UpgradeCatalogScript.FAMILY_DURATION in laser_families
		and UpgradeCatalogScript.FAMILY_BOUNCE in laser_families
		and UpgradeCatalogScript.FAMILY_RANGE in laser_families,
		"Laser should roll duration, bounce, and range, not pushback or projectile speed"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_DURATION not in rifle_families
		and UpgradeCatalogScript.FAMILY_PUSHBACK in rifle_families
		and UpgradeCatalogScript.FAMILY_BOUNCE in rifle_families
		and UpgradeCatalogScript.FAMILY_RANGE in rifle_families,
		"Rifle should roll pushback, bounce, and range, not duration"
	)
	var rng := RandomNumberGenerator.new()
	for seed in range(1, 241):
		rng.seed = seed
		var laser_parts := UpgradeCatalogScript.roll_weapon_parts(
			UpgradeCatalogScript.FAMILY_LASER,
			UpgradeCatalogScript.RARITY_LEGENDARY,
			rng
		)
		_fail_unless(laser_parts.size() == 2, "Laser cards should roll two stats")
		var laser_a := UpgradeCatalogScript.family_of(StringName(laser_parts[0]))
		var laser_b := UpgradeCatalogScript.family_of(StringName(laser_parts[1]))
		_fail_unless(laser_a != laser_b, "Weapon pair families should be unique")
		_fail_unless(
			UpgradeCatalogScript.rarity_of(StringName(laser_parts[0]))
			== UpgradeCatalogScript.RARITY_LEGENDARY
			and UpgradeCatalogScript.rarity_of(StringName(laser_parts[1]))
			== UpgradeCatalogScript.RARITY_LEGENDARY,
			"Both weapon children should share the card rarity"
		)
		_fail_unless(
			laser_a != UpgradeCatalogScript.FAMILY_PUSHBACK
			and laser_b != UpgradeCatalogScript.FAMILY_PUSHBACK
			and laser_a != UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED
			and laser_b != UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
			"Laser legendary pair never includes pushback or projectile speed"
		)
		rng.seed = seed + 1000
		var rifle_parts := UpgradeCatalogScript.roll_weapon_parts(
			UpgradeCatalogScript.FAMILY_RIFLE,
			UpgradeCatalogScript.RARITY_EPIC,
			rng
		)
		_fail_unless(rifle_parts.size() == 2, "Rifle cards should roll two stats")
		var rifle_a := UpgradeCatalogScript.family_of(StringName(rifle_parts[0]))
		var rifle_b := UpgradeCatalogScript.family_of(StringName(rifle_parts[1]))
		_fail_unless(rifle_a != rifle_b, "Rifle pair families should be unique")
		_fail_unless(
			rifle_a != UpgradeCatalogScript.FAMILY_DURATION
			and rifle_b != UpgradeCatalogScript.FAMILY_DURATION,
			"Rifle never includes duration"
		)
		rng.seed = seed + 2000
		var tesla_parts := UpgradeCatalogScript.roll_weapon_parts(
			UpgradeCatalogScript.FAMILY_TESLA,
			UpgradeCatalogScript.RARITY_RARE,
			rng
		)
		_fail_unless(tesla_parts.size() == 2, "Tesla cards should roll two stats")
		var tesla_a := UpgradeCatalogScript.family_of(StringName(tesla_parts[0]))
		var tesla_b := UpgradeCatalogScript.family_of(StringName(tesla_parts[1]))
		_fail_unless(tesla_a != tesla_b, "Tesla pair families should be unique")
		_fail_unless(
			tesla_a != UpgradeCatalogScript.FAMILY_DURATION
			and tesla_b != UpgradeCatalogScript.FAMILY_DURATION
			and tesla_a != UpgradeCatalogScript.FAMILY_PUSHBACK
			and tesla_b != UpgradeCatalogScript.FAMILY_PUSHBACK
			and tesla_a != UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED
			and tesla_b != UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED,
			"Tesla never includes duration, pushback, or projectile speed"
		)
	var rarities: Array[StringName] = [
		UpgradeCatalogScript.RARITY_COMMON,
		UpgradeCatalogScript.RARITY_UNCOMMON,
		UpgradeCatalogScript.RARITY_RARE,
		UpgradeCatalogScript.RARITY_EPIC,
		UpgradeCatalogScript.RARITY_LEGENDARY
	]
	for rarity in rarities:
		_fail_unless(
			UpgradeCatalogScript.icon_for(
				UpgradeCatalogScript.make_id(UpgradeCatalogScript.FAMILY_RIFLE, rarity)
			)
			!= null,
			"Rifle %s should use rifle_%s.jpg" % [String(rarity), String(rarity)]
		)
		_fail_unless(
			UpgradeCatalogScript.icon_for(
				UpgradeCatalogScript.make_id(UpgradeCatalogScript.FAMILY_LASER, rarity)
			)
			!= null,
			"Laser %s should use laser_%s.jpg" % [String(rarity), String(rarity)]
		)
		_fail_unless(
			UpgradeCatalogScript.icon_for(
				UpgradeCatalogScript.make_id(UpgradeCatalogScript.FAMILY_TESLA, rarity)
			)
			!= null,
			"Tesla %s should use tesla_%s.png" % [String(rarity), String(rarity)]
		)
	_fail_unless(
		UpgradeCatalogScript.icon_for(StringName(encoded)) != null,
		"Encoded rifle offers should load rifle_common.jpg from the base id"
	)
	_fail_unless(
		UpgradeCatalogScript.is_weapon_unlock(UpgradeCatalogScript.ID_UNLOCK_RIFLE)
		and UpgradeCatalogScript.display_name(UpgradeCatalogScript.ID_UNLOCK_RIFLE) == "Rifle"
		and UpgradeCatalogScript.rarity_display_name(UpgradeCatalogScript.ID_UNLOCK_RIFLE) == "",
		"Unlock rifle should be named Rifle with no rarity line"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(UpgradeCatalogScript.ID_UNLOCK_LASER) != null,
		"Unlock laser should use the common laser icon"
	)
	_fail_unless(
		UpgradeCatalogScript.is_weapon_unlock(UpgradeCatalogScript.ID_UNLOCK_TESLA)
		and UpgradeCatalogScript.display_name(UpgradeCatalogScript.ID_UNLOCK_TESLA) == "Tesla Coil"
		and UpgradeCatalogScript.rarity_display_name(UpgradeCatalogScript.ID_UNLOCK_TESLA) == "",
		"Unlock tesla should be named Tesla Coil with no rarity line"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for(UpgradeCatalogScript.ID_UNLOCK_TESLA) != null,
		"Unlock tesla should use tesla_common.png"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_GLIDE
		in UpgradeCatalogScript.eligible_shop_families(false, false),
		"Glide should roll without owning a weapon"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_STEERING
		in UpgradeCatalogScript.eligible_shop_families(false, false),
		"Steering should roll without owning a weapon"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_STEERING
		not in UpgradeCatalogScript.eligible_families(UpgradeCatalogScript.FAMILY_RIFLE)
		and UpgradeCatalogScript.FAMILY_STEERING
		not in UpgradeCatalogScript.eligible_families(UpgradeCatalogScript.FAMILY_LASER)
		and UpgradeCatalogScript.FAMILY_STEERING
		not in UpgradeCatalogScript.eligible_families(UpgradeCatalogScript.FAMILY_TESLA),
		"Steering should be a shop-wide glider card, not a weapon part"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_BOUNCE
		not in UpgradeCatalogScript.eligible_shop_families(false, false),
		"Bounce should not roll until a weapon is owned"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_BOUNCE
		in UpgradeCatalogScript.eligible_shop_families(true, false)
		and UpgradeCatalogScript.FAMILY_BOUNCE
		in UpgradeCatalogScript.eligible_shop_families(false, true)
		and UpgradeCatalogScript.FAMILY_BOUNCE
		in UpgradeCatalogScript.eligible_shop_families(false, false, true),
		"Bounce should roll in rifle-only, laser-only, and tesla-only shops"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_RANGE
		not in UpgradeCatalogScript.eligible_shop_families(false, false),
		"Range should not roll until a weapon is owned"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_RANGE
		in UpgradeCatalogScript.eligible_shop_families(true, false)
		and UpgradeCatalogScript.FAMILY_RANGE
		in UpgradeCatalogScript.eligible_shop_families(false, true)
		and UpgradeCatalogScript.FAMILY_RANGE
		in UpgradeCatalogScript.eligible_shop_families(false, false, true),
		"Range should roll in rifle-only, laser-only, and tesla-only shops"
	)
	var rifle_n := UpgradeCatalogScript.eligible_shop_families(true, false).size()
	var laser_n := UpgradeCatalogScript.eligible_shop_families(false, true).size()
	_fail_unless(
		UpgradeCatalogScript.FAMILY_DURATION not in UpgradeCatalogScript.eligible_shop_families(true, false),
		"Rifle-only shops should not roll Duration"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_PUSHBACK not in UpgradeCatalogScript.eligible_shop_families(false, true)
		and UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED not in UpgradeCatalogScript.eligible_shop_families(false, true),
		"Laser-only shops should not roll Pushback or Projectile Speed"
	)
	_fail_unless(
		is_equal_approx(UpgradeCatalogScript.unlock_chance(1, rifle_n), 1.0 / float(rifle_n)),
		"Tower 1 unlock chance should be 1/N"
	)
	_fail_unless(
		is_equal_approx(
			UpgradeCatalogScript.unlock_chance(2, rifle_n),
			1.0 / float(rifle_n) + 0.05
		),
		"Tower 2 unlock chance should be 1/N + 5%"
	)
	_fail_unless(laser_n > 0, "Laser-only shops should still have families")
	_fail_unless(
		UpgradeCatalogScript.FAMILY_TESLA
		in UpgradeCatalogScript.eligible_shop_families(false, false, true),
		"Tesla-only shops should roll Tesla cards"
	)
	_fail_unless(
		UpgradeCatalogScript.FAMILY_DURATION
		not in UpgradeCatalogScript.eligible_shop_families(false, false, true)
		and UpgradeCatalogScript.FAMILY_PUSHBACK
		not in UpgradeCatalogScript.eligible_shop_families(false, false, true)
		and UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED
		not in UpgradeCatalogScript.eligible_shop_families(false, false, true),
		"Tesla-only shops should not roll Duration, Pushback, or Projectile Speed"
	)
	_fail_unless(
		UpgradeCatalogScript.missing_unlock_id(true, true, true) == &"",
		"All three weapons owned should skip the unlock card"
	)
	var missing := UpgradeCatalogScript.missing_unlock_ids(true, false, false)
	_fail_unless(
		UpgradeCatalogScript.ID_UNLOCK_LASER in missing
		and UpgradeCatalogScript.ID_UNLOCK_TESLA in missing
		and UpgradeCatalogScript.ID_UNLOCK_RIFLE not in missing,
		"Rifle-only should be able to unlock Laser or Tesla"
	)
	var unlock_rng := RandomNumberGenerator.new()
	var saw_laser_unlock := false
	var saw_tesla_unlock := false
	for seed in range(1, 81):
		unlock_rng.seed = seed
		var rolled := UpgradeCatalogScript.missing_unlock_id(true, false, false, unlock_rng)
		if rolled == UpgradeCatalogScript.ID_UNLOCK_LASER:
			saw_laser_unlock = true
		elif rolled == UpgradeCatalogScript.ID_UNLOCK_TESLA:
			saw_tesla_unlock = true
	_fail_unless(
		saw_laser_unlock and saw_tesla_unlock,
		"Rifle-only unlock card should randomly pick Laser or Tesla"
	)
	for tower_index in range(1, 41):
		var all_owned := UpgradeCatalogScript.roll_shop(3, tower_index, 0, true, true, true)
		for id in all_owned:
			_fail_unless(
				not UpgradeCatalogScript.is_weapon_unlock(StringName(id)),
				"Owned all weapons should never roll an unlock"
			)

	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	_fail_unless(not state.has_rifle and not state.has_laser and not state.has_tesla, "No weapons until grant_starter")
	state.grant_starter(UpgradeCatalogScript.FAMILY_LASER)
	_fail_unless(state.has_laser and not state.has_rifle and not state.has_tesla, "Starter Laser should own only Laser")
	_fail_unless(
		state.owned_weapon_ids() == PackedStringArray(["laser"]),
		"HUD order should list the starter first"
	)
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	_seed_offers(
		state,
		20,
		PackedStringArray([encoded, leftover, leftover, leftover, leftover])
	)
	state.pick_offer(20, 0)
	_fail_unless(
		is_equal_approx(state.damage_bonus, 0.0)
		and is_equal_approx(state.attack_speed_reduction, 0.0),
		"Rifle bundle stats should not enter the shared shop totals"
	)
	_fail_unless(
		is_equal_approx(
			state.damage_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE),
			0.04
		)
		and is_equal_approx(
			state.attack_speed_reduction_for(UpgradeCatalogScript.FAMILY_RIFLE),
			0.04
		),
		"Picking rifle_common|damage_common|attack_speed_common should add catalog common stats to the Rifle"
	)
	_fail_unless(
		is_equal_approx(state.damage_bonus_for(UpgradeCatalogScript.FAMILY_LASER), 0.0),
		"Rifle bundle Damage should not buff the Laser"
	)
	_fail_unless(state.extra_projectiles == 0, "That rifle pair should not add projectiles")
	_fail_unless(
		is_equal_approx(state.hud_damage_bonus(), 0.0)
		and is_equal_approx(state.hud_attack_speed_reduction(), 0.0),
		"Weapon stats should not show on the HUD"
	)
	var shop_damage := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	_seed_offers(
		state,
		22,
		PackedStringArray([shop_damage, leftover, leftover, leftover, leftover])
	)
	state.pick_offer(22, 0)
	_fail_unless(
		is_equal_approx(state.damage_bonus, 0.04),
		"Shop Damage should stack on the shared total"
	)
	_fail_unless(
		is_equal_approx(state.hud_damage_bonus(), 0.04),
		"HUD Damage should only count shop cards, not weapon bundles"
	)
	_fail_unless(
		is_equal_approx(
			state.damage_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE),
			0.08
		),
		"Rifle should use shop Damage plus its bundle"
	)
	state.grant_weapon(UpgradeCatalogScript.FAMILY_RIFLE)
	_fail_unless(state.has_rifle and state.has_laser, "Unlocking Rifle should own both")
	_fail_unless(
		state.owned_weapon_ids() == PackedStringArray(["laser", "rifle"]),
		"HUD order should keep starter then the found weapon"
	)
	state.grant_weapon(UpgradeCatalogScript.FAMILY_TESLA)
	_fail_unless(
		state.has_tesla and state.owned_weapon_ids() == PackedStringArray(["laser", "rifle", "tesla"]),
		"HUD order should append Tesla Coil after the other owned weapons"
	)
	_fail_unless(
		is_equal_approx(
			state.damage_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE),
			0.08
		),
		"A later Rifle should keep shared shop Damage"
	)

	var generic_only: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(generic_only)
	generic_only.grant_starter(UpgradeCatalogScript.FAMILY_LASER)
	_seed_offers(
		generic_only,
		30,
		PackedStringArray([shop_damage, leftover, leftover, leftover, leftover])
	)
	generic_only.pick_offer(30, 0)
	generic_only.grant_weapon(UpgradeCatalogScript.FAMILY_RIFLE)
	_fail_unless(
		is_equal_approx(
			generic_only.damage_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE),
			0.04
		),
		"Generic Damage should buff a Rifle found later"
	)
	var laser_bundle := UpgradeCatalogScript.encode_weapon_offer(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_LASER,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DURATION,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var bundle_only: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(bundle_only)
	bundle_only.grant_starter(UpgradeCatalogScript.FAMILY_LASER)
	_seed_offers(
		bundle_only,
		31,
		PackedStringArray([laser_bundle, leftover, leftover, leftover, leftover])
	)
	bundle_only.pick_offer(31, 0)
	bundle_only.grant_weapon(UpgradeCatalogScript.FAMILY_RIFLE)
	_fail_unless(
		is_equal_approx(
			bundle_only.damage_bonus_for(UpgradeCatalogScript.FAMILY_LASER),
			0.04
		),
		"Laser bundle Damage should apply to the Laser"
	)
	_fail_unless(
		is_equal_approx(
			bundle_only.damage_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE),
			0.0
		),
		"Laser bundle Damage should not buff a later Rifle"
	)

	var unlock_state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(unlock_state)
	unlock_state.grant_starter(UpgradeCatalogScript.FAMILY_LASER)
	_seed_offers(
		unlock_state,
		24,
		PackedStringArray([
			String(UpgradeCatalogScript.ID_UNLOCK_RIFLE),
			leftover,
			leftover,
			leftover,
			leftover
		])
	)
	unlock_state.pick_offer(24, 0)
	_fail_unless(unlock_state.has_rifle, "Picking unlock_rifle should grant the Rifle")
	_fail_unless(
		is_equal_approx(unlock_state.damage_bonus, 0.0),
		"Unlocking a weapon should not apply stats"
	)
	_seed_offers(
		unlock_state,
		26,
		PackedStringArray([
			String(UpgradeCatalogScript.ID_UNLOCK_TESLA),
			leftover,
			leftover,
			leftover,
			leftover
		])
	)
	unlock_state.pick_offer(26, 0)
	_fail_unless(
		unlock_state.has_tesla and unlock_state.owned_weapon_ids() == PackedStringArray(["laser", "rifle", "tesla"]),
		"Picking unlock_tesla should grant Tesla Coil"
	)

	var tesla_start: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(tesla_start)
	tesla_start.grant_starter(UpgradeCatalogScript.FAMILY_TESLA)
	_fail_unless(
		tesla_start.has_tesla and not tesla_start.has_rifle and not tesla_start.has_laser,
		"Starter Tesla Coil should own only Tesla"
	)
	_fail_unless(
		tesla_start.owned_weapon_ids() == PackedStringArray(["tesla"]),
		"HUD order should list Tesla Coil first when it is the starter"
	)
	_seed_offers(
		tesla_start,
		25,
		PackedStringArray([
			String(UpgradeCatalogScript.ID_UNLOCK_TESLA),
			leftover,
			leftover,
			leftover,
			leftover
		])
	)
	tesla_start.pick_offer(25, 0)
	_fail_unless(
		tesla_start.has_tesla and tesla_start.owned_weapon_ids() == PackedStringArray(["tesla"]),
		"Picking unlock_tesla while already owned should not duplicate Tesla"
	)
	var tesla_bundle := UpgradeCatalogScript.encode_weapon_offer(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_TESLA,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_ATTACK_SPEED,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	_seed_offers(
		tesla_start,
		27,
		PackedStringArray([tesla_bundle, leftover, leftover, leftover, leftover])
	)
	tesla_start.pick_offer(27, 0)
	_fail_unless(
		is_equal_approx(
			tesla_start.damage_bonus_for(UpgradeCatalogScript.FAMILY_TESLA),
			0.04
		)
		and is_equal_approx(
			tesla_start.attack_speed_reduction_for(UpgradeCatalogScript.FAMILY_TESLA),
			0.04
		),
		"Tesla Coil bundle stats should apply to Tesla"
	)
	_fail_unless(
		is_equal_approx(tesla_start.damage_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE), 0.0)
		and is_equal_approx(tesla_start.damage_bonus, 0.0),
		"Tesla Coil bundle stats should not enter the shared shop totals"
	)

	var leftover_laser := UpgradeCatalogScript.encode_weapon_offer(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_LASER,
			UpgradeCatalogScript.RARITY_EPIC
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_CRIT,
			UpgradeCatalogScript.RARITY_EPIC
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DURATION,
			UpgradeCatalogScript.RARITY_EPIC
		)
	)
	var leftover_damage := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE,
			UpgradeCatalogScript.RARITY_RARE
		)
	)
	var leftover_luck := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_LUCK,
			UpgradeCatalogScript.RARITY_COMMON
		)
	)
	_seed_offers(
		state,
		21,
		PackedStringArray([encoded, leftover, leftover_damage, leftover_laser, leftover_luck])
	)
	state.pick_offer(21, 0)
	state.pick_offer(21, 1)
	_fail_unless(
		UpgradeCatalogScript.is_empty_offer(StringName(state.get_offers(21)[0])),
		"Taken weapon slot should be Empty until Try Again"
	)
	_fail_unless(
		UpgradeCatalogScript.is_empty_offer(StringName(state.get_offers(21)[1])),
		"Taken normal slot should be Empty"
	)
	state.reset_run()
	_fail_unless(not state.has_rifle and not state.has_laser and not state.has_tesla, "Try Again should clear weapons")
	var after := state.get_offers(21)
	_fail_unless(
		UpgradeCatalogScript.is_empty_offer(StringName(after[0])),
		"Taken weapon-bundle slots should not refill after weapons are cleared"
	)
	_fail_unless(
		UpgradeCatalogScript.is_empty_offer(StringName(after[1])),
		"A normal Empty slot should stay Empty after Try Again"
	)
	_fail_unless(after[2] == leftover_damage, "Untaken cards should stay in the shop")
	_fail_unless(after[3] == leftover_laser, "Untaken weapon cards should stay")
	_fail_unless(after[4] == leftover_luck, "Untaken luck cards should stay")
	_fail_unless(state.remaining_count(21) == 3, "Three leftover cards should remain")
	_fail_unless(
		is_equal_approx(state.damage_bonus, 0.0)
		and is_equal_approx(state.attack_speed_reduction, 0.0)
		and is_equal_approx(state.damage_bonus_for(UpgradeCatalogScript.FAMILY_RIFLE), 0.0),
		"Try Again should still zero stacked weapon stats"
	)
	state.free()
	generic_only.free()
	bundle_only.free()
	unlock_state.free()


func _verify_dawn_pose() -> void:
	var tower_pos := Vector3(-1000.0, 12.0, 8.0)
	var xz: Vector2 = PlayerRigScript.in_front_xz(tower_pos)
	_fail_unless(
		is_equal_approx(xz.x, tower_pos.x - PlayerRigScript.SPAWN_WEST_OFFSET_M),
		"Wait until dawn should spawn west of the tower, not behind it"
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


func _verify_weapon_hud_levels() -> void:
	_fail_unless(
		UpgradeCatalogScript.rarity_for_weapon_level(1) == UpgradeCatalogScript.RARITY_COMMON
		and UpgradeCatalogScript.rarity_for_weapon_level(2) == UpgradeCatalogScript.RARITY_UNCOMMON
		and UpgradeCatalogScript.rarity_for_weapon_level(3) == UpgradeCatalogScript.RARITY_RARE
		and UpgradeCatalogScript.rarity_for_weapon_level(4) == UpgradeCatalogScript.RARITY_EPIC
		and UpgradeCatalogScript.rarity_for_weapon_level(5) == UpgradeCatalogScript.RARITY_LEGENDARY
		and UpgradeCatalogScript.rarity_for_weapon_level(9) == UpgradeCatalogScript.RARITY_LEGENDARY,
		"Weapon HUD rarity should climb common to legendary then stay"
	)
	var common_rifle := UpgradeCatalogScript.icon_for(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RIFLE, UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var uncommon_rifle := UpgradeCatalogScript.icon_for(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RIFLE, UpgradeCatalogScript.RARITY_UNCOMMON
		)
	)
	var legendary_rifle := UpgradeCatalogScript.icon_for(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RIFLE, UpgradeCatalogScript.RARITY_LEGENDARY
		)
	)
	_fail_unless(
		common_rifle != null and uncommon_rifle != null and legendary_rifle != null,
		"Rifle rarity icons should exist"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for_weapon_level(UpgradeCatalogScript.FAMILY_RIFLE, 1)
		== common_rifle,
		"Level 1 Rifle should use the common icon"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for_weapon_level(UpgradeCatalogScript.FAMILY_RIFLE, 2)
		== uncommon_rifle,
		"Level 2 Rifle should use the uncommon icon"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for_weapon_level(UpgradeCatalogScript.FAMILY_RIFLE, 5)
		== legendary_rifle
		and UpgradeCatalogScript.icon_for_weapon_level(UpgradeCatalogScript.FAMILY_RIFLE, 8)
		== legendary_rifle,
		"Level 5+ Rifle should stay on the legendary icon"
	)
	var common_tesla := UpgradeCatalogScript.icon_for(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_TESLA, UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var legendary_tesla := UpgradeCatalogScript.icon_for(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_TESLA, UpgradeCatalogScript.RARITY_LEGENDARY
		)
	)
	_fail_unless(
		common_tesla != null and legendary_tesla != null,
		"Tesla rarity icons should exist"
	)
	_fail_unless(
		UpgradeCatalogScript.icon_for_weapon_level(UpgradeCatalogScript.FAMILY_TESLA, 1)
		== common_tesla
		and UpgradeCatalogScript.icon_for_weapon_level(UpgradeCatalogScript.FAMILY_TESLA, 5)
		== legendary_tesla,
		"Tesla HUD icons should climb common to legendary"
	)

	var root := get_root()
	var leftover := String(UpgradeCatalogScript.ID_EXTRA_PROJECTILE)
	var rifle_card := UpgradeCatalogScript.encode_weapon_offer(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_RIFLE, UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE, UpgradeCatalogScript.RARITY_COMMON
		),
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_ATTACK_SPEED, UpgradeCatalogScript.RARITY_COMMON
		)
	)
	var shop_damage := String(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_DAMAGE, UpgradeCatalogScript.RARITY_COMMON
		)
	)

	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	state.grant_starter(UpgradeCatalogScript.FAMILY_RIFLE)
	_fail_unless(
		state.weapon_level(UpgradeCatalogScript.FAMILY_RIFLE) == 1,
		"A new Rifle should start at Level 1"
	)
	_fail_unless(
		state.weapon_level(UpgradeCatalogScript.FAMILY_LASER) == 0
		and state.weapon_level(UpgradeCatalogScript.FAMILY_TESLA) == 0,
		"An unowned Laser or Tesla should have no level"
	)
	_seed_offers(
		state,
		30,
		PackedStringArray([shop_damage, leftover, leftover, leftover, leftover])
	)
	state.pick_offer(30, 0)
	_fail_unless(
		state.weapon_level(UpgradeCatalogScript.FAMILY_RIFLE) == 1,
		"A shared shop card should not raise the Rifle level"
	)
	_seed_offers(
		state,
		31,
		PackedStringArray([rifle_card, leftover, leftover, leftover, leftover])
	)
	state.pick_offer(31, 0)
	_fail_unless(
		state.weapon_level(UpgradeCatalogScript.FAMILY_RIFLE) == 2,
		"Picking a Rifle upgrade should raise the Rifle to Level 2"
	)
	for tower in range(32, 36):
		_seed_offers(
			state,
			tower,
			PackedStringArray([rifle_card, leftover, leftover, leftover, leftover])
		)
		state.pick_offer(tower, 0)
	_fail_unless(
		state.weapon_level(UpgradeCatalogScript.FAMILY_RIFLE) == 6,
		"Further Rifle upgrades should keep raising the level"
	)
	_fail_unless(
		UpgradeCatalogScript.rarity_for_weapon_level(
			state.weapon_level(UpgradeCatalogScript.FAMILY_RIFLE)
		)
		== UpgradeCatalogScript.RARITY_LEGENDARY,
		"Past Level 5 the Rifle icon should stay legendary"
	)
	state.reset_run()
	_fail_unless(
		state.weapon_level(UpgradeCatalogScript.FAMILY_RIFLE) == 0,
		"Try Again should clear weapon levels"
	)
	state.queue_free()


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
		var base := String(UpgradeCatalogScript.weapon_base_id(StringName(id)))
		if seen.has(base):
			return true
		seen[base] = true
	return false


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
