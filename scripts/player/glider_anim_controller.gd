class_name GliderAnimController
extends Node

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const GliderAnimLayerFiltersScript = preload("res://scripts/player/glider_anim_layer_filters.gd")

const BLEND_SPEED_MAX := GliderPhysicsScript.MAX_GROUND_SPEED
const BOOST_TIME_SCALE := 1.35
const JUMP_TIME_SCALE := 0.625

const PARAM_FORWARD_SCALE := "parameters/body/locomotion/forward/time_scale/scale"
const PARAM_STRAFE_LEFT_SCALE := "parameters/body/locomotion/strafe_left/time_scale/scale"
const PARAM_STRAFE_RIGHT_SCALE := "parameters/body/locomotion/strafe_right/time_scale/scale"
const PARAM_BOOST_SCALE := "parameters/body/boost/loop/time_scale/scale"
const PARAM_BRAKE_SCALE := "parameters/body/brake/loop/time_scale/scale"
const PARAM_JUMP_SCALE := "parameters/body/jump/time_scale/scale"
const LOCOMOTION_TRAVEL_MIN_INTERVAL := 0.2
const ROOT_GROUND_XFADE := 0.5
const LOCO_IDLE_ENTER_XFADE := 0.05
const AIR_XFADE := 0.2
const LANDING_EXIT_XFADE := ROOT_GROUND_XFADE
const LANDING_LOCO_XFADE := LANDING_EXIT_XFADE
const JUMP_CLIP := &"Eve_Jump"
const JUMP_FINISH_EPSILON := 0.05

@export var turn_enter: float = 0.05
@export var strafe_enter: float = 0.05
@export var turn_forward_frames: int = 4
@export var speed_scale_min: float = 0.85
@export var speed_scale_max: float = 1.25
@export var grounded_speed_enter: float = 0.3
@export var grounded_speed_exit: float = 0.6
## Brake loop playback scale relative to boost (0.25 = 75% less shake).
@export_range(0.05, 1.0, 0.01) var brake_loop_time_scale: float = 0.25
## Eve_Jump playback scale (0.625 = 25% faster than prior 0.5 setting).
@export_range(0.1, 2.0, 0.01) var jump_time_scale: float = JUMP_TIME_SCALE

@onready var _tree: AnimationTree = get_parent().get_node("AnimationTree")

var _glider: GliderPlayerScript
var _anim_player: AnimationPlayer
var _root_playback: AnimationNodeStateMachinePlayback
var _locomotion_playback: AnimationNodeStateMachinePlayback
var _boost_playback: AnimationNodeStateMachinePlayback
var _brake_playback: AnimationNodeStateMachinePlayback
var _root_state := &""
var _locomotion_state := &"forward"
var _snap_jump_entry := false
var _snap_boost_entry := false
var _snap_boost_loop := false
var _snap_brake_loop := false
var _turn_neutral_frames := 0
var _strafe_neutral_frames := 0
var _locomotion_travel_target := &"forward"
var _queued_locomotion := &"forward"
var _locomotion_travel_cooldown := 0.0
var _root_blend_target := &""
var _root_blend_time := 0.0
var _jump_root_lock := false
var _jump_elapsed := 0.0
var _landing_locomotion_warm := false


func _ready() -> void:
	process_priority = -100
	_glider = _find_glider()
	if _tree == null:
		push_warning("GliderAnimController: AnimationTree node missing on GliderSkin")
		return
	if not _tree.active:
		_tree.active = true
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	GliderAnimLayerFiltersScript.apply(_tree)
	_tree.set("parameters/blend/blend_amount", 1.0)
	_anim_player = _tree.get_node(_tree.anim_player) as AnimationPlayer
	_root_playback = _tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	_locomotion_playback = _tree.get("parameters/body/locomotion/playback") as AnimationNodeStateMachinePlayback
	_boost_playback = _tree.get("parameters/body/boost/playback") as AnimationNodeStateMachinePlayback
	_brake_playback = _tree.get("parameters/body/brake/playback") as AnimationNodeStateMachinePlayback
	if _root_playback != null:
		_bootstrap_playback()


