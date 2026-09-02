class_name BonusTowerPlanner
extends RefCounted

## Seeded bonus-tower layout for a westbound run. No nodes.

const INDEX_BASE := 1000
const MIN_LEVEL := 4
const WINDOW_SIZE := 8
const MAX_PER_WINDOW := 3
const SPAWN_BASE := 0.12
const SPAWN_STEP := 0.08
const SPAWN_CAP := 0.60
const MIN_OFFERS := 2
const MAX_OFFERS := 6
const PLAN_SEED := 3301
const TIER_SEED := 7919
const OFFER_SEED := 17
const GARRISON_SEED := 5513
const GARRISON_DRONE_MIN_LEVEL := 5
const GARRISON_CHARGER_CHANCE := 1.0 / 6.0
const KIND_GROUND := "ground"
const KIND_DRONE := "drone"

const TIER_Z_M: Array[float] = [900.0, 1100.0, 1300.0, 1500.0, 1800.0, 2100.0]


static func is_bonus_index(tower_index: int) -> bool:
	return tower_index >= INDEX_BASE


static func index_for_level(level: int) -> int:
	return INDEX_BASE + level


static func source_level_for_index(tower_index: int) -> int:
	if not is_bonus_index(tower_index):
		return tower_index
	return tower_index - INDEX_BASE


static func spawn_chance(misses: int) -> float:
	return clampf(SPAWN_BASE + float(maxi(misses, 0)) * SPAWN_STEP, 0.0, SPAWN_CAP)


static func radar_text(north: bool) -> String:
	var dir := "north-west" if north else "south-west"
	return "Your radar has picked up a bonus tower to the %s." % dir


static func max_unlocked_tier(level: int) -> int:
	if level >= 25:
		return 6
	if level >= 17:
		return 5
	if level >= 10:
		return 4
	if level >= 5:
		return 3
	return 2


static func offer_count_for(world_seed: int, tower_index: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_seed) * 1009 + tower_index * 9176 + OFFER_SEED
	var heads := 0
	for _i in 4:
		if rng.randf() < 0.5:
			heads += 1
	return clampi(heads + MIN_OFFERS, MIN_OFFERS, MAX_OFFERS)


static func plan(world_seed: int) -> Array[Dictionary]:
	LevelRun.ensure(world_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_seed) * PLAN_SEED + TIER_SEED
	var planned: Array[Dictionary] = []
	var misses := 0
	var spawned_in_window := 0
	var last_window := -1
	var levels := LevelRun.segment_count()
	for level in range(1, levels + 1):
		var window := int(floor(float(level - 1) / float(WINDOW_SIZE)))
		if window != last_window:
			misses = 0
			spawned_in_window = 0
			last_window = window
		if level < MIN_LEVEL:
			continue
		if spawned_in_window >= MAX_PER_WINDOW:
			continue
		var p := spawn_chance(misses)
		if rng.randf() >= p:
			misses += 1
			continue
		misses = 0
		spawned_in_window += 1
		planned.append(_entry_for_level(world_seed, level, rng))
	return planned


static func entry_for_level(world_seed: int, level: int, planned: Array[Dictionary] = []) -> Dictionary:
	var rows := planned
	if rows.is_empty():
		rows = plan(world_seed)
	for entry in rows:
		if int(entry.get("level", 0)) == level:
			return entry
	return {}


