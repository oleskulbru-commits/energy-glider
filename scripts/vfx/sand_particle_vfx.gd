class_name SandParticleVfx
extends RefCounted

## Shared sand puff look — rim/proximity parity enforced via apply_hover_dust_look().

enum BurstPreset {
	LIGHT,
	HEAVY,
	MG,
	DEATH,
	CLIMB,
	EXPLOSION,
}

const SAND_PARTICLE_MATERIAL := preload("res://assets/materials/vfx/sand_particle.tres")
const ROCKET_SMOKE_MATERIAL := preload("res://assets/materials/vfx/rocket_smoke_particle.tres")
const DRONE_MISSILE_SMOKE_MATERIAL := preload("res://assets/materials/vfx/drone_missile_smoke_particle.tres")
const FIRE_V1_PARTICLE_MATERIAL := preload("res://assets/materials/vfx/fire_v1_particle.tres")
const LIGHT_BURST_SCENE := preload("res://scenes/effects/sand_burst_light_gpu.tscn")
const HEAVY_BURST_SCENE := preload("res://scenes/effects/sand_burst_heavy_gpu.tscn")
const MG_BURST_SCENE := preload("res://scenes/effects/sand_burst_mg_gpu.tscn")
const DEATH_BURST_SCENE := preload("res://scenes/effects/sand_burst_death_gpu.tscn")
const CLIMB_BURST_SCENE := preload("res://scenes/effects/sand_burst_climb_gpu.tscn")
const EXPLOSION_BURST_SCENE := preload("res://scenes/effects/sand_burst_explosion_gpu.tscn")

const DEFAULT_VISIBILITY_AABB := AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 4.0, 8.0))
const FREE_BUFFER_SEC := 0.1
const EMITTER_QUAD_SIZE := Vector2(2.0, 2.0)

const RIM := 0.25
const RIM_TINT := 0.57
const PROXIMITY_FADE_DISTANCE := 1.0

const MISSILE_TRAIL_QUAD_SIZE := Vector2(1.6, 1.6)
const MISSILE_TRAIL_NOZZLE_Z := 0.42
const ROCKET_TRAIL_COLOR := Color(1.0, 0.68, 0.32, 0.55)
const DRONE_TRAIL_COLOR := Color(0.45, 0.68, 1.0, 0.55)
const MUZZLE_FLAME_TINT := Color(1.0, 0.767, 0.6, 1.0)
const MUZZLE_FLAME_MATERIAL_COLOR := Color(3.0, 2.3, 1.75, 1.0)
const MUZZLE_FLAME_COLOR := Color(2.4, 1.85, 1.4, 0.95)
const DEBRIS_FLAME_TRAIL_OFFSET := Vector3(0.0, 0.2, 0.0)
const DEBRIS_FLAME_QUAD_SIZE := Vector2(2.2, 2.2)
const DEBRIS_FLAME_LIFETIME := 0.72
const DEBRIS_FLAME_AMOUNT := 96


static func burst_scene(preset: BurstPreset) -> PackedScene:
	match preset:
		BurstPreset.LIGHT:
			return LIGHT_BURST_SCENE
		BurstPreset.MG:
			return MG_BURST_SCENE
		BurstPreset.DEATH:
			return DEATH_BURST_SCENE
		BurstPreset.CLIMB:
			return CLIMB_BURST_SCENE
		BurstPreset.EXPLOSION:
			return EXPLOSION_BURST_SCENE
		_:
			return HEAVY_BURST_SCENE


static func spawn_burst(
	tree: SceneTree,
	impact: Vector3,
	terrain: TerrainManager = null,
	preset: BurstPreset = BurstPreset.HEAVY,
	scale_mult: float = 1.0
) -> void:
	SandImpactDust.spawn(tree, impact, terrain, preset, scale_mult)


static func apply_hover_dust_look(material: StandardMaterial3D) -> void:
	if material == null:
		return
	var template := SAND_PARTICLE_MATERIAL as StandardMaterial3D
	material.rim_enabled = true
	material.rim = RIM
	material.rim_tint = RIM_TINT
	if template != null and template.rim_texture != null:
		material.rim_texture = template.rim_texture
	material.proximity_fade_enabled = true
	material.proximity_fade_distance = PROXIMITY_FADE_DISTANCE


static func material_for_emitter() -> StandardMaterial3D:
	return tinted_emitter_material(SAND_PARTICLE_MATERIAL)


static func material_for_rocket_trail() -> StandardMaterial3D:
	return tinted_emitter_material(ROCKET_SMOKE_MATERIAL)


static func material_for_drone_missile_trail() -> StandardMaterial3D:
	return tinted_emitter_material(DRONE_MISSILE_SMOKE_MATERIAL)


