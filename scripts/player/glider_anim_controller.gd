class_name GliderAnimController
extends Node

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const GliderAnimLayerFiltersScript = preload("res://scripts/player/glider_anim_layer_filters.gd")

const BLEND_SPEED_MAX := GliderPhysicsScript.MAX_GROUND_SPEED
const BOOST_TIME_SCALE := 1.35
const JUMP_TIME_SCALE := 0.625

const PARAM_FORWARD_SCALE := "parameters/body/locomotion/forward/time_scale/scale"
const PARAM_BOOST_SCALE := "parameters/body/boost/loop/time_scale/scale"
const PARAM_JUMP_SCALE := "parameters/body/jump/time_scale/scale"
const LOCOMOTION_TRAVEL_MIN_INTERVAL := 0.2

@export var turn_enter: float = 0.05
@export var turn_forward_frames: int = 4
@export var speed_scale_min: float = 0.85
@export var speed_scale_max: float = 1.25
@export var grounded_speed_enter: float = 0.3
@export var grounded_speed_exit: float = 0.6
## Brake reuses Eve_Boost; scale loop playback to this fraction of boost speed (0.25 = 75% less shake).
@export_range(0.05, 1.0, 0.01) var brake_boost_shake_scale: float = 0.25
## Eve_Jump playback scale (0.625 = 25% faster than prior 0.5 setting).
@export_range(0.1, 2.0, 0.01) var jump_time_scale: float = JUMP_TIME_SCALE

@onready var _tree: AnimationTree = get_parent().get_node("AnimationTree")

var _glider: GliderPlayerScript
var _root_playback: AnimationNodeStateMachinePlayback
var _locomotion_playback: AnimationNodeStateMachinePlayback
var _boost_playback: AnimationNodeStateMachinePlayback
var _root_state := &""
var _locomotion_state := &"forward"
var _snap_jump_entry := false
var _snap_boost_entry := false
var _snap_boost_loop := false
var _turn_neutral_frames := 0
var _locomotion_travel_target := &"forward"
var _queued_locomotion := &"forward"
var _locomotion_travel_cooldown := 0.0


func _ready() -> void:
	_glider = _find_glider()
	if _tree == null:
		push_warning("GliderAnimController: AnimationTree node missing on GliderSkin")
		return
	if not _tree.active:
		_tree.active = true
	GliderAnimLayerFiltersScript.apply(_tree)
	_tree.set("parameters/blend/blend_amount", 1.0)
	_root_playback = _tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	_locomotion_playback = _tree.get("parameters/body/locomotion/playback") as AnimationNodeStateMachinePlayback
	_boost_playback = _tree.get("parameters/body/boost/playback") as AnimationNodeStateMachinePlayback
	if _root_playback != null:
		_bootstrap_playback()


func reset_animation_state() -> void:
	_snap_jump_entry = false
	_snap_boost_entry = false
	_snap_boost_loop = false
	_turn_neutral_frames = 0
	_locomotion_travel_target = &"forward"
	_queued_locomotion = &"forward"
	_locomotion_travel_cooldown = 0.0
	if _tree == null:
		return
	_bootstrap_playback()
	_update_forward_time_scale(0.0)
	_update_boost_time_scale()
	_update_jump_time_scale()


func _bootstrap_playback() -> void:
	if _root_playback != null:
		_root_playback.start("grounded")
		_root_state = &"grounded"
	if _locomotion_playback != null:
		_locomotion_playback.start("forward")
		_locomotion_state = &"forward"
		_locomotion_travel_target = &"forward"
		_queued_locomotion = &"forward"
		_locomotion_travel_cooldown = 0.0
	if _boost_playback != null:
		_boost_playback.start("enter")


