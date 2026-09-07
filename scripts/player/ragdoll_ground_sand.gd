class_name RagdollGroundSand
extends Node

## Shared-cooldown sand puffs when hero ragdoll bones hit terrain.

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")

const MIN_FIRST_LANDING_SPEED := 1.0
const GROUND_OFFSET_M := 0.08

@export var min_bounce_speed := 1.2
@export var cooldown_sec := 0.10

var _ragdoll: Node3D
var _terrain: TerrainManager
var _cooldown_left := 0.0
var _has_landed := false
var _landing_preset: SandParticleVfx.BurstPreset = SandParticleVfx.BurstPreset.DEATH
var _bones: Array[PhysicalBone3D] = []
var _was_grounded: Dictionary = {}


static func attach(
	ragdoll: Node3D,
	terrain: TerrainManager,
	landing_preset: SandParticleVfx.BurstPreset = SandParticleVfx.BurstPreset.DEATH
) -> Node:
	if ragdoll == null or not ragdoll.has_method("get_simulation_skeleton"):
		return null
	var skel := ragdoll.call("get_simulation_skeleton") as Skeleton3D
	if skel == null:
		return null
	var fx = load("res://scripts/player/ragdoll_ground_sand.gd").new()
	fx._ragdoll = ragdoll
	fx._terrain = terrain
	fx._landing_preset = landing_preset
	ragdoll.add_child(fx)
	fx._collect_bones(skel)
	fx.set_physics_process(true)
	return fx


func _collect_bones(skeleton: Skeleton3D) -> void:
	_bones.clear()
	for child in skeleton.get_children():
		if child is PhysicalBone3D:
			_bones.append(child as PhysicalBone3D)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _terrain == null or _ragdoll == null or not _ragdoll.has_method("get_bone_lowest_y"):
		return
	for pb in _bones:
		if not pb.is_simulating_physics():
			continue
		var lowest_y: float = _ragdoll.call("get_bone_lowest_y", pb) as float
		var ground_y := _terrain.sample_height(pb.global_position.x, pb.global_position.z)
		var grounded := lowest_y <= ground_y + GROUND_OFFSET_M
		var was_grounded: bool = _was_grounded.get(pb.bone_name, false)
		_was_grounded[pb.bone_name] = grounded
		if not grounded or was_grounded:
			continue
		var speed := pb.linear_velocity.length()
		var min_speed := MIN_FIRST_LANDING_SPEED if not _has_landed else min_bounce_speed
		if speed < min_speed:
			continue
		if _cooldown_left > 0.0:
			continue
		var tree := get_tree()
		if tree == null:
			return
		_cooldown_left = cooldown_sec
		var preset := _landing_preset if not _has_landed else SandParticleVfxScript.BurstPreset.MG
		_has_landed = true
		SandImpactDustScript.spawn(
			tree,
			pb.global_position,
			_terrain,
			preset
		)
