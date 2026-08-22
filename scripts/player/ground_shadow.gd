class_name GroundShadow
extends Node3D

const GroundShadowMaterial = preload("res://assets/materials/ground_shadow.tres")

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
	var terrain: TerrainManager = null
	if player.terrain_manager_path != NodePath():
		terrain = player.get_node_or_null(player.terrain_manager_path) as TerrainManager

	var world := get_world_3d()
	var space := world.direct_space_state if world != null else null
	var surface := TerrainQuery.sample_surface(
		terrain,
		space,
		player.global_position.x,
		player.global_position.z,
		player.global_position.y,
		1.5,
		[player.get_rid()],
		2.0,
		RAY_LENGTH
	)
	if surface.is_empty():
		_mesh.visible = false
		return

	_mesh.visible = true
	var surface_normal: Vector3 = surface.normal
	var surface_point: Vector3 = surface.position + surface_normal * SHADOW_GROUND_OFFSET
	global_position = surface_point
	global_basis = TerrainQuery.basis_from_up(surface_normal)

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
