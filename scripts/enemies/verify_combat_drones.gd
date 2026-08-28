extends SceneTree

const CombatDroneScript = preload("res://scripts/enemies/combat_drone.gd")
const LaserDroneScript = preload("res://scripts/enemies/laser_drone.gd")
const MissileDroneScript = preload("res://scripts/enemies/missile_drone.gd")
const DroneLaserBeamScript = preload("res://scripts/enemies/drone_laser_beam.gd")
const DroneRocketScript = preload("res://scripts/enemies/drone_rocket.gd")
const GroundReticleScript = preload("res://scripts/enemies/ground_reticle.gd")
const EnemyStreamSpawnerScript = preload("res://scripts/enemies/enemy_stream_spawner.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const PlayerHealthScript = preload("res://scripts/player/player_health.gd")
const LevelRunScript = preload("res://scripts/game/level_run.gd")

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
	_verify_laser_timings()
	if _failed:
		return
	_verify_missile_hail()
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
	print("Combat drone verification passed.")
	quit(0)


func _verify_cap_and_speed() -> void:
	_fail_unless(CombatDroneScript.DRONE_MIN_LEVEL == 5, "Drones unlock at level 5")
	_fail_unless(EnemyStreamSpawnerScript.DRONE_MIN_LEVEL == 5, "Spawner drone min level should be 5")
	_fail_unless(CombatDroneScript.drone_cap_for_level(4) == 0, "Level 4 should have 0 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(5) == 3, "Level 5 should have ceil(5/2)=3 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(6) == 3, "Level 6 should have ceil(6/2)=3 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(7) == 4, "Level 7 should have ceil(7/2)=4 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(10) == 5, "Level 10 should have ceil(10/2)=5 drones")
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


func _verify_laser_timings() -> void:
	_fail_unless(is_equal_approx(DroneLaserBeamScript.FIRE_SEC, 5.0), "Laser fire should be 5 s")
	_fail_unless(is_equal_approx(DroneLaserBeamScript.RELOAD_SEC, 5.0), "Laser reload should be 5 s")
	_fail_unless(is_equal_approx(DroneLaserBeamScript.TICK_SEC, 0.5), "Laser tick should be 0.5 s")
	_fail_unless(DroneLaserBeamScript.DAMAGE == 4, "Laser tick damage should be 4")
	_fail_unless(is_equal_approx(LaserDroneScript.FIRE_SEC, 5.0), "LaserDrone fire alias should be 5 s")
	_fail_unless(
		is_equal_approx(GliderPhysicsScript.CRUISE_MAX_GROUND_SPEED, 22.0 * 0.95),
		"Laser sweep should track cruise ground speed"
	)
	var player := Node3D.new()
	root.add_child(player)
	player.global_position = Vector3.ZERO
	var beam = DroneLaserBeamScript.new()
	root.add_child(beam)
	beam.begin(Vector3(-80.0, 8.0, 0.0), player, Vector3(-1.0, 0.0, 0.0), null, true)
	_fail_unless(beam.zigzagging, "First approach beam should start in zigzag mode")
	beam.queue_free()
	var beam2 = DroneLaserBeamScript.new()
	root.add_child(beam2)
	beam2.begin(Vector3(-80.0, 8.0, 0.0), player, Vector3(-1.0, 0.0, 0.0), null, false)
	_fail_unless(not beam2.zigzagging, "Later beams should skip zigzag")
	beam2.queue_free()
	player.queue_free()


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
		is_equal_approx(MissileDroneScript.FALL_TELEGRAPH_SEC, DroneRocketScript.FLIGHT_SEC),
		"Reticle lifetime should match rocket flight time"
	)
	_fail_unless(
		is_equal_approx(MissileDroneScript.LEAD_SEC, DroneRocketScript.FLIGHT_SEC),
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
	var elapsed := 0.0
	var step := 1.0 / 60.0
	while elapsed < DroneRocketScript.FLIGHT_SEC + step and not bool(rocket.get("_spent")):
		rocket._physics_process(step)
		elapsed += step
	_fail_unless(
		absf(elapsed - DroneRocketScript.FLIGHT_SEC) <= step * 2.0,
		"Rocket should detonate after one flight duration"
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
	var player_track := CharacterBody3D.new()
	root.add_child(player_track)
	player_track.velocity = Vector3(18.0, 0.0, 0.0)
	var track_drone: MissileDrone = MissileDroneScript.new()
	root.add_child(track_drone)
	track_drone.configure(null, player_track, 15.0)
	player_track.global_position = Vector3.ZERO
	var lead_a: Vector3 = track_drone._lead_point()
	player_track.global_position = Vector3(40.0, 0.0, 0.0)
	var lead_b: Vector3 = track_drone._lead_point()
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
	while elapsed < DroneRocketScript.FLIGHT_SEC + step and not bool(miss_rocket.get("_spent")):
		miss_rocket._physics_process(step)
		elapsed += step
	_fail_unless(not bool(miss_rocket.get("_spent")), "Air rocket should pass through on miss")
	_fail_unless(
		bool(miss_rocket.get("_pass_through")),
		"Air rocket should enter pass-through after missing impact"
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
	while elapsed < DroneRocketScript.FLIGHT_SEC + step and not bool(hit_rocket.get("_spent")):
		hit_rocket._physics_process(step)
		elapsed += step
	_fail_unless(bool(hit_rocket.get("_spent")), "Air rocket should detonate when player is in blast radius")
	_fail_unless(hit_health.current < before, "Air rocket should damage player on hit")
	hit_rocket.queue_free()
	hit_rig.queue_free()

	var beam = DroneLaserBeamScript.new()
	root.add_child(beam)
	var laser_player := Node3D.new()
	root.add_child(laser_player)
	laser_player.global_position = Vector3(0.0, 10.0, 0.0)
	beam.begin(Vector3(-20.0, 8.0, 0.0), laser_player, Vector3(-1.0, 0.0, 0.0), null, false, true)
	_fail_unless(
		is_equal_approx(beam.get("_aim").y, 10.0),
		"Air laser should open at player height"
	)
	beam.queue_free()
	laser_player.queue_free()

	var lead_player := CharacterBody3D.new()
	root.add_child(lead_player)
	lead_player.global_position = Vector3.ZERO
	lead_player.velocity = Vector3(18.0, 0.0, 0.0)
	var lead_beam = DroneLaserBeamScript.new()
	root.add_child(lead_beam)
	var lead_goal: Vector3 = lead_beam._lead_goal_ground(lead_player, Vector3(-1.0, 0.0, 0.0))
	_fail_unless(lead_goal.x < -15.0, "Ground laser lead should be ahead of a westbound player")
	lead_beam.queue_free()
	lead_player.queue_free()

	var miss_beam = DroneLaserBeamScript.new()
	root.add_child(miss_beam)
	miss_beam.set("_aim", Vector3(0.0, 0.0, 0.0))
	var miss_origin := Vector3(-20.0, 8.0, 0.0)
	var miss_player := Node3D.new()
	root.add_child(miss_player)
	miss_player.global_position = Vector3(80.0, 0.0, 0.0)
	var far_end: Vector3 = miss_beam._visual_beam_end(miss_origin, miss_player, false)
	_fail_unless(
		is_equal_approx(miss_origin.distance_to(far_end), DroneLaserBeamScript.MISS_BEAM_RANGE_M),
		"Missed laser should extend to far beam range"
	)
	miss_beam.queue_free()
	miss_player.queue_free()

	var laser_hit_beam = DroneLaserBeamScript.new()
	root.add_child(laser_hit_beam)
	var hit_origin := Vector3(-20.0, 8.0, 0.0)
	var hit_aim := Vector3(0.0, 0.0, 0.0)
	laser_hit_beam.set("_aim", hit_aim)
	var laser_hit_player := Node3D.new()
	root.add_child(laser_hit_player)
	laser_hit_player.global_position = hit_aim
	var short_end: Vector3 = laser_hit_beam._visual_beam_end(hit_origin, laser_hit_player, false)
	_fail_unless(
		short_end.is_equal_approx(hit_aim),
		"On-target laser should end at the aim point"
	)
	_fail_unless(
		hit_origin.distance_to(short_end) < DroneLaserBeamScript.MISS_BEAM_RANGE_M * 0.5,
		"On-target laser should stay short"
	)
	laser_hit_beam.queue_free()
	laser_hit_player.queue_free()


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
	_fail_unless(laser.get_health() == 40, "Laser drone should start at 40 HP")

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


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
	quit(1)
