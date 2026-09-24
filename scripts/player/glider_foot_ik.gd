class_name GliderFootIk
extends Node

## Enables scene-authored TwoBoneIK3D leg modifiers when feet should track board targets.
## Board Foot_L / Foot_R RemoteTransform3D nodes drive skeleton L_Foot / R_Foot markers.

const LEG_IK_LEFT := NodePath("Model/GliderRoot/Hero_Rig/Skeleton3D/Left_LegIK")
const LEG_IK_RIGHT := NodePath("Model/GliderRoot/Hero_Rig/Skeleton3D/Right_LegIK")
const BOARD_FOOT_LEFT := NodePath("Model/GliderRoot/GliderBoard/Foot_L")
const BOARD_FOOT_RIGHT := NodePath("Model/GliderRoot/GliderBoard/Foot_R")
const FOOT_REMOTE_NAME := NodePath("RemoteTransform3D")

@export var leg_ik_enabled := true

var _left_ik: TwoBoneIK3D
var _right_ik: TwoBoneIK3D
var _left_foot_remote: RemoteTransform3D
var _right_foot_remote: RemoteTransform3D
var _leg_ik_active := false
var _configured := false


func _ready() -> void:
	call_deferred("_setup_leg_ik")


func _setup_leg_ik() -> void:
	var skin := get_parent()
	if skin == null:
		push_error("GliderFootIk: expected parent GliderSkin node")
		return
	_left_ik = skin.get_node_or_null(LEG_IK_LEFT) as TwoBoneIK3D
	_right_ik = skin.get_node_or_null(LEG_IK_RIGHT) as TwoBoneIK3D
	if _left_ik == null or _right_ik == null:
		push_error("GliderFootIk: missing Left_LegIK / Right_LegIK on hero skeleton")
		return
	var foot_l := skin.get_node_or_null(BOARD_FOOT_LEFT) as Node3D
	var foot_r := skin.get_node_or_null(BOARD_FOOT_RIGHT) as Node3D
	if foot_l == null or foot_r == null:
		push_error("GliderFootIk: missing GliderBoard Foot_L / Foot_R anchors")
		return
	_left_foot_remote = foot_l.get_node_or_null(FOOT_REMOTE_NAME) as RemoteTransform3D
	_right_foot_remote = foot_r.get_node_or_null(FOOT_REMOTE_NAME) as RemoteTransform3D
	if _left_foot_remote == null or _right_foot_remote == null:
		push_error("GliderFootIk: missing RemoteTransform3D on board foot anchors")
		return
	_configured = true
	set_leg_ik_active(false)


func is_configured() -> bool:
	return _configured


func set_leg_ik_active(enabled: bool) -> void:
	if not _configured:
		return
	var on := enabled and leg_ik_enabled
	if on == _leg_ik_active:
		return
	_leg_ik_active = on
	_left_ik.active = on
	_right_ik.active = on
	_set_foot_remote_active(on)


func is_leg_ik_active() -> bool:
	return _leg_ik_active


func set_active_for_locomotion_move(enabled: bool) -> void:
	set_leg_ik_active(enabled)


func is_active_for_locomotion_move() -> bool:
	return is_leg_ik_active()


func _set_foot_remote_active(on: bool) -> void:
	_left_foot_remote.update_position = on
	_left_foot_remote.update_rotation = false
	_left_foot_remote.update_scale = false
	_right_foot_remote.update_position = on
	_right_foot_remote.update_rotation = false
	_right_foot_remote.update_scale = false
