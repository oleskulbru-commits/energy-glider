class_name GroundReticle
extends Node3D

## Flat aiming ring on the sand for incoming drone rockets.

const LIFE_SEC := 1.4

var _life := LIFE_SEC
var _ring: MeshInstance3D


func place(world_pos: Vector3, life_sec: float = LIFE_SEC) -> void:
	global_position = world_pos + Vector3(0.0, 0.12, 0.0)
	_life = maxf(life_sec, 0.2)
	_ensure_visual()


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
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = mat
	add_child(_ring)
