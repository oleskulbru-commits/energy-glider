class_name GliderAnimController
extends Node

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")

const BLEND_SPEED_MAX := GliderPhysicsScript.MAX_GROUND_SPEED
const GROUNDED_SPEED_MAX := 1.25
const COAST_BRAKE_SPEED_MIN := 2.0
const BOOST_TIME_SCALE := 1.35

const PARAM_FORWARD_SCALE := "parameters/locomotion/forward/time_scale/scale"
const PARAM_BOOST_SCALE := "parameters/boost/time_scale/scale"

@export var turn_enter: float = 0.35
@export var turn_exit: float = 0.15
@export var speed_scale_min: float = 0.85
@export var speed_scale_max: float = 1.25

@onready var _tree: AnimationTree = get_parent().get_node("AnimationTree")

var _glider: GliderPlayerScript
var _root_playback: AnimationNodeStateMachinePlayback
var _locomotion_playback: AnimationNodeStateMachinePlayback
var _root_state := &""
var _locomotion_state := &""


func _ready() -> void:
	_glider = _find_glider()
	if _tree == null:
		push_warning("GliderAnimController: AnimationTree node missing on GliderSkin")
		return
	if not _tree.active:
		_tree.active = true
	_root_playback = _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_locomotion_playback = _tree.get("parameters/locomotion/playback") as AnimationNodeStateMachinePlayback
	if _root_playback != null:
		_root_playback.start("grounded")
	if _locomotion_playback != null:
		_locomotion_playback.start("forward")


func _physics_process(_delta: float) -> void:
	if _tree == null or _glider == null or not is_instance_valid(_glider):
		return

	var speed := _glider.get_horizontal_speed()
	var steer := _glider.get_anim_steer()

	_update_forward_time_scale(speed)
	_update_boost_time_scale()

	var next_root := _pick_root_state(speed)
	if next_root != _root_state:
		_root_state = next_root
		if _root_playback != null:
			_root_playback.travel(next_root)

	if next_root == &"locomotion":
		var next_locomotion := _pick_locomotion_state(steer)
		if next_locomotion != _locomotion_state:
			_locomotion_state = next_locomotion
			if _locomotion_playback != null:
				_locomotion_playback.travel(next_locomotion)


func _pick_root_state(speed: float) -> StringName:
	if _glider.is_run_ended():
		return &"death"
	if _glider.is_landing():
		return &"landing"
	if _should_play_coast_brake(speed):
		return &"brake"
	if _glider.is_boost_active():
		return &"boost"
	if _glider.is_grounded() and speed < GROUNDED_SPEED_MAX:
		return &"grounded"
	return &"locomotion"


func _pick_locomotion_state(steer: float) -> StringName:
	var abs_steer := absf(steer)
	if _locomotion_state == &"turn_left":
		if abs_steer < turn_exit or steer > 0.0:
			return &"forward"
		return &"turn_left"
	if _locomotion_state == &"turn_right":
		if abs_steer < turn_exit or steer < 0.0:
			return &"forward"
		return &"turn_right"
	if steer <= -turn_enter:
		return &"turn_left"
	if steer >= turn_enter:
		return &"turn_right"
	return &"forward"


func _should_play_coast_brake(speed: float) -> bool:
	if _glider.is_forward_held() or _glider.is_boost_active():
		return false
	return speed > COAST_BRAKE_SPEED_MIN


func _update_forward_time_scale(speed: float) -> void:
	var speed_t := clampf(speed / BLEND_SPEED_MAX, 0.0, 1.0)
	var scale := lerpf(speed_scale_min, speed_scale_max, speed_t)
	_tree.set(PARAM_FORWARD_SCALE, scale)


func _update_boost_time_scale() -> void:
	if _root_state == &"boost":
		_tree.set(PARAM_BOOST_SCALE, BOOST_TIME_SCALE)
	else:
		_tree.set(PARAM_BOOST_SCALE, 1.0)


func _find_glider() -> GliderPlayerScript:
	var node: Node = get_parent()
	while node != null:
		if node is GliderPlayerScript:
			return node as GliderPlayerScript
		if node.get_parent() is GliderPlayerScript:
			return node.get_parent() as GliderPlayerScript
		node = node.get_parent()
	return null
