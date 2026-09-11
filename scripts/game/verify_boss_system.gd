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
	_verify_boss_relocate()
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
		is_equal_approx(SunEaterScript.RELOCATE_PERIOD_SEC, 60.0),
		"Boss should relocate after 60 seconds standing"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.BURIED_WAIT_SEC, 2.0),
		"Boss should wait 2 seconds underground before respawning"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.MIN_RELOCATE_SEP_M, 100.0),
		"Relocate picks should prefer 100 m from previous stands"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.diameter_for_relocate(0), 160.0),
		"First night sphere should be 160 m"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.diameter_for_relocate(1), 160.0),
		"Later boss night spheres should stay 160 m"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.diameter_for_relocate(2), 160.0),
		"Hopped boss night spheres should not grow"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.sink_y(12.0, 0.0), 12.0),
		"Sink should start standing"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.sink_y(12.0, 1.5), -38.0),
		"Sink should be halfway after 1.5 seconds"
	)
	_fail_unless(
		is_equal_approx(SunEaterScript.sink_y(12.0, 3.0), -88.0),
		"Sink should finish fully buried"
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
	_fail_unless(
		is_equal_approx(SunEaterScript.NIGHT_REGEN_PER_SEC, 30.0),
		"Clock night should regenerate the boss at 30 HP per second"
	)
	_fail_unless(SunEaterScript.night_regen_heal(1.0) == 30, "One night second should heal 30")
	_fail_unless(SunEaterScript.night_regen_heal(0.5) == 15, "Half a night second should heal 15")
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
	boss.take_damage(100)
	_fail_unless(boss.get_health() == 4900, "Damage should stick before clock night")
	boss._physics_process(1.0)
	_fail_unless(boss.get_health() == 4900, "The boss should not regenerate during the day")
	boss.begin_clock_night()
	boss._physics_process(1.0)
	_fail_unless(boss.get_health() == 4930, "Clock night should regenerate 30 HP per second")
	boss._physics_process(1.0)
	_fail_unless(boss.get_health() == 4960, "Night regen should keep stacking")
	boss._physics_process(2.0)
	_fail_unless(boss.get_health() == 5000, "Night regen should stop at max HP")
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
	_fail_unless(is_equal_approx(NightScarabScript.MOVE_SPEED, 12.0), "Night scarabs should move at 12 m/s by day")
	_fail_unless(is_equal_approx(NightScarabScript.NIGHT_MOVE_SPEED, 21.0), "Night scarabs should move at 21 m/s at clock night")
	_fail_unless(is_equal_approx(NightScarabScript.FULL_SIM_RANGE_M, 50.0), "Far scarabs should drop full physics past 50 m")
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
	_fail_unless(is_equal_approx(SunEaterScript.SCARAB_NIGHT_RATE, 10.0), "Night should spawn 10 scarabs per second per sphere")
	_fail_unless(is_equal_approx(SunEaterScript.night_spawn_rate(0.0), 10.0), "Night rate should be 10/s at release")
	_fail_unless(is_equal_approx(SunEaterScript.night_spawn_rate(10.0), 10.0), "Night rate should stay 10/s")
	_fail_unless(SunEaterScript.SCARAB_CAP == 500, "Day and night scarab cap should both be 500")

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
	kit._physics_process(0.016)
	_fail_unless(
		not kit.is_queued_for_deletion(),
		"A scarab with no hunt target must keep living"
	)
	kit.free()

	var volume := NightVolumeScript.new()
	root.add_child(volume)
	volume.configure(40.0, false)
	volume.snap_to_standing(Vector3.ZERO, 0.0)
	volume.set_fade(1.0)
	_fail_unless(volume.is_formed(), "A fade-1 volume should count as formed")
	volume.set_fade(0.5)
	_fail_unless(volume.is_formed(), "A sphere that finished forming should keep counting as formed")
	volume.set_fade(1.0)
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
	_fail_unless(is_equal_approx(wanderer.move_speed, 12.0), "A daytime escaper should keep 12 m/s")
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

	var lonely: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(lonely)
	lonely.global_position = Vector3(100.0, 0.0, 50.0)
	lonely.configure(null, null)
	lonely.begin_ascent(12.0)
	lonely._physics_process(3.0)
	lonely._physics_process(8.0)
	lonely._spread_full = true
	_fail_unless(
		lonely.formed_night_volumes().size() == 1,
		"A formed boss sphere should fill even with no hunt target"
	)
	lonely._physics_process(1.0)
	_fail_unless(
		lonely.living_scarab_count() == 1,
		"Daytime spawn should fill formed spheres even without a hunt target"
	)
	_fail_unless(
		lonely.living_scarabs()[0].get_parent() != lonely,
		"Scarabs should live in the world, not inside the boss body"
	)
	lonely.living_scarabs()[0]._physics_process(0.016)
	_fail_unless(
		not lonely.living_scarabs()[0].is_queued_for_deletion(),
		"A daytime scarab must survive a physics tick without a hunt target"
	)
	lonely.free()

	var spread: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(spread)
	spread._rng.seed = 21
	spread.global_position = Vector3(100.0, 0.0, 50.0)
	spread.configure(null, null)
	spread.begin_ascent(12.0)
	spread._physics_process(3.0)
	spread._physics_process(8.0)
	_fail_unless(spread.living_scarab_count() == 0, "Boss sphere still waits until the first formed second")
	for _step in 5:
		spread._physics_process(1.0)
	_fail_unless(spread.child_night_volumes().is_empty(), "Later spheres should wait 6 seconds after the boss sphere")
	_fail_unless(spread.living_scarab_count() == 5, "Boss sphere should keep filling while waiting to spread")
	spread._physics_process(1.0)
	_fail_unless(spread.child_night_volumes().size() == 1, "A later night sphere should appear after the wait")
	var child_sphere := spread.child_night_volumes()[0]
	_fail_unless(child_sphere.is_spawn_ready(), "A placed later sphere should spawn scarabs immediately")
	_fail_unless(
		spread.formed_night_volumes().size() == 2,
		"Boss and later spheres should both count as spawners"
	)
	_fail_unless(
		_scarabs_bound_to(spread, child_sphere) >= 1,
		"A later night sphere must start spawning scarabs during the day"
	)
	_fail_unless(
		_scarabs_bound_to(spread, child_sphere) + _scarabs_bound_to(spread, spread.get_node("NightVolume"))
		== spread.living_scarab_count(),
		"Every daytime scarab should belong to a night sphere"
	)
	var child_pos := child_sphere.global_position
	_fail_unless(
		Vector2(child_pos.x - 100.0, child_pos.z - 50.0).length() >= 120.0,
		"Later sphere scarabs should live in the offset sphere, not the boss hull"
	)
	for scarab in spread.living_scarabs():
		if scarab.home_volume() != child_sphere:
			continue
		var from_child := Vector2(
			scarab.global_position.x - child_pos.x,
			scarab.global_position.z - child_pos.z
		)
		_fail_unless(
			from_child.length() <= child_sphere.radius_m,
			"Later-sphere scarabs must spawn inside that sphere"
		)
	spread._physics_process(6.0)
	_fail_unless(child_sphere.is_formed(), "Later sphere should still finish fading in")
	var child_count := _scarabs_bound_to(spread, child_sphere)
	spread._physics_process(1.0)
	_fail_unless(
		_scarabs_bound_to(spread, child_sphere) == child_count + 1,
		"A later sphere should keep spawning 1 scarab per second by day"
	)
	spread._physics_process(5.0)
	_fail_unless(spread.child_night_volumes().size() == 2, "Spread should keep planting later spheres")
	_fail_unless(
		_scarabs_bound_to(spread, spread.child_night_volumes()[1]) >= 1,
		"Every later night sphere must spawn scarabs during the day"
	)
	spread.free()

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
	_fail_unless(
		boss.living_scarabs()[0].get_parent() != boss,
		"Daytime scarabs should not be nested under the boss body"
	)
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
		_fail_unless(
			is_equal_approx(scarab.move_speed, 21.0),
			"Clock night should raise scarab speed to 21 m/s"
		)
	_fail_unless(is_equal_approx(boss.spawn_rate_per_sphere(), 10.0), "Clock night should spawn 10/s per sphere")
	boss._physics_process(1.0)
	_fail_unless(boss.living_scarab_count() == 20, "One night second should add 10 scarabs from one sphere")
	_fail_unless(
		is_equal_approx(boss.living_scarabs()[19].move_speed, 21.0),
		"Scarabs spawned at clock night should already move at 21 m/s"
	)
	_fail_unless(is_equal_approx(boss.spawn_rate_per_sphere(), 10.0), "Night rate should stay 10/s")
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
		boss.living_scarab_count() == before_late + 20,
		"A new night sphere should immediately spawn at 10/s alongside existing spheres"
	)
	hunter.free()
	boss.free()


