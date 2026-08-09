extends SceneTree

## Headless verification: run with
## godot --headless --script res://scripts/terrain/verify_terrain.gd

const ChunkBuilderScript = preload("res://scripts/terrain/chunk_builder.gd")
const DuneHeightScript = preload("res://scripts/terrain/dune_height.gd")
const LevelTerrainResolverScript = preload("res://scripts/game/level_terrain_resolver.gd")

const CHUNK_SIZE: float = 256.0
const EDGE_SAMPLE_COUNT := 8
const MAX_SEAM_ERROR := 0.01
const CREST_SCAN_STEP := 8.0
const CREST_OFFSET := 6.0
const MIN_CREST_DROPOFF := 2.0
const MAX_CREST_DROPOFF := 7.0
const SLOPE_SCAN_STEP := 4.0
const PLAY_ZONE_SIZE := 512.0
const MAX_SLOPE_DEGREES := 40.0
const SLOPE_PERCENTILE := 0.95
const MIN_MEDIAN_SLOPE_DEGREES := 10.0
const MAX_MEDIAN_SLOPE_DEGREES := 26.0
const PEAK_SCAN_STEP := 12.0
const MIN_PEAK_HEIGHT_SPREAD := 8.0
const START_PEAK_MID_DROP_MIN := 8.0
const START_PEAK_EDGE_DROP_MIN := 4.0


func _init() -> void:
	var LevelRunScript = preload("res://scripts/game/level_run.gd")
	LevelRunScript.ensure(42)

	var sampler: RefCounted = DuneHeightScript.new(42)
	sampler.set_run_origin(Vector2.ZERO)

	_verify_chunk_seams(sampler)
	_verify_chunk_builder(sampler)
	_verify_level_progression(sampler)
	_verify_start_peak(sampler)
	_verify_crest_sharpness(sampler)
	_verify_peak_height_variation(sampler)
	_verify_climbable_slopes(sampler)

	print("Terrain verification passed.")
	quit(0)


func _verify_chunk_seams(sampler: RefCounted) -> void:
	for cx in range(-1, 2):
		for cz in range(-1, 2):
			var x_boundary := (float(cx) + 1.0) * CHUNK_SIZE
			var z_boundary := (float(cz) + 1.0) * CHUNK_SIZE

			for i in EDGE_SAMPLE_COUNT + 1:
				var t := float(i) / float(EDGE_SAMPLE_COUNT)
				var z := lerpf(float(cz) * CHUNK_SIZE, float(cz + 1) * CHUNK_SIZE, t)
				var x := lerpf(float(cx) * CHUNK_SIZE, float(cx + 1) * CHUNK_SIZE, t)

				var height_x: float = sampler.sample_height(x_boundary, z)
				var height_z: float = sampler.sample_height(x, z_boundary)
				assert(absf(height_x - sampler.sample_height(x_boundary + 0.001, z)) < MAX_SEAM_ERROR)
				assert(absf(height_z - sampler.sample_height(x, z_boundary + 0.001)) < MAX_SEAM_ERROR)


func _verify_chunk_builder(sampler: RefCounted) -> void:
	# Near-home chunk uses base density.
	var build_near: Dictionary = ChunkBuilderScript.build(sampler, -2, 0)
	assert(build_near.has("mesh_arrays"))
	assert(not build_near.has("collision_heights"))
	assert(build_near.mesh_arrays.size() == Mesh.ARRAY_MAX)
	var near_verts: int = int(build_near.verts_per_side)
	assert(near_verts == ChunkBuilderScript.RENDER_VERTS_NEAR)
	var vertices_near: PackedVector3Array = build_near.mesh_arrays[Mesh.ARRAY_VERTEX]
	assert(vertices_near.size() == near_verts * near_verts)

	# Far-west chunk (~70%+ journey) uses denser mesh.
	var journey: float = LevelTerrainResolverScript.journey_length_m()
	var far_chunk_x := int(floor(-(journey * 0.78) / CHUNK_SIZE))
	var build: Dictionary = ChunkBuilderScript.build(sampler, far_chunk_x, 0)
	assert(int(build.verts_per_side) == ChunkBuilderScript.RENDER_VERTS_FAR)
	assert(int(build.verts_per_side) > near_verts)

	var vertices: PackedVector3Array = build.mesh_arrays[Mesh.ARRAY_VERTEX]
	assert(vertices.size() == int(build.verts_per_side) * int(build.verts_per_side))

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build.mesh_arrays)
	var shape: Shape3D = mesh.create_trimesh_shape()
	assert(shape is ConcavePolygonShape3D)

	var normals: PackedVector3Array = build.mesh_arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		assert(normal.y > 0.0, "Terrain face normals should point upward")

	var colors: PackedColorArray = build.mesh_arrays[Mesh.ARRAY_COLOR]
	assert(colors.size() == vertices.size(), "Terrain should include slope vertex colors")

	var min_luma := INF
	var max_luma := -INF
	for color in colors:
		var luma: float = color.r
		min_luma = minf(min_luma, luma)
		max_luma = maxf(max_luma, luma)
	assert(
		max_luma - min_luma >= 0.28,
		"Sun-shaded vertex colors should span at least 0.28 (got %.2f)" % [max_luma - min_luma]
	)

	# Mesh verts should stay close to analytical samples (hover uses the latter).
	var max_err := 0.0
	var step := maxi(vertices.size() / 200, 1)
	for i in range(0, vertices.size(), step):
		var v: Vector3 = vertices[i]
		var expected: float = sampler.sample_height(v.x, v.z)
		max_err = maxf(max_err, absf(v.y - expected))
	assert(max_err < 0.05, "Mesh vertices should match sampler (err %.3f)" % max_err)


