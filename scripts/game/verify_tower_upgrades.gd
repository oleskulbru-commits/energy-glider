extends SceneTree

const RunUpgradeStateScript = preload("res://scripts/game/run_upgrade_state.gd")
const UpgradeCatalogScript = preload("res://scripts/game/upgrade_catalog.gd")
const TowerVisitControllerScript = preload("res://scripts/game/tower_visit_controller.gd")
const PlayerRigScript = preload("res://scripts/player/player_rig.gd")
const UpgradeTowerScript = preload("res://scripts/world/upgrade_tower.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog()
	_verify_offers_and_visit_lock()
	_verify_empty_tower_confirm()
	_verify_dawn_pose()
	_verify_visit_radius()
	print("Tower upgrade verification passed.")
	quit(0)


func _verify_catalog() -> void:
	_fail_unless(
		UpgradeCatalogScript.SLOTS_PER_TOWER == 5,
		"Each tower should offer 5 slots"
	)
	_fail_unless(
		UpgradeCatalogScript.default_offers().size() == 5,
		"Default pool should fill all 5 slots"
	)
	_fail_unless(
		UpgradeCatalogScript.display_name(UpgradeCatalogScript.ID_EXTRA_PROJECTILE) == "+1 projectile",
		"Extra projectile should be labeled +1 projectile"
	)


func _verify_offers_and_visit_lock() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	_fail_unless(state.remaining_count(1) == 5, "Tower 1 should start with 5 offers")
	_fail_unless(state.extra_projectiles == 0, "Rifle stacks should start at 0")
	var picked := state.pick_offer(1, 0)
	_fail_unless(picked == UpgradeCatalogScript.ID_EXTRA_PROJECTILE, "Picking should grant extra projectile")
	_fail_unless(state.remaining_count(1) == 4, "Picked card should leave 4 offers")
	_fail_unless(state.extra_projectiles == 1, "Pick should stack extra_projectiles")
	_fail_unless(state.remaining_count(2) == 5, "Other towers should keep a full pool")

	state.mark_visited_this_life(1)
	_fail_unless(state.has_visited_this_life(1), "Opening a tower should lock it this life")
	_fail_unless(not state.has_visited_this_life(2), "Unvisited towers stay unlocked")
	state.clear_visited_this_life()
	_fail_unless(not state.has_visited_this_life(1), "Death should clear visit locks")
	_fail_unless(state.remaining_count(1) == 4, "Death should not refill offers")
	_fail_unless(state.extra_projectiles == 1, "Death should keep projectile stacks")
	state.free()


func _verify_empty_tower_confirm() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	for _i in 5:
		state.pick_offer(3, 0)
	_fail_unless(state.remaining_count(3) == 0, "Taking all 5 should empty the tower")
	_fail_unless(state.extra_projectiles == 5, "Five picks should stack five extra shots")
	state.free()


func _verify_dawn_pose() -> void:
	var tower_pos := Vector3(-1000.0, 12.0, 8.0)
	var xz: Vector2 = PlayerRigScript.in_front_xz(tower_pos)
	_fail_unless(
		is_equal_approx(xz.x, tower_pos.x + PlayerRigScript.SPAWN_EAST_OFFSET_M),
		"Wait until dawn should spawn east of the tower, not at home"
	)
	_fail_unless(is_equal_approx(xz.y, tower_pos.z), "Wait until dawn should keep the tower Z")
	_fail_unless(not is_equal_approx(xz.x, 40.0) or not is_equal_approx(tower_pos.x, 0.0), "Pose must be relative to this tower")


func _verify_visit_radius() -> void:
	var tower: UpgradeTower = UpgradeTowerScript.new()
	tower.tower_index = 1
	tower.is_home = false
	root.add_child(tower)
	tower.global_position = Vector3(-1000.0, 0.0, 0.0)
	await process_frame
	var inside := TowerVisitControllerScript.find_visit_tower(
		self, Vector3(-1000.0 + 19.0, 0.0, 0.0)
	)
	var outside := TowerVisitControllerScript.find_visit_tower(
		self, Vector3(-1000.0 + 21.0, 0.0, 0.0)
	)
	var home: UpgradeTower = UpgradeTowerScript.new()
	home.tower_index = 0
	home.is_home = true
	root.add_child(home)
	home.global_position = Vector3(0.0, 0.0, 0.0)
	await process_frame
	var at_home := TowerVisitControllerScript.find_visit_tower(self, Vector3(1.0, 0.0, 0.0))
	_fail_unless(inside == tower, "20 m should trigger a west tower")
	_fail_unless(outside == null, "Beyond 20 m should not trigger")
	_fail_unless(at_home == null, "Home tower should not open the upgrade menu")
	tower.free()
	home.free()


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
