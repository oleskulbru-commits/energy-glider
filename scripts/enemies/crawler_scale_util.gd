class_name CrawlerScaleUtil
extends RefCounted

## Detects animated GLB armature shrink and computes living-model scale.

const ANIMATED_SCENE := preload(
	"res://assets/3dmodels/enemies/crawler/crawler_animated_v001.glb"
)
const SKELETON_NODE_NAME := &"Crawler_Skeleton"
const MIN_ARMATURE_SCALE := 0.0001

static var _import_armature_scale: float = -1.0


static func import_armature_scale() -> float:
	if _import_armature_scale < 0.0:
		_import_armature_scale = _measure_import_armature_scale()
	return _import_armature_scale


static func animated_model_scale(game_scale: float) -> float:
	var armature := import_armature_scale()
	return game_scale / maxf(armature, MIN_ARMATURE_SCALE)


static func death_burst_scale(
	game_scale: float = SwarmPill.CRAWLER_LIVING_SCALE,
	burst_mult: float = SwarmPill.CRAWLER_FRACTURED_BURST_MULT
) -> float:
	return animated_model_scale(game_scale) * burst_mult


static func _measure_import_armature_scale() -> float:
	var root: Node = ANIMATED_SCENE.instantiate()
	var skeleton := root.get_node_or_null(NodePath(str(SKELETON_NODE_NAME))) as Node3D
	var scale := 1.0
	if skeleton != null:
		scale = skeleton.transform.basis.get_scale().x
	root.free()
	return maxf(scale, MIN_ARMATURE_SCALE)


static func combined_mesh_global_aabb(model: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if meshes.is_empty():
		return AABB(model.global_position, Vector3.ZERO)
	var aabb := meshes[0].global_transform * meshes[0].get_aabb()
	for mesh in meshes.slice(1):
		aabb = aabb.merge(mesh.global_transform * mesh.get_aabb())
	return aabb


static func combined_mesh_local_aabb(model: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if meshes.is_empty():
		return AABB()
	var aabb := meshes[0].get_aabb()
	for mesh in meshes.slice(1):
		aabb = aabb.merge(mesh.get_aabb())
	return aabb


static func death_burst_transform(model: Node3D) -> Transform3D:
	var aabb := combined_mesh_global_aabb(model)
	var basis := model.global_transform.basis.orthonormalized()
	var feet := Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
	return Transform3D(basis, feet)


static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			out.append(mesh_inst)
	for child in node.get_children():
		_collect_meshes(child, out)
