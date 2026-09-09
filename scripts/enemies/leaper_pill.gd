class_name LeaperPill
extends SwarmPill

## Purple pill fodder: chases a bit faster than crawlers, then intercept-leaps.

const GroundReticleScript := preload("res://scripts/enemies/ground_reticle.gd")

const MOVE_SPEED := 8.0
const PILL_COLOR := Color(0.58, 0.18, 0.92)
const RETICLE_COLOR := Color(0.72, 0.28, 0.98, 0.9)
const LEAP_RANGE_M := 15.0
const LEAP_MAX_M := 40.0
const SPAWN_AHEAD_MIN_M := 120.0
const CHARGE_SEC := 1.5
const LEAP_SEC := 1.0
const RECOVER_SEC := 0.5
const LEAP_COOLDOWN_SEC := 7.0
const SPLASH_RADIUS_M := 2.0
const LOFT_PEAK_M := 4.0
const PILL_MESH_RADIUS := 0.38
const PILL_MESH_HEIGHT := 1.05
## Vertical slop so a glider clipping the capsule still counts as a touch.
const CONTACT_Y_BELOW_M := 1.2
const CONTACT_Y_ABOVE_M := 1.5

enum LeapState { CHASE, CHARGE, LEAP, RECOVER }

var leap_state: int = LeapState.CHASE
var _pill: MeshInstance3D
var _charge_left := 0.0
var _leap_t := 0.0
var _recover_left := 0.0
var _cooldown_left := 0.0
var _leap_origin := Vector3.ZERO
var _leap_impact := Vector3.ZERO
var _reticle: GroundReticle


func _ready() -> void:
	super._ready()
	add_to_group("leaper_pill")
	_ensure_pill_visual()
	move_speed = MOVE_SPEED


func configure(terrain: TerrainManager, target: Node3D, _speed: float = MOVE_SPEED) -> void:
	super.configure(terrain, target, MOVE_SPEED)


func _ensure_pill_visual() -> void:
	var old_visual := get_node_or_null("Visual")
	if old_visual != null:
		old_visual.queue_free()
	_pill = get_node_or_null("Pill") as MeshInstance3D
	if _pill == null:
		_pill = MeshInstance3D.new()
		_pill.name = "Pill"
		var mesh := CapsuleMesh.new()
		mesh.radius = PILL_MESH_RADIUS
		mesh.height = PILL_MESH_HEIGHT
		_pill.mesh = mesh
		_pill.position.y = PILL_MESH_HEIGHT * 0.5
		add_child(_pill)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PILL_COLOR
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = PILL_COLOR
	mat.emission_energy_multiplier = 1.4
	_pill.material_override = mat


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	if not _blocks_behind_despawn() and is_behind_facing(
		_target.global_position, _target_facing_xz(), global_position
	):
		queue_free()
		return

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if leap_state == LeapState.LEAP:
		_tick_leap(delta)
		return

	_stun_left = maxf(_stun_left - delta, 0.0)
	if _stun_left > 0.0:
		velocity = Vector3.ZERO
		_hit_velocity = Vector3.ZERO
		move_and_slide()
		_snap_to_terrain()
		_update_contact(delta)
		return

	match leap_state:
		LeapState.CHARGE:
			_tick_charge(delta)
		LeapState.RECOVER:
			_tick_recover(delta)
		_:
			_tick_chase(delta)


func _tick_chase(delta: float) -> void:
	if can_begin_charge(_distance_to_target(), _cooldown_left):
		_begin_charge()
		_tick_charge(delta)
		return

	var to_target := _flat_seek_to_target()
	if to_target.length_squared() > 0.01:
		_last_seek_dir = to_target.normalized()
		velocity = _last_seek_dir * _get_move_speed()
	elif _last_seek_dir.length_squared() > 0.01:
		velocity = _last_seek_dir * _get_move_speed()
	else:
		velocity = Vector3.ZERO
	velocity += _hit_velocity
	_hit_velocity = _hit_velocity.move_toward(
		Vector3.ZERO,
		HIT_KNOCKBACK_SPEED / maxf(HIT_KNOCKBACK_DECAY_SEC, 0.001) * delta
	)
	move_and_slide()
	_snap_to_terrain()
	_align_to_terrain(_flat_velocity_dir())
	_update_contact(delta)


