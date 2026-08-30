class_name DroneLaserBeam
extends Node3D

## Enemy laser with weighted attack patterns. Shared beam visuals + tick damage.

const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const DroneLaserPatternsScript = preload("res://scripts/enemies/drone_laser_patterns.gd")
const LaserSweepLineScript = preload("res://scripts/enemies/laser_sweep_line.gd")
const LaserDotReticleScript = preload("res://scripts/enemies/laser_dot_reticle.gd")
const LaserArcTrailSegmentScript = preload("res://scripts/enemies/laser_arc_trail_segment.gd")

const FIRE_SEC := 5.0
const RELOAD_SEC := 5.0
const TICK_SEC := 0.5
const DAMAGE := 4
const LEAD_SEC := 1.0
const BEAM_START_AHEAD_M := 10.0
const HIT_RADIUS_M := 1.8
const HIT_MAX_ABOVE_M := 3.5
const HIT_RADIUS_AIR_M := 2.2
const MISS_BEAM_RANGE_M := 140.0
const RADIUS_CORE := 0.12
const RADIUS_GLOW := 0.2

const SWEEP_TELEGRAPH_SEC := 0.8
const SWEEP_CENTER_AHEAD_M := 12.0
const SWEEP_LENGTH_M := 28.0
const SWEEP_SPEED_MPS := 25.0

const DOT_WARN_SEC := 1.0
const DOT_FOLLOW_SCALE := 0.75

const CLOSING_TELEGRAPH_SEC := 0.8
const CLOSING_SPEED_MPS := 30.0
const CLOSING_ARRIVE_EPS_M := 0.2

const ARC_CENTER_AHEAD_M := 15.0
const ARC_SPAN_DEG := 50.0
const ARC_RADIUS_M := 10.0
const ARC_TRAIL_WIDTH_M := 2.4
const ARC_TRAIL_LINGER_SEC := 5.0
const ARC_TRAIL_MIN_STEP_M := 0.35

var active := false
var finished := false
var pattern: int = DroneLaserPatternsScript.Pattern.CLOSING_SWEEP

var _fire_left := 0.0
var _next_tick := 0.0
var _aim := Vector3.ZERO
var _terrain: TerrainManager
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _core_mesh: CylinderMesh
var _glow_mesh: CylinderMesh
var _facing := Vector3(-1.0, 0.0, 0.0)
var _air_targeting := false
var _sweep_start := Vector3.ZERO
var _sweep_end := Vector3.ZERO
var _closing_start := Vector3.ZERO
var _closing_target := Vector3.ZERO
var _arc_center := Vector3.ZERO
var _arc_trail_air_mode := false
var _arc_last_aim := Vector3.ZERO
var _arc_air_switched := false
var _sweep_line: Node3D
var _dot_reticle: Node3D
var _dot_locked := false


func begin(
	origin: Vector3,
	player: Node3D,
	facing: Vector3,
	terrain: TerrainManager,
	air_targeting: bool = false,
	attack_pattern: int = DroneLaserPatternsScript.Pattern.CLOSING_SWEEP
) -> void:
	_terrain = terrain
	_air_targeting = air_targeting
	pattern = attack_pattern
	_set_facing(facing)
	_dot_locked = false
	_cleanup_telegraphs()
	_init_pattern(player, facing)
	_fire_left = FIRE_SEC
	_next_tick = TICK_SEC
	active = true
	finished = false
	_ensure_visuals()
	_show(origin, player, air_targeting)
	if _can_damage():
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
	_air_targeting = air_targeting
	_advance_pattern(delta, player, facing)
	if pattern == DroneLaserPatternsScript.Pattern.CLOSING_SWEEP and _closing_sweep_complete():
		_finish()
		return
	_show(origin, player, air_targeting)
	_next_tick -= delta
	while _next_tick <= 0.0 and active and not finished:
		_deal_tick(player, air_targeting)
		_next_tick += TICK_SEC
	_fire_left -= delta
	if _fire_left <= 0.0:
		_finish()
		return


func cancel() -> void:
	_finish()


func _finish() -> void:
	active = false
	finished = true
	_cleanup_telegraphs()
	_hide()


func _elapsed() -> float:
	return FIRE_SEC - _fire_left


