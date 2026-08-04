class_name WindField
extends Node

@export var wind_direction := Vector2(0.85, 0.35)
@export var wind_strength := 8.0
@export var rotation_rate := 0.02

var _direction := Vector2.ZERO


func _ready() -> void:
	add_to_group("wind_field")
	_direction = _normalized_direction(wind_direction)


func _physics_process(delta: float) -> void:
	if absf(rotation_rate) <= 0.0001:
		return
	var angle := rotation_rate * delta
	_direction = Vector2(
		_direction.x * cos(angle) - _direction.y * sin(angle),
		_direction.x * sin(angle) + _direction.y * cos(angle)
	).normalized()


func get_wind_at(_world_pos: Vector3) -> Vector3:
	return Vector3(_direction.x, 0.0, _direction.y) * wind_strength


func get_wind_direction() -> Vector2:
	return _direction


func set_wind_direction(direction: Vector2) -> void:
	_direction = _normalized_direction(direction)


func set_rotation_rate(rate: float) -> void:
	rotation_rate = rate


func _normalized_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() < 0.0001:
		return Vector2.RIGHT
	return direction.normalized()
