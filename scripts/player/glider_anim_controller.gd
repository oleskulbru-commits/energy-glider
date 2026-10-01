class_name GliderAnimController
extends Node

const GliderAnimClipsScript = preload("res://scripts/player/glider_anim_clips.gd")
const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const GliderAnimLayerFiltersScript = preload("res://scripts/player/glider_anim_layer_filters.gd")
const GliderFootIkScript = preload("res://scripts/player/glider_foot_ik.gd")
const BLEND_SPEED_MAX := GliderPhysicsScript.MAX_GROUND_SPEED
const BOOST_TIME_SCALE := 1.35
const JUMP_TIME_SCALE := 0.625

const PARAM_MOVE_SCALE := "parameters/body/locomotion/move/time_scale/scale"
const PARAM_BLEND_POSITION := "parameters/body/locomotion/move/blend_space/blend_position"
const PARAM_GLIDE_BLEND := "parameters/body/glide/blend_space/blend_position"
const LOCO_BLEND_NEUTRAL := Vector2(0.0, 0.0)
const LOCO_BLEND_FORWARD := Vector2(0.0, 1.0)
const LOCO_BLEND_TURN_LEFT := Vector2(-1.0, 0.0)
const LOCO_BLEND_TURN_RIGHT := Vector2(1.0, 0.0)
const LOCO_BLEND_STRAFE_LEFT := Vector2(-1.0, 1.0)
const LOCO_BLEND_STRAFE_RIGHT := Vector2(1.0, 1.0)
const PARAM_BOOST_SCALE := "parameters/body/boost/loop/time_scale/scale"
const PARAM_BOOST_ENTER_SEEK := "parameters/body/boost/enter/seek/seek_request"
const PARAM_BOOST_ENTER_SCALE := "parameters/body/boost/enter/time_scale/scale"
const PARAM_BOOST_EXIT_SEEK := "parameters/body/boost/exit/seek/seek_request"
const PARAM_BOOST_EXIT_SCALE := "parameters/body/boost/exit/time_scale/scale"
const PARAM_LOCO_ENTER_SEEK := "parameters/body/locomotion/enter/seek/seek_request"
const PARAM_LOCO_ENTER_SCALE := "parameters/body/locomotion/enter/time_scale/scale"
const PARAM_LOCO_EXIT_SEEK := "parameters/body/locomotion/exit/seek/seek_request"
const PARAM_LOCO_EXIT_SCALE := "parameters/body/locomotion/exit/time_scale/scale"
const PARAM_BRAKE_SCALE := "parameters/body/brake/loop/time_scale/scale"
const CLIP_FORWARD_TO_BOOST := "Eve_Forward_To_Boost"
const CLIP_IDLE_TO_FORWARD := "Eve_Idle_To_Forward"
const PARAM_JUMP_SCALE := "parameters/body/jump/time_scale/scale"
const PARAM_JUMP_SEEK := "parameters/body/jump/seek/seek_request"
const PARAM_JUMP_CHARGE_SCALE := "parameters/body/jump_charge/time_scale/scale"
const PARAM_JUMP_CHARGE_SEEK := "parameters/body/jump_charge/seek/seek_request"
const LOCOMOTION_TRAVEL_MIN_INTERVAL := 0.2
## Locomotion / glide clip blend (BlendSpace position), not nested SM travel cooldown.
const DEFAULT_LOCO_BLEND_XFADE := 0.40
const DEFAULT_GLIDE_BLEND_XFADE := 0.28
const DEFAULT_ANIM_STEER_INPUT_SMOOTH := 0.35
const DEFAULT_ANIM_STEER_TRANSITION_SMOOTH := 0.06
const ROOT_GROUND_XFADE := 0.5
const LOCO_IDLE_ENTER_XFADE := 0.05
const AIR_XFADE := 0.2
const BRAKE_EXIT_XFADE := AIR_XFADE
const LANDING_EXIT_XFADE := ROOT_GROUND_XFADE
const LANDING_LOCO_XFADE := LANDING_EXIT_XFADE
const JUMP_CLIP := &"Eve_Jump"
const JUMP_FINISH_EPSILON := 0.05
const JUMP_CHARGE_XFADE := 0.5
const JUMP_CHARGE_ENTER_XFADE := 0.12
const JUMP_ENTER_XFADE := 0.05
const JUMP_FROM_LOCO_XFADE := AIR_XFADE
## Max wait for body playback to settle on jump after travel() (boost->jump xfade).
const JUMP_ENTRY_SETTLE_SEC := AIR_XFADE + 0.15
## Force body root onto _root_state if playback stays mismatched after crossfade.
const ROOT_DESYNC_FORCE_SEC := 0.65
const NESTED_ENTER_END_EPSILON := 0.05

@export var use_blendspace_locomotion := true
@export var blendspace_xfade := DEFAULT_LOCO_BLEND_XFADE
@export var glide_blend_xfade := DEFAULT_GLIDE_BLEND_XFADE
## Smooth steer/strafe when releasing input back to neutral.
@export var anim_steer_input_smooth := DEFAULT_ANIM_STEER_INPUT_SMOOTH
## Forward→steer and steer↔steer (same rate; faster than visual roll-in).
@export var anim_steer_transition_smooth := DEFAULT_ANIM_STEER_TRANSITION_SMOOTH
@export var turn_enter: float = 0.05
@export var strafe_enter: float = 0.05
## Max airborne lean into turn clips (0 = pure Eve_Glide, 1 = full turn clip).
@export_range(0.0, 1.0, 0.01) var air_steer_lean := 0.35
## Ignore small steer noise before applying air lean.
@export_range(0.0, 0.5, 0.01) var air_steer_enter := 0.05
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
@onready var _foot_ik: GliderFootIkScript = get_parent().get_node_or_null("GliderFootIk") as GliderFootIkScript