func _can_damage() -> bool:
	match pattern:
		DroneLaserPatternsScript.Pattern.FIXED_SWEEP:
			return _elapsed() >= SWEEP_TELEGRAPH_SEC
		DroneLaserPatternsScript.Pattern.WARNING_DOT:
			return _elapsed() >= DOT_WARN_SEC
		DroneLaserPatternsScript.Pattern.CLOSING_SWEEP:
			return _elapsed() >= CLOSING_TELEGRAPH_SEC
		DroneLaserPatternsScript.Pattern.ARC_BARRIER:
			return false
		_:
			return true


func _init_pattern(player: Node3D, facing: Vector3) -> void:
	match pattern:
		DroneLaserPatternsScript.Pattern.FIXED_SWEEP:
			_init_fixed_sweep(player, facing)
		DroneLaserPatternsScript.Pattern.WARNING_DOT:
			_init_warning_dot(player, facing)
		DroneLaserPatternsScript.Pattern.CLOSING_SWEEP:
			_init_closing_sweep(player, facing)
		DroneLaserPatternsScript.Pattern.ARC_BARRIER:
			_init_arc_barrier(player, facing)


func _advance_pattern(delta: float, player: Node3D, facing: Vector3) -> void:
	match pattern:
		DroneLaserPatternsScript.Pattern.FIXED_SWEEP:
			_advance_fixed_sweep(player)
		DroneLaserPatternsScript.Pattern.WARNING_DOT:
			_advance_warning_dot(delta, player)
		DroneLaserPatternsScript.Pattern.CLOSING_SWEEP:
			_advance_closing_sweep(delta, player)
		DroneLaserPatternsScript.Pattern.ARC_BARRIER:
			_advance_arc_barrier(player, facing)


func _init_fixed_sweep(player: Node3D, facing: Vector3) -> void:
	var center := player.global_position + facing * SWEEP_CENTER_AHEAD_M
	center = _snap_aim_point(center, false)
	var right := Vector3(facing.z, 0.0, -facing.x)
	var half := SWEEP_LENGTH_M * 0.5
	_sweep_start = _snap_aim_point(center - right * half, false)
	_sweep_end = _snap_aim_point(center + right * half, false)
	_aim = _sweep_start
	if get_tree() != null:
		_sweep_line = LaserSweepLineScript.spawn(
			get_tree(), _sweep_start, _sweep_end, SWEEP_TELEGRAPH_SEC
		)


func _advance_fixed_sweep(player: Node3D) -> void:
	if _elapsed() < SWEEP_TELEGRAPH_SEC:
		_aim = _sweep_start
		return
	var seg := Vector3(_sweep_end.x - _sweep_start.x, 0.0, _sweep_end.z - _sweep_start.z)
	var seg_len := seg.length()
	if seg_len < 0.01:
		_aim = _sweep_end
		return
	var travel := SWEEP_SPEED_MPS * (_elapsed() - SWEEP_TELEGRAPH_SEC)
	var t := clampf(travel / seg_len, 0.0, 1.0)
	var flat := _sweep_start.lerp(_sweep_end, t)
	_aim = _snap_aim_point(flat, false)


func _init_warning_dot(player: Node3D, facing: Vector3) -> void:
	_aim = _snap_aim_point(player.global_position, _air_targeting)
	if get_tree() != null:
		_dot_reticle = LaserDotReticleScript.spawn(get_tree(), _aim, DOT_WARN_SEC)


func _advance_warning_dot(delta: float, player: Node3D) -> void:
	if not _dot_locked and _elapsed() < DOT_WARN_SEC:
		var goal := _snap_aim_point(player.global_position, _air_targeting)
		var speed := maxf(_player_horiz_speed(player) * DOT_FOLLOW_SCALE, 4.0)
		_move_aim_toward_speed(goal, delta, _air_targeting, speed)
		if _dot_reticle != null and is_instance_valid(_dot_reticle):
			_dot_reticle.follow(_aim)
		return
	if not _dot_locked:
		_dot_locked = true
		if _dot_reticle != null and is_instance_valid(_dot_reticle):
			_dot_reticle.queue_free()
			_dot_reticle = null


func _init_closing_sweep(player: Node3D, facing: Vector3) -> void:
	_closing_target = _snap_aim_point(player.global_position, _air_targeting)
	var ahead := player.global_position + facing * BEAM_START_AHEAD_M
	_closing_start = _snap_aim_point(ahead, _air_targeting)
	_aim = _closing_start
	if get_tree() != null:
		_dot_reticle = LaserDotReticleScript.spawn(
			get_tree(), _closing_target, CLOSING_TELEGRAPH_SEC
		)


