extends SceneTree

const GliderBoostVfxScript = preload("res://scripts/player/glider_boost_vfx.gd")
const GliderThrusterVfxScript = preload("res://scripts/player/glider_thruster_vfx.gd")
const GliderVfxFadeEnvelopeScript = preload("res://scripts/player/glider_vfx_fade.gd")
const GliderSkinScene = preload("res://scenes/player/the_glider_skin.tscn")

const BOOST_VFX_PATH := "Model/GliderRoot/GliderBoard/ThrusterSocket/BoostVfxPivot/BoostVfx"
const THRUSTER_VFX_PATH := "Model/GliderRoot/GliderBoard/ThrusterSocket/ThrusterVfxPivot/ThrusterVfx"
const THRUSTER_ORB_PATH := (
	"Model/GliderRoot/GliderBoard/ThrusterSocket/ThrusterVfxPivot/ThrusterVfx/OrbMesh2"
)
const THRUSTER_TORUS_PATH := (
	"Model/GliderRoot/GliderBoard/ThrusterSocket/Thruster_Torus"
)
const PHASE_OFF := GliderBoostVfxScript.Phase.OFF
const PHASE_START := GliderBoostVfxScript.Phase.START
const PHASE_LOOP := GliderBoostVfxScript.Phase.LOOP
const PHASE_END := GliderBoostVfxScript.Phase.END


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _init() -> void:
	call_deferred("_run_tests")


