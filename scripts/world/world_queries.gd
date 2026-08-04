class_name WorldQueries
extends RefCounted

## Scene-tree proximity helpers for POIs and stations.


static func ranked_node3d_by_horizontal_distance(
	nodes: Array,
	origin: Vector3,
	min_distance: float = 0.0,
	exclude: Node3D = null
) -> Array:
	var ranked: Array = []
	for node in nodes:
		var spatial := node as Node3D
		if spatial == null or spatial == exclude:
			continue
		if not is_instance_valid(spatial):
			continue
		var dist := MathUtil.horizontal_distance(origin, spatial.global_position)
		if dist < min_distance:
			continue
		ranked.append({
			"node": spatial,
			"dist": dist,
			"bearing": MathUtil.bearing_to(origin, spatial.global_position),
		})
	ranked.sort_custom(func(a, b): return float(a.dist) < float(b.dist))
	return ranked


static func nearest_node3d(nodes: Array, origin: Vector3) -> Node3D:
	var ranked := ranked_node3d_by_horizontal_distance(nodes, origin)
	if ranked.is_empty():
		return null
	return ranked[0].node as Node3D


static func nearest_in_group(tree: SceneTree, group: String, origin: Vector3) -> Node3D:
	if tree == null:
		return null
	return nearest_node3d(tree.get_nodes_in_group(group), origin)


static func ranked_in_group(
	tree: SceneTree,
	group: String,
	origin: Vector3,
	min_distance: float = 0.0,
	exclude: Node3D = null
) -> Array:
	if tree == null:
		return []
	return ranked_node3d_by_horizontal_distance(
		tree.get_nodes_in_group(group),
		origin,
		min_distance,
		exclude
	)
