class_name ChunkBuilder
extends RefCounted

const CHUNK_SIZE := 256.0
## Near home (~4 m spacing). Farther west uses denser grids so mesh tracks sharp dunes.
const RENDER_VERTS_NEAR := 65
const RENDER_VERTS_MID := 97
const RENDER_VERTS_FAR := 129
const RENDER_VERTS_PER_SIDE := RENDER_VERTS_NEAR
const SUN_DIRECTION := Vector3(0.485, 0.824, 0.291)
const LevelRunScript = preload("res://scripts/game/level_run.gd")


## Vertex density by journey progress (west is more negative).
## Uses run length so a ~175 km map does not force FAR density too early.
static func verts_per_side_for_chunk(chunk_x: int) -> int:
	var journey := maxf(LevelRunScript.journey_length_m(), 1.0)
	var center_x := (float(chunk_x) + 0.5) * CHUNK_SIZE
	var west_m := maxf(-center_x, 0.0)
	var t := clampf(west_m / journey, 0.0, 1.0)
	if t < 0.35:
		return RENDER_VERTS_NEAR
	if t < 0.70:
		return RENDER_VERTS_MID
	return RENDER_VERTS_FAR


static func build(
	height_sampler: DuneHeight,
	chunk_x: int,
	chunk_z: int
) -> Dictionary:
	var verts := verts_per_side_for_chunk(chunk_x)
	var render_data := _build_mesh(height_sampler, chunk_x, chunk_z, verts)
	return {
		"mesh_arrays": render_data.mesh_arrays,
		"world_origin_x": float(chunk_x) * CHUNK_SIZE,
		"world_origin_z": float(chunk_z) * CHUNK_SIZE,
		"min_height": render_data.min_height,
		"verts_per_side": verts,
	}


static func _build_mesh(
	height_sampler: DuneHeight,
	chunk_x: int,
	chunk_z: int,
	verts_per_side: int
) -> Dictionary:
	var x0 := float(chunk_x) * CHUNK_SIZE
	var z0 := float(chunk_z) * CHUNK_SIZE
	var step := CHUNK_SIZE / float(verts_per_side - 1)

	var vertex_count := verts_per_side * verts_per_side
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(vertex_count)
	uvs.resize(vertex_count)

	var min_height := INF
	var max_height := -INF

	for iz in verts_per_side:
		for ix in verts_per_side:
			var index := iz * verts_per_side + ix
			var world_x := x0 + float(ix) * step
			var world_z := z0 + float(iz) * step
			var height := height_sampler.sample_height(world_x, world_z)
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)
			vertices[index] = Vector3(world_x, height, world_z)
			uvs[index] = Vector2(world_x / 8.0, world_z / 8.0)

	var indices := _build_indices(verts_per_side)
	var normals := _compute_normals_from_indices(vertices, indices)
	var colors := _compute_slope_colors(normals, vertices, min_height, max_height)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	return {
		"mesh_arrays": arrays,
		"min_height": min_height,
	}


static func _compute_normals_from_indices(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.ZERO)

	for i in range(0, indices.size(), 3):
		var a: int = indices[i]
		var b: int = indices[i + 1]
		var c: int = indices[i + 2]
		var face_normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
		normals[a] += face_normal
		normals[b] += face_normal
		normals[c] += face_normal

	for i in normals.size():
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	return normals


static func _compute_slope_colors(
	normals: PackedVector3Array,
	vertices: PackedVector3Array,
	min_height: float,
	max_height: float
) -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(normals.size())
	var height_range := maxf(max_height - min_height, 1.0)

	for i in normals.size():
		var normal := normals[i]
		var facing := clampf(normal.y, 0.0, 1.0)
		var shade := lerpf(0.38, 1.25, facing)
		var ndotl := clampf(normal.dot(SUN_DIRECTION), 0.0, 1.0)
		var sun_shade := lerpf(0.32, 1.35, ndotl)
		shade *= sun_shade
		var height_t := clampf((vertices[i].y - min_height) / height_range, 0.0, 1.0)
		var cool := lerpf(0.94, 1.04, height_t)
		colors[i] = Color(shade * cool, shade * cool, shade * cool * 1.03)

	return colors


static func _build_indices(verts_per_side: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for iz in verts_per_side - 1:
		for ix in verts_per_side - 1:
			var top_left := iz * verts_per_side + ix
			var top_right := top_left + 1
			var bottom_left := (iz + 1) * verts_per_side + ix
			var bottom_right := bottom_left + 1
			indices.append(top_left)
			indices.append(bottom_left)
			indices.append(top_right)
			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(bottom_right)
	return indices
