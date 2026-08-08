extends SceneTree

## Headless: godot --headless --path . --script res://scripts/game/verify_level_terrain.gd

const LevelTerrainCatalogTestsScript = preload("res://scripts/game/level_terrain_catalog_tests.gd")


func _init() -> void:
	var tests = LevelTerrainCatalogTestsScript.new()
	var error: String = tests.run()
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	print("Level terrain catalog verification passed.")
	quit(0)