var _glider: GliderPlayerScript
var _anim_player: AnimationPlayer
var _root_playback: AnimationNodeStateMachinePlayback
var _locomotion_playback: AnimationNodeStateMachinePlayback
var _boost_playback: AnimationNodeStateMachinePlayback
var _brake_playback: AnimationNodeStateMachinePlayback
var _root_state := &""
var _locomotion_state := &"move"
var _blendspace_position := LOCO_BLEND_FORWARD
var _glide_blend_position := 0.0
var _legacy_blend_target := LOCO_BLEND_FORWARD
var _legacy_locomotion_state := &"forward"
var _snap_jump_entry := false
var _snap_jump_charge_entry := false
var _snap_boost_entry := false
var _snap_boost_loop := false
var _snap_brake_loop := false
var _turn_neutral_frames := 0
var _strafe_neutral_frames := 0
var _locomotion_travel_target := &"move"
var _queued_locomotion := &"move"
var _locomotion_travel_cooldown := 0.0
var _root_blend_target := &""
var _root_blend_time := 0.0
var _jump_root_lock := false
var _jump_elapsed := 0.0
var _jump_entry_in_flight := false
var _jump_entry_realtime := 0.0
var _jump_from_boost_takeoff := false
var _locomotion_crossfade_warm := false
var _root_desync_elapsed := 0.0
var _nested_exit_active := false
var _nested_exit_kind := &""
var _pending_root_after_exit := &""
var _pending_root_xfade := ROOT_GROUND_XFADE
var _nested_exit_started_at := -1.0
var _smoothed_anim_steer := 0.0
var _smoothed_anim_strafe := 0.0


func _ready() -> void:
	process_priority = 100
	_glider = _find_glider()
	if _tree == null:
		push_warning("GliderAnimController: AnimationTree node missing on GliderSkin")
		return
	if not _tree.active:
		_tree.active = true
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	GliderAnimLayerFiltersScript.apply(_tree)
	_tree.set("parameters/blend/blend_amount", 1.0)
	_update_foot_ik(&"")
	_set_blendspace_position(_blendspace_position)
	_anim_player = _tree.get_node(_tree.anim_player) as AnimationPlayer
	GliderAnimClipsScript.apply_loop_linear(_anim_player)
	_root_playback = _tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	_locomotion_playback = _tree.get("parameters/body/locomotion/playback") as AnimationNodeStateMachinePlayback
	_boost_playback = _tree.get("parameters/body/boost/playback") as AnimationNodeStateMachinePlayback
	_brake_playback = _tree.get("parameters/body/brake/playback") as AnimationNodeStateMachinePlayback
	if _root_playback != null:
		_bootstrap_playback()


func force_landing_reaction() -> void:
	if _root_playback == null or _tree == null or _glider == null:
		return
	if not _glider.is_grounded():
		return
	_locomotion_crossfade_warm = false
	_jump_root_lock = false
	_apply_root_start(&"landing")
	_root_state = &"landing"
	_advance_animation_tree(0.0)


func get_body_root_state() -> StringName:
	return _root_state


func can_accept_body_jump() -> bool:
	if _tree == null or _glider == null or _root_playback == null:
		return false
	if _nested_exit_active:
		return false
	if _is_jump_entry_active():
		return false
	if (
		_glider.is_gliding()
		and _is_any_root_blend_active()
		and not _is_root_blend_active(&"jump")
	):
		return false
	return not _landing_blocks_jump()


## Same-frame jump root travel after physics sets the anim trigger (avoids 1-frame lag).
func apply_jump_trigger_immediate() -> void:
	if _tree == null or _glider == null or _root_playback == null:
		return
	if not can_accept_body_jump():
		return
	if not _glider.consume_jump_anim_trigger():
		return
	var prev_root := _root_state
	_discard_pending_boost_triggers()
	_snap_jump_entry = true
	_jump_root_lock = true
	if _glider.is_boost_active() or prev_root == &"boost":
		_jump_from_boost_takeoff = true
	_root_state = &"jump"
	_apply_jump_root(_jump_travel_from_state(prev_root))
	_advance_animation_tree(0.0)


func reset_animation_state() -> void:
	_snap_jump_entry = false
	_snap_jump_charge_entry = false
	_snap_boost_entry = false
	_snap_boost_loop = false
	_snap_brake_loop = false
	_turn_neutral_frames = 0
	_root_blend_target = &""
	_root_blend_time = 0.0
	_jump_root_lock = false
	_jump_elapsed = 0.0
	_jump_entry_in_flight = false
	_jump_entry_realtime = 0.0
	_jump_from_boost_takeoff = false
	_locomotion_crossfade_warm = false
	_locomotion_travel_target = &"move"
	_queued_locomotion = &"move"
	_legacy_locomotion_state = &"forward"
	_legacy_blend_target = LOCO_BLEND_FORWARD
	_blendspace_position = LOCO_BLEND_FORWARD
	_glide_blend_position = 0.0
	_smoothed_anim_steer = 0.0
	_smoothed_anim_strafe = 0.0
	_locomotion_travel_cooldown = 0.0
	_root_desync_elapsed = 0.0
	_nested_exit_active = false
	_nested_exit_kind = &""
	_pending_root_after_exit = &""
	_nested_exit_started_at = -1.0
	if _tree == null:
		return
	_bootstrap_playback()
	_update_forward_time_scale(0.0)
	_update_boost_time_scale()
	_update_brake_time_scale()
	_update_jump_time_scale()
	_reset_jump_charge_pose()


func _reset_jump_charge_pose() -> void:
	if _tree == null:
		return
	_tree.set(PARAM_JUMP_CHARGE_SEEK, 0.0)
	_tree.set(PARAM_JUMP_CHARGE_SCALE, 0.0)


func _prepare_jump_playback(continue_from_charge: bool = false) -> void:
	if _tree == null:
		return
	_update_jump_time_scale()
	if continue_from_charge and _root_playback != null:
		_tree.set(PARAM_JUMP_SEEK, _root_playback.get_current_play_position())
		_reset_jump_charge_pose()
	else:
		_tree.set(PARAM_JUMP_SEEK, 0.0)


func _bootstrap_playback() -> void:
	if _root_playback != null:
		_root_playback.start("grounded")
		_root_state = &"grounded"
	if _locomotion_playback != null:
		_locomotion_playback.start("move")
		_locomotion_state = &"move"
		_legacy_locomotion_state = &"forward"
		_legacy_blend_target = LOCO_BLEND_FORWARD
		_blendspace_position = LOCO_BLEND_FORWARD
		_locomotion_travel_target = &"move"
		_queued_locomotion = &"move"
		_locomotion_travel_cooldown = 0.0
		_set_blendspace_position(_blendspace_position)
	_set_glide_blend_position(_glide_blend_position)
	if _boost_playback != null:
		_reset_boost_enter_forward()
		_boost_playback.start("enter")
	if _brake_playback != null:
		_brake_playback.start("enter")
	_reset_boost_exit_params()
	_reset_loco_exit_params()
	_root_blend_target = &""
	_root_blend_time = 0.0
	_jump_root_lock = false
	_jump_elapsed = 0.0
	_jump_entry_in_flight = false
	_jump_entry_realtime = 0.0
	_locomotion_crossfade_warm = false
	_advance_animation_tree(0.0)


