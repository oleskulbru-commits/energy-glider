class_name VestigePickup
extends Node3D

## White sphere dropped by a ground enemy. Hops, rests, then pulls in at 10 m.

const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const VestigeWalletScript := preload("res://scripts/game/vestige_wallet.gd")

const RADIUS_M := 0.3
const PULL_RANGE_M := 10.0
const COLLECT_RANGE_M := 1.2
const DESPAWN_BEHIND_M := 400.0
const HOP_SPEED := 6.0
const HOP_UP := 4.5
const GRAVITY := 18.0
const PULL_SPEED := 36.0
const GROUND_CLEARANCE_M := 0.02

enum Phase { HOP, REST, PULL }

var _terrain: TerrainManager
var _vel := Vector3.ZERO
var _phase := Phase.HOP
var _collected := false


static func spawn(
	tree: SceneTree,
	corpse_pos: Vector3,
	hit_pos: Vector3,
	terrain: TerrainManager
) -> VestigePickup:
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null
	var pickup := VestigePickup.new()
	parent.add_child(pickup)
	pickup.global_position = corpse_pos + Vector3.UP * RADIUS_M
	pickup.setup(hit_pos, terrain)
	return pickup


static func should_commit_pull(
	distance_m: float,
	already_pulling: bool,
	range_m: float = PULL_RANGE_M
) -> bool:
	return already_pulling or distance_m <= range_m


static func has_arrived(distance_m: float, collect_m: float = COLLECT_RANGE_M) -> bool:
	return distance_m <= collect_m


func setup(hit_pos: Vector3, terrain: TerrainManager) -> void:
	_terrain = terrain
	var away := global_position - hit_pos
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(1.0, 0.0, 0.0)
	else:
		away = away.normalized()
	_vel = away * HOP_SPEED + Vector3.UP * HOP_UP


func _ready() -> void:
	add_to_group("vestige_pickup")
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Sphere"
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS_M
	mesh.height = RADIUS_M * 2.0
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.35
	mesh_node.material_override = mat
	add_child(mesh_node)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if _run_has_ended():
		discard()
		return
	if _is_abandoned():
		queue_free()
		return
	if _phase == Phase.REST and _player_distance() <= PULL_RANGE_M:
		_phase = Phase.PULL
	if _phase == Phase.HOP:
		_tick_hop(delta)
	elif _phase == Phase.PULL:
		_tick_pull(delta)
	else:
		_snap_to_ground()


func _tick_hop(delta: float) -> void:
	_vel.y -= GRAVITY * delta
	global_position += _vel * delta
	var floor_y := _floor_center_y()
	if _vel.y <= 0.0 and global_position.y <= floor_y:
		global_position.y = floor_y
		_vel = Vector3.ZERO
		_phase = Phase.REST


func _tick_pull(delta: float) -> void:
	var body := _player_body()
	if body == null:
		_snap_to_ground()
		return
	var to := body.global_position - global_position
	var dist := to.length()
	if has_arrived(dist):
		_collect()
		return
	global_position += to / dist * PULL_SPEED * delta


func discard() -> void:
	_collected = true
	set_physics_process(false)
	queue_free()


func _collect() -> void:
	if _collected:
		return
	_collected = true
	var wallet = VestigeWalletScript.find(get_tree())
	if wallet != null:
		wallet.collect_one()
	queue_free()


func _snap_to_ground() -> void:
	global_position.y = _floor_center_y()


func _floor_center_y() -> float:
	var ground := global_position.y - RADIUS_M
	if _terrain != null:
		ground = _terrain.sample_height(global_position.x, global_position.z)
	return ground + GROUND_CLEARANCE_M + RADIUS_M


func _player_distance() -> float:
	var body := _player_body()
	if body == null:
		return INF
	return global_position.distance_to(body.global_position)


func _is_abandoned() -> bool:
	var body := _player_body()
	if body == null:
		return false
	# Loaded at runtime so this pickup does not preload SwarmPill (that script preloads the drop roll).
	var swarm_script: GDScript = load("res://scripts/enemies/swarm_pill.gd")
	return swarm_script.is_behind_facing(
		body.global_position,
		_player_facing(),
		global_position,
		DESPAWN_BEHIND_M
	)


func _run_has_ended() -> bool:
	var body := _player_body()
	return body != null and body.has_method("is_run_ended") and body.is_run_ended()


func _player_body() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var rig := tree.get_first_node_in_group("player_rig")
	if rig != null and rig.has_method("get_active_body"):
		return rig.get_active_body()
	return null


func _player_facing() -> Vector3:
	var body := _player_body()
	if body != null and body is GliderPlayer:
		var fwd := MathUtil.yaw_forward((body as GliderPlayer).get_yaw())
		if fwd.length_squared() >= 0.0001:
			return fwd.normalized()
	return Vector3(-1.0, 0.0, 0.0)
