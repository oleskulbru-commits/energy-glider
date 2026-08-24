class_name WeaponSelectMenu
extends CanvasLayer

## Paused start / Try Again pick: one of the available weapons.

const SELECTED_MODULATE := Color(1.0, 0.95, 0.75, 1.0)
const IDLE_MODULATE := Color(0.92, 0.88, 0.8, 1.0)
const VOICE_DELAY_SEC := 1.0

@onready var _root: Control = %Root
@onready var _rifle_button: Button = %RifleButton
@onready var _laser_button: Button = %LaserButton
@onready var _tesla_button: Button = %TeslaButton
@onready var _start_button: Button = %StartButton
@onready var _choose_voice: AudioStreamPlayer = %ChooseWeaponVoice
@onready var _eon_voice: AudioStreamPlayer = %GetTheEonVoice

var _state: RunUpgradeState
var _rig: PlayerRig
var _selected: StringName = &""
var _choose_token := 0
var _eon_token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 21
	visible = false
	_root.visible = false
	_rifle_button.pressed.connect(_on_weapon_pressed.bind(UpgradeCatalog.FAMILY_RIFLE))
	_laser_button.pressed.connect(_on_weapon_pressed.bind(UpgradeCatalog.FAMILY_LASER))
	_tesla_button.pressed.connect(_on_weapon_pressed.bind(UpgradeCatalog.FAMILY_TESLA))
	_start_button.pressed.connect(_on_start_pressed)
	_rifle_button.icon = UpgradeCatalog.icon_for(UpgradeCatalog.ID_UNLOCK_RIFLE)
	_laser_button.icon = UpgradeCatalog.icon_for(UpgradeCatalog.ID_UNLOCK_LASER)
	_tesla_button.icon = UpgradeCatalog.icon_for(UpgradeCatalog.ID_UNLOCK_TESLA)
	call_deferred("_bind_and_open")


func _bind_and_open() -> void:
	_state = get_tree().get_first_node_in_group("run_upgrade_state") as RunUpgradeState
	var health := get_tree().get_first_node_in_group("player_health") as PlayerHealth
	if health != null:
		_rig = health.get_parent() as PlayerRig
	var director := get_tree().get_first_node_in_group("eon_director") as EonDirector
	if director != null and director.has_signal("attempt_started"):
		if not director.attempt_started.is_connected(_on_attempt_started):
			director.attempt_started.connect(_on_attempt_started)
	open()


func _on_attempt_started() -> void:
	open()


func is_open() -> bool:
	return visible


func open() -> void:
	if _state != null and (_state.has_rifle or _state.has_laser or _state.has_tesla):
		return
	var already_open := visible
	_selected = &""
	_refresh()
	visible = true
	_root.visible = true
	get_tree().paused = true
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_disable_input = false
	if _rig != null:
		_rig.release_look_mouse()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cancel_eon_voice()
	if not already_open:
		_schedule_choose_voice()


func _process(_delta: float) -> void:
	if not visible:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _refresh() -> void:
	_rifle_button.modulate = SELECTED_MODULATE if _selected == UpgradeCatalog.FAMILY_RIFLE else IDLE_MODULATE
	_laser_button.modulate = SELECTED_MODULATE if _selected == UpgradeCatalog.FAMILY_LASER else IDLE_MODULATE
	_tesla_button.modulate = SELECTED_MODULATE if _selected == UpgradeCatalog.FAMILY_TESLA else IDLE_MODULATE
	_start_button.disabled = _selected == &""


func _on_weapon_pressed(family: StringName) -> void:
	_selected = family
	_refresh()


func _on_start_pressed() -> void:
	if _selected == &"":
		return
	if _state != null:
		_state.grant_starter(_selected)
	_close()


func _close() -> void:
	_cancel_choose_voice()
	visible = false
	_root.visible = false
	get_tree().paused = false
	if _rig != null:
		_rig.capture_look_mouse()
	_schedule_eon_voice()


func _schedule_choose_voice() -> void:
	_choose_token += 1
	var token := _choose_token
	_play_choose_later(token)


func _cancel_choose_voice() -> void:
	_choose_token += 1
	if _choose_voice != null and _choose_voice.playing:
		_choose_voice.stop()


func _play_choose_later(token: int) -> void:
	await get_tree().create_timer(VOICE_DELAY_SEC, true).timeout
	if token != _choose_token or not visible:
		return
	if _choose_voice == null:
		return
	_choose_voice.play()


func _schedule_eon_voice() -> void:
	_eon_token += 1
	var token := _eon_token
	_play_eon_later(token)


func _cancel_eon_voice() -> void:
	_eon_token += 1
	if _eon_voice != null and _eon_voice.playing:
		_eon_voice.stop()


func _play_eon_later(token: int) -> void:
	await get_tree().create_timer(VOICE_DELAY_SEC, true).timeout
	if token != _eon_token or visible:
		return
	if _eon_voice == null:
		return
	_eon_voice.play()
