class_name SparkParticleVfx
extends RefCounted

## Shared ember spark look — mask/scroll parity enforced via apply_spark_look().

const SPARK_PARTICLE_MATERIAL := preload("res://assets/materials/vfx/spark_particle.tres")
const SPARKS_TEXTURE_PATH := "res://assets/vfx/effect_textures/sparks_texture.png"

## sparks_texture.png is 32x16 (2:1 wide); mesh height is the streak axis for align_y.
const SPARK_TEX_ASPECT := 2.0
const SPARK_LENGTH_M := 0.08
const SPARK_WIDTH_M := SPARK_LENGTH_M / SPARK_TEX_ASPECT
const DEFAULT_GLOW_STRENGTH := 4.5
const DEFAULT_COLOR := Color(2.0, 0.45, 0.08, 1.0)

## Looping ember preset — tuned in scenes/test/spark_particle_test.tscn.
const LOOPING_AMOUNT := 50
const LOOPING_LIFETIME := 4.0
const LOOPING_SPEED_SCALE := 2.0
const LOOPING_RANDOMNESS := 0.55
const LOOPING_VISIBILITY_AABB := AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
const LOOPING_EMISSION_RADIUS := 0.5
const LOOPING_INITIAL_VELOCITY_MIN := 2.0
const LOOPING_INITIAL_VELOCITY_MAX := 4.0
const LOOPING_GRAVITY := Vector3(0.0, -1.5, 0.0)
const LOOPING_DAMPING_MIN := 0.6
const LOOPING_DAMPING_MAX := 1.0
const LOOPING_SCALE_MIN := 0.5
const LOOPING_LIFETIME_RANDOMNESS := 1.0
const LOOPING_INHERIT_VELOCITY_RATIO := 0.22
const LOOPING_TRANSFORM_ALIGN := GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD


static func apply_spark_look(material: ShaderMaterial) -> void:
	if material == null:
		return
	var template := SPARK_PARTICLE_MATERIAL as ShaderMaterial
	if template == null:
		return
	material.shader = template.shader
	material.set_shader_parameter("Base_Texture", template.get_shader_parameter("Base_Texture"))
	material.set_shader_parameter("Streak_Mask", template.get_shader_parameter("Streak_Mask"))


static func tinted_material(
	spark_color: Color = DEFAULT_COLOR,
	glow_strength: float = DEFAULT_GLOW_STRENGTH
) -> ShaderMaterial:
	var mat := SPARK_PARTICLE_MATERIAL.duplicate() as ShaderMaterial
	apply_spark_look(mat)
	mat.set_shader_parameter("ColorParameter", spark_color)
	mat.set_shader_parameter("GlowStrength", glow_strength)
	return mat


static func make_spark_quad(
	material: ShaderMaterial,
	length_m: float = SPARK_LENGTH_M
) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(length_m / SPARK_TEX_ASPECT, length_m)
	quad.material = material
	return quad


static func configure_spark_process(proc: ParticleProcessMaterial) -> void:
	proc.particle_flag_align_y = true
	proc.angle_min = 0.0
	proc.angle_max = 0.0


static func configure_looping_process(proc: ParticleProcessMaterial) -> void:
	configure_spark_process(proc)
	proc.lifetime_randomness = LOOPING_LIFETIME_RANDOMNESS
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = LOOPING_EMISSION_RADIUS
	proc.inherit_velocity_ratio = LOOPING_INHERIT_VELOCITY_RATIO
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.initial_velocity_min = LOOPING_INITIAL_VELOCITY_MIN
	proc.initial_velocity_max = LOOPING_INITIAL_VELOCITY_MAX
	proc.gravity = LOOPING_GRAVITY
	proc.damping_min = LOOPING_DAMPING_MIN
	proc.damping_max = LOOPING_DAMPING_MAX
	proc.scale_min = LOOPING_SCALE_MIN


static func configure_looping_emitter(
	sparks: GPUParticles3D,
	amount: int = LOOPING_AMOUNT,
	lifetime: float = LOOPING_LIFETIME,
	local_coords: bool = true
) -> void:
	sparks.amount = amount
	sparks.lifetime = lifetime
	sparks.speed_scale = LOOPING_SPEED_SCALE
	sparks.randomness = LOOPING_RANDOMNESS
	sparks.visibility_aabb = LOOPING_VISIBILITY_AABB
	sparks.local_coords = local_coords
	sparks.transform_align = LOOPING_TRANSFORM_ALIGN