func reset_animation_state() -> void:
	_snap_jump_entry = false
	_snap_boost_entry = false
	_snap_boost_loop = false
	_snap_brake_loop = false
	_turn_neutral_frames = 0
	_root_blend_target = &""
	_root_blend_time = 0.0
	_jump_root_lock = false
	_jump_elapsed = 0.0
	_landing_locomotion_warm = false
	_locomotion_travel_target = &"forward"
	_queued_locomotion = &"forward"
	_locomotion_travel_cooldown = 0.0
	if _tree == null:
		return
	_bootstrap_playback()
	_update_forward_time_scale(0.0)
	_update_boost_time_scale()
	_update_brake_time_scale()
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
	if _brake_playback != null:
		_brake_playback.start("enter")
	_root_blend_target = &""
	_root_blend_time = 0.0
	_jump_root_lock = false
	_jump_elapsed = 0.0
	_landing_locomotion_warm = false
	if _tree != null:
		_tree.advance(0.0)


func _process(_delta: float) -> void:
	if _tree == null or _glider == null or not is_instance_valid(_glider):
		return

	var speed := _glider.get_horizontal_speed()
	var steer := _glider.get_anim_steer()
	var strafe := _glider.get_strafe_axis()

	_update_forward_time_scale(speed)
	_update_boost_time_scale()
	_update_brake_time_scale()
	_update_jump_time_scale()

	var next_root := _pick_root_state(speed)
	if next_root != _root_state:
		var prev_root := _root_state
		var entered_locomotion := next_root == &"locomotion" and prev_root != &"locomotion"
		_root_state = next_root
		if _root_playback != null:
			if _snap_jump_entry:
				_apply_root_start(&"jump")
				_jump_root_lock = true
			elif _snap_boost_entry or _snap_boost_loop:
				_apply_boost_root(_should_instant_root_transition(&"boost"))
			elif _snap_brake_loop:
				_apply_brake_root()
			elif next_root == &"grounded" and prev_root != &"grounded":
				_enter_grounded_idle(prev_root)
			elif prev_root == &"landing":
				_apply_landing_exit_transition(next_root)
			elif next_root == &"locomotion" and prev_root == &"grounded":
				_apply_root_travel(&"locomotion", LOCO_IDLE_ENTER_XFADE)
			elif next_root == &"locomotion" and prev_root == &"brake":
				_apply_root_travel(&"locomotion")
			elif next_root == &"glide" and prev_root == &"jump":
				_apply_root_travel(&"glide", AIR_XFADE)
				_jump_root_lock = false
			elif next_root == &"boost" and prev_root != &"boost":
				_apply_boost_root(_should_instant_root_transition(&"boost"))
			elif next_root == &"brake" and prev_root != &"brake":
				_apply_brake_root()
			elif next_root != prev_root:
				_apply_root_transition(next_root, _should_instant_root_transition(next_root))
				if next_root == &"boost" and _boost_playback != null:
					_start_boost_substate()
				elif next_root == &"brake" and _brake_playback != null:
					_start_brake_substate()
		if entered_locomotion:
			if prev_root == &"grounded":
				_start_locomotion_from_idle(steer, strafe)
			elif prev_root == &"brake":
				_warm_locomotion_for_brake_exit(steer, strafe)
			elif prev_root == &"landing":
				_landing_locomotion_warm = true
				_warm_locomotion_for_landing_exit(steer, strafe)
			else:
				_restart_locomotion(steer, strafe)

	if next_root == &"locomotion":
		_locomotion_travel_cooldown = maxf(0.0, _locomotion_travel_cooldown - _delta)
		if _is_root_blend_active(&"locomotion"):
			if _landing_locomotion_warm and _is_locomotion_playback_stale():
				_warm_locomotion_for_landing_exit(steer, strafe)
		elif _is_locomotion_playback_stale() and _root_state != &"landing":
			if not _is_any_root_blend_active():
				_restart_locomotion(steer, strafe)
		else:
			_update_locomotion(steer, strafe)

	_tick_jump_elapsed(_delta, next_root)

	_repair_brake_enter()
	_repair_root_playback(next_root)
	if _root_playback != null and next_root == &"jump":
		var cur_root := _root_playback.get_current_node()
		if cur_root not in [&"jump", &"glide"] and not _is_jump_to_glide_blend_active():
			_apply_root_start(&"jump")
	if _tree != null:
		_tree.advance(_delta)
		_tick_root_blend(_delta)
		if _root_playback != null:
			var cur_after := _root_playback.get_current_node()
			if cur_after in [&"glide", &"grounded"]:
				_jump_root_lock = false
		_sync_root_playback_after_advance(next_root)


func _is_root_blend_active(target: StringName) -> bool:
	return _root_blend_time > 0.0 and _root_blend_target == target