func _process(_delta: float) -> void:
	if _tree == null or _glider == null or not is_instance_valid(_glider):
		return

	var speed := _glider.get_horizontal_speed()
	var steer := _smooth_anim_steer_input(_glider.get_anim_steer(), _delta)
	var strafe := _smooth_anim_strafe_input(_glider.get_strafe_axis(), _delta)

	_update_forward_time_scale(speed)
	_update_boost_time_scale()
	_update_brake_time_scale()
	_update_jump_time_scale()
	_tick_jump_entry_watchdog(_delta)
	_reconcile_stale_jump_root()

	if _nested_exit_active:
		_advance_animation_tree(_delta)
		_tick_root_blend(_delta)
		if _nested_exit_kind == &"boost" and _is_boost_exit_finished():
			_finish_boost_exit(steer, strafe)
		elif _nested_exit_kind == &"locomotion" and _is_loco_exit_finished():
			_finish_loco_exit()
		_update_foot_ik(_root_state)
		return

	var next_root := _pick_root_state(speed)
	if (
		not _glider.is_boost_active()
		and _is_root_blend_active(&"boost")
		and not _is_jump_entry_active()
	):
		next_root = &"glide"
	var deferred_exit := false
	if next_root != _root_state:
		var prev_root := _root_state
		var entered_locomotion := next_root == &"locomotion" and prev_root != &"locomotion"
		if (
			prev_root == &"boost"
			and next_root != &"boost"
			and next_root != &"jump"
			and not _jump_from_boost_takeoff
		):
			deferred_exit = _try_begin_boost_exit(next_root, _xfade_for_boost_exit(prev_root, next_root))
		elif next_root == &"grounded" and prev_root == &"locomotion":
			deferred_exit = _try_begin_loco_exit()
		if not deferred_exit:
			_root_state = next_root
		if _root_playback != null and not deferred_exit:
			if _snap_jump_entry:
				_apply_jump_root(_jump_travel_from_state(prev_root))
			elif _snap_jump_charge_entry:
				_apply_jump_charge_root()
			elif prev_root == &"jump_charge" and next_root in [&"locomotion", &"grounded", &"boost", &"brake"]:
				if next_root == &"grounded":
					_enter_grounded_idle(prev_root)
				elif next_root == &"locomotion":
					_apply_root_travel(&"locomotion", JUMP_CHARGE_XFADE)
				elif next_root == &"boost":
					_apply_root_travel(&"boost", JUMP_CHARGE_XFADE)
					if _boost_playback != null:
						_start_boost_substate()
				elif next_root == &"brake":
					_apply_root_travel(&"brake", JUMP_CHARGE_XFADE)
					if _brake_playback != null:
						_start_brake_substate()
			elif _snap_boost_entry or _snap_boost_loop:
				_apply_boost_root(_should_instant_root_transition(&"boost"))
			elif _snap_brake_loop:
				_apply_brake_root()
			elif next_root == &"grounded" and prev_root != &"grounded":
				if prev_root != &"locomotion":
					_enter_grounded_idle(prev_root)
			elif prev_root == &"landing":
				_apply_landing_exit_transition(next_root)
			elif next_root == &"locomotion" and prev_root == &"grounded":
				_apply_root_travel(&"locomotion", LOCO_IDLE_ENTER_XFADE)
			elif next_root == &"locomotion" and prev_root == &"brake":
				_apply_root_travel(&"locomotion", BRAKE_EXIT_XFADE)
			elif next_root == &"glide" and prev_root == &"jump":
				_apply_root_travel(&"glide", AIR_XFADE)
				_jump_root_lock = false
				_jump_entry_in_flight = false
			elif next_root == &"glide" and prev_root == &"boost":
				_apply_root_travel(&"glide", AIR_XFADE)
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
		if entered_locomotion and not deferred_exit:
			if prev_root == &"grounded":
				_start_locomotion_from_idle(steer, strafe)
			elif prev_root == &"brake":
				_locomotion_crossfade_warm = true
				_warm_locomotion_for_brake_exit(steer, strafe)
			elif prev_root == &"landing":
				_locomotion_crossfade_warm = true
				_warm_locomotion_for_landing_exit(steer, strafe)
			else:
				_restart_locomotion(steer, strafe)

	if deferred_exit:
		_advance_animation_tree(_delta)
		_tick_root_blend(_delta)
		if _nested_exit_kind == &"boost" and _is_boost_exit_finished():
			_finish_boost_exit(steer, strafe)
		elif _nested_exit_kind == &"locomotion" and _is_loco_exit_finished():
			_finish_loco_exit()
		_update_foot_ik(_root_state)
		return

	if next_root == &"locomotion":
		_locomotion_travel_cooldown = maxf(0.0, _locomotion_travel_cooldown - _delta)
		if _is_root_blend_active(&"locomotion"):
			if _is_locomotion_playback_stale():
				_warm_locomotion_substate(steer, strafe)
			else:
				_update_locomotion(steer, strafe, _delta)
		elif _is_locomotion_playback_stale() and _root_state != &"landing":
			if not _is_any_root_blend_active():
				_restart_locomotion(steer, strafe)
		else:
			_update_locomotion(steer, strafe, _delta)

	if _should_update_glide_steer(next_root):
		_update_glide_steer(steer, _delta)

	_update_foot_ik(next_root)

	_tick_jump_elapsed(_delta, next_root)

	_repair_brake_enter()
	_repair_boost_loop()
	_repair_root_playback(next_root)
	if _root_playback != null and next_root == &"jump_charge":
		var charge_root := _root_playback.get_current_node()
		if charge_root != &"jump_charge":
			_apply_jump_charge_root()
	if _tree != null:
		_advance_animation_tree(_delta)
		_tick_root_blend(_delta)
		if _root_playback != null:
			var cur_after := _root_playback.get_current_node()
			if cur_after in [&"glide", &"grounded"]:
				if not (_glider.is_gliding() and _is_jump_entry_active()):
					if not _glider.is_jump_anim_pending():
						_jump_root_lock = false
						_jump_entry_in_flight = false
		_repair_boost_loop()
		_repair_brake_enter()
		_repair_root_desync_watchdog(next_root)
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
	_locomotion_crossfade_warm = false
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
	var cur := _root_playback.get_current_node()
	if cur == state:
		_root_blend_target = &""
		_root_blend_time = 0.0
		return
	if _root_blend_target == state and _root_blend_time > 0.0:
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


func _apply_jump_charge_root() -> void:
	_reset_jump_charge_pose()
	_apply_root_travel(&"jump_charge", JUMP_CHARGE_ENTER_XFADE)


