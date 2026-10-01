class_name NightClawReticle
extends Node3D

## Black circular terrain-aligned ground mark for Night Claws telegraph.

const TerrainQueryScript := preload("res://scripts/terrain/terrain_query.gd")

const GROUND_LIFT_M := 0.08
const DISC_THICKNESS_M := 0.04
## Near SunEater / finger black — opaque mix, not additive glow.
const RETICLE_COLOR := Color(0.02, 0.02, 0.03, 0.92)

var _mesh: MeshInstance3D
var _world_pos := Vector3.ZERO
var _terrain_ref: TerrainManager
var _diameter_m := 1.0
var _mark_set := false


func place(world_pos: Vector3, terrain: TerrainManager = null, diameter_m: float = 1.0) -> void:
	_world_pos = world_pos
	_terrain_ref = terrain
	_diameter_m = maxf(diameter_m, 0.01)
	_mark_set = true
	_align_to_ground(world_pos, terrain)
	_ensure_visual()


func _ready() -> void:
	if _mark_set:
		_align_to_ground(_world_pos, _terrain_ref)
		_ensure_visual()


func _align_to_ground(world_pos: Vector3, terrain: TerrainManager) -> void:
	## Cylinder disc sits on Y; basis_from_up lays it on the slope.
	if not is_inside_tree():
		position = Vector3(world_pos.x, world_pos.y + GROUND_LIFT_M, world_pos.z)
		basis = Basis.IDENTITY
		return
	var tree := get_tree()
	var space: PhysicsDirectSpaceState3D = null
	if tree != null and tree.root != null:
		var world := tree.root.get_world_3d()
		if world != null:
			space = world.direct_space_state
	var surface := TerrainQueryScript.sample_surface(
		terrain,
		space,
		world_pos.x,
		world_pos.z,
		world_pos.y + 2.0
	)
	if surface.is_empty():
		global_position = Vector3(world_pos.x, world_pos.y + GROUND_LIFT_M, world_pos.z)
		global_basis = Basis.IDENTITY
		return
	var normal: Vector3 = surface.normal
	var center: Vector3 = surface.position
	global_position = center + normal * GROUND_LIFT_M
	global_basis = TerrainQueryScript.basis_from_up(normal)


func _ensure_visual() -> void:
	var radius := _diameter_m * 0.5
	if _mesh == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = RETICLE_COLOR
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mark"
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = DISC_THICKNESS_M
		disc.radial_segments = 24
		disc.rings = 1
		disc.material = mat
		_mesh.mesh = disc
		add_child(_mesh)
	else:
		var disc := _mesh.mesh as CylinderMesh
		if disc != null:
			disc.top_radius = radius
			disc.bottom_radius = radius