func _is_any_root_blend_active() -> bool:
	return _root_blend_time > 0.0


func _tick_root_blend(delta: float) -> void:
	if _root_blend_time <= 0.0:
		return
	_root_blend_time = maxf(0.0, _root_blend_time - delta)
	if _root_blend_time > 0.0:
		return
	_on_root_blend_finished()


func _on_root_blend_finished() -> void:
	var finished_target := _root_blend_target
	_root_blend_target = &""
	_landing_locomotion_warm = false
	if finished_target in [&"grounded", &"locomotion"]:
		_prep_boost_brake_nested_after_exit()


func _prep_boost_brake_nested_after_exit() -> void:
	if _boost_playback != null:
		_boost_playback.start("enter")
	if _brake_playback != null:
		_brake_playback.start("enter")


func _apply_root_travel(state: StringName, xfade: float = ROOT_GROUND_XFADE) -> void:
	if _root_playback == null:
		return
	_root_playback.travel(state)
	_root_blend_target = state
	_root_blend_time = xfade


func _apply_root_start(state: StringName) -> void:
	if _root_playback != null:
		_root_playback.start(state)
	_root_blend_target = &""
	_root_blend_time = 0.0
	if state == &"jump":
		_jump_elapsed = 0.0
	elif state != &"jump":
		_jump_root_lock = false


func _apply_root_transition(state: StringName, instant: bool) -> void:
	if instant:
		_apply_root_start(state)
	else:
		_apply_root_travel(state)


func _should_instant_root_transition(state: StringName) -> bool:
	if state == &"jump":
		return true
	if state == &"boost" and _is_airborne_for_boost():
		return true
	return false


func _apply_boost_root(instant: bool) -> void:
	_apply_root_transition(&"boost", instant)
	if _boost_playback != null:
		_start_boost_substate()


func _apply_brake_root() -> void:
	var xfade := ROOT_GROUND_XFADE if _glider.is_grounded() else AIR_XFADE
	_apply_root_travel(&"brake", xfade)
	if _brake_playback != null:
		_start_brake_substate()


func _apply_landing_exit_transition(next_root: StringName) -> void:
	if next_root == &"grounded":
		_enter_grounded_idle(&"landing")
	elif next_root == &"boost":
		_apply_root_travel(&"boost", LANDING_EXIT_XFADE)
		if _boost_playback != null:
			_start_boost_substate()
	elif next_root == &"brake":
		_apply_root_travel(&"brake", LANDING_EXIT_XFADE)
		if _brake_playback != null:
			_start_brake_substate()
	elif next_root == &"locomotion":
		_apply_root_travel(&"locomotion", LANDING_EXIT_XFADE)
	else:
		_apply_root_travel(next_root, LANDING_EXIT_XFADE)


func _enter_grounded_idle(from_state: StringName, instant: bool = false) -> void:
	var use_instant := instant or from_state in [&"grounded", &"", &"Start"]
	if use_instant:
		_prep_boost_brake_nested_after_exit()
	_apply_root_transition(&"grounded", use_instant)


func _sync_root_playback_after_advance(target: StringName) -> void:
	if _root_playback == null or target == &"" or _tree == null:
		return
	var cur := _root_playback.get_current_node()
	if cur == target:
		return
	if _should_skip_root_sync(target, cur):
		return
	if target == &"grounded":
		_enter_grounded_idle(cur, true)
	elif target == &"locomotion" and cur == &"landing":
		if not _is_any_root_blend_active():
			_apply_root_travel(&"locomotion", LANDING_EXIT_XFADE)
	elif target == &"boost":
		_apply_boost_root(true)
	elif target == &"brake":
		_apply_brake_root()
	elif target == &"glide" and cur == &"jump":
		_apply_root_travel(&"glide", AIR_XFADE)
	else:
		_apply_root_transition(target, true)
	_tree.advance(0.0)


func _repair_root_playback(next_root: StringName) -> void:
	if _root_playback == null or next_root == &"":
		return
	var cur := _root_playback.get_current_node()
	if cur == next_root:
		return
	if _should_skip_root_sync(next_root, cur):
		return
	if next_root == &"grounded":
		_enter_grounded_idle(cur)
	elif next_root == &"boost":
		_apply_boost_root(false)
	elif next_root == &"brake":
		_apply_brake_root()
	elif next_root == &"locomotion":
		var loco_xfade := LOCO_IDLE_ENTER_XFADE if cur == &"grounded" else LANDING_EXIT_XFADE if cur == &"landing" else ROOT_GROUND_XFADE
		_apply_root_travel(&"locomotion", loco_xfade)
	elif next_root == &"glide" and cur == &"jump":
		_apply_root_travel(&"glide", AIR_XFADE)
	elif next_root == &"glide":
		_apply_root_travel(&"glide", AIR_XFADE)
	elif next_root == &"jump":
		_apply_root_start(&"jump")


