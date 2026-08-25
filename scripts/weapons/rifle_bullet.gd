class_name RifleBullet
extends Area3D

## Visible tracer; no gun mesh. Homes lightly on the locked pill.

const SPEED_MPS := 60.0
const LIFETIME_SEC := 2.4
const HOMING := 0.35
const DAMAGE := 10

var _target: Node3D
var _dir := Vector3.FORWARD
var _life := LIFETIME_SEC
var _spent := false


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func launch(origin: Vector3, target: Node3D, initial_dir: Vector3) -> void:
	global_position = origin
	_target = target
	if initial_dir.length_squared() > 0.0001:
		_dir = initial_dir.normalized()
	elif _aim_vector().length_squared() > 0.0001:
		_dir = _aim_vector().normalized()
	_orient()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var aim := _aim_vector()
	if aim.length_squared() > 0.0001:
		_dir = _dir.lerp(aim.normalized(), HOMING).normalized()
	global_position += _dir * SPEED_MPS * delta
	_orient()
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _aim_vector() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		_target = null
		return Vector3.ZERO
	return _target.global_position + Vector3(0.0, 0.7, 0.0) - global_position


func _orient() -> void:
	if _dir.length_squared() < 0.0001:
		return
	if absf(_dir.dot(Vector3.UP)) > 0.98:
		look_at(global_position + _dir, Vector3.FORWARD)
	else:
		look_at(global_position + _dir, Vector3.UP)


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	var pill := body as SwarmPill
	if pill == null:
		return
	_spent = true
	pill.take_damage(DAMAGE, global_position)
	queue_free()
