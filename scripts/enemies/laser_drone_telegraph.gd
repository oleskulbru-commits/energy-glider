class_name LaserDroneTelegraph
extends RefCounted

## Shared timing for the laser drone's on-screen targeting reticle.

const SHRINK_SEC := 8.0
const BLINK_SEC := 2.0
const BLINK_INTERVAL_SEC := 0.12
const POWER_ON_GLITCH_SEC := 0.96
const POWER_ON_GLITCH_INTERVAL_SEC := 0.16
const POWER_OFF_GLITCH_SEC := 0.48
const POWER_GLITCH_INTERVAL_SEC := 0.08
const START_SCALE := 2.2
const END_SCALE := 0.35


static func telegraph_total_sec() -> float:
	return SHRINK_SEC + BLINK_SEC


static func phase_at(elapsed: float) -> String:
	if elapsed < SHRINK_SEC:
		return "shrink"
	if elapsed < SHRINK_SEC + BLINK_SEC:
		return "blink"
	return "done"


static func scale_at(elapsed: float) -> float:
	if elapsed >= SHRINK_SEC:
		return END_SCALE
	var t := clampf(elapsed / SHRINK_SEC, 0.0, 1.0)
	return lerpf(START_SCALE, END_SCALE, t)


static func is_blinking(elapsed: float) -> bool:
	return elapsed >= SHRINK_SEC and elapsed < SHRINK_SEC + BLINK_SEC


## 0 at blink start, 1 when the ring completes and the blast should fire.
static func circle_trace_progress(elapsed: float) -> float:
	if elapsed < SHRINK_SEC:
		return 0.0
	if elapsed >= SHRINK_SEC + BLINK_SEC:
		return 1.0
	var blink_elapsed := elapsed - SHRINK_SEC
	return clampf(blink_elapsed / BLINK_SEC, 0.0, 1.0)


static func brackets_visible(elapsed: float) -> bool:
	if not is_blinking(elapsed):
		return true
	var blink_elapsed := elapsed - SHRINK_SEC
	return int(floor(blink_elapsed / BLINK_INTERVAL_SEC)) % 2 == 0


static func blink_visible(elapsed: float) -> bool:
	return brackets_visible(elapsed)


static func power_on_lit(elapsed: float) -> bool:
	if elapsed >= POWER_ON_GLITCH_SEC:
		return true
	if elapsed <= 0.0:
		return false
	var step := int(floor((elapsed - 0.0001) / POWER_ON_GLITCH_INTERVAL_SEC))
	return step % 2 == 1


static func power_off_lit(off_elapsed: float) -> bool:
	if off_elapsed >= POWER_OFF_GLITCH_SEC:
		return false
	if off_elapsed <= 0.0:
		return true
	var step := int(floor((off_elapsed - 0.0001) / POWER_GLITCH_INTERVAL_SEC))
	return step % 2 == 0


## Spot / HUD visibility during the main 10 s telegraph (excludes power-off shutdown).
static func reticle_lit(elapsed: float) -> bool:
	if not power_on_lit(elapsed):
		return false
	if is_blinking(elapsed):
		return brackets_visible(elapsed)
	return true


static func frame_index_for_telegraph(elapsed: float, frame_count: int) -> int:
	if frame_count <= 1:
		return 0
	var total := telegraph_total_sec()
	if total <= 0.0:
		return 0
	var t := clampf(elapsed / total, 0.0, 1.0)
	return clampi(int(floor(t * float(frame_count - 1))), 0, frame_count - 1)
