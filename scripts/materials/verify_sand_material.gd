extends SceneTree

## Headless verification: run with
## godot --headless --script res://scripts/materials/verify_sand_material.gd

const SAND_PATH := "res://assets/materials/sand.tres"
const TEXTURE_128_PREFIX := "res://assets/materials/textures/Desert_Texture/128/"
const MARS_TINT := Color(1.15, 0.78, 0.58, 1)
const TINT_EPSILON := 0.02


func _init() -> void:
	var material: Material = load(SAND_PATH)
	_fail_unless(material != null, "Failed to load sand material: %s" % SAND_PATH)

	_fail_unless(
		material is StandardMaterial3D,
		"Sand material must be StandardMaterial3D (got %s). Close sand.tres in Godot and restore SandMaterial." % material.get_class()
	)

	var sand := material as StandardMaterial3D
	_fail_unless(
		sand.get_script() != null and sand is SandMaterial,
		"Sand material must use SandMaterial script (got %s)" % (sand.get_script().get_global_name() if sand.get_script() else "none")
	)

	_assert_texture_path(sand.albedo_texture, "xd0mda1_2K_Albedo.jpg")
	_assert_texture_path(sand.normal_texture, "xd0mda1_2K_Normal.jpg")
	_assert_texture_path(sand.roughness_texture, "xd0mda1_2K_Roughness.jpg")

	_fail_unless(sand.normal_enabled, "Normal map must be enabled on sand material")
	_fail_unless(
		sand.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
		"Sand texture_filter must be NEAREST (got %d)" % sand.texture_filter
	)

	var tint_err := sand.albedo_color.r - MARS_TINT.r
	tint_err = maxf(tint_err, absf(sand.albedo_color.g - MARS_TINT.g))
	tint_err = maxf(tint_err, absf(sand.albedo_color.b - MARS_TINT.b))
	_fail_unless(
		tint_err <= TINT_EPSILON,
		"Sand albedo_color should be Mars tint %s (got %s)" % [MARS_TINT, sand.albedo_color]
	)

	print("Sand material verification passed.")
	quit(0)


func _assert_texture_path(texture: Texture2D, filename: String) -> void:
	_fail_unless(texture != null, "Missing texture: %s" % filename)
	var path := texture.resource_path
	var expected := TEXTURE_128_PREFIX + filename
	_fail_unless(
		path == expected,
		"Texture %s must use 128px path (expected %s, got %s)" % [filename, expected, path]
	)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