static func _entry_for_level(world_seed: int, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var span := LevelRun.segment_east_west_x(level)
	var x_offset := (span.x + span.y) * 0.5
	var tier := _pick_tier(rng, level)
	var north := rng.randf() < 0.5
	var z_abs: float = TIER_Z_M[tier - 1]
	var z_offset := z_abs if north else -z_abs
	var tower_index := index_for_level(level)
	return {
		"level": level,
		"tower_index": tower_index,
		"source_level": level,
		"x_offset": x_offset,
		"z_offset": z_offset,
		"tier": tier,
		"north": north,
		"offer_count": offer_count_for(world_seed, tower_index),
	}


static func _pick_tier(rng: RandomNumberGenerator, level: int) -> int:
	var weights := _tier_weights(level)
	var total := 0
	for w in weights:
		total += w
	if total <= 0:
		return 1
	var roll := rng.randi_range(0, total - 1)
	var acc := 0
	for i in weights.size():
		acc += weights[i]
		if roll < acc:
			return i + 1
	return weights.size()


static func _tier_weights(level: int) -> PackedInt32Array:
	var max_tier := max_unlocked_tier(level)
	var full: PackedInt32Array = PackedInt32Array()
	if max_tier <= 2:
		full = PackedInt32Array([70, 30])
	elif max_tier == 3:
		full = PackedInt32Array([35, 35, 30])
	elif max_tier == 4:
		full = PackedInt32Array([20, 25, 30, 25])
	elif max_tier == 5:
		full = PackedInt32Array([15, 20, 30, 25, 10])
	else:
		full = PackedInt32Array([8, 12, 18, 24, 22, 16])
	return full


static func garrison_plan(world_seed: int, level: int) -> Dictionary:
	if level < MIN_LEVEL:
		return empty_garrison_plan()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_seed) * GARRISON_SEED + index_for_level(level) * 4409
	var band := garrison_band(level)
	var kind := KIND_GROUND
	if level >= GARRISON_DRONE_MIN_LEVEL and rng.randf() < 0.5:
		kind = KIND_DRONE
	var count := 0
	var laser_count := 0
	var charger_count := 0
	if kind == KIND_DRONE:
		count = rng.randi_range(int(band.dmin), int(band.dmax))
		laser_count = laser_count_for(count)
	else:
		count = rng.randi_range(int(band.gmin), int(band.gmax))
		for _i in count:
			if rng.randf() < GARRISON_CHARGER_CHANCE:
				charger_count += 1
	return {
		"kind": kind,
		"count": count,
		"laser_count": laser_count,
		"charger_count": charger_count,
	}


static func empty_garrison_plan() -> Dictionary:
	return {
		"kind": KIND_GROUND,
		"count": 0,
		"laser_count": 0,
		"charger_count": 0,
	}


static func laser_count_for(drone_count: int) -> int:
	return int(floor(float(maxi(drone_count, 0)) / 4.0))


static func garrison_band(level: int) -> Dictionary:
	if level <= 7:
		return {"gmin": 6, "gmax": 7, "dmin": 1, "dmax": 1}
	if level <= 11:
		return {"gmin": 7, "gmax": 9, "dmin": 2, "dmax": 2}
	if level <= 15:
		return {"gmin": 10, "gmax": 12, "dmin": 3, "dmax": 4}
	if level <= 25:
		return {"gmin": 13, "gmax": 16, "dmin": 5, "dmax": 7}
	if level <= 35:
		return {"gmin": 17, "gmax": 21, "dmin": 8, "dmax": 10}
	return {"gmin": 25, "gmax": 25, "dmin": 13, "dmax": 13}


static func visit_locked(cleared: bool, spawned: bool, alive_count: int) -> bool:
	if cleared:
		return false
	if spawned:
		return alive_count > 0
	return true


static func should_spawn_garrison(player_pos: Vector3, tower_pos: Vector3, spawned: bool, cleared: bool, range_m: float = 500.0) -> bool:
	if cleared or spawned:
		return false
	return Vector2(player_pos.x - tower_pos.x, player_pos.z - tower_pos.z).length() <= range_m


static func should_skip_despawn(player_pos: Vector3, tower_pos: Vector3) -> bool:
	if player_pos.x >= tower_pos.x - 200.0:
		return false
	return Vector2(player_pos.x - tower_pos.x, player_pos.z - tower_pos.z).length() > 300.0


static func ring_offset(index: int, count: int, radius: float) -> Vector3:
	var n := maxi(count, 1)
	var angle := TAU * float(index) / float(n)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
