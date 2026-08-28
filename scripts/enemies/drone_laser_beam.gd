class_name DroneLaserBeam
extends Node3D

## Ground-aimed enemy laser. Sweeps toward the player at cruise speed.

const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")

const FIRE_SEC := 5.0
const RELOAD_SEC := 5.0
const TICK_SEC := 0.5
const DAMAGE := 4
const LEAD_SEC := 1.0
const AHEAD_MIN_M := 10.0
const HIT_RADIUS_M := 1.8
const HIT_MAX_ABOVE_M := 3.5
const HIT_RADIUS_AIR_M := 2.2
const MISS_BEAM_RANGE_M := 140.0
const RADIUS_CORE := 0.12
const RADIUS_GLOW := 0.2
const ZIGZAG_SEC := 2.25
const ZIGZAG_AMPLITUDE_GROUND_M := 6.0
const ZIGZAG_AMPLITUDE_AIR_M := 4.0
const ZIGZAG_HZ := 0.55

var active := false
var finished := false
var zigzagging := false

var _fire_left := 0.0
var _next_tick := 0.0
var _aim := Vector3.ZERO
var _terrain: TerrainManager
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _core_mesh: CylinderMesh
var _glow_mesh: CylinderMesh
var _zigzag_left := 0.0
var _zigzag_t := 0.0
var _facing := Vector3(-1.0, 0.0, 0.0)


func begin(
	origin: Vector3,
	player: Node3D,
	facing: Vector3,
	terrain: TerrainManager,
	zigzag_first: bool = false,
	air_targeting: bool = false
) -> void:
	_terrain = terrain
	_set_facing(facing)
	if air_targeting:
		_aim = _lead_goal_air(player, _facing)
	else:
		_aim = _lead_goal_ground(player, _facing)
	_fire_left = FIRE_SEC
	_next_tick = TICK_SEC
	active = true
	finished = false
	zigzagging = zigzag_first
	_zigzag_left = ZIGZAG_SEC if zigzag_first else 0.0
	_zigzag_t = 0.0
	_ensure_visuals()
	_show(origin, player, air_targeting)
	_deal_tick(player, air_targeting)


func advance(
	delta: float,
	origin: Vector3,
	player: Node3D,
	facing: Vector3,
	allow_fire: bool,
	air_targeting: bool = false
) -> void:
	if finished or not active:
		return
	if not allow_fire:
		cancel()
		return
	_set_facing(facing)
	_fire_left -= delta
	if _fire_left <= 0.0:
		_finish()
		return
	if zigzagging:
		if air_targeting:
			_zigzag_aim_air(delta, player)
		else:
			_zigzag_aim(delta, player)
	else:
		if air_targeting:
			_chase_aim_air(delta, player)
		else:
			_chase_aim(delta, player)
	_show(origin, player, air_targeting)
	_next_tick -= delta
	while _next_tick <= 0.0 and active and not finished:
		_deal_tick(player, air_targeting)
		_next_tick += TICK_SEC


func cancel() -> void:
	_finish()


func _finish() -> void:
	active = false
	finished = true
	zigzagging = false
	_hide()


func _set_facing(facing: Vector3) -> void:
	_facing = Vector3(facing.x, 0.0, facing.z)
	if _facing.length_squared() < 0.0001:
		_facing = Vector3(-1.0, 0.0, 0.0)
	else:
		_facing = _facing.normalized()


func _player_velocity(player: Node3D) -> Vector3:
	if player is GliderPlayer:
		return (player as GliderPlayer).linear_velocity
	if player is CharacterBody3D:
		return (player as CharacterBody3D).velocity
	if player is RigidBody3D:
		return (player as RigidBody3D).linear_velocity
	return Vector3.ZERO


func _lead_goal_ground(player: Node3D, facing: Vector3) -> Vector3:
	var pos := player.global_position
	var vel := _player_velocity(player)
	var horiz := Vector3(vel.x, 0.0, vel.z)
	var lead := pos + horiz * LEAD_SEC
	var ahead := Vector3(lead.x - pos.x, 0.0, lead.z - pos.z)
	if ahead.dot(facing) < 4.0:
		lead = pos + facing * maxf(horiz.length() * LEAD_SEC, AHEAD_MIN_M)
	return _ground_at(lead.x, lead.z)


func _lead_goal_air(player: Node3D, facing: Vector3) -> Vector3:
	var pos := player.global_position
	var vel := _player_velocity(player)
	var lead := pos + vel * LEAD_SEC
	var ahead := Vector3(lead.x - pos.x, 0.0, lead.z - pos.z)
	if ahead.dot(facing) < 4.0:
		var horiz := Vector3(vel.x, 0.0, vel.z)
		lead = pos + facing * maxf(horiz.length() * LEAD_SEC, AHEAD_MIN_M)
		lead.y = pos.y + vel.y * LEAD_SEC
	return lead


