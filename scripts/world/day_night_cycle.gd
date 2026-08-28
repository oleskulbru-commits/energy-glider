class_name DayNightCycle
extends Node

signal dawn
signal dusk
signal natural_dawn
signal time_changed(normalized: float)

@export var sun_path: NodePath
@export var world_environment_path: NodePath
@export var day_phase_sec := 240.0
@export var night_phase_sec := 240.0
## When false, fog density/color stay at values set on the Environment resource (for editor tuning).
@export var animate_fog := true
## Seconds into the full day+night cycle when the scene loads (skips the darkest dawn).
@export var start_offset_sec := 20.0
## Peak sun elevation at solar noon (low southern arc, ~Norway latitude).
@export var sun_max_elevation_deg := 32.0

const TRANSITION_BLEND := 0.04
const SUN_NIGHT_ELEVATION_DEG := -25.0
const SUN_NIGHT_AZIMUTH := -PI * 0.5
const SKY_DAY_TOP := Color(0.35, 0.55, 0.85)
const SKY_DAY_HORIZON := Color(0.85, 0.72, 0.55)
const SKY_NIGHT_TOP := Color(0.04, 0.06, 0.14)
const SKY_NIGHT_HORIZON := Color(0.12, 0.1, 0.18)
const FOG_DAY := Color(0.55, 0.58, 0.62)
const FOG_NIGHT := Color(0.08, 0.09, 0.14)

var time_normalized := 0.0

var _sun: DirectionalLight3D
var _environment: WorldEnvironment
var _sky_material: ProceduralSkyMaterial
var _was_night := false
var _base_day_phase_sec := -1.0
var _base_night_phase_sec := -1.0


func _ready() -> void:
	add_to_group("day_night_cycle")
	_base_day_phase_sec = day_phase_sec
	_base_night_phase_sec = night_phase_sec
	time_normalized = _boot_time_normalized()
	_was_night = is_night()
	if sun_path != NodePath():
		_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if world_environment_path != NodePath():
		_environment = get_node_or_null(world_environment_path) as WorldEnvironment
		if _environment != null and _environment.environment != null:
			var sky := _environment.environment.sky
			if sky != null and sky.sky_material is ProceduralSkyMaterial:
				_sky_material = sky.sky_material as ProceduralSkyMaterial
	_apply_time_visuals()


func _process(delta: float) -> void:
	var cycle := get_full_cycle_sec()
	if cycle <= 0.0:
		return
	var prev := time_normalized
	time_normalized = fmod(time_normalized + delta / cycle, 1.0)
	_emit_phase_transitions(prev, time_normalized)
	_apply_time_visuals()
	if not is_equal_approx(prev, time_normalized):
		time_changed.emit(time_normalized)


func get_full_cycle_sec() -> float:
	return maxf(day_phase_sec, 0.0) + maxf(night_phase_sec, 0.0)


## Shorten day and night by `bonus` (e.g. 0.10 → 90% of authored lengths).
func apply_difficulty_bonus(bonus: float) -> void:
	if _base_day_phase_sec < 0.0:
		_base_day_phase_sec = day_phase_sec
	if _base_night_phase_sec < 0.0:
		_base_night_phase_sec = night_phase_sec
	var keep := clampf(1.0 - maxf(bonus, 0.0), 0.05, 1.0)
	day_phase_sec = maxf(_base_day_phase_sec * keep, 1.0)
	night_phase_sec = maxf(_base_night_phase_sec * keep, 1.0)


func get_day_fraction() -> float:
	var cycle := get_full_cycle_sec()
	if cycle <= 0.0:
		return 0.5
	return maxf(day_phase_sec, 0.0) / cycle


func skip_to_dawn() -> void:
	_ensure_visual_bindings()
	time_normalized = _boot_time_normalized()
	_was_night = false
	# Always emit so night survival clears even if phase detection raced.
	dawn.emit()
	_apply_time_visuals()
	# Re-apply next idle in case another system overwrote lighting this frame.
	call_deferred("_apply_time_visuals")
	time_changed.emit(time_normalized)


func _boot_time_normalized() -> float:
	var cycle := get_full_cycle_sec()
	if cycle <= 0.0:
		return 0.0
	return clampf(start_offset_sec / cycle, 0.0, 1.0)


