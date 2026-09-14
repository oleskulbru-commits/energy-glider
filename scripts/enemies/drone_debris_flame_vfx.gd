class_name DroneDebrisFlameVfx
extends Node

## Looping fire puff trail on falling drone debris until ground impact.

const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")

const MIN_GROUND_SPEED := 1.0
const TERRAIN_COLLISION_LAYER := 1

var _body: RigidBody3D
var _flame_trail: GPUParticles3D
var _particle_lifetime := SandParticleVfxScript.DEBRIS_FLAME_LIFETIME
var _stopping := false


static func attach(body: RigidBody3D, chunk_scale: float = 1.0) -> void:
	if body == null:
		return
	var fx: DroneDebrisFlameVfx = load(
		"res://scripts/enemies/drone_debris_flame_vfx.gd"
	).new()
	fx._body = body
	body.add_child(fx)
	fx._flame_trail = SandParticleVfxScript.create_debris_flame_trail(body, chunk_scale)
	fx._particle_lifetime = fx._flame_trail.lifetime
	if not body.body_entered.is_connected(fx._on_body_entered):
		body.body_entered.connect(fx._on_body_entered)


func _on_body_entered(other: Node) -> void:
	if _stopping or _body == null or _flame_trail == null:
		return
	if not _is_terrain_body(other):
		return
	if _body.linear_velocity.length() < MIN_GROUND_SPEED:
		return
	_stop_flame()


func _stop_flame() -> void:
	if _stopping:
		return
	_stopping = true
	if _body != null and _body.body_entered.is_connected(_on_body_entered):
		_body.body_entered.disconnect(_on_body_entered)
	if _flame_trail != null and is_instance_valid(_flame_trail):
		_flame_trail.emitting = false
		var timer := get_tree().create_timer(_particle_lifetime + SandParticleVfxScript.FREE_BUFFER_SEC)
		timer.timeout.connect(queue_free)
	else:
		queue_free()


func _is_terrain_body(other: Node) -> bool:
	if other is StaticBody3D or other is TerrainManager:
		return true
	if other is CollisionObject3D:
		return ((other as CollisionObject3D).collision_layer & TERRAIN_COLLISION_LAYER) != 0
	return false
