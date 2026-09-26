extends SceneTree

const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")
const HeavyBurstScene := preload("res://scenes/effects/sand_burst_heavy_gpu.tscn")
const GliderScene := preload("res://scenes/player/glider.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var material := SandParticleVfxScript.material_for_emitter()
	_assert_material_parity(material, "material_for_emitter")

	var burst_root: Node3D = HeavyBurstScene.instantiate() as Node3D
	root.add_child(burst_root)
	var burst := burst_root.get_node("SandBurst") as GPUParticles3D
	_fail_unless(burst != null, "Heavy burst scene should expose SandBurst GPUParticles3D")
	SandParticleVfxScript.configure_gpu_burst(burst)
	var gpu_mesh := burst.draw_pass_1 as QuadMesh
	_fail_unless(gpu_mesh != null, "Heavy burst draw pass should be a QuadMesh")
	_assert_material_parity(gpu_mesh.material as StandardMaterial3D, "configure_gpu_burst")
	burst_root.queue_free()

	var glider: RigidBody3D = GliderScene.instantiate() as RigidBody3D
	root.add_child(glider)
	await process_frame
	var impact := glider.get_node("ImpactDust") as GPUParticles3D
	var hover := glider.get_node("HoverDust/Stream") as GPUParticles3D
	_fail_unless(impact != null, "Glider missing ImpactDust GPUParticles3D")
	_fail_unless(hover != null, "Glider missing HoverDust/Stream GPUParticles3D")
	SandParticleVfxScript.configure_gpu_impact_dust(impact)
	SandParticleVfxScript.configure_gpu_hover_dust(hover)
	for label_and_emitter in [
		["ImpactDust", impact],
		["HoverDust/Stream", hover],
	]:
		var label: String = label_and_emitter[0]
		var emitter: GPUParticles3D = label_and_emitter[1]
		var quad := emitter.draw_pass_1 as QuadMesh
		_fail_unless(quad != null, "%s should use a QuadMesh draw pass" % label)
		_assert_material_parity(quad.material as StandardMaterial3D, label)
	_fail_unless(
		impact.process_material is ParticleProcessMaterial,
		"ImpactDust should use ParticleProcessMaterial"
	)
	_fail_unless(
		hover.process_material is ParticleProcessMaterial,
		"HoverDust should use ParticleProcessMaterial"
	)
	var hover_proc := hover.process_material as ParticleProcessMaterial
	_fail_unless(hover_proc.particle_flag_align_y, "Hover dust should align Y to velocity")
	_fail_unless(hover_proc.particle_flag_rotate_y, "Hover dust should rotate around Y")
	glider.queue_free()

	var trail_host := Node3D.new()
	root.add_child(trail_host)
	var trail := SandParticleVfxScript.create_missile_smoke_trail(
		trail_host,
		SandParticleVfxScript.material_for_rocket_trail(),
		SandParticleVfxScript.ROCKET_TRAIL_COLOR
	)
	_fail_unless(trail is GPUParticles3D, "Missile smoke trail should be GPUParticles3D")
	_fail_unless(trail.amount == 72, "Missile smoke trail should keep 72 particles")
	_fail_unless(
		trail.process_material is ParticleProcessMaterial,
		"Missile smoke trail should use ParticleProcessMaterial"
	)
	var trail_quad := trail.draw_pass_1 as QuadMesh
	_fail_unless(trail_quad != null, "Missile smoke trail should use a QuadMesh draw pass")
	_assert_material_parity(trail_quad.material as StandardMaterial3D, "missile smoke trail")
	trail_host.queue_free()

	var flame_host := Node3D.new()
	root.add_child(flame_host)
	var flame_trail := SandParticleVfxScript.create_debris_flame_trail(flame_host, 1.0)
	_fail_unless(flame_trail is GPUParticles3D, "Debris flame trail should be GPUParticles3D")
	_fail_unless(flame_trail.name == "FlameTrail", "Debris flame trail node should be named FlameTrail")
	_fail_unless(
		flame_trail.amount == SandParticleVfxScript.DEBRIS_FLAME_AMOUNT,
		"Debris flame trail should keep %d particles"
		% SandParticleVfxScript.DEBRIS_FLAME_AMOUNT
	)
	_fail_unless(
		flame_trail.process_material is ParticleProcessMaterial,
		"Debris flame trail should use ParticleProcessMaterial"
	)
	var flame_quad := flame_trail.draw_pass_1 as QuadMesh
	_fail_unless(flame_quad != null, "Debris flame trail should use a QuadMesh draw pass")
	_assert_flame_material(flame_quad.material as StandardMaterial3D)
	flame_host.queue_free()

	if _failed:
		return
	print("Sand material parity verification passed.")
	quit(0)


func _assert_flame_material(material: StandardMaterial3D) -> void:
	_fail_unless(material != null, "Debris flame trail should have a StandardMaterial3D")
	_fail_unless(
		material.albedo_texture != null
		and material.albedo_texture.resource_path.ends_with("fire_v1_vfx.png"),
		"Debris flame trail should use fire_v1_vfx texture"
	)
	_fail_unless(
		is_equal_approx(
			material.albedo_color.r,
			SandParticleVfxScript.MUZZLE_FLAME_MATERIAL_COLOR.r
		)
		and is_equal_approx(
			material.albedo_color.g,
			SandParticleVfxScript.MUZZLE_FLAME_MATERIAL_COLOR.g
		)
		and is_equal_approx(
			material.albedo_color.b,
			SandParticleVfxScript.MUZZLE_FLAME_MATERIAL_COLOR.b
		),
		"Debris flame trail should use boosted muzzle-tint material color"
	)
	_fail_unless(material.emission_enabled, "Debris flame trail material should enable emission")
	_fail_unless(material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Debris flame trail should be additive")
	_fail_unless(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Debris flame trail should be unshaded")
	_fail_unless(material.proximity_fade_enabled, "Debris flame trail should enable proximity fade")


func _assert_material_parity(material: StandardMaterial3D, label: String) -> void:
	_fail_unless(material != null, "%s should have a StandardMaterial3D" % label)
	_fail_unless(material.rim_enabled, "%s should enable rim lighting" % label)
	_fail_unless(
		is_equal_approx(material.rim, SandParticleVfxScript.RIM),
		"%s rim should match hover dust (got %.3f, expected %.3f)"
		% [label, material.rim, SandParticleVfxScript.RIM]
	)
	_fail_unless(
		is_equal_approx(material.rim_tint, SandParticleVfxScript.RIM_TINT),
		"%s rim tint should match hover dust (got %.3f, expected %.3f)"
		% [label, material.rim_tint, SandParticleVfxScript.RIM_TINT]
	)
	_fail_unless(material.rim_texture != null, "%s should assign rim texture" % label)
	_fail_unless(material.proximity_fade_enabled, "%s should enable proximity fade" % label)
	_fail_unless(
		is_equal_approx(
			material.proximity_fade_distance,
			SandParticleVfxScript.PROXIMITY_FADE_DISTANCE
		),
		"%s proximity fade distance should match hover dust (got %.3f, expected %.3f)"
		% [label, material.proximity_fade_distance, SandParticleVfxScript.PROXIMITY_FADE_DISTANCE]
	)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
	quit(1)
