extends SceneTree

const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")
const SwarmPillScene = preload("res://scenes/enemies/swarm_pill.tscn")
const ChargerPillScript = preload("res://scripts/enemies/charger_pill.gd")
const ChargerPillScene = preload("res://scenes/enemies/charger_pill.tscn")
const LeaperPillScript = preload("res://scripts/enemies/leaper_pill.gd")
const LeaperPillScene = preload("res://scenes/enemies/leaper_pill.tscn")
const EnemyStreamSpawnerScript = preload("res://scripts/enemies/enemy_stream_spawner.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const DamageFloatScript = preload("res://scripts/ui/damage_float.gd")
const CombatDroneScript = preload("res://scripts/enemies/combat_drone.gd")
const LaserDroneScript = preload("res://scripts/enemies/laser_drone.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_cap_curve()
	_verify_spawn_offset()
	_verify_knockback()
	_verify_spawn_grace()
	_verify_charger()
	_verify_leaper()
	_verify_pill_health()
	_verify_level_hp_curve()
	_verify_damage_floats()
	_verify_hit_knockback()
	_verify_crawler_death()
	_verify_rifle_targeting()
	_verify_rifle_burst()
	_verify_spawn_after_try_again()
	print("Enemy stream verification passed.")
	quit(0)


func _verify_cap_curve() -> void:
	var prev := -1
	for level in range(1, 41):
		var cap := SwarmPillScript.active_cap_for_level(level)
		_fail_unless(cap >= 15 and cap <= 108, "Cap out of range at level %d: %d" % [level, cap])
		_fail_unless(cap >= prev, "Cap should be non-decreasing (%d -> %d at level %d)" % [prev, cap, level])
		prev = cap
	_fail_unless(SwarmPillScript.active_cap_for_level(1) == 15, "Level 1 cap should be 15")
	_fail_unless(SwarmPillScript.active_cap_for_level(40) == 108, "Level 40 cap should be 108")


func _verify_spawn_offset() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var player_x := 100.0
	for _i in 40:
		var offset: Vector2 = SwarmPillScript.spawn_offset_xz(30.0, 90.0, 55.0, rng)
		var world_x := player_x + offset.x
		_fail_unless(offset.x < 0.0, "Default spawn ahead offset X must be west (−X), got %s" % offset.x)
		_fail_unless(world_x < player_x, "Default spawn world X must be west of player")
		_fail_unless(absf(offset.y) <= 55.0 + 0.001, "Z offset outside spread: %s" % offset.y)
		_fail_unless(offset.x >= -90.0 - 0.001 and offset.x <= -30.0 + 0.001, "Ahead distance out of range: %s" % offset.x)

	rng.seed = 7
	var south := Vector3(0.0, 0.0, 1.0)
	for _i in 40:
		var offset_s: Vector2 = EnemyStreamSpawnerScript.spawn_offset_along_facing(
			30.0, 90.0, 55.0, rng, south
		)
		_fail_unless(offset_s.y > 0.0, "South-facing spawn must be ahead (+Z), got %s" % offset_s.y)
		_fail_unless(absf(offset_s.x) <= 55.0 + 0.001, "South-facing lateral X outside spread: %s" % offset_s.x)
		_fail_unless(offset_s.y >= 30.0 - 0.001 and offset_s.y <= 90.0 + 0.001, "South ahead distance out of range: %s" % offset_s.y)

	var origin := Vector3.ZERO
	var west := Vector3(-1.0, 0.0, 0.0)
	_fail_unless(
		SwarmPillScript.is_behind_facing(origin, west, Vector3(60.0, 0.0, 0.0)),
		"East of a westbound player past margin should count as behind"
	)
	_fail_unless(
		not SwarmPillScript.is_behind_facing(origin, west, Vector3(-20.0, 0.0, 0.0)),
		"West of a westbound player should not count as behind"
	)
	_fail_unless(
		SwarmPillScript.is_behind_facing(origin, south, Vector3(0.0, 0.0, -60.0)),
		"North of a southbound player past margin should count as behind"
	)
	_fail_unless(
		not SwarmPillScript.is_behind_facing(origin, south, Vector3(0.0, 0.0, 20.0)),
		"South of a southbound player should not count as behind"
	)

	var early := SwarmPillScript.ahead_range_for_level(1)
	_fail_unless(is_equal_approx(early.x, 50.0), "Level 1 spawn min should be 50 m")
	_fail_unless(is_equal_approx(early.y, 200.0), "Level 1 spawn max should be 200 m")
	var late := SwarmPillScript.ahead_range_for_level(40)
	_fail_unless(is_equal_approx(late.x, 40.0), "Level 40 spawn min should be 40 m")
	_fail_unless(is_equal_approx(late.y, 200.0), "Spawn max should stay 200 m at every level")
	var mid := SwarmPillScript.ahead_range_for_level(20)
	_fail_unless(mid.x < 50.0 and mid.x > 40.0, "Mid-run spawn min should sit between 50 m and 40 m")
	_fail_unless(is_equal_approx(mid.y, 200.0), "Mid-run spawn max should stay 200 m")


func _verify_knockback() -> void:
	var pill := Vector3(0.0, 1.0, 0.0)
	var body := Vector3(2.0, 1.0, 0.0)
	var impulse := SwarmPillScript.knockback_impulse_for(pill, body, 10.0)
	_fail_unless(impulse.x > 0.0, "Knockback should push body away from pill on +X")
	_fail_unless(impulse.y > 0.0, "Knockback should include slight upward")
	var toward_pill := SwarmPillScript.knockback_impulse_for(body, pill, 10.0)
	_fail_unless(toward_pill.x < 0.0, "Symmetric case should push other way")
	_fail_unless(
		SwarmPillScript.is_vertical_contact(1.0, 1.0),
		"Same height should allow vertical contact"
	)
	_fail_unless(
		SwarmPillScript.is_vertical_contact(2.0, 1.0),
		"Slightly above within max should still contact"
	)
	_fail_unless(
		not SwarmPillScript.is_vertical_contact(3.5, 1.0),
		"Flying well above pill should not contact"
	)


func _verify_spawn_grace() -> void:
	_fail_unless(
		is_equal_approx(EnemyStreamSpawnerScript.SPAWN_GRACE_SEC, 3.0),
		"Spawn grace should be 3 seconds after E.O.N. pickup"
	)
	_fail_unless(
		is_equal_approx(EnemyStreamSpawnerScript.DAWN_SPAWN_GRACE_SEC, 2.0),
		"Wait until dawn should suppress spawns for 2 seconds"
	)
	_fail_unless(
		SwarmPillScript.CONTACT_DAMAGE == 5,
		"Crawler contact damage should be 5"
	)


func _verify_charger() -> void:
	_fail_unless(
		EnemyStreamSpawnerScript.charger_cap_for_level(3) == 0,
		"Chargers should not spawn before level 4"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.charger_cap_for_level(4) == 4,
		"Level 4 charger cap should be 4"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.charger_cap_for_level(10) == 7,
		"Level 10 charger cap should be 7"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.charger_cap_for_level(40) == 19,
		"Level 40 charger cap should be 19"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.CHARGER_MIN_LEVEL == 4,
		"Chargers should unlock at level 4 (after tower 3)"
	)
	var both_short := EnemyStreamSpawnerScript.ground_spawns_this_tick(10, 12, 0, 2, 2)
	_fail_unless(both_short == Vector3i(1, 1, 0), "Both pools short should spawn one crawler and one charger")
	var crawlers_only := EnemyStreamSpawnerScript.ground_spawns_this_tick(6, 12, 2, 2, 2)
	_fail_unless(crawlers_only == Vector3i(2, 0, 0), "Only crawlers short should spawn up to 2 crawlers")
	var chargers_only := EnemyStreamSpawnerScript.ground_spawns_this_tick(12, 12, 0, 2, 2)
	_fail_unless(chargers_only == Vector3i(0, 2, 0), "Only chargers short should spawn up to 2 chargers")
	var full := EnemyStreamSpawnerScript.ground_spawns_this_tick(12, 12, 2, 2, 2)
	_fail_unless(full == Vector3i.ZERO, "Full pools should spawn nothing")
	var leapers_only := EnemyStreamSpawnerScript.ground_spawns_this_tick(12, 12, 2, 2, 2, 0, 6)
	_fail_unless(leapers_only == Vector3i(0, 0, 2), "Only leapers short should spawn up to 2 leapers")
	var crawler_leaper := EnemyStreamSpawnerScript.ground_spawns_this_tick(10, 12, 2, 2, 2, 0, 6)
	_fail_unless(crawler_leaper == Vector3i(1, 0, 1), "Crawler and leaper short should spawn one of each")
	var all_skip_crawler := EnemyStreamSpawnerScript.ground_spawns_this_tick(
		10, 12, 0, 2, 2, 0, 6, 0
	)
	_fail_unless(
		all_skip_crawler == Vector3i(0, 1, 1),
		"All three short skipping crawlers should spawn charger and leaper"
	)
	var all_skip_charger := EnemyStreamSpawnerScript.ground_spawns_this_tick(
		10, 12, 0, 2, 2, 0, 6, 1
	)
	_fail_unless(
		all_skip_charger == Vector3i(1, 0, 1),
		"All three short skipping chargers should spawn crawler and leaper"
	)
	var all_skip_leaper := EnemyStreamSpawnerScript.ground_spawns_this_tick(
		10, 12, 0, 2, 2, 0, 6, 2
	)
	_fail_unless(
		all_skip_leaper == Vector3i(1, 1, 0),
		"All three short skipping leapers should spawn crawler and charger"
	)
	_fail_unless(
		is_equal_approx(ChargerPillScript.AGGRO_RANGE_M, 15.0),
		"Charger aggro range should be 15 m"
	)
	_fail_unless(
		ChargerPillScript.CHARGER_CONTACT_DAMAGE == 12,
		"Charger contact damage should be 12"
	)
	_fail_unless(
		is_equal_approx(ChargerPillScript.AGGRO_SPEED_MULT, 2.0),
		"Charger aggro speed mult should be 2"
	)
	_fail_unless(
		is_equal_approx(ChargerPillScript.AGGRO_LINGER_SEC, 3.0),
		"Charger should linger boosted for 3s after leaving range"
	)
	var ramped := ChargerPillScript.speed_mult_step(1.0, true, 0.45, 0.45)
	_fail_unless(
		is_equal_approx(ramped, 2.0),
		"Full ramp over AGGRO_RAMP_SEC should reach 2x (got %s)" % ramped
	)
	var cooled := ChargerPillScript.speed_mult_step(2.0, false, 0.45, 0.45)
	_fail_unless(
		is_equal_approx(cooled, 1.0),
		"Leaving aggro should ramp back to 1x (got %s)" % cooled
	)

	var green: ChargerPill = ChargerPillScene.instantiate() as ChargerPill
	root.add_child(green)
	var green_scale := ChargerPillScript.CRAWLER_VISUAL_SCALE_MULT
	_fail_unless(
		is_equal_approx(green.contact_radius_m, SwarmPillScript.CONTACT_RADIUS_M * green_scale),
		"Charger contact radius should be crawler x %.1f (got %s)" % [green_scale, green.contact_radius_m]
	)
	var col := green.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_fail_unless(col != null and col.shape is CapsuleShape3D, "Green should have a capsule collision")
	var capsule := col.shape as CapsuleShape3D
	_fail_unless(
		is_equal_approx(capsule.radius, SwarmPillScript.COLLISION_RADIUS * green_scale),
		"Charger capsule radius should be crawler x %.1f (got %s)" % [green_scale, capsule.radius]
	)
	_fail_unless(
		is_equal_approx(capsule.height, SwarmPillScript.COLLISION_HEIGHT * green_scale),
		"Charger capsule height should be crawler x %.1f (got %s)" % [green_scale, capsule.height]
	)
	green.free()


func _verify_leaper() -> void:
	_fail_unless(LeaperPillScript.MAX_HEALTH == SwarmPillScript.MAX_HEALTH, "Leaper HP should mirror crawler")
	_fail_unless(is_equal_approx(LeaperPillScript.MOVE_SPEED, 8.0), "Leaper chase speed should be 8 m/s")
	_fail_unless(is_equal_approx(LeaperPillScript.LEAP_RANGE_M, 50.0), "Leap range should be 50 m")
	var leaper_ahead := LeaperPillScript.spawn_ahead_range()
	_fail_unless(is_equal_approx(leaper_ahead.x, 120.0), "Leapers should spawn no closer than 120 m")
	_fail_unless(
		is_equal_approx(leaper_ahead.y, SwarmPillScript.SPAWN_AHEAD_MAX_M),
		"Leaper spawn max should match the ground-monster far edge"
	)
	_fail_unless(
		leaper_ahead.x > LeaperPillScript.LEAP_RANGE_M,
		"Leaper spawn min should be outside leap range so they crawl in first"
	)
	_fail_unless(is_equal_approx(LeaperPillScript.CHARGE_SEC, 1.5), "Charge should last 1.5 s")
	_fail_unless(is_equal_approx(LeaperPillScript.LEAP_SEC, 1.0), "Leap should last 1 s")
	_fail_unless(is_equal_approx(LeaperPillScript.RECOVER_SEC, 0.5), "Recover should last 0.5 s")
	_fail_unless(is_equal_approx(LeaperPillScript.LEAP_COOLDOWN_SEC, 7.0), "Leap cooldown should be 7 s")
	_fail_unless(is_equal_approx(LeaperPillScript.SPLASH_RADIUS_M, 2.0), "Splash radius should be 2 m")
	_fail_unless(
		LeaperPillScript.landing_damage_for(true, true, SwarmPillScript.CONTACT_DAMAGE)
		== SwarmPillScript.CONTACT_DAMAGE,
		"Direct landing should deal full crawler damage, not splash on top"
	)
	_fail_unless(
		LeaperPillScript.landing_damage_for(false, true, SwarmPillScript.CONTACT_DAMAGE) == 2,
		"Splash-only landing should deal half crawler damage"
	)
	_fail_unless(
		LeaperPillScript.landing_damage_for(false, false, SwarmPillScript.CONTACT_DAMAGE) == 0,
		"A miss should deal no landing damage"
	)

	var predicted: Vector3 = LeaperPillScript.intercept_xz(
		Vector3(0.0, 2.0, 0.0), Vector3(-10.0, 4.0, 3.0), 1.0
	)
	_fail_unless(is_equal_approx(predicted.x, -10.0), "Intercept X should use 1s of XZ velocity")
	_fail_unless(is_equal_approx(predicted.y, 2.0), "Intercept should keep the player's Y")
	_fail_unless(is_equal_approx(predicted.z, 3.0), "Intercept Z should use 1s of XZ velocity")

	_fail_unless(
		LeaperPillScript.can_begin_charge(50.0, 0.0),
		"A leaper at 50 m with cooldown ready should start charging"
	)
	_fail_unless(
		not LeaperPillScript.can_begin_charge(50.01, 0.0),
		"A leaper past 50 m should not start a charge"
	)
	_fail_unless(
		not LeaperPillScript.can_begin_charge(10.0, 1.0),
		"A leaper on cooldown should not start a charge"
	)
	_fail_unless(
		LeaperPillScript.charge_committed(true, 80.0),
		"A started charge should stay committed if the player leaves 50 m"
	)
	_fail_unless(
		not LeaperPillScript.can_begin_charge(80.0, 0.0),
		"Leaving 50 m should still block a fresh charge"
	)

	var land := Vector3.ZERO
	var touching := Vector3(1.0, 0.4, 0.0)
	var splash := Vector3(1.8, 0.4, 0.0)
	var far := Vector3(2.5, 0.4, 0.0)
	var airborne := Vector3(0.5, 3.0, 0.0)
	_fail_unless(
		LeaperPillScript.is_direct_landing(touching, land, SwarmPillScript.CONTACT_RADIUS_M, 1.2),
		"Landing on the player should count as a direct hit"
	)
	_fail_unless(
		not LeaperPillScript.is_direct_landing(splash, land, SwarmPillScript.CONTACT_RADIUS_M, 1.2),
		"1.8 m should be outside crawler contact radius"
	)
	_fail_unless(
		LeaperPillScript.is_splash_landing(splash, land, 2.0, 1.2),
		"1.8 m should still take splash damage"
	)
	_fail_unless(
		not LeaperPillScript.is_splash_landing(far, land, 2.0, 1.2),
		"Past 2 m should miss the splash"
	)
	_fail_unless(
		not LeaperPillScript.is_splash_landing(airborne, land, 2.0, 1.2),
		"Flying well above the landing point should miss splash"
	)

	_fail_unless(
		EnemyStreamSpawnerScript.LEAPER_MIN_LEVEL == 2,
		"Leapers should unlock at level 2"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.leaper_cap_for_level(1) == 0,
		"Level 1 should spawn no leapers"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.leaper_cap_for_level(2) == 6,
		"Level 2 leaper cap should be one third of crawlers (17 → 6)"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.leaper_cap_for_level(4) == 7,
		"Level 4 leaper cap should be one third of crawlers (22 → 7)"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.leaper_cap_for_level(10) == 12,
		"Level 10 leaper cap should be one third of crawlers (36 → 12)"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.leaper_cap_for_level(40) == 36,
		"Level 40 leaper cap should be one third of crawlers (108 → 36)"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.crawler_alive_count(13, 2, 5) == 6,
		"Crawler count should ignore chargers and leapers"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.crawler_alive_count(5, 0, 5) == 0,
		"A pack of only leapers should not count as crawlers"
	)

	var purple: LeaperPill = LeaperPillScene.instantiate() as LeaperPill
	root.add_child(purple)
	_fail_unless(purple != null, "Leaper scene should instantiate")
	_fail_unless(purple.is_in_group("leaper_pill"), "Leaper should join leaper_pill")
	_fail_unless(purple.is_in_group("swarm_pill"), "Leaper should stay targetable as a swarm pill")
	_fail_unless(purple.get_max_health() == 20, "Leaper should spawn with crawler HP")
	_fail_unless(purple.contact_damage == SwarmPillScript.CONTACT_DAMAGE, "Leaper contact damage should match crawler")
	purple.configure(null, null, SwarmPillScript.DEFAULT_SPEED)
	_fail_unless(
		is_equal_approx(purple.move_speed, LeaperPillScript.MOVE_SPEED),
		"configure should keep 8 m/s even if passed crawler speed"
	)
	var pill := purple.get_node_or_null("Pill") as MeshInstance3D
	_fail_unless(pill != null, "Leaper should have a purple capsule visual")
	purple.free()


func _verify_pill_health() -> void:
	_fail_unless(SwarmPillScript.MAX_HEALTH == 20, "Crawler HP should be 20")
	_fail_unless(ChargerPillScript.CHARGER_MAX_HEALTH == 33, "Charger HP should be 33")
	_fail_unless(AutoRifleScript.DAMAGE == 20, "Rifle damage should be 20")
	_fail_unless(AutoRifleScript.damage_for(0.0) == 20, "Base rifle damage should stay 20")
	_fail_unless(AutoRifleScript.damage_for(0.04) == 21, "4% more damage should round 20.8 to 21")
	_fail_unless(AutoRifleScript.damage_for(0.13) == 23, "4% + 9% should deal 23")
	_fail_unless(AutoRifleScript.damage_for(0.15) == 23, "15% more damage should deal 23")
	_fail_unless(AutoRifleScript.damage_for(0.75) == 35, "Damage bonus should have no cap")

	var red: SwarmPill = SwarmPillScript.new()
	root.add_child(red)
	_fail_unless(red.get_max_health() == 20, "Crawler max HP after ready should be 20")
	_fail_unless(red.get_health() == 20, "Crawler should spawn at full HP")
	_fail_unless(not red.take_damage(10, Vector3(-2.0, 0.0, 0.0)), "First 10 dmg should not kill crawler")
	_fail_unless(red.get_health() == 10, "Crawler should have 10 HP after one shot")
	_fail_unless(red.take_damage(10, Vector3(-2.0, 0.0, 0.0)), "Second 10 dmg should kill crawler")
	_fail_unless(red.is_queued_for_deletion(), "Dead crawler should queue_free")
	red.free()

	var green: ChargerPill = ChargerPillScript.new()
	root.add_child(green)
	_fail_unless(green.get_max_health() == 33, "Charger max HP after ready should be 33")
	_fail_unless(not green.take_damage(10), "First shot should not kill charger")
	_fail_unless(not green.take_damage(10), "Second shot should not kill charger")
	_fail_unless(green.get_health() == 13, "Charger should have 13 HP after two shots")
	_fail_unless(not green.take_damage(10), "Third shot should not kill charger")
	_fail_unless(green.get_health() == 3, "Charger should have 3 HP after three shots")
	_fail_unless(green.take_damage(10), "Fourth shot should kill charger")
	green.free()

	var scaled_red: SwarmPill = SwarmPillScript.new()
	root.add_child(scaled_red)
	scaled_red.configure(null, null, SwarmPillScript.DEFAULT_SPEED)
	scaled_red.apply_difficulty(0.10)
	_fail_unless(scaled_red.get_max_health() == 22, "10% difficulty should floor crawler HP to 22")
	_fail_unless(scaled_red.get_health() == 22, "Scaled crawler should spawn at full scaled HP")
	_fail_unless(
		is_equal_approx(scaled_red.move_speed, 6.0),
		"10% of 6 speed should floor to 6"
	)
	_fail_unless(scaled_red.contact_damage == 5, "10% of 5 damage should floor to 5")
	scaled_red.free()

	var scaled_green: ChargerPill = ChargerPillScript.new()
	root.add_child(scaled_green)
	scaled_green.configure(null, null, SwarmPillScript.DEFAULT_SPEED)
	scaled_green.apply_difficulty(0.15)
	_fail_unless(scaled_green.get_max_health() == 37, "15% of 33 HP should floor to 37")
	_fail_unless(scaled_green.contact_damage == 13, "15% of 12 damage should floor to 13")
	_fail_unless(
		is_equal_approx(scaled_green.move_speed, 6.0),
		"15% of 6 speed should floor to 6"
	)
	scaled_green.free()


func _verify_level_hp_curve() -> void:
	_fail_unless(is_equal_approx(SwarmPillScript.hp_increment_for_level(1), 0.0), "Level 1 increment is 0%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_increment_for_level(2), 0.01), "Level 2 increment is 1%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_increment_for_level(3), 0.02), "Level 3 increment is 2%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_increment_for_level(4), 0.03), "Level 4 increment is 3%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_increment_for_level(5), 0.05), "Level 5 increment is 5%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_increment_for_level(6), 0.07), "Level 6 increment is 7%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_increment_for_level(7), 0.08), "Level 7 increment is 8%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_bonus_for_level(1), 0.0), "Level 1 bonus is 0%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_bonus_for_level(4), 0.06), "Level 4 bonus is 6%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_bonus_for_level(5), 0.11), "Level 5 bonus is 11%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_bonus_for_level(6), 0.18), "Level 6 bonus is 18%")
	_fail_unless(is_equal_approx(SwarmPillScript.hp_bonus_for_level(10), 0.50), "Level 10 bonus is 50%")
	_fail_unless(
		SwarmPillScript.scaled_health_for_level(SwarmPillScript.MAX_HEALTH, 1) == 20,
		"Level 1 crawler HP should stay 20"
	)
	_fail_unless(
		SwarmPillScript.scaled_health_for_level(SwarmPillScript.MAX_HEALTH, 3) == 21,
		"Level 3 crawler HP should round to 21"
	)
	_fail_unless(
		SwarmPillScript.scaled_health_for_level(ChargerPillScript.CHARGER_MAX_HEALTH, 4) == 35,
		"Level 4 charger HP should round to 35"
	)
	_fail_unless(
		SwarmPillScript.scaled_health_for_level(LaserDroneScript.LASER_MAX_HEALTH, 5) == 17,
		"Level 5 laser drone HP should round to 17"
	)
	_fail_unless(
		SwarmPillScript.scaled_health_for_level(CombatDroneScript.DRONE_MAX_HEALTH, 5) == 44,
		"Level 5 missile drone HP should round to 44"
	)
	_fail_unless(
		SwarmPillScript.scaled_health_for_level(SwarmPillScript.MAX_HEALTH, 10) == 30,
		"Level 10 crawler HP should round to 30"
	)
	var scaled_level: SwarmPill = SwarmPillScript.new()
	root.add_child(scaled_level)
	scaled_level.apply_level_hp(10)
	_fail_unless(scaled_level.get_max_health() == 30, "apply_level_hp should set crawler HP to 30 at level 10")
	_fail_unless(scaled_level.get_health() == 30, "apply_level_hp should refill to scaled max")
	scaled_level.free()


