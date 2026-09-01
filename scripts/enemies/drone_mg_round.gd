class_name DroneMgRound
extends Node3D

## Fast enemy MG tracer. Hits terrain and spawns sand dust; no player damage per round.

const DroneMgRoundScript := preload("res://scripts/enemies/drone_mg_round.gd")
const SandImpactDustScript = preload("res://scripts/enemies/sand_impact_dust.gd")

const SPEED_MPS := 140.0
const MAX_LIFE_SEC := 1.2
const GROUND_OFFSET_M := 0.06
const TRACER_RADIUS := 0.18
const TRACER_HEIGHT := 1.1
const STREAK_RADIUS := 0.14
const STREAK_HEIGHT := 3.2


var _dir := Vector3.DOWN
var _speed := SPEED_MPS
var _life := MAX_LIFE_SEC
var _terrain: TerrainManager
var _tracer: MeshInstance3D
var _streak: MeshInstance3D


static func fire(
	tree: SceneTree,
	origin: Vector3,
	aim_dir: Vector3,
	terrain: TerrainManager = null,
	speed_mps: float = SPEED_MPS
) -> Node3D:
	if tree == null:
		return null
	var parent := tree.current_scene
	if parent == null:
		return null
	var tracer: Node3D = DroneMgRoundScript.new()
	parent.add_child(tracer)
	tracer.configure(origin, aim_dir, terrain, speed_mps)
	return tracer


func configure(
	origin: Vector3,
	aim_dir: Vector3,
	terrain: TerrainManager,
	speed_mps: float = SPEED_MPS
) -> void:
	global_position = origin
	_terrain = terrain
	_speed = maxf(speed_mps, 1.0)
	_life = MAX_LIFE_SEC
	if aim_dir.length_squared() > 0.0001:
		_dir = aim_dir.normalized()
	_ensure_tracer()
	_orient()


func _ensure_tracer() -> void:
	if _tracer != null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.86, 0.42, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.22, 1.0)
	mat.emission_energy_multiplier = 2.6

	var streak_mat := StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.albedo_color = Color(1.0, 0.78, 0.28, 0.9)
	streak_mat.emission_enabled = true
	streak_mat.emission = Color(1.0, 0.62, 0.16, 1.0)
	streak_mat.emission_energy_multiplier = 2.0

	_streak = MeshInstance3D.new()
	_streak.name = "Streak"
	var streak_capsule := CapsuleMesh.new()
	streak_capsule.radius = STREAK_RADIUS
	streak_capsule.height = STREAK_HEIGHT
	_streak.mesh = streak_capsule
	_streak.material_override = streak_mat
	_streak.position = Vector3(0.0, 0.0, STREAK_HEIGHT * 0.45)
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streak)

	_tracer = MeshInstance3D.new()
	_tracer.name = "Tracer"
	var capsule := CapsuleMesh.new()
	capsule.radius = TRACER_RADIUS
	capsule.height = TRACER_HEIGHT
	_tracer.mesh = capsule
	_tracer.material_override = mat
	_tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tracer)


func _orient() -> void:
	if _dir.length_squared() < 0.0001:
		return
	look_at(global_position + _dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _hit_ground():
		_impact()
		queue_free()


func _hit_ground() -> bool:
	var ground_y := 0.0
	if _terrain != null:
		ground_y = _terrain.sample_height(global_position.x, global_position.z)
	return global_position.y <= ground_y + GROUND_OFFSET_M


func _impact() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var ground_y := global_position.y
	if _terrain != null:
		ground_y = _terrain.sample_height(global_position.x, global_position.z)
	SandImpactDustScript.spawn(
		tree,
		Vector3(global_position.x, ground_y, global_position.z),
		_terrain
	)
