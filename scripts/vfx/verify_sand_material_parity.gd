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
	var impact := glider.get_node("ImpactDust") as CPUParticles3D
	var hover := glider.get_node("HoverDust/Stream") as CPUParticles3D
	for label_and_emitter in [
		["ImpactDust", impact],
		["HoverDust/Stream", hover],
	]:
		var label: String = label_and_emitter[0]
		var emitter: CPUParticles3D = label_and_emitter[1]
		_fail_unless(emitter != null, "Glider missing %s sand emitter" % label)
		var quad := emitter.mesh as QuadMesh
		_fail_unless(quad != null, "%s should use a QuadMesh" % label)
		_assert_material_parity(quad.material as StandardMaterial3D, label)
	glider.queue_free()

	if _failed:
		return
	print("Sand material parity verification passed.")
	quit(0)


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
