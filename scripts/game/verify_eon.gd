extends SceneTree

const EonDirectorScript = preload("res://scripts/game/eon_director.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _run_tests() -> void:
	_verify_integrity_loss()
	_verify_try_again_gate()
	_verify_objective_text()
	_verify_pickup_blocked_while_dead()
	_verify_integrity_loss_requires_pickup()
	print("E.O.N verification passed.")
	quit(0)


func _verify_integrity_loss() -> void:
	_fail_unless(
		EonDirectorScript.apply_death_integrity_loss(100) == 80,
		"First death should reduce integrity to 80"
	)
	_fail_unless(
		EonDirectorScript.apply_death_integrity_loss(20) == 0,
		"Integrity should clamp at 0"
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
		EonDirectorScript.can_try_again_with_integrity(20),
		"Try again should be allowed at 20 integrity"
	)
	_fail_unless(
		not EonDirectorScript.can_try_again_with_integrity(0),
		"Try again should be blocked at 0 integrity"
	)


func _verify_objective_text() -> void:
	_fail_unless(
		EonDirectorScript.OBJECTIVE_RETRIEVE == "Retrieve the E.O.N",
		"Retrieve objective should use E.O.N display name"
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
