class_name LeaperPill
extends SwarmPill

## Leaper fodder: climbs out of sand, chases, then intercept-leaps once.

const GroundReticleScript := preload("res://scripts/enemies/ground_reticle.gd")
const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")

const MOVE_SPEED := 8.0
const PILL_COLOR := Color(0.58, 0.18, 0.92)
const RETICLE_COLOR := Color(0.72, 0.28, 0.98, 0.9)
const LEAP_RANGE_MIN_M := 175.0
const LEAP_RANGE_M := 200.0
const LEAP_RANGE_MAX_M := 225.0
const CHARGE_SEC := 1.0
## Air time at LEAP_RANGE_M. Other distances scale by distance / LEAP_RANGE_M.
const LEAP_SEC := 2.0
const RECOVER_SEC := 0.5
const SPLASH_RADIUS_M := 2.0
## Bezier control height above the higher end. The pill crests at half of this.
## 0.24 per meter of travel puts a 200 m leap about 24 m up, clear of the dunes.
const LOFT_PER_METER := 0.24
const LOFT_MIN_M := 8.0
const PILL_MESH_RADIUS := 0.38
const PILL_MESH_HEIGHT := 1.05
## Target standing height in meters after undoing the imported armature shrink.
const LEAPER_LIVING_SCALE := 1.15
const LEAPER_RIG_PATH := "Visual/Model/Leaper_Rig"
## Match glider idle settle: below this tangent speed, lead as if the board is still.
const LEAD_IDLE_SPEED_MPS := 0.35
## Vertical slop so a glider clipping the capsule still counts as a touch.
const CONTACT_Y_BELOW_M := 1.2
const CONTACT_Y_ABOVE_M := 1.5

enum LeapState { CHASE, CHARGE, LEAP, RECOVER }

var leap_state: int = LeapState.CHASE
var practice_lane := false
var practice_in_place := false
var practice_facing := Vector3(1.0, 0.0, 0.0)
var _practice_run_left := 0.0
var _pill: MeshInstance3D
var _leaper_anim: LeaperAnimController
var _charge_left := 0.0
var _charge_duration := 0.0
var _charge_speed_start := 0.0
var _charge_dir := Vector3.ZERO
var _leap_t := 0.0
var _recover_left := 0.0
var _has_leapt := false
var _jump_range_m := LEAP_RANGE_M
var _leap_sec := LEAP_SEC
var _leap_origin := Vector3.ZERO
var _leap_impact := Vector3.ZERO
var _reticle: GroundReticle


func _ready() -> void:
	super._ready()
	add_to_group("leaper_pill")
	_leaper_anim = _find_leaper_anim()
	if _leaper_anim != null and not _leaper_anim.spawn_finished.is_connected(_on_spawn_finished):
		_leaper_anim.spawn_finished.connect(_on_spawn_finished)
	_ensure_pill_visual()
	move_speed = MOVE_SPEED
	_jump_range_m = _rng.randf_range(LEAP_RANGE_MIN_M, LEAP_RANGE_MAX_M)
	_leap_sec = leap_sec_for_range(_jump_range_m)


func configure(terrain: TerrainManager, target: Node3D, _speed: float = MOVE_SPEED) -> void:
	super.configure(terrain, target, MOVE_SPEED)
	if _leaper_anim != null:
		_leaper_anim.configure_sand(terrain, self)


func _ensure_pill_visual() -> void:
	if get_node_or_null("Visual") != null:
		return
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


func enable_practice_lane(in_place: bool = false, facing: Vector3 = Vector3.RIGHT, run_lead_m: float = 50.0) -> void:
	practice_lane = true
	practice_in_place = in_place
	_jump_range_m = LEAP_RANGE_M
	_leap_sec = LEAP_SEC
	_has_leapt = false
	leap_state = LeapState.CHASE
	if in_place:
		practice_facing = _flat_facing(facing)
		_practice_run_left = run_lead_m / maxf(MOVE_SPEED, 0.001)


func set_practice_facing(facing: Vector3) -> void:
	practice_facing = _flat_facing(facing)