func _jump_travel_from_state(fallback: StringName) -> StringName:
	if _root_playback == null:
		return fallback
	var cur := _root_playback.get_current_node()
	if cur == StringName() or cur == &"Start":
		return fallback
	return cur


func _jump_entry_xfade(from_state: StringName) -> float:
	match from_state:
		&"jump_charge":
			return JUMP_ENTER_XFADE
		&"boost":
			return JUMP_FROM_LOCO_XFADE
		&"grounded", &"locomotion", &"brake":
			return JUMP_FROM_LOCO_XFADE
		_:
			return JUMP_ENTER_XFADE


func _apply_jump_root(from_state: StringName) -> void:
	var from_charge := from_state == &"jump_charge"
	var from_boost := from_state == &"boost"
	_prepare_jump_playback(from_charge)
	var boost_takeoff := (
		from_boost
		or (from_charge and _glider != null and _glider.is_boost_active())
	)
	if from_charge and not boost_takeoff:
		# jump_charge and jump share Eve_Jump; travel() can stall on the same clip.
		_apply_root_start(&"jump")
	else:
		_apply_root_travel(&"jump", _jump_entry_xfade(from_state if from_boost else &"boost" if boost_takeoff else from_state))
	_jump_from_boost_takeoff = boost_takeoff
	_jump_root_lock = true
	_jump_elapsed = 0.0
	_jump_entry_in_flight = true
	_jump_entry_realtime = 0.0


func _is_jump_entry_active() -> bool:
	if _jump_entry_in_flight:
		return true
	return _is_root_blend_active(&"jump")


func _tick_jump_entry_watchdog(delta: float) -> void:
	if not _jump_entry_in_flight:
		return
	_jump_entry_realtime += delta
	if _jump_entry_realtime < JUMP_ENTRY_SETTLE_SEC:
		return
	_jump_entry_in_flight = false


func _reconcile_stale_jump_root() -> void:
	if _root_playback == null:
		return
	if not _jump_root_lock and not _jump_entry_in_flight:
		return
	if _is_jump_entry_active():
		return
	var cur := _root_playback.get_current_node()
	if cur == &"jump":
		return
	if cur not in [&"glide", &"locomotion", &"grounded", &"boost", &"brake"]:
		return
	_jump_root_lock = false
	_jump_entry_in_flight = false
	_jump_entry_realtime = 0.0
	if _root_state == &"jump":
		_root_state = cur


func _is_jump_playback_settled() -> bool:
	if _root_playback == null:
		return true
	var cur := _root_playback.get_current_node()
	if cur == &"jump":
		_jump_entry_in_flight = false
		return true
	if _jump_entry_in_flight:
		if _jump_entry_realtime >= JUMP_ENTRY_SETTLE_SEC:
			_jump_entry_in_flight = false
			return true
		return false
	if _is_root_blend_active(&"jump"):
		return true
	if _is_jump_to_glide_blend_active():
		return true
	return false


func _apply_root_transition(state: StringName, instant: bool) -> void:
	if instant:
		_apply_root_start(state)
	else:
		_apply_root_travel(state)


func _should_instant_root_transition(_state: StringName) -> bool:
	return false


func _apply_boost_root(instant: bool) -> void:
	if _is_airborne_for_boost():
		_apply_root_travel(&"boost", AIR_XFADE)
	elif instant:
		_apply_root_start(&"boost")
	else:
		_apply_root_travel(&"boost")
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
		if target == &"boost":
			_repair_boost_loop()
		return
	if _should_skip_root_sync(target, cur):
		return
	if target == &"grounded":
		_enter_grounded_idle(cur, true)
	elif target == &"locomotion" and cur == &"landing":
		if not _is_any_root_blend_active():
			_apply_root_travel(&"locomotion", LANDING_EXIT_XFADE)
	elif target == &"boost":
		_apply_boost_root(_should_instant_root_transition(&"boost"))
	elif target == &"glide" and cur == &"boost":
		_apply_root_travel(&"glide", AIR_XFADE)
	elif target == &"brake":
		_apply_brake_root()
	elif target == &"glide" and cur == &"jump":
		_apply_root_travel(&"glide", AIR_XFADE)
	elif target == &"jump":
		if not _is_jump_playback_settled():
			_apply_jump_root(cur)
	else:
		_apply_root_transition(target, true)
	_advance_animation_tree(0.0)


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
		var loco_xfade := LOCO_IDLE_ENTER_XFADE if cur == &"grounded" else LANDING_EXIT_XFADE if cur == &"landing" else BRAKE_EXIT_XFADE if cur == &"brake" else JUMP_CHARGE_XFADE if cur == &"jump_charge" else ROOT_GROUND_XFADE
		_apply_root_travel(&"locomotion", loco_xfade)
	elif next_root == &"glide" and cur == &"jump":
		_apply_root_travel(&"glide", AIR_XFADE)
	elif next_root == &"glide":
		_apply_root_travel(&"glide", AIR_XFADE)
	elif next_root == &"jump":
		if not _is_jump_playback_settled():
			_apply_jump_root(cur)
	elif next_root == &"jump_charge":
		_apply_jump_charge_root()


func _repair_brake_enter() -> void:
	if _brake_playback == null or _root_state != &"brake":
		return
	if not _glider.is_braking():
		return
	var sub := _brake_playback.get_current_node()
	if sub == &"loop":
		return
	if sub not in [&"enter", &"Start"]:
		return
	if not _should_start_brake_loop() and not _nested_enter_clip_finished(_brake_playback):
		return
	_brake_playback.start("loop")
	_advance_animation_tree(0.0)


func _repair_boost_loop() -> void:
	if _boost_playback == null or _root_state != &"boost":
		return
	if not _glider.is_boost_active():
		return
	var sub := _boost_playback.get_current_node()
	if sub == &"loop":
		return
	if sub not in [&"enter", &"Start"]:
		return
	if _nested_enter_clip_finished(_boost_playback):
		_boost_playback.start(&"loop")
		_advance_animation_tree(0.0)
		return
	if _is_airborne_for_boost():
		_boost_playback.start(&"loop")
		_advance_animation_tree(0.0)


func _nested_enter_clip_finished(playback: AnimationNodeStateMachinePlayback) -> bool:
	var length := playback.get_current_length()
	if length <= 0.0:
		return false
	return playback.get_current_play_position() >= length - NESTED_ENTER_END_EPSILON


