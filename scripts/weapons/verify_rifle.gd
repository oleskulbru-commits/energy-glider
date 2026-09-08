extends SceneTree

const RifleBulletScript = preload("res://scripts/weapons/rifle_bullet.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")
const CombatDroneScript = preload("res://scripts/enemies/combat_drone.gd")
const MissileDroneScript = preload("res://scripts/enemies/missile_drone.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_aim_is_hitbox_center()
	if _failed:
		return
	_verify_aim_ignores_orientation()
	if _failed:
		return
	_verify_homing_commits()
	if _failed:
		return
	_verify_proximity_hit()
	if _failed:
		return
	_verify_yawed_drone_does_not_orbit()
	if _failed:
		return
	print("Rifle verification passed.")
	quit(0)


func _verify_aim_is_hitbox_center() -> void:
	var pill: SwarmPill = SwarmPillScript.new()
	root.add_child(pill)
	pill.global_position = Vector3(4.0, 1.0, -2.0)
	_attach_crawler_hitbox(pill)
	var col := pill.get_node("CollisionShape3D") as CollisionShape3D
	_fail_unless(
		RifleBulletScript.aim_point_for(pill).is_equal_approx(col.global_position),
		"Rifle should aim at the crawler collision center"
	)
	pill.free()


func _verify_aim_ignores_orientation() -> void:
	var pill: SwarmPill = SwarmPillScript.new()
	root.add_child(pill)
	pill.global_position = Vector3.ZERO
	_attach_crawler_hitbox(pill)
	pill.rotate_object_local(Vector3.RIGHT, deg_to_rad(40.0))
	var col := pill.get_node("CollisionShape3D") as CollisionShape3D
	var aim := RifleBulletScript.aim_point_for(pill)
	_fail_unless(
		aim.is_equal_approx(col.global_position),
		"Tilted crawler aim should follow the hitbox, not world up"
	)
	_fail_unless(
		not aim.is_equal_approx(pill.global_position + Vector3(0.0, SwarmPillScript.COLLISION_CENTER_Y, 0.0)),
		"Tilted crawler aim must not use a world-up offset"
	)
	pill.free()

	var drone: MissileDrone = MissileDroneScript.new()
	root.add_child(drone)
	drone.global_position = Vector3(-12.0, 8.0, 3.0)
	drone.look_at(drone.global_position + Vector3(1.0, 0.0, 1.0), Vector3.UP)
	_fail_unless(
		RifleBulletScript.aim_point_for(drone).is_equal_approx(drone.global_position),
		"Yawed drone aim should stay on the cube center"
	)
	_fail_unless(
		RifleBulletScript.hit_radius_for(drone)
			>= CombatDroneScript.CUBE_SIZE_M * 0.5 * sqrt(2.0) - 0.01,
		"Drone hit sphere should cover the cube after yaw"
	)
	drone.free()


func _verify_homing_commits() -> void:
	_fail_unless(
		RifleBulletScript.should_home(RifleBulletScript.HOMING_COMMIT_M + 0.1),
		"Rifle should ease toward the lock while still far"
	)
	_fail_unless(
		not RifleBulletScript.should_home(RifleBulletScript.HOMING_COMMIT_M),
		"Far homing should stop once the tracer reaches commit range"
	)
	_fail_unless(
		RifleBulletScript.should_snap_home(RifleBulletScript.HOMING_COMMIT_M),
		"Close-range homing should snap onto the hitbox center"
	)
	_fail_unless(
		RifleBulletScript.should_snap_home(0.4),
		"Inside commit range the tracer should fly at the center, not orbit"
	)
	_fail_unless(
		RifleBulletScript.heading_hits_sphere(
			Vector3.ZERO, Vector3(-1.0, 0.0, 0.0), Vector3(-4.0, 0.0, 0.0), 0.7
		),
		"A heading through the lock should count as on-course"
	)
	_fail_unless(
		not RifleBulletScript.heading_hits_sphere(
			Vector3(0.0, 0.0, 5.0), Vector3(-1.0, 0.0, 0.0), Vector3.ZERO, 1.2
		),
		"A parallel miss should snap onto the center instead of orbiting"
	)
	var blend := RifleBulletScript.homing_blend(1.0 / 60.0)
	_fail_unless(blend > 0.0 and blend < 0.25, "Per-frame homing blend should be gentle")


func _verify_proximity_hit() -> void:
	var pill: SwarmPill = SwarmPillScript.new()
	root.add_child(pill)
	pill.global_position = Vector3(-4.0, 0.0, 0.0)
	var bullet: RifleBullet = RifleBulletScript.new()
	root.add_child(bullet)
	var aim := RifleBulletScript.aim_point_for(pill)
	bullet.launch(aim + Vector3(0.2, 0.0, 0.0), pill, Vector3(-1.0, 0.0, 0.0), 20, 60.0)
	bullet._physics_process(1.0 / 60.0)
	_fail_unless(bool(bullet.get("_spent")), "A tracer passing the aim point should hit")
	_fail_unless(
		not pill.is_alive() or pill.get_health() < pill.get_max_health(),
		"Proximity hit should damage the lock"
	)
	bullet.free()
	pill.free()


func _verify_yawed_drone_does_not_orbit() -> void:
	var drone: MissileDrone = MissileDroneScript.new()
	root.add_child(drone)
	drone.set_physics_process(false)
	drone.global_position = Vector3(-20.0, 8.0, 0.0)
	drone.look_at(drone.global_position + Vector3(1.0, 0.0, 1.0), Vector3.UP)
	var center := drone.hit_center()
	var bullet: RifleBullet = RifleBulletScript.new()
	root.add_child(bullet)
	bullet.launch(center + Vector3(0.0, 0.0, 5.0), drone, Vector3(-1.0, 0.0, 0.0), 20, 60.0)
	var hit := false
	for _i in 90:
		if bool(bullet.get("_spent")):
			hit = true
			break
		bullet._physics_process(1.0 / 60.0)
	_fail_unless(hit, "Tracer should hit a yawed drone instead of orbiting")
	_fail_unless(
		not drone.is_alive() or drone.get_health() < drone.get_max_health(),
		"Yawed-drone hit should deal rifle damage"
	)
	bullet.free()
	drone.free()


func _attach_crawler_hitbox(pill: SwarmPill) -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = SwarmPillScript.COLLISION_RADIUS
	capsule.height = SwarmPillScript.COLLISION_HEIGHT
	col.shape = capsule
	col.position = Vector3(0.0, SwarmPillScript.COLLISION_CENTER_Y, 0.0)
	pill.add_child(col)


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
	quit(1)
