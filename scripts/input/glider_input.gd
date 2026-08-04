class_name GliderInput
extends Node

## PC keyboard input via project InputMap actions.

var _locomotion_enabled := true
var _boost_input_enabled := true
var _brake_ui_held := false
var _sail_deployed := false


func is_forward_held() -> bool:
	if not _locomotion_enabled:
		return false
	return Input.is_action_pressed("move_forward")


func is_boost_held() -> bool:
	if not _locomotion_enabled or not _boost_input_enabled:
		return false
	return Input.is_action_pressed("boost")


func is_brake_held() -> bool:
	if not _locomotion_enabled:
		return false
	return _brake_ui_held or Input.is_action_pressed("brake")


func is_sail_deployed() -> bool:
	return _sail_deployed


func set_sail_deployed(active: bool) -> void:
	_sail_deployed = active


func set_locomotion_enabled(enabled: bool) -> void:
	_locomotion_enabled = enabled
	if not enabled:
		set_sail_deployed(false)


func set_boost_input_enabled(enabled: bool) -> void:
	_boost_input_enabled = enabled


func set_brake_ui_hold(active: bool) -> void:
	_brake_ui_held = active


func get_steer() -> float:
	if not _locomotion_enabled:
		return 0.0
	return Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")


func is_steering() -> bool:
	return absf(get_steer()) > 0.01


func is_jump_just_pressed() -> bool:
	if not _locomotion_enabled:
		return false
	return Input.is_action_just_pressed("jump")


func is_radar_pulse_just_pressed() -> bool:
	if not _locomotion_enabled:
		return false
	return Input.is_action_just_pressed("radar_pulse")


func _process(_delta: float) -> void:
	_update_sail_state()


func _update_sail_state() -> void:
	if not _locomotion_enabled:
		set_sail_deployed(false)
		return
	set_sail_deployed(is_forward_held() and not is_boost_held())
