class_name SandParticleVfx
extends RefCounted

## Shared sand puff look — rim/proximity parity enforced via apply_hover_dust_look().

enum BurstPreset {
	LIGHT,
	HEAVY,
	MG,
	DEATH,
}

const SAND_PARTICLE_MATERIAL := preload("res://assets/materials/vfx/sand_particle.tres")
const ROCKET_SMOKE_MATERIAL := preload("res://assets/materials/vfx/rocket_smoke_particle.tres")
const DRONE_MISSILE_SMOKE_MATERIAL := preload("res://assets/materials/vfx/drone_missile_smoke_particle.tres")
const LIGHT_BURST_SCENE := preload("res://scenes/effects/sand_burst_light_gpu.tscn")
const HEAVY_BURST_SCENE := preload("res://scenes/effects/sand_burst_heavy_gpu.tscn")
const MG_BURST_SCENE := preload("res://scenes/effects/sand_burst_mg_gpu.tscn")
const DEATH_BURST_SCENE := preload("res://scenes/effects/sand_burst_death_gpu.tscn")

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


static func burst_scene(preset: BurstPreset) -> PackedScene:
	match preset:
		BurstPreset.LIGHT:
			return LIGHT_BURST_SCENE
		BurstPreset.MG:
			return MG_BURST_SCENE
		BurstPreset.DEATH:
			return DEATH_BURST_SCENE
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


static func tinted_emitter_material(source: Material) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	apply_hover_dust_look(material)
	return material


static func emitter_quad_mesh(size: Vector2 = EMITTER_QUAD_SIZE) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material_for_emitter()
	return mesh


static func configure_cpu_emitter(particles: CPUParticles3D, material: StandardMaterial3D = null) -> void:
	if particles == null:
		return
	var resolved := material if material != null else material_for_emitter()
	var mesh := particles.mesh
	if mesh is QuadMesh:
		(particles.mesh as QuadMesh).material = resolved
	elif mesh == null:
		var quad := QuadMesh.new()
		quad.size = EMITTER_QUAD_SIZE
		quad.material = resolved
		particles.mesh = quad


static func configure_gpu_burst(burst: GPUParticles3D) -> void:
	if burst == null:
		return
	var mesh := burst.draw_pass_1
	if mesh is QuadMesh:
		(mesh as QuadMesh).material = material_for_emitter()
	elif mesh == null:
		burst.draw_pass_1 = emitter_quad_mesh()


static func create_missile_smoke_trail(
	parent: Node3D,
	material: StandardMaterial3D,
	particle_color: Color = ROCKET_TRAIL_COLOR
) -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.name = "SmokeTrail"
	parent.add_child(trail)
	configure_missile_smoke_trail(trail, material, particle_color)
	return trail


static func configure_missile_smoke_trail(
	particles: CPUParticles3D,
	material: StandardMaterial3D,
	particle_color: Color = ROCKET_TRAIL_COLOR
) -> void:
	if particles == null:
		return
	particles.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, MISSILE_TRAIL_NOZZLE_Z))
	particles.emitting = false
	particles.amount = 72
	particles.lifetime = 0.48
	particles.explosiveness = 0.08
	particles.randomness = 0.65
	particles.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.05
	particles.direction = Vector3(0.0, 0.0, 1.0)
	particles.spread = 22.0
	particles.gravity = Vector3(0.0, 0.35, 0.0)
	particles.initial_velocity_min = 0.35
	particles.initial_velocity_max = 1.4
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.scale_amount_min = 0.22
	particles.scale_amount_max = 0.48
	particles.scale_amount_curve = _missile_trail_scale_curve()
	particles.color = particle_color
	particles.color_ramp = _missile_trail_color_ramp(particle_color)
	configure_cpu_emitter(particles, material)
	if particles.mesh is QuadMesh:
		(particles.mesh as QuadMesh).size = MISSILE_TRAIL_QUAD_SIZE


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
