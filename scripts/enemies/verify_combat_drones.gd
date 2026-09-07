extends SceneTree

const CombatDroneScript = preload("res://scripts/enemies/combat_drone.gd")
const LaserDroneScript = preload("res://scripts/enemies/laser_drone.gd")
const MissileDroneScript = preload("res://scripts/enemies/missile_drone.gd")
const MachineGunDroneScript = preload("res://scripts/enemies/machine_gun_drone.gd")
const DroneLaserBlastScript = preload("res://scripts/enemies/drone_laser_blast.gd")
const LaserDroneTelegraphScript = preload("res://scripts/enemies/laser_drone_telegraph.gd")
const LaserTargetReticleUIScript = preload("res://scripts/ui/laser_target_reticle_ui.gd")
const DroneRocketScript = preload("res://scripts/enemies/drone_rocket.gd")
const GroundReticleScript = preload("res://scripts/enemies/ground_reticle.gd")
const EnemyStreamSpawnerScript = preload("res://scripts/enemies/enemy_stream_spawner.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const AutoLaserScript = preload("res://scripts/weapons/auto_laser.gd")
const AutoRocketScript = preload("res://scripts/weapons/auto_rocket.gd")
const AutoTeslaScript = preload("res://scripts/weapons/auto_tesla.gd")
const AutoShotgunScript = preload("res://scripts/weapons/auto_shotgun.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")
const WeaponTargetingScript = preload("res://scripts/weapons/weapon_targeting.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const PlayerHealthScript = preload("res://scripts/player/player_health.gd")
const LevelRunScript = preload("res://scripts/game/level_run.gd")
const DroneDeathBurstScript = preload("res://scripts/enemies/drone_death_burst.gd")
const DroneStreakVfxScript = preload("res://scripts/enemies/drone_streak_vfx.gd")
const DroneDebrisThrusterVfxScript = preload("res://scripts/enemies/drone_debris_thruster_vfx.gd")
const LaserDroneSkinScene = preload("res://scenes/enemies/laser_drone_skin.tscn")
const MissileDroneScene = preload("res://scenes/enemies/missile_drone.tscn")
const LaserDroneScene = preload("res://scenes/enemies/laser_drone.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LevelRunScript.ensure(42)
	_verify_cap_and_speed()
	if _failed:
		return
	_verify_spawn_spacing()
	if _failed:
		return
	_verify_laser_rework()
	if _failed:
		return
	_verify_laser_drone_weapon_magnet()
	if _failed:
		return
	_verify_laser_spawn_rules()
	if _failed:
		return
	_verify_missile_hail()
	if _failed:
		return
	_verify_machine_gun_drone()
	if _failed:
		return
	_verify_flight_heading_inertia()
	if _failed:
		return
	_verify_air_targeting()
	if _failed:
		return
	_verify_fire_gate()
	if _failed:
		return
	_verify_smoke_ai()
	if _failed:
		return
	await _verify_drone_death_debris()
	if _failed:
		return
	print("Combat drone verification passed.")
	quit(0)


func _verify_cap_and_speed() -> void:
	_fail_unless(CombatDroneScript.DRONE_MIN_LEVEL == 5, "Drones unlock at level 5")
	_fail_unless(EnemyStreamSpawnerScript.DRONE_MIN_LEVEL == 5, "Spawner drone min level should be 5")
	_fail_unless(CombatDroneScript.drone_cap_for_level(4) == 0, "Level 4 should have 0 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(5) == 1, "Level 5 should have 1 drone")
	_fail_unless(CombatDroneScript.drone_cap_for_level(6) == 2, "Level 6 should have 2 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(7) == 3, "Level 7 should have 3 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(8) == 4, "Level 8 should have 4 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(10) == 6, "Level 10 should have 6 drones")
	_fail_unless(
		is_equal_approx(CombatDroneScript.move_speed_for_drone_level(5), 15.0),
		"Level 5 drone speed should be 15 m/s"
	)
	_fail_unless(
		is_equal_approx(CombatDroneScript.move_speed_for_drone_level(6), 16.0),
		"Level 6 drone speed should be 16 m/s"
	)
	_fail_unless(CombatDroneScript.DRONE_MAX_HEALTH == 40, "Drone HP should be 40")
	_fail_unless(
		is_equal_approx(CombatDroneScript.WEAPON_RANGE_M, 40.0),
		"Drone weapon range should be 40 m"
	)
	_fail_unless(
		is_equal_approx(CombatDroneScript.SPAWN_AHEAD_M, 400.0),
		"Drones should spawn 400 m ahead"
	)


func _verify_spawn_spacing() -> void:
	var bounds := LevelRunScript.segment_east_west_x(5)
	var east_x := bounds.x
	var west_x := bounds.y
	var span := east_x - west_x
	_fail_unless(span > 1.0, "Level 5 should have a positive westbound span")

	var even_rng := RandomNumberGenerator.new()
	even_rng.seed = 4242
	var even_thresholds := EnemyStreamSpawnerScript.build_drone_spawn_thresholds(3, 1.0, 0.5, even_rng)
	_fail_unless(even_thresholds.size() == 3, "Even schedule should have 3 thresholds")
	_fail_unless(
		is_equal_approx(even_thresholds[0], 0.5 / 3.0),
		"Even first threshold should be first midpoint"
	)
	_fail_unless(
		is_equal_approx(even_thresholds[1], 1.5 / 3.0),
		"Even second threshold should be second midpoint"
	)
	_fail_unless(
		is_equal_approx(even_thresholds[2], 2.5 / 3.0),
		"Even third threshold should be third midpoint"
	)

	var cluster_rng := RandomNumberGenerator.new()
	cluster_rng.seed = 1337
	var cluster_thresholds := EnemyStreamSpawnerScript.build_drone_spawn_thresholds(
		4, 0.0, 0.55, cluster_rng
	)
	_fail_unless(cluster_thresholds.size() == 4, "Cluster schedule should have 4 thresholds")
	for threshold in cluster_thresholds:
		_fail_unless(
			absf(threshold - 0.55) <= 0.03,
			"Clustered drones should spawn near the same progress"
		)

	_fail_unless(
		not EnemyStreamSpawnerScript.drone_spawn_progress_allows(east_x, 5, 0, even_thresholds),
		"Should not spawn first drone at east tower"
	)
	var first_x := east_x - span * even_thresholds[0] - 1.0
	_fail_unless(
		EnemyStreamSpawnerScript.drone_spawn_progress_allows(first_x, 5, 0, even_thresholds),
		"Should spawn first drone near first threshold"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.drone_spawn_progress_allows(first_x, 5, 1, even_thresholds),
		"Second drone should wait for later progress"
	)


func _verify_laser_rework() -> void:
	_fail_unless(LaserDroneScript.LASER_MAX_HEALTH == 15, "Laser drone should have 15 HP")
	_fail_unless(
		is_equal_approx(LaserDroneTelegraphScript.SHRINK_SEC, 8.0),
		"Laser shrink telegraph should be 8 s"
	)
	_fail_unless(
		is_equal_approx(LaserDroneTelegraphScript.BLINK_SEC, 2.0),
		"Laser blink telegraph should be 2 s"
	)
	_fail_unless(LaserDroneScript.BLAST_DAMAGE == 35, "Laser blast should deal 35")
	_fail_unless(is_equal_approx(LaserDroneScript.RELOAD_SEC, 5.0), "Laser reload should be 5 s")
	_fail_unless(
		is_equal_approx(LaserDroneScript.ENGAGE_INNER_M, 35.0),
		"Laser flee band should start inside 35 m"
	)
	_fail_unless(
		is_equal_approx(LaserDroneScript.LOCK_ON_RANGE_M, 180.0),
		"Laser lock-on range should be 180 m"
	)
	_fail_unless(
		LaserDroneScript.movement_zone_for_distance(200.0) == "acquire",
		"Beyond 180 m should be acquire"
	)
	_fail_unless(
		LaserDroneScript.movement_zone_for_distance(100.0) == "engage",
		"35-180 m should be engage"
	)
	_fail_unless(
		LaserDroneScript.movement_zone_for_distance(20.0) == "flee",
		"Inside 35 m should flee"
	)
	_fail_unless(
		is_equal_approx(LaserDroneScript.acquire_speed_for_player_bonus(0.0), 26.6),
		"Acquire chase should match player cruise max without boost"
	)
	_fail_unless(
		LaserDroneScript.is_within_lock_on_range(120.0),
		"Player within 180 m should allow laser lock-on"
	)
	_fail_unless(
		not LaserDroneScript.is_within_lock_on_range(220.0),
		"Player beyond 180 m should not start laser lock-on"
	)
	_fail_unless(DroneLaserBlastScript.DAMAGE == 35, "Blast damage alias should be 35")
	_fail_unless(
		is_equal_approx(DroneLaserBlastScript.SPEED_MPS, 120.0),
		"Laser ground pulse should travel at 120 m/s"
	)

	_fail_unless(
		LaserDroneTelegraphScript.scale_at(0.0) > LaserDroneTelegraphScript.scale_at(8.0),
		"Reticle should shrink over 8 s"
	)
	_fail_unless(
		is_equal_approx(LaserDroneTelegraphScript.scale_at(8.0), LaserDroneTelegraphScript.END_SCALE),
		"Reticle should reach minimum scale at 8 s"
	)
	_fail_unless(
		not LaserDroneTelegraphScript.is_blinking(7.5),
		"Reticle should not blink before 8 s"
	)
	_fail_unless(
		LaserDroneTelegraphScript.is_blinking(8.5),
		"Reticle should blink after 8 s"
	)
	_fail_unless(
		LaserDroneTelegraphScript.phase_at(9.0) == "blink",
		"Reticle should still be in blink phase at 9 s"
	)
	_fail_unless(
		LaserTargetReticleUIScript.bracket_half_spread(LaserDroneTelegraphScript.START_SCALE)
		> LaserTargetReticleUIScript.bracket_half_spread(LaserDroneTelegraphScript.END_SCALE),
		"Bracket reticle should close inward over the telegraph"
	)
	_fail_unless(
		is_equal_approx(LaserDroneTelegraphScript.circle_trace_progress(8.0), 0.0),
		"Ring trace should start at the blink phase"
	)
	_fail_unless(
		is_equal_approx(LaserDroneTelegraphScript.circle_trace_progress(9.0), 0.5),
		"Ring trace should be halfway through after 1 s of blink"
	)
	_fail_unless(
		is_equal_approx(LaserDroneTelegraphScript.circle_trace_progress(10.0), 1.0),
		"Ring trace should complete when the blast fires"
	)
	_fail_unless(
		is_equal_approx(
			LaserTargetReticleUIScript.outer_ring_radius(LaserDroneTelegraphScript.END_SCALE),
			LaserTargetReticleUIScript.bracket_half_spread(LaserDroneTelegraphScript.END_SCALE)
			+ LaserTargetReticleUIScript.BAR_LENGTH_PX
		),
		"Ring should pass through the outer tips of the bracket bars"
	)
	_fail_unless(
		LaserDroneTelegraphScript.brackets_visible(8.06),
		"Bracket bars should flash during the 2 s ring phase"
	)
	_fail_unless(
		not LaserDroneTelegraphScript.brackets_visible(8.13),
		"Bracket bars should alternate off during the ring phase"
	)

	var player := Node3D.new()
	root.add_child(player)
	player.global_position = Vector3.ZERO
	var laser: LaserDrone = LaserDroneScript.new()
	root.add_child(laser)
	laser.configure(null, player, 15.0)
	laser.global_position = Vector3(-200.0, 8.0, 0.0)
	var acquire := laser.desired_velocity_xz()
	_fail_unless(acquire.x > 0.0, "Laser should chase the player in acquire zone")
	_fail_unless(
		is_equal_approx(acquire.length(), LaserDroneScript.acquire_speed_for_player_bonus(0.0)),
		"Acquire chase should use player cruise max speed"
	)
	laser.global_position = Vector3(-80.0, 8.0, 0.0)
	_fail_unless(
		laser.desired_velocity_xz().is_equal_approx(Vector3.ZERO),
		"Laser should hold in the engage zone"
	)
	laser.global_position = Vector3(-20.0, 8.0, 0.0)
	var flee := laser.desired_velocity_xz()
	_fail_unless(flee.x < 0.0, "Laser should flee away from the player inside 35 m")
	_fail_unless(is_equal_approx(flee.length(), 15.0), "Laser flee should use drone move speed")

	var health: PlayerHealth = PlayerHealthScript.new()
	root.add_child(health)
	health.current = 50
	var blast: DroneLaserBlast = DroneLaserBlastScript.fire(
		self, Vector3(-20.0, 8.0, 0.0), player, null, 35
	)
	_advance_blast_to_impact(blast)
	_fail_unless(health.current == 15, "Laser pulse should deal 35 damage on impact")
	_fail_unless(blast.is_finished(), "Laser pulse should finish after impact")
	blast.free()
	health.free()

	var chase_player := Node3D.new()
	root.add_child(chase_player)
	chase_player.global_position = Vector3.ZERO
	var chase_blast: DroneLaserBlast = DroneLaserBlastScript.fire(
		self, Vector3(-40.0, 10.0, 0.0), chase_player, null, 35
	)
	var chase_step := 1.0 / 60.0
	var chase_elapsed := 0.0
	while chase_elapsed < 4.0 and is_instance_valid(chase_blast) and not chase_blast.is_finished():
		chase_player.global_position.x += 22.0 * chase_step
		chase_blast.advance(chase_step)
		chase_elapsed += chase_step
	_fail_unless(chase_blast.is_finished(), "Homing pulse should impact after catching the player")
	_fail_unless(
		chase_blast.global_position.x > 4.0,
		"Homing pulse should pursue the player's live position, not the fire-time lock"
	)
	chase_blast.free()
	chase_player.free()

	var charge_health: PlayerHealth = PlayerHealthScript.new()
	var charge_rig := Node3D.new()
	var charge_player := Node3D.new()
	charge_rig.add_child(charge_player)
	charge_rig.add_child(charge_health)
	root.add_child(charge_rig)
	charge_health.current = 50
	var charge_laser: LaserDrone = LaserDroneScene.instantiate() as LaserDrone
	root.add_child(charge_laser)
	charge_laser.configure(null, charge_player, 15.0)
	charge_player.global_position = Vector3.ZERO
	charge_laser.global_position = Vector3(-250.0, 8.0, 0.0)
	_fail_unless(not charge_laser.can_despawn_when_behind(), "Laser should not despawn behind until it fires")
	var step := 1.0 / 60.0
	for _i in 30:
		charge_laser._update_weapons(step)
	_fail_unless(
		not bool(charge_laser.get("_telegraph_armed")),
		"Laser should not arm while the player is outside lock-on range"
	)
	_fail_unless(
		not bool(charge_laser.get("_ui_reticle_active")),
		"Reticle should stay hidden until lock-on"
	)
	charge_laser.global_position = Vector3(-20.0, 8.0, 0.0)
	var frames := int(ceil(LaserDroneTelegraphScript.telegraph_total_sec() / step)) + 1
	for _i in frames:
		charge_laser._update_weapons(step)
	var active_blast: DroneLaserBlast = charge_laser.get("_active_blast")
	_advance_blast_to_impact(active_blast)
	_fail_unless(
		charge_health.current == 15,
		"Laser should fire automatically after the full 10 s telegraph"
	)
	_fail_unless(charge_laser.get("_has_fired_blast"), "Laser should record that it fired")
	_fail_unless(charge_laser.can_despawn_when_behind(), "Laser may despawn behind after firing")
	var flare := charge_laser.get_type_flare()
	_fail_unless(
		flare != null,
		"Laser drone should mount a visible targeting flare under Visual"
	)
	if flare != null:
		_fail_unless(
			flare.get_flare_color().is_equal_approx(Color(1.6, 0.21, 0.064, 1.0)),
			"Laser TypeFlare should use red tint (got %s)" % flare.get_flare_color()
		)
	charge_laser.free()
	charge_rig.free()

	laser.free()
	player.free()


func _verify_laser_drone_weapon_magnet() -> void:
	var origin := Vector3.ZERO
	var facing := Vector3(-1.0, 0.0, 0.0)
	var range_m := AutoRifleScript.RANGE_M
	var rng := RandomNumberGenerator.new()
	rng.seed = 17

	var laser: SwarmPill = SwarmPillScript.new()
	var closer: SwarmPill = SwarmPillScript.new()
	root.add_child(laser)
	root.add_child(closer)
	laser.add_to_group(WeaponTargetingScript.LASER_DRONE_GROUP)
	laser.global_position = Vector3(-12.0, 0.0, 0.0)
	closer.global_position = Vector3(-8.0, 0.0, 0.0)
	var pills: Array = [laser, closer]

	var rifle_pick := AutoRifleScript.pick_target(pills, origin, facing, range_m, rng)
	_fail_unless(rifle_pick == laser, "Rifle should magnet to in-range laser drone")

	var laser_pick := AutoLaserScript.pick_unique_target(
		pills, origin, facing, AutoLaserScript.RANGE_M, {}, rng
	)
	_fail_unless(laser_pick == laser, "Laser should magnet to in-range laser drone")

	var exclude: Dictionary = {}
	exclude[laser.get_instance_id()] = true
	var stacked_laser := AutoLaserScript.pick_unique_target(
		pills, origin, facing, AutoLaserScript.RANGE_M, exclude, rng
	)
	_fail_unless(
		stacked_laser == laser,
		"Extra laser beams should keep magneting the same drone"
	)

	var rocket_pick := AutoRocketScript.pick_best_target(
		pills, origin, facing, AutoRocketScript.RANGE_M
	)
	_fail_unless(rocket_pick == laser, "Rocket should magnet to in-range laser drone")

	var tesla_picks := AutoTeslaScript.pick_unique_targets(
		pills, origin, facing, AutoTeslaScript.RANGE_M, 3, rng
	)
	_fail_unless(tesla_picks.size() == 3, "Tesla volley should still fire three strikes")
	_fail_unless(
		tesla_picks[0] == laser and tesla_picks[1] == laser and tesla_picks[2] == laser,
		"All Tesla strikes should magnet to the laser drone"
	)

	var shotgun_pick := AutoShotgunScript.pick_target(
		pills, origin, facing, AutoShotgunScript.RANGE_M, rng
	)
	_fail_unless(shotgun_pick == laser, "Shotgun should magnet to in-range laser drone")

	var bounce := AutoRifleScript.pick_bounce_target(
		pills, origin, 50.0, exclude, rng
	)
	_fail_unless(
		bounce == laser,
		"Bounce chains should keep magneting the laser drone while it lives"
	)

	laser.set("_hp", 0)
	_fail_unless(not laser.is_alive(), "Test laser drone should be dead")
	var freed := AutoRifleScript.pick_target(pills, origin, facing, range_m, rng)
	_fail_unless(freed == closer, "Weapons should free up after the laser drone dies")

	var behind: SwarmPill = SwarmPillScript.new()
	var forward: SwarmPill = SwarmPillScript.new()
	var alive_laser: SwarmPill = SwarmPillScript.new()
	root.add_child(behind)
	root.add_child(forward)
	root.add_child(alive_laser)
	forward.global_position = Vector3(-15.0, 0.0, 0.0)
	behind.global_position = Vector3(25.0, 0.0, 0.0)
	alive_laser.add_to_group(WeaponTargetingScript.LASER_DRONE_GROUP)
	alive_laser.global_position = Vector3(25.0, 0.0, 5.0)
	var behind_pills: Array = [alive_laser, behind, forward]
	var no_magnet := AutoRifleScript.pick_target(
		behind_pills, origin, facing, range_m, rng
	)
	_fail_unless(
		no_magnet == forward,
		"Out-of-arc laser drones should not steal weapon focus"
	)

	laser.free()
	closer.free()
	behind.free()
	forward.free()
	alive_laser.free()


func _advance_blast_to_impact(blast: DroneLaserBlast) -> void:
	if blast == null:
		return
	var step := 1.0 / 60.0
	var elapsed := 0.0
	while elapsed < 5.0 and is_instance_valid(blast) and not blast.is_finished():
		blast.advance(step)
		elapsed += step


func _verify_laser_spawn_rules() -> void:
	var plan_rng := RandomNumberGenerator.new()
	plan_rng.seed = 9001
	var level8_plan := EnemyStreamSpawnerScript.build_drone_spawn_plan(8, plan_rng)
	_fail_unless(level8_plan.size() == 4, "Level 8 should roll four drone slots")
	var level5_plan := EnemyStreamSpawnerScript.build_drone_spawn_plan(5, plan_rng)
	_fail_unless(level5_plan.size() == 1, "Level 5 should roll one drone slot")
	_fail_unless(
		EnemyStreamSpawnerScript.drone_spawn_thresholds_from_plan(level8_plan).size() == 4,
		"Spawn plan should expose one threshold per slot"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.can_spawn_laser_now(0.0, true),
		"Active laser should block another laser spawn"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.can_spawn_laser_now(1.0, false),
		"Kill cooldown should block laser spawn"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.can_spawn_laser_now(0.0, false),
		"Laser should spawn when no active laser and no cooldown"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.can_spawn_mg_now(true),
		"Active MG drone should block another MG spawn"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.can_spawn_mg_now(false),
		"MG drone should spawn when none is active"
	)
	_fail_unless(
		EnemyStreamSpawnerScript.can_spawn_laser(0, 2, 0.0, false),
		"Legacy laser budget helper should allow first spawn"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.can_spawn_laser(0, 2, 1.0, false),
		"Legacy laser budget helper should respect cooldown"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.can_spawn_laser(0, 2, 0.0, true),
		"Legacy laser budget helper should respect active laser"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.can_spawn_laser(2, 2, 0.0, false),
		"Legacy laser budget helper should respect exhausted budget"
	)
	_fail_unless(
		is_equal_approx(EnemyStreamSpawnerScript.LASER_KILL_COOLDOWN_SEC, 45.0),
		"Laser respawn cooldown should be 45 s after kill or despawn"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.should_start_laser_cooldown_on_exit(null, null),
		"Exiting laser should not start cooldown when spawner already cleared active ref"
	)
	var fake_active := LaserDroneScript.new()
	_fail_unless(
		EnemyStreamSpawnerScript.should_start_laser_cooldown_on_exit(fake_active, fake_active),
		"Despawned active laser should start respawn cooldown"
	)
	fake_active.free()
	_verify_singleton_spawn_plan_deferral()


func _verify_singleton_spawn_plan_deferral() -> void:
	var plan: Array = [
		EnemyStreamSpawnerScript.DroneSpawnSlot.new(
			EnemyStreamSpawnerScript.DroneType.LASER, 0.2
		),
		EnemyStreamSpawnerScript.DroneSpawnSlot.new(
			EnemyStreamSpawnerScript.DroneType.MISSILE, 0.5
		),
	]
	var late_x := _player_x_at_segment_progress(8, 0.6)
	var blocked := EnemyStreamSpawnerScript.collect_due_drone_spawns(
		plan, 0, [], late_x, 8, 0.0, true, false
	)
	_fail_unless(int(blocked.cursor) == 2, "Blocked singleton slot should advance the plan cursor")
	_fail_unless(blocked.pending.size() == 1, "Blocked laser slot should be deferred")
	_fail_unless(blocked.spawns.size() == 1, "Missile slot should still spawn on schedule")
	var missile_slot: EnemyStreamSpawnerScript.DroneSpawnSlot = blocked.spawns[0]
	_fail_unless(
		missile_slot.drone_type == EnemyStreamSpawnerScript.DroneType.MISSILE,
		"Deferred laser should not block later missile spawns"
	)

	var early_x := _player_x_at_segment_progress(8, 0.3)
	var ready := EnemyStreamSpawnerScript.collect_due_drone_spawns(
		plan, 0, [], early_x, 8, 0.0, false, false
	)
	_fail_unless(int(ready.cursor) == 1, "Progress gate should stop before the missile threshold")
	_fail_unless(ready.pending.is_empty(), "Ready laser slot should not be deferred")
	_fail_unless(ready.spawns.size() == 1, "Only the first due slot should spawn early")

	var deferred_laser: EnemyStreamSpawnerScript.DroneSpawnSlot = blocked.pending[0]
	var flushed := EnemyStreamSpawnerScript.collect_due_drone_spawns(
		plan, 2, [deferred_laser], late_x, 8, 0.0, false, false
	)
	_fail_unless(flushed.pending.is_empty(), "Deferred laser should clear once singleton is free")
	_fail_unless(flushed.spawns.size() == 1, "Deferred laser should spawn when singleton frees")
	_fail_unless(
		(flushed.spawns[0] as EnemyStreamSpawnerScript.DroneSpawnSlot).drone_type
		== EnemyStreamSpawnerScript.DroneType.LASER,
		"Deferred singleton slot should keep its original type"
	)
	_verify_level_change_clears_pending_singletons()


func _verify_level_change_clears_pending_singletons() -> void:
	var leftover: EnemyStreamSpawnerScript.DroneSpawnSlot = (
		EnemyStreamSpawnerScript.DroneSpawnSlot.new(
			EnemyStreamSpawnerScript.DroneType.LASER, 0.95
		)
	)
	var new_plan: Array = [
		EnemyStreamSpawnerScript.DroneSpawnSlot.new(
			EnemyStreamSpawnerScript.DroneType.MISSILE, 0.5
		),
	]
	var early_x := _player_x_at_segment_progress(6, 0.1)
	var stale := EnemyStreamSpawnerScript.collect_due_drone_spawns(
		new_plan, 0, [leftover], early_x, 6, 0.0, false, false
	)
	_fail_unless(
		stale.spawns.size() == 1,
		"Uncleared pending singletons flush immediately once the singleton is free"
	)
	_fail_unless(
		(stale.spawns[0] as EnemyStreamSpawnerScript.DroneSpawnSlot).drone_type
		== EnemyStreamSpawnerScript.DroneType.LASER,
		"Stale pending slots keep their original drone type"
	)

	var fresh := EnemyStreamSpawnerScript.collect_due_drone_spawns(
		new_plan, 0, [], early_x, 6, 0.0, false, false
	)
	_fail_unless(
		fresh.spawns.is_empty() and fresh.pending.is_empty(),
		"Level transitions must clear pending singletons before rebuilding the plan"
	)


func _player_x_at_segment_progress(level: int, progress: float) -> float:
	var bounds := LevelRunScript.segment_east_west_x(level)
	var span := bounds.x - bounds.y
	return bounds.x - clampf(progress, 0.0, 1.0) * span


func _verify_missile_hail() -> void:
	_fail_unless(MissileDroneScript.ROCKET_COUNT_MIN == 30, "Hail min should be 30")
	_fail_unless(MissileDroneScript.ROCKET_COUNT_MAX == 40, "Hail max should be 40")
	_fail_unless(
		is_equal_approx(MissileDroneScript.STAGGER_SEC, 0.1),
		"Rocket stagger should be 0.1 s"
	)
	_fail_unless(DroneRocketScript.DAMAGE == 10, "Drone rocket should deal 10")
	_fail_unless(MissileDroneScript.ROCKET_DAMAGE == 10, "Missile drone damage alias should be 10")
	_fail_unless(
		is_equal_approx(
			MissileDroneScript.FALL_TELEGRAPH_SEC,
			DroneRocketScript.STRAIGHT_SEC + DroneRocketScript.FLIGHT_SEC
		),
		"Reticle lifetime should match rocket flight time"
	)
	_fail_unless(
		is_equal_approx(
			MissileDroneScript.LEAD_SEC,
			DroneRocketScript.STRAIGHT_SEC + DroneRocketScript.FLIGHT_SEC
		),
		"Lead time should match rocket flight time"
	)
	var origin := Vector3(-40.0, 8.0, 0.0)
	var impact := Vector3(0.0, 2.0, 5.0)
	_fail_unless(
		DroneRocketScript.arc_position(origin, impact, 0.0).is_equal_approx(origin),
		"Arc should start at origin"
	)
	_fail_unless(
		DroneRocketScript.arc_position(origin, impact, 1.0).is_equal_approx(impact),
		"Arc should end at impact"
	)
	var rocket: DroneRocket = DroneRocketScript.new()
	root.add_child(rocket)
	rocket.launch_from_drone(origin, impact)
	_fail_unless(rocket.uses_drone_missile_visual(), "Drone rocket should attach a projectile visual")
	var projectile_visual := rocket.get_node("ProjectileVisual").get_child(0)
	var streak := projectile_visual.find_child("Streak", true, false)
	_fail_unless(streak != null and streak is MeshInstance3D, "Drone rocket should include a Streak mesh")
	var launch_basis := rocket.global_transform.basis
	var launch_pos := rocket.global_position
	var step := 1.0 / 60.0
	var launch_dir: Vector3 = rocket.get("_dir")
	_fail_unless(
		-rocket.global_transform.basis.z.dot(launch_dir) > 0.99,
		"Rocket root should face the tube axis at launch"
	)
	_fail_unless(
		launch_dir.dot(Vector3.FORWARD) > 0.99,
		"Straight launch should go out the front (-Z), not the tail"
	)
	_fail_unless(
		is_equal_approx(float(rocket.get("_straight_left")), DroneRocketScript.STRAIGHT_SEC),
		"Rocket should start with a 0.3 s straight phase"
	)
	_fail_unless(
		is_equal_approx(DroneRocketScript.XFADE_SEC, 0.8),
		"Homing xfade should last 0.8 s"
	)
	var elapsed := 0.0
	var straight_checked := false
	while elapsed + step * 0.5 < DroneRocketScript.STRAIGHT_SEC:
		rocket._physics_process(step)
		elapsed += step
		_fail_unless(
			rocket.global_transform.basis.is_equal_approx(launch_basis),
			"Rocket should hold launch orientation during the straight phase"
		)
		_fail_unless(
			is_equal_approx(float(rocket.get("_flight_t")), 0.0),
			"Arc flight should not start during the straight phase"
		)
		straight_checked = true
	_fail_unless(straight_checked, "Rocket should spend time in the straight phase")
	_fail_unless(
		rocket.global_position.distance_to(launch_pos) > 0.01,
		"Rocket should travel straight out of the tube before homing"
	)
	_fail_unless(
		(rocket.global_position - launch_pos).normalized().dot(launch_dir) > 0.99,
		"Straight-phase travel should follow the tube axis"
	)
	var xfade_first := false
	var xfade_finished := false
	var mid_checked := false
	var total_flight := DroneRocketScript.STRAIGHT_SEC + DroneRocketScript.FLIGHT_SEC
	while elapsed < total_flight + step and not bool(rocket.get("_spent")):
		var xfade_before := float(rocket.get("_xfade_left"))
		rocket._physics_process(step)
		elapsed += step
		var xfade_after := float(rocket.get("_xfade_left"))
		if not xfade_first and xfade_after > 0.0 and xfade_after < DroneRocketScript.XFADE_SEC:
			xfade_first = true
			_fail_unless(
				(rocket.get("_dir") as Vector3).dot(launch_dir) > 0.7,
				"First xfade frames should still mostly face the launch direction"
			)
		if not xfade_finished and xfade_before > 0.0 and xfade_after <= 0.0:
			xfade_finished = true
			_fail_unless(
				not rocket.global_transform.basis.is_equal_approx(launch_basis),
				"Rocket should have turned by the end of the homing xfade"
			)
		if not mid_checked and float(rocket.get("_flight_t")) >= 0.5:
			mid_checked = true
			_fail_unless(
				not rocket.global_transform.basis.is_equal_approx(launch_basis),
				"Rocket should bank along arc after the straight phase"
			)
			var travel_dir: Vector3 = rocket.get("_dir")
			_fail_unless(
				-rocket.global_transform.basis.z.dot(travel_dir) > 0.99,
				"Rocket should face velocity mid-flight"
			)
	_fail_unless(xfade_first, "Rocket should crossfade into tracking")
	_fail_unless(xfade_finished, "Rocket should finish the homing xfade before impact")
	_fail_unless(mid_checked, "Rocket should reach mid-flight before detonation")
	_fail_unless(
		absf(elapsed - total_flight) <= step * 2.0,
		"Rocket should detonate after straight phase plus one flight duration"
	)
	_fail_unless(bool(rocket.get("_spent")), "Rocket should detonate at end of flight")
	rocket.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var count := rng.randi_range(MissileDroneScript.ROCKET_COUNT_MIN, MissileDroneScript.ROCKET_COUNT_MAX)
	_fail_unless(count >= 30 and count <= 40, "Random hail count should stay in 30-40")
	var points := MissileDroneScript.impact_points_around(
		Vector3.ZERO,
		35,
		MissileDroneScript.SPREAD_RADIUS_GROUND_M,
		rng
	)
	_fail_unless(points.size() == 35, "Should generate requested impact points")
	var offsets := MissileDroneScript.impact_offsets_around(
		35,
		MissileDroneScript.SPREAD_RADIUS_GROUND_M,
		rng
	)
	_fail_unless(offsets.size() == 35, "Should generate spread offsets")
	var air_offsets := MissileDroneScript.air_impact_offsets_around(35, MissileDroneScript.SPREAD_RADIUS_AIR_M, rng)
	_fail_unless(air_offsets.size() == 35, "Should generate air spread offsets")
	for air_off in air_offsets:
		var flat := Vector3(air_off.x, 0.0, air_off.z)
		_fail_unless(
			flat.length() <= MissileDroneScript.SPREAD_RADIUS_AIR_M + 0.02,
			"Air offsets should stay within air spread radius"
		)
		_fail_unless(
			absf(air_off.y) <= MissileDroneScript.SPREAD_RADIUS_AIR_M * 0.5 + 0.02,
			"Air offsets should keep vertical jitter within band"
		)
	var player_still := CharacterBody3D.new()
	root.add_child(player_still)
	player_still.velocity = Vector3.ZERO
	player_still.global_position = Vector3(12.0, 0.0, -7.0)
	var still_drone: MissileDrone = MissileDroneScript.new()
	root.add_child(still_drone)
	still_drone.configure(null, player_still, 15.0)
	var lead_still: Vector3 = still_drone._lead_point()
	_fail_unless(
		Vector2(lead_still.x, lead_still.z).distance_to(
			Vector2(player_still.global_position.x, player_still.global_position.z)
		) < 0.01,
		"Stationary player lead should stay on player XZ"
	)
	still_drone.queue_free()
	player_still.queue_free()
	var player_track := CharacterBody3D.new()
	root.add_child(player_track)
	player_track.velocity = Vector3(18.0, 0.0, 0.0)
	var track_drone: MissileDrone = MissileDroneScript.new()
	root.add_child(track_drone)
	track_drone.configure(null, player_track, 15.0)
	player_track.global_position = Vector3.ZERO
	var lead_a: Vector3 = track_drone._lead_point()
	var expected_a := player_track.global_position + Vector3(
		player_track.velocity.x, 0.0, player_track.velocity.z
	) * MissileDroneScript.LEAD_SEC
	_fail_unless(
		Vector2(lead_a.x, lead_a.z).distance_to(Vector2(expected_a.x, expected_a.z)) < 0.01,
		"Moving player lead should follow straight-line velocity extrapolation"
	)
	player_track.global_position = Vector3(40.0, 0.0, 0.0)
	var lead_b: Vector3 = track_drone._lead_point()
	var expected_b := player_track.global_position + Vector3(
		player_track.velocity.x, 0.0, player_track.velocity.z
	) * MissileDroneScript.LEAD_SEC
	_fail_unless(
		Vector2(lead_b.x, lead_b.z).distance_to(Vector2(expected_b.x, expected_b.z)) < 0.01,
		"Lead should refresh from current player position and velocity"
	)
	_fail_unless(lead_b.x > lead_a.x + 30.0, "Each rocket should use a fresh lead on the moving player")
	track_drone.queue_free()
	player_track.queue_free()
	var max_r := 0.0
	for p in points:
		max_r = maxf(max_r, Vector2(p.x, p.z).length())
	_fail_unless(
		max_r <= MissileDroneScript.SPREAD_RADIUS_GROUND_M + 0.01,
		"Impact points should stay within spread radius"
	)
	_fail_unless(
		max_r >= MissileDroneScript.SPREAD_RADIUS_GROUND_M * 0.35,
		"Impacts should reach outer band of the spread"
	)
	var reticle: GroundReticle = GroundReticleScript.new()
	root.add_child(reticle)
	reticle.place(Vector3(1.0, 2.0, 3.0), 0.5)
	_fail_unless(is_instance_valid(reticle), "Ground reticle should spawn")
	reticle.queue_free()
	_verify_missile_muzzle_slots()
	_verify_missile_aim_facing()


func _verify_missile_muzzle_slots() -> void:
	var missile: MissileDrone = MissileDroneScene.instantiate() as MissileDrone
	root.add_child(missile)
	var visual := missile.get_node_or_null("Visual") as Node3D
	_fail_unless(visual != null, "Missile drone should have Visual")
	var origins: Array[Vector3] = []
	for i in MissileDroneScript.SPAWN_SLOT_COUNT:
		var slot: Node3D = missile._get_spawn_slot(i)
		var expected_name := "Missile %d" % (i + 1)
		_fail_unless(slot != null, "Missile drone should have %s muzzle" % expected_name)
		_fail_unless(
			slot.name == expected_name,
			"Spawn slot %d should resolve to %s" % [i, expected_name]
		)
		_fail_unless(
			visual.is_ancestor_of(slot),
			"%s should live under Visual so it stays in the launcher barrel" % expected_name
		)
		origins.append(slot.global_position)
	for i in origins.size():
		for j in range(i + 1, origins.size()):
			_fail_unless(
				origins[i].distance_to(origins[j]) > 0.01,
				"Missile muzzle origins should be distinct (%d vs %d)" % [i + 1, j + 1]
			)
	var slot0: Node3D = missile._get_spawn_slot(0)
	var rocket: DroneRocket = DroneRocketScript.new()
	root.add_child(rocket)
	rocket.launch_from_drone(
		slot0.global_position,
		slot0.global_position + Vector3(10.0, 0.0, 0.0),
		null,
		slot0.global_transform
	)
	_fail_unless(
		rocket.global_position.is_equal_approx(slot0.global_position),
		"Rocket should spawn at Missile 1 barrel"
	)
	var barrel_forward := slot0.global_transform.basis.z.normalized()
	_fail_unless(
		(rocket.get("_dir") as Vector3).dot(barrel_forward) > 0.99,
		"Rocket should leave along the barrel axis"
	)
	rocket.queue_free()
	missile.queue_free()


func _verify_missile_aim_facing() -> void:
	var player := CharacterBody3D.new()
	root.add_child(player)
	player.global_position = Vector3(0.0, 0.0, 20.0)
	player.velocity = Vector3.ZERO
	var missile: MissileDrone = MissileDroneScript.new()
	root.add_child(missile)
	missile.configure(null, player, 15.0)
	missile.global_position = Vector3(0.0, 8.0, 0.0)
	missile.set("_flight_heading", Vector3(-1.0, 0.0, 0.0))
	missile.set("_firing_hail", false)
	missile._face_heading(1.0)
	var nose := _xz_nose(missile)
	_fail_unless(
		nose.dot(Vector3(-1.0, 0.0, 0.0)) > 0.99,
		"Idle missile drone should face flight heading"
	)

	missile.set("_firing_hail", true)
	missile._begin_aim_face_xfade()
	missile._face_heading(0.016)
	nose = _xz_nose(missile)
	_fail_unless(
		nose.dot(Vector3(-1.0, 0.0, 0.0)) > 0.7,
		"Hail start should xfade facing instead of snapping to the lead"
	)
	missile._face_heading(MissileDroneScript.AIM_FACE_XFADE_SEC)
	var lead: Vector3 = missile._lead_point()
	var to_lead := Vector3(
		lead.x - missile.global_position.x,
		0.0,
		lead.z - missile.global_position.z
	).normalized()
	nose = _xz_nose(missile)
	_fail_unless(nose.dot(to_lead) > 0.99, "Firing missile drone should face the lead point after xfade")
	_fail_unless(
		nose.dot(Vector3(-1.0, 0.0, 0.0)) < 0.5,
		"Firing facing should leave the kite heading"
	)
	missile.queue_free()
	player.queue_free()


func _xz_nose(node: Node3D) -> Vector3:
	var nose := Vector3(-node.global_transform.basis.z.x, 0.0, -node.global_transform.basis.z.z)
	if nose.length_squared() < 0.0001:
		return Vector3.ZERO
	return nose.normalized()


func _verify_machine_gun_drone() -> void:
	_fail_unless(
		is_equal_approx(MachineGunDroneScript.CHARGE_TRIGGER_M, 100.0),
		"MG drone should charge within 100 m"
	)
	_fail_unless(
		is_equal_approx(MachineGunDroneScript.MG_FIRE_INTERVAL_SEC, 0.05),
		"MG fire interval should be 0.05 s"
	)
	_fail_unless(MachineGunDroneScript.PASS_DAMAGE == 15, "MG pass-by damage should be 15")
	_fail_unless(
		MachineGunDroneScript.should_begin_charge(100.0),
		"MG drone should begin charge at 100 m ahead on lane"
	)
	_fail_unless(
		not MachineGunDroneScript.should_begin_charge(100.1),
		"MG drone should stay aligned beyond 100 m ahead"
	)

	var facing := Vector3(-1.0, 0.0, 0.0)
	var player := Vector3(0.0, 0.0, 0.0)
	var drone_west := Vector3(-400.0, 0.0, 20.0)
	_fail_unless(
		is_equal_approx(MachineGunDroneScript.lateral_offset_m(drone_west, player, facing), 20.0),
		"Positive lateral offset should read +20 m"
	)
	var pass_heading := MachineGunDroneScript.lane_pass_heading(
		drone_west, Vector3(-150.0, 0.0, 0.0), facing
	)
	_fail_unless(
		pass_heading.x > 0.9 and absf(pass_heading.z) < 0.1,
		"Lane pass heading should run east through the player when aligned"
	)
	var mirrored := MachineGunDroneScript.mirror_align_position(
		Vector3(-400.0, 8.0, 20.0),
		Vector3(0.0, 4.0, -35.0),
		-400.0
	)
	_fail_unless(
		is_equal_approx(mirrored.x, -400.0),
		"Align mirror should keep spawn X locked"
	)
	_fail_unless(
		is_equal_approx(mirrored.z, -35.0),
		"Align mirror should copy player world Z exactly"
	)
	_fail_unless(
		is_equal_approx(mirrored.y, 8.0),
		"Align mirror should leave height to cruise snap"
	)
	_fail_unless(
		is_equal_approx(MachineGunDroneScript.westbound_ahead_m(-400.0, -300.0), 100.0),
		"Westbound ahead should use world X separation"
	)
	_fail_unless(
		MachineGunDroneScript.charge_heading_xz(
			Vector3(-400.0, 0.0, -80.0),
			Vector3(-250.0, 0.0, -80.0)
		).is_equal_approx(Vector3(1.0, 0.0, 0.0)),
		"Charge should run along X while Z stays mirrored"
	)

	var start_heading := Vector3(-1.0, 0.0, 0.0)
	var turn_target := Vector3(0.0, 0.0, -1.0)
	var turned := CombatDroneScript.rotate_heading_toward(
		start_heading, turn_target, MachineGunDroneScript.CHARGE_TURN_RATE_DEG, 1.0
	)
	var turned_deg := rad_to_deg(acos(clampf(start_heading.dot(turned), -1.0, 1.0)))
	_fail_unless(
		turned_deg <= MachineGunDroneScript.CHARGE_TURN_RATE_DEG + 0.01,
		"MG charge turn rate should cap per second"
	)

	_fail_unless(
		MachineGunDroneScript.player_in_pass_hitbox(Vector3(0.4, 0.0, 0.0), Vector3.ZERO),
		"Pass damage should require overlap with the drone cube on XZ"
	)
	_fail_unless(
		MachineGunDroneScript.player_in_pass_hitbox(Vector3(0.0, 8.0, 0.0), Vector3(0.0, 1.0, 0.0)),
		"Pass damage should hit when the drone passes overhead above the player"
	)
	_fail_unless(
		not MachineGunDroneScript.player_in_pass_hitbox(
			Vector3(10.0, 0.0, 0.0), Vector3(0.0, 0.0, 5.0)
		),
		"Pass damage should not hit a wide Z miss"
	)

	var mg = MachineGunDroneScript.new()
	root.add_child(mg)
	_fail_unless(mg.invulnerable, "MG drone should spawn invulnerable")
	_fail_unless(not mg.take_damage(999), "Invulnerable MG drone should ignore damage")

	var rig := Node3D.new()
	root.add_child(rig)
	var player_body := CharacterBody3D.new()
	rig.add_child(player_body)
	player_body.global_position = Vector3.ZERO
	var health := PlayerHealthScript.new()
	rig.add_child(health)
	mg.configure(null, player_body, 15.0)
	mg.set("_phase", MachineGunDroneScript.FlyPhase.CHARGE)
	mg.set("_charge_heading", Vector3(1.0, 0.0, 0.0))
	mg.global_position = Vector3(-0.4, 0.0, 0.0)
	mg._try_pass_damage()
	_fail_unless(bool(mg.get("_pass_damage_dealt")), "Pass damage should hit when cube overlaps player")
	_fail_unless(health.get_current() == 35, "Pass-by should deal 15 damage once")
	mg.set("_pass_damage_dealt", false)
	health.reset_full()
	mg.global_position = Vector3(10.0, 0.0, 0.0)
	player_body.global_position = Vector3(0.0, 0.0, 5.0)
	mg._try_pass_damage()
	_fail_unless(not bool(mg.get("_pass_damage_dealt")), "Wide miss should not deal pass damage")
	_fail_unless(health.get_current() == 50, "Wide miss should deal no pass damage")
	mg._check_pass_transition()
	_fail_unless(
		int(mg.get("_phase")) == MachineGunDroneScript.FlyPhase.EXIT,
		"Drone should still exit after passing player on X"
	)
	mg.set("_phase", MachineGunDroneScript.FlyPhase.CHARGE)
	mg.set("_pass_damage_dealt", false)
	health.reset_full()
	mg.global_position = Vector3(-0.4, 8.0, 0.0)
	player_body.global_position = Vector3(0.0, 1.0, 0.0)
	mg._try_pass_damage()
	_fail_unless(
		bool(mg.get("_pass_damage_dealt")),
		"Overhead pass should deal damage when aligned on XZ"
	)
	_fail_unless(health.get_current() == 35, "Overhead pass should deal 15 damage once")
	mg.free()
	rig.free()

	var plan_rng := RandomNumberGenerator.new()
	plan_rng.seed = 424242
	var mg_count := 0
	var laser_count := 0
	var missile_count := 0
	for level in range(5, 13):
		var plan := EnemyStreamSpawnerScript.build_drone_spawn_plan(level, plan_rng)
		mg_count += EnemyStreamSpawnerScript.count_drone_type_slots(
			plan, EnemyStreamSpawnerScript.DroneType.MACHINE_GUN
		)
		laser_count += EnemyStreamSpawnerScript.count_laser_slots(plan)
		missile_count += EnemyStreamSpawnerScript.count_drone_type_slots(
			plan, EnemyStreamSpawnerScript.DroneType.MISSILE
		)
	var total := mg_count + laser_count + missile_count
	_fail_unless(total > 0, "Spawn plan should include drones")
	_fail_unless(mg_count > 0, "Spawn plan should include MG drones")
	_fail_unless(laser_count > 0, "Spawn plan should include laser drones")
	_fail_unless(missile_count > 0, "Spawn plan should include missile drones")
	var mg_share := float(mg_count) / float(total)
	_fail_unless(
		mg_share > 0.2 and mg_share < 0.45,
		"MG drones should roll near one third of slots"
	)

	var invuln: CombatDrone = MachineGunDroneScript.new()
	root.add_child(invuln)
	invuln.global_position = Vector3(-12.0, 0.0, 0.0)
	var candidates := AutoRifleScript.collect_candidates(
		[invuln], Vector3.ZERO, Vector3(-1.0, 0.0, 0.0), 40.0
	)
	_fail_unless(candidates.is_empty(), "Invulnerable drones should be skipped by weapon targeting")
	invuln.free()


func _verify_flight_heading_inertia() -> void:
	var start_heading := Vector3(-1.0, 0.0, 0.0)
	var turn_target := Vector3(0.0, 0.0, -1.0)
	var turned := CombatDroneScript.rotate_heading_toward(
		start_heading,
		turn_target,
		CombatDroneScript.FLIGHT_TURN_RATE_DEG,
		1.0
	)
	var turned_deg := rad_to_deg(acos(clampf(start_heading.dot(turned), -1.0, 1.0)))
	_fail_unless(
		turned_deg <= CombatDroneScript.FLIGHT_TURN_RATE_DEG + 0.01,
		"Flight turn rate should cap per second"
	)

	var target := Node3D.new()
	root.add_child(target)
	target.global_position = Vector3(0.0, 0.0, 200.0)

	var laser: LaserDrone = LaserDroneScript.new()
	root.add_child(laser)
	laser.global_position = Vector3(0.0, 8.0, 0.0)
	laser.configure(null, target)
	laser.set("_flight_heading", Vector3(1.0, 0.0, 0.0))

	var desired := laser.desired_velocity_xz()
	_fail_unless(desired.length_squared() > 0.0001, "Laser acquire steer test needs non-zero desired velocity")
	_fail_unless(
		LaserDroneScript.movement_zone_for_distance(laser.xz_distance_to_target()) == "acquire",
		"Heading inertia test should use acquire movement zone"
	)
	var desired_dir := desired.normalized()

	laser._steer(0.05)
	var vel_xz := Vector3(laser.velocity.x, 0.0, laser.velocity.z)
	_fail_unless(vel_xz.length_squared() > 0.0001, "Steer step should produce XZ velocity")
	var vel_dir := vel_xz.normalized()
	_fail_unless(
		vel_dir.dot(desired_dir) < 0.99,
		"Velocity direction should lag desired heading during a turn"
	)

	var heading_after: Vector3 = laser.get("_flight_heading")
	var heading_turn_deg := rad_to_deg(acos(clampf(Vector3(1.0, 0.0, 0.0).dot(heading_after), -1.0, 1.0)))
	_fail_unless(
		heading_turn_deg <= CombatDroneScript.FLIGHT_TURN_RATE_DEG * 0.05 + 0.01,
		"Heading turn per step should respect flight turn rate (got %.3f deg)"
		% heading_turn_deg
	)

	for _i in 24:
		laser._steer(0.016)
		laser._face_heading(0.016)

	vel_xz = Vector3(laser.velocity.x, 0.0, laser.velocity.z)
	vel_dir = vel_xz.normalized()
	var face_fwd := -laser.global_transform.basis.z
	face_fwd.y = 0.0
	_fail_unless(
		face_fwd.normalized().dot(vel_dir) > 0.85,
		"Body facing should track flight heading after sustained steering"
	)

	laser.queue_free()
	target.queue_free()


func _verify_air_targeting() -> void:
	var drone: CombatDrone = CombatDroneScript.new()
	root.add_child(drone)
	drone.set("_airborne_time", 0.9)
	_fail_unless(not drone.uses_air_targeting(), "Air targeting should need 1.0 s airborne")
	drone.set("_airborne_time", 1.0)
	_fail_unless(drone.uses_air_targeting(), "Air targeting should activate at 1.0 s airborne")

	var stub := Node3D.new()
	var stub_script := GDScript.new()
	stub_script.source_code = """
extends Node3D
func is_gliding() -> bool:
	return true
"""
	stub_script.reload()
	stub.set_script(stub_script)
	root.add_child(stub)
	drone.configure(null, stub, 15.0)
	drone.set("_airborne_time", 2.0)
	drone.set("_grounded_time", 0.0)
	drone._tick_air_targeting(0.2)
	_fail_unless(
		is_equal_approx(drone.get("_airborne_time"), 2.2),
		"Gliding timer should keep accumulating while target glides"
	)
	drone.set("_airborne_time", 0.0)
	drone.set("_grounded_time", 0.0)
	drone._tick_air_targeting(1.0)
	_fail_unless(
		is_equal_approx(drone.get("_airborne_time"), 1.0),
		"Stub gliding target should accumulate airborne time"
	)
	var grounded_stub := Node3D.new()
	var grounded_script := GDScript.new()
	grounded_script.source_code = """
extends Node3D
func is_gliding() -> bool:
	return false
"""
	grounded_script.reload()
	grounded_stub.set_script(grounded_script)
	root.add_child(grounded_stub)
	drone.configure(null, grounded_stub, 15.0)
	drone.set("_airborne_time", 2.0)
	drone.set("_grounded_time", 0.0)
	drone._tick_air_targeting(CombatDroneScript.AIR_TARGETING_EXIT_SEC)
	_fail_unless(
		is_equal_approx(drone.get("_airborne_time"), 0.0),
		"Grounded grace should reset airborne timer"
	)
	grounded_stub.queue_free()
	stub.queue_free()
	drone.queue_free()

	var origin := Vector3(-40.0, 8.0, 0.0)
	var impact := Vector3(0.0, 12.0, 5.0)
	var miss_rocket: DroneRocket = DroneRocketScript.new()
	root.add_child(miss_rocket)
	miss_rocket.launch_to_air_point(origin, impact)
	var player := Node3D.new()
	root.add_child(player)
	player.global_position = Vector3(30.0, 12.0, 30.0)
	var elapsed := 0.0
	var step := 1.0 / 60.0
	var total_flight := DroneRocketScript.STRAIGHT_SEC + DroneRocketScript.FLIGHT_SEC
	while elapsed < total_flight + step and not bool(miss_rocket.get("_spent")):
		miss_rocket._physics_process(step)
		elapsed += step
	_fail_unless(not bool(miss_rocket.get("_spent")), "Air rocket should pass through on miss")
	_fail_unless(
		bool(miss_rocket.get("_pass_through")),
		"Air rocket should enter pass-through after missing impact"
	)
	var expected_pass_speed := float(miss_rocket.get("_flight_speed_mps"))
	_fail_unless(
		(miss_rocket.get("_pass_vel") as Vector3).length() >= expected_pass_speed - 0.01,
		"Missed air rocket should pass through at homing flight speed"
	)
	var pass_pos: Vector3 = miss_rocket.global_position
	miss_rocket._physics_process(step)
	_fail_unless(
		miss_rocket.global_position.distance_to(pass_pos) > 0.01,
		"Missed air rocket should keep flying past the player"
	)
	miss_rocket.queue_free()
	player.queue_free()

	var hit_rig := Node3D.new()
	var rig_script := GDScript.new()
	rig_script.source_code = """
extends Node3D
var _glider: Node3D
func set_glider(node: Node3D) -> void:
	_glider = node
func get_glider() -> Node3D:
	return _glider
"""
	rig_script.reload()
	hit_rig.set_script(rig_script)
	root.add_child(hit_rig)
	var hit_player := Node3D.new()
	hit_rig.add_child(hit_player)
	hit_rig.call("set_glider", hit_player)
	var hit_health: PlayerHealth = PlayerHealthScript.new()
	hit_rig.add_child(hit_health)
	hit_player.global_position = impact
	var before := hit_health.current
	var hit_rocket: DroneRocket = DroneRocketScript.new()
	root.add_child(hit_rocket)
	hit_rocket.launch_to_air_point(origin, impact)
	elapsed = 0.0
	while elapsed < total_flight + step and not bool(hit_rocket.get("_spent")):
		hit_rocket._physics_process(step)
		elapsed += step
	_fail_unless(bool(hit_rocket.get("_spent")), "Air rocket should detonate when player is in blast radius")
	_fail_unless(hit_health.current < before, "Air rocket should damage player on hit")
	hit_rocket.queue_free()
	hit_rig.queue_free()


func _verify_fire_gate() -> void:
	var player := Node3D.new()
	root.add_child(player)
	player.global_position = Vector3.ZERO
	var west := Vector3(-1.0, 0.0, 0.0)
	_fail_unless(
		AutoRifleScript.is_in_front(player.global_position, west, Vector3(-20.0, 0.0, 0.0)),
		"West of a westbound player should be in front"
	)
	_fail_unless(
		not AutoRifleScript.is_in_front(player.global_position, west, Vector3(20.0, 0.0, 0.0)),
		"East of a westbound player should not be in front"
	)
	var drone: CombatDrone = CombatDroneScript.new()
	root.add_child(drone)
	drone.configure(null, player, 15.0)
	drone.global_position = Vector3(-80.0, 8.0, 0.0)
	drone.fly_state = CombatDroneScript.FlyState.APPROACH
	_fail_unless(not drone.can_fire_weapons(), "Should not fire beyond 40 m weapon range")
	drone.global_position = Vector3(-30.0, 8.0, 0.0)
	drone.fly_state = CombatDroneScript.FlyState.KITE
	_fail_unless(drone.can_fire_weapons(), "In range + in front should allow fire")
	drone.global_position = Vector3(30.0, 8.0, 0.0)
	drone.fly_state = CombatDroneScript.FlyState.CATCH_UP
	_fail_unless(drone.can_fire_weapons(), "Should still fire within 40 m after player passes")
	drone.global_position = Vector3(45.0, 8.0, 0.0)
	_fail_unless(not drone.can_fire_weapons(), "Should not fire beyond 40 m weapon range")
	drone.queue_free()
	player.queue_free()


func _verify_smoke_ai() -> void:
	var player := Node3D.new()
	root.add_child(player)
	player.global_position = Vector3.ZERO

	var health: PlayerHealth = PlayerHealthScript.new()
	root.add_child(health)

	var laser: LaserDrone = LaserDroneScript.new()
	root.add_child(laser)
	laser.configure(null, player, 15.0)
	laser.global_position = Vector3(-50.0, 8.0, 0.0)
	for _i in 5:
		laser._physics_process(0.05)
	_fail_unless(laser.is_alive(), "Laser drone should stay alive during smoke AI")
	_fail_unless(laser.get_health() == 15, "Laser drone should start at 15 HP")

	var missile: MissileDrone = MissileDroneScript.new()
	root.add_child(missile)
	missile.configure(null, player, 15.0)
	missile.global_position = Vector3(-35.0, 8.0, 0.0)
	missile.fly_state = CombatDroneScript.FlyState.KITE
	missile.set("_cooldown_left", 0.0)
	missile._update_weapons(0.016)
	_fail_unless(missile.is_alive(), "Missile drone should stay alive after hail attempt")
	_fail_unless(bool(missile.get("_firing_hail")), "Hail should start staggered firing")

	laser.queue_free()
	missile.queue_free()
	health.queue_free()
	player.queue_free()


func _verify_drone_death_debris() -> void:
	var container := Node3D.new()
	root.add_child(container)
	var visual: Node3D = LaserDroneSkinScene.instantiate() as Node3D
	container.add_child(visual)
	visual.global_position = Vector3(0.0, 8.0, 0.0)

	var streak_vfx := visual.get_node_or_null("Body") as DroneStreakVfxScript
	_fail_unless(streak_vfx != null, "Laser skin should have DroneStreakVfx on Body")
	streak_vfx.prepare_for_death()

	var wrapper := DroneDeathBurstScript.spawn(
		self,
		visual.global_transform,
		visual,
		Vector3.ZERO,
		null
	)
	await process_frame
	_fail_unless(wrapper != null, "DroneDeathBurst.spawn should return a wrapper")
	_fail_unless(
		wrapper.get_debris_bodies().size() == 2,
		"Drone death debris should spawn body and weapon rigid bodies (got %d)"
		% wrapper.get_debris_bodies().size()
	)

	var body_rigid: RigidBody3D = null
	for rb in wrapper.get_debris_bodies():
		if rb.find_child("ThrusterStreaks", true, false) != null:
			body_rigid = rb
			break
	_fail_unless(body_rigid != null, "Body debris should reparent ThrusterStreaks intact")

	for child in body_rigid.get_children():
		if child is MeshInstance3D and child.name.begins_with("Streak"):
			_fail_unless(
				false,
				"Debris should not flatten streak meshes as %s" % child.name
			)

	var thruster_streaks := body_rigid.get_node("ThrusterStreaks") as Node3D
	var debris_vfx: DroneDebrisThrusterVfxScript = null
	for child in body_rigid.get_children():
		if child is DroneDebrisThrusterVfxScript:
			debris_vfx = child
			break
	_fail_unless(debris_vfx != null, "Body debris should have DroneDebrisThrusterVfx attached")
	_fail_unless(thruster_streaks.visible, "Thrusters should stay on before ground hit")

	var terrain := StaticBody3D.new()
	var terrain_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	terrain_col.shape = box
	terrain.add_child(terrain_col)
	root.add_child(terrain)
	body_rigid.linear_velocity = Vector3(5.0, -2.0, 0.0)
	body_rigid.body_entered.emit(terrain)
	var flicker_wait := DroneDebrisThrusterVfxScript.FLICKER_COUNT * (
		DroneDebrisThrusterVfxScript.FLICKER_ON_SEC
		+ DroneDebrisThrusterVfxScript.FLICKER_OFF_SEC
	) + 0.05
	await create_timer(flicker_wait).timeout
	_fail_unless(not thruster_streaks.visible, "Thrusters should be off after ground-hit flicker")

	terrain.queue_free()
	wrapper.queue_free()
	visual.queue_free()
	container.queue_free()


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
	quit(1)
