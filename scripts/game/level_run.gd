class_name LevelRun
extends RefCounted

## Active westbound run for this session (generated once from world_seed).

const LevelRunGeneratorScript = preload("res://scripts/game/level_run_generator.gd")
const LevelRunSegmentScript = preload("res://scripts/game/level_run_segment.gd")

static var _seed: int = -1
static var _segments: Array = []
static var _distances: Array[float] = []
static var _tower_offsets: Array[float] = []
static var _journey_m: float = 0.0


static func ensure(world_seed: int) -> void:
	if _seed == world_seed and not _segments.is_empty():
		return
	generate(world_seed)


static func generate(world_seed: int) -> void:
	_seed = world_seed
	_segments = LevelRunGeneratorScript.generate(world_seed)
	_distances.clear()
	_tower_offsets.clear()
	var cumulative := 0.0
	for segment in _segments:
		_distances.append(segment.length_m)
		cumulative += segment.length_m
		_tower_offsets.append(-cumulative)
	_journey_m = cumulative


static func is_ready() -> bool:
	return not _segments.is_empty()


static func world_seed() -> int:
	return _seed


static func segment_count() -> int:
	_ensure_fallback()
	return _segments.size()


static func segment_distances_m() -> Array[float]:
	_ensure_fallback()
	return _distances


static func tower_x_offsets_from_origin() -> Array[float]:
	_ensure_fallback()
	return _tower_offsets


static func journey_length_m() -> float:
	_ensure_fallback()
	return maxf(_journey_m, 1.0)


static func segment_at_index(index: int) -> LevelRunSegmentScript:
	_ensure_fallback()
	var clamped := clampi(index, 1, _segments.size())
	return _segments[clamped - 1] as LevelRunSegmentScript


## Segment containing this westbound distance (0 at origin, positive west).
static func segment_at_west_m(west_m: float) -> LevelRunSegmentScript:
	_ensure_fallback()
	var remaining := maxf(west_m, 0.0)
	for i in _segments.size():
		var segment: LevelRunSegmentScript = _segments[i]
		if remaining <= segment.length_m or i == _segments.size() - 1:
			return segment
		remaining -= segment.length_m
	return _segments[_segments.size() - 1] as LevelRunSegmentScript


static func segment_east_west_x(level: int) -> Vector2:
	_ensure_fallback()
	var offsets := _tower_offsets
	if offsets.is_empty():
		return Vector2(0.0, -1000.0)
	var clamped := clampi(level, 1, offsets.size())
	if clamped <= 1:
		return Vector2(0.0, offsets[0])
	return Vector2(offsets[clamped - 2], offsets[clamped - 1])


static func level_at_world_x(world_x: float, origin_x: float = 0.0) -> int:
	_ensure_fallback()
	var offsets := _tower_offsets
	if offsets.is_empty():
		return 1
	var relative_x := world_x - origin_x
	var level := 1
	for i in offsets.size():
		if relative_x <= offsets[i]:
			level = i + 2
		else:
			break
	return mini(level, segment_count())


static func _ensure_fallback() -> void:
	if not _segments.is_empty():
		return
	generate(42)
