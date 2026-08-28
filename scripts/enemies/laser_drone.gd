class_name LaserDrone
extends "res://scripts/enemies/combat_drone.gd"

## Red cube. Ground-sweep laser once within weapon range.

const DroneLaserBeamScript = preload("res://scripts/enemies/drone_laser_beam.gd")

const FIRE_SEC := 5.0
const RELOAD_SEC := 5.0

var _reload_left := 0.0
var _beam
var _used_first_beam := false


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

	# Only fire within weapon range (including after the player passes).
	if not can_fire_weapons():
		return
	if _reload_left > 0.0:
		return
	_start_beam()


func _start_beam() -> void:
	var zigzag_first := not _used_first_beam
	_used_first_beam = true
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
		zigzag_first,
		uses_air_targeting()
	)


func _die(from_pos: Vector3) -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.cancel()
		_beam.queue_free()
		_beam = null
	super._die(from_pos)
