extends SceneTree

const GodJuiceDirectorScript = preload("res://scripts/game/god_juice_director.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _run_tests() -> void:
	_verify_integrity_loss()
	_verify_try_again_gate()
	print("God juice verification passed.")
	quit(0)


func _verify_integrity_loss() -> void:
	_fail_unless(
		GodJuiceDirectorScript.apply_death_integrity_loss(100) == 80,
		"First death should reduce integrity to 80"
	)
	_fail_unless(
		GodJuiceDirectorScript.apply_death_integrity_loss(20) == 0,
		"Integrity should clamp at 0"
	)
	_fail_unless(
		GodJuiceDirectorScript.apply_death_integrity_loss(0) == 0,
		"Zero integrity should stay at 0"
	)


func _verify_try_again_gate() -> void:
	_fail_unless(
		GodJuiceDirectorScript.can_try_again_with_integrity(100),
		"Try again should be allowed at 100 integrity"
	)
	_fail_unless(
		GodJuiceDirectorScript.can_try_again_with_integrity(20),
		"Try again should be allowed at 20 integrity"
	)
	_fail_unless(
		not GodJuiceDirectorScript.can_try_again_with_integrity(0),
		"Try again should be blocked at 0 integrity"
	)