func _physics_process(_delta: float) -> void:
	if _tree == null or _glider == null or not is_instance_valid(_glider):
		return

	var speed := _glider.get_horizontal_speed()
	var steer := _glider.get_anim_steer()

	_update_forward_time_scale(speed)
	_update_boost_time_scale()
	_update_jump_time_scale()

	var next_root := _pick_root_state(speed)
	if next_root != _root_state:
		var entered_locomotion := next_root == &"locomotion" and _root_state != &"locomotion"
		_root_state = next_root
		if _root_playback != null:
			if _snap_jump_entry:
				_root_playback.start("jump")
			elif _snap_boost_entry:
				_root_playback.travel("boost")
				if _boost_playback != null:
					_boost_playback.start("enter")
			elif _snap_boost_loop:
				_root_playback.travel("boost")
				if _boost_playback != null:
					_boost_playback.start("loop")
			else:
				_root_playback.travel(next_root)
				if next_root == &"boost" and _boost_playback != null:
					_start_boost_substate()
		if entered_locomotion:
			_restart_locomotion(steer)

	if next_root == &"locomotion":
		_locomotion_travel_cooldown = maxf(0.0, _locomotion_travel_cooldown - _delta)
		if _is_locomotion_playback_stale():
			_restart_locomotion(steer)
		else:
			_update_locomotion(steer)

	_repair_brake_boost_enter()


func _repair_brake_boost_enter() -> void:
	if _boost_playback == null or _root_state != &"boost":
		return
	if _glider.is_boost_active():
		return
	if not _glider.is_braking():
		return
	if _boost_playback.get_current_node() not in [&"enter", &"Start"]:
		return
	_boost_playback.start("loop")


func _pick_root_state(speed: float) -> StringName:
	_snap_jump_entry = false
	_snap_boost_entry = false
	_snap_boost_loop = false
	if _glider.is_run_ended():
		return &"death"
	var current := _root_playback.get_current_node() if _root_playback != null else &""
	var boost_sub := _boost_playback.get_current_node() if _boost_playback != null else &""
	if current == &"landing":
		if _is_landing_clip_finished():
			return &"locomotion"
		return &"landing"
	if _glider.is_landing() and current != &"locomotion":
		if _is_landing_clip_finished():
			return &"locomotion"
		return &"landing"

	if _glider.is_gliding():
		if _should_hold_jump_playback(current):
			return &"jump"
		if _glider.consume_jump_anim_trigger():
			_snap_jump_entry = true
			return &"jump"
		if _glider.is_boost_active() or _should_play_brake_boost(speed):
			return &"boost"
		if _glider.consume_boost_anim_trigger() or (
			_glider.consume_brake_anim_trigger() and _should_play_brake_boost(speed)
		):
			_snap_boost_loop = true
			return &"boost"
		return &"glide"

	if current == &"boost" and boost_sub == &"enter":
		if _glider.is_boost_active() or _should_play_brake_boost(speed):
			return &"boost"
	if _glider.is_boost_active() or _should_play_brake_boost(speed):
		return &"boost"
	if _root_state == &"boost" and boost_sub == &"enter":
		if _glider.is_boost_active() or _should_play_brake_boost(speed):
			return &"boost"
	if _glider.consume_boost_anim_trigger() or (
		_glider.consume_brake_anim_trigger() and _should_play_brake_boost(speed)
	):
		if _should_start_boost_loop():
			_snap_boost_loop = true
		else:
			_snap_boost_entry = true
		return &"boost"
	if _should_play_grounded_idle(speed):
		return &"grounded"
	return &"locomotion"


func _should_hold_jump_playback(current: StringName) -> bool:
	if current == &"jump":
		return true
	return _root_state == &"jump" and current != &"glide"


func _is_airborne_for_boost() -> bool:
	return _glider.is_gliding() or not _glider.is_grounded()


func _should_start_boost_loop() -> bool:
	if _is_airborne_for_boost():
		return true
	return _glider.is_braking() and not _glider.is_boost_active()


func _start_boost_substate() -> void:
	if _boost_playback == null:
		return
	if _should_start_boost_loop():
		_boost_playback.start("loop")
	else:
		_boost_playback.start("enter")


func _should_play_brake_boost(speed: float) -> bool:
	if not _glider.is_braking():
		return false
	if _root_state == &"boost" and not _glider.is_boost_active():
		return speed >= grounded_speed_exit
	return speed >= grounded_speed_enter


func _should_play_grounded_idle(speed: float) -> bool:
	if not _glider.is_grounded():
		return false
	if _glider.is_forward_held():
		return false
	if _should_play_brake_boost(speed):
		return false
	if _glider.is_braking():
		return true
	if _root_state == &"grounded":
		return speed < grounded_speed_exit
	return speed < grounded_speed_enter


