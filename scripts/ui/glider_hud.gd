class_name GliderHUD
extends CanvasLayer

const POWER_LOW_THRESHOLD := 0.20
const BONUS_RADAR_DELAY_SEC := 2.0
const BONUS_RADAR_PING_SEC := 1.0
const BONUS_RADAR_SCAN_SEC := 3.0
const BONUS_RADAR_DOT_SEC := 0.28
const BONUS_RADAR_TYPE_CPS := 40.0
const BONUS_RADAR_HOLD_SEC := 4.0
const RADAR_IDLE := 0
const RADAR_PING := 1
const RADAR_SCAN := 2
const RADAR_TYPE := 3
const RADAR_HOLD := 4
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
const LaserTargetReticleUIScript = preload("res://scripts/ui/laser_target_reticle_ui.gd")
const DeathStatsPanelScript = preload("res://scripts/ui/death_stats_panel.gd")
const RunDamageStatsScript = preload("res://scripts/game/run_damage_stats.gd")

const LASER_HIT_HUE_COLOR := Color(0.92, 0.1, 0.06, 1.0)
const LASER_HIT_HUE_PEAK_ALPHA := 0.42
const LASER_HIT_HUE_FADE_SEC := 2.0

@onready var _power_label: Label = %PowerLabel
@onready var _power_percent_label: Label = %PowerPercent
@onready var _solar_chip: PanelContainer = %SolarChip
@onready var _power_bar: ProgressBar = %PowerBar
@onready var _battery_label: Label = %BatteryLabel
@onready var _battery_bar: ProgressBar = %BatteryBar
@onready var _stopped_overlay: PanelContainer = %StoppedOverlay
@onready var _fail_fade: ColorRect = %FailFade
@onready var _laser_hit_hue: ColorRect = %LaserHitHue
@onready var _death_stats_panel: DeathStatsPanelScript = %DeathStatsPanel
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
@onready var _bonus_objective_title: Label = %BonusObjectiveTitle
@onready var _bonus_objective_label: Label = %BonusObjectiveLabel
@onready var _stop_chip: PanelContainer = %StopChip
@onready var _stop_label: Label = %StopLabel
@onready var _sail_chip: PanelContainer = %SailChip
@onready var _sail_label: Label = %SailLabel
@onready var _day_label: Label = %DayLabel
@onready var _compass_bar: CompassBar = %CompassBar
@onready var _stopped_summary: Label = %StoppedSummary
@onready var _night_warning_panel: PanelContainer = %NightWarningPanel
@onready var _night_warning_label: Label = %NightWarningLabel
@onready var _bonus_radar_panel: PanelContainer = %BonusRadarPanel
@onready var _bonus_radar_label: Label = %BonusRadarLabel
@onready var _safe_chip: PanelContainer = %SafeChip
@onready var _safe_label: Label = %SafeLabel
@onready var _outpost_board: PanelContainer = %OutpostBoard
@onready var _outpost_board_label: Label = %OutpostBoardLabel
@onready var _rifle_debug_panel: PanelContainer = %RifleDebugPanel
@onready var _rifle_cooldown_label: Label = %RifleCooldownLabel
@onready var _rifle_projectiles_label: Label = %RifleProjectilesLabel
@onready var _rifle_damage_label: Label = %RifleDamageLabel
@onready var _rifle_projectile_speed_label: Label = %RifleProjectileSpeedLabel
@onready var _glider_speed_label: Label = %GliderSpeedLabel
@onready var _glide_label: Label = %GlideLabel
@onready var _steering_label: Label = %SteeringLabel
@onready var _hp_regen_label: Label = %HpRegenLabel
@onready var _health_label: Label = %HealthLabel
@onready var _luck_label: Label = %LuckLabel
@onready var _momentum_retention_label: Label = %MomentumRetentionLabel
@onready var _crit_label: Label = %CritLabel
@onready var _bounce_label: Label = %BounceLabel
@onready var _duration_label: Label = %DurationLabel
@onready var _pushback_label: Label = %PushbackLabel
@onready var _range_label: Label = %RangeLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _weapon_tray: HBoxContainer = %WeaponTray
@onready var _laser_target_reticle: LaserTargetReticleUIScript = %LaserTargetReticle

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
var _bonus_radar_delay := 0.0
var _bonus_radar_pending_level := 0
var _bonus_radar_pinged: Dictionary = {}
var _bonus_radar_phase := 0
var _bonus_radar_phase_t := 0.0
var _bonus_radar_typed := 0.0
var _bonus_radar_failed := false
var _bonus_radar_ping_line := ""
var _bonus_radar_report := ""
var _bonus_radar_entry: Dictionary = {}
var _bonus_objective_index := -1
var _level_progress: Node
var _safe_pulse_time := 0.0
var _fail_fade_tween: Tween
var _fail_fade_active := false
var _death_board_populated := false
var _laser_hit_hue_tween: Tween
var _fail_overlay_style: StyleBoxEmpty