func _repair_brake_enter() -> void:
	if _brake_playback == null or _root_state != &"brake":
		return
	if not _glider.is_braking():
		return
	if _brake_playback.get_current_node() not in [&"enter", &"Start"]:
		return
	_brake_playback.start("loop")


func _pick_root_state(speed: float) -> StringName:
	_snap_jump_entry = false
	_snap_boost_entry = false
	_snap_boost_loop = false
	_snap_brake_loop = false
	if _glider.consume_jump_anim_trigger():
		_discard_pending_boost_triggers()
		_snap_jump_entry = true
		_jump_root_lock = true
		return &"jump"
	if _glider.is_run_ended():
		return &"death"
	var current := _root_playback.get_current_node() if _root_playback != null else &""
	var boost_sub := _boost_playback.get_current_node() if _boost_playback != null else &""
	var brake_sub := _brake_playback.get_current_node() if _brake_playback != null else &""
	if current == &"landing":
		var brake_exit := _landing_brake_exit_state(speed)
		if brake_exit != &"":
			_discard_pending_boost_triggers()
			return brake_exit
		if _is_landing_clip_finished():
			return _landing_exit_state(speed)
		return &"landing"
	if _glider.is_landing() and current == &"locomotion":
		var at_end_exit := _landing_brake_exit_state(speed)
		if at_end_exit != &"":
			_discard_pending_boost_triggers()
			return at_end_exit
	if current == &"jump" and not _is_jump_clip_finished():
		return &"jump"
	if _glider.is_landing() and current != &"locomotion":
		var brake_exit := _landing_brake_exit_state(speed)
		if brake_exit != &"":
			_discard_pending_boost_triggers()
			return brake_exit
		if _is_landing_clip_finished():
			return _landing_exit_state(speed)
		return &"landing"

	if current == &"jump":
		if _glider.is_gliding():
			if _glider.consume_boost_anim_trigger():
				_jump_root_lock = false
				_snap_boost_loop = true
				return &"boost"
			if _glider.consume_brake_anim_trigger() and _should_play_brake_anim(speed):
				_jump_root_lock = false
				_snap_brake_loop = true
				return &"brake"
			if _should_transition_jump_to_glide():
				return &"glide"
		return &"jump"

	if _glider.is_gliding():
		if _glider.consume_boost_anim_trigger():
			_jump_root_lock = false
			_snap_boost_loop = true
			return &"boost"
		if _glider.consume_brake_anim_trigger() and _should_play_brake_anim(speed):
			_jump_root_lock = false
			_snap_brake_loop = true
			return &"brake"
		if _glider.is_boost_active():
			return &"boost"
		if _should_play_brake_anim(speed):
			return &"brake"
		return &"glide"

	if current == &"boost" and boost_sub == &"enter":
		if _glider.is_boost_active():
			return &"boost"
	if _glider.is_boost_active():
		return &"boost"
	if current == &"brake" and brake_sub == &"enter":
		if _should_play_brake_anim(speed):
			return &"brake"
	if _should_play_brake_anim(speed):
		return &"brake"
	if _root_state == &"boost" and boost_sub == &"enter":
		if _glider.is_boost_active():
			return &"boost"
	if _should_play_grounded_idle(speed):
		_discard_pending_boost_triggers()
		return &"grounded"
	if _glider.consume_boost_anim_trigger():
		if _should_start_boost_loop():
			_snap_boost_loop = true
		else:
			_snap_boost_entry = true
		return &"boost"
	if _glider.consume_brake_anim_trigger() and _should_play_brake_anim(speed):
		_snap_brake_loop = true
		return &"brake"
	if _should_prefer_grounded_idle(speed):
		_discard_pending_boost_triggers()
		return &"grounded"
	if _glider.is_braking() and speed >= grounded_speed_exit:
		return &"brake"
	return &"locomotion"


func _discard_pending_boost_triggers() -> void:
	_glider.consume_boost_anim_trigger()
	_glider.consume_brake_anim_trigger()