static func material_for_debris_flame_trail() -> StandardMaterial3D:
	var material := FIRE_V1_PARTICLE_MATERIAL.duplicate() as StandardMaterial3D
	if material != null:
		material.albedo_color = MUZZLE_FLAME_MATERIAL_COLOR
		material.emission_enabled = true
		material.emission = MUZZLE_FLAME_TINT
		material.emission_energy_multiplier = 2.5
		material.proximity_fade_distance = PROXIMITY_FADE_DISTANCE
	return material


static func tinted_emitter_material(source: Material) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	apply_hover_dust_look(material)
	return material


static func emitter_quad_mesh(size: Vector2 = EMITTER_QUAD_SIZE) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material_for_emitter()
	return mesh


static func configure_gpu_emitter(
	particles: GPUParticles3D,
	material: StandardMaterial3D = null,
	quad_size: Vector2 = EMITTER_QUAD_SIZE
) -> void:
	if particles == null:
		return
	var resolved := material if material != null else material_for_emitter()
	var mesh := particles.draw_pass_1
	if mesh is QuadMesh:
		var quad := mesh as QuadMesh
		quad.material = resolved
		if quad.size == Vector2.ONE:
			quad.size = quad_size
	elif mesh == null:
		var quad := QuadMesh.new()
		quad.size = quad_size
		quad.material = resolved
		particles.draw_pass_1 = quad


static func configure_gpu_burst(burst: GPUParticles3D) -> void:
	configure_gpu_emitter(burst)


static func configure_gpu_hover_dust(
	particles: GPUParticles3D,
	material: StandardMaterial3D = null
) -> void:
	if particles == null:
		return
	particles.emitting = false
	particles.amount = 200
	particles.lifetime = 0.65
	particles.explosiveness = 0.12
	particles.randomness = 1.0
	particles.visibility_aabb = DEFAULT_VISIBILITY_AABB
	particles.local_coords = false
	particles.process_material = _hover_dust_process_material()
	configure_gpu_emitter(particles, material)


static func configure_gpu_impact_dust(
	particles: GPUParticles3D,
	material: StandardMaterial3D = null
) -> void:
	if particles == null:
		return
	particles.emitting = false
	particles.amount = 24
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.randomness = 0.55
	particles.visibility_aabb = DEFAULT_VISIBILITY_AABB
	particles.local_coords = false
	particles.process_material = _impact_dust_process_material()
	configure_gpu_emitter(particles, material)


static func create_missile_smoke_trail(
	parent: Node3D,
	material: StandardMaterial3D,
	particle_color: Color = ROCKET_TRAIL_COLOR,
	scale_mult: float = 1.0
) -> GPUParticles3D:
	var trail := GPUParticles3D.new()
	trail.name = "SmokeTrail"
	parent.add_child(trail)
	configure_gpu_missile_trail(trail, material, particle_color, scale_mult)
	return trail


static func create_debris_flame_trail(
	parent: Node3D,
	scale_mult: float = 1.0,
	particle_color: Color = MUZZLE_FLAME_COLOR
) -> GPUParticles3D:
	var trail := GPUParticles3D.new()
	trail.name = "FlameTrail"
	parent.add_child(trail)
	configure_gpu_debris_flame_trail(trail, particle_color, scale_mult)
	return trail


static func configure_gpu_missile_trail(
	particles: GPUParticles3D,
	material: StandardMaterial3D,
	particle_color: Color = ROCKET_TRAIL_COLOR,
	scale_mult: float = 1.0
) -> void:
	if particles == null:
		return
	var mult := maxf(scale_mult, 0.01)
	particles.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, MISSILE_TRAIL_NOZZLE_Z * mult))
	particles.emitting = false
	particles.amount = 72
	particles.lifetime = 0.48
	particles.explosiveness = 0.08
	particles.randomness = 0.65
	particles.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0) * mult, Vector3(6.0, 6.0, 6.0) * mult)
	particles.local_coords = false
	particles.process_material = _missile_trail_process_material(particle_color)
	var resolved := material if material != null else material_for_rocket_trail()
	configure_gpu_emitter(particles, resolved, MISSILE_TRAIL_QUAD_SIZE * mult)


static func configure_gpu_debris_flame_trail(
	particles: GPUParticles3D,
	particle_color: Color = MUZZLE_FLAME_COLOR,
	scale_mult: float = 1.0
) -> void:
	if particles == null:
		return
	var mult := maxf(scale_mult, 0.01)
	particles.transform = Transform3D(Basis.IDENTITY, DEBRIS_FLAME_TRAIL_OFFSET * mult)
	particles.emitting = true
	particles.amount = DEBRIS_FLAME_AMOUNT
	particles.lifetime = DEBRIS_FLAME_LIFETIME
	particles.explosiveness = 0.1
	particles.randomness = 0.55
	particles.visibility_aabb = AABB(Vector3(-4.0, -4.0, -4.0) * mult, Vector3(8.0, 8.0, 8.0) * mult)
	particles.local_coords = false
	particles.process_material = _debris_flame_trail_process_material(particle_color)
	configure_gpu_emitter(
		particles,
		material_for_debris_flame_trail(),
		DEBRIS_FLAME_QUAD_SIZE * mult
	)