func _ready() -> void:
	layer = 10
	add_to_group("glider_hud")
	_rig = get_parent() as PlayerRig
	if _rig != null:
		_player = _rig.get_node_or_null("Glider") as GliderPlayer
		_input = _rig.get_node_or_null("GliderInput") as GliderInputScript
		_camera = _rig.get_node_or_null("Glider/GliderCamera") as GliderCamera
		if _camera == null:
			_camera = _rig.get_node_or_null("Glider/Camera3D") as GliderCamera
	else:
		_player = get_parent() as GliderPlayer
		if _player != null:
			_input = _player.get_node_or_null("GliderInput") as GliderInputScript
	_run_score = get_tree().get_first_node_in_group("run_score") as RunScore
	_expedition = get_tree().get_first_node_in_group("expedition_state") as ExpeditionState
	_director = get_tree().get_first_node_in_group("eon_director") as EonDirectorScript
	_night_survival = get_tree().get_first_node_in_group("night_survival") as NightSurvival
	if _expedition != null:
		_expedition.day_started.connect(_on_day_started)
	if _director != null:
		_director.integrity_changed.connect(_on_integrity_changed)
		_director.objective_changed.connect(_on_objective_changed)
		_director.run_started.connect(_on_run_started)
		if not _director.attempt_started.is_connected(_on_attempt_started):
			_director.attempt_started.connect(_on_attempt_started)
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
	if _bonus_radar_panel != null:
		_bonus_radar_panel.visible = false
	_hide_bonus_objective()
	call_deferred("_bind_level_progress")
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
	if _laser_hit_hue != null:
		_laser_hit_hue.visible = false
		_laser_hit_hue.color = Color(LASER_HIT_HUE_COLOR.r, LASER_HIT_HUE_COLOR.g, LASER_HIT_HUE_COLOR.b, 0.0)
		_laser_hit_hue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_laser_hit_hue.z_index = 95
	call_deferred("_connect_weapon_tray")
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


func _connect_weapon_tray() -> void:
	_layout_weapon_tray_slots()
	var state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state != null and not state.weapons_changed.is_connected(_refresh_weapon_tray):
		state.weapons_changed.connect(_refresh_weapon_tray)
	_refresh_weapon_tray()


