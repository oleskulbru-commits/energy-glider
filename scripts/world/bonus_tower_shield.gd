class_name BonusTowerShield
extends Node3D

## Red laser dome around a bonus tower. Blocks the player and ground garrison units.

const NODE_NAME := "BonusTowerShield"
const COLLISION_LAYER := 16
const CENTER_Y_M := 50.0
const RADIUS_M := 52.0
const SHIELD_ALPHA := 0.18
const SHIELD_COLOR := Color(1.0, 0.12, 0.1, SHIELD_ALPHA)

var _body: StaticBody3D
var _mesh: MeshInstance3D
var _aim: Marker3D
var _active := true


static func ensure_on(tower: Node3D) -> BonusTowerShield:
	if tower == null:
		return null
	var existing := tower.get_node_or_null(NODE_NAME) as BonusTowerShield
	if existing != null:
		return existing
	var shield := BonusTowerShield.new()
	shield.name = NODE_NAME
	tower.add_child(shield)
	return shield


func _ready() -> void:
	position = Vector3(0.0, CENTER_Y_M, 0.0)
	_ensure_visual()
	_ensure_body()
	_ensure_aim()
	set_shield_active(_active)


func set_shield_active(on: bool) -> void:
	_active = on
	visible = on
	if _mesh != null:
		_mesh.visible = on
	if _body != null:
		_body.collision_layer = COLLISION_LAYER if on else 0
		_body.collision_mask = 0


func is_shield_active() -> bool:
	return _active


func aim_marker() -> Marker3D:
	_ensure_aim()
	return _aim


func aim_point_from(from: Vector3) -> Vector3:
	var center := global_position
	var dir := from - center
	if dir.length_squared() < 0.0001:
		dir = Vector3.RIGHT
	return center + dir.normalized() * RADIUS_M


## Equator of the dome on the shooter's azimuth — halfway up the sphere.
func aim_mid_from(from: Vector3) -> Vector3:
	var center := global_position
	var flat := Vector3(from.x - center.x, 0.0, from.z - center.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.RIGHT
	return center + flat.normalized() * RADIUS_M


func _ensure_visual() -> void:
	if _mesh != null:
		return
	_mesh = MeshInstance3D.new()
	_mesh.name = "Visual"
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS_M
	sphere.height = RADIUS_M * 2.0
	sphere.radial_segments = 24
	sphere.rings = 16
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = SHIELD_COLOR
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.18, 0.12)
	mat.emission_energy_multiplier = 1.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	_mesh.material_override = mat
	add_child(_mesh)


func _ensure_body() -> void:
	if _body != null:
		return
	_body = StaticBody3D.new()
	_body.name = "Collision"
	_body.collision_layer = COLLISION_LAYER
	_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = RADIUS_M
	col.shape = shape
	_body.add_child(col)
	add_child(_body)


func _ensure_aim() -> void:
	if _aim != null:
		return
	_aim = get_node_or_null("Aim") as Marker3D
	if _aim != null:
		return
	_aim = Marker3D.new()
	_aim.name = "Aim"
	add_child(_aim)
