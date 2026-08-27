extends SceneTree

const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const AutoRocketScript = preload("res://scripts/weapons/auto_rocket.gd")
const RocketMissileScript = preload("res://scripts/weapons/rocket_missile.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_stats()
	if _failed:
		return
	_verify_aim()
	if _failed:
		return
	print("Rocket verification passed.")
	quit(0)


func _verify_stats() -> void:
	_fail_unless(AutoRocketScript.DAMAGE == 20, "Rocket damage should be 20")
	_fail_unless(is_equal_approx(AutoRocketScript.RANGE_M, 75.0), "Rocket acquire range should be 75 m")
	_fail_unless(is_equal_approx(AutoRocketScript.FIRE_INTERVAL_SEC, 4.0), "Rocket interval should be 4 s")
	_fail_unless(is_equal_approx(AutoRocketScript.BURST_GAP_SEC, 0.12), "Rocket burst gap should be 0.12 s")
	_fail_unless(is_equal_approx(AutoRocketScript.KNOCKBACK_SPEED, 20.0), "Rocket base knockback should be 20")
	_fail_unless(is_equal_approx(RocketMissileScript.SPEED_MPS, 35.0), "Rocket cruise should be 35 m/s")
	_fail_unless(
		is_equal_approx(RocketMissileScript.SPEED_MPS * RocketMissileScript.BOOST_SEC, 6.0),
		"Rocket loft should stay 6 m"
	)
	_fail_unless(AutoRocketScript.damage_for(0.0) == 20, "Base rocket should deal 20")
	_fail_unless(
		AutoRocketScript.damage_for(0.04) == 21,
		"4% Damage should round 20.8 to 21"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.fire_interval_for(0.0), 4.0),
		"Base rocket wait should stay 4 s"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.fire_interval_for(0.13), 4.0 * 0.87),
		"4% + 9% Attack Speed should wait 4.0 × 0.87"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.fire_interval_for(0.80), 0.80),
		"80% CDR should wait 0.80 s"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.fire_interval_for(0.95), 0.80),
		"Over-cap CDR should still wait 0.80 s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(AutoRocketScript.RANGE_M, 0.0), 75.0),
		"Rocket with no Range bonus should stay 75 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(AutoRocketScript.RANGE_M, 10.0), 200.0),
		"Rocket Range bonus should clamp to 200 m"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.speed_for(0.0), 35.0),
		"Rocket with no Projectile Speed should stay 35 m/s"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.speed_for(0.15), 35.0 * 1.15),
		"15% Projectile Speed should cruise at 35 × 1.15"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.speed_for(0.95), 35.0 * 1.80),
		"Over-cap Projectile Speed should still cap at 80%"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.knockback_speed_for(0.0), 20.0),
		"Rocket knockback with no Pushback should stay 20"
	)
	_fail_unless(
		is_equal_approx(AutoRocketScript.knockback_speed_for(0.25), 25.0),
		"25% Pushback should knock back at 25"
	)
	_fail_unless(
		AutoRifleScript.crit_damage_for(AutoRocketScript.damage_for(0.0), true) == 40,
		"Rocket crit should double 20 to 40"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.burst_fire_times(3)[1], AutoRocketScript.BURST_GAP_SEC),
		"Second rocket in a burst should wait 0.12 s"
	)


func _verify_aim() -> void:
	var origin := Vector3.ZERO
	var facing := Vector3(-1.0, 0.0, 0.0)
	var range_m := AutoRocketScript.RANGE_M
	var ahead_far := _marker_at(Vector3(-60.0, 0.0, 0.0))
	var ahead_close := _marker_at(Vector3(-10.0, 0.0, 0.0))
	var fringe := _marker_at(Vector3(-8.0, 0.0, 40.0))
	var behind := _marker_at(Vector3(12.0, 0.0, 0.0))
	var too_far := _marker_at(Vector3(-90.0, 0.0, 0.0))
	var best := AutoRocketScript.rank_targets(
		[ahead_close, fringe, ahead_far, behind, too_far], origin, facing, range_m, 1
	)
	_fail_unless(
		best.size() == 1 and best[0] == ahead_far,
		"Rocket should lock the far-ahead pill first"
	)
	_fail_unless(
		AutoRocketScript.aim_score(origin, facing, ahead_far.global_position, range_m)
		> AutoRocketScript.aim_score(origin, facing, ahead_close.global_position, range_m),
		"A far-ahead pill should outscore a close-ahead pill"
	)
	_fail_unless(
		AutoRocketScript.aim_score(origin, facing, ahead_close.global_position, range_m)
		> AutoRocketScript.aim_score(origin, facing, fringe.global_position, range_m),
		"A close-ahead pill should outscore a fringe pill"
	)
	var two := AutoRocketScript.rank_targets(
		[ahead_close, fringe, ahead_far], origin, facing, range_m, 2
	)
	_fail_unless(
		two.size() == 2 and two[0] == ahead_far and two[1] == ahead_close,
		"Extra rockets should take unique targets in score order"
	)
	var leftovers := AutoRocketScript.rank_targets([ahead_far], origin, facing, range_m, 4)
	_fail_unless(
		leftovers.size() == 1 and leftovers[0] == ahead_far,
		"Leftover extra rockets should fizzle if targets run out"
	)
	var none := AutoRocketScript.rank_targets([behind, too_far], origin, facing, range_m, 2)
	_fail_unless(none.is_empty(), "Rockets should ignore behind and out-of-range pills")
	ahead_far.free()
	ahead_close.free()
	fringe.free()
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
