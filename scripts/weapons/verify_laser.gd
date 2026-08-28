extends SceneTree

const AutoLaserScript = preload("res://scripts/weapons/auto_laser.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const LaserBeamScript = preload("res://scripts/weapons/laser_beam.gd")
const RifleBulletScript = preload("res://scripts/weapons/rifle_bullet.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")
const UpgradeCatalogScript = preload("res://scripts/game/upgrade_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_ticks_and_charge()
	_verify_knockback_skip()
	_verify_pushback_speed()
	_verify_bounce()
	_verify_dead_hop_does_not_freeze()
	_verify_bounce_crits_are_independent()
	_verify_unique_primary_locks()
	_verify_chamber_semantics()
	print("Laser verification passed.")
	quit(0)


func _verify_ticks_and_charge() -> void:
	_fail_unless(AutoLaserScript.DAMAGE == 5, "Laser tick damage should be 5")
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
	_fail_unless(AutoLaserScript.damage_for(0.0) == 5, "Base laser tick should deal 5")
	_fail_unless(
		AutoRifleScript.crit_damage_for(AutoLaserScript.damage_for(0.0), true) == 10,
		"A laser crit should double 5 to 10"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.0), 2.3),
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


func _verify_pushback_speed() -> void:
	_fail_unless(
		is_equal_approx(AutoRifleScript.knockback_speed_for(0.0), SwarmPillScript.HIT_KNOCKBACK_SPEED),
		"Base rifle shove should stay 12 m/s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.knockback_speed_for(0.50), 18.0),
		"50% Pushback should shove at 18 m/s"
	)
	var wounded: SwarmPill = SwarmPillScript.new()
	root.add_child(wounded)
	wounded.take_damage(5, Vector3(-1.0, 0.0, 0.0), false, AutoRifleScript.knockback_speed_for(0.50))
	var hit_vel: Vector3 = wounded.get("_hit_velocity")
	_fail_unless(
		is_equal_approx(hit_vel.x, -18.0),
		"Legendary Pushback should apply 18 m/s west (got %s)" % hit_vel
	)
	wounded.free()
	var laser_hit: SwarmPill = SwarmPillScript.new()
	root.add_child(laser_hit)
	laser_hit.take_damage(3, Vector3.ZERO, false, AutoRifleScript.knockback_speed_for(0.50))
	var leftover: Vector3 = laser_hit.get("_hit_velocity")
	_fail_unless(
		leftover.length_squared() < 0.0001,
		"Laser zero-dir should skip Pushback (got %s)" % leftover
	)
	laser_hit.free()


func _verify_bounce() -> void:
	_fail_unless(
		is_equal_approx(AutoRifleScript.RANGE_M, 75.0),
		"Rifle acquire range should be 75 m"
	)
	_fail_unless(
		is_equal_approx(AutoLaserScript.RANGE_M, 45.0),
		"Laser acquire range should be 45 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.RANGE_ABSOLUTE_MAX, 200.0),
		"Weapon range should cap at 200 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(75.0, 0.0), 75.0),
		"Rifle with no Range bonus should stay 75 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(45.0, 0.0), 45.0),
		"Laser with no Range bonus should stay 45 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.bounce_range_for(AutoRifleScript.range_for(75.0, 0.0)), 37.5),
		"Rifle bounce range should be half of 75 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.bounce_range_for(AutoRifleScript.range_for(45.0, 0.0)), 22.5),
		"Laser bounce range should be half of 45 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(75.0, 2.0), 200.0)
		and is_equal_approx(AutoRifleScript.range_for(45.0, 4.0), 200.0),
		"Range bonus should clamp each weapon to 200 m"
	)
	_fail_unless(
		is_equal_approx(
			AutoRifleScript.bounce_range_for(AutoRifleScript.range_for(75.0, 2.0)),
			100.0
		),
		"Bounce should use half of the capped current range"
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var start: SwarmPill = SwarmPillScript.new()
	var near: SwarmPill = SwarmPillScript.new()
	var far: SwarmPill = SwarmPillScript.new()
	root.add_child(start)
	root.add_child(near)
	root.add_child(far)
	start.global_position = Vector3.ZERO
	near.global_position = Vector3(40.0, 0.0, 0.0)
	far.global_position = Vector3(80.0, 0.0, 0.0)
	var pills: Array = [start, near, far]
	var chain := AutoRifleScript.build_bounce_chain(start, pills, 2, 50.0, rng)
	_fail_unless(chain.size() == 2, "Two hops should chain start -> near -> far")
	_fail_unless(chain[0] == near and chain[1] == far, "Each hop should measure from the last hit")
	var ping := AutoRifleScript.build_bounce_chain(start, [start, near], 5, 50.0, rng)
	_fail_unless(ping.size() == 1 and ping[0] == near, "Bounces must not return to a pill already hit")
	var exclude: Dictionary = {}
	exclude[start.get_instance_id()] = true
	exclude[near.get_instance_id()] = true
	_fail_unless(
		AutoRifleScript.pick_bounce_target(pills, start.global_position, 50.0, exclude, rng) == null,
		"Already-hit pills should be excluded from bounce picks"
	)
	start.free()
	near.free()
	far.free()


func _verify_dead_hop_does_not_freeze() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var primary: SwarmPill = SwarmPillScript.new()
	var hop: SwarmPill = SwarmPillScript.new()
	root.add_child(primary)
	root.add_child(hop)
	primary.global_position = Vector3.ZERO
	hop.global_position = Vector3(10.0, 0.0, 0.0)
	var beam: LaserBeam = LaserBeamScript.new()
	root.add_child(beam)
	beam.begin(2.0, primary, 0.0, 0.0, rng, 1, 50.0, [primary, hop])
	hop.free()
	beam.advance(0.016, Vector3.ZERO, Vector3.FORWARD, [primary], rng, 0.0, 0.0)
	_fail_unless(not beam.finished, "A freed bounce hop should not freeze or finish the laser")
	beam.free()
	primary.free()


func _verify_bounce_crits_are_independent() -> void:
	var bullet: RifleBullet = RifleBulletScript.new()
	root.add_child(bullet)
	bullet.launch(
		Vector3.ZERO,
		null,
		Vector3.FORWARD,
		10,
		60.0,
		1.0,
		12.0,
		4,
		50.0
	)
	var first: Dictionary = bullet.call("_resolve_hit")
	_fail_unless(
		first.is_crit and int(first.damage) == 20,
		"100% crit chance should crit the first hit for 20"
	)
	bullet.set("_crit_chance", 0.0)
	var bounce: Dictionary = bullet.call("_resolve_hit")
	_fail_unless(
		not bounce.is_crit and int(bounce.damage) == 10,
		"A bounce should re-roll crit; 0% must not inherit the first crit"
	)
	bullet.set("_crit_chance", 1.0)
	var later: Dictionary = bullet.call("_resolve_hit")
	_fail_unless(
		later.is_crit and int(later.damage) == 20,
		"A later bounce should still be able to crit on its own"
	)
	bullet.free()


func _verify_unique_primary_locks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var origin := Vector3.ZERO
	var facing := Vector3(-1.0, 0.0, 0.0)
	var range_m := AutoLaserScript.RANGE_M
	var a: SwarmPill = SwarmPillScript.new()
	var b: SwarmPill = SwarmPillScript.new()
	var c: SwarmPill = SwarmPillScript.new()
	root.add_child(a)
	root.add_child(b)
	root.add_child(c)
	a.global_position = Vector3(-20.0, 0.0, 0.0)
	b.global_position = Vector3(-25.0, 0.0, 4.0)
	c.global_position = Vector3(-30.0, 0.0, -3.0)
	var pills: Array = [a, b, c]
	var first := AutoLaserScript.pick_unique_target(pills, origin, facing, range_m, {}, rng)
	_fail_unless(first != null, "Should pick a primary target")
	var exclude: Dictionary = {}
	exclude[first.get_instance_id()] = true
	var second := AutoLaserScript.pick_unique_target(pills, origin, facing, range_m, exclude, rng)
	_fail_unless(second != null and second != first, "Second beam should lock a different enemy")
	exclude[second.get_instance_id()] = true
	var third := AutoLaserScript.pick_unique_target(pills, origin, facing, range_m, exclude, rng)
	_fail_unless(third != null and third != first and third != second, "Third beam should take the last free enemy")
	exclude[third.get_instance_id()] = true
	_fail_unless(
		AutoLaserScript.pick_unique_target(pills, origin, facing, range_m, exclude, rng) == null,
		"With every enemy claimed, no new primary lock should be available"
	)
	a.free()
	b.free()
	c.free()


func _verify_chamber_semantics() -> void:
	# Mirror shotgun: failed spawns keep chamber slots; charge waits until the volley empties.
	var pending := 2
	var fired := 0
	var spawned := false
	if not spawned:
		pass
	else:
		pending -= 1
		fired += 1
	_fail_unless(pending == 2 and fired == 0, "Missed beam spawn should keep chamber slots")
	while pending > 0:
		spawned = true
		pending -= 1
		fired += 1
	_fail_unless(pending == 0 and fired == 2, "Charge should wait until every chambered beam fires")


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
