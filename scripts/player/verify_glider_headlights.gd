extends SceneTree

const GliderHeadlightsScript = preload("res://scripts/player/glider_headlights.gd")
const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const DayNightCycleScript = preload("res://scripts/world/day_night_cycle.gd")
const GliderSkinScene = preload("res://scenes/player/the_glider_skin.tscn")
const GliderScene = preload("res://scenes/player/glider.tscn")

const HEADLIGHTS_PATH := "Model/GliderRoot/GliderBoard/Glider_Headlights"
const SPOTLIGHT_PATH := "Model/GliderRoot/GliderBoard/Glider_Headlights/SpotLight3D"
const GLIDER_SPOTLIGHT_PATH := (
	"Visual/GliderSkin/Model/GliderRoot/GliderBoard/Glider_Headlights/SpotLight3D"
)


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _init() -> void:
	call_deferred("_run_tests")


func _spawn_day_night() -> DayNightCycle:
	var cycle: DayNightCycle = DayNightCycleScript.new()
	cycle.name = "VerifyDayNight"
	cycle.day_phase_sec = 180.0
	cycle.night_phase_sec = 180.0
	root.add_child(cycle)
	return cycle


func _find_headlight_mesh(headlights_node: Node) -> MeshInstance3D:
	for child in headlights_node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
		var nested := _find_headlight_mesh(child)
		if nested != null:
			return nested
	return null


func _surface_index_by_name(mesh: MeshInstance3D, surface_name: String) -> int:
	if mesh.mesh == null:
		return -1
	var array_mesh := mesh.mesh as ArrayMesh
	if array_mesh == null:
		return -1
	for surface_index in array_mesh.get_surface_count():
		if array_mesh.surface_get_name(surface_index) == surface_name:
			return surface_index
	return -1


func _surface_material(mesh: MeshInstance3D, surface_index: int) -> StandardMaterial3D:
	var override := mesh.get_surface_override_material(surface_index)
	if override is StandardMaterial3D:
		return override as StandardMaterial3D
	if mesh.mesh == null:
		return null
	var source := mesh.mesh.surface_get_material(surface_index)
	if source is StandardMaterial3D:
		return source as StandardMaterial3D
	return null


func _assert_surface_emission(
	headlights_node: Node,
	night_blend: float,
	lens_should_emit: bool
) -> void:
	var headlight_mesh := _find_headlight_mesh(headlights_node)
	_fail_unless(headlight_mesh != null, "Glider_Headlights should include a MeshInstance3D")

	var lens_index := _surface_index_by_name(headlight_mesh, "Headlights")
	if lens_index < 0:
		lens_index = 1
	var housing_index := _surface_index_by_name(headlight_mesh, "Glider_mat")
	if housing_index < 0:
		housing_index = 0

	var lens_material := _surface_material(headlight_mesh, lens_index)
	_fail_unless(lens_material != null, "Headlights surface should have a StandardMaterial3D")
	_fail_unless(
		lens_material.emission_enabled == lens_should_emit,
		"Headlights surface emission_enabled should be %s at night blend %.3f"
		% [lens_should_emit, night_blend]
	)
	if lens_should_emit:
		_fail_unless(
			lens_material.emission_energy_multiplier >= 3.0 * night_blend - 0.05,
			"Headlights surface should glow at night (energy %.3f, night %.3f)"
			% [lens_material.emission_energy_multiplier, night_blend]
		)

	var housing_material := _surface_material(headlight_mesh, housing_index)
	_fail_unless(housing_material != null, "Glider_mat surface should have a StandardMaterial3D")
	_fail_unless(
		not housing_material.emission_enabled,
		"Glider_mat housing should not emit (emission_enabled=%s, energy %.3f)"
		% [housing_material.emission_enabled, housing_material.emission_energy_multiplier]
	)
	_fail_unless(
		headlight_mesh.get_surface_override_material(housing_index) == null,
		"Housing surface should not receive a runtime emission override"
	)


