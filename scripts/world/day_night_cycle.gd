class_name DayNightCycle
extends Node

signal dawn
signal dusk
signal time_changed(normalized: float)

@export var sun_path: NodePath
@export var world_environment_path: NodePath
@export var day_duration_sec := 900.0
@export var start_time := 0.25

const SKY_DAY_TOP := Color(0.35, 0.55, 0.85)
const SKY_DAY_HORIZON := Color(0.85, 0.72, 0.55)
const SKY_NIGHT_TOP := Color(0.04, 0.06, 0.14)
const SKY_NIGHT_HORIZON := Color(0.12, 0.1, 0.18)
const FOG_DAY := Color(0.55, 0.58, 0.62)
const FOG_NIGHT := Color(0.08, 0.09, 0.14)

var time_normalized := 0.25

var _sun: DirectionalLight3D
var _environment: WorldEnvironment
var _sky_material: ProceduralSkyMaterial
var _dusk_sent := false


func _ready() -> void:
	add_to_group("day_night_cycle")
	time_normalized = clampf(start_time, 0.0, 1.0)
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
	if day_duration_sec <= 0.0:
		return
	var prev := time_normalized
	time_normalized = fmod(time_normalized + delta / day_duration_sec, 1.0)
	if prev > 0.7 and time_normalized < 0.1:
		_dusk_sent = false
		dawn.emit()
	_apply_time_visuals()
	if not _dusk_sent and time_normalized >= 0.75 and prev < 0.75:
		_dusk_sent = true
		dusk.emit()
	if not is_equal_approx(prev, time_normalized):
		time_changed.emit(time_normalized)


func skip_to_dawn() -> void:
	time_normalized = 0.25
	_dusk_sent = false
	dawn.emit()
	_apply_time_visuals()
	time_changed.emit(time_normalized)


func get_heat_factor() -> float:
	var noon_dist := absf(time_normalized - 0.5)
	var daylight := 1.0 - clampf((noon_dist - 0.2) / 0.3, 0.0, 1.0)
	return lerpf(0.4, 1.0, daylight)


func is_night() -> bool:
	return time_normalized >= 0.75 or time_normalized < 0.2


func _apply_time_visuals() -> void:
	var day_blend := _daylight_blend()
	if _sun != null:
		var sun_angle := lerpf(-PI * 0.15, PI * 1.15, time_normalized)
		_sun.rotation = Vector3(sun_angle, deg_to_rad(35.0), 0.0)
		_sun.light_energy = lerpf(0.25, 1.35, day_blend)
		_sun.light_color = Color(1.0, 0.88, 0.72).lerp(Color(0.55, 0.65, 0.95), 1.0 - day_blend)

	if _sky_material != null:
		_sky_material.sky_top_color = SKY_NIGHT_TOP.lerp(SKY_DAY_TOP, day_blend)
		_sky_material.sky_horizon_color = SKY_NIGHT_HORIZON.lerp(SKY_DAY_HORIZON, day_blend)

	if _environment != null and _environment.environment != null:
		_environment.environment.fog_light_color = FOG_NIGHT.lerp(FOG_DAY, day_blend)
		_environment.environment.fog_density = lerpf(0.0022, 0.00085, day_blend)


func _daylight_blend() -> float:
	if time_normalized < 0.2:
		return clampf(time_normalized / 0.2, 0.0, 1.0) * 0.35
	if time_normalized > 0.8:
		return clampf((1.0 - time_normalized) / 0.2, 0.0, 1.0) * 0.35
	if time_normalized < 0.3:
		return lerpf(0.35, 1.0, (time_normalized - 0.2) / 0.1)
	if time_normalized > 0.7:
		return lerpf(1.0, 0.35, (time_normalized - 0.7) / 0.1)
	return 1.0
