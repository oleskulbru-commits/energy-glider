extends SceneTree

const DayNightCycleScript = preload("res://scripts/world/day_night_cycle.gd")
const NightSurvivalScript = preload("res://scripts/world/night_survival.gd")
const ExpeditionStateScript = preload("res://scripts/game/expedition_state.gd")


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
	_verify_natural_dawn_day_advance()
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


func _verify_natural_dawn_day_advance() -> void:
	_fail_unless(
		not ExpeditionStateScript.should_advance_on_natural_dawn(false, false),
		"Natural dawn before the first E.O.N. should not increment DAY"
	)
	_fail_unless(
		ExpeditionStateScript.should_advance_on_natural_dawn(true, false),
		"Surviving the night should increment DAY"
	)
	_fail_unless(
		not ExpeditionStateScript.should_advance_on_natural_dawn(true, true),
		"Death screen should not increment DAY at dawn"
	)

	var cycle: DayNightCycle = DayNightCycleScript.new()
	root.add_child(cycle)
	var dawn_count := {"n": 0}
	var natural_count := {"n": 0}
	cycle.dawn.connect(func() -> void: dawn_count["n"] += 1)
	cycle.natural_dawn.connect(func() -> void: natural_count["n"] += 1)
	cycle.skip_to_dawn()
	_fail_unless(dawn_count["n"] == 1, "Wait until dawn should still emit dawn")
	_fail_unless(natural_count["n"] == 0, "skip_to_dawn must not count as a survived night")
	cycle.call("_emit_phase_transitions", 0.99, 0.01)
	_fail_unless(natural_count["n"] == 1, "Wrapping from night into day should emit natural_dawn")
	_fail_unless(dawn_count["n"] == 2, "Natural dawn should still emit dawn")

	var expedition: ExpeditionState = ExpeditionStateScript.new()
	root.add_child(expedition)
	expedition.bootstrap_day()
	_fail_unless(expedition.current_day == 1, "Run should start on DAY 1")
	expedition.call("_on_natural_dawn")
	_fail_unless(expedition.current_day == 2, "Gliding through the night should start DAY 2")
	expedition.end_day()
	_fail_unless(expedition.current_day == 3, "Wait until dawn should still increment DAY")
	cycle.free()
	expedition.free()
