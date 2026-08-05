class_name GliderHUD
extends CanvasLayer

const POWER_LOW_THRESHOLD := 0.20
const POWER_COLOR_NORMAL := Color(0.35, 0.88, 0.95)
const POWER_COLOR_LOW := Color(0.98, 0.78, 0.18)
const POWER_COLOR_EMPTY := Color(0.85, 0.28, 0.22)
const POWER_COLOR_SOLAR := Color(0.98, 0.82, 0.28)
const POWER_COLOR_OVERHEAT := Color(0.98, 0.45, 0.18)
const PULSE_COLOR := Color(1.0, 0.82, 0.28, 1.0)

const GliderInputScript = preload("res://scripts/input/glider_input.gd")

@onready var _power_label: Label = %PowerLabel
@onready var _power_percent_label: Label = %PowerPercent
@onready var _solar_chip: PanelContainer = %SolarChip
@onready var _power_bar: ProgressBar = %PowerBar
@onready var _stopped_overlay: PanelContainer = %StoppedOverlay
@onready var _stopped_distance: Label = %StoppedDistance
@onready var _interact_chip: PanelContainer = %InteractChip
@onready var _interact_label: Label = %InteractLabel
@onready var _interact_bar: ProgressBar = %InteractBar
@onready var _stop_chip: PanelContainer = %StopChip
@onready var _stop_label: Label = %StopLabel
@onready var _sail_chip: PanelContainer = %SailChip
@onready var _sail_label: Label = %SailLabel
@onready var _cargo_chip: PanelContainer = %CargoChip
@onready var _cargo_label: Label = %CargoLabel
@onready var _pulse_chip: PanelContainer = %PulseChip
@onready var _pulse_label: Label = %PulseLabel
@onready var _pulse_bar: ProgressBar = %PulseBar
@onready var _day_label: Label = %DayLabel
@onready var _compass_bar: CompassBar = %CompassBar
@onready var _stopped_summary: Label = %StoppedSummary
@onready var _day_summary_panel: PanelContainer = %DaySummaryPanel
@onready var _day_summary_label: Label = %DaySummaryLabel
@onready var _outpost_board: PanelContainer = %OutpostBoard
@onready var _outpost_board_label: Label = %OutpostBoardLabel

var _rig: PlayerRig
var _player: GliderPlayer
var _camera: GliderCamera
var _input: GliderInputScript
var _radar_pulse: RadarPulse
var _run_score: RunScore
var _expedition: ExpeditionState
var _interactor: PlayerInteractor
var _cargo: PlayerCargo
var _power_fill: StyleBoxFlat
var _solar_pulse_time := 0.0
var _interact_tap_down := false
var _pulse_scan_timer := 0.0
var _day_summary_timer := 0.0


func _ready() -> void:
	layer = 10
	_rig = get_parent() as PlayerRig
	if _rig != null:
		_player = _rig.get_node_or_null("Glider") as GliderPlayer
		_input = _rig.get_node_or_null("GliderInput") as GliderInputScript
		_interactor = _rig.get_node_or_null("PlayerInteractor") as PlayerInteractor
		_cargo = _rig.get_node_or_null("PlayerCargo") as PlayerCargo
		_radar_pulse = _rig.get_node_or_null("RadarPulse") as RadarPulse
		_camera = _rig.get_node_or_null("Glider/Camera3D") as GliderCamera
	else:
		_player = get_parent() as GliderPlayer
		_input = _player.get_node_or_null("GliderInput") as GliderInputScript
		_interactor = _player.get_node_or_null("PlayerInteractor") as PlayerInteractor
		if _interactor == null:
			_interactor = _player.get_node_or_null("GliderInteractor") as PlayerInteractor

	_run_score = get_tree().get_first_node_in_group("run_score") as RunScore
	_expedition = get_tree().get_first_node_in_group("expedition_state") as ExpeditionState
	if _expedition != null:
		_expedition.day_started.connect(_on_day_started)
		_expedition.day_ended.connect(_on_day_ended)
		_on_day_started(_expedition.current_day)
	_power_fill = _power_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_power_bar.add_theme_stylebox_override("fill", _power_fill)
	_interact_chip.gui_input.connect(_on_interact_chip_gui_input)
	_stop_chip.gui_input.connect(_on_stop_chip_gui_input)
	if _sail_chip != null:
		_sail_chip.visible = false
	if _cargo != null:
		_cargo.cargo_changed.connect(_on_cargo_changed)
		_update_cargo_display()
	if _radar_pulse != null:
		_radar_pulse.pulse_fired.connect(_on_pulse_fired)
		_radar_pulse.cooldown_changed.connect(_on_pulse_cooldown_changed)
	_update_pulse_chip()


