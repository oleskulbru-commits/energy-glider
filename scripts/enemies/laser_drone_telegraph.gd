class_name LaserDroneTelegraph
extends RefCounted

## Shared timing for the laser drone's on-screen targeting reticle.

const SHRINK_SEC := 8.0
const BLINK_SEC := 2.0
const BLINK_INTERVAL_SEC := 0.12
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
