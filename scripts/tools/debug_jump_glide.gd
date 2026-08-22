extends SceneTree

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const TerrainManagerScript = preload("res://scripts/terrain/terrain_manager.gd")
const GliderScene = preload("res://scenes/player/glider.tscn")


func _initialize() -> void:
	var terrain := TerrainManagerScript.new()
	terrain.name = "DebugTerrain"
	root.add_child(terrain)
	await process_frame

	var glider: GliderPlayerScript = GliderScene.instantiate()
	root.add_child(glider)
	glider.terrain_manager = terrain
	await process_frame

	var ground_y := terrain.sample_height(0.0, 0.0)
	glider.global_position = Vector3(0.0, ground_y + 1.12, 0.0)
	glider.velocity = Vector3.ZERO
	for _i in 60:
		await process_frame

	var skin := glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree")
	var root_playback: AnimationNodeStateMachinePlayback = tree.get("parameters/body/playback")
	var anim_player: AnimationPlayer = tree.get_node(tree.anim_player)

	glider.velocity = Vector3(0.0, 0.0, 14.0)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await process_frame
	Input.action_release("jump")
	await process_frame

	print("after jump: gliding=", glider.is_gliding(), " landing=", glider.is_landing())
	ground_y = terrain.sample_height(glider.global_position.x, glider.global_position.z)
	glider.global_position.y = ground_y + 12.0
	glider.velocity = Vector3(0.0, -0.5, 14.0)
	glider.set("_state", GliderPlayerScript.State.GLIDING)
	await process_frame

	for i in 120:
		await process_frame
		if not glider.is_gliding():
			print("frame ", i, " landed root=", root_playback.get_current_node())
			break
		var root_node := root_playback.get_current_node()
		var jump_len := root_playback.get_current_length()
		var jump_pos := root_playback.get_current_play_position()
		var ap_anim := anim_player.current_animation
		var ap_pos := anim_player.current_animation_position if ap_anim != "" else -1.0
		var ap_len := anim_player.get_animation(ap_anim).length if ap_anim != "" and anim_player.has_animation(ap_anim) else -1.0
		if i % 10 == 0 or root_node != &"jump":
			print(
				"f", i,
				" root=", root_node,
				" sm_pos=", snappedf(jump_pos, 0.001),
				" sm_len=", snappedf(jump_len, 0.001),
				" ap=", ap_anim,
				" ap_pos=", snappedf(ap_pos, 0.001),
				" ap_len=", snappedf(ap_len, 0.001)
			)
		if root_node == &"glide":
			print("SAW GLIDE at frame ", i)
			break

	quit(0)