func _layout_weapon_tray_slots() -> void:
	if _weapon_tray == null:
		return
	for slot in _weapon_tray.get_children():
		var icon := slot.get_node_or_null("Frame/Icon") as TextureRect
		if icon == null:
			continue
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		icon.custom_minimum_size = Vector2.ZERO
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _refresh_weapon_tray() -> void:
	if _weapon_tray == null:
		return
	var owned := PackedStringArray()
	var state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state != null:
		owned = state.owned_weapon_ids()
	var slots := _weapon_tray.get_children()
	for i in slots.size():
		var slot := slots[i] as Control
		if slot == null:
			continue
		var icon := slot.get_node_or_null("Frame/Icon") as TextureRect
		var name_label := slot.get_node_or_null("Name") as Label
		if i >= owned.size():
			if icon != null:
				icon.texture = null
			if name_label != null:
				name_label.text = ""
			var empty_level := slot.get_node_or_null("Level") as Label
			if empty_level != null:
				empty_level.text = ""
			continue
		var family := StringName(owned[i])
		var unlock := UpgradeCatalog.unlock_id_for(family)
		var level := 1
		if state != null:
			level = maxi(state.weapon_level(family), 1)
		if icon != null:
			icon.texture = UpgradeCatalog.icon_for_weapon_level(family, level)
		if name_label != null:
			name_label.text = UpgradeCatalog.display_name(unlock)
		var level_label := slot.get_node_or_null("Level") as Label
		if level_label != null:
			level_label.text = "Level %d" % level


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
	_update_night_warning(delta)
	_update_bonus_radar(delta)
	_update_safe_chip(delta)
	_update_integrity_bar()
	_update_eon_tracker()
	_update_speedometer()
	_update_rifle_debug()

	var show_death_overlay := _is_death_overlay_active()
	if not show_death_overlay:
		_death_board_populated = false
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
	_death_board_populated = false
	_update_integrity_panel_visibility()


func _on_attempt_started() -> void:
	_clear_bonus_radar_pings()
	_bind_level_progress()
	_arm_bonus_radar_for_level(_current_level())


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
	if _rig != null:
		_rig.release_look_mouse()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start_fail_fade()
	if _stopped_overlay != null:
		_stopped_overlay.add_theme_stylebox_override("panel", _fail_overlay_style)
	var can_retry := _director != null and _director.can_try_again()
	var flavor := (
		"You have failed your mission. Fix it."
		if can_retry
		else "You have failed your mission. The eternals condemn you for all eternity."
	)
	if _death_stats_panel != null:
		_death_stats_panel.set_flavor_text(flavor)
		if not _death_board_populated:
			var terrain := get_tree().get_first_node_in_group("terrain_manager") as TerrainManager
			var upgrade_state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
			var damage_stats := get_tree().get_first_node_in_group("run_damage_stats") as RunDamageStatsScript
			_death_stats_panel.populate(_director, terrain, upgrade_state, damage_stats)
			_death_board_populated = true
	if _stopped_distance != null:
		_stopped_distance.visible = false
	if _stopped_summary != null:
		_stopped_summary.visible = false
	if _death_buttons != null:
		_death_buttons.visible = true
	if _try_again_button != null:
		_try_again_button.visible = true
		_try_again_button.disabled = not can_retry
		if can_retry and _director != null:
			var pct := int(round(_director.next_try_again_bonus() * 100.0))
			_try_again_button.text = "Try again (+%d%% difficulty)" % pct
		else:
			_try_again_button.text = "Try again"
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


func _on_level_changed(level: int) -> void:
	_arm_bonus_radar_for_level(level)


func _bind_level_progress() -> void:
	if _level_progress != null and is_instance_valid(_level_progress):
		return
	var progress := get_tree().get_first_node_in_group("level_progress")
	if progress == null or not progress.has_signal("level_changed"):
		return
	_level_progress = progress
	if not progress.level_changed.is_connected(_on_level_changed):
		progress.level_changed.connect(_on_level_changed)
	_arm_bonus_radar_for_level(_current_level())


func _current_level() -> int:
	if _level_progress != null and is_instance_valid(_level_progress) and _level_progress.has_method("get_current_level"):
		return int(_level_progress.get_current_level())
	return 0


func _clear_bonus_radar_pings() -> void:
	_bonus_radar_pinged.clear()
	_bonus_radar_pending_level = 0
	_bonus_radar_delay = 0.0
	_bonus_radar_entry = {}
	_bonus_radar_report = ""
	_bonus_radar_ping_line = ""
	_hide_bonus_objective()
	_clear_bonus_radar()


