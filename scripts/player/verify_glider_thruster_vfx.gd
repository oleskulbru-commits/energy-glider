extends SceneTree

const GliderThrusterVfxScript = preload("res://scripts/player/glider_thruster_vfx.gd")
const GliderVfxFadeEnvelopeScript = preload("res://scripts/player/glider_vfx_fade.gd")
const GliderSkinScene = preload("res://scenes/player/the_glider_skin.tscn")

const THRUSTER_VFX_PATH := (
	"Model/GliderRoot/GliderBoard/ThrusterSocket/ThrusterVfxPivot/ThrusterVfx"
)
const THRUSTER_TORUS_PATH := (
	"Model/GliderRoot/GliderBoard/ThrusterSocket/Thruster_Torus"
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


func _assert_warm_orange_emission(material: StandardMaterial3D, label: String) -> void:
	_fail_unless(material != null, "%s should have a material override" % label)
	var tint := material.emission
	if tint.r + tint.g + tint.b < 0.01:
		tint = material.albedo_color
	_fail_unless(
		tint.r > tint.b and tint.b < 0.1,
		"%s should use warm orange emission (emission=%s, albedo=%s)"
		% [label, material.emission, material.albedo_color]
	)
	_fail_unless(
		material.emission_enabled or material.albedo_color.a > 0.05,
		"%s should emit visibly (energy=%.3f, alpha=%.3f)"
		% [label, material.emission_energy_multiplier, material.albedo_color.a]
	)


func _assert_cylinder_full_presentation(vfx: GliderThrusterVfxScript, material: StandardMaterial3D) -> void:
	var target := vfx.get_presentation()
	var base_energy := vfx.get_cylinder_base_emission_energy()
	var base_alpha := vfx.get_cylinder_base_albedo_alpha()
	if material.emission_enabled and base_energy > 0.0:
		var presentation := material.emission_energy_multiplier / base_energy
		_fail_unless(
			absf(presentation - target) < 0.08,
			"Active thruster cylinder should scale scene emission to presentation (got %.3f, target %.3f)"
			% [presentation, target]
		)
	elif base_alpha > 0.0:
		var presentation := material.albedo_color.a / base_alpha
		_fail_unless(
			absf(presentation - target) < 0.08,
			"Active thruster cylinder should scale scene alpha to presentation (got %.3f, target %.3f)"
			% [presentation, target]
		)


func _assert_idle_orb(vfx: GliderThrusterVfxScript, orb: MeshInstance3D) -> void:
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
		absf(orb.scale.x - vfx.get_orb_scene_scale()) < 0.02,
		"Idle orb should keep scene scale (got %.3f, expected %.3f)"
		% [orb.scale.x, vfx.get_orb_scene_scale()]
	)
	var omni := vfx.get_omni_light()
	_fail_unless(omni != null, "Thruster should have OmniLight3D")
	_fail_unless(not omni.visible, "Idle omni should stay off")
	_assert_torus_sync(vfx, orb)


func _assert_torus_sync(vfx: GliderThrusterVfxScript, orb: MeshInstance3D) -> void:
	var torus := vfx.get_torus()
	_fail_unless(torus != null, "Thruster should resolve Thruster_Torus")
	_fail_unless(torus.visible, "Torus should stay visible with the orb")
	var orb_material := vfx.get_orb_material_override()
	_fail_unless(orb_material != null, "Orb should have a material override for torus sync")
	var torus_material := torus.material as StandardMaterial3D
	_fail_unless(torus_material != null, "Torus should have a scene material")
	var orb_base := vfx.get_orb_base_emission_energy()
	var torus_base := vfx.get_torus_base_emission_energy()
	_fail_unless(orb_base > 0.0 and torus_base > 0.0, "Scene orb/torus materials should define emission energy")
	var orb_presentation := orb_material.emission_energy_multiplier / orb_base
	var torus_presentation := torus_material.emission_energy_multiplier / torus_base
	_fail_unless(
		absf(orb_presentation - torus_presentation) < 0.08,
		"Torus brightness should track orb presentation (orb=%.3f, torus=%.3f)"
		% [orb_presentation, torus_presentation]
	)


