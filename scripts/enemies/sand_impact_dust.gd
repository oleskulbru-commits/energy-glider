class_name SandImpactDust
extends Node3D

## World-spawned sand burst. Tuning lives in sand_burst_*_gpu.tscn — this script only places and plays.

const SandImpactDustScene := preload("res://scenes/effects/sand_impact_dust.tscn")
const SandImpactDustExplosionScene := preload("res://scenes/effects/sand_impact_dust_explosion.tscn")
const LaserImpactScene := preload("res://scenes/effects/laser_impact.tscn")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")
const CameraImpactShakeScript := preload("res://scripts/player/camera_impact_shake.gd")
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")

const GROUND_LIFT := 0.05
const LASER_SHOCKWAVE_DURATION_SEC := 0.35

var _burst_preset: SandParticleVfx.BurstPreset = SandParticleVfx.BurstPreset.HEAVY


static func spawn(
	tree: SceneTree,
	impact: Vector3,
	terrain: TerrainManager = null,
	preset: SandParticleVfx.BurstPreset = SandParticleVfx.BurstPreset.HEAVY,
	scale_mult: float = 1.0,
	shake_strength: float = 0.0,
	shake_radius_m: float = 0.0
) -> void:
	if tree == null:
		return
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return
	var dust: SandImpactDust
	if preset == SandParticleVfx.BurstPreset.HEAVY:
		dust = SandImpactDustScene.instantiate() as SandImpactDust
	elif preset == SandParticleVfx.BurstPreset.EXPLOSION:
		dust = SandImpactDustExplosionScene.instantiate() as SandImpactDust
	elif preset == SandParticleVfx.BurstPreset.LASER:
		dust = LaserImpactScene.instantiate() as SandImpactDust
	else:
		dust = SandImpactDust.new()
		var burst_root: Node = SandParticleVfx.burst_scene(preset).instantiate()
		dust.add_child(burst_root)
	parent.add_child(dust)
	dust._burst_preset = preset
	dust._place_on_surface(impact, terrain)
	if scale_mult > 0.0 and not is_equal_approx(scale_mult, 1.0):
		dust.scale = Vector3.ONE * scale_mult
	dust._play_burst()
	if shake_strength > 0.0 and shake_radius_m > 0.0:
		CameraImpactShakeScript.request(tree, impact, shake_strength, shake_radius_m)


func _ready() -> void:
	pass


func _play_burst() -> void:
	var burst := _find_burst() as GPUParticles3D
	if burst == null:
		queue_free()
		return
	if _burst_preset == SandParticleVfxScript.BurstPreset.LASER:
		SandParticleVfxScript.configure_gpu_burst(
			burst, SandParticleVfxScript.material_for_laser_impact()
		)
	else:
		SandParticleVfxScript.configure_gpu_burst(burst)
	burst.restart()
	burst.emitting = true
	var shockwave := get_node_or_null("ShockwaveRing")
	if shockwave != null and shockwave.has_method("play"):
		shockwave.call("play")
	var free_after := burst.lifetime + SandParticleVfx.FREE_BUFFER_SEC
	if shockwave != null:
		free_after = maxf(
			free_after,
			LASER_SHOCKWAVE_DURATION_SEC + SandParticleVfx.FREE_BUFFER_SEC
		)
	var timer := get_tree().create_timer(free_after)
	timer.timeout.connect(queue_free)


func _find_burst() -> Node:
	var direct := get_node_or_null("SandBurst") as GPUParticles3D
	if direct != null:
		return direct
	var burst_root := get_node_or_null("BurstRoot")
	if burst_root != null:
		return burst_root.get_node_or_null("SandBurst")
	for child in get_children():
		var nested := child.get_node_or_null("SandBurst") as GPUParticles3D
		if nested != null:
			return nested
	return null


func _place_on_surface(impact: Vector3, terrain: TerrainManager) -> void:
	var space: PhysicsDirectSpaceState3D = null
	var world := get_world_3d()
	if world != null:
		space = world.direct_space_state
	var surface := TerrainQuery.sample_surface(
		terrain,
		space,
		impact.x,
		impact.z,
		impact.y + 2.0
	)
	if surface.is_empty():
		global_position = Vector3(impact.x, impact.y + GROUND_LIFT, impact.z)
		return
	var normal: Vector3 = surface.normal
	global_position = surface.position + normal * GROUND_LIFT
	global_basis = TerrainQuery.basis_from_up(normal)
