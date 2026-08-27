class_name DroneRocket
extends Area3D

## Lofted hail rocket using player rocket visuals. Dives to a marked impact.

const RocketMissileScript = preload("res://scripts/weapons/rocket_missile.gd")
const RocketMissileScene = preload("res://scenes/weapons/rocket_missile.tscn")

const DAMAGE := 10
const BLAST_RADIUS_M := 2.2
const BLAST_MAX_ABOVE_M := 4.0
const DIVE_HOMING := 0.9

var _impact := Vector3.ZERO
var _dir := Vector3.UP
var _boost_left := RocketMissileScript.BOOST_SEC
var _speed := RocketMissileScript.SPEED_MPS
var _spent := false
var _terrain: TerrainManager


func launch_from_drone(
	origin: Vector3,
	impact: Vector3,
	terrain: TerrainManager = null
) -> void:
	_terrain = terrain
	var ground_y := impact.y
	if terrain != null:
		ground_y = terrain.sample_height(impact.x, impact.z)
	_impact = Vector3(impact.x, ground_y, impact.z)
	global_position = origin
	_dir = Vector3.UP
	_boost_left = RocketMissileScript.BOOST_SEC
	_speed = RocketMissileScript.SPEED_MPS
	_spent = false
	_steal_player_visuals()
	_orient()


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_boost_left = maxf(_boost_left - delta, 0.0)
	if _boost_left > 0.0:
		_dir = Vector3.UP
	else:
		var aim := _impact - global_position
		if aim.length_squared() > 0.0001:
			_dir = _dir.lerp(aim.normalized(), DIVE_HOMING).normalized()
	global_position += _dir * _speed * delta
	_orient()
	# Detonate near the marked impact (XZ + height).
	var flat := Vector2(global_position.x - _impact.x, global_position.z - _impact.z)
	if flat.length() <= BLAST_RADIUS_M and global_position.y <= _impact.y + 1.5:
		_detonate()
		return
	if global_position.y < _impact.y - 2.0:
		_detonate()


func _detonate() -> void:
	_spent = true
	var body := _find_player_body()
	if body != null and is_instance_valid(body):
		var delta := body.global_position - _impact
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


func _steal_player_visuals() -> void:
	# Build the same capsule/streak/trail as rocket_missile.tscn without running its script.
	if get_node_or_null("Visual") != null:
		return
	var template: Node = RocketMissileScene.instantiate()
	for child_name in ["Visual", "Streak", "Trail"]:
		var src := template.get_node_or_null(child_name)
		if src == null:
			continue
		var copy := src.duplicate()
		add_child(copy)
	template.queue_free()


func _orient() -> void:
	if _dir.length_squared() < 0.0001:
		return
	if absf(_dir.dot(Vector3.UP)) > 0.98:
		look_at(global_position + _dir, Vector3.FORWARD)
	else:
		look_at(global_position + _dir, Vector3.UP)
