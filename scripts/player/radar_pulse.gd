class_name RadarPulse
extends Node

signal cooldown_changed(remaining_sec: float, cooldown_sec: float)
signal pulse_fired(target_ripple: int)

const COOLDOWN_SEC := 5.0
const BEAM_DURATION_SEC := 4.0

var _rig: PlayerRig
var _interactor: PlayerInteractor
var _cooldown_remaining := 0.0


func _ready() -> void:
	_rig = get_parent() as PlayerRig
	_interactor = _rig.get_node_or_null("PlayerInteractor") as PlayerInteractor if _rig != null else null


func _process(delta: float) -> void:
	if _cooldown_remaining <= 0.0:
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	cooldown_changed.emit(_cooldown_remaining, COOLDOWN_SEC)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("radar_pulse"):
		return
	try_pulse()


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func get_cooldown_ratio() -> float:
	if COOLDOWN_SEC <= 0.0:
		return 0.0
	return clampf(_cooldown_remaining / COOLDOWN_SEC, 0.0, 1.0)


func is_ready() -> bool:
	return _cooldown_remaining <= 0.0


func try_pulse() -> bool:
	if not _can_pulse():
		return false
	if _cooldown_remaining > 0.0:
		return false

	var pois := get_tree().get_nodes_in_group("radar_poi")
	var target_ripple := resolve_target_ripple(pois)
	if target_ripple < 0:
		return false

	var revealed := false
	for node in pois:
		if not _is_radar_poi(node):
			continue
		if int(node.get("ripple_index")) != target_ripple:
			continue
		if not bool(node.call("is_pulse_target_active")):
			continue
		var beacon = node.call("get_radar_beacon")
		if beacon != null and beacon.has_method("reveal"):
			beacon.reveal(BEAM_DURATION_SEC)
			revealed = true

	if not revealed:
		return false

	_cooldown_remaining = COOLDOWN_SEC
	cooldown_changed.emit(_cooldown_remaining, COOLDOWN_SEC)
	pulse_fired.emit(target_ripple)
	return true


static func resolve_target_ripple(pois: Array) -> int:
	var target := -1
	for node in pois:
		if not _is_radar_poi(node):
			continue
		if not bool(node.call("is_pulse_target_active")):
			continue
		var ripple_index := int(node.get("ripple_index"))
		if target < 0 or ripple_index < target:
			target = ripple_index
	return target


static func _is_radar_poi(node: Object) -> bool:
	return (
		node != null
		and node.has_method("is_pulse_target_active")
		and node.has_method("get_radar_beacon")
		and node.get("ripple_index") != null
	)


func _can_pulse() -> bool:
	if _rig == null:
		return false
	if not _rig.is_mounted():
		return false
	if _interactor == null:
		_interactor = _rig.get_node_or_null("PlayerInteractor") as PlayerInteractor
	if _interactor != null and _interactor.is_loot_ui_open():
		return false
	return true
