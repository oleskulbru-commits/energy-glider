extends SceneTree

const BossDirectorScript := preload("res://scripts/game/boss_director.gd")
const SunEaterScene := preload("res://scenes/enemies/sun_eater.tscn")
const SunEaterScript := preload("res://scripts/enemies/sun_eater.gd")
const NightVolumeScript := preload("res://scripts/world/night_volume.gd")
const DayNightCycleScript := preload("res://scripts/world/day_night_cycle.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")
const TowerVisitControllerScript := preload("res://scripts/game/tower_visit_controller.gd")
const UpgradeTowerScript := preload("res://scripts/world/upgrade_tower.gd")
const EnemyStreamSpawnerScript := preload("res://scripts/enemies/enemy_stream_spawner.gd")
const NightScarabScene := preload("res://scenes/enemies/night_scarab.tscn")
const NightScarabScript := preload("res://scripts/enemies/night_scarab.gd")
const AutoRifleScript := preload("res://scripts/weapons/auto_rifle.gd")
const AutoShotgunScript := preload("res://scripts/weapons/auto_shotgun.gd")
const AutoTeslaScript := preload("res://scripts/weapons/auto_tesla.gd")
const AutoLaserScript := preload("res://scripts/weapons/auto_laser.gd")
const AutoRocketScript := preload("res://scripts/weapons/auto_rocket.gd")
const WeaponTargetingScript := preload("res://scripts/weapons/weapon_targeting.gd")
const RifleBulletScript := preload("res://scripts/weapons/rifle_bullet.gd")
const SwarmPillScript := preload("res://scripts/enemies/swarm_pill.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_indexes_and_hp()
	_verify_spawn_geometry()
	_verify_encounter_gates()
	_verify_ascent_and_hp_lock()
	_verify_boss_targeting()
	_verify_night_volume()
	_verify_night_spread()
	_verify_night_scarabs()
	_verify_stream_halt()
	await _verify_visit_lock()
	_verify_boss_shop()
	if _failed:
		quit(1)
		return
	print("Boss system verification passed.")
	quit(0)


func _verify_indexes_and_hp() -> void:
	for index in [1, 16, 24, 32, 40]:
		_fail_unless(
			BossDirectorScript.is_boss_tower(index),
			"Tower %d should be a boss tower" % index
		)
	for index in [0, 2, 7, 8, 9, 15, 17, 23, 25, 31, 33, 39, 41, 1004]:
		_fail_unless(
			not BossDirectorScript.is_boss_tower(index),
			"Tower %d should not be a boss tower" % index
		)
	_fail_unless(BossDirectorScript.boss_ordinal(1) == 1, "First boss ordinal should be 1")
	_fail_unless(BossDirectorScript.boss_ordinal(40) == 5, "Fifth boss ordinal should be 5")
	_fail_unless(
		BossDirectorScript.max_health_for_tower(1) == 5000,
		"First boss should have 5000 HP"
	)
	_fail_unless(
		BossDirectorScript.max_health_for_tower(16) == 10000,
		"Second boss should have 10000 HP"
	)
	_fail_unless(
		BossDirectorScript.max_health_for_tower(24) == 15000,
		"Third boss should have 15000 HP"
	)
	_fail_unless(
		BossDirectorScript.max_health_for_tower(32) == 20000,
		"Fourth boss should have 20000 HP"
	)
	_fail_unless(
		BossDirectorScript.max_health_for_tower(40) == 25000,
		"Fifth boss should have 25000 HP"
	)
	_fail_unless(
		BossDirectorScript.max_health_for_tower(7) == 0,
		"Non-boss towers should not have boss HP"
	)


func _verify_spawn_geometry() -> void:
	_fail_unless(
		is_equal_approx(BossDirectorScript.SPAWN_TRIGGER_EAST_M, 200.0),
		"Boss should trigger 200 m east of the tower"
	)
	_fail_unless(
		is_equal_approx(BossDirectorScript.SPAWN_EAST_OF_TOWER_M, 100.0),
		"Boss should spawn 100 m east of the tower"
	)
	_fail_unless(
		is_equal_approx(BossDirectorScript.spawn_x_for_tower(-14000.0), -13900.0),
		"Spawn X should sit 100 m east of the tower"
	)
	_fail_unless(
		BossDirectorScript.has_reached_trigger(-13800.0, -14000.0),
		"Player 200 m east of the tower should trigger the spawn"
	)
	_fail_unless(
		not BossDirectorScript.has_reached_trigger(-13799.0, -14000.0),
		"Player more than 200 m east should not trigger yet"
	)
	_fail_unless(
		BossDirectorScript.has_reached_trigger(-14500.0, -14000.0),
		"Player west of the tower should still count as past the trigger"
	)


func _verify_encounter_gates() -> void:
	var empty: Dictionary = {}
	_fail_unless(
		BossDirectorScript.can_start_encounter(1, false, empty),
		"First boss should spawn when none are living"
	)
	_fail_unless(
		not BossDirectorScript.can_start_encounter(1, true, empty),
		"A new boss should not spawn while another is alive"
	)
	_fail_unless(
		not BossDirectorScript.can_start_encounter(16, false, empty),
		"Second boss should wait until the first is defeated"
	)
	_fail_unless(
		BossDirectorScript.can_start_encounter(16, false, {1: true}),
		"Second boss should spawn after the first is defeated"
	)
	_fail_unless(
		not BossDirectorScript.can_start_encounter(1, false, {1: true}),
		"A defeated boss should not spawn again"
	)
	_fail_unless(
		not BossDirectorScript.can_start_encounter(9, false, empty),
		"Non-boss towers should not start an encounter"
	)


func _verify_ascent_and_hp_lock() -> void:
	_fail_unless(
		is_equal_approx(SunEaterScript.ASCENT_SEC, 3.0),
		"Sun Eater ascent should take 3 seconds"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.BRING_THE_NIGHT_SEC, 8.0),
		"Bring the Night should fade in over 8 seconds after ascent"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.HEIGHT_M, 100.0),
		"Sun Eater should be as tall as the 100 m tower"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.RADIUS_M, 7.0),
		"Sun Eater radius should be half the original 14 m"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.buried_y(12.0), -88.0),
		"Buried pose should hide the full 100 m pill"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.standing_y(12.0), 12.0),
		"Standing pose should rest on the ground"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.rise_y(12.0, 0.0), -88.0),
		"Ascent should start fully buried"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.rise_y(12.0, 1.5), -38.0),
		"Ascent should be halfway after 1.5 seconds"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.rise_y(12.0, 3.0), 12.0),
		"Ascent should finish standing after 3 seconds"
	)
	var boss: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(boss)
	boss.configure_encounter(8, 5000)
	boss.apply_level_hp(40)
	boss.apply_difficulty(1.0)
	_fail_unless(boss.get_max_health() == 5000, "Level HP curve should not scale the boss")
	_fail_unless(boss.get_health() == 5000, "Retry difficulty should not scale the boss")
	boss.begin_ascent(12.0)
	_fail_unless(
		is_equal_approx(boss.global_position.y, -88.0),
		"Boss should start the rise underground"
	)
	boss._physics_process(3.0)
	_fail_unless(
		is_equal_approx(boss.global_position.y, 12.0),
		"Boss should stand still on the ground after 3 seconds"
	)
	boss.free()


