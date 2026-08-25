class_name PlayerDeathSequence
extends Node

## Orchestrates death VFX: board tumble, sail retract, hero ragdoll detach.

const HeroRagdollScript := preload("res://scripts/player/hero_ragdoll.gd")

const TERRAIN_COLLISION_MASK := 1
const HERO_RIG_PATH := NodePath("Visual/GliderSkin/Model/GliderRoot/Hero_Rig")

@export var settle_sec := 3.0
@export var detach_delay_sec := 0.3

var _glider: Node
var _active := false
var _settle_left := 0.0
var _detach_left := -1.0
var _saved_gravity_scale := 0.0
var _saved_collision_mask := 0
var _saved_can_sleep := false
var _saved_axis_lock_x := true
var _saved_axis_lock_z := true
var _saved_visual_basis := Basis.IDENTITY
var _hero_rig: Node3D
var _hero_hidden := false
var _ragdoll: Node


func _ready() -> void:
	_glider = _find_glider()


func _physics_process(delta: float) -> void:
	if not _active or _glider == null:
		return
	if _detach_left >= 0.0:
		_detach_left = maxf(_detach_left - delta, 0.0)
		if _detach_left <= 0.0:
			_detach_left = -1.0
			_spawn_hero_ragdoll()
	if settle_sec > 0.0:
		_settle_left = maxf(_settle_left - delta, 0.0)
		if _settle_left <= 0.0 and not _glider.sleeping:
			_glider.sleeping = true


func begin(reason: String) -> void:
	if _glider == null:
		_glider = _find_glider()
	if _active or _glider == null:
		return
	if reason != "death":
		return
	_active = true
	_settle_left = settle_sec
	_detach_left = detach_delay_sec
	_save_physics_state()
	_reset_visual_basis()
	_force_sail_retract()
	_enable_death_physics()


func cleanup() -> void:
	if not _active and _ragdoll == null and not _hero_hidden:
		return
	_active = false
	_settle_left = 0.0
	_detach_left = -1.0
	_cleanup_ragdoll()
	_show_hero_rig()
	_restore_physics_state()


func is_active() -> bool:
	return _active


func get_camera_target() -> Node3D:
	if not _active:
		return null
	if _ragdoll != null and is_instance_valid(_ragdoll):
		if _ragdoll.has_method("get_camera_anchor"):
			return _ragdoll.get_camera_anchor() as Node3D
		return _ragdoll as Node3D
	var hero := _get_hero_rig()
	if hero != null and hero.visible:
		return hero
	return null


func get_camera_velocity() -> Vector3:
	if not _active or _glider == null:
		return Vector3.ZERO
	if _ragdoll != null and is_instance_valid(_ragdoll) and _ragdoll.has_method("get_follow_velocity"):
		return _ragdoll.get_follow_velocity()
	return _glider.linear_velocity


func get_camera_body_yaw() -> float:
	if not _active or _glider == null:
		return 0.0
	if _ragdoll != null and is_instance_valid(_ragdoll):
		var vel := get_camera_velocity()
		var horizontal := Vector2(vel.x, vel.z)
		if horizontal.length_squared() > 0.25:
			return atan2(horizontal.x, horizontal.y)
		var anchor := get_camera_target()
		if anchor != null:
			return anchor.global_rotation.y
		return _glider.get_yaw()
	return _glider.get_yaw()


func is_camera_grounded() -> bool:
	return false


func _find_glider() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is GliderPlayer:
			return node
		node = node.get_parent()
	return null


func _save_physics_state() -> void:
	_saved_gravity_scale = _glider.gravity_scale
	_saved_collision_mask = _glider.collision_mask
	_saved_can_sleep = _glider.can_sleep
	_saved_axis_lock_x = _glider.axis_lock_angular_x
	_saved_axis_lock_z = _glider.axis_lock_angular_z
	var visual := _glider.get_node_or_null("Visual") as Node3D
	_saved_visual_basis = visual.basis if visual != null else Basis.IDENTITY


func _restore_physics_state() -> void:
	if _glider == null:
		return
	_glider.gravity_scale = _saved_gravity_scale
	_glider.collision_mask = _saved_collision_mask
	_glider.can_sleep = _saved_can_sleep
	_glider.axis_lock_angular_x = _saved_axis_lock_x
	_glider.axis_lock_angular_z = _saved_axis_lock_z
	_glider.set_death_physics_active(false)
	var visual := _glider.get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.basis = _saved_visual_basis


func _reset_visual_basis() -> void:
	var visual := _glider.get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.basis = Basis.IDENTITY


func _enable_death_physics() -> void:
	_glider.gravity_scale = 1.0
	_glider.collision_mask = TERRAIN_COLLISION_MASK
	_glider.can_sleep = true
	_glider.axis_lock_angular_x = false
	_glider.axis_lock_angular_z = false
	_glider.set_death_physics_active(true)


func _force_sail_retract() -> void:
	var sail := _glider.get_node_or_null("Visual/GliderSkin/SailAnimController")
	if sail != null and sail.has_method("force_retract_for_death"):
		sail.force_retract_for_death()


func _get_hero_rig() -> Node3D:
	if _hero_rig != null and is_instance_valid(_hero_rig):
		return _hero_rig
	_hero_rig = _glider.get_node_or_null(HERO_RIG_PATH) as Node3D
	return _hero_rig


func _spawn_hero_ragdoll() -> void:
	var hero := _get_hero_rig()
	if hero == null:
		return
	var tree := _glider.get_tree()
	if tree == null:
		return
	var xf := hero.global_transform
	var velocity: Vector3 = _glider.linear_velocity
	var impulse: Vector3 = (
		_glider.global_transform.basis.y * 2.5 + _glider.global_transform.basis.z * 1.5
	)
	var skel := hero.get_node_or_null("Skeleton3D") as Skeleton3D
	_ragdoll = HeroRagdollScript.spawn(tree, xf, velocity, impulse, skel)
	if _ragdoll != null and _ragdoll.has_method("disable_auto_expire"):
		_ragdoll.disable_auto_expire()
	hero.visible = false
	_hero_hidden = true


func _cleanup_ragdoll() -> void:
	if _ragdoll != null and is_instance_valid(_ragdoll):
		if _ragdoll.has_method("cleanup"):
			_ragdoll.cleanup()
		else:
			_ragdoll.queue_free()
	_ragdoll = null


func _show_hero_rig() -> void:
	var hero := _get_hero_rig()
	if hero != null:
		hero.visible = true
	_hero_hidden = false
