class_name SailVisual
extends MeshInstance3D

const GliderInputScript = preload("res://scripts/input/glider_input.gd")
const WindFieldScript = preload("res://scripts/world/wind_field.gd")

const SAIL_DEPLOY_RATE := 7.0
const SAIL_RETRACT_RATE := 10.0
const SAIL_WIND_ALIGN_RATE := 5.0
const SAIL_WIND_ALIGN_MIN_DEPLOY := 0.15

# Raised sail pose authored in glider.tscn.
const SAIL_DEPLOYED_TRANSFORM := Transform3D(
	Vector3(0.8815985, -0.32141584, 0.34583476),
	Vector3(0.0, 0.73270047, 0.6809655),
	Vector3(-0.47200018, -0.6003381, 0.64594764),
	Vector3(-0.122160554, 0.82021284, 0.06835222)
)

# Stowed low along the deck, folded aft.
const SAIL_RETRACTED_TRANSFORM := Transform3D(
	Vector3(0.98, 0.0, 0.18),
	Vector3(0.0, 0.42, 0.0),
	Vector3(-0.18, 0.0, 0.98),
	Vector3(-0.04, 0.20, -0.22)
)

var _deploy := 0.0
var _wind_yaw := 0.0
var _wind_field: WindFieldScript


func _ready() -> void:
	transform = SAIL_RETRACTED_TRANSFORM


func _process(delta: float) -> void:
	var input := _get_glider_input()
	var target := 1.0 if input != null and input.is_sail_deployed() else 0.0
	var rate := SAIL_DEPLOY_RATE if target > _deploy else SAIL_RETRACT_RATE
	_deploy = move_toward(_deploy, target, rate * delta)

	var base_transform := SAIL_RETRACTED_TRANSFORM.interpolate_with(SAIL_DEPLOYED_TRANSFORM, _deploy)
	var wind_yaw := _update_wind_yaw(delta)
	var wind_basis := Basis.from_euler(Vector3(0.0, wind_yaw, 0.0))
	transform = base_transform * Transform3D(wind_basis, Vector3.ZERO)


func get_deploy_blend() -> float:
	return _deploy


func get_wind_yaw() -> float:
	return _wind_yaw


func _update_wind_yaw(delta: float) -> float:
	if _deploy < SAIL_WIND_ALIGN_MIN_DEPLOY:
		_wind_yaw = lerpf(_wind_yaw, 0.0, SAIL_WIND_ALIGN_RATE * delta)
		return _wind_yaw * _deploy

	if _wind_field == null and is_inside_tree():
		_wind_field = get_tree().get_first_node_in_group("wind_field") as WindFieldScript
	if _wind_field == null:
		return _wind_yaw * _deploy

	var glider := _get_glider()
	if glider == null:
		return _wind_yaw * _deploy

	var wind := _wind_field.get_wind_at(global_position)
	var wind_horizontal := Vector3(wind.x, 0.0, wind.z)
	if wind_horizontal.length_squared() < 0.0001:
		return _wind_yaw * _deploy

	var local_wind := glider.global_basis.inverse() * wind_horizontal.normalized()
	var target_yaw := atan2(local_wind.x, local_wind.z)
	_wind_yaw = lerp_angle(_wind_yaw, target_yaw, SAIL_WIND_ALIGN_RATE * delta)
	return _wind_yaw * _deploy


func _get_glider() -> Node3D:
	var visual := get_parent()
	if visual == null:
		return null
	return visual.get_parent() as Node3D


func _get_glider_input() -> GliderInputScript:
	var visual := get_parent()
	if visual == null:
		return null
	var glider := visual.get_parent()
	if glider == null:
		return null
	var direct := glider.get_node_or_null("GliderInput") as GliderInputScript
	if direct != null:
		return direct
	var rig := glider.get_parent()
	if rig == null:
		return null
	return rig.get_node_or_null("GliderInput") as GliderInputScript
