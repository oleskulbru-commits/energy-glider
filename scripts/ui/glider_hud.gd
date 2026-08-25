class_name GliderHUD
extends CanvasLayer

const POWER_LOW_THRESHOLD := 0.20
const POWER_COLOR_NORMAL := Color(0.35, 0.88, 0.95)
const POWER_COLOR_LOW := Color(0.98, 0.78, 0.18)
const POWER_COLOR_EMPTY := Color(0.85, 0.28, 0.22)
const POWER_COLOR_SOLAR := Color(0.98, 0.82, 0.28)
const POWER_COLOR_OVERHEAT := Color(0.98, 0.45, 0.18)
const BATTERY_COLOR_NORMAL := Color(0.95, 0.72, 0.28)
const BATTERY_COLOR_LOW := Color(0.98, 0.78, 0.18)
const BATTERY_COLOR_EMPTY := Color(0.85, 0.28, 0.22)

const GliderInputScript = preload("res://scripts/input/glider_input.gd")
const EonDirectorScript = preload("res://scripts/game/eon_director.gd")

@onready var _power_label: Label = %PowerLabel
@onready var _power_percent_label: Label = %PowerPercent
@onready var _solar_chip: PanelContainer = %SolarChip
@onready var _power_bar: ProgressBar = %PowerBar
@onready var _battery_label: Label = %BatteryLabel
@onready var _battery_bar: ProgressBar = %BatteryBar
@onready var _stopped_overlay: PanelContainer = %StoppedOverlay
@onready var _fail_fade: ColorRect = %FailFade
@onready var _stopped_title: Label = %StoppedTitle
@onready var _stopped_distance: Label = %StoppedDistance
@onready var _death_buttons: HBoxContainer = %DeathButtons
@onready var _try_again_button: Button = %TryAgainButton
@onready var _restart_button: Button = %RestartButton
@onready var _integrity_panel: PanelContainer = %IntegrityPanel
@onready var _integrity_bar: ProgressBar = %IntegrityBar
@onready var _integrity_label: Label = %IntegrityLabel
@onready var _kill_test_button: Button = %KillTestButton
@onready var _eon_tracker: PanelContainer = %EonTracker
@onready var _eon_tracker_label: Label = %EonTrackerLabel
@onready var _objective_panel: PanelContainer = %ObjectivePanel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _stop_chip: PanelContainer = %StopChip
@onready var _stop_label: Label = %StopLabel
@onready var _sail_chip: PanelContainer = %SailChip
@onready var _sail_label: Label = %SailLabel
@onready var _day_label: Label = %DayLabel
@onready var _compass_bar: CompassBar = %CompassBar
@onready var _stopped_summary: Label = %StoppedSummary
@onready var _day_summary_panel: PanelContainer = %DaySummaryPanel
@onready var _day_summary_label: Label = %DaySummaryLabel
@onready var _night_warning_panel: PanelContainer = %NightWarningPanel
@onready var _night_warning_label: Label = %NightWarningLabel
@onready var _safe_chip: PanelContainer = %SafeChip
@onready var _safe_label: Label = %SafeLabel
@onready var _outpost_board: PanelContainer = %OutpostBoard
@onready var _outpost_board_label: Label = %OutpostBoardLabel
@onready var _speed_label: Label = %SpeedLabel

var _rig: PlayerRig
var _player: GliderPlayer
var _camera: GliderCamera
var _input: GliderInputScript
var _run_score: RunScore
var _expedition: ExpeditionState
var _director: EonDirectorScript
var _night_survival: NightSurvival
var _day_night: DayNightCycle
var _power_fill: StyleBoxFlat
var _battery_fill: StyleBoxFlat
var _solar_pulse_time := 0.0
var _day_summary_timer := 0.0
var _night_warning_timer := 0.0
var _safe_pulse_time := 0.0
var _fail_fade_tween: Tween
var _fail_fade_active := false
var _fail_overlay_style: StyleBoxEmpty


