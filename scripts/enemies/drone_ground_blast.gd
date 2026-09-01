extends Node3D

## Bright flash + particle burst + lingering ground fire for drone rocket impacts.

const BlastScript := preload("res://scripts/enemies/drone_ground_blast.gd")

const TOTAL_LIFETIME_SEC := 5.0
const FIRE_EMIT_SEC := 2.8
const GROUND_LIFT := 0.2


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
	var blast: Node3D = BlastScript.new()
	parent.add_child(blast)
	var ground_y := impact.y
	if terrain != null:
		ground_y = terrain.sample_height(impact.x, impact.z)
	blast.global_position = Vector3(impact.x, ground_y + GROUND_LIFT, impact.z)


func _ready() -> void:
	_add_flash_light()
	_add_flash_burst()
	_add_ground_dust()
	_add_lingering_fire()
	var emit_timer := get_tree().create_timer(FIRE_EMIT_SEC)
	emit_timer.timeout.connect(_stop_fire_emit)
	var free_timer := get_tree().create_timer(TOTAL_LIFETIME_SEC)
	free_timer.timeout.connect(queue_free)


func _stop_fire_emit() -> void:
	var fire := get_node_or_null("LingeringFire") as CPUParticles3D
	if fire != null:
		fire.emitting = false


func _add_flash_light() -> void:
	var light := OmniLight3D.new()
	light.name = "FlashLight"
	light.light_color = Color(0.82, 0.92, 1.0, 1.0)
	light.light_energy = 24.0
	light.omni_range = 42.0
	light.shadow_enabled = false
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.85).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _add_flash_burst() -> void:
	var burst := CPUParticles3D.new()
	burst.name = "FlashBurst"
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 220
	burst.lifetime = 0.65
	burst.randomness = 0.85
	burst.direction = Vector3(0.0, 1.0, 0.0)
	burst.spread = 180.0
	burst.gravity = Vector3(0.0, -12.0, 0.0)
	burst.initial_velocity_min = 18.0
	burst.initial_velocity_max = 52.0
	burst.scale_amount_min = 5.0
	burst.scale_amount_max = 14.0
	burst.color = Color(0.9, 0.96, 1.0, 1.0)
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.local_coords = false
	burst.material_override = _flash_material()
	burst.mesh = _spark_mesh(0.52)
	add_child(burst)
	burst.restart()


func _add_ground_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "GroundDust"
	dust.emitting = true
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 180
	dust.lifetime = 1.4
	dust.randomness = 0.7
	dust.direction = Vector3(0.0, 1.0, 0.0)
	dust.spread = 28.0
	dust.gravity = Vector3(0.0, -18.0, 0.0)
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 24.0
	dust.scale_amount_min = 3.5
	dust.scale_amount_max = 8.5
	dust.color = Color(0.72, 0.82, 0.95, 0.75)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.local_coords = false
	dust.material_override = _dust_material()
	dust.mesh = _spark_mesh(0.38)
	add_child(dust)
	dust.restart()


func _add_lingering_fire() -> void:
	var fire := CPUParticles3D.new()
	fire.name = "LingeringFire"
	fire.emitting = true
	fire.one_shot = false
	fire.explosiveness = 0.15
	fire.amount = 140
	fire.lifetime = 3.2
	fire.randomness = 0.92
	fire.direction = Vector3(0.0, 1.0, 0.0)
	fire.spread = 105.0
	fire.gravity = Vector3(0.0, -1.2, 0.0)
	fire.initial_velocity_min = 1.2
	fire.initial_velocity_max = 7.5
	fire.scale_amount_min = 3.5
	fire.scale_amount_max = 9.0
	fire.color = Color(0.35, 0.62, 1.0, 0.95)
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.local_coords = false
	fire.material_override = _fire_material(5.0)
	fire.mesh = _spark_mesh(0.48)
	add_child(fire)


func _flash_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.98, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.88, 1.0, 1.0)
	mat.emission_energy_multiplier = 14.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	return mat


func _fire_material(energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.28, 0.55, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.45, 1.0, 1.0)
	mat.emission_energy_multiplier = energy
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	return mat


func _dust_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.78, 0.86, 0.96, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.62, 0.9, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	return mat


func _spark_mesh(radius: float) -> SphereMesh:
	var spark := SphereMesh.new()
	spark.radius = radius
	spark.height = radius * 2.0
	return spark