func _advance_closing_sweep(delta: float, player: Node3D) -> void:
	if _elapsed() < CLOSING_TELEGRAPH_SEC:
		_aim = _closing_start
		return
	if _dot_reticle != null and is_instance_valid(_dot_reticle):
		_dot_reticle.queue_free()
		_dot_reticle = null
	_move_aim_toward_speed(_closing_target, delta, _air_targeting, CLOSING_SPEED_MPS)


func _closing_sweep_complete() -> bool:
	if _elapsed() < CLOSING_TELEGRAPH_SEC:
		return false
	if _air_targeting:
		return _aim.distance_to(_closing_target) <= CLOSING_ARRIVE_EPS_M
	var flat := Vector2(_aim.x - _closing_target.x, _aim.z - _closing_target.z)
	return flat.length() <= CLOSING_ARRIVE_EPS_M


func _init_arc_barrier(player: Node3D, facing: Vector3) -> void:
	_arc_air_switched = false
	_arc_trail_air_mode = _air_targeting
	_update_arc_center(player, facing)
	var half := deg_to_rad(ARC_SPAN_DEG * 0.5)
	_aim = _arc_point_at(-half, facing)
	_arc_last_aim = _aim


func _advance_arc_barrier(player: Node3D, facing: Vector3) -> void:
	if _air_targeting and not _arc_air_switched:
		_arc_air_switched = true
		_arc_trail_air_mode = true
	_update_arc_center(player, facing)
	var half := deg_to_rad(ARC_SPAN_DEG * 0.5)
	var t := clampf(_elapsed() / FIRE_SEC, 0.0, 1.0)
	var angle := lerpf(-half, half, t)
	_aim = _arc_point_at(angle, facing)
	if _aim.distance_to(_arc_last_aim) >= ARC_TRAIL_MIN_STEP_M:
		_stamp_arc_trail_segment(_arc_last_aim, _aim)
		_arc_last_aim = _aim


func _update_arc_center(player: Node3D, facing: Vector3) -> void:
	var center := player.global_position + facing * ARC_CENTER_AHEAD_M
	if _arc_trail_air_mode:
		_arc_center = center
	else:
		_arc_center = _ground_at(center.x, center.z)


func _arc_point_at(angle: float, facing: Vector3) -> Vector3:
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3(-1.0, 0.0, 0.0)
	else:
		flat = flat.normalized()
	var right := Vector3(flat.z, 0.0, -flat.x)
	var dir := (flat * cos(angle) + right * sin(angle)).normalized()
	var point := _arc_center + dir * ARC_RADIUS_M
	return _snap_aim_point(point, _arc_trail_air_mode)


func _stamp_arc_trail_segment(start: Vector3, end: Vector3) -> void:
	if get_tree() == null:
		return
	LaserArcTrailSegmentScript.spawn(
		get_tree(),
		start,
		end,
		_arc_trail_air_mode,
		ARC_TRAIL_LINGER_SEC,
		_terrain
	)


func _snap_aim_point(point: Vector3, air: bool) -> Vector3:
	if air:
		return point
	return _ground_at(point.x, point.z)


func _cleanup_telegraphs() -> void:
	if _sweep_line != null and is_instance_valid(_sweep_line):
		_sweep_line.queue_free()
	_sweep_line = null
	if _dot_reticle != null and is_instance_valid(_dot_reticle):
		_dot_reticle.queue_free()
	_dot_reticle = null


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


func _player_horiz_speed(player: Node3D) -> float:
	var vel := _player_velocity(player)
	return Vector3(vel.x, 0.0, vel.z).length()


func _lead_goal_ground(player: Node3D, facing: Vector3) -> Vector3:
	var pos := player.global_position
	var vel := _player_velocity(player)
	var horiz := Vector3(vel.x, 0.0, vel.z)
	var lead := pos + horiz * LEAD_SEC
	var ahead := Vector3(lead.x - pos.x, 0.0, lead.z - pos.z)
	if ahead.dot(facing) < 4.0:
		lead = pos + facing * maxf(horiz.length() * LEAD_SEC, BEAM_START_AHEAD_M)
	return _ground_at(lead.x, lead.z)


func _move_aim_toward_speed(goal: Vector3, delta: float, air: bool, speed: float) -> void:
	var step := maxf(speed, 0.0) * delta
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
	if pattern == DroneLaserPatternsScript.Pattern.ARC_BARRIER:
		return
	if not _can_damage():
		return
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
	if (
		pattern == DroneLaserPatternsScript.Pattern.CLOSING_SWEEP
		and _elapsed() < CLOSING_TELEGRAPH_SEC
	):
		_hide()
		return
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