func _landing_brake_exit_state(speed: float) -> StringName:
	if _should_play_grounded_idle(speed):
		return &"grounded"
	if _glider.is_braking() and _should_play_brake_anim(speed):
		return &"brake"
	return &""


func _landing_exit_state(speed: float) -> StringName:
	var brake_exit := _landing_brake_exit_state(speed)
	if brake_exit != &"":
		return brake_exit
	return &"locomotion"


func _should_transition_jump_to_glide() -> bool:
	return _glider.is_gliding() and _is_jump_clip_finished()


func _tick_jump_elapsed(delta: float, next_root: StringName) -> void:
	if next_root != &"jump":
		return
	if _root_playback == null:
		return
	if _root_playback.get_current_node() == &"jump":
		_jump_elapsed += delta


func _jump_clip_duration() -> float:
	if _anim_player == null or not _anim_player.has_animation(JUMP_CLIP):
		return 0.0
	var clip_length: float = _anim_player.get_animation(JUMP_CLIP).length
	if clip_length <= 0.0 or jump_time_scale <= 0.0:
		return 0.0
	return clip_length / jump_time_scale


func _is_jump_clip_finished() -> bool:
	if _root_playback == null or _root_playback.get_current_node() != &"jump":
		return false
	var duration := _jump_clip_duration()
	if duration > 0.0 and _jump_elapsed >= duration - JUMP_FINISH_EPSILON:
		return true
	if _anim_player != null and _anim_player.current_animation == JUMP_CLIP:
		var ap_length: float = _anim_player.get_animation(JUMP_CLIP).length
		if ap_length > 0.0:
			return _anim_player.current_animation_position >= ap_length - JUMP_FINISH_EPSILON
	return false


func _is_jump_to_glide_blend_active() -> bool:
	return _is_root_blend_active(&"glide") and _root_state in [&"glide", &"jump"]


func _should_skip_root_sync(target: StringName, cur: StringName) -> bool:
	if _is_any_root_blend_active():
		return true
	if target == &"jump" and cur == &"glide" and _glider.is_gliding():
		return true
	if _glider.is_gliding() and target in [&"locomotion", &"grounded"] and cur in [&"jump", &"glide"]:
		return true
	return false


func _is_airborne_for_boost() -> bool:
	return _glider.is_gliding() or not _glider.is_grounded()


func _should_start_boost_loop() -> bool:
	return _is_airborne_for_boost()


func _should_start_brake_loop() -> bool:
	return _glider.is_braking() and not _glider.is_boost_active()


func _start_boost_substate() -> void:
	if _boost_playback == null:
		return
	if _should_start_boost_loop():
		_boost_playback.start("loop")
	else:
		_boost_playback.start("enter")


func _start_brake_substate() -> void:
	if _brake_playback == null:
		return
	if _should_start_brake_loop():
		_brake_playback.start("loop")
	else:
		_brake_playback.start("enter")


func _should_play_brake_anim(speed: float) -> bool:
	if not _glider.is_braking():
		return false
	if _glider.is_boost_active():
		return false
	return speed >= grounded_speed_exit


func _should_play_grounded_idle(speed: float) -> bool:
	if not _glider.is_grounded():
		return false
	if _should_play_brake_anim(speed):
		return false
	if _glider.is_braking():
		if _root_state == &"grounded":
			return speed < grounded_speed_exit
		return speed < grounded_speed_exit
	if _glider.is_forward_held():
		return false
	if _root_state == &"grounded":
		return speed < grounded_speed_exit
	return speed < grounded_speed_enter


func _should_prefer_grounded_idle(speed: float) -> bool:
	if not _glider.is_grounded():
		return false
	if _glider.is_braking():
		return speed < grounded_speed_exit
	if _glider.is_forward_held():
		return false
	if _glider.is_boost_active() or _should_play_brake_anim(speed):
		return false
	return speed < grounded_speed_exit


func _is_landing_clip_finished() -> bool:
	if _root_playback == null or _root_playback.get_current_node() != &"landing":
		return false
	var length := _root_playback.get_current_length()
	if length <= 0.0:
		return false
	return _root_playback.get_current_play_position() >= length - 0.05


func _restart_locomotion(steer: float, strafe: float) -> void:
	_locomotion_travel_cooldown = 0.0
	_turn_neutral_frames = 0
	_strafe_neutral_frames = 0
	if _locomotion_playback == null:
		return
	var desired := _pick_locomotion_state(steer, strafe, &"forward")
	_locomotion_state = desired
	_queued_locomotion = desired
	_locomotion_travel_target = desired
	# Nested locomotion stops updating while root is in air/landing; start() rewinds it.
	_locomotion_playback.start(desired)


