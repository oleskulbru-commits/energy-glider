class_name ShotgunFlash
extends CPUParticles3D

## Short muzzle burst. Parent to the world.

const LIFETIME_SEC := 0.16
const FREE_BUFFER_SEC := 0.15


static func spawn(tree: SceneTree, origin: Vector3, aim: Vector3) -> void:
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		return
	var burst := ShotgunFlash.new()
	parent.add_child(burst)
	burst.global_position = origin
	if aim.length_squared() > 0.0001:
		burst.direction = aim.normalized()
	burst.restart()
	burst.emitting = true


func _ready() -> void:
	emitting = false
	one_shot = true
	explosiveness = 1.0
	amount = 40
	lifetime = LIFETIME_SEC
	randomness = 0.4
	direction = Vector3(0.0, 0.0, -1.0)
	spread = 32.0
	gravity = Vector3.ZERO
	initial_velocity_min = 12.0
	initial_velocity_max = 26.0
	scale_amount_min = 0.6
	scale_amount_max = 1.4
	color = Color(1.0, 0.92, 0.62, 1.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	local_coords = false

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.94, 0.7, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.86, 0.42, 1.0)
	mat.emission_energy_multiplier = 5.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	material_override = mat

	var spark := SphereMesh.new()
	spark.radius = 0.08
	spark.height = 0.16
	mesh = spark

	var timer := get_tree().create_timer(LIFETIME_SEC + FREE_BUFFER_SEC)
	timer.timeout.connect(queue_free)
