class_name TerrainProbes
extends RefCounted

## Multi-direction terrain probe fan. Pure math + sampling callbacks — no nodes.

const BOARD_TAGS: Array[String] = ["corner", "nose", "tail", "center", "nose_corner"]
## Plane fit excludes nose_corner — same XZ as front corners; including them double-weights the nose.
const BOARD_PLANE_TAGS: Array[String] = ["corner", "nose", "tail", "center"]
const NOSE_TAGS: Array[String] = ["nose", "nose_corner"]
const AHEAD_TAGS: Array[String] = ["ahead_center", "ahead_left", "ahead_right"]


class ProbeSpec:
	var local_x: float = 0.0
	var local_z: float = 0.0
	var tag: String = ""

	func _init(x: float = 0.0, z: float = 0.0, probe_tag: String = "") -> void:
		local_x = x
		local_z = z
		tag = probe_tag


class ProbeSample:
	var tag: String = ""
	var local_offset := Vector3.ZERO
	var probe_world := Vector3.ZERO
	var ground_world := Vector3.ZERO
	var ground_y: float = NAN
	var normal := Vector3.UP
	var clearance: float = NAN
	var valid: bool = false


class SurfaceResult:
	var samples: Array[ProbeSample] = []
	var avg_normal := Vector3.UP
	var plane_normal := Vector3.UP
	var board_plane_normal := Vector3.UP
	var min_clearance: float = INF
	var avg_clearance: float = 0.0
	var nose_ground_y: float = NAN
	var tail_ground_y: float = NAN
	var center_ground_y: float = NAN


static func is_board_tag(tag: String) -> bool:
	return tag in BOARD_TAGS


static func is_board_plane_tag(tag: String) -> bool:
	return tag in BOARD_PLANE_TAGS


static func is_nose_tag(tag: String) -> bool:
	return tag in NOSE_TAGS


static func is_ahead_tag(tag: String) -> bool:
	return tag in AHEAD_TAGS


static func min_tagged_clearance(
	samples: Array[ProbeSample],
	fallback: float,
	tag_filter: Callable = Callable(),
	clearance_of: Callable = Callable()
) -> float:
	var min_clearance := fallback
	for sample in samples:
		if not sample.valid:
			continue
		if tag_filter.is_valid() and not bool(tag_filter.call(sample.tag)):
			continue
		elif not tag_filter.is_valid() and not is_board_tag(sample.tag):
			continue
		var clearance: float = (
			float(clearance_of.call(sample))
			if clearance_of.is_valid()
			else sample.clearance
		)
		min_clearance = minf(min_clearance, clearance)
	return min_clearance


static func clearance_spread(samples: Array[ProbeSample], tag_filter: Callable = Callable()) -> float:
	var min_clearance := INF
	var max_clearance := -INF
	for sample in samples:
		if not sample.valid:
			continue
		if tag_filter.is_valid() and not bool(tag_filter.call(sample.tag)):
			continue
		elif not tag_filter.is_valid() and not is_board_tag(sample.tag):
			continue
		min_clearance = minf(min_clearance, sample.clearance)
		max_clearance = maxf(max_clearance, sample.clearance)
	if min_clearance == INF:
		return 0.0
	return max_clearance - min_clearance


static func average_normals(normals: Array[Vector3], reference: Vector3 = Vector3.UP) -> Vector3:
	var ref := reference
	if ref.length_squared() < 0.0001:
		ref = Vector3.UP
	else:
		ref = ref.normalized()

	var sum := Vector3.ZERO
	var count := 0
	for normal in normals:
		if normal.length_squared() < 0.0001:
			continue
		var aligned := normal.normalized()
		if aligned.dot(ref) < 0.0:
			aligned = -aligned
		sum += aligned
		count += 1

	if count == 0 or sum.length_squared() < 0.0001:
		return Vector3.UP

	var avg := sum.normalized()
	if avg.dot(Vector3.UP) < 0.0:
		avg = -avg
	return avg


static func fit_plane_normal(points: Array[Vector3]) -> Vector3:
	if points.size() < 3:
		return Vector3.UP

	var centroid := Vector3.ZERO
	for point in points:
		centroid += point
	centroid /= float(points.size())

	var xx := 0.0
	var xy := 0.0
	var xz := 0.0
	var yy := 0.0
	var yz := 0.0
	var zz := 0.0
	for point in points:
		var r := point - centroid
		xx += r.x * r.x
		xy += r.x * r.y
		xz += r.x * r.z
		yy += r.y * r.y
		yz += r.y * r.z
		zz += r.z * r.z

	var det_x := yy * zz - yz * yz
	var det_y := xx * zz - xz * xz
	var det_z := xx * yy - xy * xy
	var normal := Vector3.ZERO
	if det_x >= det_y and det_x >= det_z:
		normal = Vector3(det_x, yz * xz - xy * zz, xy * yz - xz * yy)
	elif det_y >= det_z:
		normal = Vector3(yz * xz - xy * zz, det_y, xy * xz - yz * xx)
	else:
		normal = Vector3(xy * yz - xz * yy, xy * xz - yz * xx, det_z)

	if normal.length_squared() < 0.0001:
		return Vector3.UP
	if normal.dot(Vector3.UP) < 0.0:
		normal = -normal
	return normal.normalized()


