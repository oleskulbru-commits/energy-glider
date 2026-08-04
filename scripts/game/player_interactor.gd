class_name PlayerInteractor
extends Node

const INTERACT_HOLD_SEC := 0.75
const INTERACT_MAX_SPEED := 2.5

var _rig: PlayerRig
var _glider: GliderPlayer
var _cargo: PlayerCargo
var _antenna_state: AntennaState
var _tower: WeatherStation
var _loot_overlay: LootOverlay
var _expedition: ExpeditionState
var _hold_progress := 0.0
var _touch_hold_active := false
var _mount_blocked_frame := false
var _breach_alarm_sent := false
var _prompt := { "visible": false, "label": "", "progress": 0.0, "tap_action": false }


func _ready() -> void:
	_rig = get_parent() as PlayerRig
	if _rig != null:
		_glider = _rig.get_node_or_null("Glider") as GliderPlayer
	_cargo = get_parent().get_node_or_null("PlayerCargo") as PlayerCargo
	call_deferred("_resolve_loot_overlay")


func _process(delta: float) -> void:
	if _rig == null:
		return
	if _loot_overlay != null and _loot_overlay.is_open():
		_prompt = { "visible": false, "label": "", "progress": 0.0, "tap_action": false }
		return

	_resolve_world_refs()
	_mount_blocked_frame = false

	var mount_prompt: Dictionary = _rig.get_mount_prompt()
	if mount_prompt.get("visible", false):
		_prompt = mount_prompt.duplicate()
		_prompt["progress"] = 0.0
		_hold_progress = 0.0
		return

	var action: Dictionary = _resolve_action()
	var can_interact := not action.is_empty() and _is_slow_enough()
	var action_type: String = action.get("type", "")
	var holding := Input.is_action_pressed("interact") or _touch_hold_active

	if can_interact and action_type == "loot" and action.get("instant", false):
		if Input.is_action_just_pressed("interact"):
			_open_loot_container(action.get("container") as LootContainer)
		_hold_progress = 0.0
		_breach_alarm_sent = false
	elif can_interact and holding:
		if action_type == "deposit":
			_hold_progress += delta / INTERACT_HOLD_SEC
			if _hold_progress >= 1.0:
				_complete_deposit()
				_hold_progress = 0.0
		elif action_type == "rest":
			_hold_progress += delta / INTERACT_HOLD_SEC
			if _hold_progress >= 1.0:
				_complete_rest()
				_hold_progress = 0.0
		elif action_type == "loot":
			var container := action.get("container") as LootContainer
			if not _breach_alarm_sent:
				_raise_container_alarm(container)
				_breach_alarm_sent = true
			var duration := INTERACT_HOLD_SEC
			if container != null:
				duration = maxf(container.get_breach_duration(), 0.1)
			_hold_progress += delta / duration
			if _hold_progress >= 1.0:
				_open_loot_container(container)
				_hold_progress = 0.0
				_breach_alarm_sent = false
	elif not holding:
		_hold_progress = 0.0
		_breach_alarm_sent = false

	var show_progress: bool = (
		can_interact
		and action_type in ["deposit", "loot", "rest"]
		and not bool(action.get("instant", false))
	)
	_prompt = {
		"visible": can_interact,
		"label": action.get("label", ""),
		"progress": clampf(_hold_progress, 0.0, 1.0) if show_progress else 0.0,
		"tap_action": can_interact and action.get("instant", false),
	}


func is_loot_ui_open() -> bool:
	return _loot_overlay != null and _loot_overlay.is_open()


func get_interact_prompt() -> Dictionary:
	return _prompt


func set_touch_hold(active: bool) -> void:
	_touch_hold_active = active


func notify_mount_toggle() -> void:
	_mount_blocked_frame = true
	_hold_progress = 0.0


func _resolve_loot_overlay() -> void:
	if _rig == null:
		return
	_loot_overlay = _rig.get_node_or_null("LootOverlay") as LootOverlay


