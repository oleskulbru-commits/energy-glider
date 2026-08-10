class_name LevelLayout
extends RefCounted

const LevelRunScript = preload("res://scripts/game/level_run.gd")
const LevelTerrainSpecScript = preload("res://scripts/game/level_terrain_spec.gd")
const LevelTerrainCatalogScript = preload("res://scripts/game/level_terrain_catalog.gd")


static func segment_count() -> int:
	return LevelRunScript.segment_count()


static func segment_distances_m() -> Array[float]:
	return LevelRunScript.segment_distances_m()


## Cumulative -X offsets of west towers from run origin (not including home at 0).
static func tower_x_offsets_from_origin() -> Array[float]:
	return LevelRunScript.tower_x_offsets_from_origin()


## Hidden progression level from world X. Starts at 1; clamp at last defined level.
static func level_at_world_x(world_x: float, origin_x: float = 0.0) -> int:
	return LevelRunScript.level_at_world_x(world_x, origin_x)


## Terrain authoring spec for a level index (band + profile). Null if unset.
static func terrain_spec_for_level(level: int) -> LevelTerrainSpecScript:
	var segment = LevelRunScript.segment_at_index(level)
	if segment == null:
		return LevelTerrainCatalogScript.get_spec_for_level(level) as LevelTerrainSpecScript
	return LevelTerrainSpecScript.new(
		segment.index,
		segment.band_id,
		segment.profile_id,
		"Generated run segment"
	) as LevelTerrainSpecScript


## Relative X range for a level segment: Vector2(east_x, west_x), west is more negative.
static func segment_east_west_x(level: int) -> Vector2:
	return LevelRunScript.segment_east_west_x(level)