func _is_landing_clip_finished() -> bool:
	if _root_playback == null or _root_playback.get_current_node() != &"landing":
		return false
	var length := _root_playback.get_current_length()
	if length <= 0.0:
		return false
	return _root_playback.get_current_play_position() >= length - 0.05


func _restart_locomotion(steer: float) -> void:
	_locomotion_travel_cooldown = 0.0
	_turn_neutral_frames = 0
	if _locomotion_playback == null:
		return
	var desired := _pick_locomotion_state(steer, &"forward")
	_locomotion_state = desired
	_queued_locomotion = desired
	_locomotion_travel_target = desired
	# Nested locomotion stops updating while root is in air/landing; start() rewinds it.
	_locomotion_playback.start(desired)


func _is_locomotion_playback_stale() -> bool:
	if _locomotion_playback == null:
		return true
	var node := _locomotion_playback.get_current_node()
	return node == StringName() or node == &"Start"


func _get_locomotion_playback_state() -> StringName:
	if _locomotion_playback == null:
		return _locomotion_state
	var node := _locomotion_playback.get_current_node()
	if node == StringName() or node == &"Start":
		return _locomotion_state
	return node


func _update_locomotion(steer: float) -> void:
	if _locomotion_playback == null:
		return

	var playback_state := _get_locomotion_playback_state()
	var next_locomotion := _pick_locomotion_state(steer, playback_state)
	_locomotion_state = next_locomotion
	_queued_locomotion = next_locomotion

	if _locomotion_travel_cooldown > 0.0:
		return

	_flush_locomotion_travel()


func _flush_locomotion_travel() -> void:
	if _locomotion_playback == null:
		return
	if _queued_locomotion == _locomotion_travel_target and not _is_locomotion_playback_stale():
		return
	_locomotion_travel_target = _queued_locomotion
	_locomotion_travel_cooldown = LOCOMOTION_TRAVEL_MIN_INTERVAL
	_apply_locomotion_transition(_queued_locomotion)


func _apply_locomotion_transition(state: StringName) -> void:
	if _locomotion_playback == null:
		return
	if _is_locomotion_playback_stale():
		_locomotion_playback.start(state)
	else:
		_locomotion_playback.travel(state)


func _pick_locomotion_state(steer: float, current: StringName) -> StringName:
	if current == &"turn_left" and steer >= turn_enter:
		_turn_neutral_frames = 0
		return &"turn_right"
	if current == &"turn_right" and steer <= -turn_enter:
		_turn_neutral_frames = 0
		return &"turn_left"
	if steer <= -turn_enter:
		_turn_neutral_frames = 0
		return &"turn_left"
	if steer >= turn_enter:
		_turn_neutral_frames = 0
		return &"turn_right"
	if current == &"turn_left" or current == &"turn_right":
		_turn_neutral_frames += 1
		if _turn_neutral_frames < turn_forward_frames:
			return current
	_turn_neutral_frames = 0
	return &"forward"


func _update_forward_time_scale(speed: float) -> void:
	if _get_locomotion_playback_state() != &"forward":
		return
	var speed_t := clampf(speed / BLEND_SPEED_MAX, 0.0, 1.0)
	var scale := lerpf(speed_scale_min, speed_scale_max, speed_t)
	_tree.set(PARAM_FORWARD_SCALE, scale)


func _update_jump_time_scale() -> void:
	_tree.set(PARAM_JUMP_SCALE, jump_time_scale)


func _update_boost_time_scale() -> void:
	_tree.set(
		PARAM_BOOST_SCALE,
		compute_boost_loop_time_scale(
			BOOST_TIME_SCALE,
			brake_boost_shake_scale,
			_root_state == &"boost",
			_glider.is_boost_active(),
			_glider.is_braking()
		)
	)


static func compute_boost_loop_time_scale(
	boost_time_scale: float,
	brake_shake_scale: float,
	in_boost_root: bool,
	boost_active: bool,
	braking: bool
) -> float:
	if not in_boost_root:
		return 1.0
	if braking and not boost_active:
		return boost_time_scale * brake_shake_scale
	return boost_time_scale


func _find_glider() -> GliderPlayerScript:
	var node: Node = get_parent()
	while node != null:
		if node is GliderPlayerScript:
			return node as GliderPlayerScript
		if node.get_parent() is GliderPlayerScript:
			return node.get_parent() as GliderPlayerScript
		node = node.get_parent()
	return null
