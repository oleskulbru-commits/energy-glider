class_name KeepGoingRewards
extends RefCounted

## Bronze, silver, then gold on west towers. Keep Going promises the shown
## reward at the next tower. Arrival pays it and reveals the next tier.
## Wait drops the promise and returns the streak to bronze. Death wipes
## every roll; the same trip does not roll again.

const TIER_BRONZE := 0
const TIER_SILVER := 1
const TIER_GOLD := 2
const TIER_COUNT := 3
const FIRST_TOWER := 1
const LAST_TOWER := 40
const VESTIGE := &"vestige"
const VESTIGE_ICON := preload("res://assets/ui/upgrade_menu/reward_vestige.jpg")

var roll_salt := 0
var applied: Array[StringName] = []
var last_payout_amount := 0

var _streak := TIER_BRONZE
var _promise_tower := -1
var _promise_tier := -1
var _promise_id := StringName()
var _rolls: Dictionary = {}
var _amounts: Dictionary = {}
var _pools: Array[PackedStringArray] = [
	PackedStringArray(),
	PackedStringArray(),
	PackedStringArray(),
]
var _icons: Dictionary = {}
var _sealed := false


func _init() -> void:
	roll_salt = randi()
	set_pool(TIER_BRONZE, PackedStringArray([VESTIGE]))
	set_pool(TIER_SILVER, PackedStringArray([VESTIGE]))
	set_pool(TIER_GOLD, PackedStringArray([VESTIGE]))
	register_icon(VESTIGE, VESTIGE_ICON)


func set_pool(tier: int, ids: PackedStringArray) -> void:
	if tier < 0 or tier >= TIER_COUNT:
		return
	_pools[tier] = ids


func register_icon(id: StringName, texture: Texture2D) -> void:
	if id == &"" or texture == null:
		return
	_icons[id] = texture


func icon_for(id: StringName) -> Texture2D:
	return _icons.get(id) as Texture2D


func note_death() -> void:
	_sealed = true
	_streak = TIER_BRONZE
	_clear_promise()
	_rolls.clear()
	_amounts.clear()


func is_sealed() -> bool:
	return _sealed


func streak() -> int:
	return _streak


func promise_tower() -> int:
	return _promise_tower


func arrive(tower_index: int, is_bonus: bool) -> StringName:
	last_payout_amount = 0
	if _sealed or not _is_west_tower(tower_index, is_bonus):
		return &""
	if _promise_tower != tower_index:
		return &""
	var paid := _promise_id
	var paid_tier := _promise_tier
	_clear_promise()
	apply(paid, paid_tier, tower_index)
	if paid_tier >= TIER_GOLD:
		_streak = TIER_BRONZE
	else:
		_streak = paid_tier + 1
	return paid


func preview_id(tower_index: int, is_bonus: bool) -> StringName:
	var tier := shown_tier(tower_index, is_bonus)
	if tier < 0:
		return &""
	return _roll(tower_index + 1, tier)


func preview_amount(tower_index: int, is_bonus: bool) -> int:
	var tier := shown_tier(tower_index, is_bonus)
	if tier < 0:
		return 0
	_roll(tower_index + 1, tier)
	return int(_amounts.get(_roll_key(tower_index + 1, tier), 0))


func paid_id(tower_index: int, tier: int, is_bonus: bool) -> StringName:
	if _sealed or not _is_west_tower(tower_index, is_bonus):
		return &""
	if tier < 0 or tier >= _streak:
		return &""
	return _roll(tower_index, tier)


func shown_tier(tower_index: int, is_bonus: bool) -> int:
	if _sealed or not _is_west_tower(tower_index, is_bonus):
		return -1
	if tower_index >= LAST_TOWER:
		return -1
	return _streak


func keep_going(tower_index: int, is_bonus: bool) -> void:
	var tier := shown_tier(tower_index, is_bonus)
	if tier < 0:
		return
	var pay_at := tower_index + 1
	_promise_tower = pay_at
	_promise_tier = tier
	_promise_id = _roll(pay_at, tier)


func wait_until_dawn() -> void:
	_clear_promise()
	_streak = TIER_BRONZE


func peek_roll(pay_tower: int, tier: int) -> StringName:
	return _rolls.get(_roll_key(pay_tower, tier), &"") as StringName


func apply(id: StringName, tier: int = -1, pay_tower: int = -1) -> void:
	if id == &"":
		return
	applied.append(id)
	var key := _roll_key(pay_tower, tier)
	if pay_tower >= 0 and _amounts.has(key):
		last_payout_amount = int(_amounts[key])
	else:
		last_payout_amount = amount_for(id, tier)


func amount_for(id: StringName, tier: int, rng: RandomNumberGenerator = null) -> int:
	if id != VESTIGE:
		return 0
	if tier == TIER_GOLD:
		return 10
	var choices := PackedInt32Array()
	if tier == TIER_BRONZE:
		choices = PackedInt32Array([1, 2, 3])
	elif tier == TIER_SILVER:
		choices = PackedInt32Array([4, 5, 6])
	else:
		return 0
	var index := randi() % choices.size()
	if rng != null:
		index = rng.randi_range(0, choices.size() - 1)
	return int(choices[index])


func _clear_promise() -> void:
	_promise_tower = -1
	_promise_tier = -1
	_promise_id = &""


func _is_west_tower(tower_index: int, is_bonus: bool) -> bool:
	return not is_bonus and tower_index >= FIRST_TOWER and tower_index <= LAST_TOWER


func _roll(pay_tower: int, tier: int) -> StringName:
	var key := _roll_key(pay_tower, tier)
	if _rolls.has(key):
		return _rolls[key]
	if _sealed:
		return &""
	var pool := _pools[tier]
	var id := StringName()
	if not pool.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(roll_salt) * 1000003 + pay_tower * 9176 + tier * 13
		id = pool[rng.randi_range(0, pool.size() - 1)]
	_rolls[key] = id
	if id != &"" and not _amounts.has(key):
		_amounts[key] = amount_for(id, tier)
	return id


func _roll_key(pay_tower: int, tier: int) -> String:
	return "%d:%d" % [pay_tower, tier]
