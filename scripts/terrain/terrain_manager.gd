class_name TerrainManager
extends Node3D

const CHUNK_SIZE := ChunkBuilder.CHUNK_SIZE
const LOAD_RADIUS := 2
const UNLOAD_RADIUS := 3
const INITIAL_SYNC_RADIUS := LOAD_RADIUS

@export var world_seed: int = 42
@export var sand_material: Material
@export var track_node_path: NodePath

var run_origin: Vector2 = Vector2.ZERO
var _height_sampler: DuneHeight
var _active_chunks: Dictionary = {}
var _pending_chunks: Dictionary = {}
var _track_node: Node3D


func _ready() -> void:
	_apply_session_seed()
	_height_sampler = DuneHeight.new(world_seed)
	run_origin = Vector2(global_position.x, global_position.z)
	_height_sampler.set_run_origin(run_origin)

	if track_node_path != NodePath():
		_track_node = get_node_or_null(track_node_path) as Node3D

	# Skip mesh generation while editing — height sampling still works for tools.
	if Engine.is_editor_hint():
		return
	_load_initial_chunks_sync()


func _apply_session_seed() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://run_session.cfg") != OK:
		return
	if cfg.has_section_key("terrain", "world_seed"):
		world_seed = int(cfg.get_value("terrain", "world_seed"))


func _load_initial_chunks_sync() -> void:
	for dx in range(-INITIAL_SYNC_RADIUS, INITIAL_SYNC_RADIUS + 1):
		for dz in range(-INITIAL_SYNC_RADIUS, INITIAL_SYNC_RADIUS + 1):
			_load_chunk_sync(Vector2i(dx, dz))


func set_track_node(node: Node3D) -> void:
	_track_node = node


func ensure_loaded_at(world_pos: Vector3) -> void:
	if Engine.is_editor_hint():
		return
	var center := _world_to_chunk(world_pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_load_chunk_sync(Vector2i(center.x + dx, center.y + dz))


func sample_height(world_x: float, world_z: float) -> float:
	return _height_sampler.sample_height(world_x, world_z)


func sample_normal(world_x: float, world_z: float, epsilon: float = 1.0) -> Vector3:
	return _height_sampler.sample_normal(world_x, world_z, epsilon)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_streaming()


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
		chunk.queue_free()


func _request_chunk(key: Vector2i) -> void:
	if _active_chunks.has(key) or _pending_chunks.has(key):
		return

	if _is_ahead_of_player(key):
		_load_chunk_sync(key)
	else:
		_pending_chunks[key] = true
		WorkerThreadPool.add_task(_build_chunk_async.bind(key))


func _is_ahead_of_player(key: Vector2i) -> bool:
	var center := _world_to_chunk(_get_track_position())
	return key.y > center.y


func _load_chunk_sync(key: Vector2i) -> void:
	if _active_chunks.has(key):
		return

	_pending_chunks.erase(key)
	var build_result := ChunkBuilder.build(_height_sampler, key.x, key.y)
	build_result["chunk_key"] = key
	var chunk := _create_chunk_node(build_result)
	_active_chunks[key] = chunk
	add_child(chunk)


func _build_chunk_async(key: Vector2i) -> void:
	var build_result := ChunkBuilder.build(_height_sampler, key.x, key.y)
	build_result["chunk_key"] = key
	call_deferred("_on_chunk_built", build_result)


func _on_chunk_built(build_result: Dictionary) -> void:
	var key: Vector2i = build_result["chunk_key"]
	_pending_chunks.erase(key)

	if _active_chunks.has(key):
		return

	var chunk := _create_chunk_node(build_result)
	_active_chunks[key] = chunk
	add_child(chunk)


func _create_chunk_node(build_result: Dictionary) -> Node3D:
	var chunk_root := Node3D.new()
	var key: Vector2i = build_result["chunk_key"]
	chunk_root.name = "Chunk_%d_%d" % [key.x, key.y]

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_result["mesh_arrays"])

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if sand_material != null:
		mesh_instance.material_override = sand_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	chunk_root.add_child(mesh_instance)

	var shape := mesh.create_trimesh_shape()
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape

	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1
	static_body.add_child(collision_shape)
	chunk_root.add_child(static_body)

	return chunk_root


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CHUNK_SIZE)),
		int(floor(world_pos.z / CHUNK_SIZE))
	)


func _chunk_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
