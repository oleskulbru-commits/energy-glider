class_name CombatDrone
extends SwarmPill

## Flying cube enemy. Kites ahead of the player; no melee contact.

const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const DroneDeathBurstScript := preload("res://scripts/enemies/drone_death_burst.gd")
const DroneTypeFlareScript := preload("res://scripts/vfx/drone_type_flare.gd")

const DRONE_MAX_HEALTH := 40
const WEAPON_RANGE_M := 40.0
const SPAWN_AHEAD_M := 400.0
const CRUISE_HEIGHT_M := 8.0
const HEIGHT_FOLLOW_RATE := 4.0
const KITE_HOLD_M := 40.0
const CUBE_SIZE_M := 1.4
const DRONE_SIZE_MULT := 2.0
const BASE_MOVE_SPEED_MPS := 15.0
const DRONE_MIN_LEVEL := 5
const AIR_TARGETING_ENTER_SEC := 1.0
const AIR_TARGETING_EXIT_SEC := 0.35
const FLIGHT_TURN_RATE_DEG := 72.0
const FLIGHT_SPEED_ACCEL_MPS2 := 40.0
const FACE_SLERP_RATE := 10.0

enum FlyState { APPROACH, KITE, CATCH_UP }

var fly_state: int = FlyState.APPROACH
var _visual: Node3D
var _cube: MeshInstance3D
var _cube_color := Color(0.85, 0.15, 0.12)
var _airborne_time := 0.0
var _grounded_time := 0.0
var _flight_heading := Vector3(-1.0, 0.0, 0.0)
var invulnerable := false
var never_despawn := false


func _ready() -> void:
	add_to_group("swarm_pill")
	add_to_group("combat_drone")
	motion_mode = MOTION_MODE_FLOATING
	contact_damage = 0
	contact_radius_m = 0.0
	_max_health = DRONE_MAX_HEALTH
	_hp = get_max_health()
	_ensure_cube_visual()
	_ensure_box_hitbox()
	_apply_visual_scale()
	_apply_hitbox_scale()
	_collision_bottom_y = _compute_collision_bottom_y()
	_rng.randomize()


func configure(terrain: TerrainManager, target: Node3D, speed: float = BASE_MOVE_SPEED_MPS) -> void:
	_terrain = terrain
	_target = target
	move_speed = speed
	_snap_to_cruise_height(true, 0.0)
	_init_flight_heading_from_transform()


func _ensure_cube_visual() -> void:
	var scene_visual := get_node_or_null("Visual") as Node3D
	if scene_visual != null:
		_visual = scene_visual
		# Imported drone GLBs face +Z; steering uses look_at (-Z toward target).
		scene_visual.rotation.y = PI
		return

	_cube = get_node_or_null("Cube") as MeshInstance3D
	if _cube == null:
		_cube = MeshInstance3D.new()
		_cube.name = "Cube"
		var box := BoxMesh.new()
		box.size = Vector3.ONE * CUBE_SIZE_M
		_cube.mesh = box
		add_child(_cube)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _cube_color
	mat.roughness = 0.55
	_cube.material_override = mat


func _ensure_box_hitbox() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * body_size_m()
	col.shape = box
	col.position = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	if can_despawn_when_behind() and not never_despawn and is_behind_facing(_target.global_position, _target_facing_xz(), global_position):
		queue_free()
		return

	_stun_left = maxf(_stun_left - delta, 0.0)
	_tick_air_targeting(delta)
	if _stun_left > 0.0:
		velocity = Vector3.ZERO
		_hit_velocity = Vector3.ZERO
		move_and_slide()
		_update_weapons(delta)
		return

	_update_fly_state()
	_steer(delta)
	velocity += _hit_velocity
	_hit_velocity = _hit_velocity.move_toward(
		Vector3.ZERO,
		HIT_KNOCKBACK_SPEED / maxf(HIT_KNOCKBACK_DECAY_SEC, 0.001) * delta
	)
	move_and_slide()
	_snap_to_cruise_height(false, delta)
	_face_heading(delta)
	_update_weapons(delta)


