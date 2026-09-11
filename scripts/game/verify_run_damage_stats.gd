extends SceneTree

const RunDamageStatsScript = preload("res://scripts/game/run_damage_stats.gd")
const RunUpgradeStateScript = preload("res://scripts/game/run_upgrade_state.gd")
const UpgradeCatalogScript = preload("res://scripts/game/upgrade_catalog.gd")
const SwarmPillScene = preload("res://scenes/enemies/swarm_pill.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_overkill_records_actual_damage()
	_verify_weapon_kills()
	_verify_ranking_and_reset()
	_verify_upgrade_summary_bundles_projectiles()
	if _failed:
		quit(1)
		return
	print("Run damage stats verification passed.")
	quit(0)


func _verify_overkill_records_actual_damage() -> void:
	var stats := RunDamageStatsScript.new()
	root.add_child(stats)
	var pill: SwarmPill = SwarmPillScene.instantiate() as SwarmPill
	root.add_child(pill)
	pill.take_damage(19)
	pill.take_damage(10, Vector3.ZERO, false, SwarmPill.HIT_KNOCKBACK_SPEED, UpgradeCatalogScript.FAMILY_RIFLE)
	_fail_unless(
		stats.damage_for(UpgradeCatalogScript.FAMILY_RIFLE) == 1,
		"Overkill should only record remaining HP as damage dealt"
	)
	_fail_unless(
		stats.kills_for(UpgradeCatalogScript.FAMILY_RIFLE) == 1,
		"Lethal tagged overkill should credit one rifle kill"
	)
	pill.queue_free()
	stats.queue_free()


func _verify_weapon_kills() -> void:
	var stats := RunDamageStatsScript.new()
	root.add_child(stats)
	var wounded: SwarmPill = SwarmPillScene.instantiate() as SwarmPill
	root.add_child(wounded)
	wounded.take_damage(10, Vector3.ZERO, false, SwarmPill.HIT_KNOCKBACK_SPEED, UpgradeCatalogScript.FAMILY_RIFLE)
	_fail_unless(
		stats.kills_for(UpgradeCatalogScript.FAMILY_RIFLE) == 0,
		"Non-lethal tagged hit should not increment kills"
	)
	wounded.queue_free()

	var untagged: SwarmPill = SwarmPillScene.instantiate() as SwarmPill
	root.add_child(untagged)
	untagged.take_damage(20)
	_fail_unless(
		stats.kills_for(UpgradeCatalogScript.FAMILY_RIFLE) == 0,
		"Untagged lethal hit should not credit a weapon kill"
	)
	untagged.queue_free()

	var tagged: SwarmPill = SwarmPillScene.instantiate() as SwarmPill
	root.add_child(tagged)
	tagged.take_damage(20, Vector3.ZERO, false, SwarmPill.HIT_KNOCKBACK_SPEED, UpgradeCatalogScript.FAMILY_LASER)
	_fail_unless(
		stats.kills_for(UpgradeCatalogScript.FAMILY_LASER) == 1,
		"Lethal tagged hit should credit one kill"
	)
	stats.reset()
	_fail_unless(
		stats.kills_for(UpgradeCatalogScript.FAMILY_LASER) == 0,
		"Reset should clear weapon kills"
	)
	tagged.queue_free()
	stats.queue_free()


func _verify_ranking_and_reset() -> void:
	var stats := RunDamageStatsScript.new()
	root.add_child(stats)
	stats.record(UpgradeCatalogScript.FAMILY_RIFLE, 50)
	stats.record(UpgradeCatalogScript.FAMILY_LASER, 30)
	stats.record(UpgradeCatalogScript.FAMILY_ROCKET, 80)
	var owned := PackedStringArray(["rifle", "laser", "rocket"])
	var ranked := stats.ranked_weapons(owned)
	_fail_unless(ranked[0] == "rocket", "Highest damage weapon should rank first")
	_fail_unless(ranked[1] == "rifle", "Second highest weapon should rank second")
	stats.reset()
	_fail_unless(stats.damage_for(UpgradeCatalogScript.FAMILY_RIFLE) == 0, "Reset should clear rifle damage")
	stats.queue_free()


func _verify_upgrade_summary_bundles_projectiles() -> void:
	var state := RunUpgradeStateScript.new()
	root.add_child(state)
	state.grant_weapon(UpgradeCatalogScript.FAMILY_RIFLE)
	state._apply_upgrade(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PROJECTILE,
			UpgradeCatalogScript.RARITY_UNCOMMON
		)
	)
	state._apply_upgrade(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PROJECTILE,
			UpgradeCatalogScript.RARITY_UNCOMMON
		)
	)
	var entries := state.death_upgrade_summary()
	var found := false
	for entry in entries:
		if entry.get("family") == UpgradeCatalogScript.FAMILY_PROJECTILE:
			_fail_unless(entry.get("label") == "+4 projectiles", "Two +2 projectile picks should bundle to +4")
			found = true
	_fail_unless(found, "Projectile upgrade should appear in death summary")
	state.queue_free()


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