func _verify_level_progression(sampler: RefCounted) -> void:
	# Outside start-peak radius; far sample deep into the long run.
	var near_x := -1200.0
	var far_x := -120000.0
	var spread_near := _height_spread(sampler, near_x, 80.0)
	var spread_far := _height_spread(sampler, far_x, 80.0)
	_fail_unless(
		spread_far > spread_near + 1.5,
		"Far west should have taller dune spread (near %.1f far %.1f)" % [spread_near, spread_far]
	)
	var p_near: Dictionary = LevelTerrainResolverScript.params_at_world_x(near_x, 0.0)
	var p_far: Dictionary = LevelTerrainResolverScript.params_at_world_x(far_x, 0.0)
	_fail_unless(
		float(p_far.amplitude) > float(p_near.amplitude) + 3.0,
		"Far-west amplitude should exceed near-home amplitude"
	)
	# Soft blend across first tower seam (no hard amplitude cliff).
	var before_tower := LevelTerrainResolverScript.params_at_world_x(-900.0, 0.0)
	var after_tower := LevelTerrainResolverScript.params_at_world_x(-1100.0, 0.0)
	_fail_unless(
		absf(float(after_tower.amplitude) - float(before_tower.amplitude)) < 2.5,
		"Amplitude should not jump hard across a tower X"
	)


func _height_spread(sampler: RefCounted, center_x: float, radius: float) -> float:
	var min_h := INF
	var max_h := -INF
	for i in 9:
		var t := float(i) / 8.0
		var x := center_x + lerpf(-radius, radius, t)
		var z := lerpf(-radius, radius, t)
		var h: float = sampler.sample_height(x, z)
		min_h = minf(min_h, h)
		max_h = maxf(max_h, h)
	return max_h - min_h


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _verify_start_peak(sampler: RefCounted) -> void:
	var origin: float = sampler.sample_height(0.0, 0.0)
	var bearings: Array[Vector2] = [
		Vector2(1.0, 0.0),
		Vector2(-1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.0, -1.0),
		Vector2(0.707, 0.707),
	]
	for dir: Vector2 in bearings:
		var mid: Vector2 = dir * 250.0
		var edge: Vector2 = dir * 500.0
		var beyond: Vector2 = dir * 650.0
		var h_mid: float = sampler.sample_height(mid.x, mid.y)
		var h_edge: float = sampler.sample_height(edge.x, edge.y)
		var h_beyond: float = sampler.sample_height(beyond.x, beyond.y)
		_fail_unless(
			origin > h_mid + START_PEAK_MID_DROP_MIN,
			"Start peak should stand above mid-slope (origin %.1f vs mid %.1f @ %s)" % [origin, h_mid, dir]
		)
		_fail_unless(
			h_mid > h_edge + START_PEAK_EDGE_DROP_MIN,
			"Start peak should fall off by 500 m (mid %.1f vs edge %.1f @ %s)" % [h_mid, h_edge, dir]
		)
		_fail_unless(
			absf(h_beyond) < 200.0,
			"Height beyond start peak should stay sane (%.1f)" % h_beyond
		)