func _clear_bonus_radar() -> void:
	_bonus_radar_phase = RADAR_IDLE
	_bonus_radar_phase_t = 0.0
	_bonus_radar_typed = 0.0
	if _bonus_radar_panel != null:
		_bonus_radar_panel.visible = false


func _arm_bonus_radar_for_level(level: int) -> void:
	_bonus_radar_pending_level = 0
	_bonus_radar_delay = 0.0
	if level < BonusTowerPlanner.MIN_LEVEL:
		return
	if _bonus_radar_pinged.get(level, false):
		return
	if _bonus_radar_info_for_level(level).is_empty():
		return
	_bonus_radar_pending_level = level
	_bonus_radar_delay = BONUS_RADAR_DELAY_SEC


func _update_bonus_radar(delta: float) -> void:
	_bind_level_progress()
	_update_bonus_objective_visit()
	if _bonus_radar_delay > 0.0:
		if _current_level() != _bonus_radar_pending_level:
			_bonus_radar_pending_level = 0
			_bonus_radar_delay = 0.0
		else:
			_bonus_radar_delay = maxf(_bonus_radar_delay - delta, 0.0)
			if _bonus_radar_delay <= 0.0:
				var pending := _bonus_radar_pending_level
				_bonus_radar_pending_level = 0
				if pending == _current_level():
					_try_show_bonus_radar(pending)
	if _bonus_radar_phase == RADAR_IDLE:
		if _bonus_radar_panel != null:
			_bonus_radar_panel.visible = false
		return
	_bonus_radar_phase_t += delta
	match _bonus_radar_phase:
		RADAR_PING:
			_set_bonus_radar_text(_bonus_radar_ping_line)
			if _bonus_radar_phase_t >= BONUS_RADAR_PING_SEC:
				_begin_bonus_radar_scan()
		RADAR_SCAN:
			_set_bonus_radar_text("%s\n\n%s" % [_bonus_radar_ping_line, _scanning_line(_bonus_radar_phase_t)])
			if _bonus_radar_phase_t >= BONUS_RADAR_SCAN_SEC:
				_bonus_radar_phase = RADAR_TYPE
				_bonus_radar_phase_t = 0.0
				_bonus_radar_typed = 0.0
		RADAR_TYPE:
			_bonus_radar_typed += delta * BONUS_RADAR_TYPE_CPS
			var typed_n := mini(int(_bonus_radar_typed), _bonus_radar_report.length())
			_set_bonus_radar_text("%s\n\n%s" % [_bonus_radar_ping_line, _bonus_radar_report.substr(0, typed_n)])
			if typed_n >= _bonus_radar_report.length():
				_bonus_radar_phase = RADAR_HOLD
				_bonus_radar_phase_t = 0.0
		RADAR_HOLD:
			_set_bonus_radar_text("%s\n\n%s" % [_bonus_radar_ping_line, _bonus_radar_report])
			if _bonus_radar_phase_t >= BONUS_RADAR_HOLD_SEC:
				_finish_bonus_radar_toast()


func _begin_bonus_radar_scan() -> void:
	var world_seed := LevelRun.world_seed()
	var level := int(_bonus_radar_entry.get("level", 0))
	_bonus_radar_failed = BonusTowerPlanner.scan_failed(world_seed, level)
	_bonus_radar_report = BonusTowerPlanner.scan_report_text(world_seed, _bonus_radar_entry, _bonus_radar_failed)
	_bonus_radar_phase = RADAR_SCAN
	_bonus_radar_phase_t = 0.0


func _scanning_line(elapsed: float) -> String:
	var dots := BonusTowerPlanner.scanning_dots(int(elapsed / BONUS_RADAR_DOT_SEC))
	if dots.is_empty():
		return ""
	return "Scanning %s" % dots