func _verify_damage_floats() -> void:
	_fail_unless(
		DamageFloatScript.text_for(10) == "10",
		"Damage numbers should show the hit amount without a minus sign"
	)
	_fail_unless(
		is_equal_approx(DamageFloatScript.DURATION_SEC, 1.0),
		"Enemy damage floats should last as long as the player numbers"
	)
	_fail_unless(DamageFloatScript.RISE_M > 0.0, "Damage numbers should float upward")
	var start := Vector3(0.0, 0.12, 0.02)
	var mid := DamageFloatScript.float_point(0.5, start, 0.8, 1.0, 0.4)
	var top := DamageFloatScript.float_point(1.0, start, 0.8, 1.0, 0.4)
	_fail_unless(top.y > start.y, "The float path should end higher than it started")
	_fail_unless(mid.y < top.y, "Numbers should keep rising instead of falling")
	_fail_unless(
		not is_equal_approx(mid.x, lerpf(start.x, 0.8, 0.5)),
		"The rise should bow sideways instead of traveling in a straight line"
	)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 11
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 29
	var path_a: Dictionary = DamageFloatScript.roll_path(start, rng_a)
	var path_b: Dictionary = DamageFloatScript.roll_path(start, rng_b)
	_fail_unless(
		not is_equal_approx(path_a.end_x, path_b.end_x)
		or not is_equal_approx(path_a.bulge_x, path_b.bulge_x)
		or not is_equal_approx(path_a.end_y, path_b.end_y),
		"Each number should roll a different rise path"
	)
	_clear_damage_floats()
	var red: SwarmPill = SwarmPillScript.new()
	root.add_child(red)
	red.take_damage(10, Vector3(-2.0, 0.0, 0.0))
	var labels := _damage_float_labels()
	_fail_unless(labels.size() == 1, "A hit should spawn one damage float")
	_fail_unless(labels[0].text == "10", "Rifle hit should show 10")
	_fail_unless(labels[0].font == DamageFloatScript.FONT, "Damage floats should use Bungee")
	_fail_unless(
		labels[0].scale.x < 0.5,
		"Damage floats should pop in from a small scale"
	)
	_fail_unless(labels[0].get_parent() != red, "Float should not die with the pill")
	red.take_damage(10, Vector3(-2.0, 0.0, 0.0))
	labels = _damage_float_labels()
	_fail_unless(labels.size() == 2, "Killing blow should still spawn a damage float")
	_fail_unless(red.is_queued_for_deletion(), "Second 10 dmg should kill crawler")
	var saw_kill_text := false
	for label in labels:
		if label.text == "10":
			saw_kill_text = true
	_fail_unless(saw_kill_text, "Killing blow should show the rolled hit amount")
	red.free()
	_clear_damage_floats()

	var green: ChargerPill = ChargerPillScript.new()
	root.add_child(green)
	green.take_damage(10)
	green.take_damage(10)
	green.take_damage(10)
	labels = _damage_float_labels()
	_fail_unless(labels.size() == 3, "Each charger hit should spawn a float")
	var texts: Array[String] = []
	for label in labels:
		texts.append(label.text)
	_fail_unless(texts.has("10"), "Charger hits should show rolled damage, not HP left")
	_fail_unless(not texts.has("5"), "Overkill should not clamp the float to remaining HP")
	green.free()
	_clear_damage_floats()

	# Crits must stay readable when damage exceeds enemy HP (rocket vs crawler).
	var crit_target: SwarmPill = SwarmPillScript.new()
	root.add_child(crit_target)
	crit_target.take_damage(46, Vector3(-1.0, 0.0, 0.0), true)
	labels = _damage_float_labels()
	_fail_unless(labels.size() == 1, "Crit overkill should spawn one float")
	_fail_unless(labels[0].text == "46", "Crit float should show doubled damage, not remaining HP")
	_fail_unless(
		labels[0].modulate.is_equal_approx(DamageFloatScript.CRIT_COLOR),
		"Crit float should use the yellow crit color"
	)
	_fail_unless(
		DamageFloatScript.CRIT_SCALE > 1.0,
		"Crit numbers should land bigger than normal hits"
	)
	_fail_unless(
		DamageFloatScript.CRIT_RISE_M > DamageFloatScript.RISE_M,
		"Crit numbers should float higher than normal hits"
	)
	_fail_unless(
		labels[0].outline_size == DamageFloatScript.CRIT_OUTLINE_SIZE,
		"Crit numbers should use a heavier outline"
	)
	crit_target.free()
	_clear_damage_floats()


