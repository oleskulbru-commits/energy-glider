class_name NightClaws
extends Node3D

## Ground claw volley: telegraph marks, then dark pills spike and retract.

signal finished

const NightClawReticleScript := preload("res://scripts/enemies/night_claw_reticle.gd")
const MathUtilScript := preload("res://scripts/util/math_util.gd")
const TerrainQueryScript := preload("res://scripts/terrain/terrain_query.gd")

const ZONE_FORWARD_M := 100.0
const ZONE_LATERAL_HALF_M := 50.0
const SPOT_DIAMETER_M := 1.0
const SPOT_RADIUS_M := SPOT_DIAMETER_M * 0.5
const MIN_SPOT_SEP_M := SPOT_DIAMETER_M
const CLAW_COUNT_MIN := 150
const CLAW_COUNT_MAX := 200
const PLACE_TRIES_PER_SPOT := 128
const TELEGRAPH_SEC := 1.0
const RISE_SEC := 0.08
const HOLD_SEC := 1.0
const RETRACT_SEC := 1.4
## Tip of the 10 m claw reaches about this far above the sand.
const PEAK_HEIGHT_M := 5.0
const PILL_HEIGHT_M := 10.0
## Extra mesh length buried below the sand so the capsule dome is hidden.
const PILL_VISUAL_EXTRA_M := 1.0
const PILL_RADIUS_M := 0.5
const DAMAGE_RISE := 25
const DAMAGE_HOLD := 10
const DAMAGE_RETRACT := 10
## Glider hover height over the mark still counts as standing in the claw.
const CONTACT_MAX_ABOVE_M := 12.0
const PILL_COLOR := Color(0.02, 0.02, 0.03)

enum Phase { TELEGRAPH, STRIKE, HOLD, RETRACT, DONE }

class ClawSlot:
	var xz: Vector3
	var ground_y: float
	var ground_normal := Vector3.UP
	var hit_rise := false
	var hit_hold := false
	var hit_retract := false
	var reticle: Node3D
	var pill: MeshInstance3D
	var rise_t := 0.0


var _boss: SunEater
var _player: Node3D
var _terrain: TerrainManager
var _phase := Phase.TELEGRAPH
var _phase_t := 0.0
var _anchor := Vector3.ZERO
var _forward := Vector3(-1.0, 0.0, 0.0)
var _right := Vector3(0.0, 0.0, 1.0)
var _slots: Array[ClawSlot] = []


static func facing_xz_for_player(player: Node3D) -> Vector3:
	if player == null:
		return Vector3(-1.0, 0.0, 0.0)
	var vel := Vector3.ZERO
	if player is RigidBody3D:
		vel = (player as RigidBody3D).linear_velocity
	elif player.get("velocity") != null:
		vel = player.velocity as Vector3
	var flat := Vector3(vel.x, 0.0, vel.z)
	if flat.length_squared() > 1.0:
		return flat.normalized()
	if player.has_method("get_yaw"):
		return MathUtilScript.yaw_forward(float(player.call("get_yaw")))
	var basis_fwd := -player.global_transform.basis.z
	basis_fwd.y = 0.0
	if basis_fwd.length_squared() > 0.0001:
		return basis_fwd.normalized()
	return Vector3(-1.0, 0.0, 0.0)


static func build_claw_positions(
	anchor: Vector3,
	forward_xz: Vector3,
	count: int,
	rng: RandomNumberGenerator,
	terrain: TerrainManager = null
) -> PackedVector3Array:
	var forward := Vector3(forward_xz.x, 0.0, forward_xz.z)
	if forward.length_squared() < 0.0001:
		forward = Vector3(-1.0, 0.0, 0.0)
	else:
		forward = forward.normalized()
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.0001:
		right = Vector3(0.0, 0.0, 1.0)
	else:
		right = right.normalized()
	var placed: Array[Vector2] = []
	var out := PackedVector3Array()
	var want := clampi(count, CLAW_COUNT_MIN, CLAW_COUNT_MAX)
	for _n in want:
		var placed_one := false
		for _try in PLACE_TRIES_PER_SPOT:
			var f := rng.randf_range(0.0, ZONE_FORWARD_M)
			var r := rng.randf_range(-ZONE_LATERAL_HALF_M, ZONE_LATERAL_HALF_M)
			var candidate := Vector2(f, r)
			if not _can_place_spot(candidate, placed):
				continue
			placed.append(candidate)
			var world := anchor + forward * f + right * r
			var ground_y := world.y
			if terrain != null:
				ground_y = terrain.sample_height(world.x, world.z)
			out.append(Vector3(world.x, ground_y, world.z))
			placed_one = true
			break
		if not placed_one:
			break
	return out