func _update_fly_state() -> void:
	var facing := _target_facing_xz()
	var in_front := AutoRifleScript.is_in_front(_target.global_position, facing, global_position)
	var dist := AutoRifleScript.xz_distance(global_position, _target.global_position)
	if not in_front:
		fly_state = FlyState.CATCH_UP
	elif dist > WEAPON_RANGE_M + 2.0:
		fly_state = FlyState.APPROACH
	else:
		fly_state = FlyState.KITE


func _steer(delta: float) -> void:
	var desired := _desired_xz()
	var to := desired - Vector3(global_position.x, 0.0, global_position.z)
	to.y = 0.0
	if to.length_squared() < 0.04:
		velocity = Vector3(velocity.x, 0.0, velocity.z).lerp(Vector3.ZERO, minf(delta * 6.0, 1.0))
		velocity.y = 0.0
		return
	var dir := to.normalized()
	var speed := _get_move_speed()
	if fly_state == FlyState.KITE:
		speed = minf(speed, to.length() * 2.5)
	_steer_heading_toward(dir, FLIGHT_TURN_RATE_DEG, delta)
	_apply_flight_velocity(speed, delta)


func _desired_xz() -> Vector3:
	var player := _target.global_position
	var facing := _target_facing_xz()
	match fly_state:
		FlyState.CATCH_UP:
			return Vector3(player.x, 0.0, player.z) + facing * (KITE_HOLD_M * 0.5)
		FlyState.APPROACH:
			return Vector3(player.x, 0.0, player.z) + facing * KITE_HOLD_M
		_:
			return Vector3(player.x, 0.0, player.z) + facing * KITE_HOLD_M


func _steer_heading_toward(desired_dir: Vector3, turn_rate_deg: float, delta: float) -> void:
	var flat := Vector3(desired_dir.x, 0.0, desired_dir.z)
	if flat.length_squared() < 0.0001:
		return
	_flight_heading = rotate_heading_toward(_flight_heading, flat, turn_rate_deg, delta)


func _apply_flight_velocity(target_speed: float, delta: float) -> void:
	var current_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var new_speed := move_toward(
		current_speed,
		maxf(target_speed, 0.0),
		FLIGHT_SPEED_ACCEL_MPS2 * maxf(delta, 0.0)
	)
	if _flight_heading.length_squared() < 0.0001:
		velocity = Vector3.ZERO
		velocity.y = 0.0
		return
	velocity = _flight_heading * new_speed
	velocity.y = 0.0


func _face_heading(delta: float) -> void:
	if _flight_heading.length_squared() < 0.0001:
		return
	var forward := Vector3(_flight_heading.x, 0.0, _flight_heading.z).normalized()
	var target_basis := Basis.looking_at(forward, Vector3.UP).orthonormalized()
	global_transform.basis = global_transform.basis.slerp(
		target_basis,
		minf(FACE_SLERP_RATE * maxf(delta, 0.0), 1.0)
	)


func _init_flight_heading_from_transform() -> void:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		_flight_heading = forward.normalized()


static func rotate_heading_toward(
	current: Vector3,
	target: Vector3,
	max_turn_deg: float,
	delta: float
) -> Vector3:
	var cur := Vector3(current.x, 0.0, current.z)
	var tgt := Vector3(target.x, 0.0, target.z)
	if cur.length_squared() < 0.0001:
		cur = Vector3(-1.0, 0.0, 0.0)
	else:
		cur = cur.normalized()
	if tgt.length_squared() < 0.0001:
		return cur
	tgt = tgt.normalized()
	var max_rad := deg_to_rad(maxf(max_turn_deg, 0.0)) * maxf(delta, 0.0)
	var angle := cur.signed_angle_to(tgt, Vector3.UP)
	var turn := clampf(angle, -max_rad, max_rad)
	return cur.rotated(Vector3.UP, turn).normalized()