func _verify_hit_knockback() -> void:
	var west: Vector3 = SwarmPillScript.hit_knockback_velocity_for(Vector3(-1.0, 0.2, 0.0))
	_fail_unless(west.x < 0.0, "Westbound bullet should shove the pill west")
	_fail_unless(is_equal_approx(west.y, 0.0), "Hit knockback should stay horizontal")
	_fail_unless(is_equal_approx(west.z, 0.0), "A straight west shot should not shove sideways")

	var glancing: Vector3 = SwarmPillScript.hit_knockback_velocity_for(Vector3(-0.8, 0.1, 0.6))
	_fail_unless(glancing.x < 0.0, "Glancing bullet should keep its forward push")
	_fail_unless(glancing.z > 0.0, "Glancing bullet should shove along its travel, not the hit face")

	var impact_on_west_face := Vector3(-0.4, 1.0, 0.0)
	var pill_origin := Vector3.ZERO
	var away_from_impact: Vector3 = pill_origin - impact_on_west_face
	_fail_unless(away_from_impact.x > 0.0, "Sanity: west-face impact points back toward the player")
	var along_bullet: Vector3 = SwarmPillScript.hit_knockback_velocity_for(Vector3(-1.0, 0.0, 0.0))
	_fail_unless(
		along_bullet.x < 0.0,
		"Knockback must follow the bullet, not the capsule contact normal"
	)

	var red: SwarmPill = SwarmPillScript.new()
	root.add_child(red)
	var died := red.take_damage(20, Vector3(-1.0, 0.0, 0.0))
	_fail_unless(died, "20 damage should kill a full crawler")
	var leftover: Vector3 = red.get("_hit_velocity")
	_fail_unless(
		leftover.length_squared() < 0.0001,
		"Lethal hit should skip knockback (got %s)" % leftover
	)
	red.free()

	var wounded: SwarmPill = SwarmPillScript.new()
	root.add_child(wounded)
	wounded.take_damage(10, Vector3(-1.0, 0.0, 0.4))
	var hit_vel: Vector3 = wounded.get("_hit_velocity")
	_fail_unless(hit_vel.x < 0.0, "Non-lethal hit should shove along the bullet")
	_fail_unless(hit_vel.z > 0.0, "Non-lethal hit should keep the bullet's sideways component")
	wounded.free()