func _resolve_world_refs() -> void:
	if _antenna_state == null or not is_instance_valid(_antenna_state):
		_antenna_state = get_tree().get_first_node_in_group("antenna_state") as AntennaState
	_tower = _find_nearest_station()
	if _glider == null and _rig != null:
		_glider = _rig.get_node_or_null("Glider") as GliderPlayer
	if _loot_overlay == null and _rig != null:
		_loot_overlay = _rig.get_node_or_null("LootOverlay") as LootOverlay
	if _expedition == null or not is_instance_valid(_expedition):
		_expedition = get_tree().get_first_node_in_group("expedition_state") as ExpeditionState


func _find_nearest_station() -> WeatherStation:
	var body := _get_active_body()
	var origin := body.global_position if body != null else (
		_glider.global_position if _glider != null else Vector3.ZERO
	)
	return WorldQueries.nearest_in_group(get_tree(), "weather_station", origin) as WeatherStation


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
	if _cargo == null:
		return {}

	if _can_deposit():
		return { "type": "deposit", "label": "INSTALL" }

	if _can_rest():
		return { "type": "rest", "label": "REST" }

	if _can_loot():
		var container := _find_nearest_container()
		if container != null:
			return {
				"type": "loot",
				"label": container.get_prompt_label(),
				"container": container,
				"instant": container.is_breached(),
			}

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


func _can_loot() -> bool:
	if _rig == null:
		return false
	if _rig.is_mounted():
		return false
	var body := _get_active_body()
	if body == null:
		return false
	return _find_nearest_container() != null


func _find_nearest_container() -> LootContainer:
	var body := _get_active_body()
	if body == null:
		return null

	var best: LootContainer = null
	var best_dist := INF

	for node in get_tree().get_nodes_in_group("wreck_site"):
		var wreck := node as WreckSite
		if wreck == null or wreck.is_depleted():
			continue
		var container := wreck.get_loot_container()
		if container == null or not container.can_interact(body):
			continue
		var dist := wreck.global_position.distance_squared_to(body.global_position)
		if dist < best_dist:
			best_dist = dist
			best = container

	for node in get_tree().get_nodes_in_group("loot_container"):
		var container := node as LootContainer
		if container == null or not container.can_interact(body):
			continue
		if container.get_parent() is WreckSite:
			continue
		var host := container.get_parent() as Node3D
		if host == null:
			continue
		var dist := host.global_position.distance_squared_to(body.global_position)
		if dist < best_dist:
			best_dist = dist
			best = container

	return best


func _can_deposit() -> bool:
	var body := _get_active_body()
	if _tower == null or _antenna_state == null or body == null or _cargo == null:
		return false
	if _cargo.count_items_of_type(CargoTypes.Type.ANTENNA_PART) <= 0:
		return false
	if _antenna_state.installed_parts >= _antenna_state.total_parts:
		return false
	return _antenna_state.is_within_hub(body.global_position, _tower.global_position)


func _complete_deposit() -> void:
	var body := _get_active_body()
	if _tower != null and _antenna_state != null and _cargo != null and _glider != null and body != null:
		_tower.try_deposit(body, _cargo, _antenna_state, _glider)


func _open_loot_container(container: LootContainer) -> void:
	if container == null or _loot_overlay == null or _cargo == null:
		return
	if not container.is_breached():
		container.breach()
	_loot_overlay.open(container, _cargo)


func _raise_container_alarm(container: LootContainer) -> void:
	if container == null:
		return
	var body := _get_active_body()
	var parent := container.get_parent()
	if parent is WreckSite:
		(parent as WreckSite).raise_alarm(body)


func blocks_mount_toggle() -> bool:
	if is_loot_ui_open():
		return true
	var action := _resolve_action()
	var action_type: String = action.get("type", "")
	return action_type == "loot" or action_type == "deposit" or action_type == "rest"