func _snap_to_cruise_height(instant: bool, delta: float = 0.016) -> void:
	var ground := 0.0
	if _terrain != null:
		ground = _terrain.sample_height(global_position.x, global_position.z)
	var cruise_y := ground + CRUISE_HEIGHT_M
	var target_y := cruise_y
	if _target != null and is_instance_valid(_target):
		target_y = maxf(cruise_y, _target.global_position.y)
	if instant:
		global_position.y = target_y
		return
	global_position.y = move_toward(global_position.y, target_y, HEIGHT_FOLLOW_RATE * delta)


## Subclasses implement weapons. Base is a no-op.
func _update_weapons(_delta: float) -> void:
	pass


func can_despawn_when_behind() -> bool:
	return true


func can_fire_weapons() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if _stun_left > 0.0:
		return false
	return xz_distance_to_target() <= WEAPON_RANGE_M


func uses_air_targeting() -> bool:
	return _airborne_time >= AIR_TARGETING_ENTER_SEC


func _tick_air_targeting(delta: float) -> void:
	if _is_target_gliding():
		_airborne_time += delta
		_grounded_time = 0.0
	else:
		_grounded_time += delta
		if _grounded_time >= AIR_TARGETING_EXIT_SEC:
			_airborne_time = 0.0


func _is_target_gliding() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if _target is GliderPlayer:
		return (_target as GliderPlayer).is_gliding()
	if _target.has_method("is_gliding"):
		return bool(_target.call("is_gliding"))
	return false


func xz_distance_to_target() -> float:
	if _target == null or not is_instance_valid(_target):
		return INF
	return AutoRifleScript.xz_distance(global_position, _target.global_position)


func take_damage(
	amount: int,
	hit_dir: Vector3 = Vector3.ZERO,
	is_crit: bool = false,
	knockback_speed: float = HIT_KNOCKBACK_SPEED,
	weapon_family: StringName = &""
) -> bool:
	if invulnerable:
		return false
	return super.take_damage(amount, hit_dir, is_crit, knockback_speed, weapon_family)


func _die(from_pos: Vector3) -> void:
	set_physics_process(false)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = true
	if _visual != null:
		var streak_vfx := _visual.get_node_or_null("Body") as DroneStreakVfx
		if streak_vfx != null:
			streak_vfx.prepare_for_death()
		DroneDeathBurstScript.spawn(get_tree(), global_transform, _visual, from_pos, _terrain)
		_visual.visible = false
	elif _cube != null:
		_cube.visible = false
		KillSparks.spawn(get_tree(), global_position)
	else:
		KillSparks.spawn(get_tree(), global_position)
	died.emit()
	queue_free()


func _apply_visual_scale() -> void:
	if _visual != null:
		_visual.scale = Vector3.ONE * DRONE_SIZE_MULT
		return
	if _cube != null and _cube.mesh is BoxMesh:
		(_cube.mesh as BoxMesh).size = Vector3.ONE * body_size_m()


func get_type_flare() -> Node3D:
	if _visual == null:
		return null
	var flare := _visual.find_child("TypeFlare", true, false)
	if flare != null and flare.get_script() == DroneTypeFlareScript:
		return flare
	return null


func _apply_hitbox_scale() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null or col.shape == null:
		return
	if col.shape is BoxShape3D:
		(col.shape as BoxShape3D).size = Vector3.ONE * body_size_m()


func _sync_anim_speed() -> void:
	pass


func _update_contact(_delta: float) -> void:
	pass


func _is_spawn_active() -> bool:
	return false


static func drone_cap_for_level(level: int) -> int:
	if level < DRONE_MIN_LEVEL:
		return 0
	return level - DRONE_MIN_LEVEL + 1


static func move_speed_for_drone_level(level: int) -> float:
	if level < DRONE_MIN_LEVEL:
		return BASE_MOVE_SPEED_MPS
	return BASE_MOVE_SPEED_MPS + float(level - DRONE_MIN_LEVEL)


static func spawn_ahead_m() -> float:
	return SPAWN_AHEAD_M


static func body_size_m() -> float:
	return CUBE_SIZE_M * DRONE_SIZE_MULT
