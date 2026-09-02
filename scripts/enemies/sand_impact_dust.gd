class_name SandImpactDust
extends Node3D

## Mars-sand burst when MG rounds pepper the dunes. Tune Albedo Color on SandBurst mesh material in sand_impact_dust.tscn.

const SandImpactDustScene := preload("res://scenes/effects/sand_impact_dust.tscn")

const GROUND_LIFT := 0.05
const FREE_BUFFER_SEC := 0.1

@export_range(0.0, 1.0, 0.01) var burst_alpha := 0.75


static func spawn(
	tree: SceneTree,
	impact: Vector3,
	terrain: TerrainManager = null
) -> void:
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		return
	var dust: SandImpactDust = SandImpactDustScene.instantiate() as SandImpactDust
	parent.add_child(dust)
	dust._place_on_surface(impact, terrain, tree)


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


func _ready() -> void:
	var burst := get_node_or_null("SandBurst") as CPUParticles3D
	if burst == null:
		queue_free()
		return
	_apply_sand_tint(burst)
	burst.emitting = true
	burst.restart()
	var timer := get_tree().create_timer(burst.lifetime + FREE_BUFFER_SEC)
	timer.timeout.connect(queue_free)


func _apply_sand_tint(burst: CPUParticles3D) -> void:
	SandParticleVfx.apply_to(burst, SandParticleVfx.IMPACT_QUAD_SIZE)
	burst.color = Color(1.0, 1.0, 1.0, burst_alpha)