static func build_surface(
	origin: Vector3,
	yaw: float,
	probe_bottom_y: float,
	specs: Array[ProbeSpec],
	sample_height: Callable,
	sample_normal: Callable,
	clamp_ground_y: Callable = Callable(),
	reference_normal: Vector3 = Vector3.UP
) -> SurfaceResult:
	var result := SurfaceResult.new()
	var yaw_basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	var normals: Array[Vector3] = []
	var ground_points: Array[Vector3] = []
	var board_points: Array[Vector3] = []
	var clearance_sum := 0.0
	var clearance_count := 0

	for spec in specs:
		var local := Vector3(spec.local_x, 0.0, spec.local_z)
		var world_offset: Vector3 = yaw_basis * local
		var probe_world := Vector3(
			origin.x + world_offset.x,
			origin.y + probe_bottom_y,
			origin.z + world_offset.z
		)
		var raw_y: float = sample_height.call(probe_world.x, probe_world.z)
		var sample := ProbeSample.new()
		sample.tag = spec.tag
		sample.local_offset = local
		sample.probe_world = probe_world

		if is_nan(raw_y):
			result.samples.append(sample)
			continue

		var ground_y: float = raw_y
		if clamp_ground_y.is_valid():
			ground_y = clamp_ground_y.call(raw_y)

		var ground_world := Vector3(probe_world.x, ground_y, probe_world.z)
		var clearance := probe_world.y - ground_y
		var normal: Vector3 = sample_normal.call(probe_world.x, probe_world.z)

		sample.ground_y = ground_y
		sample.ground_world = ground_world
		sample.normal = normal
		sample.clearance = clearance
		sample.valid = true
		result.samples.append(sample)

		normals.append(normal)
		ground_points.append(ground_world)
		if is_board_plane_tag(spec.tag):
			board_points.append(ground_world)
		result.min_clearance = minf(result.min_clearance, clearance)
		clearance_sum += clearance
		clearance_count += 1

		match spec.tag:
			"nose":
				result.nose_ground_y = ground_y
			"tail":
				result.tail_ground_y = ground_y
			"center":
				result.center_ground_y = ground_y

	result.avg_normal = average_normals(normals, reference_normal)
	result.plane_normal = fit_plane_normal(ground_points) if ground_points.size() >= 3 else result.avg_normal
	result.board_plane_normal = (
		fit_plane_normal(board_points)
		if board_points.size() >= 3
		else result.avg_normal
	)
	if result.min_clearance == INF:
		result.min_clearance = 0.0
	result.avg_clearance = clearance_sum / float(clearance_count) if clearance_count > 0 else 0.0
	return result


static func build_default_specs(
	board_half_extents: Vector3,
	board_half_length: float,
	forward_distances: PackedFloat32Array,
	lateral: float,
	velocity_lookahead: float,
	include_velocity_probe: bool,
	velocity_local_x: float,
	velocity_local_z: float
) -> Array[ProbeSpec]:
	var specs: Array[ProbeSpec] = []

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			specs.append(ProbeSpec.new(
				sx * board_half_extents.x,
				sz * board_half_extents.z,
				"corner"
			))

	specs.append(ProbeSpec.new(0.0, board_half_length, "nose"))
	specs.append(ProbeSpec.new(0.0, -board_half_length, "tail"))
	specs.append(ProbeSpec.new(0.0, 0.0, "center"))
	# Forward underside edges — catch thin front digging into rising faces.
	specs.append(ProbeSpec.new(-board_half_extents.x, board_half_length, "nose_corner"))
	specs.append(ProbeSpec.new(board_half_extents.x, board_half_length, "nose_corner"))

	for distance in forward_distances:
		specs.append(ProbeSpec.new(0.0, distance, "ahead_center"))
		specs.append(ProbeSpec.new(-lateral, distance, "ahead_left"))
		specs.append(ProbeSpec.new(lateral, distance, "ahead_right"))

	if include_velocity_probe and velocity_lookahead > 0.0:
		var vel_len := Vector2(velocity_local_x, velocity_local_z).length()
		if vel_len > 0.1:
			var scale := velocity_lookahead / vel_len
			specs.append(ProbeSpec.new(
				velocity_local_x * scale,
				velocity_local_z * scale,
				"velocity"
			))

	return specs
