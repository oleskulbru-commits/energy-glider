class_name LaserDrone
extends "res://scripts/enemies/combat_drone.gd"

## Glass-cannon drone: shrinking HUD reticle telegraph, then one unavoidable 35-damage blast.

const GliderHUDScript = preload("res://scripts/ui/glider_hud.gd")
const LaserDroneTelegraphScript = preload("res://scripts/enemies/laser_drone_telegraph.gd")
const DroneLaserBlastScript = preload("res://scripts/enemies/drone_laser_blast.gd")
const LaserDroneFlareScript = preload("res://scripts/enemies/laser_drone_flare.gd")

const LASER_MAX_HEALTH := 15
const TELEGRAPH_TOTAL_SEC := (
	LaserDroneTelegraphScript.SHRINK_SEC + LaserDroneTelegraphScript.BLINK_SEC
)
const BLAST_DAMAGE := 35
const RELOAD_SEC := 5.0
const FLEE_RADIUS_M := 50.0

enum AttackPhase { CHARGE, RELOAD }

var _attack_phase := AttackPhase.CHARGE
var _telegraph_elapsed := 0.0
var _reload_left := 0.0
var _has_fired_blast := false
var _ui_reticle_active := false
var _active_blast: Node3D
var _flare: Node3D


func _ready() -> void:
	_cube_color = Color(0.9, 0.12, 0.1)
	super._ready()
	_max_health = LASER_MAX_HEALTH
	_hp = LASER_MAX_HEALTH
	_ensure_flare()
	add_to_group("laser_drone")


func _exit_tree() -> void:
	_clear_reticle()


func apply_difficulty(bonus: float) -> void:
	if bonus <= 0.0:
		return
	move_speed = float(_scaled_stat(move_speed, bonus))


func can_despawn_when_behind() -> bool:
	return _has_fired_blast


func desired_velocity_xz() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		return Vector3.ZERO
	if _stun_left > 0.0:
		return Vector3.ZERO
	var dist := xz_distance_to_target()
	if dist > FLEE_RADIUS_M:
		return Vector3.ZERO
	var away := global_position - _target.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(1.0, 0.0, 0.0)
	else:
		away = away.normalized()
	return away * _get_move_speed()


func _update_fly_state() -> void:
	pass


func _steer(delta: float) -> void:
	var desired := desired_velocity_xz()
	if desired.length_squared() < 0.0001:
		velocity = Vector3(velocity.x, 0.0, velocity.z).lerp(Vector3.ZERO, minf(delta * 6.0, 1.0))
		velocity.y = 0.0
		return
	velocity = desired


func _update_weapons(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _stun_left > 0.0:
		return

	match _attack_phase:
		AttackPhase.RELOAD:
			_tick_reload(delta)
		_:
			_tick_charge(delta)


func _tick_reload(delta: float) -> void:
	_update_flare()
	_reload_left = maxf(_reload_left - delta, 0.0)
	if _reload_left > 0.0:
		return
	_attack_phase = AttackPhase.CHARGE
	_telegraph_elapsed = 0.0
	_ensure_reticle()


func _tick_charge(delta: float) -> void:
	_ensure_reticle()
	_telegraph_elapsed += delta
	_update_reticle(delta)
	_update_flare()
	if _telegraph_elapsed < TELEGRAPH_TOTAL_SEC:
		return
	if _fire_blast():
		_has_fired_blast = true
		_clear_reticle()
		_attack_phase = AttackPhase.RELOAD
		_reload_left = RELOAD_SEC
		_telegraph_elapsed = 0.0


func _get_hud() -> GliderHUD:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("glider_hud") as GliderHUD


func _ensure_reticle() -> void:
	if _ui_reticle_active:
		return
	var hud := _get_hud()
	if hud == null:
		return
	hud.set_laser_target_telegraph_active(true)
	_ui_reticle_active = true


func _update_reticle(delta: float) -> void:
	if not _ui_reticle_active:
		return
	var hud := _get_hud()
	if hud == null:
		return
	hud.update_laser_target_telegraph(_telegraph_elapsed, delta)


func _ensure_flare() -> void:
	if _flare != null and is_instance_valid(_flare):
		return
	_flare = LaserDroneFlareScript.new()
	_flare.name = "TargetFlare"
	add_child(_flare)


func _update_flare() -> void:
	_ensure_flare()
	if _flare == null or not is_instance_valid(_flare):
		return
	if not _flare.has_method("set_charge_phase"):
		return
	if _attack_phase == AttackPhase.RELOAD:
		_flare.set_reload_phase(true)
		return
	_flare.set_reload_phase(false)
	var ratio := clampf(_telegraph_elapsed / TELEGRAPH_TOTAL_SEC, 0.0, 1.0)
	_flare.set_charge_phase(true, ratio)


func _fire_blast() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var tree := get_tree()
	if tree == null:
		return false
	if _active_blast != null and is_instance_valid(_active_blast):
		_active_blast.queue_free()
	_active_blast = DroneLaserBlastScript.fire(
		tree, global_position, _target, _terrain, BLAST_DAMAGE
	)
	return true


func _clear_reticle() -> void:
	if not _ui_reticle_active:
		return
	var hud := _get_hud()
	if hud != null:
		hud.set_laser_target_telegraph_active(false)
	_ui_reticle_active = false


func _die(from_pos: Vector3) -> void:
	_clear_reticle()
	if _active_blast != null and is_instance_valid(_active_blast):
		_active_blast.queue_free()
		_active_blast = null
	super._die(from_pos)
