class_name RocketExplosion
extends CPUParticles3D

## Orange blast. Parent to the world so it outlives the missile.

const LIFETIME_SEC := 0.45
const FREE_BUFFER_SEC := 0.2


static func spawn(tree: SceneTree, origin: Vector3) -> void:
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		return
	var burst := RocketExplosion.new()
	parent.add_child(burst)
	burst.global_position = origin
	burst.restart()
	burst.emitting = true


func _ready() -> void:
	emitting = false
	one_shot = true
	explosiveness = 1.0
	amount = 56
	lifetime = LIFETIME_SEC
	randomness = 0.75
	direction = Vector3(0.0, 1.0, 0.0)
	spread = 180.0
	gravity = Vector3(0.0, -14.0, 0.0)
	initial_velocity_min = 8.0
	initial_velocity_max = 22.0
	scale_amount_min = 1.2
	scale_amount_max = 2.4
	color = Color(1.0, 0.42, 0.16, 1.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	local_coords = false

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.62, 0.22, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.38, 0.08, 1.0)
	mat.emission_energy_multiplier = 6.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	material_override = mat

	var spark := SphereMesh.new()
	spark.radius = 0.22
	spark.height = 0.44
	mesh = spark

	var timer := get_tree().create_timer(LIFETIME_SEC + FREE_BUFFER_SEC)
	timer.timeout.connect(queue_free)
