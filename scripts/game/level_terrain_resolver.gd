class_name LevelTerrainResolver
extends RefCounted

## Westbound journey intensity → dune sampling knobs.
## Continuous distance ramp (not per-tower / per-level). Catalog remains for later authoring.

const LevelLayoutScript = preload("res://scripts/game/level_layout.gd")

## Match chunk size so streamed meshes reuse cached knobs; soft-lerp between slabs.
const SLAB_M := 256.0

## Mild near home → firmer far west across the authored run length.
## Kept below the old extreme so denser meshes can track hover height.
const INTENSITY_START := 0.08
const INTENSITY_END := 0.64

const BAND_AMPLITUDE := {"min": 14.0, "max": 34.0}
const BAND_WARP := {"min": 22.0, "max": 72.0}
const BAND_RIDGE := {"min": 1.48, "max": 2.0}

static var _slab_cache: Dictionary = {} # int -> Dictionary
static var _journey_m := -1.0


static func params_at_world_x(world_x: float, origin_x: float = 0.0) -> Dictionary:
	var west_m := maxf(origin_x - world_x, 0.0)
	var slab_f := west_m / SLAB_M
	var slab0 := int(floor(slab_f))
	var frac := slab_f - float(slab0)
	var a := _params_for_slab(slab0)
	if frac <= 0.0001:
		return a
	var b := _params_for_slab(slab0 + 1)
	return _lerp_params(a, b, frac)


static func _params_for_slab(slab: int) -> Dictionary:
	if _slab_cache.has(slab):
		return _slab_cache[slab]
	var west_m := maxf(float(slab) * SLAB_M, 0.0)
	var t := clampf(west_m / _journey_length_m(), 0.0, 1.0)
	t = smoothstep(0.0, 1.0, t)
	var intensity := lerpf(INTENSITY_START, INTENSITY_END, t)
	var params := _band_params(intensity)
	_slab_cache[slab] = params
	return params


static func _journey_length_m() -> float:
	if _journey_m > 0.0:
		return _journey_m
	var total := 0.0
	for distance in LevelLayoutScript.SEGMENT_DISTANCES_M:
		total += float(distance)
	_journey_m = maxf(total, 1.0)
	return _journey_m


static func _band_params(intensity: float) -> Dictionary:
	var t := clampf(intensity, 0.0, 1.0)
	return {
		"amplitude": lerpf(float(BAND_AMPLITUDE["min"]), float(BAND_AMPLITUDE["max"]), t),
		"warp_strength": lerpf(float(BAND_WARP["min"]), float(BAND_WARP["max"]), t),
		"ridge_power": lerpf(float(BAND_RIDGE["min"]), float(BAND_RIDGE["max"]), t),
		"frequency_scale": lerpf(0.72, 1.10, t),
		"z_scale": lerpf(0.75, 1.15, t),
		"flat_bias": lerpf(0.12, -0.05, t),
		"crest_sharpness": lerpf(0.92, 1.06, t),
	}


static func _lerp_params(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	return {
		"amplitude": lerpf(a.amplitude, b.amplitude, t),
		"warp_strength": lerpf(a.warp_strength, b.warp_strength, t),
		"ridge_power": lerpf(a.ridge_power, b.ridge_power, t),
		"frequency_scale": lerpf(a.frequency_scale, b.frequency_scale, t),
		"z_scale": lerpf(a.z_scale, b.z_scale, t),
		"flat_bias": lerpf(a.flat_bias, b.flat_bias, t),
		"crest_sharpness": lerpf(a.crest_sharpness, b.crest_sharpness, t),
	}
