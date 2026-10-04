class_name GliderFootIk
extends Node

## Enables scene-authored TwoBoneIK3D leg modifiers when feet should track board targets.

const LEG_IK_LEFT := NodePath("Model/GliderRoot/Hero_Rig/Skeleton3D/Left_LegIK")
const LEG_IK_RIGHT := NodePath("Model/GliderRoot/Hero_Rig/Skeleton3D/Right_LegIK")

@export var leg_ik_enabled := true

var _left_ik: TwoBoneIK3D
var _right_ik: TwoBoneIK3D
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


func is_leg_ik_active() -> bool:
	return _leg_ik_active


func set_active_for_locomotion_move(enabled: bool) -> void:
	set_leg_ik_active(enabled)


func is_active_for_locomotion_move() -> bool:
	return is_leg_ik_active()
