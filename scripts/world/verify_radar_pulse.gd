extends SceneTree

const RadarPulseScript = preload("res://scripts/player/radar_pulse.gd")


class MockPoi extends RefCounted:
	var ripple_index: int = 0
	var active: bool = true

	func is_pulse_target_active() -> bool:
		return active

	func get_radar_beacon():
		return null


func _init() -> void:
	call_deferred("_run_tests")


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _run_tests() -> void:
	_fail_unless(is_equal_approx(RadarPulseScript.COOLDOWN_SEC, 5.0), "Cooldown should be 5 seconds")

	var all_active: Array = []
	var poi0 := MockPoi.new()
	poi0.ripple_index = 0
	var poi1 := MockPoi.new()
	poi1.ripple_index = 1
	var poi2 := MockPoi.new()
	poi2.ripple_index = 2
	all_active.append(poi0)
	all_active.append(poi1)
	all_active.append(poi2)
	_fail_unless(
		RadarPulseScript.resolve_target_ripple(all_active) == 0,
		"Target ripple should be 0 when all bands are active"
	)

	poi0.active = false
	_fail_unless(
		RadarPulseScript.resolve_target_ripple(all_active) == 1,
		"Target ripple should advance to 1 when ripple 0 is depleted"
	)

	poi1.active = false
	poi2.active = false
	_fail_unless(
		RadarPulseScript.resolve_target_ripple(all_active) == -1,
		"Target ripple should be -1 when all POIs are depleted"
	)

	print("Radar pulse verification passed.")
	quit(0)
