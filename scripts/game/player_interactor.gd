class_name PlayerInteractor
extends Node

const INTERACT_HOLD_SEC := 0.75
const INTERACT_MAX_SPEED := 2.5

var _rig: PlayerRig
var _glider: GliderPlayer
var _antenna_state: AntennaState
var _tower: UpgradeTower
var _expedition: ExpeditionState
var _hold_progress := 0.0
var _touch_hold_active := false
var _prompt := { "visible": false, "label": "", "progress": 0.0, "tap_action": false }


func _ready() -> void:
	_rig = get_parent() as PlayerRig
	if _rig != null:
		_glider = _rig.get_node_or_null("Glider") as GliderPlayer


func _process(delta: float) -> void:
	if _rig == null:
		return

	_resolve_world_refs()

	var action: Dictionary = _resolve_action()
	var can_interact := not action.is_empty() and _is_slow_enough()
	var action_type: String = action.get("type", "")
	var holding := Input.is_action_pressed("interact") or _touch_hold_active

	if can_interact and holding and action_type == "rest":
		_hold_progress += delta / INTERACT_HOLD_SEC
		if _hold_progress >= 1.0:
			_complete_rest()
			_hold_progress = 0.0
	elif not holding:
		_hold_progress = 0.0

	_prompt = {
		"visible": can_interact,
		"label": action.get("label", ""),
		"progress": clampf(_hold_progress, 0.0, 1.0) if can_interact else 0.0,
		"tap_action": false,
	}


func get_interact_prompt() -> Dictionary:
	return _prompt


func set_touch_hold(active: bool) -> void:
	_touch_hold_active = active


func _resolve_world_refs() -> void:
	if _antenna_state == null or not is_instance_valid(_antenna_state):
		_antenna_state = get_tree().get_first_node_in_group("antenna_state") as AntennaState
	_tower = _find_nearest_tower()
	if _glider == null and _rig != null:
		_glider = _rig.get_node_or_null("Glider") as GliderPlayer
	if _expedition == null or not is_instance_valid(_expedition):
		_expedition = get_tree().get_first_node_in_group("expedition_state") as ExpeditionState


func _find_nearest_tower() -> UpgradeTower:
	var body := _get_active_body()
	var origin := body.global_position if body != null else (
		_glider.global_position if _glider != null else Vector3.ZERO
	)
	return WorldQueries.nearest_in_group(get_tree(), "upgrade_tower", origin) as UpgradeTower


func _get_active_body() -> PhysicsBody3D:
	if _rig == null:
		return null
	return _rig.get_active_body()


func _is_slow_enough() -> bool:
	var body := _get_active_body()
	if body == null:
		return false
	return MathUtil.horizontal_speed(body.velocity) <= INTERACT_MAX_SPEED


func _resolve_action() -> Dictionary:
	if _can_rest():
		return { "type": "rest", "label": "REST" }
	return {}


func _can_rest() -> bool:
	var body := _get_active_body()
	if _tower == null or _antenna_state == null or body == null:
		return false
	if not _antenna_state.is_within_hub(body.global_position, _tower.global_position):
		return false
	if _glider != null and _glider.is_run_ended():
		return false
	return true


func _complete_rest() -> void:
	if _expedition == null:
		return
	_expedition.end_day()