func _await_fade_in(vfx: GliderBoostVfxScript) -> void:
	var deadline := Time.get_ticks_msec() + int((GliderVfxFadeEnvelopeScript.DEFAULT_FADE_IN + 0.05) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if vfx.get_presentation() > 0.95:
			return
	_fail_unless(
		vfx.get_presentation() > 0.95,
		"Boost presentation should reach full strength after fade-in (got %.3f)"
		% vfx.get_presentation()
	)


func _await_fade_out(vfx: GliderBoostVfxScript) -> void:
	var deadline := Time.get_ticks_msec() + int((GliderVfxFadeEnvelopeScript.DEFAULT_FADE_OUT + 0.05) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if vfx.get_presentation() <= GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD:
			return
	_fail_unless(
		vfx.get_presentation() <= GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD,
		"Boost presentation should fade out before hiding (got %.3f)"
		% vfx.get_presentation()
	)


func _assert_cylinder_full_presentation(vfx: GliderBoostVfxScript, material: StandardMaterial3D) -> void:
	var target := vfx.get_presentation()
	var base_energy := vfx.get_cylinder_base_emission_energy()
	var base_alpha := vfx.get_cylinder_base_albedo_alpha()
	if material.emission_enabled and base_energy > 0.0:
		var presentation := material.emission_energy_multiplier / base_energy
		_fail_unless(
			absf(presentation - target) < 0.08,
			"Active boost cylinder should scale scene emission to presentation (got %.3f, target %.3f)"
			% [presentation, target]
		)
	elif base_alpha > 0.0:
		var presentation := material.albedo_color.a / base_alpha
		_fail_unless(
			absf(presentation - target) < 0.08,
			"Active boost cylinder should scale scene alpha to presentation (got %.3f, target %.3f)"
			% [presentation, target]
		)


func _assert_idle_orb(thruster_vfx: GliderThrusterVfxScript, orb: MeshInstance3D) -> void:
	_fail_unless(orb.visible, "Orb should stay visible at idle")
	var presentation := thruster_vfx.get_orb_presentation()
	_fail_unless(
		presentation > 0.45 and presentation < 0.55,
		"Idle orb should emit at half strength (got %.3f)" % presentation
	)
	var orb_material := thruster_vfx.get_orb_material_override()
	_fail_unless(orb_material != null, "Idle orb should have a material override")
	_fail_unless(
		orb_material.emission.r > 0.9 and orb_material.emission.b < 0.05,
		"Idle orb emission should be straight orange (emission=%s)" % orb_material.emission
	)
	_fail_unless(
		absf(orb.scale.x - thruster_vfx.get_orb_scene_scale()) < 0.02,
		"Idle orb should keep scene scale (got %.3f, expected %.3f)"
		% [orb.scale.x, thruster_vfx.get_orb_scene_scale()]
	)


func _assert_boost_lights_active(vfx: GliderBoostVfxScript, thruster_vfx: GliderThrusterVfxScript) -> void:
	var omni := vfx.get_omni_light()
	var base_energy := vfx.get_base_omni_energy()
	var thruster_base := thruster_vfx.get_base_omni_energy()
	var presentation := vfx.get_presentation()
	_fail_unless(omni != null, "Boost should have omni light")
	_fail_unless(base_energy > 0.0, "Boost omni should define a scene base energy")
	_fail_unless(omni.visible, "Boost omni should be visible when active")
	_fail_unless(
		absf(omni.light_energy - base_energy * presentation) < 0.08,
		"Boost omni should scale with presentation (got %.3f at p=%.3f, base=%.3f)"
		% [omni.light_energy, presentation, base_energy]
	)
	var thruster_omni := thruster_vfx.get_omni_light()
	_fail_unless(
		omni.light_energy > thruster_base * presentation * 0.5,
		"Boost omni should exceed thruster half-tier energy (got %.3f)" % omni.light_energy
	)
	_fail_unless(
		not thruster_omni.visible,
		"Thruster omni should stay off while boost is active"
	)


func _assert_boost_lights_hidden(vfx: GliderBoostVfxScript) -> void:
	var omni := vfx.get_omni_light()
	_fail_unless(omni != null, "Boost should have omni light")
	_fail_unless(not omni.visible, "Boost omni should hide when OFF"	)


func _assert_torus_matches_orb(thruster_vfx: GliderThrusterVfxScript, orb: MeshInstance3D) -> void:
	var torus := thruster_vfx.get_torus()
	_fail_unless(torus != null, "Thruster should resolve Thruster_Torus")
	_fail_unless(torus.visible, "Torus should stay visible with the orb")
	var orb_material := thruster_vfx.get_orb_material_override()
	_fail_unless(orb_material != null, "Orb should have a material override for torus sync")
	var torus_material := torus.material as StandardMaterial3D
	_fail_unless(torus_material != null, "Torus should have a scene material")
	var orb_base := thruster_vfx.get_orb_base_emission_energy()
	var torus_base := thruster_vfx.get_torus_base_emission_energy()
	_fail_unless(orb_base > 0.0 and torus_base > 0.0, "Scene orb/torus materials should define emission energy")
	var orb_presentation := orb_material.emission_energy_multiplier / orb_base
	var torus_presentation := torus_material.emission_energy_multiplier / torus_base
	_fail_unless(
		absf(orb_presentation - torus_presentation) < 0.08,
		"Torus brightness should track orb presentation (orb=%.3f, torus=%.3f)"
		% [orb_presentation, torus_presentation]
	)


func _run_tests() -> void:
	await process_frame

	var skin: Node3D = GliderSkinScene.instantiate()
	root.add_child(skin)

	var boost_node := skin.get_node_or_null(BOOST_VFX_PATH)
	_fail_unless(boost_node != null, "BoostVfx should live under BoostVfxPivot on ThrusterSocket")

	var vfx := boost_node as GliderBoostVfxScript
	_fail_unless(vfx != null, "BoostVfx should use GliderBoostVfx script")

	await process_frame
	await process_frame

	_fail_unless(
		vfx.get_start_mesh_count() == GliderBoostVfxScript.START_COUNT,
		"Expected %d start meshes, got %d"
		% [GliderBoostVfxScript.START_COUNT, vfx.get_start_mesh_count()]
	)
	_fail_unless(
		vfx.get_loop_mesh_count() == GliderBoostVfxScript.LOOP_COUNT,
		"Expected %d loop meshes, got %d"
		% [GliderBoostVfxScript.LOOP_COUNT, vfx.get_loop_mesh_count()]
	)
	_fail_unless(
		vfx.get_end_mesh_count() == GliderBoostVfxScript.END_COUNT,
		"Expected %d end meshes, got %d"
		% [GliderBoostVfxScript.END_COUNT, vfx.get_end_mesh_count()]
	)

	var mesh := vfx.get_target_mesh()
	_fail_unless(mesh != null, "Boost VFX should create a cylinder MeshInstance3D")

	var orb := vfx.get_orb_mesh()
	_fail_unless(orb != null, "Boost VFX should resolve the shared thruster orb")
	var thruster_orb := skin.get_node_or_null(THRUSTER_ORB_PATH) as MeshInstance3D
	_fail_unless(
		orb == thruster_orb,
		"Boost VFX should borrow ThrusterVfx OrbMesh2"
	)
	var thruster_vfx := skin.get_node_or_null(THRUSTER_VFX_PATH) as GliderThrusterVfxScript
	_fail_unless(thruster_vfx != null, "ThrusterVfx should exist beside BoostVfx")

	await process_frame
	_assert_idle_orb(thruster_vfx, orb)
	_assert_torus_matches_orb(thruster_vfx, orb)
	_fail_unless(not mesh.visible, "Cylinder should hide while idle")

	_fail_unless(vfx.get_phase() == PHASE_OFF, "Boost VFX should start OFF")
	_assert_boost_lights_hidden(vfx)
	_fail_unless(
		not thruster_vfx.get_omni_light().visible,
		"Thruster omni should stay off while boost is idle"
	)

	vfx.debug_simulate_boost_only()
	await process_frame
	_fail_unless(
		vfx.get_phase() == PHASE_START,
		"Shift-only boost should enter START without forward held"
	)
	_fail_unless(mesh.visible, "Cylinder should show for Shift-only boost")
	_fail_unless(orb.visible, "Shared orb should show for Shift-only boost")
	await _await_fade_in(vfx)
	vfx.debug_simulate_boost_release()
	await process_frame
	for i in 120:
		await process_frame
		if vfx.get_phase() == PHASE_OFF:
			break
	await _await_fade_out(vfx)

	vfx.debug_simulate_boost_press()
	await process_frame
	_fail_unless(vfx.get_phase() == PHASE_START, "Boost press should enter START phase")
	_fail_unless(
		thruster_vfx != null,
		"ThrusterVfx should exist beside BoostVfx"
	)
	_fail_unless(
		not thruster_vfx.is_active(),
		"Thruster should stay inactive during boost START"
	)
	_fail_unless(
		vfx.get_presentation() < 1.0,
		"First frame after boost press should not snap to full presentation"
	)
	_fail_unless(mesh.visible, "Cylinder should be visible during START fade-in")
	_fail_unless(orb.visible, "Shared orb should stay visible during boost START")

	await _await_fade_in(vfx)
	_assert_boost_lights_active(vfx, thruster_vfx)
	_assert_torus_matches_orb(thruster_vfx, orb)

	var material := vfx.get_material_override()
	_fail_unless(material != null, "Boost VFX should assign material_override")
	_fail_unless(
		material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD,
		"Boost VFX material should use additive blend"
	)
	_assert_cylinder_full_presentation(vfx, material)

	var first_texture := material.albedo_texture
	_fail_unless(first_texture != null, "Boost VFX should assign an initial texture")

	var saw_texture_change := false
	for i in 30:
		await process_frame
		var current_material := vfx.get_material_override()
		if current_material != null and current_material.albedo_texture != first_texture:
			saw_texture_change = true
			break

	_fail_unless(saw_texture_change, "START sequence should advance texture frames")

	for i in 120:
		await process_frame
		if vfx.get_phase() == PHASE_LOOP:
			break

	_fail_unless(vfx.get_phase() == PHASE_LOOP, "Held boost should enter LOOP after START")

	var loop_texture := vfx.get_material_override().albedo_texture
	for i in 120:
		await process_frame
		var current_material := vfx.get_material_override()
		if current_material != null and current_material.albedo_texture != loop_texture:
			break

	_fail_unless(
		vfx.get_material_override().albedo_texture != loop_texture,
		"LOOP sequence should keep advancing textures"
	)

	vfx.debug_simulate_boost_release()
	await process_frame
	_fail_unless(vfx.get_phase() == PHASE_END, "Boost release should enter END phase")

	for i in 120:
		await process_frame
		if vfx.get_phase() == PHASE_OFF:
			break

	_fail_unless(vfx.get_phase() == PHASE_OFF, "END sequence should return to OFF")
	await _await_fade_out(vfx)
	_assert_boost_lights_hidden(vfx)
	_fail_unless(not mesh.visible, "Cylinder should hide when OFF")
	await process_frame
	_assert_idle_orb(thruster_vfx, orb)

	vfx.debug_simulate_boost_press()
	await process_frame
	await _await_fade_in(vfx)
	_fail_unless(
		vfx.get_phase() == PHASE_START or vfx.get_phase() == PHASE_LOOP,
		"Boost should be active before forward-release test"
	)
	vfx.debug_simulate_forward_release()
	await process_frame
	_fail_unless(
		vfx.get_phase() != PHASE_OFF,
		"Forward release should not stop boost VFX while Shift is held"
	)
	_fail_unless(mesh.visible, "Cylinder should stay visible after forward release while boosting")
	_fail_unless(orb.visible, "Orb should stay visible after forward release while boosting")
	vfx.debug_simulate_boost_release()
	await process_frame
	for i in 120:
		await process_frame
		if vfx.get_phase() == PHASE_OFF:
			break
	await _await_fade_out(vfx)
	await process_frame
	_assert_idle_orb(thruster_vfx, orb)

	skin.queue_free()
	print("Glider boost VFX verification passed.")
	quit(0)
