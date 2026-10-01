extends SceneTree

const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const AutoShotgunScript = preload("res://scripts/weapons/auto_shotgun.gd")
const AutoLaserScript = preload("res://scripts/weapons/auto_laser.gd")
const AutoTeslaScript = preload("res://scripts/weapons/auto_tesla.gd")
const AutoRocketScript = preload("res://scripts/weapons/auto_rocket.gd")
const PlayerRigScript = preload("res://scripts/player/player_rig.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")
const HUDScene := preload("res://scenes/ui/glider_hud.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_idle_uses_body()
	_verify_aim_uses_look()
	_verify_zero_look_falls_back()
	_verify_aim_chip_border()
	_verify_preview_primary_locks()
	_verify_aimed_fire_matches_reticle()
	_verify_aim_lock_reticles_hud()
	print("Weapon aim verification passed.")
	quit(0)


func _verify_idle_uses_body() -> void:
	var origin := Vector3.ZERO
	var body := Vector3(-1.0, 0.0, 0.0)
	var look := Vector3(1.0, 0.0, 0.0)
	var ahead := Vector3(-10.0, 0.0, 0.0)
	var behind := Vector3(10.0, 0.0, 0.0)
	var facing := PlayerRigScript.resolve_weapon_facing_xz(body, look, false)
	_fail_unless(facing.is_equal_approx(body), "Idle aim should follow glider yaw")
	_fail_unless(
		AutoRifleScript.is_in_front(origin, facing, ahead),
		"Idle cone should include a target in front of the nose"
	)
	_fail_unless(
		not AutoRifleScript.is_in_front(origin, facing, behind),
		"Idle cone should ignore a target behind the nose"
	)


func _verify_aim_uses_look() -> void:
	var origin := Vector3.ZERO
	var body := Vector3(-1.0, 0.0, 0.0)
	var look := Vector3(1.0, 0.0, 0.0)
	var ahead := Vector3(-10.0, 0.0, 0.0)
	var behind := Vector3(10.0, 0.0, 0.0)
	var facing := PlayerRigScript.resolve_weapon_facing_xz(body, look, true)
	_fail_unless(facing.is_equal_approx(look), "Held aim should follow camera look")
	_fail_unless(
		AutoRifleScript.is_in_front(origin, facing, behind),
		"Aimed cone looking behind should include a target behind the nose"
	)
	_fail_unless(
		not AutoRifleScript.is_in_front(origin, facing, ahead),
		"Aimed cone looking behind should ignore a target in front of the nose"
	)


func _verify_zero_look_falls_back() -> void:
	var body := Vector3(-1.0, 0.0, 0.0)
	var facing := PlayerRigScript.resolve_weapon_facing_xz(body, Vector3.ZERO, true)
	_fail_unless(facing.is_equal_approx(body), "Aim with no look vector should keep body facing")


func _verify_aim_chip_border() -> void:
	var hud: GliderHUD = HUDScene.instantiate() as GliderHUD
	root.add_child(hud)
	var chip := hud.get_node_or_null("%AimChip") as PanelContainer
	_fail_unless(chip != null, "HUD should include an Aim chip")
	var panel := chip.get_theme_stylebox("panel") as StyleBoxFlat
	_fail_unless(panel != null, "Aim chip should use a StyleBoxFlat panel")
	_fail_unless(panel.border_width_left == GliderHUD.AIM_BORDER_IDLE_PX, "Idle Aim border should be 1 px")
	_fail_unless(
		panel.border_color.is_equal_approx(GliderHUD.AIM_BORDER_IDLE),
		"Idle Aim border should stay sand"
	)
	GliderHUD._apply_aim_border_to(panel, true)
	_fail_unless(panel.border_width_left == GliderHUD.AIM_BORDER_ACTIVE_PX, "Held Aim border should thicken")
	_fail_unless(
		panel.border_color.is_equal_approx(GliderHUD.AIM_BORDER_ACTIVE),
		"Held Aim border should turn green"
	)
	var template := hud.get_node_or_null("%AimReticle") as TextureRect
	_fail_unless(template != null, "HUD should keep an AimReticle texture template")
	_fail_unless(template.texture != null, "AimReticle template should use the player aim texture")
	_fail_unless(not template.visible, "AimReticle template should stay hidden")
	_fail_unless(hud.get_node_or_null("%AimReticleLayer") != null, "HUD should include AimReticleLayer")
	hud.queue_free()


func _verify_preview_primary_locks() -> void:
	var origin := Vector3(0.0, 1.0, 0.0)
	var facing := Vector3(-1.0, 0.0, 0.0)
	var near_front := _make_pill(Vector3(-20.0, 0.0, 0.0))
	var far_front := _make_pill(Vector3(-40.0, 0.0, 0.0))
	var behind := _make_pill(Vector3(20.0, 0.0, 0.0))
	var pills: Array = [near_front, far_front, behind]
	var rifle := AutoRifleScript.preview_primary_target(pills, origin, facing, 75.0)
	_fail_unless(rifle == near_front, "Rifle preview should pick the closest front candidate")
	var shotgun := AutoShotgunScript.preview_primary_target(pills, origin, facing, 40.0)
	_fail_unless(shotgun == near_front, "Shotgun preview should pick the closest front candidate")
	var laser := AutoLaserScript.preview_primary_target(pills, origin, facing, 45.0)
	_fail_unless(laser == near_front, "Laser preview should pick one primary, not bounce hops")
	var tesla := AutoTeslaScript.preview_primary_target(pills, origin, facing, 20.0)
	_fail_unless(tesla == near_front, "Tesla preview should pick one primary")
	var rocket := AutoRocketScript.preview_primary_target(pills, origin, facing, 75.0)
	_fail_unless(rocket != null and rocket != behind, "Rocket preview should stay on a front lock")
	_fail_unless(
		AutoRifleScript.preview_primary_target([behind], origin, facing, 75.0) == null,
		"Preview must not lock a behind-only candidate"
	)
	near_front.free()
	far_front.free()
	behind.free()


func _verify_aimed_fire_matches_reticle() -> void:
	var origin := Vector3(0.0, 1.0, 0.0)
	var facing := Vector3(-1.0, 0.0, 0.0)
	var near := _make_pill(Vector3(-12.0, 0.0, 2.0))
	var mid := _make_pill(Vector3(-24.0, 0.0, -6.0))
	var far := _make_pill(Vector3(-40.0, 0.0, 8.0))
	var pills: Array = [far, mid, near]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rifle_lock := AutoRifleScript.preview_primary_target(pills, origin, facing, 75.0)
	var shotgun_lock := AutoShotgunScript.preview_primary_target(pills, origin, facing, 40.0)
	var laser_lock := AutoLaserScript.preview_primary_target(pills, origin, facing, 45.0)
	var tesla_lock := AutoTeslaScript.preview_primary_target(pills, origin, facing, 20.0)
	_fail_unless(rifle_lock == near, "Reticle lock should be the closest front target")
	_fail_unless(shotgun_lock == near, "Shotgun reticle should mark the closest target")
	_fail_unless(laser_lock == near, "Laser reticle should mark the closest target")
	_fail_unless(tesla_lock == near, "Tesla reticle should mark the closest target in range")
	var saw_other := false
	for _i in 24:
		var rifle_shot := AutoRifleScript.pick_target(pills, origin, facing, 75.0, rng, true)
		var shotgun_shot := AutoShotgunScript.pick_target(pills, origin, facing, 40.0, rng, true)
		var laser_shot := AutoLaserScript.pick_unique_target(
			pills, origin, facing, 45.0, {near.get_instance_id(): true}, rng, true
		)
		var tesla_shots := AutoTeslaScript.pick_unique_targets(
			pills, origin, facing, 20.0, 1, rng, {near.get_instance_id(): true}, true
		)
		_fail_unless(rifle_shot == rifle_lock, "Aimed rifle should fire the reticle lock")
		_fail_unless(shotgun_shot == shotgun_lock, "Aimed shotgun should fire the reticle lock")
		_fail_unless(laser_shot == laser_lock, "Aimed laser should fire the reticle lock")
		_fail_unless(
			tesla_shots.size() == 1 and tesla_shots[0] == tesla_lock,
			"Aimed tesla should strike the reticle lock"
		)
		var idle := AutoRifleScript.pick_target(pills, origin, facing, 75.0, rng, false)
		if idle != null and idle != rifle_lock:
			saw_other = true
	_fail_unless(saw_other, "Idle fire should still spread across the cone")
	near.free()
	mid.free()
	far.free()


func _verify_aim_lock_reticles_hud() -> void:
	var hud: GliderHUD = HUDScene.instantiate() as GliderHUD
	root.add_child(hud)
	hud.set_aim_lock_reticles_for_test([])
	_fail_unless(hud.visible_aim_lock_reticle_count() == 0, "No aim lock reticles when not aiming")
	hud.set_aim_lock_reticles_for_test([Vector3(10.0, 2.0, 0.0), Vector3(20.0, 2.0, 5.0)])
	_fail_unless(hud.visible_aim_lock_reticle_count() == 2, "Each lock should show one world aim reticle")
	hud.set_aim_lock_reticles_for_test([])
	_fail_unless(hud.visible_aim_lock_reticle_count() == 0, "Clearing locks should hide aim reticles")
	hud.queue_free()


func _make_pill(pos: Vector3) -> SwarmPill:
	var pill: SwarmPill = SwarmPillScript.new()
	root.add_child(pill)
	pill.global_position = pos
	return pill


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
