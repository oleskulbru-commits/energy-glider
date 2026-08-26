class_name SwarmPill
extends CharacterBody3D

signal died

## Stream enemy: animated crawler that chases the player and deals contact damage.

const CrawlerDeathBurstScript := preload("res://scripts/enemies/crawler_death_burst.gd")

## Fine-tune below 1.0 if the Blender-sized import still reads large in-game.
const CRAWLER_SIZE_MULT := 0.85
const CRAWLER_LIVING_SCALE := CRAWLER_SIZE_MULT * 0.5
const CRAWLER_FRACTURED_BURST_MULT := 1.0
const GROUND_CLEARANCE_M := 0.02
const TERRAIN_NORMAL_EPSILON := 2.0
const TERRAIN_ALIGN_BLEND := 0.25
const BEHIND_MARGIN_M := 50.0
const KNOCKBACK_SPEED := 10.0
const KNOCKBACK_UP_SPEED := 1.5
const DAMAGE_INTERVAL_SEC := 0.5
const CONTACT_DAMAGE := 5
const CONTACT_RADIUS_M := 1.35
const COLLISION_RADIUS := 0.3
const COLLISION_HEIGHT := 0.6
const COLLISION_CENTER_Y := 0.32
## Ignore hits when the player is clearly jumping/flying over the pill.
const CONTACT_MAX_ABOVE_M := 1.2
const DEFAULT_SPEED := 8.0
const MAX_HEALTH := 20
const HIT_KNOCKBACK_SPEED := 12.0
const HIT_KNOCKBACK_DECAY_SEC := 0.3
const DAMAGE_FLOAT_HEIGHT_M := 1.55

var move_speed := DEFAULT_SPEED
var contact_damage := CONTACT_DAMAGE
var contact_radius_m := CONTACT_RADIUS_M
var contact_max_above_m := CONTACT_MAX_ABOVE_M

var _target: Node3D
var _terrain: TerrainManager
var _in_contact := false
var _damage_timer := 0.0
var _last_seek_dir := Vector3.ZERO
## Subclasses (charger) multiply base move_speed while aggro'd.
var chase_speed_mult := 1.0
var _max_health := MAX_HEALTH
var _hp := MAX_HEALTH
var _hit_velocity := Vector3.ZERO
var _anim: CrawlerAnimController
var _collision_bottom_y := 0.0
var _rng := RandomNumberGenerator.new()
var _stun_left := 0.0


func _ready() -> void:
	add_to_group("swarm_pill")
	motion_mode = MOTION_MODE_GROUNDED
	_hp = get_max_health()
	_apply_visual_scale()
	_apply_hitbox_scale()
	_collision_bottom_y = _compute_collision_bottom_y()
	_anim = _find_anim_controller()
	if _anim != null and not _anim.spawn_finished.is_connected(_on_spawn_finished):
		_anim.spawn_finished.connect(_on_spawn_finished)
	_rng.randomize()


func configure(terrain: TerrainManager, target: Node3D, speed: float = DEFAULT_SPEED) -> void:
	_terrain = terrain
	_target = target
	move_speed = speed
	_snap_to_terrain()


func set_target(target: Node3D) -> void:
	_target = target


func set_move_speed(speed: float) -> void:
	move_speed = speed


func get_health() -> int:
	return _hp


func get_max_health() -> int:
	return _max_health


## Scale speed / contact damage / HP by retry difficulty (floor). No-op at 0%.
func apply_difficulty(bonus: float) -> void:
	if bonus <= 0.0:
		return
	move_speed = float(_scaled_stat(move_speed, bonus))
	contact_damage = _scaled_stat(float(contact_damage), bonus)
	_max_health = _scaled_stat(float(_max_health), bonus)
	_hp = _max_health


static func _scaled_stat(base: float, bonus: float) -> int:
	var scaled := floorf(base * (1.0 + maxf(bonus, 0.0)))
	if base > 0.0:
		return maxi(int(scaled), 1)
	return 0


func is_alive() -> bool:
	return _hp > 0


## Returns true if the pill died from this hit. Lethal hits skip knockback.
func take_damage(
	amount: int,
	hit_dir: Vector3 = Vector3.ZERO,
	is_crit: bool = false,
	knockback_speed: float = HIT_KNOCKBACK_SPEED
) -> bool:
	if amount <= 0 or _hp <= 0:
		return false
	var dealt := mini(amount, _hp)
	_hp = maxi(_hp - amount, 0)
	_spawn_damage_float(dealt, is_crit)
	if _hp <= 0:
		var from_pos := global_position
		if hit_dir.length_squared() > 0.0001:
			from_pos = global_position - hit_dir.normalized()
		_die(from_pos)
		return true
	if hit_dir.length_squared() > 0.0001:
		_hit_velocity = hit_knockback_velocity_for(hit_dir, knockback_speed)
	return false


func apply_stun(duration_sec: float) -> void:
	if _hp <= 0:
		return
	_stun_left = maxf(_stun_left, maxf(duration_sec, 0.0))


