class_name DroneDebrisSparkVfx
extends Node

## Looping ember sparks on falling drone debris until ground impact.

const DroneDamageSparkVfxScript := preload("res://scripts/vfx/drone_damage_spark_vfx.gd")

const MIN_GROUND_SPEED := 1.0
const TERRAIN_COLLISION_LAYER := 1
const LOCAL_OFFSET := Vector3(0.0, 0.35, 0.0)

var _body: RigidBody3D
var _sparks: GPUParticles3D
var _particle_lifetime := DroneDamageSparkVfxScript.DEBRIS_PARTICLE_LIFETIME
var _stopping := false


static func attach(
	body: RigidBody3D,
	spark_color: Color,
	chunk_scale: float = 1.0
) -> void:
	if body == null:
		return
	var fx: DroneDebrisSparkVfx = load(
		"res://scripts/enemies/drone_debris_spark_vfx.gd"
	).new()
	fx._body = body
	fx._particle_lifetime = DroneDamageSparkVfxScript.DEBRIS_PARTICLE_LIFETIME
	body.add_child(fx)
	var spark_length := DroneDamageSparkVfxScript.debris_spark_length_for_chunk(chunk_scale)
	var emission_radius := DroneDamageSparkVfxScript.debris_emission_radius_for_chunk(chunk_scale)
	var offset := LOCAL_OFFSET * clampf(chunk_scale * 0.12, 0.35, 1.5)
	fx._sparks = DroneDamageSparkVfxScript.build_looping_sparks(
		body,
		spark_color,
		"DebrisSparks",
		offset,
		1.0,
		DroneDamageSparkVfxScript.DEBRIS_PARTICLE_LIFETIME,
		DroneDamageSparkVfxScript.DEBRIS_PARTICLE_AMOUNT,
		DroneDamageSparkVfxScript.DEBRIS_VISIBILITY_AABB,
		0.75,
		1.35,
		DroneDamageSparkVfxScript.DEBRIS_GLOW_STRENGTH,
		emission_radius,
		spark_length,
		false,
		1.5,
		4.5
	)
	if not body.body_entered.is_connected(fx._on_body_entered):
		body.body_entered.connect(fx._on_body_entered)


func _on_body_entered(other: Node) -> void:
	if _stopping or _body == null or _sparks == null:
		return
	if not _is_terrain_body(other):
		return
	if _body.linear_velocity.length() < MIN_GROUND_SPEED:
		return
	_stop_sparks()


func _stop_sparks() -> void:
	if _stopping:
		return
	_stopping = true
	if _body != null and _body.body_entered.is_connected(_on_body_entered):
		_body.body_entered.disconnect(_on_body_entered)
	if _sparks != null and is_instance_valid(_sparks):
		_sparks.emitting = false
		var timer := get_tree().create_timer(_particle_lifetime + 0.1)
		timer.timeout.connect(queue_free)
	else:
		queue_free()


func _is_terrain_body(other: Node) -> bool:
	if other is StaticBody3D or other is TerrainManager:
		return true
	if other is CollisionObject3D:
		return ((other as CollisionObject3D).collision_layer & TERRAIN_COLLISION_LAYER) != 0
	return false