static func _can_place_spot(candidate: Vector2, placed: Array[Vector2]) -> bool:
	for other in placed:
		if candidate.distance_to(other) < MIN_SPOT_SEP_M:
			return false
	return true


static func local_forward_right(
	world_pos: Vector3,
	anchor: Vector3,
	forward_xz: Vector3
) -> Vector2:
	var forward := Vector3(forward_xz.x, 0.0, forward_xz.z).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var delta := world_pos - anchor
	return Vector2(delta.dot(forward), delta.dot(right))


static func surface_at_mark(
	terrain: TerrainManager,
	space: PhysicsDirectSpaceState3D,
	world_x: float,
	world_z: float,
	fallback_y: float
) -> Dictionary:
	var surface := TerrainQueryScript.sample_surface(
		terrain,
		space,
		world_x,
		world_z,
		fallback_y + 2.0
	)
	if surface.is_empty():
		return {
			"position": Vector3(world_x, fallback_y, world_z),
			"normal": Vector3.UP,
		}
	return surface


func configure(boss: SunEater, player: Node3D, terrain: TerrainManager, rng: RandomNumberGenerator) -> void:
	_boss = boss
	_player = player
	_terrain = terrain
	_anchor = player.global_position
	_forward = facing_xz_for_player(player)
	_right = Vector3.UP.cross(_forward).normalized()
	var count := rng.randi_range(CLAW_COUNT_MIN, CLAW_COUNT_MAX)
	var positions := build_claw_positions(_anchor, _forward, count, rng, terrain)
	var space := _physics_space()
	_slots.clear()
	for pos in positions:
		var surface := surface_at_mark(terrain, space, pos.x, pos.z, pos.y)
		var center: Vector3 = surface.position
		var normal: Vector3 = surface.normal
		if normal.length_squared() < 0.0001:
			normal = Vector3.UP
		else:
			normal = normal.normalized()
		var slot := ClawSlot.new()
		slot.xz = Vector3(center.x, center.y, center.z)
		slot.ground_y = center.y
		slot.ground_normal = normal
		_slots.append(slot)
	_spawn_reticles()
	_phase = Phase.TELEGRAPH
	_phase_t = 0.0
	set_physics_process(true)


func phase() -> Phase:
	return _phase


func claw_count() -> int:
	return _slots.size()


func positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for slot in _slots:
		out.append(slot.xz)
	return out


func anchor() -> Vector3:
	return _anchor


func forward_xz() -> Vector3:
	return _forward


func is_done() -> bool:
	return _phase == Phase.DONE or is_queued_for_deletion()


func apply_hit_for_test(body: Node3D, slot_index: int = 0) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	_try_hit_body_at_claw(body, _slots[slot_index])


