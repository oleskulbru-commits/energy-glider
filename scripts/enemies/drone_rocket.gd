class_name DroneRocket
extends Node3D

## Descending hail rocket. No mid-flight homing — hits the marked XZ.

const DAMAGE := 10
const FALL_SPEED_MPS := 28.0
const SPAWN_HEIGHT_M := 22.0
const BLAST_RADIUS_M := 2.2
const BLAST_MAX_ABOVE_M := 4.0

var _target_xz := Vector3.ZERO
var _spent := false
var _mesh: MeshInstance3D


func launch(impact: Vector3, terrain: TerrainManager = null) -> void:
	var ground_y := impact.y
	if terrain != null:
		ground_y = terrain.sample_height(impact.x, impact.z)
	_target_xz = Vector3(impact.x, ground_y, impact.z)
	global_position = Vector3(impact.x, ground_y + SPAWN_HEIGHT_M, impact.z)
	_spent = false
	_ensure_visual()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	global_position.y -= FALL_SPEED_MPS * delta
	if global_position.y <= _target_xz.y + 0.15:
		_detonate()


func _detonate() -> void:
	_spent = true
	var body := _find_player_body()
	if body != null and is_instance_valid(body):
		var delta := body.global_position - _target_xz
		if delta.y <= BLAST_MAX_ABOVE_M:
			var flat := Vector2(delta.x, delta.z)
			if flat.length() <= BLAST_RADIUS_M:
				var health := get_tree().get_first_node_in_group("player_health")
				if health != null and health.has_method("take_damage"):
					health.take_damage(DAMAGE)
	queue_free()


func _find_player_body() -> Node3D:
	var health := get_tree().get_first_node_in_group("player_health")
	if health != null:
		var parent := health.get_parent()
		if parent is PlayerRig:
			var body := (parent as PlayerRig).get_active_body()
			if body != null:
				return body
		if parent != null and parent.has_method("get_glider"):
			var glider: Variant = parent.get_glider()
			if glider is Node3D:
				return glider as Node3D
	return null


func _ensure_visual() -> void:
	if _mesh != null:
		return
	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.18
	capsule.height = 0.7
	_mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.45, 1.0)
	mat.emission_energy_multiplier = 1.4
	_mesh.material_override = mat
	add_child(_mesh)
