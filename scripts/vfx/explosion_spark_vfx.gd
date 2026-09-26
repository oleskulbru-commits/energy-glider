class_name ExplosionSparkVfx
extends Node3D

## One-shot ember spark burst layered on aerial explosion impacts.

const DroneHitSparkVfxScript := preload("res://scripts/vfx/drone_hit_spark_vfx.gd")
const SparkParticleVfxScript := preload("res://scripts/vfx/spark_particle_vfx.gd")
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")

const LIFETIME_SEC := 0.35
const FREE_BUFFER_SEC := 0.12
const REFERENCE_WORLD_SCALE := 12.0


static func spawn_from_preset(
	tree: SceneTree,
	world_pos: Vector3,
	preset: AerialExplosionPreset,
	scale_mult: float = 1.0,
	spray_dir: Vector3 = Vector3.UP
) -> Node3D:
	if tree == null or preset == null or not preset.spawn_sparks or preset.spark_count <= 0:
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null

	var fx: Node3D = load("res://scripts/vfx/explosion_spark_vfx.gd").new()
	parent.add_child(fx)
	fx.global_position = world_pos
	fx._build_burst(preset, scale_mult, spray_dir)
	fx._schedule_cleanup()
	return fx


func _build_burst(
	preset: AerialExplosionPreset,
	scale_mult: float,
	spray_dir: Vector3
) -> void:
	var size_ratio := preset.world_scale * maxf(scale_mult, 0.01) / REFERENCE_WORLD_SCALE
	var emission_radius := 0.42 * maxf(size_ratio, 0.55)
	var spark_length := SparkParticleVfxScript.SPARK_LENGTH_M * maxf(size_ratio, 0.75) * 2.2
	var aabb_half := 4.0 * maxf(size_ratio, 0.75)

	var mat := SparkParticleVfxScript.tinted_material(preset.spark_color, preset.spark_glow_strength)

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = emission_radius
	var burst_dir := spray_dir
	if burst_dir.length_squared() < 0.0001:
		burst_dir = Vector3.UP
	else:
		burst_dir = burst_dir.normalized()
	proc.direction = burst_dir
	proc.spread = 118.0
	var velocity_scale := maxf(sqrt(size_ratio), 0.85)
	proc.initial_velocity_min = 6.0 * velocity_scale
	proc.initial_velocity_max = 18.0 * velocity_scale
	proc.gravity = Vector3(0.0, -5.5, 0.0)
	proc.damping_min = 0.6
	proc.damping_max = 1.2
	proc.scale_min = 0.65 * maxf(size_ratio, 0.7)
	proc.scale_max = 1.35 * maxf(size_ratio, 0.85)
	DroneHitSparkVfxScript.configure_spark_process(proc)

	var burst := GPUParticles3D.new()
	burst.name = "ExplosionSparkBurst"
	burst.emitting = false
	burst.amount = preset.spark_count
	burst.lifetime = LIFETIME_SEC
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.randomness = 0.72
	burst.visibility_aabb = AABB(
		Vector3(-aabb_half, -aabb_half, -aabb_half),
		Vector3(aabb_half * 2.0, aabb_half * 2.0, aabb_half * 2.0)
	)
	burst.local_coords = false
	burst.process_material = proc
	burst.amount_ratio = 1.0
	burst.draw_pass_1 = SparkParticleVfxScript.make_spark_quad(mat, spark_length)
	add_child(burst)
	burst.restart()
	burst.emitting = true


func _schedule_cleanup() -> void:
	var timer := get_tree().create_timer(LIFETIME_SEC + FREE_BUFFER_SEC)
	timer.timeout.connect(queue_free)
