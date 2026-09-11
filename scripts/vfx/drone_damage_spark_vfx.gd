class_name DroneDamageSparkVfx
extends RefCounted

## Looping ember sparks on wounded combat drones. Attach to the drone Visual node.

const DroneHitSparkVfxScript := preload("res://scripts/vfx/drone_hit_spark_vfx.gd")
const SPARK_MATERIAL := preload("res://assets/materials/vfx/drone_damage_spark.tres")

const DEFAULT_EMBER_COLOR := Color(2.0, 0.45, 0.08, 1.0)
const DEFAULT_GLOW_STRENGTH := 4.5
const LOCAL_OFFSET := Vector3(0.0, 0.35, 0.0)
## Cancels CombatDrone Visual scale (DRONE_SIZE_MULT = 4).
const VISUAL_SCALE_COMPENSATION := 0.25
const PARTICLE_AMOUNT := 12
const PARTICLE_LIFETIME := 0.65
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
	visibility_aabb: AABB = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0)),
	scale_min: float = 0.5,
	scale_max: float = 1.0,
	glow_strength: float = DEFAULT_GLOW_STRENGTH,
	emission_radius: float = 0.5,
	spark_length_m: float = -1.0,
	use_local_coords: bool = true,
	initial_velocity_min: float = 0.8,
	initial_velocity_max: float = 2.5
) -> GPUParticles3D:
	var mat := SPARK_MATERIAL.duplicate() as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("ColorParameter", spark_color)
		mat.set_shader_parameter("GlowStrength", glow_strength)

	var length_m := spark_length_m
	if length_m <= 0.0:
		length_m = DroneHitSparkVfxScript.SPARK_LENGTH_M

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = emission_radius
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 45.0
	proc.initial_velocity_min = initial_velocity_min
	proc.initial_velocity_max = initial_velocity_max
	proc.gravity = Vector3(0.0, -1.5, 0.0)
	proc.damping_min = 0.6
	proc.damping_max = 1.0
	proc.scale_min = scale_min
	proc.scale_max = scale_max
	DroneHitSparkVfxScript.configure_spark_process(proc)

	var sparks := GPUParticles3D.new()
	sparks.name = node_name
	sparks.position = local_offset
	sparks.scale = Vector3.ONE * scale_compensation
	sparks.emitting = true
	sparks.amount = particle_amount
	sparks.lifetime = particle_lifetime
	sparks.one_shot = false
	sparks.randomness = 0.55
	sparks.visibility_aabb = visibility_aabb
	sparks.local_coords = use_local_coords
	sparks.amount_ratio = 1.0
	sparks.process_material = proc
	sparks.draw_pass_1 = DroneHitSparkVfxScript.make_spark_quad(mat, length_m)
	parent.add_child(sparks)
	return sparks


static func debris_spark_length_for_chunk(chunk_scale: float) -> float:
	return DroneHitSparkVfxScript.SPARK_LENGTH_M * maxf(chunk_scale * DEBRIS_SPARK_LENGTH_SCALE, 2.0)


static func debris_emission_radius_for_chunk(chunk_scale: float) -> float:
	return clampf(chunk_scale * 0.18, 0.6, 2.5)
