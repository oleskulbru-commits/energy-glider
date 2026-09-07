class_name MachineGunDrone
extends "res://scripts/enemies/combat_drone.gd"

## Invulnerable green cube. Align: locked X, mirrors player Z. Charge: steers toward player with a turn cap.

const DroneLaserBlastScript = preload("res://scripts/enemies/drone_laser_blast.gd")
const DroneMgRoundScript = preload("res://scripts/enemies/drone_mg_round.gd")

const CHARGE_TRIGGER_M := 100.0
const CHARGE_SPEED_MPS := 28.0
const CHARGE_TURN_RATE_DEG := 36.0
const MG_FIRE_INTERVAL_SEC := 0.05
const PASS_DAMAGE := 15
const PASS_HIT_HALF_XZ_M := CUBE_SIZE_M * DRONE_SIZE_MULT * 0.5
const PASS_HIT_ABOVE_M := CUBE_SIZE_M * DRONE_SIZE_MULT * 0.5
## Drone cruises above the player; reach down through that gap for overhead passes.
const PASS_HIT_BELOW_M := CRUISE_HEIGHT_M + 2.0
const DESPAWN_BEHIND_M := 40.0
const EXIT_DESPAWN_SEC := 1.5
const MG_AIM_PITCH_DEG := 38.0

enum FlyPhase { ALIGN, CHARGE, EXIT }

var _phase := FlyPhase.ALIGN
var _lane_forward := Vector3(-1.0, 0.0, 0.0)
var _hold_x := 0.0
var _charge_heading := Vector3(1.0, 0.0, 0.0)
var _pass_damage_dealt := false
var _exit_left := 0.0
var _mg_cooldown := 0.0
var _gun_barrel: Node3D
var _muzzle_flash: MuzzleFlash
var _tracer_size_ref: MeshInstance3D


func _ready() -> void:
	_cube_color = Color(0.22, 0.82, 0.32)
	invulnerable = true
	super._ready()
	add_to_group("machine_gun_drone")
	_cache_gun_barrel()
	_cache_tracer_reference()
	_stop_muzzle_flash()


func _cache_gun_barrel() -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		visual = _visual
	if visual == null:
		return
	_gun_barrel = visual.find_child("GunBarrel", true, false) as Node3D
	if _gun_barrel == null:
		return
	_muzzle_flash = _gun_barrel.get_node_or_null("MuzzleFlash") as MuzzleFlash
	_tracer_size_ref = visual.find_child("TracerSizeReference", true, false) as MeshInstance3D


func _cache_tracer_reference() -> void:
	if _tracer_size_ref == null:
		return
	_tracer_size_ref.visible = false


func configure(terrain: TerrainManager, target: Node3D, speed: float = BASE_MOVE_SPEED_MPS) -> void:
	super.configure(terrain, target, speed)
	_lane_forward = _target_facing_xz()
	_hold_x = global_position.x


func apply_difficulty(bonus: float) -> void:
	if bonus <= 0.0:
		return
	move_speed = float(_scaled_stat(move_speed, bonus))


func can_despawn_when_behind() -> bool:
	return _phase == FlyPhase.EXIT


func can_fire_weapons() -> bool:
	return _phase == FlyPhase.CHARGE


func _update_fly_state() -> void:
	pass


