class_name DroneRocket
extends Area3D

## Lofted hail rocket with drone missile mesh and energy streak VFX.

const DroneMissileProjectileScene = preload("res://scenes/enemies/drone_missile_projectile.tscn")
const DroneGroundBlastScript = preload("res://scripts/enemies/drone_ground_blast.gd")

enum FlightMode { GROUND_ARC, AIR_LINEAR }

const DAMAGE := 10
const BLAST_RADIUS_M := 2.2
const BLAST_MAX_ABOVE_M := 4.0
const AIR_BLAST_RADIUS_M := 2.0
const FLIGHT_SEC := 1.2
const LOFT_PEAK_M := 8.0
const PASS_THROUGH_SEC := 1.5
const PASS_THROUGH_DISTANCE_M := 60.0
const TRAIL_COLOR := Color(0.25, 0.55, 1.0, 1.0)
const TRAIL_EMISSION := Color(0.15, 0.45, 1.0, 1.0)

var _origin := Vector3.ZERO
var _impact := Vector3.ZERO
var _flight_t := 0.0
var _dir := Vector3.UP
var _spent := false
var _terrain: TerrainManager
var _flight_mode := FlightMode.GROUND_ARC
var _pass_through := false
var _pass_vel := Vector3.ZERO
var _pass_ttl := 0.0
var _pass_traveled := 0.0
var _flight_speed_mps := 0.0


func launch_from_drone(
	origin: Vector3,
	impact: Vector3,
	terrain: TerrainManager = null,
	spawn_transform: Transform3D = Transform3D.IDENTITY,
	visual_template: Node = null
) -> void:
	_flight_mode = FlightMode.GROUND_ARC
	_pass_through = false
	_terrain = terrain
	var ground_y := impact.y
	if terrain != null:
		ground_y = terrain.sample_height(impact.x, impact.z)
	_origin = origin
	_impact = Vector3(impact.x, ground_y, impact.z)
	_flight_t = 0.0
	_spent = false
	_apply_spawn_transform(spawn_transform, origin)
	_dir = arc_velocity(_origin, _impact, 0.0)
	_attach_projectile_visual(visual_template)
	_orient()


func launch_to_air_point(
	origin: Vector3,
	impact_3d: Vector3,
	spawn_transform: Transform3D = Transform3D.IDENTITY,
	visual_template: Node = null
) -> void:
	_flight_mode = FlightMode.AIR_LINEAR
	_pass_through = false
	_terrain = null
	_origin = origin
	_impact = impact_3d
	_flight_t = 0.0
	_spent = false
	_apply_spawn_transform(spawn_transform, origin)
	var delta := _impact - _origin
	if delta.length_squared() < 0.0001:
		_dir = Vector3.FORWARD
		_flight_speed_mps = 0.0
	else:
		_dir = delta.normalized()
		_flight_speed_mps = delta.length() / FLIGHT_SEC
	_attach_projectile_visual(visual_template)
	_orient()


func _apply_spawn_transform(spawn_transform: Transform3D, origin: Vector3) -> void:
	if spawn_transform != Transform3D.IDENTITY:
		global_position = spawn_transform.origin
		_origin = global_position
	else:
		global_position = origin


func uses_drone_missile_visual() -> bool:
	return get_node_or_null("ProjectileVisual") != null


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0


func _physics_process(delta: float) -> void:
	if _spent:
		return
	if _pass_through:
		_tick_pass_through(delta)
		return
	if _flight_mode == FlightMode.AIR_LINEAR:
		_physics_process_air(delta)
		return
	_flight_t += delta / FLIGHT_SEC
	if _flight_t >= 1.0:
		global_position = _impact
		_detonate()
		return
	global_position = arc_position(_origin, _impact, _flight_t)
	_dir = arc_velocity(_origin, _impact, _flight_t)
	_orient()