func _ready() -> void:
	layer = 10
	_rig = get_parent() as PlayerRig
	if _rig != null:
		_player = _rig.get_node_or_null("Glider") as GliderPlayer
		_input = _rig.get_node_or_null("GliderInput") as GliderInputScript
		_camera = _rig.get_node_or_null("Glider/GliderCamera") as GliderCamera
		if _camera == null:
			_camera = _rig.get_node_or_null("Glider/Camera3D") as GliderCamera
	else:
		_player = get_parent() as GliderPlayer
		_input = _player.get_node_or_null("GliderInput") as GliderInputScript
	_run_score = get_tree().get_first_node_in_group("run_score") as RunScore
	_expedition = get_tree().get_first_node_in_group("expedition_state") as ExpeditionState
	_director = get_tree().get_first_node_in_group("eon_director") as EonDirectorScript
	_night_survival = get_tree().get_first_node_in_group("night_survival") as NightSurvival
	if _expedition != null:
		_expedition.day_started.connect(_on_day_started)
		_expedition.day_ended.connect(_on_day_ended)
	if _director != null:
		_director.integrity_changed.connect(_on_integrity_changed)
		_director.objective_changed.connect(_on_objective_changed)
		_director.run_started.connect(_on_run_started)
		_on_integrity_changed(_director.integrity)
		_on_objective_changed(_director.get_objective_text())
		_update_integrity_panel_visibility()
	if _night_survival != null:
		_night_survival.night_warning.connect(_on_night_warning)
		_night_survival.safe_changed.connect(_on_night_safe_changed)
		_on_night_safe_changed(_night_survival.is_safe())
	_day_night = get_tree().get_first_node_in_group("day_night_cycle") as DayNightCycle
	if _day_night != null:
		_day_night.dawn.connect(_clear_night_warning)
	if _night_warning_panel != null:
		_night_warning_panel.visible = false
	if _safe_chip != null:
		_safe_chip.visible = false
	if _try_again_button != null:
		_try_again_button.pressed.connect(_on_try_again_pressed)
	if _restart_button != null:
		_restart_button.pressed.connect(_on_restart_pressed)
		_restart_button.text = "New game"
	if _kill_test_button != null:
		_kill_test_button.pressed.connect(_on_kill_test_pressed)
	if _day_label != null:
		_day_label.visible = false
	if _death_buttons != null:
		_death_buttons.visible = false
	if _integrity_panel != null:
		_integrity_panel.visible = false
	if _fail_fade != null:
		_fail_fade.visible = false
		_fail_fade.color = Color(0, 0, 0, 0)
		_fail_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fail_fade.z_index = 100
	if _stopped_overlay != null:
		_stopped_overlay.z_index = 101
	_fail_overlay_style = StyleBoxEmpty.new()
	_power_fill = _power_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_power_bar.add_theme_stylebox_override("fill", _power_fill)
	if _battery_bar != null:
		_battery_fill = _battery_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		_battery_bar.add_theme_stylebox_override("fill", _battery_fill)
		if _battery_fill != null:
			_battery_fill.bg_color = BATTERY_COLOR_EMPTY
	_stop_chip.gui_input.connect(_on_stop_chip_gui_input)
	if _sail_chip != null:
		_sail_chip.visible = false
	_lock_eon_tracker_layout()
func _lock_eon_tracker_layout() -> void:
	if _eon_tracker == null:
		return
	# Bottom-center; fixed offsets so soft retry
	# and overlay visibility cannot shove this into the compass.
	_eon_tracker.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_eon_tracker.anchor_left = 0.5
	_eon_tracker.anchor_right = 0.5
	_eon_tracker.anchor_top = 1.0
	_eon_tracker.anchor_bottom = 1.0
	_eon_tracker.offset_left = -100.0
	_eon_tracker.offset_right = 100.0
	_eon_tracker.offset_top = -64.0
	_eon_tracker.offset_bottom = -28.0
	_eon_tracker.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_eon_tracker.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_eon_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _player == null and _rig != null:
		_player = _rig.get_node_or_null("Glider") as GliderPlayer
	if _input == null and _rig != null:
		_input = _rig.get_node_or_null("GliderInput") as GliderInputScript
	if _player == null:
		return

	_update_power_meter(delta)
	_update_landing_feedback()
	_update_stop_chip()
	_update_compass()
	_update_outpost_board()
	_update_day_summary(delta)
	_update_night_warning(delta)
	_update_safe_chip(delta)
	_update_integrity_bar()
	_update_eon_tracker()
	_update_speedometer()

	var show_death_overlay := _is_death_overlay_active()
	if show_death_overlay:
		_stopped_overlay.visible = true
		_update_death_overlay()
	elif _player.is_run_ended() and _player.get_end_reason() != "death":
		_hide_fail_fade()
		_stopped_overlay.visible = true
		_update_stopped_overlay()
	elif _player.is_run_ended() and _player.get_end_reason() == "death":
		if _director != null and _director.death_fade_active:
			_start_fail_fade()
		else:
			_hide_fail_fade()
		_stopped_overlay.visible = false
	else:
		_hide_fail_fade()
		_stopped_overlay.visible = false


