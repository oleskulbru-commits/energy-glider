class_name SandImpactDust
extends Node3D

## Mars-sand burst when MG rounds pepper the dunes. Matches glider hover dust visuals.

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const HoverDustScript = preload("res://scripts/player/hover_dust.gd")

const GROUND_LIFT := 0.05
const BURST_INTENSITY := 1.35


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
	var dust: SandImpactDust = SandImpactDustScript.new()
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
	var burst := CPUParticles3D.new()
	burst.name = "SandBurst"
	HoverDustScript.configure_impact_burst(burst, BURST_INTENSITY)
	add_child(burst)
	burst.restart()
	var timer := get_tree().create_timer(HoverDustScript.BASE_LIFETIME + 0.1)
	timer.timeout.connect(queue_free)
