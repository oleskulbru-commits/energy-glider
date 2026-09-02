extends SceneTree

const RunUpgradeStateScript = preload("res://scripts/game/run_upgrade_state.gd")
const UpgradeCatalogScript = preload("res://scripts/game/upgrade_catalog.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_percent_clamps()
	_verify_apply_loadout()
	_verify_weapon_cap()
	if _failed:
		return
	print("God mode menu verification passed.")
	quit(0)


func _verify_percent_clamps() -> void:
	_fail_unless(
		UpgradeCatalogScript.clamp_god_mode_percent(UpgradeCatalogScript.FAMILY_GLIDE, 80) == 50,
		"Glide percent should clamp to 50"
	)
	_fail_unless(
		UpgradeCatalogScript.clamp_god_mode_percent(UpgradeCatalogScript.FAMILY_CRIT, 150) == 100,
		"Crit percent should clamp to 100"
	)
	_fail_unless(
		UpgradeCatalogScript.clamp_god_mode_percent(
			UpgradeCatalogScript.FAMILY_ATTACK_SPEED, 95
		) == 80,
		"Attack speed percent should clamp to 80"
	)
	_fail_unless(
		UpgradeCatalogScript.clamp_god_mode_percent(
			UpgradeCatalogScript.FAMILY_PROJECTILE_SPEED, 120
		) == 80,
		"Projectile speed percent should clamp to 80"
	)
	_fail_unless(
		is_equal_approx(
			UpgradeCatalogScript.god_mode_percent_to_fraction(
				UpgradeCatalogScript.FAMILY_ATTACK_SPEED, 15
			),
			0.15
		),
		"Attack speed percent should convert to 0.15 fraction"
	)


func _verify_apply_loadout() -> void:
	var state := RunUpgradeStateScript.new()
	root.add_child(state)
	var weapons := PackedStringArray(["rifle", "laser", "rocket"])
	var stats := {
		UpgradeCatalogScript.FAMILY_PROJECTILE: 4,
		UpgradeCatalogScript.FAMILY_ATTACK_SPEED: 15,
	}
	state.apply_god_mode_loadout(weapons, stats)
	_fail_unless(state.owned_weapon_count() == 3, "God mode should grant three weapons")
	_fail_unless(state.extra_projectiles == 4, "God mode should set four extra projectiles")
	_fail_unless(
		is_equal_approx(state.attack_speed_reduction, 0.15),
		"God mode should set attack speed reduction from percent input"
	)
	state.queue_free()


func _verify_weapon_cap() -> void:
	var state := RunUpgradeStateScript.new()
	root.add_child(state)
	var weapons := PackedStringArray([
		"rifle", "laser", "tesla", "rocket", "shotgun"
	])
	state.apply_god_mode_loadout(weapons, {})
	_fail_unless(
		state.owned_weapon_count() == UpgradeCatalogScript.MAX_OWNED_WEAPONS,
		"God mode should cap granted weapons at four"
	)
	state.queue_free()


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
