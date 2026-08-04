class_name ScoutDrone
extends CharacterBody3D

enum State { PATROL, INVESTIGATE, CHASE, RETURN }

const PATROL_RADIUS := 14.0
const PATROL_HEIGHT := 4.5
const PATROL_SPEED := 2.8
const CHASE_SPEED := 6.2
const INVESTIGATE_SPEED := 4.5
const RETURN_SPEED := 3.6
const ALARM_DURATION := 10.0
const PATROL_ANGLE_RATE := 0.55
const HOVER_BOB_AMPLITUDE := 0.18
const HOVER_BOB_RATE := 2.4
const KNOCKBACK_IMPULSE := 4.5
const GIVE_UP_RADIUS := 28.0

var _anchor: Vector3 = Vector3.ZERO
var _patrol_angle := 0.0
var _state := State.PATROL
var _target: Node3D
var _alarm_timer := 0.0
var _bob_time := 0.0
var _investigate_point := Vector3.ZERO


func _ready() -> void:
	add_to_group("scout_drone")
	motion_mode = MOTION_MODE_FLOATING
	_anchor = global_position
	_patrol_angle = randf() * TAU


func configure(anchor: Vector3, start_angle: float = -1.0) -> void:
	_anchor = anchor
	if start_angle >= 0.0:
		_patrol_angle = start_angle
	else:
		_patrol_angle = randf() * TAU
	global_position = _patrol_position()
	_state = State.PATROL


func raise_alarm(target: Node3D) -> void:
	if target == null:
		return
	_target = target
	_alarm_timer = ALARM_DURATION
	_state = State.INVESTIGATE
	_investigate_point = target.global_position


func _physics_process(delta: float) -> void:
	_bob_time += delta * HOVER_BOB_RATE
	if _alarm_timer > 0.0:
		_alarm_timer = maxf(_alarm_timer - delta, 0.0)

	match _state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			_investigate(delta)
		State.CHASE:
			_chase(delta)
		State.RETURN:
			_return_home(delta)

	_apply_hover_bob()
	move_and_slide()
	_orient_to_velocity()


func _patrol(delta: float) -> void:
	_patrol_angle += PATROL_ANGLE_RATE * delta
	var desired := _patrol_position()
	velocity = (desired - global_position) / maxf(delta, 0.0001)
	if velocity.length() > PATROL_SPEED:
		velocity = velocity.normalized() * PATROL_SPEED

	if _target != null and is_instance_valid(_target) and _alarm_timer > 0.0:
		_state = State.INVESTIGATE
		_investigate_point = _target.global_position


func _investigate(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_begin_return()
		return

	_investigate_point = _target.global_position
	var to_target := _investigate_point - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 2.25:
		_state = State.CHASE
		return

	velocity = to_target.normalized() * INVESTIGATE_SPEED
	if _alarm_timer <= 0.0:
		_begin_return()


func _chase(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_begin_return()
		return

	var to_target := _target.global_position - global_position
	var flat_dist := Vector2(to_target.x, to_target.z).length()
	if flat_dist > GIVE_UP_RADIUS or _alarm_timer <= 0.0:
		_begin_return()
		return

	var desired := _target.global_position + Vector3(0.0, PATROL_HEIGHT, 0.0)
	velocity = (desired - global_position) / maxf(delta, 0.0001)
	if velocity.length() > CHASE_SPEED:
		velocity = velocity.normalized() * CHASE_SPEED


func _return_home(delta: float) -> void:
	var desired := _patrol_position()
	var to_home := desired - global_position
	if to_home.length_squared() < 0.25:
		_state = State.PATROL
		_target = null
		velocity = Vector3.ZERO
		return
	velocity = to_home.normalized() * RETURN_SPEED


func _begin_return() -> void:
	_state = State.RETURN
	_target = null


func _patrol_position() -> Vector3:
	return Vector3(
		_anchor.x + cos(_patrol_angle) * PATROL_RADIUS,
		_anchor.y + PATROL_HEIGHT,
		_anchor.z + sin(_patrol_angle) * PATROL_RADIUS
	)


func _apply_hover_bob() -> void:
	global_position.y = _anchor.y + PATROL_HEIGHT + sin(_bob_time) * HOVER_BOB_AMPLITUDE


func _orient_to_velocity() -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.04:
		return
	rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 0.15)


func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		var push: Vector3 = global_position - character.global_position
		push.y = 0.0
		if push.length_squared() < 0.01:
			push = Vector3.FORWARD
		push = push.normalized()
		body.velocity += push * KNOCKBACK_IMPULSE
	elif body is RigidBody3D:
		var rigid := body as RigidBody3D
		var push := (rigid.global_position - global_position).normalized()
		push.y = 0.2
		rigid.apply_central_impulse(-push * KNOCKBACK_IMPULSE * rigid.mass)