func _process(delta: float) -> void:
	if _player == null and _rig != null:
		_player = _rig.get_node_or_null("Glider") as GliderPlayer
	if _input == null and _rig != null:
		_input = _rig.get_node_or_null("GliderInput") as GliderInputScript
	if _player == null:
		return

	_update_power_meter(delta)
	_update_landing_feedback()
	_update_interact_prompt()
	_update_stop_chip()
	_update_cargo_display()
	_update_pulse_chip(delta)
	_update_compass()
	_update_outpost_board()
	_update_day_summary(delta)

	_stopped_overlay.visible = _player.is_run_ended()
	if _player.is_run_ended():
		_update_stopped_overlay()


func _update_power_meter(delta: float) -> void:
	var power_ratio := _player.get_charge_ratio()
	var overheat_ratio := _player.get_overheat_cooldown_ratio()
	var cooling_progress := 1.0 - overheat_ratio

	_power_bar.value = power_ratio * 100.0
	_power_percent_label.text = "%d%%" % int(roundf(power_ratio * 100.0))

	if _player.is_run_ended():
		_power_label.text = "STOPPED"
	elif _rig != null and not _rig.is_mounted():
		_power_label.text = "ON FOOT"
	elif _player.is_overheated():
		_power_label.text = "COOLING"
	else:
		_power_label.text = "Thruster Charge"

	var solar_active := _player.is_solar_charging()
	_solar_chip.visible = solar_active and (_rig == null or _rig.is_mounted())

	if _power_fill == null:
		return

	if _player.is_run_ended():
		_power_fill.bg_color = POWER_COLOR_EMPTY
	elif _player.is_overheated():
		_power_fill.bg_color = POWER_COLOR_OVERHEAT.lerp(POWER_COLOR_NORMAL, cooling_progress)
	elif solar_active:
		_solar_pulse_time += delta * 4.0
		var pulse := (sin(_solar_pulse_time) + 1.0) * 0.5
		_power_fill.bg_color = POWER_COLOR_NORMAL.lerp(POWER_COLOR_SOLAR, pulse)
	elif power_ratio < POWER_LOW_THRESHOLD:
		_power_fill.bg_color = POWER_COLOR_LOW
	else:
		_power_fill.bg_color = POWER_COLOR_NORMAL


func _on_day_started(day: int) -> void:
	if _day_label != null:
		_day_label.text = "DAY %d" % day


func _on_day_ended(summary: Dictionary) -> void:
	if _day_summary_panel == null or _day_summary_label == null:
		return
	var distance_m := float(summary.get("distance_m", 0.0))
	var score := int(summary.get("score", 0))
	_day_summary_label.text = "DAY %d COMPLETE\n%s  +%d pts" % [
		int(summary.get("day", 1)),
		MathUtil.format_distance_m(distance_m),
		score,
	]
	_day_summary_panel.visible = true
	_day_summary_timer = 3.5


func _update_day_summary(delta: float) -> void:
	if _day_summary_timer <= 0.0:
		if _day_summary_panel != null:
			_day_summary_panel.visible = false
		return
	_day_summary_timer = maxf(_day_summary_timer - delta, 0.0)
	if _day_summary_timer <= 0.0 and _day_summary_panel != null:
		_day_summary_panel.visible = false


func _update_stopped_overlay() -> void:
	if _run_score != null:
		_stopped_distance.text = _run_score.format_distance()
	if _stopped_summary != null and _expedition != null:
		_stopped_summary.text = "Score %d" % _expedition.total_score