func _run_tests() -> void:
	await process_frame

	var cycle := _spawn_day_night()

	var skin: Node3D = GliderSkinScene.instantiate()
	root.add_child(skin)

	var headlights_node := skin.get_node_or_null(HEADLIGHTS_PATH)
	_fail_unless(headlights_node != null, "Glider_Headlights should live under GliderBoard")

	var headlights := headlights_node as GliderHeadlightsScript
	_fail_unless(headlights != null, "Glider_Headlights should use GliderHeadlights script")

	var spot := skin.get_node_or_null(SPOTLIGHT_PATH) as SpotLight3D
	_fail_unless(spot != null, "SpotLight3D should live under Glider_Headlights")

	await process_frame
	await process_frame

	cycle.time_normalized = cycle.get_day_fraction() * 0.5
	cycle.call("_apply_time_visuals")
	await process_frame

	var day_night := cycle.get_night_blend()
	_fail_unless(
		not spot.visible,
		"Headlight should be hidden during day (night blend %.3f, energy %.3f)"
		% [day_night, spot.light_energy]
	)
	_fail_unless(
		spot.light_energy < 0.05,
		"Headlight energy should fade out during day (got %.3f)" % spot.light_energy
	)
	_fail_unless(
		headlights.get_emission_energy() < 0.05,
		"Headlight emission should be off during day (got %.3f)"
		% headlights.get_emission_energy()
	)
	_assert_surface_emission(headlights_node, day_night, false)

	cycle.time_normalized = cycle.get_day_fraction() + 0.25
	cycle.call("_apply_time_visuals")
	await process_frame

	var night_blend := cycle.get_night_blend()
	_fail_unless(night_blend > 0.9, "Night sample should have high night blend (got %.3f)" % night_blend)
	_fail_unless(spot.visible, "Headlight should be visible at night")
	_fail_unless(
		absf(spot.light_energy - 3.5 * night_blend) < 0.05,
		"Headlight energy should scale with night blend (got %.3f, expected %.3f)"
		% [spot.light_energy, 3.5 * night_blend]
	)
	_fail_unless(
		headlights.get_emission_energy() >= 3.0 * night_blend - 0.05,
		"Headlight emission should reach at least 3 at full night (got %.3f, night %.3f)"
		% [headlights.get_emission_energy(), night_blend]
	)
	_assert_surface_emission(headlights_node, night_blend, true)

	skin.queue_free()

	var glider := GliderScene.instantiate() as GliderPlayerScript
	_fail_unless(glider != null, "Glider scene should root on GliderPlayer")
	root.add_child(glider)
	await process_frame
	await process_frame

	var glider_spot := glider.get_node_or_null(GLIDER_SPOTLIGHT_PATH) as SpotLight3D
	_fail_unless(glider_spot != null, "Glider scene should include a headlight spotlight")

	var glider_headlights := glider.get_node_or_null(
		"Visual/GliderSkin/Model/GliderRoot/GliderBoard/Glider_Headlights"
	) as GliderHeadlightsScript
	_fail_unless(glider_headlights != null, "Glider scene should include GliderHeadlights")

	cycle.time_normalized = cycle.get_day_fraction() + 0.25
	cycle.call("_apply_time_visuals")
	await process_frame
	_fail_unless(glider_spot.visible, "Headlight should be visible at night on glider scene")

	glider.end_run("verify")
	await process_frame

	_fail_unless(not glider_spot.visible, "Headlight should hide when run has ended")
	_fail_unless(
		glider_spot.light_energy < 0.05,
		"Headlight energy should be zero when run has ended (got %.3f)" % glider_spot.light_energy
	)
	_fail_unless(
		glider_headlights.get_emission_energy() < 0.05,
		"Headlight emission should be off when run has ended (got %.3f)"
		% glider_headlights.get_emission_energy()
	)

	glider.queue_free()
	cycle.queue_free()
	print("Glider headlight verification passed.")
	quit(0)
