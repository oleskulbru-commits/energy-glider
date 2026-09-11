class_name WeaponTargeting
extends RefCounted

## Living magnets steal every weapon lock while in range. Boss beats the red drone.

const LASER_DRONE_GROUP := "laser_drone"
const BOSS_GROUP := "boss"
const MAGNET_GROUPS: Array[StringName] = [BOSS_GROUP, LASER_DRONE_GROUP]


static func lock_point(target: Node3D, from: Vector3) -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	if target is SwarmPill:
		return (target as SwarmPill).closest_aim_point(from)
	return target.global_position


static func in_xz_range(origin: Vector3, target: Node3D, range_m: float) -> bool:
	return AutoRifle.xz_distance(origin, lock_point(target, origin)) <= range_m


static func in_3d_range(origin: Vector3, target: Node3D, range_m: float) -> bool:
	return origin.distance_to(lock_point(target, origin)) <= range_m


static func is_lock_in_front(origin: Vector3, facing: Vector3, target: Node3D) -> bool:
	var pos := lock_point(target, origin)
	var to := Vector3(pos.x - origin.x, 0.0, pos.z - origin.z)
	if to.length_squared() < 0.0001:
		return true
	return AutoRifle.is_in_front(origin, facing, pos)


static func find_magnet(
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float,
	use_3d_range: bool = false,
	below_xz_eps_m: float = 0.05
) -> Node3D:
	for group in MAGNET_GROUPS:
		var magnet := _find_group_magnet(
			group, pills, origin, facing, range_m, use_3d_range, below_xz_eps_m
		)
		if magnet != null:
			return magnet
	return null


## Kept for existing weapon call sites. Boss outranks the red drone.
static func find_laser_drone_magnet(
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float,
	use_3d_range: bool = false,
	below_xz_eps_m: float = 0.05
) -> Node3D:
	return find_magnet(pills, origin, facing, range_m, use_3d_range, below_xz_eps_m)


static func find_magnet_bounce(
	pills: Array,
	from: Vector3,
	bounce_range: float
) -> Node3D:
	for group in MAGNET_GROUPS:
		var magnet := _find_group_magnet_bounce(group, pills, from, bounce_range)
		if magnet != null:
			return magnet
	return null


static func find_laser_drone_magnet_bounce(
	pills: Array,
	from: Vector3,
	bounce_range: float
) -> Node3D:
	return find_magnet_bounce(pills, from, bounce_range)


static func _find_group_magnet(
	group: StringName,
	pills: Array,
	origin: Vector3,
	facing: Vector3,
	range_m: float,
	use_3d_range: bool,
	below_xz_eps_m: float
) -> Node3D:
	for node in pills:
		if node == null or not is_instance_valid(node):
			continue
		if not (node as Node).is_in_group(group):
			continue
		var pill := node as SwarmPill
		if pill == null or not pill.is_alive():
			continue
		var pos := lock_point(pill, origin)
		if use_3d_range:
			if origin.distance_to(pos) > range_m:
				continue
			var xz := AutoRifle.xz_distance(origin, pos)
			if xz > below_xz_eps_m and not AutoRifle.is_in_front(origin, facing, pos):
				continue
		else:
			if AutoRifle.xz_distance(origin, pos) > range_m:
				continue
			if not is_lock_in_front(origin, facing, pill):
				continue
		return pill
	return null


static func _find_group_magnet_bounce(
	group: StringName,
	pills: Array,
	from: Vector3,
	bounce_range: float
) -> Node3D:
	for node in pills:
		if node == null or not is_instance_valid(node):
			continue
		if not (node as Node).is_in_group(group):
			continue
		var pill := node as SwarmPill
		if pill == null or not pill.is_alive():
			continue
		if AutoRifle.xz_distance(from, lock_point(pill, from)) > bounce_range:
			continue
		return pill
	return null
