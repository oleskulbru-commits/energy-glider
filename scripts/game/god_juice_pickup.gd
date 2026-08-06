class_name GodJuicePickup
extends Node3D

signal collected

const PICKUP_RADIUS_M := 7.0
const BOB_SPEED := 2.4
const BOB_HEIGHT := 0.18
const SPIN_SPEED := 1.6

@onready var _visual: Node3D = $Visual

var _visual_base_y := 0.0
var _bob_time := 0.0


func _ready() -> void:
	add_to_group("god_juice")
	if _visual != null:
		_visual_base_y = _visual.position.y


func _process(delta: float) -> void:
	if _visual == null:
		return
	_bob_time += delta
	_visual.position.y = _visual_base_y + sin(_bob_time * BOB_SPEED) * BOB_HEIGHT
	_visual.rotate_y(SPIN_SPEED * delta)


func try_collect(body: Node3D) -> bool:
	if body == null:
		return false
	var offset := body.global_position - global_position
	offset.y = 0.0
	if offset.length() > PICKUP_RADIUS_M:
		return false
	collected.emit()
	return true


func get_world_position() -> Vector3:
	return global_position
