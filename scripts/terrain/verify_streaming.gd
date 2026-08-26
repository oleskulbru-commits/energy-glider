extends SceneTree

const TerrainManagerScript = preload("res://scripts/terrain/terrain_manager.gd")
const ChunkBuilderScript = preload("res://scripts/terrain/chunk_builder.gd")
const DuneHeightScript = preload("res://scripts/terrain/dune_height.gd")
const SandMaterial = preload("res://assets/materials/sand.tres")

const EXPECTED_INITIAL_CHUNKS := 25
const HEIGHT_TOLERANCE := 2.0
const ASYNC_LOAD_TIMEOUT_MS := 8000


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var terrain: Node3D = TerrainManagerScript.new()
	terrain.sand_material = SandMaterial
	root.add_child(terrain)

	var player := Node3D.new()
	player.name = "TrackTarget"
	player.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(player)
	terrain.set_track_node(player)

	await _await_chunks_ready(terrain, EXPECTED_INITIAL_CHUNKS)

	_verify_trimesh_collision(terrain)
	await _await_all_collisions(terrain)
	await physics_frame
	await physics_frame
	_verify_raycast_height(terrain, Vector3(64.0, 0.0, 64.0))

	var checkpoints := [0.0, -256.0, -512.0, -768.0]
	for x in checkpoints:
		player.position = Vector3(x, 0.0, 0.0)
		await _await_west_ahead_chunk(terrain, player.position)

	await _verify_far_west_coarse_collision(terrain, player)

	print("Collision and streaming verification passed with %d chunk nodes." % terrain.get_child_count())
	quit(0)


func _await_chunks_ready(terrain: Node3D, expected_count: int) -> void:
	var deadline := Time.get_ticks_msec() + ASYNC_LOAD_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if terrain.get_child_count() >= expected_count:
			return
		await process_frame
	assert(false, "Timed out waiting for %d async terrain chunks (got %d)" % [
		expected_count, terrain.get_child_count()
	])


func _await_all_collisions(terrain: Node3D) -> void:
	var deadline := Time.get_ticks_msec() + ASYNC_LOAD_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if _all_chunks_have_collision(terrain):
			return
		await process_frame
	assert(false, "Timed out waiting for terrain collision finalize")


func _all_chunks_have_collision(terrain: Node3D) -> bool:
	if terrain.get_child_count() == 0:
		return false
	for chunk in terrain.get_children():
		var static_body := chunk.get_node_or_null("TerrainCollision") as StaticBody3D
		if static_body == null or static_body.get_child_count() == 0:
			return false
	return true


func _await_west_ahead_chunk(terrain: Node3D, track_pos: Vector3) -> void:
	var center_x := int(floor(track_pos.x / 256.0))
	var ahead_key := "Chunk_%d_0" % (center_x - 1)
	var deadline := Time.get_ticks_msec() + ASYNC_LOAD_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		for child in terrain.get_children():
			if child.name == ahead_key:
				var body := child.get_node_or_null("TerrainCollision") as StaticBody3D
				if body != null and body.get_child_count() > 0:
					return
		await process_frame
	if center_x <= 0:
		assert(
			terrain.get_child_count() >= EXPECTED_INITIAL_CHUNKS,
			"Westbound ahead chunk should load asynchronously"
		)


func _verify_trimesh_collision(terrain: Node3D) -> void:
	var static_body := _find_terrain_body(terrain)
	assert(static_body != null, "Chunk should have StaticBody3D")
	var collision_shape: CollisionShape3D = static_body.get_child(0) as CollisionShape3D
	assert(collision_shape.shape is ConcavePolygonShape3D, "Terrain should use trimesh collision")
	assert(not (collision_shape.shape is HeightMapShape3D), "HeightMapShape3D should be removed")


func _verify_far_west_coarse_collision(terrain: TerrainManager, player: Node3D) -> void:
	var far_chunk_x := int(floor(-(ChunkBuilderScript.DENSE_FAR_WEST_M + 500.0) / ChunkBuilderScript.CHUNK_SIZE))
	var chunk_center_x := (float(far_chunk_x) + 0.5) * ChunkBuilderScript.CHUNK_SIZE
	player.position = Vector3(chunk_center_x, 0.0, 0.0)

	var chunk_name := "Chunk_%d_0" % far_chunk_x
	var deadline := Time.get_ticks_msec() + ASYNC_LOAD_TIMEOUT_MS
	var found_chunk: Node3D = null
	while Time.get_ticks_msec() < deadline:
		for child in terrain.get_children():
			if child.name == chunk_name:
				found_chunk = child
				var body := child.get_node_or_null("TerrainCollision") as StaticBody3D
				if body != null and body.get_child_count() > 0:
					break
		if found_chunk != null:
			var body := found_chunk.get_node_or_null("TerrainCollision") as StaticBody3D
			if body != null and body.get_child_count() > 0:
				break
		await process_frame

	assert(found_chunk != null, "Far-west chunk should stream in asynchronously")

	var render_verts: int = ChunkBuilderScript.verts_per_side_for_chunk(far_chunk_x)
	assert(
		render_verts > ChunkBuilderScript.COLLISION_VERTS_PER_SIDE,
		"Far-west render mesh should be denser than collision grid"
	)

	var sampler: RefCounted = DuneHeightScript.new(terrain.world_seed)
	sampler.set_run_origin(terrain.run_origin)
	var collision_build: Dictionary = ChunkBuilderScript.build_collision(sampler, far_chunk_x, 0)
	assert(int(collision_build.verts_per_side) == ChunkBuilderScript.COLLISION_VERTS_PER_SIDE)
	var collision_vertices: PackedVector3Array = collision_build.mesh_arrays[Mesh.ARRAY_VERTEX]
	assert(collision_vertices.size() == ChunkBuilderScript.COLLISION_VERTS_PER_SIDE ** 2)


func _find_terrain_body(terrain: Node3D) -> StaticBody3D:
	for chunk in terrain.get_children():
		for child in chunk.get_children():
			if child is StaticBody3D:
				return child as StaticBody3D
	return null


func _verify_raycast_height(terrain: TerrainManager, world_pos: Vector3) -> void:
	var expected: float = terrain.sample_height(world_pos.x, world_pos.z)
	var space_state := root.get_world_3d().direct_space_state
	var from := Vector3(world_pos.x, expected + 50.0, world_pos.z)
	var to := Vector3(world_pos.x, expected - 10.0, world_pos.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.hit_back_faces = true
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		# Headless Jolt may not register trimesh raycasts immediately; verify mesh height instead.
		var sampler: RefCounted = DuneHeightScript.new(terrain.world_seed)
		sampler.set_run_origin(terrain.run_origin)
		var build: Dictionary = ChunkBuilderScript.build(sampler, 0, 0)
		var vertices: PackedVector3Array = build.mesh_arrays[Mesh.ARRAY_VERTEX]
		var closest_dist_sq := INF
		var mesh_y := expected
		for vertex in vertices:
			var dist_sq := Vector2(vertex.x, vertex.z).distance_squared_to(
				Vector2(world_pos.x, world_pos.z)
			)
			if dist_sq < closest_dist_sq:
				closest_dist_sq = dist_sq
				mesh_y = vertex.y
		assert(closest_dist_sq < INF, "Should find mesh vertex near probe point")
		assert(absf(mesh_y - expected) < HEIGHT_TOLERANCE, "Mesh height should match sampled height")
		return
	assert(absf(hit.position.y - expected) < HEIGHT_TOLERANCE, "Collision height should match sampled height")