func reset_for_next_hop(run_lead_m: float = 50.0) -> void:
	_has_leapt = false
	leap_state = LeapState.CHASE
	_charge_left = 0.0
	_recover_left = 0.0
	_leap_sec = LEAP_SEC
	if practice_in_place:
		_practice_run_left = run_lead_m / maxf(MOVE_SPEED, 0.001)


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		if practice_lane:
			return
		queue_free()
		return

	if (
		not practice_lane
		and not _blocks_behind_despawn()
		and is_behind_facing(_target.global_position, _target_facing_xz(), global_position)
	):
		queue_free()
		return

	if _is_spawn_active():
		velocity = Vector3.ZERO
		move_and_slide()
		_snap_to_terrain()
		_align_to_terrain(_flat_seek_to_target())
		return

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
	if practice_in_place:
		_tick_chase_in_place(delta)
		return

	if can_begin_charge(_distance_to_target(), _has_leapt, _jump_range_m):
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
	_sync_anim_speed()


func _begin_charge() -> void:
	leap_state = LeapState.CHARGE
	_charge_dir = _charge_heading()
	_charge_speed_start = _charge_entry_speed()
	_charge_duration = _charge_duration_sec()
	_charge_left = _charge_duration
	if _leaper_anim != null:
		_leaper_anim.play_stop_run()


func _tick_charge(delta: float) -> void:
	if _charge_duration <= 0.001:
		_charge_duration = _charge_duration_sec()
	if _charge_dir.length_squared() <= 0.0001:
		_charge_dir = _charge_heading()
	if _charge_speed_start <= 0.001:
		_charge_speed_start = _charge_entry_speed()
	var duration := maxf(_charge_duration, 0.001)
	var coast_frac := _charge_left / duration
	velocity = _charge_dir * (_charge_speed_start * coast_frac)
	velocity += _hit_velocity
	_hit_velocity = _hit_velocity.move_toward(
		Vector3.ZERO,
		HIT_KNOCKBACK_SPEED / maxf(HIT_KNOCKBACK_DECAY_SEC, 0.001) * delta
	)
	move_and_slide()
	_snap_to_terrain()
	if _charge_dir.length_squared() > 0.0001:
		_align_to_terrain(_charge_dir)
	else:
		_orient_toward_target()
	_update_contact(delta)
	_charge_left = maxf(_charge_left - delta, 0.0)
	if _charge_left <= 0.0:
		_begin_leap()


func _charge_duration_sec() -> float:
	if _leaper_anim != null:
		var clip_sec := _leaper_anim.stop_run_duration()
		if clip_sec > 0.001:
			return clip_sec
	return CHARGE_SEC


func _charge_heading() -> Vector3:
	if practice_in_place and practice_facing.length_squared() > 0.0001:
		return practice_facing
	if _last_seek_dir.length_squared() > 0.0001:
		return _last_seek_dir.normalized()
	var to_target := _flat_seek_to_target()
	if to_target.length_squared() > 0.0001:
		return to_target.normalized()
	return Vector3(1.0, 0.0, 0.0)


func _charge_entry_speed() -> float:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() > 0.01:
		return flat.length()
	return _get_move_speed()


func _begin_leap() -> void:
	leap_state = LeapState.LEAP
	_has_leapt = true
	_leap_t = 0.0
	_leap_origin = global_position
	if practice_in_place:
		_leap_impact = _practice_landing_point(_leap_origin)
	else:
		_leap_impact = landing_point_for(
			_leap_origin,
			_target.global_position,
			_target_velocity(),
			_terrain,
			_collision_bottom_y,
			_leap_sec
		)
	motion_mode = MOTION_MODE_FLOATING
	_hit_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	if not practice_in_place:
		_place_landing_reticle()
	if _leaper_anim != null:
		_leaper_anim.play_leap(_leap_sec)


func _tick_leap(delta: float) -> void:
	_leap_t += delta / _leap_sec
	if _leap_t >= 1.0:
		global_position = _leap_impact
		_on_landed()
		return
	var loft := _leap_loft_m()
	global_position = DroneRocket.arc_position(_leap_origin, _leap_impact, _leap_t, loft)
	var along := Vector3(_leap_impact.x - _leap_origin.x, 0.0, _leap_impact.z - _leap_origin.z)
	if along.length_squared() > 0.0001:
		_align_airborne(along.normalized())
	elif practice_in_place and practice_facing.length_squared() > 0.0001:
		_align_airborne(practice_facing)
	if not _landing_owns_hit():
		_update_contact(delta)