func _set_bonus_radar_text(text: String) -> void:
	if _bonus_radar_label == null:
		return
	_bonus_radar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bonus_radar_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_bonus_radar_label.text = text


func _finish_bonus_radar_toast() -> void:
	_show_bonus_objective_from_scan()
	_clear_bonus_radar()


func _show_bonus_objective_from_scan() -> void:
	var north := bool(_bonus_radar_entry.get("north", true))
	var distance := BonusTowerPlanner.distance_label(int(_bonus_radar_entry.get("tier", 1)))
	var upgrades := int(_bonus_radar_entry.get("offer_count", 0))
	var text := BonusTowerPlanner.bonus_objective_text(north, distance, upgrades, _bonus_radar_failed)
	_bonus_objective_index = int(_bonus_radar_entry.get("tower_index", -1))
	if _bonus_objective_title != null:
		_bonus_objective_title.visible = true
	if _bonus_objective_label != null:
		_bonus_objective_label.text = text
		_bonus_objective_label.visible = true


func _hide_bonus_objective() -> void:
	_bonus_objective_index = -1
	if _bonus_objective_title != null:
		_bonus_objective_title.visible = false
	if _bonus_objective_label != null:
		_bonus_objective_label.visible = false
		_bonus_objective_label.text = ""


func _update_bonus_objective_visit() -> void:
	if _bonus_objective_index < 0:
		return
	var state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state == null:
		return
	if state.has_visited_this_life(_bonus_objective_index):
		_hide_bonus_objective()
		return
	var west_index := BonusTowerPlanner.source_level_for_index(_bonus_objective_index)
	if west_index >= 1 and state.has_visited_this_life(west_index):
		_hide_bonus_objective()
		return
	var current := _current_level()
	for later_west in range(west_index + 1, maxi(current, west_index) + 1):
		if state.has_visited_this_life(later_west):
			_hide_bonus_objective()
			return


func _try_show_bonus_radar(level: int) -> void:
	if level < BonusTowerPlanner.MIN_LEVEL:
		return
	if _bonus_radar_pinged.get(level, false):
		return
	if level != _current_level():
		return
	var info := _bonus_radar_info_for_level(level)
	if info.is_empty():
		return
	_bonus_radar_pinged[level] = true
	_bonus_radar_entry = info.duplicate()
	_bonus_radar_ping_line = BonusTowerPlanner.radar_text(bool(info.get("north", true)))
	_bonus_radar_report = ""
	_bonus_radar_failed = false
	_bonus_radar_phase = RADAR_PING
	_bonus_radar_phase_t = 0.0
	_bonus_radar_typed = 0.0
	_set_bonus_radar_text(_bonus_radar_ping_line)
	if _bonus_radar_panel != null:
		_bonus_radar_panel.visible = true
		_bonus_radar_panel.modulate = Color.WHITE


func _bonus_radar_info_for_level(level: int) -> Dictionary:
	var world_seed := LevelRun.world_seed()
	if world_seed < 0:
		return {}
	var entry := BonusTowerPlanner.entry_for_level(world_seed, level)
	if entry.is_empty():
		return {}
	var origin_z := 0.0
	var terrain := get_tree().get_first_node_in_group("terrain_manager") as TerrainManager
	if terrain != null:
		origin_z = terrain.run_origin.y
	for node in get_tree().get_nodes_in_group("upgrade_tower"):
		var tower := node as UpgradeTower
		if tower == null or not tower.is_bonus:
			continue
		if tower.source_level == level:
			entry["north"] = tower.global_position.z >= origin_z
			break
	return entry


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
	if _death_stats_panel != null:
		_death_stats_panel.set_flavor_text("Stopped")
		_death_stats_panel.set_sections_visible(false)
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
		var tower := node as UpgradeTower
		if tower == null or not is_instance_valid(tower) or tower.is_bonus:
			continue
		var dx := absf(tower.global_position.x - target_x)
		if dx < best_dx:
			best_dx = dx
			best = tower
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


