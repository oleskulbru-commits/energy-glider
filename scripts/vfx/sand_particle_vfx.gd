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
	var material := SAND_PARTICLE_MATERIAL.duplicate() as StandardMaterial3D
	apply_hover_dust_look(material)
	return material


static func emitter_quad_mesh(size: Vector2 = EMITTER_QUAD_SIZE) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material_for_emitter()
	return mesh


static func configure_cpu_emitter(particles: CPUParticles3D) -> void:
	if particles == null:
		return
	var mesh := particles.mesh
	if mesh is QuadMesh:
		(particles.mesh as QuadMesh).material = material_for_emitter()
	elif mesh == null:
		particles.mesh = emitter_quad_mesh()


static func configure_gpu_burst(burst: GPUParticles3D) -> void:
	if burst == null:
		return
	var mesh := burst.draw_pass_1
	if mesh is QuadMesh:
		(mesh as QuadMesh).material = material_for_emitter()
	elif mesh == null:
		burst.draw_pass_1 = emitter_quad_mesh()
