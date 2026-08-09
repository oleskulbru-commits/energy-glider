extends SceneTree

## Headless: godot --headless --path . --script res://scripts/game/verify_level_terrain.gd

const LevelTerrainCatalogTestsScript = preload("res://scripts/game/level_terrain_catalog_tests.gd")
const LevelRunTestsScript = preload("res://scripts/game/level_run_tests.gd")


func _init() -> void:
	var catalog_tests = LevelTerrainCatalogTestsScript.new()
	var catalog_error: String = catalog_tests.run()
	if not catalog_error.is_empty():
		push_error(catalog_error)
		quit(1)
		return

	var run_tests = LevelRunTestsScript.new()
	var run_error: String = run_tests.run()
	if not run_error.is_empty():
		push_error(run_error)
		quit(1)
		return

	print("Level terrain catalog + run generator verification passed.")
	quit(0)