func _verify_crawler_death() -> void:
	var red: SwarmPill = SwarmPillScene.instantiate() as SwarmPill
	root.add_child(red)
	_fail_unless(red.take_damage(20, Vector3(-3.0, 1.0, 0.0)), "Lethal hit should report death")
	_fail_unless(red.is_queued_for_deletion(), "Lethal hit should queue_free the enemy")
	red.free()


func _verify_rifle_targeting() -> void:
	_fail_unless(is_equal_approx(AutoRifleScript.RANGE_M, 75.0), "Rifle range should be 75 m")
	_fail_unless(is_equal_approx(AutoRifleScript.FIRE_INTERVAL_SEC, 2.3), "Rifle interval should be 2.3 s")
	_fail_unless(is_equal_approx(AutoRifleScript.CDR_CAP, 0.80), "Attack Speed should cap at 80% CDR")
	_fail_unless(is_equal_approx(AutoRifleScript.SPEED_CAP, 0.80), "Projectile Speed should cap at 80%")
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.0), 2.3),
		"Base volley wait should stay 2.3 s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.13), 2.3 * 0.87),
		"4% + 9% Attack Speed should wait 2.3 × 0.87"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.80), 2.3 * 0.20),
		"80% CDR should wait 0.46 s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.95), 2.3 * 0.20),
		"Over-cap CDR should still wait 0.46 s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.speed_for(0.0), 60.0),
		"Base bullet speed should stay 60 m/s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.speed_for(0.13), 60.0 * 1.13),
		"4% + 9% Projectile Speed should be 60 × 1.13"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.speed_for(0.80), 108.0),
		"80% Projectile Speed should be 108 m/s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.speed_for(0.95), 108.0),
		"Over-cap Projectile Speed should still be 108 m/s"
	)
	_fail_unless(is_equal_approx(AutoRifleScript.BURST_GAP_SEC, 0.12), "Burst gap should stay 0.12 s")

	var origin := Vector3.ZERO
	var facing := Vector3(-1.0, 0.0, 0.0)
	var near_a := _marker_at(Vector3(-40.0, 0.0, 0.0))
	var near_b := _marker_at(Vector3(0.0, 0.0, 50.0))
	var behind := _marker_at(Vector3(40.0, 0.0, 0.0))
	var far := _marker_at(Vector3(-120.0, 0.0, 0.0))
	var pills := [near_a, near_b, behind, far]
	var candidates := AutoRifleScript.collect_candidates(
		pills, origin, facing, AutoRifleScript.RANGE_M
	)
	_fail_unless(candidates.size() == 2, "Only in-range frontal pills should be candidates (got %d)" % candidates.size())
	_fail_unless(not candidates.has(far), "Pills beyond 75 m must not be targeted")
	_fail_unless(not candidates.has(behind), "Pills behind the player must not be targeted")
	_fail_unless(
		AutoRifleScript.is_in_front(origin, facing, near_a.global_position),
		"Westbound facing should treat −X as in front"
	)
	_fail_unless(
		not AutoRifleScript.is_in_front(origin, facing, behind.global_position),
		"Westbound facing should treat +X as behind"
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var saw_a := false
	var saw_b := false
	for _i in 40:
		var picked := AutoRifleScript.pick_target(
			pills, origin, facing, AutoRifleScript.RANGE_M, rng
		)
		_fail_unless(picked != far, "Random pick must never choose out-of-range pill")
		_fail_unless(picked != behind, "Random pick must never choose a pill behind the player")
		if picked == near_a:
			saw_a = true
		elif picked == near_b:
			saw_b = true
	_fail_unless(saw_a and saw_b, "Random pick should not always choose the same in-range pill")

	near_a.free()
	near_b.free()
	behind.free()
	far.free()


func _verify_rifle_burst() -> void:
	_fail_unless(AutoRifleScript.projectile_count_for(0) == 1, "Base rifle should fire 1 shot")
	_fail_unless(AutoRifleScript.projectile_count_for(1) == 2, "+1 projectile should fire 2 shots")
	_fail_unless(AutoRifleScript.projectile_count_for(2) == 3, "+2 extras should fire 3 shots")
	_fail_unless(AutoRifleScript.projectile_count_for(5) == 6, "Legendary +5 extras should fire 6 shots")
	var times := AutoRifleScript.burst_fire_times(2)
	_fail_unless(times.size() == 2, "Two-shot burst should have two fire times")
	_fail_unless(is_equal_approx(times[0], 0.0), "First burst shot should fire immediately")
	_fail_unless(
		is_equal_approx(times[1], AutoRifleScript.BURST_GAP_SEC),
		"Second burst shot should wait the burst gap"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.burst_cooldown_start_sec(2), AutoRifleScript.BURST_GAP_SEC),
		"Cooldown should start after the last burst shot"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.burst_cooldown_start_sec(1), 0.0),
		"Single shot cooldown should start immediately"
	)


func _verify_spawn_after_try_again() -> void:
	_fail_unless(
		not EnemyStreamSpawnerScript.should_spawn_stream(false, false, false),
		"New game should not spawn enemies before the first E.O.N. pickup"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.should_spawn_stream(true, true, false),
		"Enemies should spawn while carrying the E.O.N."
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.should_spawn_stream(false, true, true),
		"Enemies should stop while the death screen is up"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.should_spawn_stream(false, true, false),
		"Try Again should spawn enemies even before picking up the E.O.N. again"
	)


func _damage_float_labels() -> Array[Label3D]:
	var labels: Array[Label3D] = []
	for node in root.get_tree().get_nodes_in_group(DamageFloatScript.GROUP):
		var label := node as Label3D
		if label != null:
			labels.append(label)
	return labels


func _clear_damage_floats() -> void:
	for label in _damage_float_labels():
		var parent := label.get_parent()
		if parent != null and parent != root and String(parent.name).begins_with("DamageFloat"):
			parent.free()
		else:
			label.free()


func _marker_at(pos: Vector3) -> Node3D:
	var marker := Node3D.new()
	root.add_child(marker)
	marker.global_position = pos
	return marker


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