func _warm_locomotion_for_landing_exit(steer: float, strafe: float) -> void:
	_warm_locomotion_substate(steer, strafe)
	if _tree != null:
		_tree.advance(0.0)


func _warm_locomotion_for_brake_exit(steer: float, strafe: float) -> void:
	_warm_locomotion_substate(steer, strafe)


func _warm_locomotion_substate(steer: float, strafe: float) -> void:
	_locomotion_travel_cooldown = 0.0
	_turn_neutral_frames = 0
	_strafe_neutral_frames = 0
	if _locomotion_playback == null:
		return
	var playback_state := _get_locomotion_playback_state()
	var desired := _pick_locomotion_state(steer, strafe, playback_state)
	_locomotion_state = desired
	_queued_locomotion = desired
	_locomotion_travel_target = desired
	_locomotion_playback.start(desired)


func _start_locomotion_from_idle(steer: float, strafe: float) -> void:
	_locomotion_travel_cooldown = 0.0
	_turn_neutral_frames = 0
	_strafe_neutral_frames = 0
	if _locomotion_playback == null:
		return
	var desired := _pick_locomotion_state(steer, strafe, &"forward")
	_locomotion_state = desired
	_queued_locomotion = desired
	_locomotion_travel_target = desired
	_locomotion_playback.start("enter")


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


func _update_locomotion(steer: float, strafe: float) -> void:
	if _locomotion_playback == null:
		return
	if _locomotion_playback.get_current_node() == &"enter":
		return

	var playback_state := _get_locomotion_playback_state()
	var next_locomotion := _pick_locomotion_state(steer, strafe, playback_state)
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


func _pick_locomotion_state(steer: float, strafe: float, current: StringName) -> StringName:
	if current == &"strafe_left" and strafe <= -strafe_enter:
		_strafe_neutral_frames = 0
		_turn_neutral_frames = 0
		return &"strafe_right"
	if current == &"strafe_right" and strafe >= strafe_enter:
		_strafe_neutral_frames = 0
		_turn_neutral_frames = 0
		return &"strafe_left"
	if strafe >= strafe_enter:
		_strafe_neutral_frames = 0
		_turn_neutral_frames = 0
		return &"strafe_left"
	if strafe <= -strafe_enter:
		_strafe_neutral_frames = 0
		_turn_neutral_frames = 0
		return &"strafe_right"
	if current == &"strafe_left" or current == &"strafe_right":
		_strafe_neutral_frames += 1
		if _strafe_neutral_frames < turn_forward_frames:
			return current
	_strafe_neutral_frames = 0

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


func _is_forward_locomotion_state(state: StringName) -> bool:
	return state in [&"forward", &"strafe_left", &"strafe_right"]


func _update_forward_time_scale(speed: float) -> void:
	if not _is_forward_locomotion_state(_get_locomotion_playback_state()):
		return
	var speed_t := clampf(speed / BLEND_SPEED_MAX, 0.0, 1.0)
	var scale := lerpf(speed_scale_min, speed_scale_max, speed_t)
	_tree.set(PARAM_FORWARD_SCALE, scale)
	_tree.set(PARAM_STRAFE_LEFT_SCALE, scale)
	_tree.set(PARAM_STRAFE_RIGHT_SCALE, scale)


func _update_jump_time_scale() -> void:
	_tree.set(PARAM_JUMP_SCALE, jump_time_scale)


func _update_boost_time_scale() -> void:
	var scale := BOOST_TIME_SCALE if _root_state == &"boost" else 1.0
	_tree.set(PARAM_BOOST_SCALE, scale)


func _update_brake_time_scale() -> void:
	var scale := compute_brake_loop_time_scale(
		BOOST_TIME_SCALE,
		brake_loop_time_scale,
		_root_state == &"brake"
	)
	_tree.set(PARAM_BRAKE_SCALE, scale)


static func compute_brake_loop_time_scale(
	boost_time_scale: float,
	brake_loop_scale: float,
	in_brake_root: bool
) -> float:
	if not in_brake_root:
		return 1.0
	return boost_time_scale * brake_loop_scale


static func compute_boost_loop_time_scale(
	boost_time_scale: float,
	_brake_shake_scale: float,
	in_boost_root: bool,
	boost_active: bool,
	braking: bool
) -> float:
	if not in_boost_root:
		return 1.0
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
