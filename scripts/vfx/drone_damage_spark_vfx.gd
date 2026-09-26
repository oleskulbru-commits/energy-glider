class_name DroneDamageSparkVfx
extends RefCounted

## Looping ember sparks on wounded combat drones. Attach to the drone Visual node.

const SparkParticleVfxScript := preload("res://scripts/vfx/spark_particle_vfx.gd")

const DEFAULT_EMBER_COLOR := SparkParticleVfxScript.DEFAULT_COLOR
const DEFAULT_GLOW_STRENGTH := SparkParticleVfxScript.DEFAULT_GLOW_STRENGTH
const LOCAL_OFFSET := Vector3(0.0, 0.35, 0.0)
## Cancels CombatDrone Visual scale (DRONE_SIZE_MULT = 4).
const VISUAL_SCALE_COMPENSATION := 0.25
const PARTICLE_AMOUNT := SparkParticleVfxScript.LOOPING_AMOUNT
const PARTICLE_LIFETIME := SparkParticleVfxScript.LOOPING_LIFETIME
const DEBRIS_PARTICLE_LIFETIME := 2.0
const DEBRIS_PARTICLE_AMOUNT := 24
const DEBRIS_GLOW_STRENGTH := 8.0
const DEBRIS_VISIBILITY_AABB := AABB(Vector3(-8.0, -8.0, -8.0), Vector3(16.0, 16.0, 16.0))
const DEBRIS_SPARK_LENGTH_SCALE := 0.65


static func attach(visual: Node3D, spark_color: Color = DEFAULT_EMBER_COLOR) -> GPUParticles3D:
	if visual == null:
		return null
	var existing := visual.get_node_or_null("DamageSparks") as GPUParticles3D
	if existing != null:
		return existing

	return build_looping_sparks(
		visual,
		spark_color,
		"DamageSparks",
		LOCAL_OFFSET,
		VISUAL_SCALE_COMPENSATION
	)


static func build_looping_sparks(
	parent: Node3D,
	spark_color: Color,
	node_name: String = "DamageSparks",
	local_offset: Vector3 = LOCAL_OFFSET,
	scale_compensation: float = 1.0,
	particle_lifetime: float = PARTICLE_LIFETIME,
	particle_amount: int = PARTICLE_AMOUNT,
	visibility_aabb: AABB = SparkParticleVfxScript.LOOPING_VISIBILITY_AABB,
	scale_min: float = -1.0,
	scale_max: float = -1.0,
	glow_strength: float = DEFAULT_GLOW_STRENGTH,
	emission_radius: float = -1.0,
	spark_length_m: float = -1.0,
	use_local_coords: bool = true,
	initial_velocity_min: float = -1.0,
	initial_velocity_max: float = -1.0
) -> GPUParticles3D:
	var mat := SparkParticleVfxScript.tinted_material(spark_color, glow_strength)

	var length_m := spark_length_m
	if length_m <= 0.0:
		length_m = SparkParticleVfxScript.SPARK_LENGTH_M

	var proc := ParticleProcessMaterial.new()
	SparkParticleVfxScript.configure_looping_process(proc)
	if emission_radius >= 0.0:
		proc.emission_sphere_radius = emission_radius
	if scale_min >= 0.0:
		proc.scale_min = scale_min
	if scale_max >= 0.0:
		proc.scale_max = scale_max
	if initial_velocity_min >= 0.0:
		proc.initial_velocity_min = initial_velocity_min
	if initial_velocity_max >= 0.0:
		proc.initial_velocity_max = initial_velocity_max

	var sparks := GPUParticles3D.new()
	sparks.name = node_name
	sparks.position = local_offset
	sparks.scale = Vector3.ONE * scale_compensation
	sparks.emitting = true
	sparks.one_shot = false
	sparks.amount_ratio = 1.0
	sparks.process_material = proc
	sparks.draw_pass_1 = SparkParticleVfxScript.make_spark_quad(mat, length_m)
	SparkParticleVfxScript.configure_looping_emitter(
		sparks,
		particle_amount,
		particle_lifetime,
		use_local_coords
	)
	if visibility_aabb != SparkParticleVfxScript.LOOPING_VISIBILITY_AABB:
		sparks.visibility_aabb = visibility_aabb
	parent.add_child(sparks)
	return sparks


static func debris_spark_length_for_chunk(chunk_scale: float) -> float:
	return SparkParticleVfxScript.SPARK_LENGTH_M * maxf(chunk_scale * DEBRIS_SPARK_LENGTH_SCALE, 2.0)


static func debris_emission_radius_for_chunk(chunk_scale: float) -> float:
	return clampf(chunk_scale * 0.18, 0.6, 2.5)
