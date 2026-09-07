extends SceneTree

const RifleBulletScript = preload("res://scripts/weapons/rifle_bullet.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_aim_is_inside_hitbox()
	if _failed:
		return
	_verify_homing_commits()
	if _failed:
		return
	_verify_proximity_hit()
	if _failed:
		return
	print("Rifle verification passed.")
	quit(0)


func _verify_aim_is_inside_hitbox() -> void:
	_fail_unless(
		is_equal_approx(RifleBulletScript.AIM_UP_M, SwarmPillScript.COLLISION_CENTER_Y),
		"Rifle should aim at the crawler collision center, not above the capsule"
	)
	_fail_unless(
		RifleBulletScript.AIM_UP_M < SwarmPillScript.COLLISION_CENTER_Y
			+ SwarmPillScript.COLLISION_HEIGHT * 0.5,
		"Rifle aim point should stay inside the crawler capsule"
	)
	var aim := RifleBulletScript.aim_point_for(Vector3.ZERO)
	_fail_unless(
		aim.is_equal_approx(Vector3(0.0, RifleBulletScript.AIM_UP_M, 0.0)),
		"Aim point should sit AIM_UP_M above the enemy origin"
	)


func _verify_homing_commits() -> void:
	_fail_unless(
		RifleBulletScript.should_home(RifleBulletScript.HOMING_COMMIT_M + 0.1),
		"Rifle should home while still far from the lock"
	)
	_fail_unless(
		not RifleBulletScript.should_home(RifleBulletScript.HOMING_COMMIT_M),
		"Rifle should fly straight once it reaches commit range"
	)
	_fail_unless(
		not RifleBulletScript.should_home(0.4),
		"Close-range homing should stay off so the tracer cannot orbit"
	)
	var blend := RifleBulletScript.homing_blend(1.0 / 60.0)
	_fail_unless(blend > 0.0 and blend < 0.25, "Per-frame homing blend should be gentle")


func _verify_proximity_hit() -> void:
	var pill: SwarmPill = SwarmPillScript.new()
	root.add_child(pill)
	pill.global_position = Vector3(-4.0, 0.0, 0.0)
	var bullet: RifleBullet = RifleBulletScript.new()
	root.add_child(bullet)
	var aim := RifleBulletScript.aim_point_for(pill.global_position)
	bullet.launch(aim + Vector3(0.2, 0.0, 0.0), pill, Vector3(-1.0, 0.0, 0.0), 20, 60.0)
	bullet._physics_process(1.0 / 60.0)
	_fail_unless(bool(bullet.get("_spent")), "A tracer passing the aim point should hit")
	_fail_unless(
		not pill.is_alive() or pill.get_health() < pill.get_max_health(),
		"Proximity hit should damage the lock"
	)
	bullet.free()
	pill.free()


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
	quit(1)
