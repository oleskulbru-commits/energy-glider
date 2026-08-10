class_name LevelRunTests
extends RefCounted

## Seeded run generator assertions (no mesh builds).

const LevelRunScript = preload("res://scripts/game/level_run.gd")
const LevelRunGeneratorScript = preload("res://scripts/game/level_run_generator.gd")


func run() -> String:
	if LevelRunGeneratorScript.DISTANCE_SCHEDULE_M.size() != LevelRunGeneratorScript.SEGMENT_COUNT:
		return "Distance schedule size mismatch"
	var total := LevelRunGeneratorScript.total_journey_m()
	if total < 170000.0 or total > 180000.0:
		return "Unexpected journey length %.1f" % total

	LevelRunScript.generate(12345)
	if LevelRunScript.segment_count() != 40:
		return "Expected 40 segments"
	var offsets: Array[float] = LevelRunScript.tower_x_offsets_from_origin()
	if offsets.size() != 40:
		return "Expected 40 tower offsets"
	if not is_equal_approx(offsets[0], -1000.0):
		return "First tower should be at -1000"
	if not is_equal_approx(offsets[offsets.size() - 1], -total):
		return "Last tower should be at -journey"

	var seg1 = LevelRunScript.segment_at_index(1)
	if seg1.intensity > LevelRunGeneratorScript.INTENSITY_START + 0.12:
		return "Segment 1 should stay near low intensity"
	for i in 5:
		var early = LevelRunScript.segment_at_index(i + 1)
		if early.band_id != "TUTORIAL" and early.band_id != "EASY":
			return "Early segment %d should be TUTORIAL/EASY (got %s)" % [i + 1, early.band_id]
		var pool: Array = LevelRunGeneratorScript.HYBRID_POOLS[early.band_id]
		if not String(early.profile_id) in pool:
			return "Early segment %d profile %s not in band pool" % [i + 1, early.profile_id]

	LevelRunScript.generate(12345)
	var profiles_a: Array[String] = []
	var intensities_a: Array[float] = []
	for i in 40:
		var seg = LevelRunScript.segment_at_index(i + 1)
		profiles_a.append(seg.profile_id)
		intensities_a.append(seg.intensity)

	LevelRunScript.generate(12345)
	for i in 40:
		var seg = LevelRunScript.segment_at_index(i + 1)
		if seg.profile_id != profiles_a[i] or not is_equal_approx(seg.intensity, intensities_a[i]):
			return "Same seed should reproduce run"

	LevelRunScript.generate(99999)
	var changed := false
	for i in 40:
		var seg = LevelRunScript.segment_at_index(i + 1)
		if seg.profile_id != profiles_a[i]:
			changed = true
			break
	if not changed:
		return "Different seed should change profiles"

	var early_avg := 0.0
	var late_avg := 0.0
	for i in 5:
		early_avg += LevelRunScript.segment_at_index(i + 1).intensity
		late_avg += LevelRunScript.segment_at_index(36 + i).intensity
	early_avg /= 5.0
	late_avg /= 5.0
	if late_avg <= early_avg + 0.08:
		return "Late intensity should exceed early (%.3f vs %.3f)" % [late_avg, early_avg]

	return ""
