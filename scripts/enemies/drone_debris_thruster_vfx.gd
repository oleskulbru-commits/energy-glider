class_name DroneDebrisThrusterVfx
extends Node

## Keeps thruster streaks lit on falling body debris until ground impact, then flickers off.

const FLICKER_COUNT := 4
const FLICKER_ON_SEC := 0.07
const FLICKER_OFF_SEC := 0.10
const MIN_GROUND_SPEED := 1.0
const TERRAIN_COLLISION_LAYER := 1

var _body: RigidBody3D
var _thruster_streaks: Node3D
var _flickering := false
var _flicker_left := 0
var _flicker_timer := 0.0
var _flicker_on := true


static func attach(body: RigidBody3D, thruster_streaks: Node3D) -> void:
	if body == null or thruster_streaks == null:
		return
	var fx: DroneDebrisThrusterVfx = load(
		"res://scripts/enemies/drone_debris_thruster_vfx.gd"
	).new()
	fx._body = body
	fx._thruster_streaks = thruster_streaks
	body.add_child(fx)
	thruster_streaks.visible = true
	if not body.body_entered.is_connected(fx._on_body_entered):
		body.body_entered.connect(fx._on_body_entered)


func _on_body_entered(other: Node) -> void:
	if _flickering or _body == null or _thruster_streaks == null:
		return
	if not _is_terrain_body(other):
		return
	if _body.linear_velocity.length() < MIN_GROUND_SPEED:
		return
	_begin_flicker()


func _begin_flicker() -> void:
	if _body != null and _body.body_entered.is_connected(_on_body_entered):
		_body.body_entered.disconnect(_on_body_entered)
	_flickering = true
	_flicker_left = FLICKER_COUNT
	_flicker_on = true
	_flicker_timer = FLICKER_ON_SEC
	_thruster_streaks.visible = true
	set_process(true)


func _process(delta: float) -> void:
	if not _flickering or not is_instance_valid(_thruster_streaks):
		set_process(false)
		return
	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return
	if _flicker_on:
		_flicker_on = false
		_thruster_streaks.visible = false
		_flicker_timer = FLICKER_OFF_SEC
	else:
		_flicker_left -= 1
		if _flicker_left <= 0:
			_thruster_streaks.visible = false
			_flickering = false
			set_process(false)
			return
		_flicker_on = true
		_thruster_streaks.visible = true
		_flicker_timer = FLICKER_ON_SEC


func is_flickering() -> bool:
	return _flickering


func _is_terrain_body(other: Node) -> bool:
	if other is StaticBody3D or other is TerrainManager:
		return true
	if other is CollisionObject3D:
		return ((other as CollisionObject3D).collision_layer & TERRAIN_COLLISION_LAYER) != 0
	return false
