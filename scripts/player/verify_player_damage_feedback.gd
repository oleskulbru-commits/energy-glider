extends SceneTree

const PlayerDamageFeedbackScript := preload("res://scripts/player/player_damage_feedback.gd")
const PlayerHealthScript := preload("res://scripts/player/player_health.gd")
const GliderPlayerScript := preload("res://scripts/player/glider_player.gd")
const GliderAnimControllerScript := preload("res://scripts/player/glider_anim_controller.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig_scene := FileAccess.get_file_as_string("res://scenes/player/player_rig.tscn")
	_fail_unless(
		rig_scene.find("PlayerDamageFeedback") != -1,
		"PlayerRig should include PlayerDamageFeedback"
	)
	var blast_source := FileAccess.get_file_as_string("res://scripts/enemies/drone_laser_blast.gd")
	_fail_unless(
		blast_source.find("_trigger_hit_hue") == -1,
		"Laser blast should rely on PlayerDamageFeedback instead of direct HUD hue"
	)
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/glider_hud.gd")
	_fail_unless(
		hud_source.find("play_damage_flash") != -1,
		"GliderHUD should expose play_damage_flash for damage feedback"
	)
	var anim_source := FileAccess.get_file_as_string("res://scripts/player/glider_anim_controller.gd")
	_fail_unless(
		anim_source.find("force_landing_reaction") != -1,
		"GliderAnimController should force landing on heavy hits"
	)
	_fail_unless(
		is_equal_approx(PlayerDamageFeedbackScript.shake_strength_for(35), 0.85),
		"Heavy hits should use explosion-scale camera shake"
	)
	_fail_unless(
		PlayerDamageFeedbackScript.shake_strength_for(2) < PlayerDamageFeedbackScript.shake_strength_for(35),
		"Light hits should shake less than heavy hits"
	)

	var root_node := Node.new()
	root.add_child(root_node)
	var health := PlayerHealthScript.new()
	health.name = "PlayerHealth"
	var feedback := PlayerDamageFeedbackScript.new()
	feedback.health_path = NodePath("../PlayerHealth")
	root_node.add_child(health)
	root_node.add_child(feedback)
	await process_frame
	_fail_unless(_is_connected_to_feedback(health, feedback), "PlayerDamageFeedback should listen to damaged")

	var glider := GliderPlayerScript.new()
	root_node.add_child(glider)
	glider.set("_state", GliderPlayerScript.State.GROUNDED)
	glider.play_hit_reaction()
	_fail_unless(glider.is_landing(), "Heavy hit reaction should start landing stabilize timer")

	feedback.queue_free()
	health.queue_free()
	glider.queue_free()
	root_node.queue_free()
	print("Player damage feedback verification passed.")
	quit(0)


func _is_connected_to_feedback(health: PlayerHealth, feedback: Node) -> bool:
	for conn: Dictionary in health.damaged.get_connections():
		var callable: Callable = conn["callable"]
		if callable.get_object() == feedback:
			return true
	return false


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