func _repair_root_desync_watchdog(target: StringName) -> void:
	if _root_playback == null or target == &"":
		_root_desync_elapsed = 0.0
		return
	var cur := _root_playback.get_current_node()
	if cur == target:
		_root_desync_elapsed = 0.0
		return
	if _should_skip_root_sync(target, cur):
		return
	_root_desync_elapsed += get_process_delta_time()
	if _root_desync_elapsed < ROOT_DESYNC_FORCE_SEC:
		return
	_root_desync_elapsed = 0.0
	_force_root_playback_to(target, cur)


func _force_root_playback_to(target: StringName, _cur: StringName) -> void:
	_root_blend_target = &""
	_root_blend_time = 0.0
	_jump_entry_in_flight = false
	match target:
		&"boost":
			_apply_root_start(&"boost")
			if _boost_playback != null:
				_start_boost_substate()
		&"brake":
			_apply_root_start(&"brake")
			if _brake_playback != null:
				_start_brake_substate()
		&"jump":
			_apply_root_start(&"jump")
		&"grounded":
			_prep_boost_brake_nested_after_exit()
			_apply_root_start(&"grounded")
		&"locomotion":
			_apply_root_start(&"locomotion")
			if _locomotion_playback != null:
				_locomotion_playback.start("move")
		&"glide":
			_apply_root_start(&"glide")
		&"jump_charge":
			_reset_jump_charge_pose()
			_apply_root_start(&"jump_charge")
		_:
			_apply_root_start(target)
	_advance_animation_tree(0.0)


func is_landing_anim_blocking_jump() -> bool:
	return _landing_blocks_jump()


func _landing_blocks_jump() -> bool:
	if _root_playback == null:
		if _glider != null and _glider.is_landing() and _glider.is_grounded():
			return true
		return false
	var cur := _root_playback.get_current_node()
	if cur == &"landing" and not _is_landing_clip_finished():
		return true
	if _is_root_blend_active(&"locomotion") and cur == &"landing":
		return true
	if _glider != null and _glider.is_landing() and _glider.is_grounded():
		return true
	return false


func _pick_root_state(speed: float) -> StringName:
	_snap_jump_entry = false
	_snap_jump_charge_entry = false
	_snap_boost_entry = false
	_snap_boost_loop = false
	_snap_brake_loop = false
	if not _landing_blocks_jump() and _glider.consume_jump_anim_trigger():
		_discard_pending_boost_triggers()
		_snap_jump_entry = true
		_jump_root_lock = true
		if _glider.is_boost_active() or _root_state == &"boost":
			_jump_from_boost_takeoff = true
		return &"jump"
	if _should_hold_boost_jump_takeoff():
		return &"jump"
	if _glider.is_jump_charging():
		_snap_jump_charge_entry = _root_state != &"jump_charge"
		return &"jump_charge"
	if _glider.is_run_ended():
		return &"death"
	if _is_jump_entry_active():
		return &"jump"
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
			if not _jump_from_boost_takeoff:
				if _glider.consume_boost_anim_trigger():
					_jump_root_lock = false
					_snap_boost_loop = true
					return &"boost"
				if _glider.consume_brake_anim_trigger() and _should_play_brake_anim(speed):
					_jump_root_lock = false
					_snap_brake_loop = true
					return &"brake"
			if _should_transition_jump_to_glide():
				_jump_root_lock = false
				_jump_from_boost_takeoff = false
				if _glider.is_boost_active():
					_snap_boost_loop = true
					return &"boost"
				return &"glide"
		if not _is_jump_clip_finished():
			return &"jump"
		return _jump_finished_exit_state(speed)

	if _glider.is_gliding():
		if _should_prefer_jump_over_glide(current):
			return &"jump"
		if _should_defer_air_boost():
			return &"jump"
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
	if _should_hold_boost_jump_takeoff():
		return &"jump"
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
	return _glider.is_gliding() and not _jump_entry_in_flight and _is_jump_clip_finished()


func _jump_finished_exit_state(_speed: float) -> StringName:
	_jump_root_lock = false
	_jump_entry_in_flight = false
	_jump_entry_realtime = 0.0
	var from_boost := _jump_from_boost_takeoff
	_jump_from_boost_takeoff = false
	if _glider.is_gliding():
		if _glider.is_boost_active() or from_boost:
			_snap_boost_loop = true
			return &"boost"
		return &"glide"
	if _glider.is_boost_active():
		_snap_boost_loop = true
		return &"boost"
	return &"locomotion"


func _should_defer_air_boost() -> bool:
	return _should_hold_boost_jump_takeoff()


func _should_hold_boost_jump_takeoff() -> bool:
	if not _jump_from_boost_takeoff:
		return false
	if _is_jump_clip_finished():
		return false
	if _jump_entry_in_flight:
		return true
	if _is_root_blend_active(&"jump"):
		return true
	if _root_state == &"jump" and _jump_root_lock:
		return true
	return false


func _should_prefer_jump_over_glide(current: StringName) -> bool:
	if not _glider.is_gliding():
		return false
	if _is_jump_entry_active():
		return true
	if current in [&"jump_charge", &"boost", &"brake", &"locomotion", &"grounded"]:
		if _jump_entry_in_flight or _jump_root_lock or _root_state == &"jump":
			return not _is_jump_clip_finished()
	if _is_root_blend_active(&"jump"):
		return true
	if _jump_root_lock or _root_state == &"jump":
		return not _is_jump_clip_finished()
	return false


func _tick_jump_elapsed(delta: float, next_root: StringName) -> void:
	if next_root != &"jump" and _root_state != &"jump":
		return
	if _root_playback == null:
		return
	var cur := _root_playback.get_current_node()
	if cur == &"jump" or _is_root_blend_active(&"jump"):
		_jump_elapsed += delta


func _jump_clip_duration() -> float:
	if _anim_player == null or not _anim_player.has_animation(JUMP_CLIP):
		return 0.0
	var clip_length: float = _anim_player.get_animation(JUMP_CLIP).length
	if clip_length <= 0.0 or jump_time_scale <= 0.0:
		return 0.0
	return clip_length / jump_time_scale


func _is_jump_clip_finished() -> bool:
	if _jump_entry_in_flight:
		return false
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
	if target == &"jump" and (cur == &"jump" or _is_root_blend_active(&"jump")):
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
	var target: StringName = &"loop" if _should_start_boost_loop() else &"enter"
	var current := _boost_playback.get_current_node()
	if current == target:
		return
	if current == &"enter" and target == &"enter":
		return
	if target == &"enter":
		_reset_boost_enter_forward()
	_boost_playback.start(target)
	_advance_animation_tree(0.0)


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
	_ensure_move_locomotion_playback(true)
	_apply_locomotion_target(steer, strafe, true)


