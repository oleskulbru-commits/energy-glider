class_name DroneMgRound
extends Node3D

## Fast enemy MG tracer. Hits terrain and spawns sand dust; no player damage per round.

const DroneMgRoundScript := preload("res://scripts/enemies/drone_mg_round.gd")
const SandImpactDustScript = preload("res://scripts/enemies/sand_impact_dust.gd")
const SandParticleVfxScript = preload("res://scripts/vfx/sand_particle_vfx.gd")

const SPEED_MPS := 140.0
const MAX_LIFE_SEC := 1.2
const GROUND_OFFSET_M := 0.06
const FALLBACK_RADIUS := 0.01
const FALLBACK_HEIGHT := 0.4


var _dir := Vector3.DOWN
var _speed := SPEED_MPS
var _life := MAX_LIFE_SEC
var _terrain: TerrainManager
var _tracer: MeshInstance3D


static func fire(
	tree: SceneTree,
	aim_dir: Vector3,
	terrain: TerrainManager = null,
	speed_mps: float = SPEED_MPS,
	gun_barrel: Node3D = null,
	size_ref: MeshInstance3D = null
) -> Node3D:
	if tree == null:
		return null
	var parent := tree.current_scene
	if parent == null:
		return null
	var tracer: Node3D = DroneMgRoundScript.new()
	parent.add_child(tracer)
	tracer.configure(aim_dir, terrain, speed_mps, gun_barrel, size_ref)
	return tracer


static func reference_has_capsule(ref: MeshInstance3D) -> bool:
	return ref != null and ref.mesh is CapsuleMesh


static func capsule_world_size(ref: MeshInstance3D) -> Vector2:
	if not reference_has_capsule(ref):
		return Vector2.ZERO
	var mesh := ref.mesh as CapsuleMesh
	var scale := ref.global_transform.basis.get_scale().abs()
	var radius_scale := maxf(scale.x, scale.z)
	return Vector2(mesh.radius * radius_scale, mesh.height * scale.y)


func configure(
	aim_dir: Vector3,
	terrain: TerrainManager,
	speed_mps: float = SPEED_MPS,
	gun_barrel: Node3D = null,
	size_ref: MeshInstance3D = null
) -> void:
	_terrain = terrain
	_speed = maxf(speed_mps, 1.0)
	_life = MAX_LIFE_SEC
	if aim_dir.length_squared() > 0.0001:
		_dir = aim_dir.normalized()
	_apply_reference_transform(gun_barrel, size_ref)
	_ensure_tracer(size_ref)
	_orient()


func _apply_reference_transform(gun_barrel: Node3D, _size_ref: MeshInstance3D) -> void:
	if gun_barrel != null:
		global_position = gun_barrel.global_position
		return
	global_position = Vector3.ZERO


func _orient() -> void:
	if _dir.length_squared() < 0.0001:
		return
	if absf(_dir.dot(Vector3.UP)) > 0.98:
		look_at(global_position + _dir, Vector3.FORWARD)
	else:
		look_at(global_position + _dir, Vector3.UP)


func _ensure_tracer(size_ref: MeshInstance3D) -> void:
	if _tracer != null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.86, 0.42, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.22, 1.0)
	mat.emission_energy_multiplier = 2.6

	_tracer = MeshInstance3D.new()
	_tracer.name = "Tracer"
	if reference_has_capsule(size_ref):
		_tracer.mesh = (size_ref.mesh as CapsuleMesh).duplicate()
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = FALLBACK_RADIUS
		capsule.height = FALLBACK_HEIGHT
		_tracer.mesh = capsule
	_tracer.material_override = mat
	_tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tracer.transform = Transform3D(
		Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0)),
		Vector3.ZERO
	)
	add_child(_tracer)


func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_orient()
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
		_terrain,
		SandParticleVfxScript.BurstPreset.MG
	)
