class_name ChargerPill
extends SwarmPill

## Larger green pill: ramps to 2x speed within 15 m and hits harder.

const CRAWLER_VISUAL_SCALE_MULT := 3.0
const CHARGER_CONTACT_DAMAGE := 12
const CHARGER_MAX_HEALTH := 25
const AGGRO_RANGE_M := 15.0
const AGGRO_SPEED_MULT := 2.0
const AGGRO_RAMP_SEC := 0.45
## Keep 2x after the player leaves aggro range (not player-speed matching).
const AGGRO_LINGER_SEC := 3.0

var _speed_mult := 1.0
var _aggro_linger_left := 0.0
var _aggro_latched := false


func _ready() -> void:
	super._ready()
	add_to_group("charger_pill")
	contact_damage = CHARGER_CONTACT_DAMAGE
	_max_health = CHARGER_MAX_HEALTH
	_hp = get_max_health()


func _get_crawler_visual_scale_mult() -> float:
	return CRAWLER_VISUAL_SCALE_MULT


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
