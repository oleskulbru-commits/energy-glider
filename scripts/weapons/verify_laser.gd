extends SceneTree

const AutoLaserScript = preload("res://scripts/weapons/auto_laser.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")
const UpgradeCatalogScript = preload("res://scripts/game/upgrade_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_ticks_and_charge()
	_verify_knockback_skip()
	print("Laser verification passed.")
	quit(0)


func _verify_ticks_and_charge() -> void:
	_fail_unless(AutoLaserScript.DAMAGE == 3, "Laser tick damage should be 3")
	_fail_unless(is_equal_approx(AutoLaserScript.FIRE_SEC, 2.0), "Laser fire time should be 2 s")
	_fail_unless(is_equal_approx(AutoLaserScript.CHARGE_SEC, 2.0), "Laser charge should be 2 s")
	_fail_unless(is_equal_approx(AutoLaserScript.CHARGE_FLOOR, 0.5), "Laser charge floor should be 0.5 s")
	_fail_unless(is_equal_approx(AutoLaserScript.TICK_SEC, 0.5), "Laser tick interval should be 0.5 s")
	_fail_unless(
		is_equal_approx(AutoLaserScript.fire_time_for(0.0), 2.0),
		"Base laser fire time should stay 2 s"
	)
	_fail_unless(
		is_equal_approx(AutoLaserScript.fire_time_for(0.25), 2.5),
		"Rare Duration should fire for 2.50 s"
	)
	_fail_unless(
		is_equal_approx(AutoLaserScript.fire_time_for(0.50), 3.0),
		"Legendary Duration should fire for 3.00 s"
	)
	_fail_unless(
		AutoLaserScript.tick_count_for(AutoLaserScript.fire_time_for(0.0)) == 4,
		"Base laser should tick 4 times"
	)
	_fail_unless(
		AutoLaserScript.tick_count_for(AutoLaserScript.fire_time_for(0.25)) == 5,
		"25% Duration should tick 5 times"
	)
	_fail_unless(
		AutoLaserScript.tick_count_for(AutoLaserScript.fire_time_for(0.50)) == 6,
		"50% Duration should tick 6 times"
	)
	_fail_unless(
		is_equal_approx(AutoLaserScript.charge_for(0.0), 2.0),
		"Base laser charge should stay 2 s"
	)
	_fail_unless(
		is_equal_approx(AutoLaserScript.charge_for(0.80), 0.5),
		"80% Attack Speed should floor laser charge at 0.5 s"
	)
	_fail_unless(
		is_equal_approx(AutoLaserScript.charge_for(0.95), 0.5),
		"Over-cap Attack Speed should still floor laser charge at 0.5 s"
	)
	_fail_unless(AutoLaserScript.damage_for(0.0) == 3, "Base laser tick should deal 3")
	_fail_unless(
		AutoRifleScript.crit_damage_for(AutoLaserScript.damage_for(0.0), true) == 6,
		"A laser crit should double 3 to 6"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.0), 3.0),
		"Rifle interval should ignore Duration"
	)
	_fail_unless(
		is_equal_approx(
			UpgradeCatalogScript.duration_percent(UpgradeCatalogScript.RARITY_RARE),
			0.25
		),
		"Rare Duration should be 25%"
	)


func _verify_knockback_skip() -> void:
	var west: Vector3 = SwarmPillScript.hit_knockback_velocity_for(Vector3.ZERO)
	_fail_unless(west.x < 0.0, "Zero-dir helper still maps to west; take_damage must skip it")
	var wounded: SwarmPill = SwarmPillScript.new()
	root.add_child(wounded)
	wounded.take_damage(5, Vector3.ZERO)
	var leftover: Vector3 = wounded.get("_hit_velocity")
	_fail_unless(
		leftover.length_squared() < 0.0001,
		"Zero-dir hits should skip knockback (got %s)" % leftover
	)
	wounded.free()


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