func _update_compass() -> void:
	if _compass_bar == null:
		return
	if _camera == null and _rig != null:
		_camera = _rig.get_node_or_null("Glider/Camera3D") as GliderCamera
	if _camera == null:
		return

	var yaw := _camera.get_follow_yaw()
	_compass_bar.set_yaw(yaw)

	var track_pos := _tracking_position()

	var poi_bearing := _resolve_poi_bearing(track_pos)
	if is_nan(poi_bearing):
		_compass_bar.set_poi_bearing(NAN)
	else:
		_compass_bar.set_poi_bearing(poi_bearing)

	_compass_bar.set_outpost_bearings(_resolve_outpost_bearings(track_pos, 3))


func _tracking_position() -> Vector3:
	if _rig != null:
		return _rig.get_tracking_position()
	return _player.global_position


func _resolve_outpost_bearings(track_pos: Vector3, limit: int) -> Array:
	var ranked := WorldQueries.ranked_in_group(
		get_tree(),
		"weather_station",
		track_pos,
		40.0
	)
	var bearings: Array = []
	for i in mini(limit, ranked.size()):
		bearings.append(float(ranked[i].bearing))
	return bearings


func _update_outpost_board() -> void:
	if _outpost_board == null or _outpost_board_label == null or _player == null:
		return
	var track_pos := _tracking_position()

	var ranked := WorldQueries.ranked_in_group(get_tree(), "weather_station", track_pos)
	if ranked.is_empty():
		_outpost_board.visible = false
		return

	var hub := ranked[0].node as Node3D
	var hub_dist := float(ranked[0].dist)
	if hub == null or hub_dist > AntennaState.HUB_RADIUS_M:
		_outpost_board.visible = false
		return

	var neighbors := WorldQueries.ranked_in_group(
		get_tree(),
		"weather_station",
		hub.global_position,
		0.0,
		hub
	)

	var lines: PackedStringArray = PackedStringArray(["NEARBY OUTPOSTS"])
	for i in mini(3, neighbors.size()):
		var entry: Dictionary = neighbors[i]
		lines.append("%s  %s" % [
			_bearing_to_compass_label(float(entry.bearing)),
			MathUtil.format_distance_m(float(entry.dist)),
		])
	_outpost_board_label.text = "\n".join(lines)
	_outpost_board.visible = true


func _bearing_to_compass_label(bearing_rad: float) -> String:
	var deg := int(roundf(rad_to_deg(wrapf(bearing_rad, 0.0, TAU)))) % 360
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var idx := int(roundf(float(deg) / 45.0)) % 8
	return dirs[idx]


func _resolve_poi_bearing(track_pos: Vector3) -> float:
	var best_ripple := 9999
	var best_pos := Vector3.ZERO
	var found := false
	for node in get_tree().get_nodes_in_group("radar_poi"):
		if not node.has_method("is_pulse_target_active"):
			continue
		if not bool(node.call("is_pulse_target_active")):
			continue
		var ripple_index := int(node.get("ripple_index"))
		if ripple_index < best_ripple:
			best_ripple = ripple_index
			if node is Node3D:
				best_pos = (node as Node3D).global_position
				found = true
	if not found:
		return NAN
	return MathUtil.bearing_to(track_pos, best_pos)


func _on_cargo_changed(_used_slots: int, _capacity: int) -> void:
	_update_cargo_display()


func _update_cargo_display() -> void:
	if _cargo_chip == null or _cargo_label == null:
		return
	if _cargo == null:
		_cargo = get_tree().get_first_node_in_group("player_cargo") as PlayerCargo
	if _cargo == null:
		_cargo_chip.visible = false
		return
	_cargo_chip.visible = _cargo.has_cargo()
	if _cargo_chip.visible:
		_cargo_label.text = "%s  %s" % [_cargo.get_cargo_label(), _cargo.get_summary_label()]


