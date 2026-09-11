extends SceneTree

const BossDirectorScript := preload("res://scripts/game/boss_director.gd")
const SunEaterScene := preload("res://scenes/enemies/sun_eater.tscn")
const SunEaterScript := preload("res://scripts/enemies/sun_eater.gd")
const NightVolumeScript := preload("res://scripts/world/night_volume.gd")
const DayNightCycleScript := preload("res://scripts/world/day_night_cycle.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")
const TowerVisitControllerScript := preload("res://scripts/game/tower_visit_controller.gd")
const UpgradeTowerScript := preload("res://scripts/world/upgrade_tower.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_indexes_and_hp()
	_verify_spawn_geometry()
	_verify_encounter_gates()
	_verify_ascent_and_hp_lock()
	_verify_night_volume()
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
