extends SceneTree

const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const AutoShotgunScript = preload("res://scripts/weapons/auto_shotgun.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_stats()
	if _failed:
		return
	_verify_cone()
	if _failed:
		return
	print("Shotgun verification passed.")
	quit(0)


func _verify_stats() -> void:
	_fail_unless(AutoShotgunScript.DAMAGE == 17, "Shotgun damage should be 17")
	_fail_unless(is_equal_approx(AutoShotgunScript.RANGE_M, 15.0), "Shotgun acquire range should be 15 m")
	_fail_unless(is_equal_approx(AutoShotgunScript.FIRE_INTERVAL_SEC, 2.5), "Shotgun interval should be 2.5 s")
	_fail_unless(is_equal_approx(AutoShotgunScript.BURST_GAP_SEC, 0.5), "Extra shotgun volley should wait 0.5 s")
	_fail_unless(
		is_equal_approx(AutoShotgunScript.burst_gap_for(0.0), 0.5),
		"Shotgun with no Attack Speed should wait 0.5 s between volleys"
	)
	_fail_unless(
		is_equal_approx(AutoShotgunScript.burst_gap_for(0.13), 0.5 * (1.0 - 0.13 * 0.20)),
		"Attack Speed should apply 20% of its percent to volley gap"
	)
	_fail_unless(
		is_equal_approx(AutoShotgunScript.burst_gap_for(0.80), 0.5 * (1.0 - 0.80 * 0.20)),
		"80% Attack Speed should wait 0.5 × 0.84 between volleys"
	)
	_fail_unless(
		AutoShotgunScript.burst_gap_for(20.0) >= AutoShotgunScript.BURST_GAP_MIN_SEC - 0.0001,
		"Volley gap should not drop below 0.2 s"
	)
	_fail_unless(is_equal_approx(AutoShotgunScript.KNOCKBACK_SPEED, 28.0), "Shotgun base knockback should be 28")
	_fail_unless(is_equal_approx(AutoShotgunScript.CONE_HALF_DEG, 22.0), "Shotgun cone half-angle should be 22 deg")
	_fail_unless(AutoShotgunScript.PELLET_COUNT == 16, "Shotgun should spray 16 visual pellets")
	_fail_unless(is_equal_approx(AutoShotgunScript.PELLET_TRAVEL_M, 32.0), "Pellets should fly 32 m before vanishing")
	_fail_unless(AutoShotgunScript.damage_for(0.0) == 17, "Base shotgun should deal 17")
	_fail_unless(
		AutoShotgunScript.damage_for(0.04) == 18,
		"4% Damage should round 17.68 to 18"
	)
	_fail_unless(
		is_equal_approx(AutoShotgunScript.fire_interval_for(0.0), 2.5),
		"Base shotgun wait should stay 2.5 s"
	)
	_fail_unless(
		is_equal_approx(AutoShotgunScript.fire_interval_for(0.13), 2.5 * 0.87),
		"4% + 9% Attack Speed should wait 2.5 × 0.87"
	)
	_fail_unless(
		is_equal_approx(AutoShotgunScript.fire_interval_for(0.80), 0.50),
		"80% CDR should wait 0.50 s"
	)
	_fail_unless(
		is_equal_approx(AutoShotgunScript.fire_interval_for(0.95), 0.50),
		"Over-cap CDR should still wait 0.50 s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(AutoShotgunScript.RANGE_M, 0.0), 15.0),
		"Shotgun with no Range bonus should stay 15 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(AutoShotgunScript.RANGE_M, 20.0), 200.0),
		"Shotgun Range bonus should clamp to 200 m"
	)
	_fail_unless(
		is_equal_approx(AutoShotgunScript.knockback_speed_for(0.0), 28.0),
		"Shotgun knockback with no Pushback should stay 28"
	)
	_fail_unless(
		is_equal_approx(AutoShotgunScript.knockback_speed_for(0.25), 35.0),
		"25% Pushback should knock back at 35"
	)
	_fail_unless(
		AutoRifleScript.crit_damage_for(AutoShotgunScript.damage_for(0.0), true) == 34,
		"Shotgun crit should double 17 to 34"
	)
	_fail_unless(
		AutoRifleScript.projectile_count_for(1) == 2,
		"One Extra Projectile should queue a second volley"
	)


func _verify_cone() -> void:
	var origin := Vector3.ZERO
	var aim := Vector3(-1.0, 0.0, 0.0)
	var range_m := AutoShotgunScript.RANGE_M
	var half := deg_to_rad(AutoShotgunScript.CONE_HALF_DEG)
	var ahead := _marker_at(Vector3(-10.0, 0.0, 0.0))
	var in_fringe := _marker_at(Vector3(-10.0, 0.0, 3.5))
	var out_fringe := _marker_at(Vector3(-10.0, 0.0, 6.0))
	var behind := _marker_at(Vector3(8.0, 0.0, 0.0))
	var too_far := _marker_at(Vector3(-20.0, 0.0, 0.0))
	var hit := AutoShotgunScript.pills_in_cone(
		origin, aim, range_m, half, [ahead, in_fringe, out_fringe, behind, too_far]
	)
	_fail_unless(ahead in hit, "A pill dead ahead inside range should take the blast")
	_fail_unless(in_fringe in hit, "A pill inside the cone lip should take the blast")
	_fail_unless(out_fringe not in hit, "A pill outside the cone should miss")
	_fail_unless(behind not in hit, "A pill behind the glider should miss")
	_fail_unless(too_far not in hit, "A pill past 15 m should miss")
	ahead.free()
	in_fringe.free()
	out_fringe.free()
	behind.free()
	too_far.free()


func _marker_at(pos: Vector3) -> Node3D:
	var marker := Node3D.new()
	root.add_child(marker)
	marker.global_position = pos
	return marker


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
	quit(1)