func is_stunned() -> bool:
	return _stun_left > 0.0


func _spawn_damage_float(amount: int, is_crit: bool = false) -> void:
	DamageFloat.spawn_world(self, amount, _rng, DAMAGE_FLOAT_HEIGHT_M, is_crit)


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	# Fallen behind (east of player past margin) — despawn.
	if global_position.x > _target.global_position.x + BEHIND_MARGIN_M:
		queue_free()
		return

	_update_chase(delta)

	if _is_spawn_active():
		velocity = Vector3.ZERO
		velocity += _hit_velocity
		_hit_velocity = _hit_velocity.move_toward(
			Vector3.ZERO,
			HIT_KNOCKBACK_SPEED / maxf(HIT_KNOCKBACK_DECAY_SEC, 0.001) * delta
		)
		move_and_slide()
		_snap_to_terrain()
		_align_to_terrain(_flat_seek_to_target())
		return

	_stun_left = maxf(_stun_left - delta, 0.0)
	if _stun_left > 0.0:
		velocity = Vector3.ZERO
		_hit_velocity = Vector3.ZERO
		move_and_slide()
		_snap_to_terrain()
		_update_contact(delta)
		return

	var seek := Vector3(to_target.x, 0.0, to_target.z)
	if seek.length_squared() > 0.01:
		_last_seek_dir = seek.normalized()
		velocity = _last_seek_dir * _get_move_speed()
	elif _last_seek_dir.length_squared() > 0.01:
		# On top of / overlapping the player — keep charging; don't drop to a standstill.
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
	_sync_anim_speed()
	_update_contact(delta)


func _is_spawn_active() -> bool:
	return _anim != null and _anim.is_spawn_active()


func _get_crawler_visual_scale_mult() -> float:
	return 1.0


func _apply_visual_scale() -> void:
	var model := _get_crawler_model()
	if model != null:
		var base := CrawlerScaleUtil.animated_model_scale(CRAWLER_LIVING_SCALE)
		model.scale = Vector3.ONE * base * _get_crawler_visual_scale_mult()


