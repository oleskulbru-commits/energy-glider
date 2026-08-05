class_name MathUtil
extends RefCounted

## Shared planar math and display helpers.


static func horizontal(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


static func horizontal_speed(velocity: Vector3) -> float:
	return Vector2(velocity.x, velocity.z).length()


static func yaw_forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


static func angle_diff(from_yaw: float, to_yaw: float) -> float:
	return wrapf(to_yaw - from_yaw, -PI, PI)


static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func bearing_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


static func format_distance_m(distance_m: float) -> String:
	if distance_m >= 1000.0:
		return "%.1f km" % (distance_m / 1000.0)
	return "%d m" % int(roundf(distance_m))