func _warm_locomotion_for_landing_exit(steer: float, strafe: float) -> void:
	_warm_locomotion_substate(steer, strafe, false)


func _warm_locomotion_for_brake_exit(steer: float, strafe: float) -> void:
	_warm_locomotion_substate(steer, strafe, false)


func _warm_locomotion_for_boost_exit(steer: float, strafe: float) -> void:
	_warm_locomotion_substate(steer, strafe, false)


func _warm_locomotion_substate(steer: float, strafe: float, instant: bool = false) -> void:
	_locomotion_travel_cooldown = 0.0
	_turn_neutral_frames = 0
	_strafe_neutral_frames = 0
	if _locomotion_playback == null:
		return
	_ensure_move_locomotion_playback(instant)
	_apply_locomotion_target(steer, strafe, instant)
	_advance_animation_tree(0.0)


func _start_locomotion_from_idle(steer: float, strafe: float) -> void:
	_locomotion_travel_cooldown = 0.0
	_turn_neutral_frames = 0
	_strafe_neutral_frames = 0
	if _locomotion_playback == null:
		return
	_legacy_locomotion_state = _pick_locomotion_state(steer, strafe, &"forward")
	_locomotion_state = &"enter"
	_queued_locomotion = &"move"
	_locomotion_travel_target = &"move"
	_reset_loco_enter_forward()
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


func _update_locomotion(steer: float, strafe: float, delta: float) -> void:
	if _locomotion_playback == null:
		return
	if _locomotion_playback.get_current_node() == &"enter":
		return
	_ensure_move_locomotion_playback()
	if use_blendspace_locomotion:
		_update_locomotion_blendspace_smooth(steer, strafe, delta)
	else:
		_update_locomotion_legacy_snap(steer, strafe, delta)


func _ensure_move_locomotion_playback(instant: bool = false) -> void:
	if _locomotion_playback == null:
		return
	var node := _locomotion_playback.get_current_node()
	if node == &"move":
		_locomotion_state = &"move"
		return
	if node == &"enter":
		return
	if node == &"exit":
		_reset_loco_exit_params()
	if instant:
		_locomotion_playback.start("move")
	else:
		_locomotion_playback.travel("move")
	_locomotion_state = &"move"
	_queued_locomotion = &"move"
	_locomotion_travel_target = &"move"


func _apply_locomotion_target(steer: float, strafe: float, instant: bool) -> void:
	var target := _compute_locomotion_blend_target(steer, strafe)
	if not use_blendspace_locomotion:
		_legacy_locomotion_state = _pick_locomotion_state(steer, strafe, _legacy_locomotion_state)
		_legacy_blend_target = target
	_step_blendspace_toward(target, get_process_delta_time(), instant)


func _compute_locomotion_blend_target(steer: float, strafe: float) -> Vector2:
	var speed := _glider.get_horizontal_speed() if _glider != null else 0.0
	if use_blendspace_locomotion:
		return _compute_blendspace_target(steer, strafe, speed)
	return locomotion_state_to_blend(_pick_locomotion_state(steer, strafe, _legacy_locomotion_state))


func _smooth_anim_steer_input(raw: float, delta: float) -> float:
	_smoothed_anim_steer = _smooth_anim_axis_for_blend(
		raw, _smoothed_anim_steer, delta, turn_enter
	)
	return _smoothed_anim_steer


func _smooth_anim_strafe_input(raw: float, delta: float) -> float:
	_smoothed_anim_strafe = _smooth_anim_axis_for_blend(
		raw, _smoothed_anim_strafe, delta, strafe_enter
	)
	return _smoothed_anim_strafe


func _smooth_anim_axis_for_blend(
	raw: float, smoothed: float, delta: float, enter_threshold: float
) -> float:
	if anim_steer_input_smooth <= 0.0 and anim_steer_transition_smooth <= 0.0:
		return raw
	var wants_input := absf(raw) > enter_threshold
	var tau := anim_steer_transition_smooth if wants_input else anim_steer_input_smooth
	if tau <= 0.0:
		return raw
	var t := clampf(delta / tau, 0.0, 1.0)
	return lerpf(smoothed, raw, t)


func _blendspace_lerp_weight(delta: float) -> float:
	if blendspace_xfade <= 0.0:
		return 1.0
	return clampf(delta / blendspace_xfade, 0.0, 1.0)


func _glide_blend_lerp_weight(delta: float) -> float:
	if glide_blend_xfade <= 0.0:
		return 1.0
	return clampf(delta / glide_blend_xfade, 0.0, 1.0)


func _step_blendspace_toward(target: Vector2, delta: float, instant: bool) -> void:
	if instant:
		_blendspace_position = target
	else:
		_blendspace_position = _blendspace_position.lerp(target, _blendspace_lerp_weight(delta))
	_set_blendspace_position(_blendspace_position)


func _update_locomotion_blendspace_smooth(steer: float, strafe: float, delta: float) -> void:
	var target := _compute_blendspace_target(
		steer,
		strafe,
		_glider.get_horizontal_speed() if _glider != null else 0.0
	)
	_step_blendspace_toward(target, delta, false)


func _update_locomotion_legacy_snap(steer: float, strafe: float, delta: float) -> void:
	var desired := _pick_locomotion_state(steer, strafe, _legacy_locomotion_state)
	if desired != _legacy_locomotion_state or _is_locomotion_playback_stale():
		if _locomotion_travel_cooldown <= 0.0:
			_legacy_locomotion_state = desired
			_legacy_blend_target = locomotion_state_to_blend(desired)
			_locomotion_travel_target = &"move"
			_locomotion_travel_cooldown = LOCOMOTION_TRAVEL_MIN_INTERVAL
	_step_blendspace_toward(_legacy_blend_target, delta, false)


func _compute_blendspace_target(steer: float, strafe: float, speed: float) -> Vector2:
	var x := _compute_blendspace_x(steer, strafe)
	var y := _compute_forward_commit(speed)
	if y < 0.2:
		x = clampf(x * 1.35, -1.0, 1.0)
	return Vector2(x, y)


func _compute_blendspace_x(steer: float, strafe: float) -> float:
	if absf(strafe) > strafe_enter:
		# Input strafe_left is +1 but Eve_Turn_Left lives at negative X in the blend space.
		return clampf(-strafe, -1.0, 1.0)
	return clampf(steer, -1.0, 1.0)


