class_name LevelTerrainCatalogTests
extends RefCounted

## Shared assertions for the level terrain catalog (used by headless verify).

const LevelTerrainCatalogScript = preload("res://scripts/game/level_terrain_catalog.gd")

const EXPECTED_ATOMIC := 72
const EXPECTED_HYBRID := 16
const EXPECTED_TOTAL := EXPECTED_ATOMIC + EXPECTED_HYBRID


## Returns empty string on success, otherwise an error message.
func run() -> String:
	if LevelTerrainCatalogScript.all_bands().size() != 5:
		return "Expected 5 difficulty bands"
	if LevelTerrainCatalogScript.profile_count() != EXPECTED_TOTAL:
		return "Expected %d profiles, got %d" % [
			EXPECTED_TOTAL, LevelTerrainCatalogScript.profile_count()
		]

	var hybrid_count := 0
	for profile in LevelTerrainCatalogScript.all_profiles():
		if not profile.is_hybrid():
			continue
		hybrid_count += 1
		for part_id in profile.composed_of:
			var part = LevelTerrainCatalogScript.get_profile(part_id)
			if part == null:
				return "Hybrid %s missing part %s" % [profile.id, part_id]
			if part.is_hybrid():
				return "Hybrid %s should compose atomics only" % profile.id
	if hybrid_count != EXPECTED_HYBRID:
		return "Expected %d hybrids" % EXPECTED_HYBRID

	var expected := {
		1: ["TUTORIAL", "tutorial_flow"],
		2: ["EASY", "learning_desert"],
		3: ["MEDIUM", "knife_medium"],
		4: ["HARD", "gauntlet_hard"],
		5: ["HARD", "endurance_hard"],
	}
	for level in expected.keys():
		var spec = LevelTerrainCatalogScript.get_spec_for_level(level)
		if spec == null:
			return "Missing terrain spec for level %d" % level
		if spec.band_id != expected[level][0]:
			return "Level %d band mismatch" % level
		if spec.profile_id != expected[level][1]:
			return "Level %d profile mismatch" % level
		if LevelTerrainCatalogScript.get_band(spec.band_id) == null:
			return "Unknown band on level %d" % level
		if LevelTerrainCatalogScript.get_profile(spec.profile_id) == null:
			return "Unknown profile on level %d" % level
		var described: String = spec.describe()
		var prefix := "Level %d, %s (%s)" % [level, spec.band_id, spec.profile_id]
		if not described.begins_with(prefix):
			return "describe() format wrong: %s" % described

	if LevelTerrainCatalogScript.list_profiles_in_category("crest").size() < 8:
		return "Crest category should list atomic crest profiles"
	return ""
