extends Control

## Draws panel_frame.png in pieces.
## Corners, the center tab, and the side diamonds keep a uniform scale.
## Only the straight top, bottom, and side segments stretch.

const FRAME := preload("res://assets/ui/upgrade_menu/panel_frame.png")
const SRC_W := 1024.0
const SRC_H := 394.0
const SCALE := 1.35
const CORNER_W := 140.0
const TOP_H := 80.0
const BOT_H := 86.0
const SIDE_W := 100.0
const DIAMOND_Y := 158.0
const DIAMOND_H := 58.0
const TAB := Rect2(248, 10, 528, 30)
const TOP_EDGE := Rect2(140, 30, 744, 28)
const BOT_EDGE_Y := 346.0
const BOT_EDGE_H := 16.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func top_stroke_y() -> float:
	return 42.0 * SCALE


func top_bar_span() -> Vector2:
	var inset := 108.0 * SCALE
	return Vector2(inset, size.x - inset)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var top_h := TOP_H * SCALE
	var bot_h := BOT_H * SCALE
	var side_w := SIDE_W * SCALE
	var diamond_h := DIAMOND_H * SCALE
	var mid_top := top_h
	var mid_h := size.y - top_h - bot_h
	var gap := maxf(0.0, (mid_h - diamond_h) * 0.5)
	_edge(TOP_EDGE, Rect2(CORNER_W * SCALE, TOP_EDGE.position.y * SCALE, size.x - CORNER_W * SCALE * 2.0, TOP_EDGE.size.y * SCALE))
	var bot_src_y := SRC_H - BOT_H
	_edge(
		Rect2(CORNER_W, BOT_EDGE_Y, SRC_W - CORNER_W * 2.0, BOT_EDGE_H),
		Rect2(
			CORNER_W * SCALE,
			size.y - bot_h + (BOT_EDGE_Y - bot_src_y) * SCALE,
			size.x - CORNER_W * SCALE * 2.0,
			BOT_EDGE_H * SCALE
		)
	)
	_side(Rect2(0, TOP_H, SIDE_W, DIAMOND_Y - TOP_H), Rect2(0, mid_top, side_w, gap))
	_side(
		Rect2(SRC_W - SIDE_W, TOP_H, SIDE_W, DIAMOND_Y - TOP_H),
		Rect2(size.x - side_w, mid_top, side_w, gap)
	)
	var below_y := DIAMOND_Y + DIAMOND_H
	var below_h := bot_src_y - below_y
	_side(Rect2(0, below_y, SIDE_W, below_h), Rect2(0, mid_top + gap + diamond_h, side_w, gap))
	_side(
		Rect2(SRC_W - SIDE_W, below_y, SIDE_W, below_h),
		Rect2(size.x - side_w, mid_top + gap + diamond_h, side_w, gap)
	)
	_piece(Rect2(0, 0, CORNER_W, TOP_H), Rect2(0, 0, CORNER_W * SCALE, top_h))
	_piece(Rect2(SRC_W - CORNER_W, 0, CORNER_W, TOP_H), Rect2(size.x - CORNER_W * SCALE, 0, CORNER_W * SCALE, top_h))
	_piece(Rect2(0, bot_src_y, CORNER_W, BOT_H), Rect2(0, size.y - bot_h, CORNER_W * SCALE, bot_h))
	_piece(
		Rect2(SRC_W - CORNER_W, bot_src_y, CORNER_W, BOT_H),
		Rect2(size.x - CORNER_W * SCALE, size.y - bot_h, CORNER_W * SCALE, bot_h)
	)
	_piece(TAB, Rect2((size.x - TAB.size.x * SCALE) * 0.5, TAB.position.y * SCALE, TAB.size.x * SCALE, TAB.size.y * SCALE))
	_piece(Rect2(0, DIAMOND_Y, SIDE_W, DIAMOND_H), Rect2(0, mid_top + gap, side_w, diamond_h))
	_piece(
		Rect2(SRC_W - SIDE_W, DIAMOND_Y, SIDE_W, DIAMOND_H),
		Rect2(size.x - side_w, mid_top + gap, side_w, diamond_h)
	)


func _piece(src: Rect2, dst: Rect2) -> void:
	draw_texture_rect_region(FRAME, dst, src)


func _edge(src: Rect2, dst: Rect2) -> void:
	draw_texture_rect_region(FRAME, dst, src)


func _side(src: Rect2, dst: Rect2) -> void:
	if dst.size.y <= 1.0:
		return
	draw_texture_rect_region(FRAME, dst, src)
