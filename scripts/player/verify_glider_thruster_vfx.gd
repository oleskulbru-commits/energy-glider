extends SceneTree

const GliderThrusterVfxScript = preload("res://scripts/player/glider_thruster_vfx.gd")
const GliderVfxFadeEnvelopeScript = preload("res://scripts/player/glider_vfx_fade.gd")
const GliderSkinScene = preload("res://scenes/player/the_glider_skin.tscn")

const THRUSTER_VFX_PATH := (
	"Model/GliderRoot/GliderBoard/ThrusterSocket/ThrusterVfxPivot/ThrusterVfx"
)
const THRUSTER_OMNI_PATH := (
	"Model/GliderRoot/GliderBoard/ThrusterSocket/ThrusterVfxPivot/ThrusterVfx/OmniLight3D"
)


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _init() -> void:
	call_deferred("_run_tests")


func _await_fade_in(vfx: GliderThrusterVfxScript) -> void:
	var deadline := Time.get_ticks_msec() + int((GliderVfxFadeEnvelopeScript.DEFAULT_FADE_IN + 0.05) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if vfx.get_presentation() > 0.95:
			return
	_fail_unless(
		vfx.get_presentation() > 0.95,
		"Thruster presentation should reach full strength after fade-in (got %.3f)"
		% vfx.get_presentation()
	)


func _await_fade_out(vfx: GliderThrusterVfxScript) -> void:
	var deadline := Time.get_ticks_msec() + int((GliderVfxFadeEnvelopeScript.DEFAULT_FADE_OUT + 0.05) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if vfx.get_presentation() <= GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD:
			return
	_fail_unless(
		vfx.get_presentation() <= GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD,
		"Thruster presentation should fade out before hiding (got %.3f)"
		% vfx.get_presentation()
	)


func _assert_idle_orb(
	vfx: GliderThrusterVfxScript,
	orb: MeshInstance3D,
	omni: OmniLight3D,
	full_omni_energy: float = -1.0
) -> void:
	_fail_unless(orb.visible, "Orb should stay visible at idle")
	var presentation := vfx.get_orb_presentation()
	_fail_unless(
		presentation > 0.45 and presentation < 0.55,
		"Idle orb should emit at half strength (got %.3f)" % presentation
	)
	var orb_material := vfx.get_orb_material_override()
	_fail_unless(orb_material != null, "Idle orb should have a material override")
	_fail_unless(
		orb_material.emission.r > 0.9 and orb_material.emission.b < 0.05,
		"Idle orb emission should be straight orange (emission=%s)" % orb_material.emission
	)
	_fail_unless(
		orb_material.emission_texture == null,
		"Idle orb should not use flipbook emission texture"
	)
	_fail_unless(
		vfx.get_orb_scale_factor() > 0.45 and vfx.get_orb_scale_factor() < 0.55,
		"Idle orb should render at half size (scale %.3f)" % vfx.get_orb_scale_factor()
	)
	_fail_unless(omni != null, "Thruster VFX should include an OmniLight3D")
	_fail_unless(omni.visible, "Idle thruster omni should stay visible")
	_fail_unless(
		omni.light_color.r > omni.light_color.b,
		"Idle thruster omni should be orange (color=%s)" % omni.light_color
	)
	_fail_unless(
		vfx.get_omni_light_color().r > vfx.get_omni_light_color().b,
		"Idle thruster omni color should match orange idle orb"
	)
	if full_omni_energy > 0.0:
		_fail_unless(
			absf(omni.light_energy - full_omni_energy * 0.5) < 0.06,
			"Idle thruster omni should be half of full thrust energy (got %.3f, full %.3f)"
			% [omni.light_energy, full_omni_energy]
		)
	else:
		_fail_unless(
			omni.light_energy > 0.45 and omni.light_energy < 0.55,
			"Idle thruster omni should emit at half base energy (got %.3f)" % omni.light_energy
		)


func _run_tests() -> void:
	await process_frame

	var skin: Node3D = GliderSkinScene.instantiate()
	root.add_child(skin)

	var thruster_node := skin.get_node_or_null(THRUSTER_VFX_PATH)
	_fail_unless(thruster_node != null, "ThrusterVfx should live under ThrusterVfxPivot on ThrusterSocket")

	var vfx := thruster_node as GliderThrusterVfxScript
	_fail_unless(vfx != null, "ThrusterVfx should use GliderThrusterVfx script")

	vfx.force_loop_preview = false

	await process_frame
	await process_frame

	_fail_unless(
		vfx.get_loop_mesh_count() == GliderThrusterVfxScript.LOOP_COUNT,
		"Expected %d thruster loop meshes, got %d"
		% [GliderThrusterVfxScript.LOOP_COUNT, vfx.get_loop_mesh_count()]
	)

	var cylinder := vfx.get_target_mesh()
	_fail_unless(cylinder != null, "Thruster VFX should create a cylinder MeshInstance3D")

	var orb := vfx.get_orb_mesh()
	_fail_unless(orb != null, "Thruster VFX should create an orb MeshInstance3D")

	var omni := skin.get_node_or_null(THRUSTER_OMNI_PATH) as OmniLight3D
	_fail_unless(omni != null, "Thruster VFX should include an OmniLight3D")

	_fail_unless(not vfx.is_active(), "Thruster VFX should start inactive")
	_fail_unless(not cylinder.visible, "Cylinder should hide while inactive")
	_assert_idle_orb(vfx, orb, omni)

	vfx.debug_simulate_forward_press()
	await process_frame
	_fail_unless(vfx.is_active(), "Forward press should activate thruster VFX")
	_fail_unless(
		vfx.get_presentation() < 1.0,
		"First frame after forward press should not snap to full presentation"
	)
	_fail_unless(cylinder.visible, "Cylinder should show during fade-in")
	_fail_unless(orb.visible, "Orb should show during fade-in")

	for i in 3:
		await process_frame
	_fail_unless(
		vfx.get_presentation() > 0.1 and vfx.get_presentation() < 0.9,
		"Thruster fade-in should reach mid presentation before full (got %.3f)"
		% vfx.get_presentation()
	)
	_fail_unless(omni.visible, "Thruster omni should stay visible during fade-in")
	_fail_unless(
		omni.light_color.r > 0.05 and omni.light_color.b > 0.05,
		"Mid fade-in omni should crossfade color (color=%s)" % omni.light_color
	)
	_fail_unless(
		not (omni.light_color.r > 0.9 and omni.light_color.b < 0.05),
		"Mid fade-in omni should not remain pure orange (color=%s)" % omni.light_color
	)
	_fail_unless(
		not (omni.light_color.b > omni.light_color.r and omni.light_color.b > 0.8),
		"Mid fade-in omni should not snap to full blue (color=%s)" % omni.light_color
	)
	_fail_unless(
		omni.light_energy > 0.5 and omni.light_energy < 1.0,
		"Mid fade-in omni energy should sit between idle and full (got %.3f)" % omni.light_energy
	)

	await _await_fade_in(vfx)

	var full_omni_energy := omni.light_energy

	_fail_unless(
		vfx.get_orb_scale_factor() > 0.95,
		"Active orb should render at full size (scale %.3f)" % vfx.get_orb_scale_factor()
	)
	_fail_unless(omni.visible, "Active thruster omni should be visible after fade-in")
	_fail_unless(
		omni.light_color.b > omni.light_color.r,
		"Active thruster omni should use blue thrust color (color=%s)" % omni.light_color
	)
	_fail_unless(
		absf(omni.light_energy - full_omni_energy) < 0.06,
		"Active thruster omni should reach full thrust energy (got %.3f, expected %.3f)"
		% [omni.light_energy, full_omni_energy]
	)

	var material := vfx.get_material_override()
	_fail_unless(material != null, "Thruster VFX should assign material_override")
	_fail_unless(
		material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD,
		"Thruster VFX material should use additive blend"
	)

	var first_texture := material.albedo_texture
	_fail_unless(first_texture != null, "Thruster VFX should assign an initial texture")

	var saw_texture_change := false
	for i in 30:
		await process_frame
		var current_material := vfx.get_material_override()
		if current_material != null and current_material.albedo_texture != first_texture:
			saw_texture_change = true
			break

	_fail_unless(saw_texture_change, "Thruster loop should advance texture frames while active")

	vfx.debug_simulate_brake()
	await process_frame
	_fail_unless(not vfx.is_active(), "Brake should deactivate thruster VFX")
	await _await_fade_out(vfx)
	_fail_unless(not cylinder.visible, "Cylinder should hide on brake")
	_assert_idle_orb(vfx, orb, omni, full_omni_energy)

	vfx.debug_simulate_forward_press()
	vfx.debug_simulate_brake_release()
	await process_frame
	_fail_unless(vfx.is_active(), "Forward without brake should reactivate thruster VFX")
	await _await_fade_in(vfx)

	vfx.debug_simulate_boost_active(true)
	await process_frame
	_fail_unless(not vfx.is_active(), "Boost should hide cruise thruster even if forward held")
	await _await_fade_out(vfx)
	_fail_unless(not cylinder.visible, "Cylinder should hide during boost")
	_fail_unless(orb.visible, "Orb should stay visible during boost (boost owns full emission)")

	vfx.debug_simulate_boost_active(false)
	await process_frame
	_fail_unless(vfx.is_active(), "Releasing boost should restore thruster while forward held")
	await _await_fade_in(vfx)

	vfx.debug_simulate_forward_release()
	await process_frame
	_fail_unless(not vfx.is_active(), "Forward release should deactivate thruster VFX")
	await _await_fade_out(vfx)
	_assert_idle_orb(vfx, orb, omni, full_omni_energy)

	skin.queue_free()
	print("Glider thruster VFX verification passed.")
	quit(0)
