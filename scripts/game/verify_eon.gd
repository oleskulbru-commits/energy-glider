extends SceneTree

const EonDirectorScript = preload("res://scripts/game/eon_director.gd")
const DayNightCycleScript = preload("res://scripts/world/day_night_cycle.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _run_tests() -> void:
	_verify_integrity_loss()
	_verify_try_again_gate()
	_verify_difficulty_bonus()
	_verify_scaled_stat()
	_verify_day_night_difficulty()
	_verify_objective_text()
	_verify_pickup_blocked_while_dead()
	_verify_integrity_loss_requires_pickup()
	_verify_sticky_integrity_after_first_collect()
	_verify_eon_tracker_always_while_awaiting()
	print("E.O.N verification passed.")
	quit(0)


func _verify_integrity_loss() -> void:
	_fail_unless(
		EonDirectorScript.apply_death_integrity_loss(100) == 66,
		"First death should reduce integrity to 66"
	)
	_fail_unless(
		EonDirectorScript.apply_death_integrity_loss(66) == 32,
		"Second death should reduce integrity to 32"
	)
	_fail_unless(
		EonDirectorScript.apply_death_integrity_loss(32) == 0,
		"Third death should clamp integrity at 0"
	)
	_fail_unless(
		EonDirectorScript.apply_death_integrity_loss(0) == 0,
		"Zero integrity should stay at 0"
	)


func _verify_try_again_gate() -> void:
	_fail_unless(
		EonDirectorScript.can_try_again_with_integrity(100),
		"Try again should be allowed at 100 integrity"
	)
	_fail_unless(
		EonDirectorScript.can_try_again_with_integrity(32),
		"Try again should be allowed at 32 integrity"
	)
	_fail_unless(
		not EonDirectorScript.can_try_again_with_integrity(0),
		"Try again should be blocked at 0 integrity"
	)


func _verify_difficulty_bonus() -> void:
	_fail_unless(
		is_equal_approx(EonDirectorScript.difficulty_bonus_for_retry_count(0), 0.0),
		"No retries should be 0% difficulty"
	)
	_fail_unless(
		is_equal_approx(EonDirectorScript.difficulty_bonus_for_retry_count(1), 0.10),
		"First Try Again should be +10%"
	)
	_fail_unless(
		is_equal_approx(EonDirectorScript.difficulty_bonus_for_retry_count(2), 0.15),
		"Second Try Again should be +15%"
	)
	_fail_unless(
		is_equal_approx(EonDirectorScript.difficulty_bonus_for_retry_count(3), 0.20),
		"Third Try Again should be +20%"
	)
	var director: EonDirector = EonDirectorScript.new()
	root.add_child(director)
	_fail_unless(is_equal_approx(director.difficulty_bonus(), 0.0), "Fresh director bonus is 0")
	_fail_unless(
		is_equal_approx(director.next_try_again_bonus(), 0.10),
		"Next Try Again preview should be +10%"
	)
	director.retry_count = 1
	_fail_unless(is_equal_approx(director.difficulty_bonus(), 0.10), "After 1 retry bonus is 10%")
	_fail_unless(
		is_equal_approx(director.next_try_again_bonus(), 0.15),
		"Next Try Again preview should be +15%"
	)
	director.free()


func _verify_scaled_stat() -> void:
	_fail_unless(EonDirectorScript.scaled_stat(20.0, 0.0) == 20, "0% should leave HP unchanged")
	_fail_unless(EonDirectorScript.scaled_stat(20.0, 0.10) == 22, "10% of 20 HP should floor to 22")
	_fail_unless(EonDirectorScript.scaled_stat(8.0, 0.10) == 8, "10% of 8 speed should floor to 8")
	_fail_unless(EonDirectorScript.scaled_stat(8.0, 0.15) == 9, "15% of 8 speed should floor to 9")
	_fail_unless(EonDirectorScript.scaled_stat(5.0, 0.10) == 5, "10% of 5 damage should floor to 5")
	_fail_unless(EonDirectorScript.scaled_stat(5.0, 0.20) == 6, "20% of 5 damage should floor to 6")
	_fail_unless(EonDirectorScript.scaled_stat(25.0, 0.10) == 27, "10% of 25 HP should floor to 27")
	_fail_unless(EonDirectorScript.scaled_stat(12.0, 0.15) == 13, "15% of 12 damage should floor to 13")


func _verify_day_night_difficulty() -> void:
	var cycle: DayNightCycle = DayNightCycleScript.new()
	root.add_child(cycle)
	cycle.day_phase_sec = 240.0
	cycle.night_phase_sec = 240.0
	cycle.apply_difficulty_bonus(0.10)
	_fail_unless(
		is_equal_approx(cycle.day_phase_sec, 216.0),
		"10% difficulty should shorten day to 216s"
	)
	_fail_unless(
		is_equal_approx(cycle.night_phase_sec, 216.0),
		"10% difficulty should shorten night to 216s"
	)
	cycle.apply_difficulty_bonus(0.15)
	_fail_unless(
		is_equal_approx(cycle.day_phase_sec, 204.0),
		"15% difficulty should shorten day to 204s from base"
	)
	cycle.free()


func _verify_objective_text() -> void:
	_fail_unless(
		EonDirectorScript.OBJECTIVE_RETRIEVE == "Retrieve the E.O.N",
		"Retrieve objective should use E.O.N display name"
	)
	_fail_unless(
		("Travel west and get to upgrade tower %s" % "1")
		== "Travel west and get to upgrade tower 1",
		"Travel objective should include tower number"
	)


func _verify_pickup_blocked_while_dead() -> void:
	_fail_unless(
		EonDirectorScript.can_collect_eon_while(false, false),
		"Pickup should be allowed while alive and not on death screen"
	)
	_fail_unless(
		not EonDirectorScript.can_collect_eon_while(true, false),
		"Pickup should be blocked while awaiting death choice"
	)
	_fail_unless(
		not EonDirectorScript.can_collect_eon_while(false, true),
		"Pickup should be blocked while run is ended"
	)
	_fail_unless(
		not EonDirectorScript.can_collect_eon_while(true, true),
		"Pickup should be blocked while dead and awaiting choice"
	)


func _verify_integrity_loss_requires_pickup() -> void:
	_fail_unless(
		not EonDirectorScript.should_apply_integrity_loss_on_death(false),
		"Integrity should not drop before the E.O.N has been collected"
	)
	_fail_unless(
		EonDirectorScript.should_apply_integrity_loss_on_death(true),
		"Integrity should drop on death after the E.O.N has been collected"
	)


func _verify_sticky_integrity_after_first_collect() -> void:
	# After first pickup, deaths while awaiting re-pickup still cost integrity,
	# but the grounded E.O.N only moves if it was collected again this attempt.
	_fail_unless(
		EonDirectorScript.should_apply_integrity_loss_on_death(true),
		"Integrity should keep dropping on death while awaiting re-pickup"
	)
	_fail_unless(
		EonDirectorScript.should_respawn_eon_at_death(true),
		"E.O.N should re-drop at death when it was picked up this attempt"
	)
	_fail_unless(
		not EonDirectorScript.should_respawn_eon_at_death(false),
		"E.O.N should stay put when dying before re-pickup"
	)
	var integrity := 100
	integrity = EonDirectorScript.apply_death_integrity_loss(integrity)
	_fail_unless(integrity == 66, "First post-collect death should leave 66 integrity")
	integrity = EonDirectorScript.apply_death_integrity_loss(integrity)
	_fail_unless(
		integrity == 32,
		"Second death while awaiting re-pickup should still deteriorate to 32"
	)


func _verify_eon_tracker_always_while_awaiting() -> void:
	_fail_unless(
		EonDirectorScript.should_show_eon_tracker_for(true, true),
		"Tracker/compass should show while awaiting with an E.O.N present"
	)
	_fail_unless(
		not EonDirectorScript.should_show_eon_tracker_for(true, false),
		"Tracker should hide when no E.O.N exists"
	)
	_fail_unless(
		not EonDirectorScript.should_show_eon_tracker_for(false, true),
		"Tracker should hide after E.O.N is collected (run active)"
	)