func _physics_process_air(delta: float) -> void:
	_flight_t += delta / FLIGHT_SEC
	if _flight_t < 1.0:
		global_position = _origin.lerp(_impact, _flight_t)
		var travel := _impact - _origin
		if travel.length_squared() > 0.0001:
			_dir = travel.normalized()
		_orient()
		if _try_air_hit_at(global_position):
			return
		return
	global_position = _impact
	if _try_air_hit_at(_impact):
		return
	_begin_pass_through()


func _tick_pass_through(delta: float) -> void:
	var step := _pass_vel * delta
	global_position += step
	_pass_traveled += step.length()
	_pass_ttl -= delta
	_orient()
	if _pass_ttl <= 0.0 or _pass_traveled >= PASS_THROUGH_DISTANCE_M:
		queue_free()


func _begin_pass_through() -> void:
	_pass_through = true
	var dir := _dir
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	_pass_vel = dir * _flight_speed_mps
	_pass_ttl = PASS_THROUGH_SEC
	_pass_traveled = 0.0


func _try_air_hit_at(point: Vector3) -> bool:
	var body := _find_player_body()
	if body == null or not is_instance_valid(body):
		return false
	if body.global_position.distance_to(point) > AIR_BLAST_RADIUS_M:
		return false
	_spent = true
	var health := get_tree().get_first_node_in_group("player_health")
	if health != null and health.has_method("take_damage"):
		health.take_damage(DAMAGE)
	queue_free()
	return true


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
	if _flight_mode == FlightMode.GROUND_ARC:
		DroneGroundBlastScript.spawn(get_tree(), _impact, _terrain)
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


func _attach_projectile_visual(visual_template: Node = null) -> void:
	if get_node_or_null("ProjectileVisual") != null:
		return
	var visual_root := Node3D.new()
	visual_root.name = "ProjectileVisual"
	add_child(visual_root)
	var from_template := false
	if visual_template != null and _duplicate_template_visuals(visual_root, visual_template):
		from_template = true
		_tint_projectile_vfx(visual_root)
		_align_projectile_visual(visual_root, from_template)
		return
	var fallback: Node3D = DroneMissileProjectileScene.instantiate()
	visual_root.add_child(fallback)
	_tint_projectile_vfx(visual_root)
	_align_projectile_visual(visual_root, false)


func _duplicate_template_visuals(visual_root: Node3D, visual_template: Node) -> bool:
	var copied := false
	if visual_template is MeshInstance3D or visual_template is CSGShape3D:
		visual_root.add_child(visual_template.duplicate())
		return true
	for child in visual_template.get_children():
		if child is Node3D:
			visual_root.add_child(child.duplicate())
			copied = true
	return copied


func _tint_projectile_vfx(root: Node) -> void:
	var streak := root.find_child("Streak", true, false) as MeshInstance3D
	if streak != null:
		_tint_streak_blue(streak)


func _tint_streak_blue(streak: MeshInstance3D) -> void:
	var mat := streak.material_override
	if mat is ShaderMaterial:
		var shader_mat := (mat as ShaderMaterial).duplicate()
		shader_mat.set_shader_parameter(
			"ColorParameter",
			Color(TRAIL_COLOR.r * 1.6, TRAIL_COLOR.g * 1.4, TRAIL_COLOR.b * 1.6, 0.85)
		)
		shader_mat.set_shader_parameter("GlowStrength", 3.0)
		streak.material_override = shader_mat
	elif mat is StandardMaterial3D:
		var std_mat := (mat as StandardMaterial3D).duplicate()
		std_mat.albedo_color = Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, 0.65)
		std_mat.emission = TRAIL_EMISSION
		streak.material_override = std_mat


func _align_projectile_visual(visual_root: Node3D, _from_template: bool) -> void:
	# GLB missile meshes point +Z; DroneRocket travel forward is -Z (Basis.looking_at).
	visual_root.basis = Basis.from_euler(Vector3(0.0, PI, 0.0))


func _orient() -> void:
	if _dir.length_squared() < 0.0001:
		return
	var up := Vector3.UP
	if absf(_dir.dot(up)) > 0.98:
		up = Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(_dir, up), global_position)
