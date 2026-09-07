extends SceneTree

const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const PlayerRigScript = preload("res://scripts/player/player_rig.gd")
const HUDScene := preload("res://scenes/ui/glider_hud.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_idle_uses_body()
	_verify_aim_uses_look()
	_verify_zero_look_falls_back()
	_verify_aim_chip_border()
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
	hud.queue_free()


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