func _verify_boss_relocate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var prev: Array[Vector2] = [Vector2.ZERO]
	var pick := SunEaterScript.try_pick_boss_xz(rng, Vector2.ZERO, prev)
	_fail_unless(pick.is_finite(), "Relocate should find a point in the night disk")
	_fail_unless(
		pick.length() <= SunEaterScript.SPREAD_RADIUS_M + 0.01,
		"Relocate must stay inside the 400 m night-sphere disk"
	)
	_fail_unless(
		pick.distance_to(Vector2.ZERO) >= SunEaterScript.MIN_RELOCATE_SEP_M - 0.01,
		"Relocate should sit at least 100 m from previous stands when there is room"
	)
	rng.seed = 9
	var cramped := SunEaterScript.try_pick_boss_xz(
		rng, Vector2.ZERO, prev, 50.0, 100.0, 64
	)
	_fail_unless(
		cramped.length() <= 50.01,
		"A packed disk must still pick inside the allowed area"
	)
	_fail_unless(
		cramped.length() >= 49.0,
		"When 100 m is impossible, relocate should pick as far as possible"
	)

	var boss: SunEater = SunEaterScene.instantiate() as SunEater
	root.add_child(boss)
	boss._rng.seed = 21
	boss.global_position = Vector3(100.0, 0.0, 50.0)
	boss.configure_encounter(1, 5000)
	boss.begin_ascent(12.0)
	boss._spread_full = true
	boss._physics_process(3.0)
	boss._physics_process(8.0)
	_fail_unless(boss.is_blocking_stream(), "Stream should halt after the first ascent")
	_fail_unless(not boss.is_sinking(), "Boss should still be standing after Bring the Night")
	var leftover := boss.follow_night_volume()
	_fail_unless(leftover != null, "First stand should have a follow night sphere")
	_fail_unless(is_equal_approx(leftover.radius_m, 80.0), "First night sphere radius should be 80 m")
	_fail_unless(boss.batch_size() == 1, "First stay should plant one child sphere at a time")
	var scarabs_before := boss.living_scarab_count()
	boss._physics_process(60.0)
	_fail_unless(boss.is_sinking(), "Boss should start sinking after 60 seconds standing")
	_fail_unless(not leftover.follow_host, "The old night sphere should stay behind as a static volume")
	_fail_unless(leftover.is_spawn_ready(), "The leftover sphere should keep spawning scarabs")
	_fail_unless(
		leftover in boss.child_night_volumes(),
		"The leftover sphere should remain in the spawn list"
	)
	_fail_unless(
		is_equal_approx(boss.global_position.y, 12.0),
		"Sink should not consume the stand tick"
	)
	boss._physics_process(1.5)
	_fail_unless(
		is_equal_approx(boss.global_position.y, SunEaterScript.sink_y(12.0, 1.5)),
		"Boss should descend through the terrain"
	)
	_fail_unless(boss.is_blocking_stream(), "Stream should stay halted while the boss sinks")
	boss._physics_process(1.5)
	_fail_unless(boss.is_buried_waiting(), "Boss should wait underground after sinking")
	_fail_unless(
		is_equal_approx(boss.global_position.y, -88.0),
		"Buried wait should sit fully underground"
	)
	_fail_unless(boss.is_blocking_stream(), "Stream should stay halted while the boss is buried")
	var old_xz := Vector2(100.0, 50.0)
	boss._physics_process(2.0)
	_fail_unless(boss.relocate_count() == 1, "First hop should count as one relocate")
	_fail_unless(boss.batch_size() == 2, "Each hop should add one child sphere per wave")
	_fail_unless(
		is_equal_approx(boss.night_sphere_diameter(), 160.0),
		"The new night sphere should stay 160 m after the first hop"
	)
	_fail_unless(boss.get_health() == 5000, "Relocate must not reset boss HP")
	_fail_unless(
		boss.living_scarab_count() >= scarabs_before,
		"Relocate must not wipe the collected scarabs"
	)
	_fail_unless(is_instance_valid(leftover), "The leftover night sphere must survive the hop")
	var new_xz := Vector2(boss.global_position.x, boss.global_position.z)
	_fail_unless(
		new_xz.distance_to(old_xz) >= 100.0 - 0.01,
		"New stand should be at least 100 m from the previous one"
	)
	_fail_unless(
		new_xz.distance_to(boss.origin_xz()) <= SunEaterScript.SPREAD_RADIUS_M + 0.01,
		"New stand must stay inside the original night-sphere disk"
	)
	_fail_unless(boss.is_blocking_stream(), "Stream should stay halted while the boss re-rises")
	_fail_unless(not boss.has_finished_ascent(), "Re-ascent should not look like the first rise is still pending for stream")
	var follow := boss.follow_night_volume()
	_fail_unless(follow != leftover, "A new follow sphere should grow at the new stand")
	_fail_unless(is_equal_approx(follow.radius_m, 80.0), "New follow sphere should match the original 160 m sphere")
	boss._physics_process(3.0)
	_fail_unless(boss.has_finished_ascent(), "Boss should stand again after relocate ascent")
	boss._physics_process(8.0)
	_fail_unless(follow.is_formed(), "The new larger sphere should fade in over 8 seconds")
	boss._spread_full = false
	var children_before := boss.child_night_volumes().size()
	boss._physics_process(6.0)
	_fail_unless(
		boss.child_night_volumes().size() == children_before + 2,
		"After the first hop, a wave should plant two child spheres at once"
	)
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
	_fail_unless(not boss.is_blocking_stream(), "Stream should keep running until the first ascent finishes")
	boss._physics_process(2.9)
	_fail_unless(not boss.has_finished_ascent(), "Ascent should not finish before 3 seconds")
	boss._physics_process(0.1)
	_fail_unless(boss.has_finished_ascent(), "Stream should halt once the boss has fully ascended")
	_fail_unless(boss.is_blocking_stream(), "An ascended boss should block the regular stream")
	boss._spread_full = true
	boss._physics_process(8.0)
	boss._physics_process(60.0)
	boss._physics_process(3.0)
	_fail_unless(boss.is_buried_waiting(), "Boss should be underground after a relocate sink")
	_fail_unless(boss.is_blocking_stream(), "Stream should stay halted while the boss is buried")
	boss._physics_process(2.0)
	_fail_unless(not boss.has_finished_ascent(), "Relocate rise should still count as ascending")
	_fail_unless(boss.is_blocking_stream(), "Stream should stay halted while the boss re-rises")
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


func _scarabs_bound_to(boss: SunEater, volume: NightVolume) -> int:
	var count := 0
	for scarab in boss.living_scarabs():
		if scarab.home_volume() == volume:
			count += 1
	return count


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


class FakeBossDirector extends Node:
	var blocking := false

	func is_blocking_upgrades() -> bool:
		return blocking