func _update_rifle_debug() -> void:
	if _rifle_debug_panel == null:
		return
	var extras := 0
	var reduction := 0.0
	var bonus := 0.0
	var speed_bonus := 0.0
	var glider_bonus := 0.0
	var glide_bonus := 0.0
	var steering_bonus := 0.0
	var regen := 0.0
	var health_bonus := 0
	var luck := 0
	var retention := 0.0
	var crit := 0.0
	var duration := 0.0
	var pushback := 0.0
	var range_bonus := 0.0
	var bounce := 0
	var state := get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	if state != null:
		extras = state.hud_extra_projectiles()
		reduction = state.hud_attack_speed_reduction()
		bonus = state.hud_damage_bonus()
		speed_bonus = state.hud_projectile_speed_bonus()
		glider_bonus = state.glider_speed_bonus
		glide_bonus = clampf(state.glide_bonus, 0.0, UpgradeCatalog.GLIDE_CAP)
		steering_bonus = clampf(state.steering_bonus, 0.0, UpgradeCatalog.STEERING_CAP)
		regen = state.health_regen_per_sec
		health_bonus = state.max_health_bonus
		luck = state.luck_bonus
		retention = clampf(state.momentum_retention, 0.0, UpgradeCatalog.MOMENTUM_RETENTION_CAP)
		crit = clampf(state.hud_crit_chance(), 0.0, UpgradeCatalog.CRIT_CAP)
		duration = state.hud_duration_bonus()
		pushback = state.hud_pushback_bonus()
		range_bonus = state.hud_range_bonus()
		bounce = state.hud_bounce_count()
	var any := false
	any = _show_upgrade_line(
		_rifle_cooldown_label,
		"Attack Speed %d%%" % int(roundf(reduction * 100.0)),
		reduction > 0.0
	) or any
	any = _show_upgrade_line(
		_rifle_projectiles_label,
		"Projectiles %d" % AutoRifle.projectile_count_for(extras),
		extras > 0
	) or any
	any = _show_upgrade_line(
		_rifle_damage_label,
		"Damage %d%%" % int(roundf(bonus * 100.0)),
		bonus > 0.0
	) or any
	any = _show_upgrade_line(
		_rifle_projectile_speed_label,
		"Projectile Speed %d%%" % int(roundf(speed_bonus * 100.0)),
		speed_bonus > 0.0
	) or any
	any = _show_upgrade_line(
		_glider_speed_label,
		"Glider Speed %d%%" % int(roundf(glider_bonus * 100.0)),
		glider_bonus > 0.0
	) or any
	any = _show_upgrade_line(
		_glide_label,
		"Glide %d%%" % int(roundf(glide_bonus * 100.0)),
		glide_bonus > 0.0
	) or any
	any = _show_upgrade_line(
		_steering_label,
		"Steering %d%%" % int(roundf(steering_bonus * 100.0)),
		steering_bonus > 0.0
	) or any
	any = _show_upgrade_line(
		_hp_regen_label,
		"HP Regen %s" % UpgradeCatalog.hp_regen_period_text(
			regen * UpgradeCatalog.HP_REGEN_PERIOD_SEC
		),
		regen > 0.0
	) or any
	any = _show_upgrade_line(
		_health_label,
		"Health %d" % (PlayerHealth.BASE_HEALTH + health_bonus),
		health_bonus > 0
	) or any
	any = _show_upgrade_line(_luck_label, "Luck +%d" % luck, luck > 0) or any
	any = _show_upgrade_line(
		_momentum_retention_label,
		"Momentum Retention %d%%" % int(roundf(retention * 100.0)),
		retention > 0.0
	) or any
	any = _show_upgrade_line(
		_crit_label,
		"Crit %d%%" % int(roundf(crit * 100.0)),
		crit > 0.0
	) or any
	any = _show_upgrade_line(
		_bounce_label,
		"Bounce %d" % bounce,
		bounce > 0
	) or any
	any = _show_upgrade_line(
		_duration_label,
		"Duration %d%%" % int(roundf(duration * 100.0)),
		duration > 0.0
	) or any
	any = _show_upgrade_line(
		_pushback_label,
		"Pushback %d%%" % int(roundf(pushback * 100.0)),
		pushback > 0.0
	) or any
	any = _show_upgrade_line(
		_range_label,
		"Range %d%%" % int(roundf(range_bonus * 100.0)),
		range_bonus > 0.0
	) or any
	_rifle_debug_panel.visible = any
	if any:
		_rifle_debug_panel.reset_size()


