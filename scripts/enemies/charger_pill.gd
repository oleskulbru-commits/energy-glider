class_name ChargerPill
extends SwarmPill

## Larger charger: ramps to 2x speed (12 m/s) within 15 m and hits harder.

const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")

const CRAWLER_VISUAL_SCALE_MULT := 3.0
const CHARGER_CONTACT_DAMAGE := 12
const CHARGER_MAX_HEALTH := 33
const AGGRO_RANGE_M := 15.0
## 2x base (6 → 12 m/s) while aggro'd.
const AGGRO_SPEED_MULT := 2.0
const AGGRO_RAMP_SEC := 0.45
## Keep 2x after the player leaves aggro range (not player-speed matching).
const AGGRO_LINGER_SEC := 3.0
const CHARGE_DUST_INTERVAL_SEC := 0.1
const CHARGE_DUST_MIN_SPEED := 4.0

var _speed_mult := 1.0
var _aggro_linger_left := 0.0
var _aggro_latched := false
var _charge_dust_timer := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("charger_pill")
	contact_damage = CHARGER_CONTACT_DAMAGE
	_max_health = CHARGER_MAX_HEALTH
	_hp = get_max_health()


func _get_crawler_visual_scale_mult() -> float:
	return CRAWLER_VISUAL_SCALE_MULT


func get_walk_dust_preset() -> SandParticleVfx.BurstPreset:
	return SandParticleVfx.BurstPreset.MG


func get_climb_dust_preset() -> SandParticleVfx.BurstPreset:
	return SandParticleVfx.BurstPreset.DEATH


func get_charge_dust_preset() -> SandParticleVfx.BurstPreset:
	return SandParticleVfx.BurstPreset.MG


func get_walk_dust_shake_strength() -> float:
	return 0.14


func get_walk_dust_shake_radius_m() -> float:
	return 12.0


func get_climb_dust_shake_strength() -> float:
	return 0.65


func get_climb_dust_shake_radius_m() -> float:
	return 28.0


func get_charge_dust_shake_strength() -> float:
	return 0.11


func get_charge_dust_shake_radius_m() -> float:
	return 16.0


func _update_chase(delta: float) -> void:
	var dist := INF
	if _target != null and is_instance_valid(_target):
		var delta_pos := _target.global_position - global_position
		dist = Vector2(delta_pos.x, delta_pos.z).length()

	if dist <= AGGRO_RANGE_M:
		_aggro_latched = true
		_aggro_linger_left = AGGRO_LINGER_SEC
		_speed_mult = AGGRO_SPEED_MULT
	elif _aggro_latched:
		_aggro_linger_left = maxf(_aggro_linger_left - delta, 0.0)
		if _aggro_linger_left <= 0.0:
			_aggro_latched = false

	if _aggro_latched:
		_speed_mult = AGGRO_SPEED_MULT
	else:
		_speed_mult = speed_mult_step(_speed_mult, false, AGGRO_RAMP_SEC, delta)
	chase_speed_mult = _speed_mult
	_update_charge_dust(delta)


func _update_charge_dust(delta: float) -> void:
	if _is_spawn_active() or is_stunned() or not _aggro_latched:
		_charge_dust_timer = 0.0
		return
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if flat_speed < CHARGE_DUST_MIN_SPEED:
		return
	_charge_dust_timer -= delta
	if _charge_dust_timer > 0.0:
		return
	_charge_dust_timer = CHARGE_DUST_INTERVAL_SEC
	_spawn_charge_dust()


func _spawn_charge_dust() -> void:
	var tree := get_tree()
	if tree == null or _terrain == null:
		return
	var skin := get_node_or_null("Visual") as Node3D
	var anchor_pos := global_position
	if skin != null:
		var dig := skin.get_node_or_null("DigDustAnchor") as Node3D
		if dig != null:
			anchor_pos = dig.global_position
	SandImpactDustScript.spawn(
		tree,
		anchor_pos,
		_terrain,
		get_charge_dust_preset(),
		get_sand_burst_scale_mult(),
		get_charge_dust_shake_strength(),
		get_charge_dust_shake_radius_m()
	)


func _get_move_speed() -> float:
	return move_speed * chase_speed_mult


## Ramp speed multiplier toward 2x when aggro, else back to 1x.
static func speed_mult_step(
	current: float,
	in_aggro: bool,
	ramp_sec: float,
	delta: float,
	aggro_mult: float = AGGRO_SPEED_MULT
) -> float:
	var target := aggro_mult if in_aggro else 1.0
	var rate := absf(aggro_mult - 1.0) / maxf(ramp_sec, 0.001)
	return move_toward(current, target, rate * delta)
