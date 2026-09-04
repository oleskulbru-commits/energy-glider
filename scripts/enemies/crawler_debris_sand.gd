class_name CrawlerDebrisSand
extends Node

## Light sand puffs when death shards bounce on terrain.

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")

const TERRAIN_COLLISION_LAYER := 1

@export var min_bounce_speed := 1.5
@export var cooldown_sec := 0.12

var _terrain: TerrainManager
var _body: RigidBody3D
var _cooldown_left := 0.0


static func attach(body: RigidBody3D, terrain: TerrainManager) -> void:
	if body == null:
		return
	var fx = load("res://scripts/enemies/crawler_debris_sand.gd").new()
	fx._body = body
	fx._terrain = terrain
	body.add_child(fx)
	if not body.body_entered.is_connected(fx._on_body_entered):
		body.body_entered.connect(fx._on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _on_body_entered(other: Node) -> void:
	if other == null or _body == null:
		return
	if not _is_terrain_body(other):
		return
	if _body.linear_velocity.length() < min_bounce_speed:
		return
	if _cooldown_left > 0.0:
		return
	var tree := get_tree()
	if tree == null:
		return
	_cooldown_left = cooldown_sec
	SandImpactDustScript.spawn(
		tree,
		_body.global_position,
		_terrain,
		SandParticleVfxScript.BurstPreset.LIGHT
	)


func _is_terrain_body(other: Node) -> bool:
	if other is StaticBody3D or other is TerrainManager:
		return true
	if other is CollisionObject3D:
		return ((other as CollisionObject3D).collision_layer & TERRAIN_COLLISION_LAYER) != 0
	return false
