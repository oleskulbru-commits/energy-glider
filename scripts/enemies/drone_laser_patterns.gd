class_name DroneLaserPatterns
extends RefCounted

enum Pattern { FIXED_SWEEP, WARNING_DOT, CLOSING_SWEEP, ARC_BARRIER }

const PATTERN_COUNT := 4

## Level 5–6, 7–8, 9–10, 11+ — FixedSweep, WarningDot, ClosingSweep, ArcBarrier.
const WEIGHT_BANDS: Array = [
	[55, 35, 10, 0],
	[35, 35, 25, 5],
	[20, 30, 35, 15],
	[15, 25, 35, 25],
]


static func weight_level_for(level: int) -> int:
	return clampi(level, 5, 99)


static func band_index_for(level: int) -> int:
	var wlevel := weight_level_for(level)
	if wlevel <= 6:
		return 0
	if wlevel <= 8:
		return 1
	if wlevel <= 10:
		return 2
	return 3


static func band_weights(level: int, air_targeting: bool) -> PackedInt32Array:
	var band: Array = WEIGHT_BANDS[band_index_for(level)]
	var weights := PackedInt32Array()
	weights.resize(PATTERN_COUNT)
	for i in PATTERN_COUNT:
		weights[i] = int(band[i])
	if air_targeting:
		weights[Pattern.FIXED_SWEEP] = 0
		weights = _renormalize_to_100(weights)
	return weights


static func _renormalize_to_100(weights: PackedInt32Array) -> PackedInt32Array:
	var total := 0
	for w in weights:
		total += w
	if total <= 0:
		return weights
	var out := PackedInt32Array()
	out.resize(weights.size())
	var assigned := 0
	var last_idx := 0
	for i in weights.size():
		if weights[i] <= 0:
			out[i] = 0
			continue
		last_idx = i
		var share := int(round(float(weights[i]) / float(total) * 100.0))
		out[i] = share
		assigned += share
	if assigned != 100:
		out[last_idx] += 100 - assigned
	return out


static func pick_pattern(
	level: int,
	air_targeting: bool,
	rng: RandomNumberGenerator
) -> int:
	var weights := band_weights(level, air_targeting)
	var total := 0
	for w in weights:
		total += w
	if total <= 0:
		return Pattern.CLOSING_SWEEP
	var roll := rng.randi_range(1, total)
	var acc := 0
	for i in PATTERN_COUNT:
		acc += weights[i]
		if roll <= acc:
			return i
	return Pattern.CLOSING_SWEEP


static func pick_uniform(rng: RandomNumberGenerator) -> int:
	if rng == null:
		return Pattern.FIXED_SWEEP
	return rng.randi_range(0, PATTERN_COUNT - 1)