func _is_death_overlay_active() -> bool:
	return (
		_player.is_run_ended()
		and _player.get_end_reason() == "death"
		and _director != null
		and _director.awaiting_death_choice
	)


func _on_integrity_changed(value: int) -> void:
	_update_integrity_bar(value)
	_update_integrity_panel_visibility()


func _on_run_started() -> void:
	_update_integrity_panel_visibility()


func _on_objective_changed(text: String) -> void:
	if _objective_label != null:
		_objective_label.text = text
	if _objective_panel != null:
		_objective_panel.visible = true
	_update_integrity_panel_visibility()


func _update_integrity_panel_visibility() -> void:
	if _integrity_panel == null:
		return
	_integrity_panel.visible = _director != null and _director.has_collected_eon()


func _update_integrity_bar(value: int = -1) -> void:
	if _integrity_bar == null:
		return
	if value < 0 and _director != null:
		value = _director.integrity
	if value < 0:
		value = 100
	_integrity_bar.value = float(value)
	if _integrity_label != null:
		_integrity_label.text = "E.O.N Integrity  %d%%" % value
	_update_integrity_panel_visibility()


func _update_eon_tracker() -> void:
	if _eon_tracker == null or _eon_tracker_label == null or _director == null:
		return
	var track_pos := _tracking_position()
	var should_show_tracker := _director.should_show_eon_tracker(track_pos)
	if should_show_tracker and not _eon_tracker.visible:
		_lock_eon_tracker_layout()
	_eon_tracker.visible = should_show_tracker
	if not should_show_tracker:
		if _compass_bar != null:
			_compass_bar.set_eon_bearing(NAN)
		return
	var eon_dist := _director.get_eon_distance(track_pos)
	_eon_tracker_label.text = "E.O.N  %s" % MathUtil.format_distance_m(eon_dist)


func _update_death_overlay() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start_fail_fade()
	if _stopped_overlay != null:
		_stopped_overlay.add_theme_stylebox_override("panel", _fail_overlay_style)
	var can_retry := _director != null and _director.can_try_again()
	if _stopped_title != null:
		if can_retry:
			_stopped_title.text = "You have failed your mission. Fix it."
		else:
			_stopped_title.text = (
				"You have failed your mission. The eternals condemn you for all eternity."
			)
	if _stopped_distance != null:
		_stopped_distance.visible = false
	if _stopped_summary != null:
		_stopped_summary.visible = false
	if _death_buttons != null:
		_death_buttons.visible = true
	if _try_again_button != null:
		_try_again_button.visible = true
		_try_again_button.disabled = not can_retry
		_try_again_button.modulate = (
			Color(1, 1, 1, 1) if can_retry else Color(0.55, 0.55, 0.55, 0.85)
		)
	if _restart_button != null:
		_restart_button.text = "New game"
		_restart_button.disabled = false
		_restart_button.modulate = Color(1, 1, 1, 1)


func _start_fail_fade() -> void:
	if _fail_fade == null or _fail_fade_active:
		return
	_fail_fade_active = true
	_fail_fade.visible = true
	_fail_fade.color = Color(0, 0, 0, 0)
	if _fail_fade_tween != null:
		_fail_fade_tween.kill()
	_fail_fade_tween = create_tween()
	_fail_fade_tween.tween_property(_fail_fade, "color:a", 1.0, 0.5)