func _apply_hitbox_scale() -> void:
	var mult := _get_crawler_visual_scale_mult()
	contact_radius_m = CONTACT_RADIUS_M * mult
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null or not col.shape is CapsuleShape3D:
		return
	var capsule := (col.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	capsule.radius = COLLISION_RADIUS * mult
	capsule.height = COLLISION_HEIGHT * mult
	col.shape = capsule
	col.position.y = COLLISION_CENTER_Y * mult


func _get_crawler_model() -> Node3D:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		return null
	return visual.get_node_or_null("Model") as Node3D


func _get_death_burst_transform() -> Transform3D:
	var model := _get_crawler_model()
	if model != null:
		return CrawlerScaleUtil.death_burst_transform(model)
	return global_transform


func _find_anim_controller() -> CrawlerAnimController:
	var skin := get_node_or_null("Visual")
	if skin == null:
		return null
	return skin.find_child("CrawlerAnimController", true, false) as CrawlerAnimController


func _on_spawn_finished() -> void:
	_sync_anim_speed()


func _sync_anim_speed() -> void:
	if _anim == null or _is_spawn_active():
		return
	_anim.set_move_speed(_get_move_speed())


func _orient_toward_target() -> void:
	_align_to_terrain(_flat_seek_to_target())


func _orient_to_velocity() -> void:
	_align_to_terrain(_flat_velocity_dir())


func _flat_seek_to_target() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		return Vector3.ZERO
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	return to_target


func _flat_velocity_dir() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func _compute_collision_bottom_y() -> float:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null or col.shape == null:
		return 0.0
	if col.shape is CapsuleShape3D:
		var capsule := col.shape as CapsuleShape3D
		return col.position.y - capsule.height * 0.5
	if col.shape is BoxShape3D:
		var box := col.shape as BoxShape3D
		return col.position.y - box.size.y * 0.5
	return col.position.y


func _snap_to_terrain() -> void:
	if _terrain == null:
		return
	var ground_y := _terrain.sample_height(global_position.x, global_position.z)
	global_position.y = ground_y - _collision_bottom_y + GROUND_CLEARANCE_M


func _align_to_terrain(flat_forward: Vector3) -> void:
	if _terrain == null:
		return
	var normal := _terrain.sample_normal(
		global_position.x,
		global_position.z,
		TERRAIN_NORMAL_EPSILON
	)
	var forward := flat_forward
	if forward.length_squared() < 0.0001:
		forward = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	forward = forward.slide(normal)
	if forward.length_squared() < 0.0001:
		return
	var target_basis := Basis.looking_at(forward, normal).orthonormalized()
	global_transform.basis = global_transform.basis.slerp(target_basis, TERRAIN_ALIGN_BLEND)


func _die(from_pos: Vector3) -> void:
	set_physics_process(false)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = true
	var burst_xf := _get_death_burst_transform()
	var burst_scale := (
		CrawlerScaleUtil.death_burst_scale(CRAWLER_LIVING_SCALE, CRAWLER_FRACTURED_BURST_MULT)
		* _get_crawler_visual_scale_mult()
	)
	var visual := get_node_or_null("Visual")
	if visual != null:
		visual.visible = false
	CrawlerDeathBurstScript.spawn(get_tree(), burst_xf, from_pos, burst_scale)
	died.emit()
	queue_free()


## Subclasses adjust chase behavior (e.g. aggro speed ramp).
func _update_chase(_delta: float) -> void:
	pass


func _get_move_speed() -> float:
	return move_speed * chase_speed_mult


## XZ proximity with a height gate so airborne flyovers don't clip/damage.
func _update_contact(delta: float) -> void:
	var touching := _is_touching_target()
	if touching:
		if not _in_contact:
			_tick_contact()
			_damage_timer = DAMAGE_INTERVAL_SEC
		else:
			_damage_timer = maxf(_damage_timer - delta, 0.0)
			if _damage_timer <= 0.0:
				_tick_contact()
				_damage_timer = DAMAGE_INTERVAL_SEC
	else:
		_damage_timer = 0.0
	_in_contact = touching


func _is_touching_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var delta := _target.global_position - global_position
	# Player jumping / gliding above the pill — no shove or damage.
	if delta.y > contact_max_above_m:
		return false
	var flat := Vector2(delta.x, delta.z)
	return flat.length() <= contact_radius_m


static func is_vertical_contact(player_y: float, pill_y: float, max_above_m: float = CONTACT_MAX_ABOVE_M) -> bool:
	return (player_y - pill_y) <= max_above_m


func _tick_contact() -> void:
	_apply_knockback()
	_apply_contact_damage()


func _apply_knockback() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var away := knockback_velocity_for(global_position, _target.global_position)
	if _target.has_method("queue_knockback"):
		_target.queue_knockback(away)
	elif _target is RigidBody3D:
		var rigid := _target as RigidBody3D
		rigid.apply_central_impulse(away * maxf(rigid.mass, 0.01))


func _apply_contact_damage() -> void:
	var health := get_tree().get_first_node_in_group("player_health")
	if health == null or not health.has_method("take_damage"):
		return
	health.take_damage(contact_damage)


## Horizontal shove (+ slight up) applied as velocity delta via GliderPlayer.queue_knockback.
static func knockback_velocity_for(
	pill_pos: Vector3,
	body_pos: Vector3,
	speed: float = KNOCKBACK_SPEED,
	up: float = KNOCKBACK_UP_SPEED
) -> Vector3:
	var away := body_pos - pill_pos
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(1.0, 0.0, 0.0)
	else:
		away = away.normalized()
	return Vector3(away.x * speed, up, away.z * speed)


## Horizontal shove along the bullet's travel direction. Lethal hits should not call this.
static func hit_knockback_velocity_for(
	hit_dir: Vector3,
	speed: float = HIT_KNOCKBACK_SPEED
) -> Vector3:
	var along := Vector3(hit_dir.x, 0.0, hit_dir.z)
	if along.length_squared() < 0.0001:
		along = Vector3(-1.0, 0.0, 0.0)
	else:
		along = along.normalized()
	return Vector3(along.x * speed, 0.0, along.z * speed)


## Legacy impulse helper (mass-scaled); prefer knockback_velocity_for + queue_knockback.
static func knockback_impulse_for(
	pill_pos: Vector3,
	body_pos: Vector3,
	body_mass: float,
	impulse_strength: float = 7.5,
	up: float = 0.22
) -> Vector3:
	var vel := knockback_velocity_for(pill_pos, body_pos, impulse_strength, up * impulse_strength)
	return vel * maxf(body_mass, 0.01)


## Westbound spawn X (more negative = ahead) and lateral Z offset.
static func spawn_offset_xz(
	ahead_min_m: float,
	ahead_max_m: float,
	spread_m: float,
	rng: RandomNumberGenerator
) -> Vector2:
	var ahead := rng.randf_range(ahead_min_m, ahead_max_m)
	var z_off := rng.randf_range(-spread_m, spread_m)
	return Vector2(-ahead, z_off)


static func active_cap_for_level(level: int, min_cap: int = 8, max_cap: int = 60) -> int:
	var t := clampf(float(level - 1) / 39.0, 0.0, 1.0)
	return int(roundf(lerpf(float(min_cap), float(max_cap), t)))


static func move_speed_for_level(_level: int) -> float:
	return DEFAULT_SPEED


static func ahead_range_for_level(level: int) -> Vector2:
	var t := clampf(float(level - 1) / 39.0, 0.0, 1.0)
	var min_ahead := lerpf(40.0, 30.0, t)
	var max_ahead := 110.0
	return Vector2(min_ahead, max_ahead)


static func z_spread_for_level(level: int) -> float:
	var t := clampf(float(level - 1) / 39.0, 0.0, 1.0)
	return lerpf(25.0, 55.0, t)
