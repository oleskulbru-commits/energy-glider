class_name LevelRunGenerator
extends RefCounted

## Seeded builder for the westbound run: fixed distances, intensity trend + wobble, hybrid profiles.

const LevelRunSegmentScript = preload("res://scripts/game/level_run_segment.gd")

const SEGMENT_COUNT := 40
const INTENSITY_START := 0.08
const INTENSITY_END := 0.64
const WOBBLE_AMPLITUDE := 0.14
const MAX_STEP := 0.15
const PROFILE_COOLDOWN := 3
const BREATHER_EVERY := 6
const BREATHER_DROP := 0.08
const ROLLING_WINDOW := 5

## Fixed schedule (meters), segments 1..40.
const DISTANCE_SCHEDULE_M: Array[float] = [
	1000.0, 1000.0, # 1-2
	1500.0, 1500.0, # 3-4
	2000.0, 2000.0, # 5-6
	2500.0, 2500.0, # 7-8
	3000.0, 3000.0, # 9-10
	3500.0, 3500.0, 3500.0, # 11-13
	4000.0, 4000.0, # 14-15
	4500.0, 4500.0, # 16-17
	5000.0, 5000.0, 5000.0, 5000.0, 5000.0, 5000.0, 5000.0, 5000.0, # 18-25
	5500.0, 5500.0, 5500.0, 5500.0, 5500.0, 5500.0, 5500.0, 5500.0, 5500.0, # 26-34
	6000.0, 6000.0, 6000.0, 6000.0, 6000.0, # 35-39
	8000.0, # 40
]

const HYBRID_POOLS: Dictionary = {
	"TUTORIAL": ["tutorial_flow"],
	"EASY": ["learning_desert", "open_speedway", "crest_school", "bowl_runner"],
	"MEDIUM": ["slalom_medium", "knife_medium", "climb_medium", "warp_medium"],
	"HARD": ["gauntlet_hard", "basin_hard", "chaos_hard", "endurance_hard"],
	"EXTREME": ["extreme_spine", "extreme_walls", "extreme_warp"],
}


static func distance_schedule() -> Array[float]:
	return DISTANCE_SCHEDULE_M.duplicate()


static func total_journey_m() -> float:
	var total := 0.0
	for distance in DISTANCE_SCHEDULE_M:
		total += distance
	return total


static func generate(world_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_seed) * 1009 + 4177

	var segments: Array = []
	var recent_profiles: Array[String] = []
	var intensities: Array[float] = []

	for i in SEGMENT_COUNT:
		var index := i + 1
		var length_m: float = DISTANCE_SCHEDULE_M[i]
		var intensity := _intensity_for_segment(index, intensities, rng)
		intensities.append(intensity)
		var band_id := band_for_intensity(intensity)
		var profile_id := _profile_for_segment(index, band_id, recent_profiles, rng)
		recent_profiles.append(profile_id)
		if recent_profiles.size() > PROFILE_COOLDOWN:
			recent_profiles.pop_front()
		segments.append(
			LevelRunSegmentScript.new(index, length_m, intensity, band_id, profile_id)
		)
	return segments


static func band_for_intensity(intensity: float) -> String:
	if intensity < 0.125:
		return "TUTORIAL"
	if intensity < 0.375:
		return "EASY"
	if intensity < 0.625:
		return "MEDIUM"
	if intensity < 0.825:
		return "HARD"
	return "EXTREME"


static func _intensity_for_segment(
	index: int,
	previous: Array[float],
	rng: RandomNumberGenerator
) -> float:
	var t := float(index - 1) / float(SEGMENT_COUNT - 1)
	t = smoothstep(0.0, 1.0, t)
	var base := lerpf(INTENSITY_START, INTENSITY_END, t)
	var wobble := (rng.randf() * 2.0 - 1.0) * WOBBLE_AMPLITUDE
	var intensity := base + wobble

	var chapter_max := lerpf(0.28, INTENSITY_END + 0.02, t)
	var chapter_min := lerpf(INTENSITY_START, 0.42, t)
	intensity = clampf(intensity, chapter_min, chapter_max)

	if not previous.is_empty():
		var prev: float = previous[previous.size() - 1]
		intensity = clampf(intensity, prev - MAX_STEP, prev + MAX_STEP)
		if index % BREATHER_EVERY == 0 and intensity > prev:
			intensity = maxf(prev - BREATHER_DROP, chapter_min)

	if previous.size() >= ROLLING_WINDOW - 1:
		var window_sum := intensity
		for j in range(previous.size() - (ROLLING_WINDOW - 1), previous.size()):
			window_sum += previous[j]
		var avg := window_sum / float(ROLLING_WINDOW)
		var older := 0.0
		var older_count := mini(previous.size(), ROLLING_WINDOW)
		for j in range(previous.size() - older_count, previous.size()):
			older += previous[j]
		older /= float(older_count)
		if avg + 0.001 < older:
			intensity = clampf(older + 0.02, chapter_min, chapter_max)

	return clampf(intensity, INTENSITY_START, INTENSITY_END)


static func _profile_for_segment(
	_index: int,
	band_id: String,
	recent: Array[String],
	rng: RandomNumberGenerator
) -> String:
	var pool: Array = HYBRID_POOLS.get(band_id, HYBRID_POOLS["MEDIUM"])
	var candidates: Array[String] = []
	for id in pool:
		var profile_id := String(id)
		if profile_id in recent:
			continue
		candidates.append(profile_id)
	if candidates.is_empty():
		for id in pool:
			candidates.append(String(id))
	return candidates[rng.randi_range(0, candidates.size() - 1)]