func _compute_forward_commit(speed: float) -> float:
	if _glider != null and _glider.is_forward_held():
		return 1.0
	if speed >= grounded_speed_enter:
		return clampf(speed / BLEND_SPEED_MAX, 0.35, 0.85)
	return 0.0


func _set_blendspace_position(position: Vector2) -> void:
	if _tree == null:
		return
	_tree.set(PARAM_BLEND_POSITION, position)


func _set_glide_blend_position(position: float) -> void:
	if _tree == null:
		return
	_tree.set(PARAM_GLIDE_BLEND, position)


func _advance_animation_tree(delta: float) -> void:
	if _tree == null:
		return
	_tree.advance(delta)


func _update_foot_ik(next_root: StringName) -> void:
	if _foot_ik == null or not _foot_ik.is_configured() or _root_playback == null:
		return
	var body := _root_playback.get_current_node()
	var active := _should_run_leg_ik(body, next_root)
	_foot_ik.set_leg_ik_active(active)


func _should_run_leg_ik(body: StringName, next_root: StringName) -> bool:
	if _jump_from_boost_takeoff and (body == &"jump" or next_root == &"jump"):
		return false
	if _leg_ik_for_body_state(body):
		return true
	if body == &"boost" and _glider != null and not _glider.is_grounded():
		return false
	if next_root == &"":
		return false
	return _leg_ik_for_body_state(next_root)


func _leg_ik_for_body_state(body: StringName) -> bool:
	if body == &"locomotion" and _get_locomotion_playback_state() == &"move":
		return true
	if body == &"boost" and _glider != null and _glider.is_grounded():
		return true
	if body == &"brake" and _glider != null and _brake_leg_ik():
		return true
	if body in [&"jump", &"jump_charge", &"glide", &"landing"]:
		return true
	return false


func _brake_leg_ik() -> bool:
	return _glider.is_grounded() or _glider.is_gliding()


func _should_update_glide_steer(next_root: StringName) -> bool:
	if _glider == null or not _glider.is_gliding():
		return false
	return next_root in [&"jump", &"glide"]


func _update_glide_steer(steer: float, delta: float) -> void:
	var axis := clampf(steer, -1.0, 1.0)
	if absf(axis) < air_steer_enter:
		axis = 0.0
	var target := axis * air_steer_lean
	if glide_blend_xfade <= 0.0:
		_glide_blend_position = target
	else:
		_glide_blend_position = lerpf(
			_glide_blend_position,
			target,
			_glide_blend_lerp_weight(delta)
		)
	_set_glide_blend_position(_glide_blend_position)


func get_glide_blend_position() -> float:
	return _glide_blend_position


static func locomotion_state_to_blend(state: StringName) -> Vector2:
	match state:
		&"turn_left":
			return LOCO_BLEND_TURN_LEFT
		&"turn_right":
			return LOCO_BLEND_TURN_RIGHT
		&"strafe_left":
			return LOCO_BLEND_STRAFE_LEFT
		&"strafe_right":
			return LOCO_BLEND_STRAFE_RIGHT
		_:
			return LOCO_BLEND_FORWARD


func get_blendspace_position() -> Vector2:
	return _blendspace_position


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
	return state in [&"move", &"enter"]


func _update_forward_time_scale(speed: float) -> void:
	if not _is_forward_locomotion_state(_get_locomotion_playback_state()):
		return
	var speed_t := clampf(speed / BLEND_SPEED_MAX, 0.0, 1.0)
	var scale := lerpf(speed_scale_min, speed_scale_max, speed_t)
	_tree.set(PARAM_MOVE_SCALE, scale)


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


func _clip_length(clip_name: String) -> float:
	if _anim_player == null:
		return 0.0
	var anim := _anim_player.get_animation(StringName(clip_name))
	if anim == null:
		return 0.0
	return anim.length


func _reset_boost_enter_forward() -> void:
	if _tree == null:
		return
	_tree.set(PARAM_BOOST_ENTER_SEEK, 0.0)
	_tree.set(PARAM_BOOST_ENTER_SCALE, 1.0)


func _reset_boost_exit_params() -> void:
	if _tree == null:
		return
	_tree.set(PARAM_BOOST_EXIT_SEEK, 0.0)
	_tree.set(PARAM_BOOST_EXIT_SCALE, 1.0)


func _reset_loco_enter_forward() -> void:
	if _tree == null:
		return
	_tree.set(PARAM_LOCO_ENTER_SEEK, 0.0)
	_tree.set(PARAM_LOCO_ENTER_SCALE, 1.0)


func _reset_loco_exit_params() -> void:
	if _tree == null:
		return
	_tree.set(PARAM_LOCO_EXIT_SEEK, 0.0)
	_tree.set(PARAM_LOCO_EXIT_SCALE, 1.0)


func _seek_for_boost_reverse(sub: StringName) -> float:
	var length := _clip_length(CLIP_FORWARD_TO_BOOST)
	if length <= 0.0 or _boost_playback == null:
		return 0.0
	if sub == &"loop":
		return maxf(length - 0.05, 0.0)
	if sub in [&"enter", &"exit"]:
		var pos := clampf(_boost_playback.get_current_play_position(), 0.0, length)
		if pos > 0.02:
			return pos
	return maxf(length - 0.05, 0.0)


func _seek_for_loco_reverse(sub: StringName) -> float:
	var length := _clip_length(CLIP_IDLE_TO_FORWARD)
	if length <= 0.0 or _locomotion_playback == null:
		return 0.0
	if sub == &"move":
		return maxf(length - 0.05, 0.0)
	if sub in [&"enter", &"exit"]:
		var pos := clampf(_locomotion_playback.get_current_play_position(), 0.0, length)
		if pos > 0.02:
			return pos
	return maxf(length - 0.05, 0.0)


func _reset_locomotion_for_grounded_blend(steer: float, strafe: float) -> void:
	if _locomotion_playback == null or _tree == null:
		return
	_reset_loco_exit_params()
	_reset_loco_enter_forward()
	_locomotion_travel_cooldown = 0.0
	_locomotion_state = &"move"
	_queued_locomotion = &"move"
	_locomotion_travel_target = &"move"
	_locomotion_playback.start(&"move")
	_apply_locomotion_target(steer, strafe, true)
	_advance_animation_tree(0.0)


func _xfade_for_boost_exit(_prev: StringName, next: StringName) -> float:
	match next:
		&"glide":
			return AIR_XFADE
		&"locomotion":
			return AIR_XFADE
		&"brake":
			return AIR_XFADE
		&"grounded":
			return ROOT_GROUND_XFADE
		_:
			return ROOT_GROUND_XFADE


