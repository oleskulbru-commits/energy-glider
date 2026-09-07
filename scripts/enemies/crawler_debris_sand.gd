class_name CrawlerDebrisSand
extends Node

## Impact-sized sand puffs when death shards bounce on terrain.

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")

const TERRAIN_COLLISION_LAYER := 1
const MIN_FIRST_LANDING_SPEED := 1.0

@export var min_bounce_speed := 1.2
@export var cooldown_sec := 0.10

var _terrain: TerrainManager
var _body: PhysicsBody3D
var _cooldown_left := 0.0
var _has_landed := false
var _landing_preset: SandParticleVfx.BurstPreset = SandParticleVfx.BurstPreset.MG


static func attach(
	body: PhysicsBody3D,
	terrain: TerrainManager,
	landing_preset: SandParticleVfx.BurstPreset = SandParticleVfx.BurstPreset.MG
) -> Node:
	if body == null:
		return null
	var fx = load("res://scripts/enemies/crawler_debris_sand.gd").new()
	fx._body = body
	fx._terrain = terrain
	fx._landing_preset = landing_preset
	body.add_child(fx)
	if not body.body_entered.is_connected(fx._on_body_entered):
		body.body_entered.connect(fx._on_body_entered)
	return fx


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _on_body_entered(other: Node) -> void:
	if other == null or _body == null:
		return
	if not _is_terrain_body(other):
		return
	var vel := Vector3.ZERO
	if _body is RigidBody3D:
		vel = (_body as RigidBody3D).linear_velocity
	elif _body is PhysicalBone3D:
		vel = (_body as PhysicalBone3D).linear_velocity
	var speed := vel.length()
	var min_speed := MIN_FIRST_LANDING_SPEED if not _has_landed else min_bounce_speed
	if speed < min_speed:
		return
	if _cooldown_left > 0.0:
		return
	var tree := get_tree()
	if tree == null:
		return
	_cooldown_left = cooldown_sec
	var is_first_landing := not _has_landed
	var preset := _landing_preset if is_first_landing else SandParticleVfxScript.BurstPreset.MG
	_has_landed = true
	var speed_factor := clampf(speed / 8.0, 0.55, 1.4)
	var shake_strength := _debris_shake_strength(is_first_landing, preset) * speed_factor
	var shake_radius_m := 26.0
	SandImpactDustScript.spawn(
		tree,
		_body.global_position,
		_terrain,
		preset,
		1.0,
		shake_strength,
		shake_radius_m
	)


func _debris_shake_strength(
	is_first_landing: bool,
	preset: SandParticleVfx.BurstPreset
) -> float:
	if is_first_landing:
		if preset == SandParticleVfx.BurstPreset.DEATH:
			return 0.55
		return 0.32
	return 0.14


func _is_terrain_body(other: Node) -> bool:
	if other is StaticBody3D or other is TerrainManager:
		return true
	if other is CollisionObject3D:
		return ((other as CollisionObject3D).collision_layer & TERRAIN_COLLISION_LAYER) != 0
	return false
