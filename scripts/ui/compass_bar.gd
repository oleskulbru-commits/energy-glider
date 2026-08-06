class_name CompassBar
extends Control

const VISIBLE_DEGREES := 120.0
const TICK_STEP_DEG := 15.0
const CARDINALS := {
	0: "N",
	90: "E",
	180: "S",
	270: "W",
}

var yaw_rad := 0.0
var poi_bearing_rad := NAN
var eon_bearing_rad := NAN
var outpost_bearings: Array = []


var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func set_yaw(radians: float) -> void:
	yaw_rad = radians
	queue_redraw()


func set_poi_bearing(radians: float) -> void:
	poi_bearing_rad = radians
	queue_redraw()


func set_eon_bearing(radians: float) -> void:
	eon_bearing_rad = radians
	queue_redraw()


func set_outpost_bearings(bearings: Array) -> void:
	outpost_bearings = bearings
	queue_redraw()


static func yaw_to_cardinal_index(yaw: float) -> String:
	var deg := int(roundf(rad_to_deg(wrapf(yaw, 0.0, TAU)))) % 360
	return CARDINALS.get(deg, str(deg))


static func angle_diff(from_yaw: float, to_yaw: float) -> float:
	return MathUtil.angle_diff(from_yaw, to_yaw)


func _draw() -> void:
	var center := size * 0.5
	var px_per_deg := size.x / VISIBLE_DEGREES
	var center_deg := rad_to_deg(yaw_rad)

	for tick_deg in range(0, 360, int(TICK_STEP_DEG)):
		var delta := wrapf(center_deg - float(tick_deg), -180.0, 180.0)
		if absf(delta) > VISIBLE_DEGREES * 0.5:
			continue
		var x := center.x + delta * px_per_deg
		var major := int(tick_deg) % 90 == 0
		var tick_h := 10.0 if major else 6.0
		draw_line(
			Vector2(x, 4.0),
			Vector2(x, 4.0 + tick_h),
			Color(0.92, 0.9, 0.82, 0.9 if major else 0.55),
			1.0 if major else 1.0
		)
		if major:
			var label: String = CARDINALS.get(tick_deg, "")
			if label.is_empty():
				label = str(tick_deg)
			var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			draw_string(
				_font,
				Vector2(x - text_size.x * 0.5, 28.0),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color(0.98, 0.94, 0.82, 0.95)
			)

	draw_line(
		Vector2(center.x, 0.0),
		Vector2(center.x, size.y),
		Color(1.0, 0.82, 0.28, 0.95),
		2.0
	)

	for bearing in outpost_bearings:
		if typeof(bearing) != TYPE_FLOAT and typeof(bearing) != TYPE_INT:
			continue
		var out_delta := -rad_to_deg(angle_diff(yaw_rad, float(bearing)))
		if absf(out_delta) > VISIBLE_DEGREES * 0.5:
			continue
		var out_x := center.x + out_delta * px_per_deg
		draw_line(
			Vector2(out_x, size.y - 14.0),
			Vector2(out_x, size.y - 2.0),
			Color(0.55, 0.85, 1.0, 0.95),
			2.0
		)
		draw_circle(Vector2(out_x, size.y - 4.0), 3.0, Color(0.55, 0.85, 1.0, 0.95))

	if not is_nan(poi_bearing_rad):
		var poi_delta := -rad_to_deg(angle_diff(yaw_rad, poi_bearing_rad))
		if absf(poi_delta) <= VISIBLE_DEGREES * 0.5:
			var poi_x := center.x + poi_delta * px_per_deg
			draw_circle(Vector2(poi_x, size.y - 6.0), 4.0, Color(1.0, 0.82, 0.28, 0.95))

	if not is_nan(eon_bearing_rad):
		var eon_delta := -rad_to_deg(angle_diff(yaw_rad, eon_bearing_rad))
		if absf(eon_delta) <= VISIBLE_DEGREES * 0.5:
			var eon_x := center.x + eon_delta * px_per_deg
			var eon_center := Vector2(eon_x, size.y - 8.0)
			draw_colored_polygon(
				PackedVector2Array([
					eon_center + Vector2(0.0, -7.0),
					eon_center + Vector2(-5.0, 3.0),
					eon_center + Vector2(5.0, 3.0),
				]),
				Color(0.92, 0.35, 1.0, 0.98)
			)
