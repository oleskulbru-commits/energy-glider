class_name CrawlerAnimController
extends Node

## Drives crawler spawn (ClimbUp once) then chase (Forward loop).

signal spawn_finished

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")

const ANIM_CLIMB := &"Crawler_ClimbUp"
const ANIM_FORWARD := &"Crawler_Forward"
const REFERENCE_SPEED := SwarmPill.DEFAULT_SPEED

@export var animation_player_path: NodePath = ^"../Model/AnimationPlayer"
@export var dig_dust_interval_sec := 0.12
@export var dig_dust_anchor_path: NodePath = ^"DigDustAnchor"

var _player: AnimationPlayer
var _spawn_active := true
var _terrain: TerrainManager
var _host: Node3D
var _dig_anchor: Node3D
var _dig_dust_timer := 0.0
var _used_climb_anim := false


func configure_sand(terrain: TerrainManager, host: Node3D) -> void:
	_terrain = terrain
	_host = host
	_dig_anchor = get_node_or_null(dig_dust_anchor_path) as Node3D


func _ready() -> void:
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if _dig_anchor == null:
		_dig_anchor = get_node_or_null(dig_dust_anchor_path) as Node3D
	if _player == null:
		push_warning("CrawlerAnimController: AnimationPlayer not found at %s" % animation_player_path)
		_finish_spawn()
		return
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)
	begin_spawn()


func begin_spawn() -> void:
	_spawn_active = true
	_dig_dust_timer = 0.0
	if _player == null:
		_finish_spawn()
		return
	if not _player.has_animation(String(ANIM_CLIMB)):
		push_warning(
			"CrawlerAnimController: '%s' missing from AnimationPlayer; skipping spawn gate"
			% ANIM_CLIMB
		)
		_spawn_dust(SandParticleVfxScript.BurstPreset.HEAVY)
		_finish_spawn()
		return
	_used_climb_anim = true
	_player.play(ANIM_CLIMB)
	_spawn_dust(SandParticleVfxScript.BurstPreset.HEAVY)
	_dig_dust_timer = dig_dust_interval_sec


func is_spawn_active() -> bool:
	return _spawn_active


func set_move_speed(speed: float) -> void:
	if _player == null or _spawn_active:
		return
	_player.speed_scale = speed / maxf(REFERENCE_SPEED, 0.001)


func _process(delta: float) -> void:
	if not _spawn_active or not _used_climb_anim:
		return
	_dig_dust_timer -= delta
	if _dig_dust_timer > 0.0:
		return
	_dig_dust_timer = dig_dust_interval_sec
	_spawn_dust(SandParticleVfxScript.BurstPreset.LIGHT)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != ANIM_CLIMB:
		return
	_finish_spawn()


func _finish_spawn() -> void:
	if not _spawn_active:
		return
	_spawn_active = false
	_used_climb_anim = false
	if _player != null and _player.has_animation(String(ANIM_FORWARD)):
		_player.play(ANIM_FORWARD)
	spawn_finished.emit()


func _spawn_dust(preset: SandParticleVfx.BurstPreset) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var anchor: Node3D = _dig_anchor if _dig_anchor != null else _host
	if anchor == null:
		return
	SandImpactDustScript.spawn(tree, anchor.global_position, _terrain, preset)
