class_name WeaponTargeting
extends RefCounted

## When a living laser drone is in weapon range, all player weapons focus it until it dies.

const LASER_DRONE_GROUP := "laser_drone"


static func find_laser_drone_magnet(
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float,
	use_3d_range: bool = false,
	below_xz_eps_m: float = 0.05
) -> Node3D:
	for node in pills:
		if node == null or not is_instance_valid(node):
			continue
		if not (node as Node).is_in_group(LASER_DRONE_GROUP):
			continue
		var pill := node as SwarmPill
		if pill == null or not pill.is_alive():
			continue
		var pos := pill.global_position
		if use_3d_range:
			if origin.distance_to(pos) > range_m:
				continue
			var xz := AutoRifle.xz_distance(origin, pos)
			if xz > below_xz_eps_m and not AutoRifle.is_in_front(origin, facing, pos):
				continue
		else:
			if AutoRifle.xz_distance(origin, pos) > range_m:
				continue
			if not AutoRifle.is_in_front(origin, facing, pos):
				continue
		return pill
	return null


static func find_laser_drone_magnet_bounce(
	pills: Array,
	from: Vector3,
	bounce_range: float
) -> Node3D:
	for node in pills:
		if node == null or not is_instance_valid(node):
			continue
		if not (node as Node).is_in_group(LASER_DRONE_GROUP):
			continue
		var pill := node as SwarmPill
		if pill == null or not pill.is_alive():
			continue
		if AutoRifle.xz_distance(from, pill.global_position) > bounce_range:
			continue
		return pill
	return null