func _on_landed() -> void:
	motion_mode = MOTION_MODE_GROUNDED
	_clear_reticle()
	_snap_to_terrain()
	_spawn_landing_dust()
	_apply_landing_hit()
	leap_state = LeapState.RECOVER
	_recover_left = RECOVER_SEC
	if _leaper_anim != null:
		_leaper_anim.play_land()
		_recover_left = maxf(_recover_left, _leaper_anim.recover_duration())


func _tick_recover(delta: float) -> void:
	_recover_left = maxf(_recover_left - delta, 0.0)
	velocity = Vector3.ZERO
	move_and_slide()
	_snap_to_terrain()
	_orient_toward_target()
	_update_contact(delta)
	if _recover_left <= 0.0 and (_leaper_anim == null or not _leaper_anim.is_recover_active()):
		leap_state = LeapState.CHASE
		if _leaper_anim != null:
			_leaper_anim.set_run_speed(_get_move_speed())


func spawns_climb_dust() -> bool:
	return false


func get_landing_dust_preset() -> SandParticleVfx.BurstPreset:
	return SandParticleVfx.BurstPreset.HEAVY


func get_landing_dust_scale_mult() -> float:
	return get_sand_burst_scale_mult() * 1.5


func get_landing_dust_shake_strength() -> float:
	return 0.35


func get_landing_dust_shake_radius_m() -> float:
	return 24.0


func _spawn_landing_dust() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var impact_pos := global_position
	var skin := get_node_or_null("Visual") as Node3D
	if skin != null:
		var dig := skin.get_node_or_null("DigDustAnchor") as Node3D
		if dig != null:
			impact_pos = dig.global_position
	SandImpactDustScript.spawn(
		tree,
		impact_pos,
		_terrain,
		get_landing_dust_preset(),
		get_landing_dust_scale_mult(),
		get_landing_dust_shake_strength(),
		get_landing_dust_shake_radius_m()
	)


func _apply_landing_hit() -> void:
	if practice_lane:
		return
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
	reticle.place(_leap_impact, _leap_sec, _terrain, RETICLE_COLOR)
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
	var world_vel := Vector3.ZERO
	if _target is GliderPlayer:
		world_vel = (_target as GliderPlayer).linear_velocity
	elif _target is CharacterBody3D:
		world_vel = (_target as CharacterBody3D).velocity
	elif _target is RigidBody3D:
		world_vel = (_target as RigidBody3D).linear_velocity
	else:
		return Vector3.ZERO
	return lead_velocity_xz(world_vel, _target_ground_normal())


func _target_ground_normal() -> Vector3:
	if _target != null and is_instance_valid(_target) and _target is GliderPlayer:
		var predictive := (_target as GliderPlayer).get_predictive_normal()
		if predictive.length_squared() > 0.0001:
			return predictive.normalized()
	if _terrain != null and _target != null and is_instance_valid(_target):
		return _terrain.sample_normal(_target.global_position.x, _target.global_position.z)
	return Vector3.UP


func _is_touching_target() -> bool:
	if practice_lane:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	return is_body_contact(
		_target.global_position,
		global_position,
		contact_radius_m,
		CONTACT_Y_BELOW_M,
		CONTACT_Y_ABOVE_M
	)


func _landing_owns_hit() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	return landing_owns_hit(
		_target.global_position,
		_leap_impact,
		contact_radius_m,
		SPLASH_RADIUS_M,
		contact_max_above_m,
		contact_damage
	)


func _distance_to_target() -> float:
	if _target == null or not is_instance_valid(_target):
		return INF
	return range_distance(_target.global_position, global_position)


func _blocks_behind_despawn() -> bool:
	return leap_state == LeapState.CHARGE or leap_state == LeapState.LEAP


func _tick_chase_in_place(delta: float) -> void:
	_practice_run_left = maxf(_practice_run_left - delta, 0.0)
	velocity = Vector3.ZERO
	move_and_slide()
	_snap_to_terrain()
	if practice_facing.length_squared() > 0.0001:
		_align_to_terrain(practice_facing)
	_update_contact(delta)
	_sync_anim_speed()
	if _has_leapt:
		return
	if _practice_run_left <= 0.0:
		_begin_charge()
		_tick_charge(delta)


func _practice_landing_point(origin: Vector3) -> Vector3:
	var land_y := origin.y
	if _terrain != null:
		land_y = _terrain.sample_height(origin.x, origin.z)
	return Vector3(
		origin.x,
		land_y - _collision_bottom_y + GROUND_CLEARANCE_M,
		origin.z
	)


