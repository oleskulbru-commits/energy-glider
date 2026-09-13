class_name FingerReticle
extends Node3D

## 10 m warning ring that follows the glider, then locks before The Finger slams.

const RADIUS_M := 10.0
const RING_INNER_M := 9.55
const RING_OUTER_M := 10.25
const GROUND_LIFT_M := 0.14
const RING_COLOR := Color(0.78, 0.07, 0.05, 0.92)

var _follow: Node3D
var _terrain: TerrainManager
var _locked := false
var _ring: MeshInstance3D


func configure(target: Node3D, terrain: TerrainManager = null) -> void:
	_follow = target
	_terrain = terrain
	_locked = false
	_ensure_visual()
	_snap_to_follow()


func lock() -> void:
	_locked = true
	_follow = null


func is_locked() -> bool:
	return _locked


func is_following() -> bool:
	return not _locked


func locked_position() -> Vector3:
	return global_position


func _physics_process(_delta: float) -> void:
	if _locked:
		return
	_snap_to_follow()


func _snap_to_follow() -> void:
	if _follow == null or not is_instance_valid(_follow):
		return
	var pos := _follow.global_position
	var ground_y := pos.y
	if _terrain != null:
		ground_y = _terrain.sample_height(pos.x, pos.z)
	global_position = Vector3(pos.x, ground_y + GROUND_LIFT_M, pos.z)


func _ensure_visual() -> void:
	if _ring != null:
		return
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = RING_INNER_M
	torus.outer_radius = RING_OUTER_M
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 2.4
	mat.albedo_color = RING_COLOR
	mat.emission = Color(RING_COLOR.r * 0.9, RING_COLOR.g * 0.9, RING_COLOR.b * 0.9)
	_ring.material_override = mat
	add_child(_ring)
