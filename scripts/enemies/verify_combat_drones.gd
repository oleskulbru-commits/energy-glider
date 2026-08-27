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

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_cap_and_speed()
	if _failed:
		return
	_verify_laser_timings()
	if _failed:
		return
	_verify_missile_hail()
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
	_fail_unless(CombatDroneScript.drone_cap_for_level(5) == 1, "Level 5 should have 1 drone")
	_fail_unless(CombatDroneScript.drone_cap_for_level(6) == 2, "Level 6 should have 2 drones")
	_fail_unless(CombatDroneScript.drone_cap_for_level(10) == 6, "Level 10 should have 6 drones")
	_fail_unless(
		is_equal_approx(CombatDroneScript.move_speed_for_drone_level(5), 15.0),
		"Level 5 drone speed should be 15 m/s"
	)
	_fail_unless(
		is_equal_approx(CombatDroneScript.move_speed_for_drone_level(6), 16.0),
		"Level 6 drone speed should be 16 m/s"
	)
	_fail_unless(CombatDroneScript.DRONE_MAX_HEALTH == 25, "Drone HP should be 25")
	_fail_unless(
		is_equal_approx(CombatDroneScript.WEAPON_RANGE_M, 40.0),
		"Drone weapon range should be 40 m"
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


func _verify_missile_hail() -> void:
	_fail_unless(MissileDroneScript.ROCKET_COUNT == 20, "Hail should fire 20 rockets")
	_fail_unless(DroneRocketScript.DAMAGE == 10, "Drone rocket should deal 10")
	_fail_unless(MissileDroneScript.ROCKET_DAMAGE == 10, "Missile drone damage alias should be 10")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var points := MissileDroneScript.impact_points_around(Vector3.ZERO, 20, 22.0, rng)
	_fail_unless(points.size() == 20, "Should generate 20 impact points")
	var max_r := 0.0
	for p in points:
		max_r = maxf(max_r, Vector2(p.x, p.z).length())
	_fail_unless(max_r <= 22.0 + 0.01, "Impact points should stay within spread radius")
	_fail_unless(max_r >= 22.0 * 0.35, "Impacts should reach outer band of the spread")
	var reticle: GroundReticle = GroundReticleScript.new()
	root.add_child(reticle)
	reticle.place(Vector3(1.0, 2.0, 3.0), 0.5)
	_fail_unless(is_instance_valid(reticle), "Ground reticle should spawn")
	reticle.queue_free()


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
	drone.global_position = Vector3(-30.0, 8.0, 0.0)
	drone.fly_state = CombatDroneScript.FlyState.APPROACH
	_fail_unless(drone.can_fire_weapons(), "Approach + in front should allow fire (laser pre-range)")
	drone.fly_state = CombatDroneScript.FlyState.CATCH_UP
	_fail_unless(not drone.can_fire_weapons(), "Catch-up should disable fire")
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
	_fail_unless(laser.get_health() == 25, "Laser drone should start at 25 HP")

	var missile: MissileDrone = MissileDroneScript.new()
	root.add_child(missile)
	missile.configure(null, player, 15.0)
	missile.global_position = Vector3(-35.0, 8.0, 0.0)
	missile.fly_state = CombatDroneScript.FlyState.KITE
	missile.set("_cooldown_left", 0.0)
	missile._update_weapons(0.016)
	_fail_unless(missile.is_alive(), "Missile drone should stay alive after hail attempt")

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