func _begin_charge() -> void:
	leap_state = LeapState.CHARGE
	_charge_left = CHARGE_SEC
	velocity = Vector3.ZERO


func _tick_charge(delta: float) -> void:
	_charge_left = maxf(_charge_left - delta, 0.0)
	velocity = Vector3.ZERO
	velocity += _hit_velocity
	_hit_velocity = _hit_velocity.move_toward(
		Vector3.ZERO,
		HIT_KNOCKBACK_SPEED / maxf(HIT_KNOCKBACK_DECAY_SEC, 0.001) * delta
	)
	move_and_slide()
	_snap_to_terrain()
	_orient_toward_target()
	_update_contact(delta)
	if _charge_left <= 0.0:
		_begin_leap()


func _begin_leap() -> void:
	leap_state = LeapState.LEAP
	_cooldown_left = LEAP_COOLDOWN_SEC
	_leap_t = 0.0
	_leap_origin = global_position
	_leap_impact = landing_point_for(
		_leap_origin,
		_target.global_position,
		_target_velocity(),
		_terrain,
		_collision_bottom_y
	)
	motion_mode = MOTION_MODE_FLOATING
	_hit_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	_place_landing_reticle()


func _tick_leap(delta: float) -> void:
	_leap_t += delta / LEAP_SEC
	if _leap_t >= 1.0:
		global_position = _leap_impact
		_on_landed()
		return
	global_position = DroneRocket.arc_position(_leap_origin, _leap_impact, _leap_t, LOFT_PEAK_M)
	var along := Vector3(_leap_impact.x - _leap_origin.x, 0.0, _leap_impact.z - _leap_origin.z)
	if along.length_squared() > 0.0001:
		_align_airborne(along.normalized())
	_update_contact(delta)


func _on_landed() -> void:
	motion_mode = MOTION_MODE_GROUNDED
	_clear_reticle()
	_snap_to_terrain()
	_apply_landing_hit()
	leap_state = LeapState.RECOVER
	_recover_left = RECOVER_SEC


func _tick_recover(delta: float) -> void:
	_recover_left = maxf(_recover_left - delta, 0.0)
	velocity = Vector3.ZERO
	move_and_slide()
	_snap_to_terrain()
	_orient_toward_target()
	_update_contact(delta)
	if _recover_left <= 0.0:
		leap_state = LeapState.CHASE


func _apply_landing_hit() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var player_pos := _target.global_position
	var direct := is_direct_landing(
		player_pos, global_position, contact_radius_m, contact_max_above_m
	)
	var splash := is_splash_landing(
		player_pos, global_position, SPLASH_RADIUS_M, contact_max_above_m
	)
	var amount := landing_damage_for(direct, splash, contact_damage)
	if amount <= 0:
		return
	if direct:
		_apply_knockback()
	var health := get_tree().get_first_node_in_group("player_health")
	if health != null and health.has_method("take_damage"):
		health.take_damage(amount)
	_in_contact = true
	_damage_timer = DAMAGE_INTERVAL_SEC


func _place_landing_reticle() -> void:
	_clear_reticle()
	var tree := get_tree()
	if tree == null:
		return
	var parent: Node = tree.current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var reticle: GroundReticle = GroundReticleScript.new()
	parent.add_child(reticle)
	reticle.place(_leap_impact, LEAP_SEC, RETICLE_COLOR)
	_reticle = reticle


func _clear_reticle() -> void:
	if _reticle != null and is_instance_valid(_reticle):
		_reticle.queue_free()
	_reticle = null


func _align_airborne(flat_forward: Vector3) -> void:
	var forward := Vector3(flat_forward.x, 0.0, flat_forward.z)
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.0001:
		return
	right = right.normalized()
	var up := forward.cross(right).normalized()
	global_transform.basis = Basis(right, up, -forward).orthonormalized()


func _target_velocity() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		return Vector3.ZERO
	if _target is GliderPlayer:
		return (_target as GliderPlayer).linear_velocity
	if _target is CharacterBody3D:
		return (_target as CharacterBody3D).velocity
	if _target is RigidBody3D:
		return (_target as RigidBody3D).linear_velocity
	return Vector3.ZERO


func _is_touching_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	return is_body_contact(
		_target.global_position,
		global_position,
		contact_radius_m,
		CONTACT_Y_BELOW_M,
		CONTACT_Y_ABOVE_M
	)


func _distance_to_target() -> float:
	if _target == null or not is_instance_valid(_target):
		return INF
	return range_distance(_target.global_position, global_position)


