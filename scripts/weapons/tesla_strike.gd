class_name TeslaStrike
extends Node3D

## Vertical sky bolt, or a hop arc between two aim points. World-parented.

const AIM_UP_M := 0.7
const HEIGHT_M := 12.0
const LIFETIME_SEC := 0.12
const CORE_RADIUS := 0.13
const GLOW_RADIUS := 0.30

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _is_link := false


static func spawn(tree: SceneTree, aim: Vector3) -> void:
	_spawn_at(tree, aim, aim + Vector3.UP * HEIGHT_M, false)


static func spawn_link(tree: SceneTree, from: Vector3, to: Vector3) -> void:
	_spawn_at(tree, from, to, true)


static func aim_point_for(target: Node3D) -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	return target.global_position + Vector3(0.0, AIM_UP_M, 0.0)


static func _spawn_at(tree: SceneTree, from: Vector3, to: Vector3, is_link: bool) -> void:
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		return
	var bolt := TeslaStrike.new()
	bolt._from = from
	bolt._to = to
	bolt._is_link = is_link
	parent.add_child(bolt)


func _ready() -> void:
	if _is_link:
		_build_link()
		_burst_sparks(_to)
	else:
		global_position = _from
		_build_rod(HEIGHT_M)
		_burst_sparks(_from)
	var timer := get_tree().create_timer(LIFETIME_SEC)
	timer.timeout.connect(queue_free)


func _build_link() -> void:
	global_position = _from
	var dir := _to - _from
	var length := dir.length()
	if length < 0.08:
		return
	if absf(dir.normalized().dot(Vector3.UP)) > 0.98:
		look_at(_to, Vector3.FORWARD)
	else:
		look_at(_to, Vector3.UP)
	var core := _make_rod(CORE_RADIUS, Color(1.0, 0.96, 1.0, 1.0), Color(0.92, 0.82, 1.0, 1.0), 8.0, length)
	var glow := _make_rod(GLOW_RADIUS, Color(0.72, 0.42, 1.0, 0.42), Color(0.62, 0.28, 1.0, 1.0), 3.8, length)
	core.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	glow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var mid := Vector3(0.0, 0.0, -length * 0.5)
	core.position = mid
	glow.position = mid
	add_child(glow)
	add_child(core)


func _build_rod(height: float) -> void:
	var core := _make_rod(CORE_RADIUS, Color(1.0, 0.96, 1.0, 1.0), Color(0.92, 0.82, 1.0, 1.0), 8.0, height)
	var glow := _make_rod(GLOW_RADIUS, Color(0.72, 0.42, 1.0, 0.42), Color(0.62, 0.28, 1.0, 1.0), 3.8, height)
	var mid := Vector3(0.0, height * 0.5, 0.0)
	core.position = mid
	glow.position = mid
	add_child(glow)
	add_child(core)


func _make_rod(
	radius: float, albedo: Color, emission: Color, energy: float, height: float
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.45
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if albedo.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	var rod := MeshInstance3D.new()
	rod.mesh = mesh
	rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return rod


func _burst_sparks(at: Vector3) -> void:
	var sparks := CPUParticles3D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 28
	sparks.lifetime = 0.28
	sparks.randomness = 0.7
	sparks.direction = Vector3(0.0, 1.0, 0.0)
	sparks.spread = 180.0
	sparks.gravity = Vector3(0.0, -10.0, 0.0)
	sparks.initial_velocity_min = 5.0
	sparks.initial_velocity_max = 13.0
	sparks.scale_amount_min = 0.7
	sparks.scale_amount_max = 1.5
	sparks.color = Color(0.86, 0.7, 1.0, 1.0)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.local_coords = false
	sparks.top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.88, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.4, 1.0, 1.0)
	mat.emission_energy_multiplier = 5.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	sparks.material_override = mat
	var spark := SphereMesh.new()
	spark.radius = 0.1
	spark.height = 0.2
	sparks.mesh = spark
	add_child(sparks)
	sparks.global_position = at
	sparks.restart()
	sparks.emitting = true
