class_name LevelTerrainResolver
extends RefCounted

## Segment table + catalog profiles → dune sampling knobs (slab-cached).

const LevelRunScript = preload("res://scripts/game/level_run.gd")
const LevelTerrainCatalogScript = preload("res://scripts/game/level_terrain_catalog.gd")

const SLAB_M := 256.0
const BLEND_WIDTH_M := 150.0

const BAND_AMPLITUDE := {"min": 14.0, "max": 34.0}
const BAND_WARP := {"min": 22.0, "max": 72.0}
const BAND_RIDGE := {"min": 1.48, "max": 2.0}

static var _slab_cache: Dictionary = {} # int -> Dictionary
static var _segment_param_cache: Dictionary = {} # int segment index -> Dictionary
static var _cache_seed: int = -999


static func params_at_world_x(world_x: float, origin_x: float = 0.0) -> Dictionary:
	_ensure_cache_valid()
	var west_m := maxf(origin_x - world_x, 0.0)
	var slab_f := west_m / SLAB_M
	var slab0 := int(floor(slab_f))
	var frac := slab_f - float(slab0)
	var a := _params_for_slab(slab0, origin_x)
	if frac <= 0.0001:
		return a
	var b := _params_for_slab(slab0 + 1, origin_x)
	return _lerp_params(a, b, frac)


static func journey_length_m() -> float:
	return LevelRunScript.journey_length_m()


static func _ensure_cache_valid() -> void:
	var seed_now: int = LevelRunScript.world_seed()
	if seed_now == _cache_seed and not _slab_cache.is_empty():
		return
	_cache_seed = seed_now
	_slab_cache.clear()
	_segment_param_cache.clear()


static func _params_for_slab(slab: int, origin_x: float) -> Dictionary:
	if _slab_cache.has(slab):
		return _slab_cache[slab]
	var west_m := maxf(float(slab) * SLAB_M + SLAB_M * 0.5, 0.0)
	var world_x := origin_x - west_m
	var params := _params_at_west_m(west_m, world_x, origin_x)
	_slab_cache[slab] = params
	return params


static func _params_at_west_m(west_m: float, _world_x: float, _origin_x: float) -> Dictionary:
	var primary_seg = LevelRunScript.segment_at_west_m(west_m)
	var primary := _params_for_segment(primary_seg)
	var blend := _boundary_blend(west_m, primary_seg.index)
	if blend.is_empty():
		return primary
	var other := LevelRunScript.segment_at_index(int(blend.other_index))
	var secondary := _params_for_segment(other)
	return _lerp_params(primary, secondary, float(blend.t))


static func _params_for_segment(segment) -> Dictionary:
	if segment == null:
		return _band_params(0.5)
	var key: int = segment.index
	if _segment_param_cache.has(key):
		return _segment_param_cache[key]
	var base := _band_params(segment.intensity)
	var mods := _profile_modifiers(segment.profile_id)
	var params := _apply_modifiers(base, mods)
	_segment_param_cache[key] = params
	return params


static func _boundary_blend(west_m: float, segment_index: int) -> Dictionary:
	var bounds: Vector2 = LevelRunScript.segment_east_west_x(segment_index)
	# bounds are relative X (east, west) with west more negative; convert to west_m.
	var east_west_m := maxf(-bounds.x, 0.0)
	var west_west_m := maxf(-bounds.y, 0.0)
	if segment_index < LevelRunScript.segment_count():
		var dist_west := absf(west_m - west_west_m)
		if dist_west < BLEND_WIDTH_M:
			var t := 1.0 - (dist_west / BLEND_WIDTH_M)
			t = smoothstep(0.0, 1.0, t) * 0.5
			return {"other_index": segment_index + 1, "t": t}
	if segment_index > 1:
		var dist_east := absf(west_m - east_west_m)
		if dist_east < BLEND_WIDTH_M:
			var t := 1.0 - (dist_east / BLEND_WIDTH_M)
			t = smoothstep(0.0, 1.0, t) * 0.5
			return {"other_index": segment_index - 1, "t": t}
	return {}


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


static func _identity_mods() -> Dictionary:
	return {
		"amplitude_scale": 1.0,
		"warp_scale": 1.0,
		"ridge_power_add": 0.0,
		"frequency_scale": 1.0,
		"z_scale": 1.0,
		"flat_bias_add": 0.0,
		"crest_sharpness_scale": 1.0,
	}


static func _profile_modifiers(profile_id: String) -> Dictionary:
	var profile = LevelTerrainCatalogScript.get_profile(profile_id)
	if profile == null:
		return _identity_mods()
	if profile.is_hybrid():
		return _compose_atomic_mods(profile.composed_of)
	return _atomic_mods(profile_id)


