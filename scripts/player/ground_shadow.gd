class_name GroundShadow
extends Node3D

const GroundShadowMaterial = preload("res://materials/ground_shadow.tres")

const SHADOW_BASE_SIZE := 1.6
const SHADOW_GROUND_OFFSET := 0.05
const FADE_START_CLEARANCE := 0.9
const MAX_CLEARANCE := 2.0
const RAY_LENGTH := 24.0
const BASE_ALPHA := 0.35

var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	top_level = true

	_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SHADOW_BASE_SIZE, SHADOW_BASE_SIZE)
	_mesh.mesh = plane
	_material = GroundShadowMaterial.duplicate() as StandardMaterial3D
	_mesh.material_override = _material
	add_child(_mesh)


func _physics_process(_delta: float) -> void:
	var player := get_parent() as GliderPlayer
	if player == null:
		return

	var clearance := player.get_clearance()
	var from := player.global_position + Vector3(0.0, 2.0, 0.0)
	var to := from + Vector3.DOWN * RAY_LENGTH
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var hit := space_state.intersect_ray(query)

	if hit.is_empty():
		_mesh.visible = false
		return

	_mesh.visible = true
	var surface_point: Vector3 = hit.position + hit.normal * SHADOW_GROUND_OFFSET
	global_position = surface_point
	var basis := Basis()
	basis.y = hit.normal
	basis.x = Vector3.UP.cross(hit.normal)
	if basis.x.length_squared() < 0.0001:
		basis.x = Vector3.RIGHT.cross(hit.normal)
	basis.x = basis.x.normalized()
	basis.z = basis.x.cross(basis.y)
	global_basis = basis

	var scale_factor := lerpf(1.0, 2.4, clampf(clearance / MAX_CLEARANCE, 0.0, 1.0))
	_mesh.scale = Vector3(scale_factor, 1.0, scale_factor)

	var alpha := BASE_ALPHA
	if clearance > FADE_START_CLEARANCE:
		alpha *= 1.0 - clampf(
			(clearance - FADE_START_CLEARANCE) / (MAX_CLEARANCE - FADE_START_CLEARANCE),
			0.0,
			1.0
		)
	_material.albedo_color = Color(0.08, 0.06, 0.04, alpha)
