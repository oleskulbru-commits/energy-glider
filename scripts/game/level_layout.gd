class_name LevelLayout
extends RefCounted

const LevelTerrainSpecScript = preload("res://scripts/game/level_terrain_spec.gd")
const LevelTerrainCatalogScript = preload("res://scripts/game/level_terrain_catalog.gd")

## Westbound segment lengths between upgrade towers (level 1..N).
## Level 1 = home to first west tower; crossing tower N advances past that segment.
const SEGMENT_DISTANCES_M: Array[float] = [
	1000.0,
	2000.0,
	2500.0,
	2500.0,
	3000.0,
]


static func segment_count() -> int:
	return SEGMENT_DISTANCES_M.size()


## Cumulative -X offsets of west towers from run origin (not including home at 0).
static func tower_x_offsets_from_origin() -> Array[float]:
	var offsets: Array[float] = []
	var cumulative := 0.0
	for distance in SEGMENT_DISTANCES_M:
		cumulative += distance
		offsets.append(-cumulative)
	return offsets


## Hidden progression level from world X. Starts at 1; clamp at last defined level.
static func level_at_world_x(world_x: float, origin_x: float = 0.0) -> int:
	var offsets := tower_x_offsets_from_origin()
	if offsets.is_empty():
		return 1
	var relative_x := world_x - origin_x
	var level := 1
	for i in offsets.size():
		# Cleared destination tower for segment (i+1) when at or west of its X.
		if relative_x <= offsets[i]:
			level = i + 2
		else:
			break
	return mini(level, segment_count())


## Terrain authoring spec for a level index (band + profile). Null if unset.
static func terrain_spec_for_level(level: int) -> LevelTerrainSpecScript:
	return LevelTerrainCatalogScript.get_spec_for_level(level) as LevelTerrainSpecScript


## Relative X range for a level segment: Vector2(east_x, west_x), west is more negative.
static func segment_east_west_x(level: int) -> Vector2:
	var offsets := tower_x_offsets_from_origin()
	if offsets.is_empty():
		return Vector2(0.0, -1000.0)
	var clamped := clampi(level, 1, offsets.size())
	if clamped <= 1:
		return Vector2(0.0, offsets[0])
	return Vector2(offsets[clamped - 2], offsets[clamped - 1])