func _hide_fail_fade() -> void:
	_fail_fade_active = false
	if _fail_fade_tween != null:
		_fail_fade_tween.kill()
		_fail_fade_tween = null
	if _fail_fade != null:
		_fail_fade.visible = false
		_fail_fade.color = Color(0, 0, 0, 0)


func _on_try_again_pressed() -> void:
	# Clear the black fail fade before resetting lighting so dawn isn't
	# revealed from under a night-tinted death screen.
	_hide_fail_fade()
	if _stopped_overlay != null:
		_stopped_overlay.visible = false
	if _director != null:
		_director.request_try_again()


func _on_restart_pressed() -> void:
	if _director != null:
		_director.request_restart()


func _on_kill_test_pressed() -> void:
	if _director != null:
		_director.kill_player_for_debug()
	elif _player != null and not _player.is_run_ended():
		_player.end_run("death")


func _update_power_meter(delta: float) -> void:
	var power_ratio := _player.get_charge_ratio()
	var overheat_ratio := _player.get_overheat_cooldown_ratio()
	var cooling_progress := 1.0 - overheat_ratio

	_power_bar.value = power_ratio * 100.0
	_power_percent_label.text = "%d%%" % int(roundf(power_ratio * 100.0))

	if _player.is_run_ended():
		_power_label.text = "STOPPED"
	elif _player.is_overheated():
		_power_label.text = "COOLING"
	else:
		_power_label.text = "Thruster Charge"

	var solar_active := _player.is_solar_charging()
	_solar_chip.visible = solar_active
	_update_battery_meter()

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


func _update_battery_meter() -> void:
	if _battery_bar == null:
		return
	var battery_ratio := _player.get_battery_ratio()
	_battery_bar.value = battery_ratio * 100.0
	if _battery_label != null:
		_battery_label.text = "Battery"
	if _battery_fill == null:
		return
	if _player.is_run_ended() or battery_ratio <= 0.0:
		_battery_fill.bg_color = BATTERY_COLOR_EMPTY
	elif battery_ratio < POWER_LOW_THRESHOLD:
		_battery_fill.bg_color = BATTERY_COLOR_LOW
	else:
		_battery_fill.bg_color = BATTERY_COLOR_NORMAL


func _on_day_started(day: int) -> void:
	if _day_label != null:
		_day_label.text = "DAY %d" % day
		_day_label.visible = true


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


func _on_night_warning() -> void:
	if _night_warning_panel == null:
		return
	if _night_warning_label != null:
		_night_warning_label.text = NightSurvival.NIGHT_WARNING_TEXT
	_night_warning_panel.visible = true
	_night_warning_timer = 3.0


func _clear_night_warning() -> void:
	_night_warning_timer = 0.0
	if _night_warning_panel != null:
		_night_warning_panel.visible = false


func _update_night_warning(delta: float) -> void:
	if _night_warning_timer <= 0.0:
		if _night_warning_panel != null:
			_night_warning_panel.visible = false
		return
	_night_warning_timer = maxf(_night_warning_timer - delta, 0.0)
	if _night_warning_timer <= 0.0:
		_clear_night_warning()


func _on_night_safe_changed(is_safe: bool) -> void:
	if _safe_chip == null:
		return
	_safe_chip.visible = is_safe
	if is_safe:
		_safe_pulse_time = 0.0


func _update_safe_chip(delta: float) -> void:
	if _safe_chip == null or not _safe_chip.visible:
		return
	_safe_pulse_time += delta
	var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(_safe_pulse_time * 2.4))
	_safe_chip.modulate = Color(1.0, 1.0, 1.0, pulse)
	if _safe_label != null:
		_safe_label.modulate = Color(0.45, 0.92, 0.55, pulse)