func _steer(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	match _phase:
		FlyPhase.ALIGN:
			global_position = mirror_align_position(
				global_position,
				_target.global_position,
				_hold_x
			)
			velocity = Vector3.ZERO
			_steer_heading_toward(-_lane_forward, FLIGHT_TURN_RATE_DEG, delta)
			if _should_begin_charge():
				_begin_charge()
		FlyPhase.CHARGE:
			_tick_charge_steering(delta)
			_flight_heading = _charge_heading
			_apply_flight_velocity(CHARGE_SPEED_MPS, delta)
			_try_pass_damage()
			_check_pass_transition()
		FlyPhase.EXIT:
			_flight_heading = _charge_heading
			_apply_flight_velocity(CHARGE_SPEED_MPS, delta)
			_exit_left = maxf(_exit_left - delta, 0.0)
			if _exit_left <= 0.0 or is_behind_facing(
				_target.global_position,
				_lane_forward,
				global_position,
				DESPAWN_BEHIND_M
			):
				queue_free()


func _should_begin_charge() -> bool:
	var player_pos := _target.global_position
	var aligned := mirror_align_position(global_position, player_pos, _hold_x)
	var ahead := westbound_ahead_m(aligned.x, player_pos.x)
	return should_begin_charge(ahead)


func _begin_charge() -> void:
	global_position = mirror_align_position(
		global_position,
		_target.global_position,
		_hold_x
	)
	_phase = FlyPhase.CHARGE
	_charge_heading = charge_heading_xz(global_position, _target.global_position)


func _tick_charge_steering(delta: float) -> void:
	var desired := heading_toward_player_xz(global_position, _target.global_position)
	_charge_heading = CombatDrone.rotate_heading_toward(
		_charge_heading,
		desired,
		CHARGE_TURN_RATE_DEG,
		delta
	)


func _try_pass_damage() -> void:
	if _pass_damage_dealt or _phase != FlyPhase.CHARGE:
		return
	if not player_in_pass_hitbox(global_position, _target.global_position):
		return
	_deal_pass_damage()


func _check_pass_transition() -> void:
	if _phase != FlyPhase.CHARGE:
		return
	if not has_passed_player_on_x(
		global_position.x,
		_target.global_position.x,
		_charge_heading.x
	):
		return
	_begin_exit()


func _deal_pass_damage() -> void:
	if _pass_damage_dealt:
		return
	_pass_damage_dealt = true
	DroneLaserBlastScript.apply_damage(get_tree(), PASS_DAMAGE, _target)


func _begin_exit() -> void:
	_phase = FlyPhase.EXIT
	_exit_left = EXIT_DESPAWN_SEC


func _update_weapons(delta: float) -> void:
	_mg_cooldown = maxf(_mg_cooldown - delta, 0.0)
	if _phase != FlyPhase.CHARGE:
		_stop_muzzle_flash()
		return
	if _stun_left > 0.0:
		_stop_muzzle_flash()
		return
	if _mg_cooldown > 0.0:
		return
	_fire_mg_round()
	_mg_cooldown = MG_FIRE_INTERVAL_SEC


func _fire_mg_round() -> void:
	var aim_dir := straight_fire_direction(_charge_heading, MG_AIM_PITCH_DEG)
	DroneMgRoundScript.fire(
		get_tree(),
		aim_dir,
		_terrain,
		DroneMgRoundScript.SPEED_MPS,
		_gun_barrel,
		_tracer_size_ref
	)
	if _muzzle_flash != null:
		_muzzle_flash.flash()


func _stop_muzzle_flash() -> void:
	if _muzzle_flash != null:
		_muzzle_flash.stop()


static func straight_fire_direction(flat_heading: Vector3, pitch_deg: float) -> Vector3:
	var fwd := Vector3(flat_heading.x, 0.0, flat_heading.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(-1.0, 0.0, 0.0)
	else:
		fwd = fwd.normalized()
	var pitch := deg_to_rad(clampf(pitch_deg, 5.0, 85.0))
	return Vector3(
		fwd.x * cos(pitch),
		-sin(pitch),
		fwd.z * cos(pitch)
	).normalized()


static func right_from_facing(facing_xz: Vector3) -> Vector3:
	var fwd := Vector3(facing_xz.x, 0.0, facing_xz.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(-1.0, 0.0, 0.0)
	else:
		fwd = fwd.normalized()
	return Vector3(fwd.z, 0.0, -fwd.x)


static func lateral_offset_m(
	drone_pos: Vector3,
	player_pos: Vector3,
	facing_xz: Vector3
) -> float:
	var right := right_from_facing(facing_xz)
	var offset := Vector3(drone_pos.x - player_pos.x, 0.0, drone_pos.z - player_pos.z)
	return offset.dot(right)


static func ahead_offset_m(
	drone_pos: Vector3,
	player_pos: Vector3,
	facing_xz: Vector3
) -> float:
	var fwd := Vector3(facing_xz.x, 0.0, facing_xz.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(-1.0, 0.0, 0.0)
	else:
		fwd = fwd.normalized()
	var offset := Vector3(drone_pos.x - player_pos.x, 0.0, drone_pos.z - player_pos.z)
	return offset.dot(fwd)


## Locked at spawn X; mirrors player Z while aligning. Height comes from cruise snap.
static func mirror_align_position(
	drone_pos: Vector3,
	player_pos: Vector3,
	hold_x: float
) -> Vector3:
	return Vector3(hold_x, drone_pos.y, player_pos.z)


## Westbound run: player east of the drone reads as positive ahead meters.
static func westbound_ahead_m(drone_x: float, player_x: float) -> float:
	return player_x - drone_x


## Straight east/west pass; heading steers toward the player with a capped turn rate.
static func charge_heading_xz(drone_pos: Vector3, player_pos: Vector3) -> Vector3:
	return heading_toward_player_xz(drone_pos, player_pos)


static func heading_toward_player_xz(from: Vector3, to: Vector3) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if flat.length_squared() < 0.0001:
		return Vector3(1.0, 0.0, 0.0)
	return flat.normalized()


static func align_velocity_z(
	drone_pos: Vector3,
	player_pos: Vector3,
	_player_velocity_xz: Vector3,
	_catch_up_speed_mps: float
) -> Vector3:
	var mirrored := mirror_align_position(drone_pos, player_pos, drone_pos.x)
	if is_equal_approx(mirrored.z, drone_pos.z):
		return Vector3.ZERO
	return Vector3(0.0, 0.0, signf(mirrored.z - drone_pos.z))


static func align_velocity_xz(
	drone_pos: Vector3,
	player_pos: Vector3,
	_lane_forward: Vector3,
	player_velocity_xz: Vector3,
	catch_up_speed_mps: float
) -> Vector3:
	return align_velocity_z(drone_pos, player_pos, player_velocity_xz, catch_up_speed_mps)


## When the drone is west of a westbound player, run east through their lane position.
static func lane_pass_heading(
	drone_pos: Vector3,
	player_pos: Vector3,
	lane_forward: Vector3
) -> Vector3:
	var to_player := Vector3(player_pos.x - drone_pos.x, 0.0, player_pos.z - drone_pos.z)
	if to_player.length_squared() < 0.0001:
		return Vector3(-lane_forward.x, 0.0, -lane_forward.z).normalized()
	return to_player.normalized()


static func player_in_pass_hitbox(drone_pos: Vector3, player_pos: Vector3) -> bool:
	var offset := player_pos - drone_pos
	return (
		absf(offset.x) <= PASS_HIT_HALF_XZ_M
		and absf(offset.z) <= PASS_HIT_HALF_XZ_M
		and offset.y <= PASS_HIT_ABOVE_M
		and offset.y >= -PASS_HIT_BELOW_M
	)


static func has_passed_player_on_x(
	drone_x: float,
	player_x: float,
	heading_x: float,
	margin_m: float = 1.0
) -> bool:
	if heading_x > 0.01:
		return drone_x >= player_x + margin_m
	if heading_x < -0.01:
		return drone_x <= player_x - margin_m
	return absf(drone_x - player_x) >= margin_m


static func should_begin_charge(ahead_m: float) -> bool:
	return ahead_m <= CHARGE_TRIGGER_M
