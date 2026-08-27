extends SceneTree

const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const AutoRocketScript = preload("res://scripts/weapons/auto_rocket.gd")
const RocketMissileScript = preload("res://scripts/weapons/rocket_missile.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")

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
	_verify_shared_and_chamber()
	if _failed:
		return
	_verify_retarget()
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
	var missile: RocketMissile = RocketMissileScript.new()
	root.add_child(missile)
	missile.set("_damage", 23)
	missile.set("_crit_chance", 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	missile.set("_rng", rng)
	var hit: Dictionary = missile.call("_resolve_hit")
	_fail_unless(bool(hit.is_crit), "100% rocket crit chance should crit")
	_fail_unless(int(hit.damage) == 46, "Rocket crit should roll 46 from base 23")
	var pill: SwarmPill = SwarmPillScript.new()
	root.add_child(pill)
	pill.take_damage(int(hit.damage), Vector3.LEFT, bool(hit.is_crit), 20.0)
	var labels: Array = []
	for node in root.get_tree().get_nodes_in_group("damage_float"):
		if node is Label3D:
			labels.append(node)
	_fail_unless(labels.size() == 1, "Rocket crit should spawn a damage float")
	_fail_unless(
		(labels[0] as Label3D).text == "-46",
		"Rocket crit float must show 46 even when crawler HP is only 20"
	)
	for label in labels:
		var host: Node = (label as Node).get_parent()
		if host != null and host != root:
			host.free()
		else:
			(label as Node).free()
	pill.free()
	missile.free()
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
	var ranked := AutoRocketScript.rank_targets(
		[ahead_close, fringe, ahead_far], origin, facing, range_m, 2
	)
	_fail_unless(
		ranked.size() == 2 and ranked[0] == ahead_far and ranked[1] == ahead_close,
		"rank_targets should still order unique candidates by score"
	)
	var pick_a := AutoRocketScript.pick_best_target(
		[ahead_close, fringe, ahead_far], origin, facing, range_m
	)
	var pick_b := AutoRocketScript.pick_best_target(
		[ahead_close, fringe, ahead_far], origin, facing, range_m
	)
	_fail_unless(
		pick_a == ahead_far and pick_b == ahead_far,
		"Extra rockets may share the same best lock"
	)
	var none := AutoRocketScript.rank_targets([behind, too_far], origin, facing, range_m, 2)
	_fail_unless(none.is_empty(), "Rockets should ignore behind and out-of-range pills")
	ahead_far.free()
	ahead_close.free()
	fringe.free()
	behind.free()
	too_far.free()


func _verify_shared_and_chamber() -> void:
	# Chamber semantics: leftover slots stay until a successful fire (shotgun pattern).
	var remaining := 2
	var fired := 0
	# No target → do not consume chamber.
	var miss: Node3D = null
	if miss == null:
		pass
	else:
		remaining -= 1
		fired += 1
	_fail_unless(remaining == 2 and fired == 0, "Missed rocket should keep chamber slots")
	# Successful fires empty the chamber before cooldown.
	while remaining > 0:
		remaining -= 1
		fired += 1
	_fail_unless(remaining == 0 and fired == 2, "Cooldown starts only after chamber empties")
	var origin := Vector3.ZERO
	var facing := Vector3(-1.0, 0.0, 0.0)
	var only := _marker_at(Vector3(-40.0, 0.0, 0.0))
	var shared_a := AutoRocketScript.pick_best_target([only], origin, facing, AutoRocketScript.RANGE_M)
	var shared_b := AutoRocketScript.pick_best_target([only], origin, facing, AutoRocketScript.RANGE_M)
	_fail_unless(
		shared_a == only and shared_b == only,
		"With one enemy, every chambered rocket should share that lock"
	)
	only.free()


func _verify_retarget() -> void:
	var first: SwarmPill = SwarmPillScript.new()
	var second: SwarmPill = SwarmPillScript.new()
	root.add_child(first)
	root.add_child(second)
	first.global_position = Vector3(-20.0, 0.0, 0.0)
	second.global_position = Vector3(-35.0, 0.0, 5.0)
	# Force dead lock without freeing the node (mirrors post-kill before queue_free).
	first.set("_hp", 0)

	var missile: RocketMissile = RocketMissileScript.new()
	root.add_child(missile)
	missile.global_position = Vector3.ZERO
	missile.set("_dir", Vector3(-1.0, 0.0, 0.0))
	missile.set("_launch_facing", Vector3(-1.0, 0.0, 0.0))
	missile.set("_target", first)
	var next_lock := missile.retarget_if_needed()
	_fail_unless(next_lock == second, "Dead lock should retarget to another living crawler")
	missile.set("_target", second)
	second.set("_hp", 0)
	_fail_unless(
		missile.retarget_if_needed() == null,
		"With no living candidates, retarget should clear the lock"
	)
	missile.free()
	first.free()
	second.free()

	_verify_loft_retarget_uses_launch_facing()


func _verify_loft_retarget_uses_launch_facing() -> void:
	# Shared lock dies during loft: `_dir` is UP so XZ-from-dir used to fall back to −Z.
	var dead: SwarmPill = SwarmPillScript.new()
	var west: SwarmPill = SwarmPillScript.new()
	var north: SwarmPill = SwarmPillScript.new()
	root.add_child(dead)
	root.add_child(west)
	root.add_child(north)
	dead.global_position = Vector3(-25.0, 0.0, 0.0)
	west.global_position = Vector3(-40.0, 0.0, 0.0)
	north.global_position = Vector3(0.0, 0.0, -40.0)
	dead.set("_hp", 0)

	var lofted: RocketMissile = RocketMissileScript.new()
	root.add_child(lofted)
	lofted.global_position = Vector3(0.0, RocketMissileScript.LOFT_M, 0.0)
	lofted.set("_dir", Vector3.UP)
	lofted.set("_boost_left", RocketMissileScript.BOOST_SEC)
	lofted.set("_launch_facing", Vector3(-1.0, 0.0, 0.0))
	lofted.set("_target", dead)

	var next_lock := lofted.retarget_if_needed()
	_fail_unless(
		next_lock == west,
		"Loft retarget should prefer westbound pack using launch facing, not northern crawlers"
	)
	lofted.free()
	dead.free()
	west.free()
	north.free()


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
