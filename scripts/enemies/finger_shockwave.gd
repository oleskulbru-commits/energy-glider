class_name FingerShockwave
extends Node3D

## Expanding sand ring at Finger impact. Visual only.

const RADIUS_M := 10.0
const LIFE_SEC := 0.48
const GROUND_LIFT_M := 0.16
const RING_COLOR := Color(0.55, 0.08, 0.04, 0.85)
const RING_WIDTH_M := 0.55

var _life := LIFE_SEC
var _ring: MeshInstance3D
var _torus: TorusMesh
var _mat: StandardMaterial3D


static func spawn(
	tree: SceneTree,
	impact: Vector3,
	terrain: TerrainManager = null
) -> FingerShockwave:
	var wave := FingerShockwave.new()
	var parent: Node = null
	if tree != null:
		parent = tree.current_scene
		if parent == null:
			parent = tree.root
	if parent != null:
		parent.add_child(wave)
	var ground_y := impact.y
	if terrain != null:
		ground_y = terrain.sample_height(impact.x, impact.z)
	wave.global_position = Vector3(impact.x, ground_y + GROUND_LIFT_M, impact.z)
	return wave


func _ready() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_torus = TorusMesh.new()
	_torus.inner_radius = 0.08
	_torus.outer_radius = 0.35
	_ring.mesh = _torus
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 3.2
	_mat.albedo_color = RING_COLOR
	_mat.emission = Color(0.85, 0.18, 0.06)
	_ring.material_override = _mat
	add_child(_ring)
	SandImpactDust.spawn(get_tree(), global_position, null)


func _physics_process(delta: float) -> void:
	_life -= delta
	var t := 1.0 - clampf(_life / LIFE_SEC, 0.0, 1.0)
	var radius := lerpf(0.35, RADIUS_M, t)
	_torus.inner_radius = maxf(radius - RING_WIDTH_M, 0.05)
	_torus.outer_radius = radius
	if _mat != null:
		var fade := 1.0 - t
		_mat.albedo_color.a = RING_COLOR.a * fade
		_mat.emission_energy_multiplier = 3.2 * fade
	if _life <= 0.0:
		queue_free()
