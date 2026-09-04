class_name CrawlerDeathBurst
extends Node3D

## One-shot fractured crawler shards driven by physics.

const FRACTURED_SCENE := preload(
	"res://assets/3dmodels/enemies/crawler/crawler_fractured_v001.glb"
)
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const CrawlerDebrisSandScript := preload("res://scripts/enemies/crawler_debris_sand.gd")

const LIFETIME_SEC := 3.0
const IMPULSE_MIN := 5.0
const IMPULSE_MAX := 16.0
const UP_IMPULSE := 4.0
const TORQUE_MAX := 10.0
const MIN_MESH_VOLUME := 0.00008

## World/terrain only — avoid blocking player shots or enemy hits.
const DEBRIS_COLLISION_LAYER := 1
const DEBRIS_COLLISION_MASK := 1

var _terrain: TerrainManager


static func spawn(
	tree: SceneTree,
	xf: Transform3D,
	hit_pos: Vector3,
	scale: float = CrawlerScaleUtil.death_burst_scale(),
	terrain: TerrainManager = null
) -> void:
	if tree == null:
		return
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return
	var burst := FRACTURED_SCENE.instantiate()
	var wrapper := CrawlerDeathBurst.new()
	parent.add_child(wrapper)
	wrapper.global_transform = xf
	wrapper.add_child(burst)
	burst.scale = Vector3.ONE * scale
	wrapper._terrain = terrain
	wrapper._build_shards(burst, hit_pos)
	KillSparks.spawn(tree, xf.origin)
	wrapper._schedule_cleanup()


func _build_shards(model_root: Node, hit_pos: Vector3) -> void:
	_hide_non_piece_meshes(model_root)
	var pieces := _collect_piece_meshes(model_root)
	for mesh_inst: MeshInstance3D in pieces:
		_promote_to_rigid_body(mesh_inst, hit_pos)
	if pieces.is_empty():
		push_warning("CrawlerDeathBurst: no fractured pieces found")
	else:
		model_root.visible = false


func _is_shard_mesh_name(name: String) -> bool:
	if name.begins_with("Crawler_Fractured_cell") or name.begins_with("Crawler_Pieces"):
		return true
	# Fractured export: Crawler_Model_001, Crawler_Model_002, ... (not living Crawler_Model).
	return name.begins_with("Crawler_Model_")


func _hide_non_piece_meshes(model_root: Node) -> void:
	for child in model_root.get_children():
		if child.name.begins_with("Crawler_Skeleton"):
			child.visible = false
		elif child is MeshInstance3D and not _is_shard_mesh_name(child.name):
			child.visible = false


func _collect_piece_meshes(model_root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_collect_piece_meshes_recursive(model_root, out)
	return out


func _collect_piece_meshes_recursive(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null and _is_shard_mesh_name(mesh_inst.name):
			out.append(mesh_inst)
	for child in node.get_children():
		_collect_piece_meshes_recursive(child, out)


func _promote_to_rigid_body(mesh_inst: MeshInstance3D, hit_pos: Vector3) -> void:
	var mesh: Mesh = mesh_inst.mesh
	if mesh == null:
		mesh_inst.queue_free()
		return
	var aabb := mesh.get_aabb()
	if aabb.size.length_squared() < MIN_MESH_VOLUME:
		mesh_inst.queue_free()
		return

	var body := RigidBody3D.new()
	body.collision_layer = DEBRIS_COLLISION_LAYER
	body.collision_mask = DEBRIS_COLLISION_MASK
	body.gravity_scale = 1.0
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 1
	body.add_child(_duplicate_mesh(mesh_inst))
	body.add_child(_collision_for_mesh(mesh))

	add_child(body)
	body.global_transform = mesh_inst.global_transform
	mesh_inst.queue_free()

	_apply_burst_impulse(body, hit_pos)
	CrawlerDebrisSandScript.attach(body, _terrain)


func _duplicate_mesh(source: MeshInstance3D) -> MeshInstance3D:
	var copy := MeshInstance3D.new()
	copy.mesh = source.mesh
	copy.transform = Transform3D.IDENTITY
	for surface_idx in source.get_surface_override_material_count():
		var mat := source.get_surface_override_material(surface_idx)
		if mat != null:
			copy.set_surface_override_material(surface_idx, mat)
	return copy


func _collision_for_mesh(mesh: Mesh) -> CollisionShape3D:
	var shape_node := CollisionShape3D.new()
	var shape: Shape3D = mesh.create_convex_shape(true, false)
	if shape == null:
		shape = mesh.create_trimesh_shape()
	shape_node.shape = shape
	return shape_node


func _apply_burst_impulse(body: RigidBody3D, hit_pos: Vector3) -> void:
	var origin := hit_pos
	if origin == Vector3.ZERO:
		origin = body.global_position
	var dir := body.global_position - origin
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	dir = dir.normalized()
	var strength := randf_range(IMPULSE_MIN, IMPULSE_MAX)
	var impulse := dir * strength + Vector3.UP * UP_IMPULSE
	body.apply_central_impulse(impulse)
	body.apply_torque_impulse(
		Vector3(
			randf_range(-TORQUE_MAX, TORQUE_MAX),
			randf_range(-TORQUE_MAX, TORQUE_MAX),
			randf_range(-TORQUE_MAX, TORQUE_MAX)
		)
	)


func _schedule_cleanup() -> void:
	var timer := get_tree().create_timer(LIFETIME_SEC)
	timer.timeout.connect(queue_free)