func _assert_torus_scale_unchanged(torus: CSGShape3D, baseline_scale: Vector3) -> void:
	_fail_unless(
		torus.scale.is_equal_approx(baseline_scale),
		"Torus scale should stay fixed (got %s, expected %s)" % [torus.scale, baseline_scale]
	)


func _assert_active_lights(vfx: GliderThrusterVfxScript) -> void:
	var omni := vfx.get_omni_light()
	var base_energy := vfx.get_base_omni_energy()
	var presentation := vfx.get_presentation() * 0.5
	_fail_unless(omni != null, "Thruster should have OmniLight3D")
	_fail_unless(base_energy > 0.0, "Thruster omni should define a scene base energy")
	_fail_unless(omni.visible, "Active thruster omni should be visible")
	_fail_unless(
		absf(omni.light_energy - base_energy * presentation) < 0.08,
		"Thruster omni should be half tier at thrust (got %.3f at p=%.3f, base=%.3f)"
		% [omni.light_energy, presentation, base_energy]
	)


func _assert_lights_hidden(vfx: GliderThrusterVfxScript) -> void:
	var omni := vfx.get_omni_light()
	_fail_unless(not omni.visible, "Thruster omni should hide when inactive")


func _run_tests() -> void:
	await process_frame

	var skin: Node3D = GliderSkinScene.instantiate()
	root.add_child(skin)

	var thruster_node := skin.get_node_or_null(THRUSTER_VFX_PATH)
	_fail_unless(thruster_node != null, "ThrusterVfx should live under ThrusterVfxPivot on ThrusterSocket")

	var vfx := thruster_node as GliderThrusterVfxScript
	_fail_unless(vfx != null, "ThrusterVfx should use GliderThrusterVfx script")

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

	_fail_unless(not vfx.is_active(), "Thruster VFX should start inactive")
	_fail_unless(not cylinder.visible, "Cylinder should hide while inactive")
	_assert_idle_orb(vfx, orb)

	var torus := vfx.get_torus()
	_fail_unless(torus != null, "Thruster should resolve Thruster_Torus")
	var torus_baseline_scale := torus.scale

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
		vfx.get_presentation() > 0.08 and vfx.get_presentation() < 0.9,
		"Thruster fade-in should reach mid presentation before full (got %.3f)"
		% vfx.get_presentation()
	)

	await _await_fade_in(vfx)

	_fail_unless(
		absf(orb.scale.x - vfx.get_orb_scene_scale()) < 0.02,
		"Active orb should keep scene scale (got %.3f, expected %.3f)"
		% [orb.scale.x, vfx.get_orb_scene_scale()]
	)

	var material := vfx.get_material_override()
	_fail_unless(material != null, "Thruster VFX should assign material_override")
	_fail_unless(
		material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD,
		"Thruster VFX material should use additive blend"
	)
	_assert_cylinder_full_presentation(vfx, material)

	var orb_material := vfx.get_orb_material_override()
	_assert_warm_orange_emission(orb_material, "Active thruster orb")

	var first_texture := material.albedo_texture
	_fail_unless(first_texture != null, "Thruster VFX should assign an initial texture")
	_assert_active_lights(vfx)
	_assert_torus_sync(vfx, orb)
	_assert_torus_scale_unchanged(torus, torus_baseline_scale)

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
	_assert_idle_orb(vfx, orb)

	vfx.debug_simulate_forward_press()
	vfx.debug_simulate_brake_release()
	await process_frame
	_fail_unless(vfx.is_active(), "Forward without brake should reactivate thruster VFX")
	await _await_fade_in(vfx)

	vfx.debug_simulate_boost_active(true)
	await process_frame
	_fail_unless(not vfx.is_active(), "Boost should hide cruise thruster even if forward held")
	_assert_lights_hidden(vfx)
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
	_assert_idle_orb(vfx, orb)

	skin.queue_free()
	print("Glider thruster VFX verification passed.")
	quit(0)