static func _hover_dust_process_material() -> ParticleProcessMaterial:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(0.425, 0.025, 0.85)
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 75.0
	proc.gravity = Vector3(0.0, -1.2, 0.0)
	proc.initial_velocity_min = 0.6
	proc.initial_velocity_max = 1.8
	proc.angle_min = 90.0
	proc.angle_max = 360.0
	proc.scale_min = 0.4
	proc.scale_max = 0.75
	proc.color = Color(1.0, 1.0, 1.0, 0.32)
	proc.color_ramp = _gradient_texture(_hover_dust_gradient())
	proc.particle_flag_align_y = true
	proc.particle_flag_rotate_y = true
	return proc


static func _impact_dust_process_material() -> ParticleProcessMaterial:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.12
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 55.0
	proc.initial_velocity_min = 2.0
	proc.initial_velocity_max = 5.5
	proc.gravity = Vector3(0.0, -6.0, 0.0)
	proc.scale_min = 0.35
	proc.scale_max = 0.65
	proc.scale_curve = _curve_texture(_impact_dust_scale_curve())
	proc.color = Color(1.0, 1.0, 1.0, 0.75)
	proc.color_ramp = _gradient_texture(_impact_dust_gradient())
	return proc


static func _missile_trail_process_material(particle_color: Color) -> ParticleProcessMaterial:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.05
	proc.direction = Vector3(0.0, 0.0, 1.0)
	proc.spread = 22.0
	proc.gravity = Vector3(0.0, 0.35, 0.0)
	proc.initial_velocity_min = 0.35
	proc.initial_velocity_max = 1.4
	proc.angle_min = -180.0
	proc.angle_max = 180.0
	proc.scale_min = 0.22
	proc.scale_max = 0.48
	proc.scale_curve = _curve_texture(_missile_trail_scale_curve())
	proc.color = particle_color
	proc.color_ramp = _gradient_texture(_missile_trail_color_ramp(particle_color))
	return proc


static func _debris_flame_trail_process_material(particle_color: Color) -> ParticleProcessMaterial:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.14
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 34.0
	proc.gravity = Vector3(0.0, 0.55, 0.0)
	proc.initial_velocity_min = 0.55
	proc.initial_velocity_max = 2.0
	proc.angle_min = -180.0
	proc.angle_max = 180.0
	proc.scale_min = 0.38
	proc.scale_max = 0.78
	proc.scale_curve = _curve_texture(_debris_flame_trail_scale_curve())
	proc.color = particle_color
	proc.color_ramp = _gradient_texture(_debris_flame_trail_color_ramp(particle_color))
	return proc


static func _hover_dust_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16612378, 0.3159609])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.35),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	return gradient


static func _impact_dust_scale_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.55))
	curve.add_point(Vector2(0.25, 0.82))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


static func _impact_dust_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.55),
		Color(1.0, 1.0, 1.0, 0.22),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	return gradient


static func _missile_trail_scale_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.35, 0.72))
	curve.add_point(Vector2(1.0, 0.95))
	return curve


static func _missile_trail_color_ramp(particle_color: Color) -> Gradient:
	var gradient := Gradient.new()
	var bright := Color(
		minf(particle_color.r * 1.35, 1.0),
		minf(particle_color.g * 1.2, 1.0),
		minf(particle_color.b * 1.15, 1.0),
		minf(particle_color.a * 1.12, 1.0)
	)
	var mid := Color(
		particle_color.r,
		particle_color.g,
		particle_color.b,
		particle_color.a * 0.68
	)
	var fade := Color(0.85, 0.82, 0.78, 0.0)
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	gradient.colors = PackedColorArray([bright, mid, fade, fade])
	return gradient


static func _debris_flame_trail_scale_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.45))
	curve.add_point(Vector2(0.28, 0.82))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


static func _debris_flame_trail_color_ramp(particle_color: Color) -> Gradient:
	var gradient := Gradient.new()
	var bright := Color(
		particle_color.r * 1.35,
		particle_color.g * 1.22,
		particle_color.b * 1.12,
		particle_color.a
	)
	var mid := Color(
		particle_color.r * 0.95,
		particle_color.g * 0.78,
		particle_color.b * 0.5,
		particle_color.a * 0.78
	)
	var fade := Color(
		particle_color.r * 0.45,
		particle_color.g * 0.22,
		particle_color.b * 0.08,
		0.0
	)
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.62, 1.0])
	gradient.colors = PackedColorArray([bright, mid, fade, fade])
	return gradient


static func _gradient_texture(gradient: Gradient) -> GradientTexture1D:
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _curve_texture(curve: Curve) -> CurveTexture:
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture
