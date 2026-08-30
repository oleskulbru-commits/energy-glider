class_name TerrainManager
extends Node3D

const CHUNK_SIZE := ChunkBuilder.CHUNK_SIZE
const LOAD_RADIUS := 2
const UNLOAD_RADIUS := 3
const INITIAL_LOAD_RADIUS := LOAD_RADIUS
const MAX_MESH_FINALIZE_PER_FRAME := 1
const MAX_COLLISION_FINALIZE_PER_FRAME := 1
const LevelRunScript = preload("res://scripts/game/level_run.gd")
const RUN_SESSION_PATH := "user://run_session.cfg"

@export var world_seed: int = 42
@export var sand_material: Material
@export var track_node_path: NodePath

var run_origin: Vector2 = Vector2.ZERO
var _height_sampler: DuneHeight
var _active_chunks: Dictionary = {}
var _pending_chunks: Dictionary = {}
var _mesh_ready_queue: Array[Dictionary] = []
var _collision_pending: Array[Dictionary] = []
var _track_node: Node3D


func _ready() -> void:
	add_to_group("terrain_manager")
	# Keep streaming/finalize alive while weapon select pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_session_seed()
	LevelRunScript.ensure(world_seed)
	_height_sampler = DuneHeight.new(world_seed)
	run_origin = Vector2(global_position.x, global_position.z)
	_height_sampler.set_run_origin(run_origin)

	if track_node_path != NodePath():
		_track_node = get_node_or_null(track_node_path) as Node3D

	# Skip mesh generation while editing — height sampling still works for tools.
	if Engine.is_editor_hint():
		return
	_prewarm_height_cache()
	_request_initial_chunks()


func _apply_session_seed() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RUN_SESSION_PATH)
	if OS.has_feature("editor"):
		# F5 / editor play should roll a fresh run so tower shops vary while iterating.
		world_seed = randi()
	elif cfg.has_section_key("terrain", "world_seed"):
		world_seed = int(cfg.get_value("terrain", "world_seed"))
	cfg.set_value("terrain", "world_seed", world_seed)
	cfg.save(RUN_SESSION_PATH)
	LevelRunScript.generate(world_seed)


func _prewarm_height_cache() -> void:
	var journey_m := LevelRunScript.journey_length_m()
	var sample_step := CHUNK_SIZE
	var origin_x := run_origin.x
	var origin_z := run_origin.y
	var west_m := 0.0
	while west_m <= journey_m + CHUNK_SIZE:
		_height_sampler.sample_height(origin_x - west_m, origin_z)
		west_m += sample_step
	for lateral in [-512.0, 512.0]:
		west_m = 0.0
		while west_m <= journey_m + CHUNK_SIZE:
			_height_sampler.sample_height(origin_x - west_m, origin_z + lateral)
			west_m += sample_step * 2.0


func _request_initial_chunks() -> void:
	for dx in range(-INITIAL_LOAD_RADIUS, INITIAL_LOAD_RADIUS + 1):
		for dz in range(-INITIAL_LOAD_RADIUS, INITIAL_LOAD_RADIUS + 1):
			_request_chunk(Vector2i(dx, dz))


func set_track_node(node: Node3D) -> void:
	_track_node = node


func ensure_loaded_at(world_pos: Vector3) -> void:
	if Engine.is_editor_hint():
		return
	var center := _world_to_chunk(world_pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_request_chunk(Vector2i(center.x + dx, center.y + dz))


func sample_height(world_x: float, world_z: float) -> float:
	return _height_sampler.sample_height(world_x, world_z)


func sample_normal(world_x: float, world_z: float, epsilon: float = 1.0) -> Vector3:
	return _height_sampler.sample_normal(world_x, world_z, epsilon)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_streaming()
	_finalize_meshes()
	_finalize_collisions()


func _get_track_position() -> Vector3:
	if _track_node != null:
		return _track_node.global_position
	return Vector3.ZERO


func _update_streaming() -> void:
	var track_pos := _get_track_position()
	var center := _world_to_chunk(track_pos)

	for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			if not _active_chunks.has(key) and not _pending_chunks.has(key):
				_request_chunk(key)

	var keys_to_remove: Array[Vector2i] = []
	for key: Vector2i in _active_chunks.keys():
		if _chunk_chebyshev_distance(key, center) > UNLOAD_RADIUS:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		var chunk: Node3D = _active_chunks[key]
		_active_chunks.erase(key)
		_remove_collision_pending_for_chunk(chunk)
		chunk.queue_free()


func _remove_collision_pending_for_chunk(chunk: Node3D) -> void:
	for i in range(_collision_pending.size() - 1, -1, -1):
		if _collision_pending[i].get("chunk") == chunk:
			_collision_pending.remove_at(i)


func _request_chunk(key: Vector2i) -> void:
	if _active_chunks.has(key) or _pending_chunks.has(key):
		return

	_pending_chunks[key] = true
	WorkerThreadPool.add_task(_build_chunk_async.bind(key))


func _build_chunk_async(key: Vector2i) -> void:
	var sampler := DuneHeight.new(world_seed)
	sampler.set_run_origin(run_origin)
	var build_result := ChunkBuilder.build(sampler, key.x, key.y)
	var collision_result := ChunkBuilder.build_collision(sampler, key.x, key.y)
	var payload := {
		"chunk_key": key,
		"mesh_arrays": build_result["mesh_arrays"],
		"collision_arrays": collision_result["mesh_arrays"],
		"verts_per_side": build_result["verts_per_side"],
		"collision_verts_per_side": collision_result["verts_per_side"],
	}
	call_deferred("_on_chunk_built", payload)


func _on_chunk_built(payload: Dictionary) -> void:
	var key: Vector2i = payload["chunk_key"]
	if _active_chunks.has(key):
		_pending_chunks.erase(key)
		return
	_mesh_ready_queue.append(payload)


func _sort_mesh_queue_by_player() -> void:
	var center := _world_to_chunk(_get_track_position())
	_mesh_ready_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var key_a: Vector2i = a["chunk_key"]
		var key_b: Vector2i = b["chunk_key"]
		return _chunk_chebyshev_distance(key_a, center) < _chunk_chebyshev_distance(key_b, center)
	)


func _finalize_meshes() -> void:
	if _mesh_ready_queue.is_empty():
		return

	_sort_mesh_queue_by_player()
	var center := _world_to_chunk(_get_track_position())
	var finalized := 0

	while finalized < MAX_MESH_FINALIZE_PER_FRAME and not _mesh_ready_queue.is_empty():
		var payload: Dictionary = _mesh_ready_queue.pop_front()
		var key: Vector2i = payload["chunk_key"]
		_pending_chunks.erase(key)

		if _active_chunks.has(key):
			continue
		if _chunk_chebyshev_distance(key, center) > UNLOAD_RADIUS:
			continue

		var chunk := _finalize_mesh(payload)
		_active_chunks[key] = chunk
		add_child(chunk)
		_collision_pending.append({
			"chunk": chunk,
			"collision_arrays": payload["collision_arrays"],
		})
		finalized += 1


func _finalize_mesh(payload: Dictionary) -> Node3D:
	var chunk_root := Node3D.new()
	var key: Vector2i = payload["chunk_key"]
	chunk_root.name = "Chunk_%d_%d" % [key.x, key.y]
	chunk_root.set_meta("collision_pending", true)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, payload["mesh_arrays"])

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if sand_material != null:
		mesh_instance.material_override = sand_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	chunk_root.add_child(mesh_instance)

	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1
	chunk_root.add_child(static_body)

	return chunk_root


func _finalize_collisions() -> void:
	if _collision_pending.is_empty():
		return

	var finalized := 0
	var index := 0
	while index < _collision_pending.size() and finalized < MAX_COLLISION_FINALIZE_PER_FRAME:
		var entry: Dictionary = _collision_pending[index]
		var chunk: Node3D = entry.get("chunk")
		if chunk == null or not is_instance_valid(chunk):
			_collision_pending.remove_at(index)
			continue

		var static_body := chunk.get_node_or_null("TerrainCollision") as StaticBody3D
		if static_body == null:
			_collision_pending.remove_at(index)
			continue

		var collision_mesh := ArrayMesh.new()
		collision_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			entry["collision_arrays"]
		)
		var shape := collision_mesh.create_trimesh_shape()
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		chunk.set_meta("collision_pending", false)

		_collision_pending.remove_at(index)
		finalized += 1


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CHUNK_SIZE)),
		int(floor(world_pos.z / CHUNK_SIZE))
	)


func _chunk_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
