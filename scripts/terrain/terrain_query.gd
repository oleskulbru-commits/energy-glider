class_name TerrainQuery
extends RefCounted

## Shared terrain height / raycast / surface-basis helpers.

const DEFAULT_COLLISION_MASK := 1
const DEFAULT_RAY_UP := 8.0
const DEFAULT_RAY_DOWN := 24.0


static func raycast_ground(
	space: PhysicsDirectSpaceState3D,
	world_x: float,
	world_z: float,
	origin_y: float,
	up: float = DEFAULT_RAY_UP,
	down: float = DEFAULT_RAY_DOWN,
	exclude: Array = [],
	collision_mask: int = DEFAULT_COLLISION_MASK
) -> Dictionary:
	if space == null:
		return {}
	var from := Vector3(world_x, origin_y + up, world_z)
	var to := Vector3(world_x, origin_y - down, world_z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	if not exclude.is_empty():
		query.exclude = exclude
	return space.intersect_ray(query)


static func sample_height(
	terrain: TerrainManager,
	space: PhysicsDirectSpaceState3D,
	world_x: float,
	world_z: float,
	origin_y: float,
	exclude: Array = [],
	up: float = DEFAULT_RAY_UP,
	down: float = DEFAULT_RAY_DOWN
) -> float:
	if terrain != null:
		return terrain.sample_height(world_x, world_z)
	var hit := raycast_ground(space, world_x, world_z, origin_y, up, down, exclude)
	if hit.is_empty():
		return NAN
	return hit.position.y


static func sample_normal(
	terrain: TerrainManager,
	space: PhysicsDirectSpaceState3D,
	world_x: float,
	world_z: float,
	origin_y: float,
	normal_epsilon: float = 1.5,
	exclude: Array = [],
	up: float = DEFAULT_RAY_UP,
	down: float = DEFAULT_RAY_DOWN
) -> Vector3:
	if terrain != null:
		return terrain.sample_normal(world_x, world_z, normal_epsilon)
	var hit := raycast_ground(space, world_x, world_z, origin_y, up, down, exclude)
	if hit.is_empty():
		return Vector3.UP
	var normal: Vector3 = hit.normal
	if normal.length_squared() < 0.0001:
		return Vector3.UP
	return normal.normalized()


static func sample_surface(
	terrain: TerrainManager,
	space: PhysicsDirectSpaceState3D,
	world_x: float,
	world_z: float,
	origin_y: float,
	normal_epsilon: float = 1.5,
	exclude: Array = [],
	up: float = 2.0,
	down: float = DEFAULT_RAY_DOWN
) -> Dictionary:
	if terrain != null:
		var height := terrain.sample_height(world_x, world_z)
		return {
			"position": Vector3(world_x, height, world_z),
			"normal": terrain.sample_normal(world_x, world_z, normal_epsilon),
		}
	var hit := raycast_ground(space, world_x, world_z, origin_y, up, down, exclude)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit.normal
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	return {
		"position": hit.position,
		"normal": normal,
	}


static func basis_from_up(normal: Vector3) -> Basis:
	var up := normal
	if up.length_squared() < 0.0001:
		up = Vector3.UP
	else:
		up = up.normalized()
	var basis := Basis()
	basis.y = up
	basis.x = Vector3.UP.cross(up)
	if basis.x.length_squared() < 0.0001:
		basis.x = Vector3.RIGHT.cross(up)
	basis.x = basis.x.normalized()
	basis.z = basis.x.cross(basis.y)
	return basis


static func downhill_dir(terrain: TerrainManager, world_x: float, world_z: float, epsilon: float = 1.0) -> Vector3:
	if terrain == null:
		return Vector3.ZERO
	var h_x := terrain.sample_height(world_x + epsilon, world_z)
	var h_mx := terrain.sample_height(world_x - epsilon, world_z)
	var h_z := terrain.sample_height(world_x, world_z + epsilon)
	var h_mz := terrain.sample_height(world_x, world_z - epsilon)
	# Finite difference of height points downhill (same sign as sample_normal XZ).
	var downhill := Vector3(h_mx - h_x, 0.0, h_mz - h_z)
	return downhill.normalized() if downhill.length_squared() > 0.0001 else Vector3.ZERO
