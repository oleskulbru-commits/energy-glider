class_name SandImpactDust
extends Node3D

## Small mars-sand burst when MG rounds pepper the dunes.

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")

const LIFETIME_SEC := 0.55
const GROUND_LIFT := 0.04
const DUST_COLOR := Color(0.78, 0.62, 0.4, 0.72)


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
	var ground_y := impact.y
	if terrain != null:
		ground_y = terrain.sample_height(impact.x, impact.z)
	dust.global_position = Vector3(impact.x, ground_y + GROUND_LIFT, impact.z)


func _ready() -> void:
	_add_burst()
	var timer := get_tree().create_timer(LIFETIME_SEC)
	timer.timeout.connect(queue_free)


func _add_burst() -> void:
	var burst := CPUParticles3D.new()
	burst.name = "SandBurst"
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 48
	burst.lifetime = LIFETIME_SEC
	burst.randomness = 0.55
	burst.direction = Vector3(0.0, 1.0, 0.0)
	burst.spread = 42.0
	burst.gravity = Vector3(0.0, -10.0, 0.0)
	burst.initial_velocity_min = 2.5
	burst.initial_velocity_max = 9.0
	burst.scale_amount_min = 0.12
	burst.scale_amount_max = 0.32
	burst.color = DUST_COLOR
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.local_coords = false
	burst.material_override = _dust_material()
	burst.mesh = _quad_mesh()
	add_child(burst)
	burst.restart()


func _dust_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _quad_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	return quad