static func _compose_atomic_mods(atomic_ids: Array) -> Dictionary:
	if atomic_ids.is_empty():
		return _identity_mods()
	var acc := _identity_mods()
	acc.amplitude_scale = 0.0
	acc.warp_scale = 0.0
	acc.ridge_power_add = 0.0
	acc.frequency_scale = 0.0
	acc.z_scale = 0.0
	acc.flat_bias_add = 0.0
	acc.crest_sharpness_scale = 0.0
	var n := float(atomic_ids.size())
	for id in atomic_ids:
		var m := _atomic_mods(String(id))
		acc.amplitude_scale += m.amplitude_scale
		acc.warp_scale += m.warp_scale
		acc.ridge_power_add += m.ridge_power_add
		acc.frequency_scale += m.frequency_scale
		acc.z_scale += m.z_scale
		acc.flat_bias_add += m.flat_bias_add
		acc.crest_sharpness_scale += m.crest_sharpness_scale
	acc.amplitude_scale /= n
	acc.warp_scale /= n
	acc.ridge_power_add /= n
	acc.frequency_scale /= n
	acc.z_scale /= n
	acc.flat_bias_add /= n
	acc.crest_sharpness_scale /= n
	return acc


static func _atomic_mods(atomic_id: String) -> Dictionary:
	var table := {
		"rolling_lanes": {"amplitude_scale": 0.9, "frequency_scale": 0.7, "z_scale": 0.7},
		"gentle_swells": {"amplitude_scale": 0.85, "frequency_scale": 0.65, "crest_sharpness_scale": 0.9},
		"mid_cadence": {"frequency_scale": 1.0},
		"tight_chop": {"frequency_scale": 1.18, "amplitude_scale": 0.95},
		"mega_rollers": {"frequency_scale": 0.55, "amplitude_scale": 1.1, "z_scale": 0.65},
		"soft_shoulders": {"crest_sharpness_scale": 0.85, "ridge_power_add": -0.12},
		"knife_crests": {"crest_sharpness_scale": 1.12, "ridge_power_add": 0.14},
		"razor_spine": {"crest_sharpness_scale": 1.15, "ridge_power_add": 0.18, "z_scale": 0.9},
		"broken_teeth": {"crest_sharpness_scale": 1.1, "frequency_scale": 1.08, "z_scale": 1.08},
		"soft_bowls": {"amplitude_scale": 0.95, "flat_bias_add": 0.04, "z_scale": 1.05},
		"deep_basins": {"amplitude_scale": 1.12, "flat_bias_add": -0.02, "z_scale": 1.08},
		"escape_gulches": {"z_scale": 1.08, "frequency_scale": 1.05},
		"easy_grades": {"amplitude_scale": 0.9, "frequency_scale": 0.85},
		"climb_trains": {"amplitude_scale": 1.1, "frequency_scale": 0.82, "flat_bias_add": -0.03},
		"wall_faces": {"amplitude_scale": 1.15, "frequency_scale": 1.08, "ridge_power_add": 0.1},
		"relief_after_climb": {"amplitude_scale": 1.05, "flat_bias_add": 0.03},
		"punish_climbs": {"amplitude_scale": 1.12, "flat_bias_add": -0.05},
		"corridor_west": {"z_scale": 0.55},
		"mild_weave": {"z_scale": 1.05},
		"slalom_spines": {"z_scale": 1.1, "frequency_scale": 1.05},
		"maze_basins": {"z_scale": 1.1, "warp_scale": 1.08},
		"honest_terrain": {"warp_scale": 0.55},
		"soft_warp": {"warp_scale": 0.85},
		"twisted_warp": {"warp_scale": 1.12},
		"frequent_flats": {"flat_bias_add": 0.14},
		"occasional_shelves": {"flat_bias_add": 0.05},
		"scarce_flats": {"flat_bias_add": -0.1},
		"glide_garden": {"crest_sharpness_scale": 0.95, "flat_bias_add": 0.04},
		"carry_paradise": {"frequency_scale": 0.75, "flat_bias_add": 0.06},
		"momentum_tax": {"frequency_scale": 1.08, "flat_bias_add": -0.04, "amplitude_scale": 1.05},
		"ridge_gauntlet": {"crest_sharpness_scale": 1.12, "frequency_scale": 1.1, "flat_bias_add": -0.06},
		"blind_backsides": {"crest_sharpness_scale": 1.08, "ridge_power_add": 0.08},
		"cliffette_drops": {"amplitude_scale": 1.12, "ridge_power_add": 0.12},
		"no_line_chaos": {"z_scale": 1.1, "warp_scale": 1.1, "frequency_scale": 1.08},
		"syncopated_ridges": {"frequency_scale": 1.1, "crest_sharpness_scale": 1.08},
	}
	var mods := _identity_mods()
	if not table.has(atomic_id):
		return mods
	var entry: Dictionary = table[atomic_id]
	for key in entry.keys():
		mods[key] = entry[key]
	return mods


static func _apply_modifiers(base: Dictionary, mods: Dictionary) -> Dictionary:
	# Caps keep feature width above coarse mesh spacing so hover stays on the sand.
	return {
		"amplitude": maxf(base.amplitude * mods.amplitude_scale, 6.0),
		"warp_strength": clampf(base.warp_strength * mods.warp_scale, 8.0, 78.0),
		"ridge_power": clampf(base.ridge_power + mods.ridge_power_add, 1.2, 2.4),
		"frequency_scale": clampf(base.frequency_scale * mods.frequency_scale, 0.5, 1.12),
		"z_scale": clampf(base.z_scale * mods.z_scale, 0.55, 1.12),
		"flat_bias": clampf(base.flat_bias + mods.flat_bias_add, -0.25, 0.25),
		"crest_sharpness": clampf(base.crest_sharpness * mods.crest_sharpness_scale, 0.75, 1.3),
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
