class_name KillSparks
extends CPUParticles3D

## One-shot yellow burst. Parent to the world so it outlives the dead pill.

const LIFETIME_SEC := 0.55
const FREE_BUFFER_SEC := 0.2


static func spawn(tree: SceneTree, origin: Vector3) -> void:
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		return
	var burst := KillSparks.new()
	parent.add_child(burst)
	burst.global_position = origin
	burst.restart()
	burst.emitting = true


func _ready() -> void:
	emitting = false
	one_shot = true
	explosiveness = 1.0
	amount = 48
	lifetime = LIFETIME_SEC
	randomness = 0.7
	direction = Vector3(0.0, 1.0, 0.0)
	spread = 180.0
	gravity = Vector3(0.0, -12.0, 0.0)
	initial_velocity_min = 6.0
	initial_velocity_max = 16.0
	scale_amount_min = 1.0
	scale_amount_max = 1.8
	color = Color(1.0, 0.86, 0.32, 1.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	local_coords = false

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.92, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.3, 1.0)
	mat.emission_energy_multiplier = 5.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	material_override = mat

	var spark := SphereMesh.new()
	spark.radius = 0.18
	spark.height = 0.36
	mesh = spark

	var timer := get_tree().create_timer(LIFETIME_SEC + FREE_BUFFER_SEC)
	timer.timeout.connect(queue_free)
