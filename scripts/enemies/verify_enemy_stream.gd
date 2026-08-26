extends SceneTree

const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")
const SwarmPillScene = preload("res://scenes/enemies/swarm_pill.tscn")
const ChargerPillScript = preload("res://scripts/enemies/charger_pill.gd")
const ChargerPillScene = preload("res://scenes/enemies/charger_pill.tscn")
const EnemyStreamSpawnerScript = preload("res://scripts/enemies/enemy_stream_spawner.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const DamageFloatScript = preload("res://scripts/ui/damage_float.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_cap_curve()
	_verify_spawn_offset()
	_verify_knockback()
	_verify_spawn_grace()
	_verify_charger()
	_verify_pill_health()
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
	var early := SwarmPillScript.ahead_range_for_level(1)
	_fail_unless(is_equal_approx(early.x, 40.0), "Level 1 spawn min should stay 40 m")
	_fail_unless(is_equal_approx(early.y, 110.0), "Level 1 spawn max should be 110 m")
	var late := SwarmPillScript.ahead_range_for_level(40)
	_fail_unless(is_equal_approx(late.x, 30.0), "Level 40 spawn min should stay 30 m")
	_fail_unless(is_equal_approx(late.y, 110.0), "Spawn max should stay 110 m at every level")


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
		is_equal_approx(EnemyStreamSpawnerScript.CHARGER_SPAWN_CHANCE, 1.0 / 6.0),
		"Charger spawn chance should be 1/6 (1:5 vs crawlers)"
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


func _verify_pill_health() -> void:
	_fail_unless(SwarmPillScript.MAX_HEALTH == 20, "Crawler HP should be 20")
	_fail_unless(ChargerPillScript.CHARGER_MAX_HEALTH == 25, "Charger HP should be 25")
	_fail_unless(AutoRifleScript.DAMAGE == 10, "Rifle damage should be 10")
	_fail_unless(AutoRifleScript.damage_for(0.0) == 10, "Base rifle damage should stay 10")
	_fail_unless(AutoRifleScript.damage_for(0.04) == 10, "4% more damage should round 10.4 down to 10")
	_fail_unless(AutoRifleScript.damage_for(0.13) == 11, "4% + 9% should deal 11")
	_fail_unless(AutoRifleScript.damage_for(0.15) == 12, "15% more damage should deal 12")
	_fail_unless(AutoRifleScript.damage_for(0.75) == 18, "Damage bonus should have no cap")

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
	_fail_unless(green.get_max_health() == 25, "Charger max HP after ready should be 25")
	_fail_unless(not green.take_damage(10), "First shot should not kill charger")
	_fail_unless(not green.take_damage(10), "Second shot should not kill charger")
	_fail_unless(green.get_health() == 5, "Charger should have 5 HP after two shots")
	_fail_unless(green.take_damage(10), "Third shot should kill charger")
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
	_fail_unless(scaled_green.get_max_health() == 28, "15% of 25 HP should floor to 28")
	_fail_unless(scaled_green.contact_damage == 13, "15% of 12 damage should floor to 13")
	_fail_unless(
		is_equal_approx(scaled_green.move_speed, 6.0),
		"15% of 6 speed should floor to 6"
	)
	scaled_green.free()


func _verify_damage_floats() -> void:
	_fail_unless(
		DamageFloatScript.text_for(10) == "-10",
		"Enemy hits should use the same -N text as the player"
	)
	_fail_unless(
		is_equal_approx(DamageFloatScript.DURATION_SEC, 0.75),
		"Enemy damage floats should last as long as the player numbers"
	)
	_clear_damage_floats()
	var red: SwarmPill = SwarmPillScript.new()
	root.add_child(red)
	red.take_damage(10, Vector3(-2.0, 0.0, 0.0))
	var labels := _damage_float_labels()
	_fail_unless(labels.size() == 1, "A hit should spawn one damage float")
	_fail_unless(labels[0].text == "-10", "Rifle hit should show -10")
	_fail_unless(labels[0].get_parent() != red, "Float should not die with the pill")
	red.take_damage(10, Vector3(-2.0, 0.0, 0.0))
	labels = _damage_float_labels()
	_fail_unless(labels.size() == 2, "Killing blow should still spawn a damage float")
	_fail_unless(red.is_queued_for_deletion(), "Second 10 dmg should kill crawler")
	var saw_kill_text := false
	for label in labels:
		if label.text == "-10":
			saw_kill_text = true
	_fail_unless(saw_kill_text, "Killing blow should show the HP actually lost")
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
	_fail_unless(texts.has("-10"), "First charger shots should show -10")
	_fail_unless(texts.has("-5"), "Overkill on remaining HP should show -5")
	green.free()
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
	_fail_unless(is_equal_approx(AutoRifleScript.FIRE_INTERVAL_SEC, 3.0), "Rifle interval should be 3 s")
	_fail_unless(is_equal_approx(AutoRifleScript.CDR_CAP, 0.80), "Attack Speed should cap at 80% CDR")
	_fail_unless(is_equal_approx(AutoRifleScript.SPEED_CAP, 0.80), "Projectile Speed should cap at 80%")
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.0), 3.0),
		"Base volley wait should stay 3 s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.13), 3.0 * 0.87),
		"4% + 9% Attack Speed should wait 3.0 × 0.87"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.80), 0.60),
		"80% CDR should wait 0.60 s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.fire_interval_for(0.95), 0.60),
		"Over-cap CDR should still wait 0.60 s"
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
