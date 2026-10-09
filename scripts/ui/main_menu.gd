extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const VestigeBankScript := preload("res://scripts/game/vestige_bank.gd")
const GameSettingsScript := preload("res://scripts/game/game_settings.gd")
const GLOW_PAD_SCALE := 0.06
const GLOW_FADE_TIME := 0.22
const MENU_THEME_DELAY := 2.0
const MENU_THEME_FADE_TIME := 1.0

@export var play_hover_texture: Texture2D
@export var small_hover_texture: Texture2D

var vestiges: int = 0

@onready var _buttons_box: VBoxContainer = %Buttons
@onready var _play_button: TextureButton = %PlayButton
@onready var _unlocks_button: TextureButton = %UnlocksButton
@onready var _options_button: TextureButton = %OptionsButton
@onready var _quit_button: TextureButton = %QuitButton
@onready var _hover_glow: TextureRect = %HoverGlow
@onready var _vestiges: HBoxContainer = %Vestiges
@onready var _vestiges_label: Label = %VestigesLabel
@onready var _options_menu: Control = %OptionsMenu
@onready var _audio_menu: Control = %AudioMenu
@onready var _gameplay_button: TextureButton = %GameplayButton
@onready var _controls_button: TextureButton = %ControlsButton
@onready var _audio_button: TextureButton = %AudioButton
@onready var _graphics_button: TextureButton = %GraphicsButton
@onready var _accessibility_button: TextureButton = %AccessibilityButton
@onready var _back_button: TextureButton = %BackButton
@onready var _menu_theme: AudioStreamPlayer = %MenuTheme
@onready var _mute_all: TextureButton = %MuteAllToggle
@onready var _audio_back_button: TextureButton = %AudioBackButton
@onready var _restore_defaults_button: TextureButton = %RestoreDefaultsButton
@onready var _master_volume: VolumeSlider = %MasterVolume
@onready var _music_volume: VolumeSlider = %MusicVolume
@onready var _sfx_volume: VolumeSlider = %SfxVolume
@onready var _ui_volume: VolumeSlider = %UiVolume

var _buttons: Array[TextureButton] = []
var _hovered_button: TextureButton
var _glow_tween: Tween
var _theme_fade_tween: Tween
var _starting_game := false
var _options_open := false
var _audio_open := false


