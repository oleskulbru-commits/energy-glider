class_name LeaperAnimController
extends Node

## Drives leaper spawn climb, run cycle, stop/jump, air loop, land, and stand-up.

signal spawn_finished

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")

const ANIM_CLIMB := &"Leaper_ClimbUp"
const ANIM_START_RUN := &"Leaper_Start_Run"
const ANIM_RUN := &"Leaper_Run"
const ANIM_STOP_RUN := &"Leaper_StopRun"
const ANIM_JUMP := &"Leaper_Jump"
const ANIM_AIR := &"Leaper_Air"
const ANIM_LAND := &"Leaper_Landing"
const ANIM_STAND := &"Leaper_StandUp"

const STATE_CLIMB := &"climb"
const STATE_START_RUN := &"start_run"
const STATE_RUN := &"run"
const STATE_STOP_RUN := &"stop_run"
const STATE_JUMP := &"jump"
const STATE_AIR := &"air"
const STATE_LAND := &"land"
const STATE_STAND := &"stand_up"

const PARAM_PLAYBACK := "parameters/playback"
const PARAM_RUN_SCALE := "parameters/run/time_scale/scale"
const PARAM_AIR_SCALE := "parameters/air/time_scale/scale"
const RUN_XFADE := 0.12
const AIR_XFADE := 0.15
const LAND_XFADE := 0.08
const AUTO_XFADE := 0.08

@export var animation_tree_path: NodePath = ^"../AnimationTree"
@export var animation_player_path: NodePath = ^"../Model/AnimationPlayer"
@export var dig_dust_interval_sec := 0.12
@export var dig_dust_anchor_path: NodePath = ^"DigDustAnchor"
@export var run_reference_speed := 8.0

var _tree: AnimationTree
var _player: AnimationPlayer
var _playback: AnimationNodeStateMachinePlayback
var _spawn_active := true
var _recover_active := false
var _recover_seen_land := false
var _terrain: TerrainManager
var _host: Node3D
var _dig_anchor: Node3D
var _dig_dust_timer := 0.0
var _used_climb_anim := false


func configure_sand(terrain: TerrainManager, host: Node3D) -> void:
	_terrain = terrain
	_host = host
	_dig_anchor = get_node_or_null(dig_dust_anchor_path) as Node3D


func _enter_tree() -> void:
	_tree = get_node_or_null(animation_tree_path) as AnimationTree
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if _tree != null and _player != null:
		_tree.anim_player = _tree.get_path_to(_player)
		_build_tree()
		_tree.active = true
		_playback = _tree.get(PARAM_PLAYBACK) as AnimationNodeStateMachinePlayback


func _ready() -> void:
	if _dig_anchor == null:
		_dig_anchor = get_node_or_null(dig_dust_anchor_path) as Node3D
	if _tree != null and not _tree.animation_finished.is_connected(_on_animation_finished):
		_tree.animation_finished.connect(_on_animation_finished)
	elif _player != null and not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)
	begin_spawn()


func begin_spawn() -> void:
	_spawn_active = true
	_dig_dust_timer = 0.0
	_used_climb_anim = false
	if _playback == null or _player == null or not _player.has_animation(String(ANIM_CLIMB)):
		_finish_spawn()
		return
	_used_climb_anim = true
	_playback.start(STATE_CLIMB)
	_spawn_climb_dust()
	_dig_dust_timer = dig_dust_interval_sec


func is_spawn_active() -> bool:
	return _spawn_active


func is_recover_active() -> bool:
	return _recover_active


func recover_duration() -> float:
	return _clip_length(ANIM_LAND) + _clip_length(ANIM_STAND) + LAND_XFADE


func set_run_speed(speed: float) -> void:
	if _tree == null or _spawn_active:
		return
	_tree.set(PARAM_RUN_SCALE, speed / maxf(run_reference_speed, 0.001))


func play_stop_run() -> void:
	_travel(STATE_STOP_RUN)


func play_leap(air_sec: float) -> void:
	_set_air_scale(air_sec)
	if _player != null and _player.has_animation(String(ANIM_JUMP)):
		_travel(STATE_JUMP)
	else:
		_travel(STATE_AIR)


func play_land() -> void:
	_recover_active = true
	_recover_seen_land = false
	_travel(STATE_LAND)


func _set_air_scale(air_sec: float) -> void:
	if _tree == null:
		return
	var length := _clip_length(ANIM_AIR)
	if length <= 0.001 or air_sec <= 0.001:
		_tree.set(PARAM_AIR_SCALE, 1.0)
		return
	_tree.set(PARAM_AIR_SCALE, length / air_sec)


func _process(delta: float) -> void:
	if _spawn_active and _used_climb_anim:
		_dig_dust_timer -= delta
		if _dig_dust_timer <= 0.0:
			_dig_dust_timer = dig_dust_interval_sec
			_spawn_climb_dust()
		var spawn_node := _current_state()
		if spawn_node == STATE_START_RUN or spawn_node == STATE_RUN:
			_finish_spawn()
	if _recover_active:
		var node := _current_state()
		if node == STATE_LAND or node == STATE_STAND:
			_recover_seen_land = true
		elif _recover_seen_land:
			_recover_active = false


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_CLIMB:
		_finish_spawn()
	elif anim_name == ANIM_STAND:
		_recover_active = false