func _verify_boss_targeting() -> void:
	_fail_unless(
		SunEaterScript.PILL_COLOR.r < 0.08
		and SunEaterScript.PILL_COLOR.g < 0.08
		and SunEaterScript.PILL_COLOR.b < 0.08,
		"Sun Eater pill should be black"
	)
	var boss: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(boss)
	boss.global_position = Vector3(0.0, 0.0, 0.0)
	boss.begin_ascent(0.0)
	boss._physics_process(3.0)
	var muzzle := Vector3(12.0, 2.0, 0.0)
	var lock := boss.closest_aim_point(muzzle)
	_fail_unless(
		lock.y < 20.0,
		"Weapons beside the boss should lock a low point on the capsule, not the 50 m center"
	)
	_fail_unless(
		not lock.is_equal_approx(boss.hit_center()),
		"Closest aim must not snap to the capsule center when the player is near the base"
	)
	_fail_unless(
		WeaponTargetingScript.in_3d_range(muzzle, boss, AutoShotgunScript.RANGE_M),
		"Shotgun range should reach the nearby surface of the 100 m pill"
	)
	_fail_unless(
		WeaponTargetingScript.in_xz_range(muzzle, boss, AutoTeslaScript.RANGE_M),
		"Tesla range should reach the nearby surface of the 100 m pill"
	)
	_fail_unless(
		WeaponTargetingScript.in_xz_range(muzzle, boss, AutoRifleScript.RANGE_M),
		"Rifle range should reach the nearby surface of the 100 m pill"
	)
	var high := Vector3(12.0, 40.0, 0.0)
	var high_lock := boss.closest_aim_point(high)
	_fail_unless(
		high_lock.y > 25.0 and high_lock.y < 55.0,
		"A lock beside the shaft should sit on the nearby hull, not the feet or the tip"
	)
	_fail_unless(
		WeaponTargetingScript.in_3d_range(high, boss, AutoShotgunScript.RANGE_M),
		"Shotgun should acquire the hull when flying beside the boss"
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var facing := Vector3(-1.0, 0.0, 0.0)
	var rifle_pick := AutoRifleScript.pick_target([boss], muzzle, facing, AutoShotgunScript.RANGE_M, rng)
	_fail_unless(rifle_pick == boss, "Short-range acquire should still pick the Sun Eater")
	var shotgun_pick := AutoShotgunScript.pick_target(
		[boss], muzzle, facing, AutoShotgunScript.RANGE_M, rng
	)
	_fail_unless(shotgun_pick == boss, "Shotgun should pick the Sun Eater by its hull, not its center")
	var rifle_aim := RifleBulletScript.aim_point_for(boss, muzzle)
	_fail_unless(
		rifle_aim.is_equal_approx(lock),
		"Rifle tracers should home to the closest point on the boss pill"
	)
	var wall := SwarmPillScript.new()
	root.add_child(wall)
	wall.global_position = Vector3(9.0, 0.0, 0.0)
	var swarm: Array = [boss, wall]
	_fail_unless(
		AutoRifleScript.pick_target(swarm, muzzle, facing, AutoRifleScript.RANGE_M, rng) == boss,
		"Rifle should magnet to the Sun Eater over closer scarabs"
	)
	_fail_unless(
		AutoShotgunScript.pick_target(swarm, muzzle, facing, AutoShotgunScript.RANGE_M, rng) == boss,
		"Shotgun should magnet to the Sun Eater over closer scarabs"
	)
	_fail_unless(
		AutoLaserScript.pick_unique_target(swarm, muzzle, facing, AutoLaserScript.RANGE_M, {}, rng)
		== boss,
		"Laser should magnet to the Sun Eater over closer scarabs"
	)
	_fail_unless(
		AutoRocketScript.pick_best_target(swarm, muzzle, facing, AutoRocketScript.RANGE_M) == boss,
		"Rockets should magnet to the Sun Eater over closer scarabs"
	)
	var tesla_picks := AutoTeslaScript.pick_unique_targets(
		swarm, muzzle, facing, AutoTeslaScript.RANGE_M, 3, rng
	)
	_fail_unless(tesla_picks.size() == 3, "Tesla volley should still fire three strikes")
	_fail_unless(
		tesla_picks[0] == boss and tesla_picks[1] == boss and tesla_picks[2] == boss,
		"All Tesla strikes should magnet to the Sun Eater"
	)
	var bounce := AutoRifleScript.pick_bounce_target(swarm, muzzle, 50.0, {}, rng)
	_fail_unless(bounce == boss, "Bounce chains should magnet to the Sun Eater while it lives")
	var drone := SwarmPillScript.new()
	root.add_child(drone)
	drone.add_to_group(WeaponTargetingScript.LASER_DRONE_GROUP)
	drone.global_position = Vector3(8.0, 0.0, 0.0)
	_fail_unless(
		AutoRifleScript.pick_target([boss, drone, wall], muzzle, facing, AutoRifleScript.RANGE_M, rng)
		== boss,
		"The Sun Eater should outrank the red drone magnet"
	)
	var far := Vector3(100.0, 2.0, 0.0)
	wall.global_position = Vector3(90.0, 0.0, 0.0)
	_fail_unless(
		AutoRifleScript.pick_target(swarm, far, facing, AutoRifleScript.RANGE_M, rng) == wall,
		"Out-of-range boss should leave weapons free to hit the scarab wall"
	)
	_fail_unless(
		AutoShotgunScript.pick_target(swarm, far, facing, AutoShotgunScript.RANGE_M, rng) == wall,
		"Short-range weapons should treat nearby scarabs as a wall when the boss is too far"
	)
	boss.set("_hp", 0)
	_fail_unless(not boss.is_alive(), "Test boss should be dead")
	wall.global_position = Vector3(9.0, 0.0, 0.0)
	_fail_unless(
		AutoRifleScript.pick_target(swarm, muzzle, facing, AutoRifleScript.RANGE_M, rng) == wall,
		"Weapons should free up for the scarab wall after the boss dies"
	)
	drone.free()
	wall.free()
	boss.free()


func _verify_night_volume() -> void:
	_fail_unless(
		is_equal_approx(NightVolumeScript.DIAMETER_M, 160.0),
		"Night volume sphere should be 160 m across"
	)
	_fail_unless(
		is_equal_approx(NightVolumeScript.RADIUS_M, 80.0),
		"Night volume sphere radius should be 80 m"
	)
	_fail_unless(
		is_equal_approx(NightVolumeScript.EDGE_FADE_M, 14.0),
		"Night volume should soften ~14 m at the edges"
	)
	var boss: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(boss)
	boss.global_position = Vector3(100.0, 0.0, 50.0)
	boss.begin_ascent(12.0)
	var volume := boss.get_node("NightVolume") as NightVolume
	_fail_unless(volume != null, "Sun Eater should carry a NightVolume")
	_fail_unless(
		is_equal_approx(boss.global_position.y, -88.0),
		"Boss should start the rise underground"
	)
	_fail_unless(
		is_equal_approx(volume.global_position.y, 12.0),
		"Sphere center should sit on standing terrain while the boss is buried"
	)
	_fail_unless(
		is_equal_approx(volume.global_position.x, 100.0)
		and is_equal_approx(volume.global_position.z, 50.0),
		"Night volume should track the boss XZ"
	)
	_fail_unless(is_equal_approx(volume.fade, 0.0), "Night volume should be invisible at ascent start")
	var center := Vector3(100.0, 12.0, 50.0)
	_fail_unless(
		is_equal_approx(volume.blend_at_world(center), 0.0),
		"Camera blend should stay 0 until the volume fades in"
	)
	boss._physics_process(3.0)
	_fail_unless(
		is_equal_approx(boss.global_position.y, 12.0),
		"Boss should stand on the ground after ascent"
	)
	_fail_unless(
		is_equal_approx(volume.fade, 0.0),
		"Bring the Night should not start until the boss has finished rising"
	)
	_fail_unless(
		is_equal_approx(volume.global_position.y, 12.0),
		"Sphere center should stay on standing terrain after ascent"
	)
	boss._physics_process(4.0)
	_fail_unless(
		is_equal_approx(volume.fade, 0.5),
		"Bring the Night should be half opacity after 4 seconds"
	)
	boss._physics_process(4.0)
	_fail_unless(is_equal_approx(volume.fade, 1.0), "Bring the Night should be fully faded in after 8 seconds")
	var mesh := volume.get_node("Mesh") as MeshInstance3D
	_fail_unless(mesh != null, "Night volume should have a sphere mesh")
	_fail_unless(mesh.mesh is SphereMesh, "Bring the Night hull should be a sphere")
	_fail_unless(
		is_equal_approx(mesh.global_position.y, 12.0),
		"Sphere mesh should be centered on standing terrain"
	)
	_fail_unless(
		volume.blend_at_world(center) > 0.95,
		"Camera at the sphere center should read as full local night"
	)
	_fail_unless(
		volume.blend_at_world(Vector3(100.0, 12.0, 50.0)) > 0.95,
		"Local night should reach standing terrain height"
	)
	_fail_unless(
		is_equal_approx(volume.blend_at_world(Vector3(280.0, center.y, 50.0)), 0.0),
		"Camera outside the 160 m sphere should not blend into night"
	)
	var cycle: DayNightCycle = DayNightCycleScript.new()
	cycle.day_phase_sec = 240.0
	cycle.night_phase_sec = 240.0
	cycle.start_offset_sec = 48.0
	root.add_child(cycle)
	_fail_unless(not cycle.is_night(), "Clock should still be daytime")
	_fail_unless(
		cycle.get_daylight_blend() > 0.99,
		"Clock daylight blend should ignore the night volume"
	)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_position = Vector3(280.0, center.y, 50.0)
	camera.make_current()
	_fail_unless(
		cycle.get_night_blend() < 0.05,
		"Headlight night blend should stay off when the camera is outside the volume"
	)
	camera.global_position = center
	_fail_unless(
		cycle.get_night_blend() > 0.95,
		"Headlight night blend should rise when the camera is inside the volume"
	)
	_fail_unless(not cycle.is_night(), "Local night should not flip the clock is_night() gate")
	camera.free()
	cycle.free()
	boss.free()


func _verify_night_spread() -> void:
	_fail_unless(
		is_equal_approx(SunEaterScript.CHILD_DIAMETER_M, 80.0),
		"Spread spheres should be half the 160 m boss sphere"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.CHILD_RADIUS_M, 40.0),
		"Spread sphere radius should be 40 m"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.SPREAD_RADIUS_M, 400.0),
		"Spread picks should stay inside a 400 m circle"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.SPREAD_WAIT_SEC, 6.0),
		"Spread should wait 6 seconds between fully formed spheres"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.CHILD_FORM_SEC, 6.0),
		"Child spheres should fade in over 6 seconds"
	)
	var boss_r := NightVolumeScript.RADIUS_M
	var child_r := SunEaterScript.CHILD_RADIUS_M
	_fail_unless(
		SunEaterScript.spheres_overlap_xz(Vector2.ZERO, boss_r, Vector2(119.0, 0.0), child_r),
		"119 m from the boss sphere should overlap a child sphere"
	)
	_fail_unless(
		not SunEaterScript.spheres_overlap_xz(Vector2.ZERO, boss_r, Vector2(120.0, 0.0), child_r),
		"120 m from the boss sphere should be a valid child center"
	)
	_fail_unless(
		SunEaterScript.spheres_overlap_xz(Vector2.ZERO, child_r, Vector2(79.0, 0.0), child_r),
		"Two children 79 m apart should overlap"
	)
	_fail_unless(
		not SunEaterScript.spheres_overlap_xz(Vector2.ZERO, child_r, Vector2(80.0, 0.0), child_r),
		"Two children 80 m apart should not overlap"
	)
	var boss_only: Array[Dictionary] = [{"xz": Vector2.ZERO, "r": boss_r}]
	_fail_unless(
		not SunEaterScript.can_place_xz(Vector2(119.0, 0.0), child_r, boss_only),
		"Placement should reject overlap with the boss sphere"
	)
	_fail_unless(
		SunEaterScript.can_place_xz(Vector2(120.0, 0.0), child_r, boss_only),
		"Placement should allow a child on the 120 m ring"
	)
	var packed: Array[Dictionary] = [{"xz": Vector2.ZERO, "r": 400.0}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var blocked := SunEaterScript.try_pick_child_xz(rng, Vector2.ZERO, packed)
	_fail_unless(not blocked.is_finite(), "A full 400 m ring should stop further picks")
	rng.seed = 11
	var picked := SunEaterScript.try_pick_child_xz(rng, Vector2.ZERO, boss_only)
	_fail_unless(picked.is_finite(), "An empty ring around the boss should still have room")
	_fail_unless(
		picked.length() >= boss_r + child_r,
		"A random child center should sit outside the boss sphere"
	)
	_fail_unless(
		picked.length() <= SunEaterScript.SPREAD_RADIUS_M,
		"A random child center should stay inside the 400 m disk"
	)
	var boss: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(boss)
	boss._rng.seed = 21
	boss.global_position = Vector3(100.0, 0.0, 50.0)
	boss.begin_ascent(12.0)
	boss._physics_process(3.0)
	boss._physics_process(8.0)
	_fail_unless(
		boss.child_night_volumes().is_empty(),
		"No child sphere should spawn until 6 seconds after the boss sphere is formed"
	)
	_fail_unless(is_equal_approx(boss.bring_the_night_fade(), 1.0), "Boss sphere should be fully formed")
	boss._physics_process(6.0)
	_fail_unless(
		boss.child_night_volumes().size() == 1,
		"First child sphere should spawn after the 6 second wait"
	)
	var child := boss.child_night_volumes()[0]
	_fail_unless(is_equal_approx(child.radius_m, 40.0), "Child sphere should be half size")
	_fail_unless(is_equal_approx(child.fade, 0.0), "A newly spawned child should start at zero opacity")
	_fail_unless(
		is_equal_approx(child.global_position.y, 12.0),
		"Child sphere center should sit on standing terrain"
	)
	var from_boss := Vector2(child.global_position.x - 100.0, child.global_position.z - 50.0)
	_fail_unless(
		from_boss.length() >= boss_r + child_r,
		"Child sphere should not overlap the boss sphere"
	)
	boss._physics_process(6.0)
	_fail_unless(is_equal_approx(child.fade, 1.0), "Child sphere should finish fading in after 6 seconds")
	boss._physics_process(6.0)
	_fail_unless(
		boss.child_night_volumes().size() == 2,
		"A second child should spawn 6 seconds after the first finishes"
	)
	var second := boss.child_night_volumes()[1]
	var between := Vector2(
		second.global_position.x - child.global_position.x,
		second.global_position.z - child.global_position.z
	)
	_fail_unless(
		between.length() >= child_r + child_r,
		"Child spheres should not overlap each other"
	)
	boss.free()


func _verify_night_scarabs() -> void:
	_fail_unless(is_equal_approx(NightScarabScript.MOVE_SPEED, 12.0), "Night scarabs should move at 12 m/s")
	_fail_unless(NightScarabScript.SCARAB_CONTACT_DAMAGE == 2, "Night scarabs should deal 2 damage")
	_fail_unless(NightScarabScript.SCARAB_MAX_HEALTH == 15, "Night scarabs should have 15 HP")
	_fail_unless(NightScarabScript.is_escape_spawn(10), "Every 10th scarab should be able to leave")
	_fail_unless(not NightScarabScript.is_escape_spawn(9), "The 9th scarab should stay bound")
	_fail_unless(NightScarabScript.is_escape_spawn(20), "The 20th scarab should be able to leave")
	_fail_unless(
		not NightScarabScript.should_hunt_player(false, false),
		"Bound scarabs should roam while the player is outside the sphere"
	)
	_fail_unless(
		NightScarabScript.should_hunt_player(true, false),
		"Bound scarabs should hunt when the player enters the sphere"
	)
	_fail_unless(
		NightScarabScript.should_hunt_player(false, true),
		"Unshackled scarabs should hunt even if the player is outside"
	)
	_fail_unless(is_equal_approx(SunEaterScript.night_spawn_rate(0.0), 1.0), "Night rate should start at 1/s")
	_fail_unless(is_equal_approx(SunEaterScript.night_spawn_rate(4.99), 1.0), "Night rate should stay 1/s until 5s")
	_fail_unless(is_equal_approx(SunEaterScript.night_spawn_rate(5.0), 2.0), "Night rate should be 2/s at 5s")
	_fail_unless(is_equal_approx(SunEaterScript.night_spawn_rate(10.0), 3.0), "Night rate should be 3/s at 10s")

	var kit := NightScarabScene.instantiate()
	root.add_child(kit)
	_fail_unless(kit.get_max_health() == 15, "Night scarab kit HP should be 15")
	_fail_unless(kit.get_health() == 15, "Night scarab should spawn at full 15 HP")
	_fail_unless(kit.contact_damage == 2, "Night scarab kit damage should be 2")
	_fail_unless(is_equal_approx(kit.move_speed, 12.0), "Night scarab kit speed should be 12")
	kit.apply_level_hp(40)
	kit.apply_difficulty(1.0)
	_fail_unless(kit.get_max_health() == 15, "Level HP curve should not scale night scarabs")
	_fail_unless(kit.contact_damage == 2, "Retry difficulty should not scale night scarab damage")
	kit.free()

	var volume := NightVolumeScript.new()
	root.add_child(volume)
	volume.configure(40.0, false)
	volume.snap_to_standing(Vector3.ZERO, 0.0)
	volume.set_fade(1.0)
	_fail_unless(volume.is_formed(), "A fade-1 volume should count as formed")
	_fail_unless(volume.contains_xz(Vector3(10.0, 4.0, 0.0)), "A point inside the disk should count")
	_fail_unless(not volume.contains_xz(Vector3(41.0, 0.0, 0.0)), "A point past the radius should be outside")
	var clamped := volume.clamp_xz(Vector3(80.0, 1.0, 0.0), 1.0)
	_fail_unless(
		clamped.x <= 39.01,
		"Clamp should pull a point back inside the wander radius"
	)
	_fail_unless(volume.contains_xz(clamped), "Clamped points should remain inside the sphere")

	var player := Node3D.new()
	root.add_child(player)
	player.global_position = Vector3(200.0, 0.0, 0.0)
	var wanderer := NightScarabScene.instantiate()
	root.add_child(wanderer)
	wanderer.global_position = Vector3(5.0, 0.0, 0.0)
	wanderer.configure(null, player)
	wanderer.bind_sphere(volume, false)
	wanderer._update_chase(0.1)
	_fail_unless(not wanderer.is_unshackled(), "A normal spawn should stay bound")
	_fail_unless(not wanderer.is_hunting_in_sphere(), "Player outside should leave the scarab roaming")
	wanderer.global_position = Vector3(80.0, 0.0, 0.0)
	wanderer._after_move(0.016)
	_fail_unless(
		Vector2(wanderer.global_position.x, wanderer.global_position.z).length() <= 39.01,
		"Roaming scarabs must not leave their night sphere"
	)
	player.global_position = Vector3(8.0, 0.0, 0.0)
	wanderer._update_chase(0.1)
	_fail_unless(wanderer.is_hunting_in_sphere(), "Player inside the sphere should make the scarab hunt")
	player.global_position = Vector3(200.0, 0.0, 0.0)
	wanderer._update_chase(0.1)
	_fail_unless(not wanderer.is_hunting_in_sphere(), "Player leaving the sphere should return the scarab to roam")
	wanderer.unshackle()
	_fail_unless(wanderer.is_unshackled(), "Unshackle should release the scarab from its sphere")
	_fail_unless(
		wanderer._blocks_behind_despawn(),
		"Night scarabs should never despawn when the player drives past them"
	)
	player.global_position = Vector3(-80.0, 0.0, 0.0)
	wanderer._physics_process(0.016)
	_fail_unless(
		is_instance_valid(wanderer),
		"An unshackled scarab behind the player must stay in the world"
	)
	wanderer.free()
	player.free()
	volume.free()

	var boss: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(boss)
	var hunter := Node3D.new()
	root.add_child(hunter)
	hunter.global_position = Vector3(100.0, 12.0, 50.0)
	boss.global_position = Vector3(100.0, 0.0, 50.0)
	boss.configure(null, hunter)
	boss.begin_ascent(12.0)
	boss._physics_process(3.0)
	boss._physics_process(8.0)
	boss._spread_full = true
	_fail_unless(boss.formed_night_volumes().size() == 1, "Boss sphere should spawn scarabs once fully formed")
	_fail_unless(boss.living_scarab_count() == 0, "Scarabs should not spawn until the first formed second")
	boss._physics_process(1.0)
	_fail_unless(boss.living_scarab_count() == 1, "A formed sphere should spawn 1 scarab per second by day")
	_fail_unless(not boss.living_scarabs()[0].is_unshackled(), "The first scarab should stay bound")
	boss._physics_process(9.0)
	_fail_unless(boss.living_scarab_count() == 10, "Ten seconds should yield ten scarabs from one sphere")
	var tenth = boss.living_scarabs()[9]
	_fail_unless(tenth.is_unshackled(), "Every 10th scarab should be able to leave the sphere")
	for i in range(9):
		_fail_unless(
			not boss.living_scarabs()[i].is_unshackled(),
			"Scarabs 1-9 should stay bound to their sphere"
		)
	var night_volume := boss.get_node("NightVolume") as NightVolume
	boss.begin_clock_night()
	_fail_unless(boss.is_night_unleashed(), "Clock night should unshackle the collected swarm")
	_fail_unless(not night_volume.visuals_enabled(), "Formed night spheres should vanish at clock night")
	var mesh := night_volume.get_node("Mesh") as MeshInstance3D
	_fail_unless(mesh == null or not mesh.visible, "Night sphere meshes should hide at clock night")
	for scarab in boss.living_scarabs():
		_fail_unless(scarab.is_unshackled(), "Every collected scarab should hunt after night falls")
	_fail_unless(is_equal_approx(boss.spawn_rate_per_sphere(), 1.0), "Night ramp should still be 1/s at release")
	boss._physics_process(5.0)
	_fail_unless(is_equal_approx(boss.spawn_rate_per_sphere(), 2.0), "Night ramp should be 2/s after 5 seconds")
	boss._physics_process(5.0)
	_fail_unless(is_equal_approx(boss.spawn_rate_per_sphere(), 3.0), "Night ramp should be 3/s after 10 seconds")
	var before_late := boss.living_scarab_count()
	var late := NightVolumeScript.new()
	boss.add_child(late)
	late.configure(SunEaterScript.CHILD_RADIUS_M, false)
	late.snap_to_standing(Vector3(300.0, 0.0, 50.0), 12.0)
	late.set_fade(1.0)
	late.set_visuals_enabled(false)
	boss._child_volumes.append(late)
	_fail_unless(not late.visuals_enabled(), "Night-only spheres should have no visuals")
	boss._physics_process(1.0)
	_fail_unless(
		boss.living_scarab_count() == before_late + 6,
		"A sphere that forms at t=10s should immediately spawn at 3/s alongside existing spheres"
	)
	hunter.free()
	boss.free()


func _verify_stream_halt() -> void:
	_fail_unless(
		EnemyStreamSpawnerScript.should_spawn_stream(true, true, false, false),
		"Regular stream should spawn while no ascended boss is blocking"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.should_spawn_stream(true, true, false, true),
		"An ascended boss should halt regular enemy stream spawns"
	)
	_fail_unless(
		not EnemyStreamSpawnerScript.should_spawn_stream(true, true, true, false),
		"A finished run should still halt the stream"
	)
	var boss: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(boss)
	boss.begin_ascent(12.0)
	_fail_unless(not boss.has_finished_ascent(), "Stream should keep running while the boss is still rising")
	boss._physics_process(2.9)
	_fail_unless(not boss.has_finished_ascent(), "Ascent should not finish before 3 seconds")
	boss._physics_process(0.1)
	_fail_unless(boss.has_finished_ascent(), "Stream should halt once the boss has fully ascended")
	boss.free()


func _verify_visit_lock() -> void:
	var tower: UpgradeTower = UpgradeTowerScript.new()
	tower.tower_index = 9
	root.add_child(tower)
	tower.global_position = Vector3(-1000.0, 0.0, 0.0)
	await process_frame
	var open := TowerVisitControllerScript.find_visit_tower(self, Vector3(-1000.0, 0.0, 0.0))
	_fail_unless(open == tower, "Towers should stay visitable when no boss is alive")
	var blocker := FakeBossDirector.new()
	blocker.blocking = true
	root.add_child(blocker)
	blocker.add_to_group("boss_director")
	await process_frame
	var locked := TowerVisitControllerScript.find_visit_tower(self, Vector3(-1000.0, 0.0, 0.0))
	_fail_unless(locked == null, "A living boss should lock every upgrade tower")
	blocker.blocking = false
	var unlocked := TowerVisitControllerScript.find_visit_tower(self, Vector3(-1000.0, 0.0, 0.0))
	_fail_unless(unlocked == tower, "Towers should unlock after the boss is defeated")
	blocker.free()
	tower.free()


func _verify_boss_shop() -> void:
	var weights := UpgradeCatalogScript.boss_rarity_weights()
	_fail_unless(
		weights.size() == 5
		and int(weights[0]) == 0
		and int(weights[1]) == 0
		and int(weights[2]) == 500
		and int(weights[3]) == 375
		and int(weights[4]) == 125,
		"Boss shop weights should be 50 / 37.5 / 12.5 rare/epic/legendary"
	)
	for tower_index in [1, 16, 24, 32, 40]:
		var shop := UpgradeCatalogScript.roll_shop(
			1, tower_index, 20, true, true, true, true, true, 0, -1, true
		)
		_fail_unless(shop.size() == 5, "Boss shop %d should still offer 5 cards" % tower_index)
		_fail_unless(not _has_duplicate(shop), "Boss shop %d should not repeat a card" % tower_index)
		for id in shop:
			var offer := StringName(id)
			if UpgradeCatalogScript.is_weapon_unlock(offer):
				continue
			var rarity := UpgradeCatalogScript.rarity_of(offer)
			_fail_unless(
				rarity == UpgradeCatalogScript.RARITY_RARE
				or rarity == UpgradeCatalogScript.RARITY_EPIC
				or rarity == UpgradeCatalogScript.RARITY_LEGENDARY,
				"Boss shop cards should be rare, epic, or legendary"
			)


func _has_duplicate(shop: PackedStringArray) -> bool:
	var seen: Dictionary = {}
	for id in shop:
		var base := String(UpgradeCatalogScript.weapon_base_id(StringName(id)))
		if seen.has(base):
			return true
		seen[base] = true
	return false


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


class FakeBossDirector extends Node:
	var blocking := false

	func is_blocking_upgrades() -> bool:
		return blocking
