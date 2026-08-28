class_name GliderVfxFadeEnvelope
extends RefCounted

const DEFAULT_FADE_IN := 0.12
const DEFAULT_FADE_OUT := 0.25
const VISIBILITY_THRESHOLD := 0.02
const DORMANT_EPSILON := 0.001

var value := 0.0
var target := 0.0
var fade_in_duration := DEFAULT_FADE_IN
var fade_out_duration := DEFAULT_FADE_OUT


func step(delta: float) -> void:
	if is_equal_approx(value, target):
		return
	var duration := fade_in_duration if target > value else fade_out_duration
	var rate := 1.0 / maxf(duration, 0.001)
	value = move_toward(value, target, rate * delta)


func is_dormant() -> bool:
	return target <= DORMANT_EPSILON and value <= DORMANT_EPSILON


func should_show() -> bool:
	return value > VISIBILITY_THRESHOLD or target > VISIBILITY_THRESHOLD