func _leap_loft_m() -> float:
	if practice_in_place:
		var flat_end := _leap_origin + practice_facing * LEAP_RANGE_M
		return loft_for_span(_leap_origin, flat_end)
	return loft_for_span(_leap_origin, _leap_impact)


func leap_motion_direction() -> Vector3:
	if leap_state != LeapState.LEAP:
		return Vector3.ZERO
	return DroneRocket.arc_velocity(_leap_origin, _leap_impact, _leap_t, _leap_loft_m())


func _flat_facing(dir: Vector3) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return Vector3(1.0, 0.0, 0.0)
	return flat.normalized()


func _die(from_pos: Vector3, _weapon_family: StringName = &"") -> void:
	_clear_reticle()
	set_physics_process(false)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = true
	var visual := get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.visible = false
	if _pill != null:
		_pill.visible = false
	died.emit()
	queue_free()


func _apply_hitbox_scale() -> void:
	pass


func _apply_visual_scale() -> void:
	var model := get_node_or_null("Visual/Model") as Node3D
	if model == null:
		return
	var rig := get_node_or_null(LEAPER_RIG_PATH) as Node3D
	var armature := 1.0
	if rig != null:
		armature = absf(rig.transform.basis.get_scale().x)
	var s := LEAPER_LIVING_SCALE / maxf(armature, 0.0001)
	model.scale = Vector3(s, s, s)


func _sync_anim_speed() -> void:
	if _leaper_anim == null or _is_spawn_active():
		return
	_leaper_anim.set_run_speed(_get_move_speed())


func _is_spawn_active() -> bool:
	return _leaper_anim != null and _leaper_anim.is_spawn_active()


func _find_leaper_anim() -> LeaperAnimController:
	var skin := get_node_or_null("Visual")
	if skin == null:
		return null
	return skin.find_child("LeaperAnimController", true, false) as LeaperAnimController


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


## Slope-tangent XZ for leap lead. Hover/floor correction along the normal is ignored;
## idle boards (tangent speed under LEAD_IDLE_SPEED_MPS) aim at their current position.
static func lead_velocity_xz(
	world_vel: Vector3,
	ground_normal: Vector3 = Vector3.UP,
	idle_speed_mps: float = LEAD_IDLE_SPEED_MPS
) -> Vector3:
	var normal := ground_normal
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	var tangent := world_vel.slide(normal)
	if tangent.length() <= idle_speed_mps:
		return Vector3.ZERO
	return Vector3(tangent.x, 0.0, tangent.z)


static func leap_sec_for_range(
	range_m: float, base_range_m: float = LEAP_RANGE_M, base_sec: float = LEAP_SEC
) -> float:
	return base_sec * (range_m / base_range_m)


static func loft_for_span(origin: Vector3, impact: Vector3) -> float:
	var flat := Vector2(impact.x - origin.x, impact.z - origin.z).length()
	return maxf(LOFT_MIN_M, flat * LOFT_PER_METER)


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
	lead_sec: float = LEAP_SEC
) -> Vector3:
	var predicted := intercept_xz(player_pos, player_vel, lead_sec)
	return Vector3(predicted.x, origin.y, predicted.z)


static func landing_point_for(
	origin: Vector3,
	player_pos: Vector3,
	player_vel: Vector3,
	terrain: TerrainManager,
	collision_bottom_y: float,
	lead_sec: float = LEAP_SEC
) -> Vector3:
	var aim := landing_aim_xz(origin, player_pos, player_vel, lead_sec)
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
	dist_m: float, has_leapt: bool = false, range_m: float = LEAP_RANGE_M
) -> bool:
	return not has_leapt and dist_m <= range_m


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


static func landing_owns_hit(
	player_pos: Vector3,
	impact: Vector3,
	contact_radius: float,
	splash_radius: float,
	max_above_m: float,
	contact_damage: int
) -> bool:
	return landing_damage_for(
		is_direct_landing(player_pos, impact, contact_radius, max_above_m),
		is_splash_landing(player_pos, impact, splash_radius, max_above_m),
		contact_damage
	) > 0


static func spawn_ahead_range() -> Vector2:
	return Vector2(LEAP_RANGE_MAX_M, LEAP_RANGE_MAX_M)
