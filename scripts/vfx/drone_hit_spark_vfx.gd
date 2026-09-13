class_name DroneHitSparkVfx
extends Node3D

## One-shot emissive sparks on drone hits.

const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const SparkParticleVfxScript := preload("res://scripts/vfx/spark_particle_vfx.gd")

const LIFETIME_SEC := 0.3
const FREE_BUFFER_SEC := 0.1
const DEFAULT_GLOW_STRENGTH := 5.0
const SPARK_TEX_ASPECT := SparkParticleVfxScript.SPARK_TEX_ASPECT
const SPARK_LENGTH_M := SparkParticleVfxScript.SPARK_LENGTH_M


static func make_spark_quad(
	material: ShaderMaterial,
	length_m: float = SPARK_LENGTH_M
) -> QuadMesh:
	return SparkParticleVfxScript.make_spark_quad(material, length_m)


static func configure_spark_process(proc: ParticleProcessMaterial) -> void:
	SparkParticleVfxScript.configure_spark_process(proc)


static func spawn(
	tree: SceneTree,
	hit_pos: Vector3,
	hit_dir: Vector3,
	spark_color: Color,
	count: int,
	glow_strength: float = DEFAULT_GLOW_STRENGTH,
	spark_length_m: float = SPARK_LENGTH_M
) -> Node3D:
	if tree == null or count <= 0:
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null

	var wrapper = load("res://scripts/vfx/drone_hit_spark_vfx.gd").new()
	parent.add_child(wrapper)
	wrapper.global_position = hit_pos
	wrapper._build_burst(hit_dir, spark_color, count, glow_strength, spark_length_m)
	wrapper._schedule_cleanup()
	return wrapper


func _build_burst(
	hit_dir: Vector3,
	spark_color: Color,
	count: int,
	glow_strength: float,
	spark_length_m: float = SPARK_LENGTH_M
) -> void:
	var mat := SparkParticleVfxScript.tinted_material(spark_color, glow_strength)

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.12
	var spray_dir := hit_dir
	if spray_dir.length_squared() < 0.0001:
		spray_dir = Vector3(0.0, 1.0, 0.0)
	else:
		spray_dir = spray_dir.normalized()
	proc.direction = spray_dir
	proc.spread = 52.0
	proc.initial_velocity_min = 2.0
	proc.initial_velocity_max = 6.0
	proc.gravity = Vector3(0.0, -3.0, 0.0)
	proc.damping_min = 0.8
	proc.damping_max = 1.4
	proc.scale_min = 0.5
	proc.scale_max = 1.0
	configure_spark_process(proc)

	var burst := GPUParticles3D.new()
	burst.name = "SparkBurst"
	burst.emitting = false
	burst.amount = count
	burst.lifetime = LIFETIME_SEC
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.randomness = 0.65
	burst.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))
	burst.local_coords = false
	burst.process_material = proc
	burst.amount_ratio = 1.0
	burst.draw_pass_1 = make_spark_quad(mat, spark_length_m)
	add_child(burst)
	burst.restart()
	burst.emitting = true


func _schedule_cleanup() -> void:
	var timer := get_tree().create_timer(LIFETIME_SEC + FREE_BUFFER_SEC)
	timer.timeout.connect(queue_free)
