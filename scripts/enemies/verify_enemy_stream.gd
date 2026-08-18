extends SceneTree

const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")
const ChargerPillScript = preload("res://scripts/enemies/charger_pill.gd")
const EnemyStreamSpawnerScript = preload("res://scripts/enemies/enemy_stream_spawner.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_cap_curve()
	_verify_spawn_offset()
	_verify_knockback()
	_verify_spawn_grace()
	_verify_charger()
	_verify_pill_health()
	_verify_hit_knockback()
	_verify_rifle_targeting()
	_verify_rifle_burst()
	_verify_spawn_after_try_again()
	print("Enemy stream verification passed.")
	quit(0)


func _verify_cap_curve() -> void:
	var prev := -1
	for level in range(1, 41):
		var cap := SwarmPillScript.active_cap_for_level(level)
		_fail_unless(cap >= 8 and cap <= 60, "Cap out of range at level %d: %d" % [level, cap])
		_fail_unless(cap >= prev, "Cap should be non-decreasing (%d -> %d at level %d)" % [prev, cap, level])
		prev = cap
	_fail_unless(SwarmPillScript.active_cap_for_level(1) == 8, "Level 1 cap should be 8")
	_fail_unless(SwarmPillScript.active_cap_for_level(40) == 60, "Level 40 cap should be 60")


func _verify_spawn_offset() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var player_x := 100.0
	for _i in 40:
		var offset: Vector2 = SwarmPillScript.spawn_offset_xz(30.0, 90.0, 55.0, rng)
		var world_x := player_x + offset.x
		_fail_unless(offset.x < 0.0, "Spawn ahead offset X must be negative (west), got %s" % offset.x)
		_fail_unless(world_x < player_x, "Spawn world X must be west of player")
		_fail_unless(absf(offset.y) <= 55.0 + 0.001, "Z offset outside spread: %s" % offset.y)
		_fail_unless(offset.x >= -90.0 - 0.001 and offset.x <= -30.0 + 0.001, "Ahead distance out of range: %s" % offset.x)


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
		"Red swarm contact damage should be 5"
	)


func _verify_charger() -> void:
	_fail_unless(
		is_equal_approx(EnemyStreamSpawnerScript.CHARGER_SPAWN_CHANCE, 1.0 / 6.0),
		"Charger spawn chance should be 1/6 (1:5 vs red)"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.CHARGER_MIN_LEVEL == 2,
		"Chargers should unlock at level 2 (after tower 1)"
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


func _verify_pill_health() -> void:
	_fail_unless(SwarmPillScript.MAX_HEALTH == 20, "Red pill HP should be 20")
	_fail_unless(ChargerPillScript.CHARGER_MAX_HEALTH == 25, "Green pill HP should be 25")
	_fail_unless(AutoRifleScript.DAMAGE == 10, "Rifle damage should be 10")

	var red: SwarmPill = SwarmPillScript.new()
	root.add_child(red)
	_fail_unless(red.get_max_health() == 20, "Red max HP after ready should be 20")
	_fail_unless(red.get_health() == 20, "Red should spawn at full HP")
	_fail_unless(not red.take_damage(10, Vector3(-2.0, 0.0, 0.0)), "First 10 dmg should not kill red")
	_fail_unless(red.get_health() == 10, "Red should have 10 HP after one shot")
	_fail_unless(red.take_damage(10, Vector3(-2.0, 0.0, 0.0)), "Second 10 dmg should kill red")
	_fail_unless(red.is_queued_for_deletion(), "Dead red should queue_free")
	red.free()

	var green: ChargerPill = ChargerPillScript.new()
	root.add_child(green)
	_fail_unless(green.get_max_health() == 25, "Green max HP after ready should be 25")
	_fail_unless(not green.take_damage(10), "First shot should not kill green")
	_fail_unless(not green.take_damage(10), "Second shot should not kill green")
	_fail_unless(green.get_health() == 5, "Green should have 5 HP after two shots")
	_fail_unless(green.take_damage(10), "Third shot should kill green")
	green.free()


func _verify_hit_knockback() -> void:
	var shove: Vector3 = SwarmPillScript.hit_knockback_velocity_for(
		Vector3(-2.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 0.0)
	)
	_fail_unless(shove.x > 0.0, "Hit knockback should push pill away from the shot")
	_fail_unless(is_equal_approx(shove.y, 0.0), "Hit knockback should stay horizontal")

	var red: SwarmPill = SwarmPillScript.new()
	root.add_child(red)
	var died := red.take_damage(20, Vector3(-2.0, 0.0, 0.0))
	_fail_unless(died, "20 damage should kill a full red pill")
	var leftover: Vector3 = red.get("_hit_velocity")
	_fail_unless(
		leftover.length_squared() < 0.0001,
		"Lethal hit should skip knockback (got %s)" % leftover
	)
	red.free()

	var wounded: SwarmPill = SwarmPillScript.new()
	root.add_child(wounded)
	wounded.take_damage(10, Vector3(-2.0, 0.0, 0.0))
	var hit_vel: Vector3 = wounded.get("_hit_velocity")
	_fail_unless(hit_vel.x > 0.0, "Non-lethal hit should apply knockback")
	wounded.free()


func _verify_rifle_targeting() -> void:
	_fail_unless(is_equal_approx(AutoRifleScript.RANGE_M, 100.0), "Rifle range should be 100 m")
	_fail_unless(is_equal_approx(AutoRifleScript.FIRE_INTERVAL_SEC, 3.0), "Rifle interval should be 3 s")

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
	_fail_unless(not candidates.has(far), "Pills beyond 100 m must not be targeted")
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
	_fail_unless(AutoRifleScript.projectile_count_for(3) == 4, "Stacks should keep adding shots")
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