func _verify_crest_sharpness(sampler: RefCounted) -> void:
	var peak_count := 0
	var total_dropoff := 0.0
	# Mid-late journey where intensity + profiles create launchable crests.
	var x0 := -80000
	var x1 := -79600
	var z0 := -200
	var z1 := 200

	for x in range(x0, x1, int(CREST_SCAN_STEP)):
		for z in range(z0, z1, int(CREST_SCAN_STEP)):
			var xf := float(x)
			var zf := float(z)
			var center: float = sampler.sample_height(xf, zf)
			var neighbors := [
				sampler.sample_height(xf - CREST_OFFSET, zf),
				sampler.sample_height(xf + CREST_OFFSET, zf),
				sampler.sample_height(xf, zf - CREST_OFFSET),
				sampler.sample_height(xf, zf + CREST_OFFSET),
			]

			if center <= neighbors[0] or center <= neighbors[1]:
				continue
			if center <= neighbors[2] or center <= neighbors[3]:
				continue

			var min_neighbor := minf(
				minf(neighbors[0], neighbors[1]),
				minf(neighbors[2], neighbors[3])
			)
			total_dropoff += center - min_neighbor
			peak_count += 1

	_fail_unless(peak_count > 0, "Should find local height maxima in test region")
	var average_dropoff := total_dropoff / float(peak_count)
	_fail_unless(
		average_dropoff >= MIN_CREST_DROPOFF,
		"Crest dropoff should be launchable (avg %.2f, need >= %.2f)" % [average_dropoff, MIN_CREST_DROPOFF]
	)
	_fail_unless(
		average_dropoff <= MAX_CREST_DROPOFF,
		"Crest dropoff should stay climbable (avg %.2f, need <= %.2f)" % [average_dropoff, MAX_CREST_DROPOFF]
	)


func _verify_peak_height_variation(sampler: RefCounted) -> void:
	var crest_heights: Array[float] = []
	var x0 := -90000
	var x1 := -89400
	var z0 := -256
	var z1 := 256

	for x in range(x0, x1, int(PEAK_SCAN_STEP)):
		for z in range(z0, z1, int(PEAK_SCAN_STEP)):
			var xf := float(x)
			var zf := float(z)
			var center: float = sampler.sample_height(xf, zf)
			var neighbors := [
				sampler.sample_height(xf - CREST_OFFSET, zf),
				sampler.sample_height(xf + CREST_OFFSET, zf),
				sampler.sample_height(xf, zf - CREST_OFFSET),
				sampler.sample_height(xf, zf + CREST_OFFSET),
			]

			if center <= neighbors[0] or center <= neighbors[1]:
				continue
			if center <= neighbors[2] or center <= neighbors[3]:
				continue

			crest_heights.append(center)

	_fail_unless(crest_heights.size() >= 8, "Should find enough crest samples for peak spread")
	crest_heights.sort()
	var low_quartile := crest_heights[crest_heights.size() / 4]
	var high_quartile := crest_heights[crest_heights.size() * 3 / 4]
	var spread := high_quartile - low_quartile
	var full_spread := crest_heights[crest_heights.size() - 1] - crest_heights[0]
	_fail_unless(
		spread >= MIN_PEAK_HEIGHT_SPREAD or full_spread >= MIN_PEAK_HEIGHT_SPREAD * 1.35,
		"Crest heights should vary (Q spread %.2f, full %.2f, need >= %.2f)" % [
			spread, full_spread, MIN_PEAK_HEIGHT_SPREAD
		]
	)


func _verify_climbable_slopes(sampler: RefCounted) -> void:
	var slope_angles: Array[float] = []
	var x0 := -80000
	var x1 := -79500
	var z0 := -256
	var z1 := 256

	for x in range(x0, x1, int(SLOPE_SCAN_STEP)):
		for z in range(z0, z1, int(SLOPE_SCAN_STEP)):
			var xf := float(x)
			var zf := float(z)
			var normal: Vector3 = sampler.sample_normal(xf, zf, 4.0)
			var slope_deg := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
			slope_angles.append(slope_deg)

	_fail_unless(not slope_angles.is_empty(), "Should sample slope angles in play zone")

	slope_angles.sort()
	var median := slope_angles[slope_angles.size() / 2]
	var percentile_index := mini(int(float(slope_angles.size()) * SLOPE_PERCENTILE), slope_angles.size() - 1)
	var max_slope := slope_angles[percentile_index]

	_fail_unless(max_slope <= MAX_SLOPE_DEGREES, "95th-percentile slope should be climbable (%.1f°, limit %.1f°)" % [max_slope, MAX_SLOPE_DEGREES])
	_fail_unless(
		median >= MIN_MEDIAN_SLOPE_DEGREES and median <= MAX_MEDIAN_SLOPE_DEGREES,
		"Median slope should be in playable band (%.1f°, want %.1f-%.1f°)" % [
			median, MIN_MEDIAN_SLOPE_DEGREES, MAX_MEDIAN_SLOPE_DEGREES
		]
	)
