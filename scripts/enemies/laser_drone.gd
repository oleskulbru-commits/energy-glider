class_name LaserDrone
extends "res://scripts/enemies/combat_drone.gd"

## Red cube. Weighted-random laser patterns once within weapon range.

const DroneLaserBeamScript = preload("res://scripts/enemies/drone_laser_beam.gd")
const DroneLaserPatternsScript = preload("res://scripts/enemies/drone_laser_patterns.gd")

const FIRE_SEC := 5.0
const RELOAD_SEC := 5.0

var uniform_laser_patterns := false
var _reload_left := 0.0
var _beam


func _ready() -> void:
	_cube_color = Color(0.9, 0.12, 0.1)
	super._ready()
	add_to_group("laser_drone")


func _update_weapons(delta: float) -> void:
	_reload_left = maxf(_reload_left - delta, 0.0)
	if _beam != null and is_instance_valid(_beam):
		if _beam.active:
			_beam.advance(
				delta,
				global_position,
				_target,
				_target_facing_xz(),
				can_fire_weapons(),
				uses_air_targeting()
			)
			if _beam.finished:
				_beam.queue_free()
				_beam = null
				_reload_left = RELOAD_SEC
			return
		_beam.queue_free()
		_beam = null

	if not can_fire_weapons():
		return
	if _reload_left > 0.0:
		return
	_start_beam()


func _start_beam() -> void:
	var attack_pattern: int
	if uniform_laser_patterns:
		attack_pattern = DroneLaserPatternsScript.pick_uniform(_rng)
	else:
		attack_pattern = DroneLaserPatternsScript.pick_pattern(
			_current_level(),
			uses_air_targeting(),
			_rng
		)
	_beam = DroneLaserBeamScript.new()
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	parent.add_child(_beam)
	_beam.begin(
		global_position,
		_target,
		_target_facing_xz(),
		_terrain,
		uses_air_targeting(),
		attack_pattern
	)


func _current_level() -> int:
	var progress := get_tree().get_first_node_in_group("level_progress")
	if progress != null and progress.has_method("get_current_level"):
		return maxi(int(progress.get_current_level()), 1)
	return 1


func _die(from_pos: Vector3) -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.cancel()
		_beam.queue_free()
		_beam = null
	super._die(from_pos)
