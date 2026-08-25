class_name SailAnimController
extends Node

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderInputScript = preload("res://scripts/input/glider_input.gd")

const DEPLOY_CLIP := &"Sail_Deploy"
const PARAM_SAIL_PLAYBACK := "parameters/sail/playback"
const PARAM_SAIL_DOWN_SEEK := "parameters/sail/sail_down/seek/seek_request"
const PARAM_SAIL_DOWN_SCALE := "parameters/sail/sail_down/time_scale/scale"
const PARAM_DEPLOY_FWD_SEEK := "parameters/sail/deploy_forward/seek/seek_request"
const PARAM_DEPLOY_FWD_SCALE := "parameters/sail/deploy_forward/time_scale/scale"
const PARAM_DEPLOY_REV_SEEK := "parameters/sail/deploy_reverse/seek/seek_request"
const PARAM_DEPLOY_REV_SCALE := "parameters/sail/deploy_reverse/time_scale/scale"
const DEPLOY_END_EPSILON := 0.03

@onready var _tree: AnimationTree = get_parent().get_node("AnimationTree")

var _glider: GliderPlayerScript
var _anim_player: AnimationPlayer
var _sail_playback: AnimationNodeStateMachinePlayback
var _sail_state := &""
var _was_sail_deployed := false
var _deploy_reverse_started_at := -1.0
var _forced_death_retract := false


func _ready() -> void:
	# After GliderInput (0) so deploy/retract reacts same frame W/S changes.
	process_priority = 1
	if _tree == null:
		push_warning("SailAnimController: AnimationTree node missing on GliderSkin")
		return
	if not _tree.active:
		_tree.active = true
	_anim_player = _tree.get_node(_tree.anim_player) as AnimationPlayer
	_sail_playback = _tree.get(PARAM_SAIL_PLAYBACK) as AnimationNodeStateMachinePlayback
	if _sail_playback == null:
		push_warning("SailAnimController: sail playback missing — rebuild glider_anim_state_machine.tres")
		return
	call_deferred("_bootstrap_sail_state")


func reset_animation_state() -> void:
	if _tree == null or _sail_playback == null:
		return
	_tree.set(PARAM_DEPLOY_FWD_SEEK, 0.0)
	_tree.set(PARAM_DEPLOY_FWD_SCALE, 1.0)
	_tree.set(PARAM_DEPLOY_REV_SEEK, 0.0)
	_tree.set(PARAM_DEPLOY_REV_SCALE, 1.0)
	_forced_death_retract = false
	_enter_stowed()
	_was_sail_deployed = _is_sail_deployed()
	_deploy_reverse_started_at = -1.0
	_forced_death_retract = false


func force_retract_for_death() -> void:
	if _tree == null or _sail_playback == null:
		return
	_forced_death_retract = true
	_was_sail_deployed = true
	if _sail_state == &"sail_down":
		return
	var seek := _deploy_seek_for_reverse()
	_tree.set(PARAM_DEPLOY_REV_SEEK, seek)
	_tree.set(PARAM_DEPLOY_REV_SCALE, -1.0)
	_deploy_reverse_started_at = Time.get_ticks_msec() / 1000.0
	if _sail_state == &"":
		_sail_playback.start("deploy_reverse")
	else:
		_sail_playback.travel("deploy_reverse")
	_sail_state = &"deploy_reverse"
	_tree.advance(0.0)


func get_sail_state() -> StringName:
	return _sail_state


func _bootstrap_sail_state() -> void:
	_glider = _find_glider()
	_tree.set(PARAM_DEPLOY_FWD_SEEK, 0.0)
	_tree.set(PARAM_DEPLOY_FWD_SCALE, 1.0)
	_tree.set(PARAM_DEPLOY_REV_SEEK, 0.0)
	_tree.set(PARAM_DEPLOY_REV_SCALE, 1.0)
	_enter_stowed()
	_was_sail_deployed = _is_sail_deployed()
	_deploy_reverse_started_at = -1.0


