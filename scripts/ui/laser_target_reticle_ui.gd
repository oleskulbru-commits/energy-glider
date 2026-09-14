class_name LaserTargetReticleUI
extends Control

## HUD laser telegraph: reticle_1 flipbook (60 frames) stretched over 8 s shrink, then 2 s blink + ring.

const TelegraphScript = preload("res://scripts/enemies/laser_drone_telegraph.gd")
const VfxFlipbookScript := preload("res://scripts/vfx/vfx_flipbook.gd")
const ReticleShader := preload("res://assets/vfx/shaders/hud_laser_reticle.gdshader")

const TEXTURE_DIR := "res://assets/vfx/effect_textures/reticles/"
const FRAME_PREFIX := "reticle_1_frame_"
const FRAME_COUNT := 60
const FRAME_OFFSET := 0
## Flipbook art has canvas padding; inflate draw rect to match procedural bracket extent.
const FLIPBOOK_ART_SCALE := 1.45

const RETICLE_TINT := Color(1.6, 0.21, 0.064, 1.0)
const GLOW_STRENGTH := 3.0
const RING_COLOR := Color(1.0, 0.22, 0.1, 0.98)
const RING_WIDTH_PX := 3.5
const RING_LEAD_RADIUS_PX := 4.0
const BAR_LENGTH_PX := 42.0
const BASE_HALF_SPREAD_PX := 72.0
const RING_START_ANGLE := -PI * 0.5

static var _frames: Array[Texture2D] = []
static var _frames_loaded := false

var _display_scale := TelegraphScript.START_SCALE
var _elapsed := 0.0
var _circle_trace := 0.0
var _flipbook_visible := true
var _draw_visible := false
var _screen_center := Vector2.ZERO
var _anchor_valid := false
var _reticle_material: ShaderMaterial


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	_ensure_frames()
	_reticle_material = ShaderMaterial.new()
	_reticle_material.shader = ReticleShader
	_reticle_material.set_shader_parameter("color_tint", RETICLE_TINT)
	_reticle_material.set_shader_parameter("glow_strength", GLOW_STRENGTH)


func show_telegraph() -> void:
	_display_scale = TelegraphScript.START_SCALE
	_elapsed = 0.0
	_circle_trace = 0.0
	_draw_visible = true
	_anchor_valid = false
	visible = true
	queue_redraw()


func hide_telegraph() -> void:
	_draw_visible = false
	_anchor_valid = false
	_elapsed = 0.0
	_circle_trace = 0.0
	visible = false
	queue_redraw()


func update_telegraph(elapsed: float, _delta: float, screen_center: Vector2, anchor_valid: bool = true) -> void:
	if not _draw_visible:
		return
	_screen_center = screen_center.round()
	_anchor_valid = anchor_valid
	_elapsed = maxf(elapsed, 0.0)
	_display_scale = TelegraphScript.scale_at(_elapsed)
	_circle_trace = TelegraphScript.circle_trace_progress(_elapsed)
	_flipbook_visible = TelegraphScript.brackets_visible(_elapsed)
	visible = anchor_valid
	queue_redraw()


static func bracket_half_spread(scale: float) -> float:
	return BASE_HALF_SPREAD_PX * scale


static func outer_ring_radius(scale: float) -> float:
	return bracket_half_spread(scale) + BAR_LENGTH_PX


static func pixel_perfect_flip_rect(
	center: Vector2,
	desired_diameter: float,
	texture: Texture2D
) -> Rect2:
	var tex_px := maxi(1, int(roundf(texture.get_size().x)))
	var target := maxf(float(tex_px), desired_diameter)
	var scale := maxi(1, int(floor(target / float(tex_px))))
	var diameter := float(scale * tex_px)
	var snapped_center := center.round()
	var half := diameter * 0.5
	var pos := (snapped_center - Vector2(half, half)).round()
	return Rect2(pos, Vector2(diameter, diameter))


static func frame_index_at(elapsed: float) -> int:
	if elapsed >= TelegraphScript.SHRINK_SEC:
		return FRAME_COUNT - 1
	var t := clampf(elapsed / TelegraphScript.SHRINK_SEC, 0.0, 1.0)
	return clampi(int(floor(t * float(FRAME_COUNT - 1))), 0, FRAME_COUNT - 1)


static func _ensure_frames() -> Array[Texture2D]:
	if _frames_loaded:
		return _frames
	_frames = VfxFlipbookScript.load_texture_sequence(
		TEXTURE_DIR,
		FRAME_PREFIX,
		FRAME_COUNT,
		FRAME_OFFSET
	)
	_frames_loaded = true
	return _frames


func _draw() -> void:
	if not _draw_visible or not visible or not _anchor_valid:
		return
	var center := _screen_center.round()
	var radius := outer_ring_radius(_display_scale)

	if _flipbook_visible:
		var flip_diameter := radius * 2.0 * FLIPBOOK_ART_SCALE
		_draw_flipbook(center, flip_diameter)

	if _circle_trace <= 0.0:
		return
	material = null
	_draw_circle_trace(center, radius, _circle_trace)


func _draw_flipbook(center: Vector2, desired_diameter: float) -> void:
	var frames := _ensure_frames()
	if frames.is_empty():
		return
	var frame_idx := frame_index_at(_elapsed)
	frame_idx = clampi(frame_idx, 0, frames.size() - 1)
	var texture := frames[frame_idx]
	if texture == null:
		return
	var rect := pixel_perfect_flip_rect(center, desired_diameter, texture)
	material = _reticle_material
	draw_texture_rect(texture, rect, false)
	material = null


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