func _zigzag_aim(delta: float, player: Node3D) -> void:
	_zigzag_left = maxf(_zigzag_left - delta, 0.0)
	_zigzag_t += delta
	if _zigzag_left <= 0.0:
		zigzagging = false
		_chase_aim(delta, player)
		return
	var right := Vector3(_facing.z, 0.0, -_facing.x)
	var lateral := sin(_zigzag_t * TAU * ZIGZAG_HZ) * ZIGZAG_AMPLITUDE_GROUND_M
	var goal := _lead_goal_ground(player, _facing) + right * lateral
	goal = _ground_at(goal.x, goal.z)
	_move_aim_toward(goal, delta, false)


func _zigzag_aim_air(delta: float, player: Node3D) -> void:
	_zigzag_left = maxf(_zigzag_left - delta, 0.0)
	_zigzag_t += delta
	if _zigzag_left <= 0.0:
		zigzagging = false
		_chase_aim_air(delta, player)
		return
	var right := Vector3(_facing.z, 0.0, -_facing.x)
	var lateral := sin(_zigzag_t * TAU * ZIGZAG_HZ) * ZIGZAG_AMPLITUDE_AIR_M
	var goal := _lead_goal_air(player, _facing) + right * lateral
	_move_aim_toward(goal, delta, true)


func _chase_aim(delta: float, player: Node3D) -> void:
	var goal := _lead_goal_ground(player, _facing)
	_move_aim_toward(goal, delta, false)


func _chase_aim_air(delta: float, player: Node3D) -> void:
	var goal := _lead_goal_air(player, _facing)
	_move_aim_toward(goal, delta, true)


func _move_aim_toward(goal: Vector3, delta: float, air: bool) -> void:
	var step := GliderPhysicsScript.CRUISE_MAX_GROUND_SPEED * delta
	if air:
		var to := goal - _aim
		if to.length() <= step:
			_aim = goal
		else:
			_aim += to.normalized() * step
		return
	var flat := Vector3(goal.x - _aim.x, 0.0, goal.z - _aim.z)
	if flat.length() <= step:
		_aim = goal
	else:
		_aim += flat.normalized() * step
		_aim = _ground_at(_aim.x, _aim.z)


func _ground_at(x: float, z: float) -> Vector3:
	var y := 0.0
	if _terrain != null:
		y = _terrain.sample_height(x, z)
	return Vector3(x, y, z)


func _is_player_in_hit_range(player: Node3D, air_targeting: bool) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var delta := player.global_position - _aim
	if air_targeting:
		return delta.length() <= HIT_RADIUS_AIR_M
	if delta.y > HIT_MAX_ABOVE_M:
		return false
	return Vector2(delta.x, delta.z).length() <= HIT_RADIUS_M


func _visual_beam_end(origin: Vector3, player: Node3D, air_targeting: bool) -> Vector3:
	if _is_player_in_hit_range(player, air_targeting):
		return _aim
	var dir := _aim - origin
	if dir.length_squared() < 0.0001:
		return _aim
	return origin + dir.normalized() * MISS_BEAM_RANGE_M


func _deal_tick(player: Node3D, air_targeting: bool = false) -> void:
	if not _is_player_in_hit_range(player, air_targeting):
		return
	var health := get_tree().get_first_node_in_group("player_health")
	if health != null and health.has_method("take_damage"):
		health.take_damage(DAMAGE)


func _ensure_visuals() -> void:
	if _core != null:
		return

	_core_mesh = CylinderMesh.new()
	_core_mesh.top_radius = RADIUS_CORE
	_core_mesh.bottom_radius = RADIUS_CORE
	_core_mesh.height = 1.0
	_core = MeshInstance3D.new()
	_core.mesh = _core_mesh
	_core.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.2, 0.15)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.25, 0.1)
	core_mat.emission_energy_multiplier = 2.5
	_core.material_override = core_mat
	add_child(_core)

	_glow_mesh = CylinderMesh.new()
	_glow_mesh.top_radius = RADIUS_GLOW
	_glow_mesh.bottom_radius = RADIUS_GLOW
	_glow_mesh.height = 1.0
	_glow = MeshInstance3D.new()
	_glow.mesh = _glow_mesh
	_glow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.35, 0.2, 0.35)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.3, 0.15)
	glow_mat.emission_energy_multiplier = 1.2
	_glow.material_override = glow_mat
	add_child(_glow)


func _show(origin: Vector3, player: Node3D, air_targeting: bool) -> void:
	var to := _visual_beam_end(origin, player, air_targeting)
	var dir := to - origin
	var length := dir.length()
	if length < 0.08:
		_hide()
		return
	global_position = origin
	if absf(dir.normalized().dot(Vector3.UP)) > 0.98:
		look_at(to, Vector3.FORWARD)
	else:
		look_at(to, Vector3.UP)
	_core_mesh.height = length
	_glow_mesh.height = length
	var mid := Vector3(0.0, 0.0, -length * 0.5)
	_core.position = mid
	_glow.position = mid
	_core.visible = true
	_glow.visible = true


func _hide() -> void:
	if _core != null:
		_core.visible = false
	if _glow != null:
		_glow.visible = false
