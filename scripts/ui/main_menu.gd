extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const REST_MODULATE := Color(0.58, 0.52, 0.44, 1.0)
const LIT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const GLOW_PAD_SCALE := 0.06
const GLOW_FADE_TIME := 0.22
const MENU_THEME_DELAY := 2.0
const MENU_THEME_FADE_TIME := 1.0

@export var play_hover_texture: Texture2D
@export var small_hover_texture: Texture2D

var vestiges: int = 0

@onready var _play_button: TextureButton = %PlayButton
@onready var _unlocks_button: TextureButton = %UnlocksButton
@onready var _quit_button: TextureButton = %QuitButton
@onready var _hover_glow: TextureRect = %HoverGlow
@onready var _vestiges_label: Label = %VestigesLabel
@onready var _menu_theme: AudioStreamPlayer = %MenuTheme

var _buttons: Array[TextureButton] = []
var _hovered_button: TextureButton
var _glow_tween: Tween
var _theme_fade_tween: Tween
var _starting_game := false


func _ready() -> void:
	_cover_window()
	get_tree().root.size_changed.connect(_cover_window)
	_buttons = [_play_button, _unlocks_button, _quit_button]
	_vestiges_label.text = str(vestiges)
	_play_button.pressed.connect(_on_play_pressed)
	_unlocks_button.pressed.connect(_on_unlocks_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for button in _buttons:
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
		button.focus_entered.connect(_on_button_focused.bind(button))
		button.focus_exited.connect(_refresh_button_modulate.bind(button))
	_hover_glow.modulate.a = 0.0
	_hover_glow.visible = false
	resized.connect(_place_glow_if_hovered)
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


func _on_quit_pressed() -> void:
	get_tree().quit()


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


func _on_button_focused(button: TextureButton) -> void:
	_refresh_button_modulate(button)


func _place_glow_if_hovered() -> void:
	if _hovered_button != null:
		_place_glow(_hovered_button)


func _refresh_button_modulate(button: TextureButton) -> void:
	var lit := button.has_focus() or button.is_hovered()
	button.modulate = LIT_MODULATE if lit else REST_MODULATE


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
