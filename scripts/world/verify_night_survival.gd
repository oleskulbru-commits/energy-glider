extends SceneTree

const DayNightCycleScript = preload("res://scripts/world/day_night_cycle.gd")
const NightSurvivalScript = preload("res://scripts/world/night_survival.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _run_tests() -> void:
	_verify_phase_lengths()
	_verify_night_gate()
	_verify_kill_threshold()
	print("Night survival verification passed.")
	quit(0)


func _verify_phase_lengths() -> void:
	_fail_unless(
		is_equal_approx(DayNightCycleScript.night_starts_at_fraction(180.0, 180.0), 0.5),
		"Equal day/night phases should split the cycle at 0.5"
	)
	_fail_unless(
		is_equal_approx(DayNightCycleScript.night_starts_at_fraction(180.0, 180.0) * 360.0, 180.0),
		"Night should begin after 180 seconds when both phases are 180"
	)


func _verify_night_gate() -> void:
	_fail_unless(
		NightSurvivalScript.NIGHT_WARNING_TEXT
		== "Night has arrived. Get to a relay tower or face the darkness.",
		"Night warning copy mismatch"
	)
	_fail_unless(
		is_equal_approx(NightSurvivalScript.UNPROTECTED_KILL_SEC, 30.0),
		"Unprotected night kill should be 30 seconds"
	)


func _verify_kill_threshold() -> void:
	_fail_unless(
		not NightSurvivalScript.should_kill_unprotected(29.9),
		"Should not kill before 30 unprotected seconds"
	)
	_fail_unless(
		NightSurvivalScript.should_kill_unprotected(30.0),
		"Should kill at 30 unprotected seconds"
	)
	_fail_unless(
		NightSurvivalScript.should_kill_unprotected(45.0),
		"Should kill after 30 unprotected seconds"
	)
