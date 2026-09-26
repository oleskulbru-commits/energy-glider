extends SceneTree

const SparkParticleVfxScript := preload("res://scripts/vfx/spark_particle_vfx.gd")
const DroneHitSparkVfxScript := preload("res://scripts/vfx/drone_hit_spark_vfx.gd")
const DroneDamageSparkVfxScript := preload("res://scripts/vfx/drone_damage_spark_vfx.gd")
const ExplosionSparkVfxScript := preload("res://scripts/vfx/explosion_spark_vfx.gd")
const DefaultPresetPath := "res://assets/vfx/explosions/presets/aerial_explode_1.tres"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var template := SparkParticleVfxScript.SPARK_PARTICLE_MATERIAL as ShaderMaterial
	_fail_unless(template != null, "spark_particle.tres should load as ShaderMaterial")

	var hit_mat := SparkParticleVfxScript.tinted_material(Color(1.0, 0.5, 0.1, 1.0), 5.0)
	_assert_look_parity(template, hit_mat, "Hit spark")

	var damage_mat := SparkParticleVfxScript.tinted_material(Color(2.0, 0.45, 0.08, 1.0), 4.5)
	_assert_look_parity(template, damage_mat, "Damage spark")

	var preset := ResourceLoader.load(DefaultPresetPath) as AerialExplosionPreset
	_fail_unless(preset != null, "Default explosion preset should load")
	var explosion_mat := SparkParticleVfxScript.tinted_material(
		preset.spark_color,
		preset.spark_glow_strength
	)
	_assert_look_parity(template, explosion_mat, "Explosion spark")

	var hit_wrapper := DroneHitSparkVfxScript.spawn(
		self,
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		Color(1.6, 0.21, 0.064, 1.0),
		4
	)
	await process_frame
	_verify_runtime_quad(hit_wrapper, "Hit burst")
	hit_wrapper.queue_free()

	var damage_parent := Node3D.new()
	root.add_child(damage_parent)
	var damage_sparks := DroneDamageSparkVfxScript.build_looping_sparks(
		damage_parent,
		Color(2.0, 0.45, 0.08, 1.0)
	)
	await process_frame
	_verify_runtime_quad(damage_sparks, "Damage loop")
	damage_parent.queue_free()

	var explosion_fx := ExplosionSparkVfxScript.spawn_from_preset(self, Vector3(2.0, 0.0, 0.0), preset)
	await process_frame
	_verify_runtime_quad(explosion_fx, "Explosion burst")
	explosion_fx.queue_free()

	print("Spark particle parity verification passed.")
	quit(0)


func _assert_look_parity(template: ShaderMaterial, material: ShaderMaterial, label: String) -> void:
	_fail_unless(
		material.get_shader_parameter("Base_Texture") == template.get_shader_parameter("Base_Texture"),
		"%s should match template Base_Texture" % label
	)
	_fail_unless(
		material.get_shader_parameter("Streak_Mask") == template.get_shader_parameter("Streak_Mask"),
		"%s should match template Streak_Mask" % label
	)


func _verify_runtime_quad(node: Node, label: String) -> void:
	var particles := node as GPUParticles3D
	if particles == null:
		particles = node.get_node_or_null("SparkBurst") as GPUParticles3D
	if particles == null:
		particles = node.get_node_or_null("ExplosionSparkBurst") as GPUParticles3D
	_fail_unless(particles != null, "%s should expose GPUParticles3D" % label)
	var quad := particles.draw_pass_1 as QuadMesh
	_fail_unless(quad != null, "%s should use QuadMesh draw pass" % label)
	var mat := quad.material as ShaderMaterial
	_fail_unless(mat != null, "%s should use ShaderMaterial" % label)
	var template := SparkParticleVfxScript.SPARK_PARTICLE_MATERIAL as ShaderMaterial
	_assert_look_parity(template, mat, label)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
