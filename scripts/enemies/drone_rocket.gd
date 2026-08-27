class_name DroneRocket
extends Area3D

## Lofted hail rocket using player rocket visuals. Reaches its mark in FLIGHT_SEC.

const RocketMissileScene = preload("res://scenes/weapons/rocket_missile.tscn")

const DAMAGE := 10
const BLAST_RADIUS_M := 2.2
const BLAST_MAX_ABOVE_M := 4.0
const FLIGHT_SEC := 1.5
const LOFT_PEAK_M := 8.0
const TRAIL_COLOR := Color(0.25, 0.55, 1.0, 1.0)
const TRAIL_EMISSION := Color(0.15, 0.45, 1.0, 1.0)

var _origin := Vector3.ZERO
var _impact := Vector3.ZERO
var _flight_t := 0.0
var _dir := Vector3.UP
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
	_origin = origin
	_impact = Vector3(impact.x, ground_y, impact.z)
	_flight_t = 0.0
	_spent = false
	global_position = _origin
	_dir = arc_velocity(_origin, _impact, 0.0)
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
	_flight_t += delta / FLIGHT_SEC
	if _flight_t >= 1.0:
		global_position = _impact
		_detonate()
		return
	global_position = arc_position(_origin, _impact, _flight_t)
	_dir = arc_velocity(_origin, _impact, _flight_t)
	_orient()


static func arc_position(
	origin: Vector3,
	impact: Vector3,
	t: float,
	loft_m: float = LOFT_PEAK_M
) -> Vector3:
	var u := clampf(t, 0.0, 1.0)
	if u <= 0.0:
		return origin
	if u >= 1.0:
		return impact
	var control := Vector3(
		(origin.x + impact.x) * 0.5,
		maxf(origin.y, impact.y) + loft_m,
		(origin.z + impact.z) * 0.5
	)
	var inv := 1.0 - u
	return (
		inv * inv * origin
		+ 2.0 * inv * u * control
		+ u * u * impact
	)


static func arc_velocity(
	origin: Vector3,
	impact: Vector3,
	t: float,
	loft_m: float = LOFT_PEAK_M
) -> Vector3:
	var eps := 0.01
	var ahead := clampf(t + eps, 0.0, 1.0)
	var behind := clampf(t - eps, 0.0, 1.0)
	var delta := arc_position(origin, impact, ahead, loft_m) - arc_position(origin, impact, behind, loft_m)
	if delta.length_squared() < 0.0001:
		return Vector3.DOWN
	return delta.normalized()


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
		if child_name == "Trail" and copy is CPUParticles3D:
			_tint_trail_blue(copy as CPUParticles3D)
		add_child(copy)
	template.queue_free()


func _tint_trail_blue(trail: CPUParticles3D) -> void:
	trail.color = TRAIL_COLOR
	if trail.material_override is StandardMaterial3D:
		var mat := (trail.material_override as StandardMaterial3D).duplicate()
		mat.albedo_color = TRAIL_COLOR
		mat.emission = TRAIL_EMISSION
		trail.material_override = mat


func _orient() -> void:
	if _dir.length_squared() < 0.0001:
		return
	if absf(_dir.dot(Vector3.UP)) > 0.98:
		look_at(global_position + _dir, Vector3.FORWARD)
	else:
		look_at(global_position + _dir, Vector3.UP)
