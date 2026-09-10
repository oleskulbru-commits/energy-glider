class_name GroundReticle
extends Node3D

## Flat aiming ring on the sand for incoming drone rockets.

const LIFE_SEC := 1.4
const RING_COLOR := Color(0.2, 0.85, 1.0, 0.9)

var _life := LIFE_SEC
var _ring: MeshInstance3D
var _color := RING_COLOR


func place(world_pos: Vector3, life_sec: float = LIFE_SEC, color: Color = RING_COLOR) -> void:
	global_position = world_pos + Vector3(0.0, 0.12, 0.0)
	_life = maxf(life_sec, 0.2)
	_color = color
	_ensure_visual()
	_apply_ring_color()


func _ready() -> void:
	_ensure_visual()


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _ensure_visual() -> void:
	if _ring != null:
		return
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 1.35
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = mat
	add_child(_ring)
	_apply_ring_color()


func _apply_ring_color() -> void:
	if _ring == null or not (_ring.material_override is StandardMaterial3D):
		return
	var mat := _ring.material_override as StandardMaterial3D
	mat.albedo_color = _color
	mat.emission = Color(_color.r * 0.85, _color.g * 0.85, _color.b * 0.85)