func _update_stopped_overlay() -> void:
	if _stopped_overlay != null:
		_stopped_overlay.remove_theme_stylebox_override("panel")
	if _stopped_title != null:
		_stopped_title.text = "Stopped"
	if _death_buttons != null:
		_death_buttons.visible = false
	if _stopped_distance != null:
		_stopped_distance.visible = true
		if _run_score != null:
			_stopped_distance.text = _run_score.format_distance()
	if _stopped_summary != null:
		_stopped_summary.visible = true
		if _expedition != null:
			_stopped_summary.text = "Score %d" % _expedition.total_score


func _update_compass() -> void:
	if _compass_bar == null:
		return
	if _camera == null and _rig != null:
		_camera = _rig.get_node_or_null("Glider/GliderCamera") as GliderCamera
		if _camera == null:
			_camera = _rig.get_node_or_null("Glider/Camera3D") as GliderCamera
	if _camera == null:
		return

	var yaw := _camera.get_follow_yaw()
	_compass_bar.set_yaw(yaw)

	var track_pos := _tracking_position()

	_compass_bar.set_poi_bearing(NAN)
	_compass_bar.set_outpost_bearings(_resolve_outpost_bearings(track_pos))

	if _director != null and _director.should_show_eon_tracker(track_pos):
		_compass_bar.set_eon_bearing(_director.get_eon_bearing(track_pos))
	else:
		_compass_bar.set_eon_bearing(NAN)


func _tracking_position() -> Vector3:
	if _rig != null:
		return _rig.get_tracking_position()
	return _player.global_position


## Only the next objective tower, and only after the E.O.N. run has started.
func _resolve_outpost_bearings(track_pos: Vector3) -> Array:
	if _director == null or not _director.is_run_active():
		return []
	var tower := _find_next_objective_tower()
	if tower == null:
		return []
	var dist := MathUtil.horizontal_distance(track_pos, tower.global_position)
	if dist < 40.0:
		return []
	return [MathUtil.bearing_to(track_pos, tower.global_position)]


func _find_next_objective_tower() -> Node3D:
	if _director == null:
		return null
	var tower_n := int(_director.next_upgrade_tower_label)
	var offsets: Array[float] = LevelLayout.tower_x_offsets_from_origin()
	if tower_n < 1 or tower_n > offsets.size():
		return null
	var origin_x := _run_origin_x()
	var target_x := origin_x + offsets[tower_n - 1]
	var best: Node3D = null
	var best_dx := INF
	for node in get_tree().get_nodes_in_group("upgrade_tower"):
		var spatial := node as Node3D
		if spatial == null or not is_instance_valid(spatial):
			continue
		var dx := absf(spatial.global_position.x - target_x)
		if dx < best_dx:
			best_dx = dx
			best = spatial
	# Towers are pinned to planned X; allow small float / snap slack.
	if best == null or best_dx > 50.0:
		return null
	return best


func _run_origin_x() -> float:
	var terrain := get_tree().get_first_node_in_group("terrain_manager") as TerrainManager
	if terrain == null:
		terrain = get_tree().root.find_child("TerrainManager", true, false) as TerrainManager
	if terrain != null:
		return terrain.run_origin.x
	return 0.0


func _update_outpost_board() -> void:
	if _outpost_board == null or _outpost_board_label == null or _player == null:
		return
	var track_pos := _tracking_position()

	var ranked := WorldQueries.ranked_in_group(get_tree(), "upgrade_tower", track_pos)
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
		"upgrade_tower",
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


func _update_landing_feedback() -> void:
	if _sail_chip == null or _sail_label == null or _player == null:
		return

	var feedback: Dictionary = _player.get_landing_feedback()
	if feedback.get("timer", 0.0) <= 0.01:
		_sail_chip.visible = false
		return

	# SailChip nodes host landing feedback (e.g. HEAVY on steep falls) in the HUD scene.
	_sail_chip.visible = true
	_sail_label.text = feedback.get("label", "")
	_sail_label.remove_theme_color_override("font_color")


func _update_stop_chip() -> void:
	if _player == null or _stop_chip == null:
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


func _update_speedometer() -> void:
	if _speed_label == null or _player == null:
		return
	var speed := MathUtil.horizontal_speed(_player.velocity)
	_speed_label.text = "%d m/s" % int(roundf(speed))


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