func _ready() -> void:
	GameSettingsScript.apply()
	_cover_window()
	get_tree().root.size_changed.connect(_cover_window)
	_buttons = [
		_play_button,
		_unlocks_button,
		_options_button,
		_quit_button,
		_gameplay_button,
		_controls_button,
		_audio_button,
		_graphics_button,
		_accessibility_button,
		_back_button,
		_audio_back_button,
		_restore_defaults_button,
	]
	vestiges = VestigeBankScript.get_total()
	_vestiges_label.text = str(vestiges)
	_play_button.pressed.connect(_on_play_pressed)
	_unlocks_button.pressed.connect(_on_unlocks_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_audio_button.pressed.connect(_open_audio)
	_back_button.pressed.connect(_close_options)
	_audio_back_button.pressed.connect(_close_audio)
	_restore_defaults_button.pressed.connect(_on_restore_defaults_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for button in _buttons:
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
	_hover_glow.modulate.a = 0.0
	_hover_glow.visible = false
	resized.connect(_place_glow_if_hovered)
	_sync_mute_all_from_bus()
	_mute_all.toggled.connect(_on_mute_all_toggled)
	_play_menu_theme()
	call_deferred("_focus_play")


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.root.size_changed.is_connected(_cover_window):
		tree.root.size_changed.disconnect(_cover_window)
	var window := get_window()
	if window != null:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _cover_window() -> void:
	var window := get_window()
	if window == null:
		return
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _on_play_pressed() -> void:
	if _starting_game:
		return
	_starting_game = true
	_play_button.disabled = true
	if _theme_fade_tween != null and _theme_fade_tween.is_valid():
		_theme_fade_tween.kill()
	var from_volume := db_to_linear(_menu_theme.volume_db)
	if not _menu_theme.playing or from_volume <= 0.001:
		_start_game()
		return
	_theme_fade_tween = create_tween()
	_theme_fade_tween.tween_method(_set_theme_linear_volume, from_volume, 0.0, MENU_THEME_FADE_TIME)
	_theme_fade_tween.tween_callback(_start_game)


func _set_theme_linear_volume(linear: float) -> void:
	_menu_theme.volume_db = linear_to_db(maxf(linear, 0.0001))


func _start_game() -> void:
	_menu_theme.stop()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_unlocks_pressed() -> void:
	pass


func _on_options_pressed() -> void:
	_open_options()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _audio_open:
		_close_audio()
		get_viewport().set_input_as_handled()
		return
	if not _options_open:
		return
	_close_options()
	get_viewport().set_input_as_handled()


func _open_options() -> void:
	if _options_open or _starting_game:
		return
	_options_open = true
	_hovered_button = null
	_fade_glow(0.0)
	_buttons_box.visible = false
	_options_menu.visible = true
	_gameplay_button.grab_focus()


func _open_audio() -> void:
	if not _options_open or _audio_open:
		return
	_audio_open = true
	_hovered_button = null
	_fade_glow(0.0)
	_options_menu.visible = false
	_audio_menu.visible = true
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()


func _close_audio() -> void:
	if not _audio_open:
		return
	_audio_open = false
	_hovered_button = null
	_fade_glow(0.0)
	_audio_menu.visible = false
	_options_menu.visible = true
	_audio_button.grab_focus()


func _close_options() -> void:
	if not _options_open:
		return
	_audio_open = false
	_audio_menu.visible = false
	_options_open = false
	_hovered_button = null
	_fade_glow(0.0)
	_options_menu.visible = false
	_buttons_box.visible = true
	_options_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _sync_mute_all_from_bus() -> void:
	var muted := GameSettingsScript.is_muted()
	_mute_all.set_pressed_no_signal(muted)
	for row: VolumeSlider in [_master_volume, _music_volume, _sfx_volume, _ui_volume]:
		row.set_counted(not muted)


func _on_mute_all_toggled(muted: bool) -> void:
	GameSettingsScript.set_muted(muted)
	for row: VolumeSlider in [_master_volume, _music_volume, _sfx_volume, _ui_volume]:
		row.set_counted(not muted)


func _on_restore_defaults_pressed() -> void:
	GameSettingsScript.restore_audio_defaults()
	for row: VolumeSlider in [_master_volume, _music_volume, _sfx_volume, _ui_volume]:
		row.set_volume(GameSettingsScript.DEFAULT_VOLUME)
	_sync_mute_all_from_bus()


func _play_menu_theme() -> void:
	var theme := _menu_theme.stream as AudioStreamMP3
	if theme != null:
		theme.loop = true
	_set_theme_linear_volume(0.0)
	_theme_fade_tween = create_tween()
	_theme_fade_tween.tween_interval(MENU_THEME_DELAY)
	_theme_fade_tween.tween_callback(_begin_menu_theme)
	_theme_fade_tween.tween_method(_set_theme_linear_volume, 0.0, 1.0, MENU_THEME_FADE_TIME)


func _begin_menu_theme() -> void:
	if _starting_game or _menu_theme.playing:
		return
	_menu_theme.play()


func _focus_play() -> void:
	_play_button.grab_focus()


func _on_button_mouse_entered(button: TextureButton) -> void:
	_hovered_button = button
	button.grab_focus()
	_place_glow(button)
	_fade_glow(1.0)


func _on_button_mouse_exited(button: TextureButton) -> void:
	if _hovered_button != button:
		return
	_hovered_button = null
	call_deferred("_fade_out_if_idle")


func _fade_out_if_idle() -> void:
	if _hovered_button != null:
		return
	_fade_glow(0.0)


func _place_glow_if_hovered() -> void:
	if _hovered_button != null:
		_place_glow(_hovered_button)


func _place_glow(button: TextureButton) -> void:
	var texture := small_hover_texture if button != _play_button else play_hover_texture
	if texture != null:
		_hover_glow.texture = texture
	var rect := button.get_global_rect()
	var pad := rect.size * GLOW_PAD_SCALE
	_hover_glow.global_position = rect.position - pad
	_hover_glow.size = rect.size + pad * 2.0


func _fade_glow(target_alpha: float) -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	var current := _hover_glow.modulate.a
	if is_equal_approx(current, target_alpha):
		_hover_glow.visible = target_alpha > 0.0
		return
	_hover_glow.visible = true
	var duration := GLOW_FADE_TIME * absf(target_alpha - current)
	_glow_tween = create_tween()
	_glow_tween.tween_property(_hover_glow, "modulate:a", target_alpha, duration)
	if target_alpha <= 0.0:
		_glow_tween.tween_callback(_hide_glow_if_clear)


func _hide_glow_if_clear() -> void:
	if _hover_glow.modulate.a <= 0.001 and _hovered_button == null:
		_hover_glow.visible = false
