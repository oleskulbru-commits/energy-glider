class_name LaserTargetReticleUI
extends Control

## Screen-centered bracket reticle: four red bars closing on the crosshair.

const TelegraphScript = preload("res://scripts/enemies/laser_drone_telegraph.gd")

const BAR_COLOR := Color(0.98, 0.14, 0.08, 0.96)
const BAR_LENGTH_PX := 42.0
const BAR_THICKNESS_PX := 4.5
const BASE_HALF_SPREAD_PX := 72.0

var _display_scale := TelegraphScript.START_SCALE
var _draw_visible := false
var _screen_center := Vector2.ZERO
var _anchor_valid := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_telegraph() -> void:
	_display_scale = TelegraphScript.START_SCALE
	_draw_visible = true
	_anchor_valid = false
	visible = true
	queue_redraw()


func hide_telegraph() -> void:
	_draw_visible = false
	_anchor_valid = false
	visible = false
	queue_redraw()


func update_telegraph(elapsed: float, _delta: float, screen_center: Vector2, anchor_valid: bool = true) -> void:
	if not _draw_visible:
		return
	_screen_center = screen_center
	_anchor_valid = anchor_valid
	_display_scale = TelegraphScript.scale_at(elapsed)
	visible = anchor_valid and TelegraphScript.blink_visible(elapsed)
	queue_redraw()


static func bracket_half_spread(scale: float) -> float:
	return BASE_HALF_SPREAD_PX * scale


func _draw() -> void:
	if not _draw_visible or not visible or not _anchor_valid:
		return
	var center := _screen_center
	var half_spread := bracket_half_spread(_display_scale)
	var bar_len := BAR_LENGTH_PX
	var thick := BAR_THICKNESS_PX
	var half_thick := thick * 0.5

	draw_rect(
		Rect2(center.x - half_thick, center.y - half_spread - bar_len, thick, bar_len),
		BAR_COLOR,
		true
	)
	draw_rect(
		Rect2(center.x - half_thick, center.y + half_spread, thick, bar_len),
		BAR_COLOR,
		true
	)
	draw_rect(
		Rect2(center.x - half_spread - bar_len, center.y - half_thick, bar_len, thick),
		BAR_COLOR,
		true
	)
	draw_rect(
		Rect2(center.x + half_spread, center.y - half_thick, bar_len, thick),
		BAR_COLOR,
		true
	)
