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
	_verify_sun_arc()
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
		== "Night has arrived. Get to an upgrade tower or face the darkness.",
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


func _verify_sun_arc() -> void:
	var day_phase := 240.0
	var night_phase := 240.0
	var day_fraction := DayNightCycleScript.night_starts_at_fraction(day_phase, night_phase)
	var max_elev := 32.0
	var boot_t := 20.0 / (day_phase + night_phase)

	var boot_pos := DayNightCycleScript.sun_position_for_time(boot_t, day_fraction, max_elev)
	_fail_unless(boot_pos.y > 0.0, "Boot sun should be above the horizon (got y=%.3f)" % boot_pos.y)

	var noon_pos := DayNightCycleScript.sun_position_for_time(day_fraction * 0.5, day_fraction, max_elev)
	_fail_unless(
		is_equal_approx(rad_to_deg(asin(clampf(noon_pos.y, -1.0, 1.0))), max_elev, 0.5),
		"Noon sun elevation should match max (got %.1f deg)" % rad_to_deg(asin(noon_pos.y))
	)
	_fail_unless(noon_pos.z > 0.5, "Noon sun should be in the southern sky (+Z)")

	var dawn_pos := DayNightCycleScript.sun_position_for_time(0.0, day_fraction, max_elev)
	_fail_unless(dawn_pos.x > 0.5, "Dawn sun should rise in the east (+X)")

	var dusk_pos := DayNightCycleScript.sun_position_for_time(
		day_fraction - 0.001,
		day_fraction,
		max_elev
	)
	_fail_unless(dusk_pos.x < -0.5, "Dusk sun should set in the west (-X)")