func _try_begin_boost_exit(target: StringName, xfade: float) -> bool:
	if _boost_playback == null or _tree == null:
		return false
	if _clip_length(CLIP_FORWARD_TO_BOOST) <= 0.0:
		return false
	var sub := _boost_playback.get_current_node()
	if sub in [&"Start", &""]:
		return false
	_pending_root_after_exit = target
	_pending_root_xfade = xfade
	if sub == &"exit":
		_ensure_boost_exit_reverse_playback()
		_arm_nested_boost_exit(false)
		return true
	var seek := _seek_for_boost_reverse(sub)
	_tree.set(PARAM_BOOST_EXIT_SEEK, seek)
	_tree.set(PARAM_BOOST_EXIT_SCALE, -1.0)
	_arm_nested_boost_exit(true)
	_boost_playback.travel(&"exit")
	_advance_animation_tree(0.0)
	return true


func _try_begin_loco_exit() -> bool:
	if _locomotion_playback == null or _tree == null:
		return false
	var sub := _get_locomotion_playback_state()
	if _clip_length(CLIP_IDLE_TO_FORWARD) <= 0.0:
		return false
	if sub not in [&"move", &"enter", &"exit"]:
		return false
	_pending_root_after_exit = &"grounded"
	_pending_root_xfade = ROOT_GROUND_XFADE
	if sub == &"exit":
		_ensure_loco_exit_reverse_playback()
		_arm_nested_loco_exit(false)
		return true
	var seek := _seek_for_loco_reverse(sub)
	_tree.set(PARAM_LOCO_EXIT_SEEK, seek)
	_tree.set(PARAM_LOCO_EXIT_SCALE, -1.0)
	_arm_nested_loco_exit(true)
	_locomotion_playback.travel(&"exit")
	_advance_animation_tree(0.0)
	return true


func _arm_nested_boost_exit(reset_timer: bool) -> void:
	if reset_timer or _nested_exit_started_at < 0.0:
		_nested_exit_started_at = Time.get_ticks_msec() / 1000.0
	_nested_exit_active = true
	_nested_exit_kind = &"boost"


func _arm_nested_loco_exit(reset_timer: bool) -> void:
	if reset_timer or _nested_exit_started_at < 0.0:
		_nested_exit_started_at = Time.get_ticks_msec() / 1000.0
	_nested_exit_active = true
	_nested_exit_kind = &"locomotion"


func _ensure_boost_exit_reverse_playback() -> void:
	if _boost_playback == null or _tree == null:
		return
	var scale: float = _tree.get(PARAM_BOOST_EXIT_SCALE)
	if scale < 0.0:
		return
	var length := _clip_length(CLIP_FORWARD_TO_BOOST)
	if length <= 0.0:
		return
	var pos := clampf(_boost_playback.get_current_play_position(), 0.0, length)
	var seek := maxf(length - 0.05, 0.0) if pos <= 0.02 else pos
	_tree.set(PARAM_BOOST_EXIT_SEEK, seek)
	_tree.set(PARAM_BOOST_EXIT_SCALE, -1.0)
	if _boost_playback.get_current_node() != &"exit":
		_boost_playback.travel(&"exit")
	_advance_animation_tree(0.0)


func _ensure_loco_exit_reverse_playback() -> void:
	if _locomotion_playback == null or _tree == null:
		return
	var scale: float = _tree.get(PARAM_LOCO_EXIT_SCALE)
	if scale < 0.0:
		return
	var length := _clip_length(CLIP_IDLE_TO_FORWARD)
	if length <= 0.0:
		return
	var pos := clampf(_locomotion_playback.get_current_play_position(), 0.0, length)
	var seek := maxf(length - 0.05, 0.0) if pos <= 0.02 else pos
	_tree.set(PARAM_LOCO_EXIT_SEEK, seek)
	_tree.set(PARAM_LOCO_EXIT_SCALE, -1.0)
	if _locomotion_playback.get_current_node() != &"exit":
		_locomotion_playback.travel(&"exit")
	_advance_animation_tree(0.0)


func _is_boost_exit_finished() -> bool:
	if _boost_playback == null or _tree == null:
		return true
	if _boost_playback.get_current_node() != &"exit":
		return false
	var scale: float = _tree.get(PARAM_BOOST_EXIT_SCALE)
	if scale >= 0.0:
		return false
	if _boost_playback.get_current_play_position() > 0.02:
		return false
	return _nested_exit_started_at >= 0.0


func _is_loco_exit_finished() -> bool:
	if _locomotion_playback == null or _tree == null:
		return true
	if _locomotion_playback.get_current_node() != &"exit":
		return false
	var scale: float = _tree.get(PARAM_LOCO_EXIT_SCALE)
	if scale >= 0.0:
		return false
	if _locomotion_playback.get_current_play_position() > 0.02:
		return false
	return _nested_exit_started_at >= 0.0


func _finish_boost_exit(steer: float, strafe: float) -> void:
	var target := _pending_root_after_exit
	var xfade := _pending_root_xfade
	_nested_exit_active = false
	_nested_exit_kind = &""
	_nested_exit_started_at = -1.0
	_pending_root_after_exit = &""
	_reset_boost_exit_params()
	_root_state = target
	match target:
		&"grounded":
			_enter_grounded_idle(&"boost")
		&"locomotion":
			_locomotion_crossfade_warm = true
			_warm_locomotion_for_boost_exit(steer, strafe)
			_apply_root_travel(&"locomotion", xfade)
		&"glide":
			_apply_root_travel(&"glide", xfade)
		&"brake":
			_apply_brake_root()
		_:
			_apply_root_travel(target, xfade)
	_prep_boost_brake_nested_after_exit()
	_advance_animation_tree(0.0)


func _finish_loco_exit() -> void:
	var steer := _glider.get_anim_steer() if _glider != null else 0.0
	var strafe := _glider.get_strafe_axis() if _glider != null else 0.0
	_nested_exit_active = false
	_nested_exit_kind = &""
	_nested_exit_started_at = -1.0
	_pending_root_after_exit = &""
	_reset_loco_exit_params()
	_reset_locomotion_for_grounded_blend(steer, strafe)
	_root_state = &"grounded"
	_enter_grounded_idle(&"locomotion")
	_advance_animation_tree(0.0)


func _find_glider() -> GliderPlayerScript:
	var node: Node = get_parent()
	while node != null:
		if node is GliderPlayerScript:
			return node as GliderPlayerScript
		if node.get_parent() is GliderPlayerScript:
			return node.get_parent() as GliderPlayerScript
		node = node.get_parent()
	return null
