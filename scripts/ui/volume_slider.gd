class_name VolumeSlider
extends Control

const DEFAULT_VOLUME := 1.0
const SILENT_DB := -80.0
const DIMMED := Color(0.45, 0.42, 0.38, 1)

@export var bus_name := "Master"
@export var title := "MASTER VOLUME"

@onready var _title: Label = $Title
@onready var _track: TextureRect = $Track
@onready var _fill_clip: Control = $FillClip
@onready var _fill: TextureRect = $FillClip/Fill
@onready var _knob: TextureRect = $Knob
@onready var _percent: Label = $Percent
@onready var _hit: Control = $Hit

var _volume := DEFAULT_VOLUME
var _dragging := false


func set_counted(counted: bool) -> void:
	modulate = Color.WHITE if counted else DIMMED


func set_volume(value: float) -> void:
	_apply_volume(value)


func _ready() -> void:
	_title.text = title
	_hit.gui_input.connect(_on_gui_input)
	_apply_volume(DEFAULT_VOLUME)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_set_volume_from_global(event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		_set_volume_from_global(event.global_position)
		_hit.accept_event()


func _set_volume_from_global(global_position: Vector2) -> void:
	var track_rect := _track.get_global_rect()
	var value := 0.0 if track_rect.size.x <= 0.0 else (global_position.x - track_rect.position.x) / track_rect.size.x
	_apply_volume(value)


func _apply_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	var track_size := _track.size
	_fill.position = Vector2.ZERO
	_fill.size = track_size
	_fill_clip.position = _track.position
	_fill_clip.size = Vector2(track_size.x * _volume, track_size.y)
	var knob_size := _knob.size
	_knob.position = _track.position + Vector2(
		track_size.x * _volume - knob_size.x * 0.5,
		(track_size.y - knob_size.y) * 0.5
	)
	_percent.text = "%d%%" % roundi(_volume * 100.0)
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	if _volume <= 0.0:
		AudioServer.set_bus_volume_db(bus, SILENT_DB)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(_volume))
