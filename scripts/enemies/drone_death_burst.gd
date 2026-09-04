class_name DroneDeathBurst
extends Node3D

## Body + weapon module physics debris when a combat drone dies.

const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const CrawlerDebrisSandScript := preload("res://scripts/enemies/crawler_debris_sand.gd")

const BODY_PIECE_PATH := NodePath("Body/Body")
const WEAPON_PIECE_PATH := NodePath("Body/CSGCylinder3D/Weapon_Pivot/WeaponModule")

const LIFETIME_SEC := 3.0
const IMPULSE_MIN := 3.0
const IMPULSE_MAX := 10.0
const UP_IMPULSE := 2.5
const TORQUE_MAX := 8.0
const MIN_MESH_VOLUME := 0.00008

const DEBRIS_COLLISION_LAYER := 1
const DEBRIS_COLLISION_MASK := 1

var _terrain: TerrainManager


static func spawn(
	tree: SceneTree,
	drone_xf: Transform3D,
	visual: Node3D,
	hit_pos: Vector3,
	terrain: TerrainManager = null
) -> Node3D:
	if tree == null or visual == null:
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null
	var wrapper = load("res://scripts/enemies/drone_death_burst.gd").new()
	parent.add_child(wrapper)
	wrapper.global_transform = drone_xf
	wrapper._terrain = terrain
	wrapper._spawn_pieces(visual, hit_pos)
	KillSparks.spawn(tree, drone_xf.origin)
	wrapper._schedule_cleanup()
	return wrapper


func get_debris_bodies() -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = []
	for child in get_children():
		if child is RigidBody3D:
			out.append(child as RigidBody3D)
	return out


func _spawn_pieces(visual: Node3D, hit_pos: Vector3) -> void:
	var body_piece := visual.get_node_or_null(BODY_PIECE_PATH) as Node3D
	var weapon_piece := visual.get_node_or_null(WEAPON_PIECE_PATH) as Node3D
	if body_piece != null:
		_promote_piece(body_piece, hit_pos)
	if weapon_piece != null:
		_promote_piece(weapon_piece, hit_pos)
	if get_child_count() == 0:
		push_warning("DroneDeathBurst: no debris pieces spawned from visual")


func _promote_piece(piece_root: Node3D, hit_pos: Vector3) -> void:
	var mesh_entries := _collect_mesh_entries(piece_root)
	if mesh_entries.is_empty():
		return

	var body := RigidBody3D.new()
	body.collision_layer = DEBRIS_COLLISION_LAYER
	body.collision_mask = DEBRIS_COLLISION_MASK
	body.gravity_scale = 1.0
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 1
	add_child(body)
	body.global_transform = piece_root.global_transform

	for entry in mesh_entries:
		var mesh_inst: MeshInstance3D = entry.inst
		var mesh: Mesh = mesh_inst.mesh
		if mesh == null:
			continue
		if mesh.get_aabb().size.length_squared() < MIN_MESH_VOLUME:
			continue
		var copy := _duplicate_mesh(mesh_inst)
		copy.transform = entry.local_xf
		body.add_child(copy)
		var collision := _collision_for_mesh(mesh)
		collision.transform = entry.local_xf
		body.add_child(collision)

	if body.get_child_count() == 0:
		body.queue_free()
		return

	_apply_burst_impulse(body, hit_pos)
	CrawlerDebrisSandScript.attach(body, _terrain)


func _collect_mesh_entries(piece_root: Node3D) -> Array:
	var out: Array = []
	_collect_mesh_entries_recursive(piece_root, piece_root, out)
	return out


func _collect_mesh_entries_recursive(node: Node, piece_root: Node3D, out: Array) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			out.append({
				"inst": mesh_inst,
				"local_xf": piece_root.global_transform.affine_inverse() * mesh_inst.global_transform,
			})
	for child in node.get_children():
		_collect_mesh_entries_recursive(child, piece_root, out)


func _duplicate_mesh(source: MeshInstance3D) -> MeshInstance3D:
	var copy := MeshInstance3D.new()
	copy.mesh = source.mesh
	for surface_idx in source.get_surface_override_material_count():
		var mat := source.get_surface_override_material(surface_idx)
		if mat != null:
			copy.set_surface_override_material(surface_idx, mat)
	if source.material_override != null:
		copy.material_override = source.material_override
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
