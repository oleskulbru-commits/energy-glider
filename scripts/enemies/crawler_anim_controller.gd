class_name CrawlerAnimController
extends Node

## Drives crawler spawn (ClimbUp once) then chase (Forward loop).

signal spawn_finished

const ANIM_CLIMB := &"Crawler_ClimbUp"
const ANIM_FORWARD := &"Crawler_Forward"
const REFERENCE_SPEED := SwarmPill.DEFAULT_SPEED

@export var animation_player_path: NodePath = ^"../Model/AnimationPlayer"

var _player: AnimationPlayer
var _spawn_active := true


func _ready() -> void:
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if _player == null:
		push_warning("CrawlerAnimController: AnimationPlayer not found at %s" % animation_player_path)
		_finish_spawn()
		return
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)
	begin_spawn()


func begin_spawn() -> void:
	_spawn_active = true
	if _player == null:
		_finish_spawn()
		return
	if not _player.has_animation(String(ANIM_CLIMB)):
		push_warning(
			"CrawlerAnimController: '%s' missing from AnimationPlayer; skipping spawn gate"
			% ANIM_CLIMB
		)
		_finish_spawn()
		return
	_player.play(ANIM_CLIMB)


func is_spawn_active() -> bool:
	return _spawn_active


func set_move_speed(speed: float) -> void:
	if _player == null or _spawn_active:
		return
	_player.speed_scale = speed / maxf(REFERENCE_SPEED, 0.001)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != ANIM_CLIMB:
		return
	_finish_spawn()


func _finish_spawn() -> void:
	if not _spawn_active:
		return
	_spawn_active = false
	if _player != null and _player.has_animation(String(ANIM_FORWARD)):
		_player.play(ANIM_FORWARD)
	spawn_finished.emit()


