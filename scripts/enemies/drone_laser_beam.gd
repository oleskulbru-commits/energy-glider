class_name DroneLaserBeam
extends Node3D

## Ground-aimed enemy laser. Sweeps toward the player at cruise speed.

const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")

const FIRE_SEC := 5.0
const RELOAD_SEC := 5.0
const TICK_SEC := 0.5
const DAMAGE := 4
const OPEN_AHEAD_M := 15.0
const HIT_RADIUS_M := 1.8
const HIT_MAX_ABOVE_M := 3.5
const RADIUS_CORE := 0.12
const RADIUS_GLOW := 0.2

var active := false
var finished := false

var _fire_left := 0.0
var _next_tick := 0.0
var _aim := Vector3.ZERO
var _terrain: TerrainManager
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _core_mesh: CylinderMesh
var _glow_mesh: CylinderMesh
var _spot: MeshInstance3D


func begin(origin: Vector3, player: Node3D, facing: Vector3, terrain: TerrainManager) -> void:
	_terrain = terrain
	_aim = _open_aim(player, facing)
	_fire_left = FIRE_SEC
	_next_tick = TICK_SEC
	active = true
	finished = false
	_ensure_visuals()
	_show(origin)
	_deal_tick(player)


func advance(delta: float, origin: Vector3, player: Node3D, facing: Vector3, allow_fire: bool) -> void:
	if finished or not active:
		return
	if not allow_fire:
		cancel()
		return
	_fire_left -= delta
	if _fire_left <= 0.0:
		_finish()
		return
	_chase_aim(delta, player)
	_show(origin)
	_next_tick -= delta
	while _next_tick <= 0.0 and active and not finished:
		_deal_tick(player)
		_next_tick += TICK_SEC


func cancel() -> void:
	_finish()


func _finish() -> void:
	active = false
	finished = true
	_hide()


func _open_aim(player: Node3D, facing: Vector3) -> Vector3:
	var fwd := Vector3(facing.x, 0.0, facing.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(-1.0, 0.0, 0.0)
	else:
		fwd = fwd.normalized()
	var xz := player.global_position + fwd * OPEN_AHEAD_M
	return _ground_at(xz.x, xz.z)


func _chase_aim(delta: float, player: Node3D) -> void:
	var goal := _ground_at(player.global_position.x, player.global_position.z)
	var flat := Vector3(goal.x - _aim.x, 0.0, goal.z - _aim.z)
	var step := GliderPhysicsScript.CRUISE_MAX_GROUND_SPEED * delta
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


func _deal_tick(player: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	var delta := player.global_position - _aim
	if delta.y > HIT_MAX_ABOVE_M:
		return
	var flat := Vector2(delta.x, delta.z)
	if flat.length() > HIT_RADIUS_M:
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

	_spot = MeshInstance3D.new()
	var disc := TorusMesh.new()
	disc.inner_radius = 0.55
	disc.outer_radius = 1.1
	_spot.mesh = disc
	var spot_mat := StandardMaterial3D.new()
	spot_mat.albedo_color = Color(1.0, 0.25, 0.15, 0.85)
	spot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spot_mat.emission_enabled = true
	spot_mat.emission = Color(1.0, 0.2, 0.1)
	spot_mat.emission_energy_multiplier = 1.5
	_spot.material_override = spot_mat
	add_child(_spot)


func _show(origin: Vector3) -> void:
	var to := _aim
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
	_spot.visible = true
	_spot.top_level = true
	_spot.global_position = _aim + Vector3(0.0, 0.1, 0.0)
	_spot.global_basis = Basis.IDENTITY


func _hide() -> void:
	if _core != null:
		_core.visible = false
	if _glow != null:
		_glow.visible = false
	if _spot != null:
		_spot.visible = false