func _process(_delta: float) -> void:
	if _tree == null or _sail_playback == null:
		return
	if _glider == null or not is_instance_valid(_glider):
		_glider = _find_glider()
		if _glider == null:
			return

	if _forced_death_retract:
		_sail_state = _sail_playback.get_current_node()
		if _sail_state == &"deploy_reverse" and _is_deploy_reverse_finished():
			_deploy_reverse_started_at = -1.0
			_tree.set(PARAM_DEPLOY_REV_SEEK, 0.0)
			_tree.set(PARAM_DEPLOY_REV_SCALE, 1.0)
			_enter_stowed()
		return

	var sail_deployed := _is_sail_deployed()
	if sail_deployed != _was_sail_deployed:
		if sail_deployed:
			_begin_deploy_forward()
		else:
			_begin_deploy_reverse()
		_was_sail_deployed = sail_deployed

	_sail_state = _sail_playback.get_current_node()
	if _sail_state == &"deploy_forward" and sail_deployed:
		_try_finish_deploy_forward()
	elif _sail_state == &"deploy_reverse":
		if _is_deploy_reverse_finished():
			_deploy_reverse_started_at = -1.0
			_tree.set(PARAM_DEPLOY_REV_SEEK, 0.0)
			_tree.set(PARAM_DEPLOY_REV_SCALE, 1.0)
			_enter_stowed()


func _enter_stowed() -> void:
	_tree.set(PARAM_SAIL_DOWN_SEEK, 0.0)
	_tree.set(PARAM_SAIL_DOWN_SCALE, 0.0)
	_sail_playback.start("sail_down")
	_sail_state = &"sail_down"
	_tree.advance(0.0)


func _begin_deploy_forward() -> void:
	var seek := _deploy_seek_for_forward()
	_tree.set(PARAM_DEPLOY_FWD_SEEK, seek)
	_tree.set(PARAM_DEPLOY_FWD_SCALE, 1.0)
	if _sail_state == &"sail_down":
		_sail_playback.start("deploy_forward")
	else:
		_sail_playback.travel("deploy_forward")
	_tree.advance(0.0)
	_sail_state = &"deploy_forward"


func _begin_sail_up() -> void:
	_sail_playback.start("sail_up")
	_sail_state = &"sail_up"


func _try_finish_deploy_forward() -> void:
	var length := _deploy_length()
	if length <= 0.0:
		return
	var pos := _sail_playback.get_current_play_position()
	if pos < length - DEPLOY_END_EPSILON:
		return
	_begin_sail_up()


func _begin_deploy_reverse() -> void:
	match _sail_state:
		&"sail_down":
			_sail_playback.travel("sail_down")
		_:
			var seek := _deploy_seek_for_reverse()
			_tree.set(PARAM_DEPLOY_REV_SEEK, seek)
			_tree.set(PARAM_DEPLOY_REV_SCALE, -1.0)
			_deploy_reverse_started_at = Time.get_ticks_msec() / 1000.0
			_sail_playback.travel("deploy_reverse")


func _is_deploy_reverse_finished() -> bool:
	var pos := _sail_playback.get_current_play_position()
	if pos > 0.02:
		return false
	if _deploy_reverse_started_at < 0.0:
		return false
	var scale: float = _tree.get(PARAM_DEPLOY_REV_SCALE)
	return scale < 0.0


func _deploy_seek_for_forward() -> float:
	if _sail_state == &"deploy_reverse" or _sail_state == &"deploy_forward":
		return _current_deploy_seconds()
	return 0.0


func _deploy_seek_for_reverse() -> float:
	if _sail_state == &"deploy_forward" or _sail_state == &"deploy_reverse":
		return _current_deploy_seconds()
	var length := _deploy_length()
	if length <= 0.0:
		return 0.0
	# Seek slightly before clip end so reverse playback does not instant-trigger AT_END.
	return maxf(length - 0.05, 0.0)


func _current_deploy_seconds() -> float:
	var length := _deploy_length()
	if length <= 0.0:
		return 0.0
	return clampf(_sail_playback.get_current_play_position(), 0.0, length)


func _deploy_length() -> float:
	if _anim_player == null or not _anim_player.has_animation(DEPLOY_CLIP):
		return 0.0
	return _anim_player.get_animation(DEPLOY_CLIP).length


func _is_sail_deployed() -> bool:
	if _glider != null and _glider.has_method("is_sail_deployed"):
		return _glider.is_sail_deployed()
	var input := _find_glider_input()
	return input != null and input.is_sail_deployed()


func _find_glider() -> GliderPlayerScript:
	var node: Node = get_parent()
	while node != null:
		if node is GliderPlayerScript:
			return node as GliderPlayerScript
		if node.get_parent() is GliderPlayerScript:
			return node.get_parent() as GliderPlayerScript
		node = node.get_parent()
	return null


func _find_glider_input() -> GliderInputScript:
	var glider := _find_glider()
	if glider == null:
		return null
	var input := glider.get_node_or_null("GliderInput") as GliderInputScript
	if input != null:
		return input
	var parent := glider.get_parent()
	if parent != null:
		return parent.get_node_or_null("GliderInput") as GliderInputScript
	return null
