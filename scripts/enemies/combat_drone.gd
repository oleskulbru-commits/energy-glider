class_name CombatDrone
extends SwarmPill

## Flying cube enemy. Kites ahead of the player; no melee contact.

const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")

const DRONE_MAX_HEALTH := 40
const WEAPON_RANGE_M := 40.0
const SPAWN_AHEAD_M := 400.0
const CRUISE_HEIGHT_M := 8.0
const HEIGHT_FOLLOW_RATE := 4.0
const KITE_HOLD_M := 40.0
const CUBE_SIZE_M := 1.4
const BASE_MOVE_SPEED_MPS := 15.0
const DRONE_MIN_LEVEL := 5
const AIR_TARGETING_ENTER_SEC := 1.0
const AIR_TARGETING_EXIT_SEC := 0.35

enum FlyState { APPROACH, KITE, CATCH_UP }

var fly_state: int = FlyState.APPROACH
var _cube: MeshInstance3D
var _cube_color := Color(0.85, 0.15, 0.12)
var _airborne_time := 0.0
var _grounded_time := 0.0
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
	_collision_bottom_y = _compute_collision_bottom_y()
	_rng.randomize()


func configure(terrain: TerrainManager, target: Node3D, speed: float = BASE_MOVE_SPEED_MPS) -> void:
	_terrain = terrain
	_target = target
	move_speed = speed
	_snap_to_cruise_height(true, 0.0)


func bind_garrison(anchor: Vector3) -> void:
	super.bind_garrison(anchor)
	never_despawn = true


func _ensure_cube_visual() -> void:
	var old_visual := get_node_or_null("Visual")
	if old_visual != null:
		old_visual.queue_free()
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
	box.size = Vector3.ONE * CUBE_SIZE_M
	col.shape = box
	col.position = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	if can_despawn_when_behind() and not never_despawn and not garrisoned and is_behind_facing(_target.global_position, _target_facing_xz(), global_position):
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
	_face_target()
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
	if garrisoned:
		_steer_garrison(delta)
		return
	var desired := _desired_xz()
	var to := desired - Vector3(global_position.x, 0.0, global_position.z)
	to.y = 0.0
	if to.length_squared() < 0.04:
		velocity = Vector3(velocity.x, 0.0, velocity.z).lerp(Vector3.ZERO, minf(delta * 6.0, 1.0))
		velocity.y = 0.0
		return
	var dir := to.normalized()
	var speed := _get_move_speed()
	# Soft arrive near kite hold so we don't overshoot forever.
	if fly_state == FlyState.KITE:
		speed = minf(speed, to.length() * 2.5)
	velocity = dir * speed


func _steer_garrison(delta: float) -> void:
	tick_garrison_aggro(_target.global_position)
	var goal := _garrison_goal_xz()
	var to := goal - Vector3(global_position.x, 0.0, global_position.z)
	to.y = 0.0
	if to.length_squared() < 0.25:
		velocity = Vector3(velocity.x, 0.0, velocity.z).lerp(Vector3.ZERO, minf(delta * 6.0, 1.0))
		velocity.y = 0.0
		return
	velocity = to.normalized() * _get_move_speed()


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


func _face_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var flat := Vector3(
		_target.global_position.x - global_position.x,
		0.0,
		_target.global_position.z - global_position.z
	)
	if flat.length_squared() < 0.0001:
		return
	look_at(global_position + flat.normalized(), Vector3.UP)


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
	if garrisoned and not _garrison_aggroed:
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
	if _cube != null:
		_cube.visible = false
	died.emit()
	queue_free()


func _apply_visual_scale() -> void:
	pass


func _apply_hitbox_scale() -> void:
	pass


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
