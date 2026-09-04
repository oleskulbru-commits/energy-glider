class_name SandParticleVfx
extends RefCounted

## Shared sand puff look — edit assets/materials/vfx/sand_particle.tres in the inspector.
## World bursts use GPU scenes; glider emitters reference the material directly in their scenes.

enum BurstPreset {
	LIGHT,
	HEAVY,
}

const SAND_PARTICLE_MATERIAL := preload("res://assets/materials/vfx/sand_particle.tres")
const LIGHT_BURST_SCENE := preload("res://scenes/effects/sand_burst_light_gpu.tscn")
const HEAVY_BURST_SCENE := preload("res://scenes/effects/sand_burst_heavy_gpu.tscn")

const DEFAULT_VISIBILITY_AABB := AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 4.0, 8.0))
const FREE_BUFFER_SEC := 0.1


static func burst_scene(preset: BurstPreset) -> PackedScene:
	return LIGHT_BURST_SCENE if preset == BurstPreset.LIGHT else HEAVY_BURST_SCENE


static func spawn_burst(
	tree: SceneTree,
	impact: Vector3,
	terrain: TerrainManager = null,
	preset: BurstPreset = BurstPreset.HEAVY
) -> void:
	SandImpactDust.spawn(tree, impact, terrain, preset)