func _physics_process(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	_phase_t += delta
	match _phase:
		Phase.TELEGRAPH:
			if _phase_t >= TELEGRAPH_SEC:
				_begin_strike()
		Phase.STRIKE:
			_tick_strike(delta)
		Phase.HOLD:
			_tick_hold(delta)
		Phase.RETRACT:
			_tick_retract(delta)


func _spawn_reticles() -> void:
	var host := _world_host()
	for slot in _slots:
		var reticle: NightClawReticle = NightClawReticleScript.new()
		host.add_child(reticle)
		reticle.place(slot.xz, _terrain, SPOT_DIAMETER_M)
		slot.reticle = reticle


func _clear_reticles() -> void:
	for slot in _slots:
		if slot.reticle != null and is_instance_valid(slot.reticle):
			slot.reticle.queue_free()
		slot.reticle = null


func _begin_strike() -> void:
	_clear_reticles()
	_spawn_pills()
	_phase = Phase.STRIKE
	_phase_t = 0.0
	for slot in _slots:
		slot.rise_t = 0.0
	_check_strike_start_hits()


func _spawn_pills() -> void:
	var host := _world_host()
	for slot in _slots:
		var pill := MeshInstance3D.new()
		pill.name = "NightClawPill"
		var mesh := CapsuleMesh.new()
		mesh.radius = PILL_RADIUS_M
		mesh.height = PILL_HEIGHT_M + PILL_VISUAL_EXTRA_M
		pill.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PILL_COLOR
		mat.emission_enabled = true
		mat.emission = PILL_COLOR
		mat.emission_energy_multiplier = 1.2
		pill.material_override = mat
		host.add_child(pill)
		slot.pill = pill
		_set_pill_height(slot, 0.0)


func _tick_strike(delta: float) -> void:
	var u := clampf(_phase_t / maxf(RISE_SEC, 0.001), 0.0, 1.0)
	for slot in _slots:
		slot.rise_t = u
		_set_pill_height(slot, u)
		_try_hit_during_phase(slot)
	if _phase_t >= RISE_SEC:
		for slot in _slots:
			_set_pill_height(slot, 1.0)
			_try_hit_during_phase(slot)
		_phase = Phase.HOLD
		_phase_t = 0.0


func _tick_hold(delta: float) -> void:
	for slot in _slots:
		_set_pill_height(slot, 1.0)
		_try_hit_during_phase(slot)
	if _phase_t >= HOLD_SEC:
		_phase = Phase.RETRACT
		_phase_t = 0.0


func _tick_retract(delta: float) -> void:
	var u := 1.0 - clampf(_phase_t / maxf(RETRACT_SEC, 0.001), 0.0, 1.0)
	for slot in _slots:
		_set_pill_height(slot, u)
		_try_hit_during_phase(slot)
	if _phase_t >= RETRACT_SEC:
		_finish()


func _set_pill_height(slot: ClawSlot, rise_u: float) -> void:
	if slot.pill == null or not is_instance_valid(slot.pill):
		return
	var normal := slot.ground_normal
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	var basis := TerrainQueryScript.basis_from_up(normal)
	var center := Vector3(slot.xz.x, slot.ground_y, slot.xz.z)
	var visual_h := PILL_HEIGHT_M + PILL_VISUAL_EXTRA_M
	var bury_off := -visual_h * 0.5
	## Keep tip at the same height; extra length only sinks into the sand.
	var peak_off := PEAK_HEIGHT_M - PILL_VISUAL_EXTRA_M * 0.5
	slot.pill.global_basis = basis
	slot.pill.global_position = center + normal * lerpf(bury_off, peak_off, rise_u)


func _check_strike_start_hits() -> void:
	var body := _player_body()
	if body == null:
		return
	for slot in _slots:
		_try_hit_body_at_claw(body, slot)


func _try_hit_during_phase(slot: ClawSlot) -> void:
	var body := _player_body()
	if body == null:
		return
	_try_hit_body_at_claw(body, slot)


func _try_hit_body_at_claw(body: Node3D, slot: ClawSlot) -> void:
	var damage := 0
	match _phase:
		Phase.STRIKE:
			if slot.hit_rise:
				return
			damage = DAMAGE_RISE
		Phase.HOLD:
			if slot.hit_hold:
				return
			damage = DAMAGE_HOLD
		Phase.RETRACT:
			if slot.hit_retract:
				return
			damage = DAMAGE_RETRACT
		_:
			return
	if not _body_over_claw(body, slot):
		return
	match _phase:
		Phase.STRIKE:
			slot.hit_rise = true
		Phase.HOLD:
			slot.hit_hold = true
		Phase.RETRACT:
			slot.hit_retract = true
	var tree := get_tree()
	if tree == null:
		return
	var health := tree.get_first_node_in_group("player_health")
	if health != null and health.has_method("take_damage"):
		health.call("take_damage", damage)


func _body_over_claw(body: Node3D, slot: ClawSlot) -> bool:
	var pos := body.global_position
	var flat := Vector2(pos.x - slot.xz.x, pos.z - slot.xz.z)
	if flat.length() > SPOT_RADIUS_M:
		return false
	if pos.y - slot.ground_y > CONTACT_MAX_ABOVE_M:
		return false
	return true


func _player_body() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	var tree := get_tree()
	if tree == null:
		return null
	var player := tree.get_first_node_in_group("player")
	if player is Node3D:
		return player as Node3D
	return null


func _world_host() -> Node:
	var tree := get_tree()
	if tree == null:
		return self
	var scene := tree.current_scene
	if scene != null:
		return scene
	return self


func _physics_space() -> PhysicsDirectSpaceState3D:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	var world := tree.root.get_world_3d()
	if world == null:
		return null
	return world.direct_space_state


func _finish() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	_clear_reticles()
	for slot in _slots:
		if slot.pill != null and is_instance_valid(slot.pill):
			slot.pill.queue_free()
		slot.pill = null
	set_physics_process(false)
	finished.emit()
	queue_free()