func _ensure_visual_bindings() -> void:
	if _sun == null and sun_path != NodePath():
		_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _environment == null and world_environment_path != NodePath():
		_environment = get_node_or_null(world_environment_path) as WorldEnvironment
	if (
		_sky_material == null
		and _environment != null
		and _environment.environment != null
		and _environment.environment.sky != null
		and _environment.environment.sky.sky_material is ProceduralSkyMaterial
	):
		_sky_material = _environment.environment.sky.sky_material as ProceduralSkyMaterial


func get_heat_factor() -> float:
	if is_night():
		return 0.4
	# Noon sits at the midpoint of the day half.
	var noon := get_day_fraction() * 0.5
	var noon_dist := absf(time_normalized - noon)
	var daylight := 1.0 - clampf((noon_dist - 0.1) / 0.15, 0.0, 1.0)
	return lerpf(0.4, 1.0, daylight)


func is_night() -> bool:
	return time_normalized >= get_day_fraction()


static func night_starts_at_fraction(day_phase: float, night_phase: float) -> float:
	var cycle := maxf(day_phase, 0.0) + maxf(night_phase, 0.0)
	if cycle <= 0.0:
		return 0.5
	return maxf(day_phase, 0.0) / cycle


func _emit_phase_transitions(prev: float, next: float) -> void:
	var day_end := get_day_fraction()
	var crossed_dusk := prev < day_end and next >= day_end
	var wrapped_to_dawn := prev > next
	var crossed_dawn := wrapped_to_dawn or (prev >= day_end and next < day_end)
	if crossed_dusk:
		_was_night = true
		dusk.emit()
	elif crossed_dawn:
		_was_night = false
		dawn.emit()
		natural_dawn.emit()


func _apply_time_visuals() -> void:
	var day_blend := _daylight_blend()
	if _sun != null:
		_sun.basis = _sun_basis_for_time(time_normalized)
		_sun.light_energy = lerpf(0.25, 1.35, day_blend)
		_sun.light_color = Color(1.0, 0.88, 0.72).lerp(Color(0.55, 0.65, 0.95), 1.0 - day_blend)

	if _sky_material != null:
		_sky_material.sky_top_color = SKY_NIGHT_TOP.lerp(SKY_DAY_TOP, day_blend)
		_sky_material.sky_horizon_color = SKY_NIGHT_HORIZON.lerp(SKY_DAY_HORIZON, day_blend)

	if _environment != null and _environment.environment != null and animate_fog:
		_environment.environment.fog_light_color = FOG_NIGHT.lerp(FOG_DAY, day_blend)
		_environment.environment.fog_density = lerpf(0.0022, 0.00085, day_blend)


func _daylight_blend() -> float:
	var day_end := get_day_fraction()
	var blend := TRANSITION_BLEND
	if time_normalized < blend:
		return lerpf(0.0, 1.0, time_normalized / maxf(blend, 0.001))
	if time_normalized < day_end - blend:
		return 1.0
	if time_normalized < day_end:
		return lerpf(1.0, 0.0, (time_normalized - (day_end - blend)) / maxf(blend, 0.001))
	return 0.0


func get_daylight_blend() -> float:
	return _daylight_blend()


func get_night_blend() -> float:
	return 1.0 - get_daylight_blend()


func _sun_basis_for_time(t: float) -> Basis:
	return sun_basis_for_time(t, get_day_fraction(), sun_max_elevation_deg)


## Direction from ground toward the sun in the sky (unit vector).
static func sun_position_for_time(
	time_normalized: float,
	day_fraction: float,
	max_elevation_deg: float
) -> Vector3:
	if time_normalized >= day_fraction:
		return _sun_pos_from_angles(SUN_NIGHT_AZIMUTH, deg_to_rad(SUN_NIGHT_ELEVATION_DEG))
	var day_t := time_normalized / maxf(day_fraction, 0.001)
	var azimuth := lerpf(PI * 0.5, -PI * 0.5, day_t)
	var elevation := sin(day_t * PI) * deg_to_rad(max_elevation_deg)
	return _sun_pos_from_angles(azimuth, elevation)


static func sun_basis_for_time(
	time_normalized: float,
	day_fraction: float,
	max_elevation_deg: float
) -> Basis:
	var sun_pos := sun_position_for_time(time_normalized, day_fraction, max_elevation_deg)
	return Basis.looking_at(-sun_pos, Vector3.UP)


static func _sun_pos_from_angles(azimuth: float, elevation: float) -> Vector3:
	return Vector3(
		cos(elevation) * sin(azimuth),
		sin(elevation),
		cos(elevation) * cos(azimuth)
	).normalized()