func _finish_spawn() -> void:
	if not _spawn_active:
		return
	_spawn_active = false
	_used_climb_anim = false
	if _playback != null:
		if _player != null and _player.has_animation(String(ANIM_START_RUN)):
			_playback.travel(STATE_START_RUN)
		else:
			_playback.travel(STATE_RUN)
	spawn_finished.emit()


func _travel(state: StringName) -> void:
	if _playback == null:
		return
	if _current_state() == state:
		return
	_playback.travel(state)


func _current_state() -> StringName:
	if _playback == null:
		return &""
	return StringName(_playback.get_current_node())


func _clip_length(clip_name: StringName) -> float:
	if _player == null or not _player.has_animation(String(clip_name)):
		return 0.0
	var anim := _player.get_animation(String(clip_name))
	if anim == null:
		return 0.0
	return anim.length


func _spawn_climb_dust() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var anchor: Node3D = _dig_anchor if _dig_anchor != null else _host
	if anchor == null:
		return
	var preset := SandParticleVfxScript.BurstPreset.CLIMB
	var scale_mult := 1.0
	var shake_strength := 0.22
	var shake_radius_m := 18.0
	if _host is SwarmPill:
		var pill := _host as SwarmPill
		preset = pill.get_climb_dust_preset()
		scale_mult = pill.get_sand_burst_scale_mult()
		shake_strength = pill.get_climb_dust_shake_strength()
		shake_radius_m = pill.get_climb_dust_shake_radius_m()
	SandImpactDustScript.spawn(
		tree,
		anchor.global_position,
		_terrain,
		preset,
		scale_mult,
		shake_strength,
		shake_radius_m
	)


func _build_tree() -> void:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node(STATE_CLIMB, _make_clip(ANIM_CLIMB), Vector2(0, 80))
	sm.add_node(STATE_START_RUN, _make_clip(ANIM_START_RUN), Vector2(220, 80))
	sm.add_node(STATE_RUN, _make_timescaled_clip(ANIM_RUN), Vector2(440, 80))
	sm.add_node(STATE_STOP_RUN, _make_clip(ANIM_STOP_RUN), Vector2(440, 220))
	sm.add_node(STATE_JUMP, _make_clip(ANIM_JUMP), Vector2(660, 220))
	sm.add_node(STATE_AIR, _make_timescaled_clip(ANIM_AIR), Vector2(880, 220))
	sm.add_node(STATE_LAND, _make_clip(ANIM_LAND), Vector2(880, 80))
	sm.add_node(STATE_STAND, _make_clip(ANIM_STAND), Vector2(660, 80))

	sm.add_transition("Start", STATE_CLIMB, _make_transition(0.0, false, false))
	sm.add_transition(STATE_CLIMB, STATE_START_RUN, _make_transition(AUTO_XFADE, true, true))
	sm.add_transition(STATE_START_RUN, STATE_RUN, _make_transition(AUTO_XFADE, true, true))
	sm.add_transition(STATE_START_RUN, STATE_STOP_RUN, _make_transition(RUN_XFADE, false, false))
	sm.add_transition(STATE_RUN, STATE_STOP_RUN, _make_transition(RUN_XFADE, false, false))
	sm.add_transition(STATE_STOP_RUN, STATE_JUMP, _make_transition(AUTO_XFADE, false, false))
	sm.add_transition(STATE_JUMP, STATE_AIR, _make_transition(AIR_XFADE, true, true))
	sm.add_transition(STATE_AIR, STATE_LAND, _make_transition(LAND_XFADE, false, false))
	sm.add_transition(STATE_LAND, STATE_STAND, _make_transition(AUTO_XFADE, true, true))
	sm.add_transition(STATE_STAND, STATE_RUN, _make_transition(RUN_XFADE, true, true))
	sm.add_transition(STATE_STOP_RUN, STATE_RUN, _make_transition(RUN_XFADE, false, false))
	sm.add_transition(STATE_CLIMB, STATE_RUN, _make_transition(RUN_XFADE, false, false))

	_ensure_loop(ANIM_RUN)
	_ensure_loop(ANIM_AIR)
	_tree.tree_root = sm


func _ensure_loop(clip_name: StringName) -> void:
	if _player == null or not _player.has_animation(String(clip_name)):
		return
	var anim := _player.get_animation(String(clip_name))
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR


func _make_clip(clip_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip_name
	return node


func _make_timescaled_clip(clip_name: StringName) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_clip(clip_name)
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 0))
	tree.add_node("time_scale", time_scale, Vector2(220, 0))
	tree.connect_node(&"time_scale", 0, &"clip")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_transition(
	xfade: float, auto_advance: bool, at_end: bool
) -> AnimationNodeStateMachineTransition:
	var trans := AnimationNodeStateMachineTransition.new()
	trans.xfade_time = xfade
	if auto_advance:
		trans.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	else:
		trans.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	if at_end:
		trans.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	else:
		trans.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	return trans
