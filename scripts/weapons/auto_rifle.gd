class_name AutoRifle
extends Node

## Invisible Megabonk-style rifle. Only the tracer is visible.

const RifleBulletScene := preload("res://scenes/weapons/rifle_bullet.tscn")

const DAMAGE := 10
const RANGE_M := 100.0
const FIRE_INTERVAL_SEC := 3.0
const MUZZLE_UP_M := 0.85

var _rig: PlayerRig
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rig = get_parent() as PlayerRig
	_rng.randomize()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	if not _can_fire():
		return
	var origin := _muzzle_origin()
	var target := pick_target(get_tree().get_nodes_in_group("swarm_pill"), origin, RANGE_M, _rng)
	if target == null:
		return
	_fire(origin, target)
	_cooldown = FIRE_INTERVAL_SEC


func _can_fire() -> bool:
	if _rig == null:
		return false
	var glider := _rig.get_glider()
	return glider != null and not glider.is_run_ended()


func _muzzle_origin() -> Vector3:
	var glider := _rig.get_glider() if _rig != null else null
	if glider == null:
		return Vector3.ZERO
	return glider.global_position + Vector3.UP * MUZZLE_UP_M


func _fire(origin: Vector3, target: Node3D) -> void:
	var bullet: RifleBullet = RifleBulletScene.instantiate() as RifleBullet
	var parent := get_tree().current_scene
	if parent == null:
		parent = _rig
	parent.add_child(bullet)
	var aim := target.global_position + Vector3(0.0, 0.7, 0.0) - origin
	bullet.launch(origin, target, aim)


static func xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func collect_candidates(pills: Array, origin: Vector3, range_m: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in pills:
		var pill := node as Node3D
		if pill == null or not is_instance_valid(pill):
			continue
		if pill is SwarmPill and not (pill as SwarmPill).is_alive():
			continue
		if xz_distance(origin, pill.global_position) <= range_m:
			found.append(pill)
	return found


static func pick_target(pills: Array, origin: Vector3, range_m: float, rng: RandomNumberGenerator) -> Node3D:
	var candidates := collect_candidates(pills, origin, range_m)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]
