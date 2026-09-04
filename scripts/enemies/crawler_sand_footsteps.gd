class_name CrawlerSandFootsteps
extends Node

## Animation-synced sand puffs at foot markers while the crawler walks.

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")

const ANIM_FORWARD := &"Crawler_Forward"
const MIN_MOVE_SPEED := 0.75
const STEP_CROSS_EPSILON := 0.0005

@export var animation_player_path: NodePath = ^"../Model/AnimationPlayer"
@export var anim_controller_path: NodePath = ^"../CrawlerAnimController"
@export var foot_markers: Array[NodePath] = []
@export var step_times: PackedFloat32Array = PackedFloat32Array([0.12, 0.37, 0.62, 0.87])

var _terrain: TerrainManager
var _player: AnimationPlayer
var _anim: CrawlerAnimController
var _host: CharacterBody3D
var _prev_norm_time := -1.0
var _marker_nodes: Array[Node3D] = []


func configure(terrain: TerrainManager, host: CharacterBody3D) -> void:
	_terrain = terrain
	_host = host


func _ready() -> void:
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_anim = get_node_or_null(anim_controller_path) as CrawlerAnimController
	_resolve_markers()


func _resolve_markers() -> void:
	_marker_nodes.clear()
	for path in foot_markers:
		var marker := get_node_or_null(path) as Node3D
		if marker != null:
			_marker_nodes.append(marker)


func _physics_process(_delta: float) -> void:
	if _terrain == null or _host == null or _player == null or _anim == null:
		return
	if _anim.is_spawn_active():
		_prev_norm_time = -1.0
		return
	if _player.current_animation != ANIM_FORWARD or not _player.is_playing():
		_prev_norm_time = -1.0
		return
	var flat_speed := Vector2(_host.velocity.x, _host.velocity.z).length()
	if flat_speed < MIN_MOVE_SPEED:
		_prev_norm_time = -1.0
		return
	if _marker_nodes.is_empty() or step_times.is_empty():
		return

	var anim_len := _player.current_animation_length
	if anim_len <= 0.0:
		return
	var norm_time := fposmod(_player.current_animation_position / anim_len, 1.0)
	if _prev_norm_time < 0.0:
		_prev_norm_time = norm_time
		return

	var count := mini(_marker_nodes.size(), step_times.size())
	for i in count:
		if _crossed_threshold(_prev_norm_time, norm_time, step_times[i]):
			_spawn_at_marker(_marker_nodes[i])

	_prev_norm_time = norm_time


func _crossed_threshold(prev_time: float, current_time: float, threshold: float) -> bool:
	if absf(current_time - prev_time) <= STEP_CROSS_EPSILON:
		return false
	if prev_time <= current_time:
		return prev_time < threshold and current_time >= threshold
	return prev_time < threshold or current_time >= threshold


func _spawn_at_marker(marker: Node3D) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var world_pos := marker.global_position
	SandImpactDustScript.spawn(
		tree,
		world_pos,
		_terrain,
		SandParticleVfxScript.BurstPreset.LIGHT
	)
