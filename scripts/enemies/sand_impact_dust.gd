class_name SandImpactDust
extends Node3D

## World-spawned sand burst. Tuning lives in sand_burst_*_gpu.tscn — this script only places and plays.

const SandImpactDustScene := preload("res://scenes/effects/sand_impact_dust.tscn")

const GROUND_LIFT := 0.05


static func spawn(
	tree: SceneTree,
	impact: Vector3,
	terrain: TerrainManager = null,
	preset: SandParticleVfx.BurstPreset = SandParticleVfx.BurstPreset.HEAVY
) -> void:
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		return
	var dust: SandImpactDust
	if preset == SandParticleVfx.BurstPreset.HEAVY:
		dust = SandImpactDustScene.instantiate() as SandImpactDust
	else:
		dust = SandImpactDust.new()
		var burst_root: Node = SandParticleVfx.burst_scene(preset).instantiate()
		dust.add_child(burst_root)
	parent.add_child(dust)
	dust._place_on_surface(impact, terrain, tree)
	dust._play_burst()


func _ready() -> void:
	pass


func _play_burst() -> void:
	var burst := _find_burst() as GPUParticles3D
	if burst == null:
		queue_free()
		return
	burst.restart()
	burst.emitting = true
	var timer := get_tree().create_timer(burst.lifetime + SandParticleVfx.FREE_BUFFER_SEC)
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


func _place_on_surface(impact: Vector3, terrain: TerrainManager, tree: SceneTree) -> void:
	var space: PhysicsDirectSpaceState3D = null
	var world := tree.root.get_world_3d() if tree.root != null else null
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
