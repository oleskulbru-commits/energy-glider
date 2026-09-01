class_name LaserTargetReticleUI
extends Control

## Screen-centered bracket reticle with a 2 s clockwise ring trace before the blast.

const TelegraphScript = preload("res://scripts/enemies/laser_drone_telegraph.gd")

const BAR_COLOR := Color(0.98, 0.14, 0.08, 0.96)
const RING_COLOR := Color(1.0, 0.22, 0.1, 0.98)
const RING_WIDTH_PX := 3.5
const RING_LEAD_RADIUS_PX := 4.0
const BAR_LENGTH_PX := 42.0
const BAR_THICKNESS_PX := 4.5
const BASE_HALF_SPREAD_PX := 72.0
const RING_START_ANGLE := -PI * 0.5

var _display_scale := TelegraphScript.START_SCALE
var _circle_trace := 0.0
var _brackets_visible := true
var _draw_visible := false
var _screen_center := Vector2.ZERO
var _anchor_valid := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_telegraph() -> void:
	_display_scale = TelegraphScript.START_SCALE
	_circle_trace = 0.0
	_draw_visible = true
	_anchor_valid = false
	visible = true
	queue_redraw()


func hide_telegraph() -> void:
	_draw_visible = false
	_anchor_valid = false
	_circle_trace = 0.0
	visible = false
	queue_redraw()


func update_telegraph(elapsed: float, _delta: float, screen_center: Vector2, anchor_valid: bool = true) -> void:
	if not _draw_visible:
		return
	_screen_center = screen_center
	_anchor_valid = anchor_valid
	_display_scale = TelegraphScript.scale_at(elapsed)
	_circle_trace = TelegraphScript.circle_trace_progress(elapsed)
	_brackets_visible = TelegraphScript.brackets_visible(elapsed)
	visible = anchor_valid
	queue_redraw()


static func bracket_half_spread(scale: float) -> float:
	return BASE_HALF_SPREAD_PX * scale


static func outer_ring_radius(scale: float) -> float:
	return bracket_half_spread(scale) + BAR_LENGTH_PX


func _draw() -> void:
	if not _draw_visible or not visible or not _anchor_valid:
		return
	var center := _screen_center
	var half_spread := bracket_half_spread(_display_scale)
	var bar_len := BAR_LENGTH_PX
	var thick := BAR_THICKNESS_PX
	var half_thick := thick * 0.5

	if _brackets_visible:
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

	if _circle_trace <= 0.0:
		return
	_draw_circle_trace(center, outer_ring_radius(_display_scale), _circle_trace)


func _draw_circle_trace(center: Vector2, radius: float, progress: float) -> void:
	if radius <= 0.0 or progress <= 0.0:
		return
	var sweep := TAU * clampf(progress, 0.0, 1.0)
	var point_count := maxi(12, int(ceil(96.0 * progress)))
	var end_angle := RING_START_ANGLE + sweep
	draw_arc(center, radius, RING_START_ANGLE, end_angle, point_count, RING_COLOR, RING_WIDTH_PX, true)
	if progress >= 1.0:
		return
	var lead := center + Vector2(cos(end_angle), sin(end_angle)) * radius
	draw_circle(lead, RING_LEAD_RADIUS_PX, RING_COLOR)
