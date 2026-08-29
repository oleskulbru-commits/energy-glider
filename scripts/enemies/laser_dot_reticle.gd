class_name LaserDotReticle
extends Node3D

const DotReticleScript := preload("res://scripts/enemies/laser_dot_reticle.gd")

## Red warning ring for dot-lock laser telegraph.

const LIFE_SEC := 1.05

var _ring: MeshInstance3D


static func spawn(tree: SceneTree, world_pos: Vector3, life_sec: float = LIFE_SEC) -> Node3D:
	var dot: Node3D = DotReticleScript.new()
	var parent := tree.current_scene if tree != null else null
	if parent == null:
		return dot
	parent.add_child(dot)
	dot.place(world_pos, life_sec)
	return dot


func place(world_pos: Vector3, life_sec: float = LIFE_SEC) -> void:
	global_position = world_pos + Vector3(0.0, 0.12, 0.0)
	set_meta("_life", maxf(life_sec, 0.1))
	_ensure_visual()


func _ready() -> void:
	set_meta("_life", LIFE_SEC)
	_ensure_visual()


func _physics_process(delta: float) -> void:
	var life: float = float(get_meta("_life", LIFE_SEC))
	life -= delta
	set_meta("_life", life)
	if life <= 0.0:
		queue_free()


func follow(world_pos: Vector3) -> void:
	global_position = world_pos + Vector3(0.0, 0.12, 0.0)


func _ensure_visual() -> void:
	if _ring != null:
		return
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 1.25
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.12, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.08)
	mat.emission_energy_multiplier = 2.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = mat
	add_child(_ring)