func _show_upgrade_line(label: Label, text: String, active: bool) -> bool:
	if label == null:
		return false
	label.visible = active
	if active:
		label.text = text
	return active


func _on_stop_chip_gui_input(event: InputEvent) -> void:
	if _input == null or _stop_chip == null or not _stop_chip.is_inside_tree():
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_input.set_brake_ui_hold(mouse.pressed)
	_stop_chip.accept_event()


func set_laser_target_telegraph_active(active: bool) -> void:
	if _laser_target_reticle == null:
		return
	if active:
		var anchor := _player_reticle_screen_anchor()
		_laser_target_reticle.show_telegraph()
		_laser_target_reticle.update_telegraph(0.0, 0.0, anchor.screen_pos, anchor.valid)
	else:
		_laser_target_reticle.hide_telegraph()


func update_laser_target_telegraph(elapsed: float, delta: float) -> void:
	if _laser_target_reticle == null:
		return
	var anchor := _player_reticle_screen_anchor()
	_laser_target_reticle.update_telegraph(elapsed, delta, anchor.screen_pos, anchor.valid)


func play_laser_drone_hit_hue() -> void:
	if _laser_hit_hue == null:
		return
	if _laser_hit_hue_tween != null:
		_laser_hit_hue_tween.kill()
		_laser_hit_hue_tween = null
	_laser_hit_hue.visible = true
	_laser_hit_hue.color = Color(
		LASER_HIT_HUE_COLOR.r,
		LASER_HIT_HUE_COLOR.g,
		LASER_HIT_HUE_COLOR.b,
		LASER_HIT_HUE_PEAK_ALPHA
	)
	_laser_hit_hue_tween = create_tween()
	_laser_hit_hue_tween.tween_property(
		_laser_hit_hue, "color:a", 0.0, LASER_HIT_HUE_FADE_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_laser_hit_hue_tween.finished.connect(_on_laser_hit_hue_fade_finished, CONNECT_ONE_SHOT)


func _on_laser_hit_hue_fade_finished() -> void:
	_laser_hit_hue_tween = null
	if _laser_hit_hue == null:
		return
	_laser_hit_hue.visible = false
	_laser_hit_hue.color = Color(
		LASER_HIT_HUE_COLOR.r,
		LASER_HIT_HUE_COLOR.g,
		LASER_HIT_HUE_COLOR.b,
		0.0
	)


func _player_reticle_screen_anchor() -> Dictionary:
	var fallback := get_viewport().get_visible_rect().size * 0.5
	if _player == null or not is_instance_valid(_player):
		return {"screen_pos": fallback, "valid": false}
	if _camera == null and _rig != null:
		_camera = _rig.get_node_or_null("Glider/GliderCamera") as GliderCamera
		if _camera == null:
			_camera = _rig.get_node_or_null("Glider/Camera3D") as GliderCamera
	if _camera == null:
		return {"screen_pos": fallback, "valid": false}
	var world_pos := _player.global_position + Vector3(0.0, _camera.look_height, 0.0)
	if _camera.is_position_behind(world_pos):
		return {"screen_pos": fallback, "valid": false}
	return {"screen_pos": _camera.unproject_position(world_pos), "valid": true}
