class_name ShotgunPellet
extends Node3D

## Visual pellet. No hitbox; the cone applies damage.

var _dir := Vector3.FORWARD
var _speed := 50.0
var _life := 0.3


func launch(origin: Vector3, dir: Vector3, speed_mps: float, lifetime_sec: float) -> void:
	global_position = origin
	if dir.length_squared() > 0.0001:
		_dir = dir.normalized()
	_speed = maxf(speed_mps, 0.01)
	_life = maxf(lifetime_sec, 0.05)
	_orient()


func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_orient()
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _orient() -> void:
	if _dir.length_squared() < 0.0001:
		return
	if absf(_dir.dot(Vector3.UP)) > 0.98:
		look_at(global_position + _dir, Vector3.FORWARD)
	else:
		look_at(global_position + _dir, Vector3.UP)