func _update_landing_feedback() -> void:
	if _sail_chip == null or _sail_label == null or _player == null:
		return

	var feedback: Dictionary = _player.get_landing_feedback()
	if feedback.get("timer", 0.0) <= 0.01:
		_sail_chip.visible = false
		return

	# SailChip nodes host landing HARD/SKIM feedback in the current HUD scene.
	_sail_chip.visible = true
	_sail_label.text = feedback.get("label", "")
	_sail_label.remove_theme_color_override("font_color")


func _update_interact_prompt() -> void:
	if _interactor == null:
		_interact_chip.visible = false
		return

	var prompt: Dictionary = _interactor.get_interact_prompt()
	_interact_chip.visible = prompt.get("visible", false)
	if not _interact_chip.visible:
		return

	_interact_label.text = prompt.get("label", "")
	var tap_action: bool = prompt.get("tap_action", false)
	if tap_action:
		_interact_bar.visible = false
	else:
		_interact_bar.visible = true
		_interact_bar.value = prompt.get("progress", 0.0)


func _update_stop_chip() -> void:
	if _player == null or _stop_chip == null:
		return

	if _rig != null and not _rig.is_mounted():
		_stop_chip.visible = false
		return

	var speed := MathUtil.horizontal_speed(_player.velocity)
	var show_chip := (_player.is_braking() or speed > 0.8) and not _player.is_run_ended()
	_stop_chip.visible = show_chip
	if not show_chip:
		return

	_stop_label.text = "STOP"
	if _player.is_braking():
		_stop_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45, 1))
	else:
		_stop_label.remove_theme_color_override("font_color")


func _on_pulse_fired(_target_ripple: int) -> void:
	_pulse_scan_timer = 0.45


func _on_pulse_cooldown_changed(_remaining_sec: float, _cooldown_sec: float) -> void:
	_update_pulse_chip()


func _update_pulse_chip(delta: float = 0.0) -> void:
	if _pulse_chip == null or _pulse_label == null or _pulse_bar == null:
		return
	if _radar_pulse == null and _rig != null:
		_radar_pulse = _rig.get_node_or_null("RadarPulse") as RadarPulse

	var mounted: bool = _rig == null or _rig.is_mounted()
	_pulse_chip.visible = mounted and _player != null and not _player.is_run_ended()
	if not _pulse_chip.visible:
		return

	if _pulse_scan_timer > 0.0:
		_pulse_scan_timer = maxf(_pulse_scan_timer - delta, 0.0)

	var cooldown_ratio := 0.0
	if _radar_pulse != null:
		cooldown_ratio = _radar_pulse.get_cooldown_ratio()

	if _pulse_scan_timer > 0.0:
		_pulse_label.text = "SCANNING"
		_pulse_label.add_theme_color_override("font_color", PULSE_COLOR)
	elif cooldown_ratio > 0.0:
		var remaining := 0.0
		if _radar_pulse != null:
			remaining = _radar_pulse.get_cooldown_remaining()
		_pulse_label.text = "PULSE %.0fs" % ceilf(remaining)
		_pulse_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72, 1.0))
	else:
		_pulse_label.text = "PULSE [Q]"
		_pulse_label.add_theme_color_override("font_color", PULSE_COLOR)

	_pulse_bar.visible = cooldown_ratio > 0.0
	_pulse_bar.value = 1.0 - cooldown_ratio


func _on_interact_chip_gui_input(event: InputEvent) -> void:
	if _interactor == null:
		return

	if event is InputEventMouseButton:
		if event is InputEvent:
			(event as InputEvent).set_handled()

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_interact_tap_down = true
				if _interactor.get_interact_prompt().get("tap_action", false):
					if _rig != null:
						_rig.request_mount_toggle()
					return
			else:
				_interact_tap_down = false
			_interactor.set_touch_hold(mouse.pressed and not _interactor.get_interact_prompt().get("tap_action", false))


func _on_stop_chip_gui_input(event: InputEvent) -> void:
	if _input == null:
		return

	if event is InputEventMouseButton:
		if event is InputEvent:
			(event as InputEvent).set_handled()

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_input.set_brake_ui_hold(mouse.pressed)