func _blocks_behind_despawn() -> bool:
	return leap_state == LeapState.CHARGE or leap_state == LeapState.LEAP


func _die(from_pos: Vector3) -> void:
	_clear_reticle()
	set_physics_process(false)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = true
	if _pill != null:
		_pill.visible = false
	died.emit()
	queue_free()


func _apply_visual_scale() -> void:
	pass


func _sync_anim_speed() -> void:
	pass


func _is_spawn_active() -> bool:
	return false


static func is_body_contact(
	player_pos: Vector3,
	pill_pos: Vector3,
	radius_m: float,
	y_below_m: float = CONTACT_Y_BELOW_M,
	y_above_m: float = CONTACT_Y_ABOVE_M
) -> bool:
	var delta := player_pos - pill_pos
	if Vector2(delta.x, delta.z).length() > radius_m:
		return false
	return delta.y >= -y_below_m and delta.y <= y_above_m


static func intercept_xz(player_pos: Vector3, player_vel: Vector3, lead_sec: float) -> Vector3:
	return Vector3(
		player_pos.x + player_vel.x * lead_sec,
		player_pos.y,
		player_pos.z + player_vel.z * lead_sec
	)


static func landing_aim_xz(
	origin: Vector3,
	player_pos: Vector3,
	player_vel: Vector3,
	max_m: float = LEAP_MAX_M,
	lead_sec: float = LEAP_SEC
) -> Vector3:
	var to_player := Vector3(player_pos.x - origin.x, 0.0, player_pos.z - origin.z)
	var player_dist := to_player.length()
	var dir := Vector3.ZERO
	var travel := 0.0
	if player_dist > max_m:
		dir = to_player / player_dist
		travel = max_m
	else:
		var predicted := intercept_xz(player_pos, player_vel, lead_sec)
		var to_pred := Vector3(predicted.x - origin.x, 0.0, predicted.z - origin.z)
		var pred_dist := to_pred.length()
		if pred_dist > 0.0001:
			dir = to_pred / pred_dist
			travel = minf(pred_dist, max_m)
		elif player_dist > 0.0001:
			dir = to_player / player_dist
			travel = player_dist
	return Vector3(origin.x + dir.x * travel, origin.y, origin.z + dir.z * travel)


static func landing_point_for(
	origin: Vector3,
	player_pos: Vector3,
	player_vel: Vector3,
	terrain: TerrainManager,
	collision_bottom_y: float,
	max_m: float = LEAP_MAX_M
) -> Vector3:
	var aim := landing_aim_xz(origin, player_pos, player_vel, max_m)
	var land_y := aim.y
	if terrain != null:
		land_y = terrain.sample_height(aim.x, aim.z)
	return Vector3(
		aim.x,
		land_y - collision_bottom_y + GROUND_CLEARANCE_M,
		aim.z
	)


static func range_distance(player_pos: Vector3, pill_pos: Vector3) -> float:
	return player_pos.distance_to(pill_pos)


static func can_begin_charge(
	dist_m: float, cooldown_left: float, range_m: float = LEAP_RANGE_M
) -> bool:
	return cooldown_left <= 0.0 and dist_m <= range_m


static func charge_committed(started: bool, _dist_m: float, _range_m: float = LEAP_RANGE_M) -> bool:
	return started


static func is_direct_landing(
	player_pos: Vector3, land_pos: Vector3, contact_radius: float, max_above_m: float
) -> bool:
	if player_pos.y - land_pos.y > max_above_m:
		return false
	var flat := Vector2(player_pos.x - land_pos.x, player_pos.z - land_pos.z)
	return flat.length() <= contact_radius


static func is_splash_landing(
	player_pos: Vector3, land_pos: Vector3, splash_radius: float, max_above_m: float
) -> bool:
	if player_pos.y - land_pos.y > max_above_m:
		return false
	var flat := Vector2(player_pos.x - land_pos.x, player_pos.z - land_pos.z)
	return flat.length() <= splash_radius


static func landing_damage_for(direct: bool, splash: bool, contact_damage: int) -> int:
	if direct:
		return contact_damage
	if splash:
		return contact_damage / 2
	return 0


static func spawn_ahead_range() -> Vector2:
	return Vector2(SPAWN_AHEAD_MIN_M, SPAWN_AHEAD_MAX_M)
