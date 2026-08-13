extends SceneTree

const GLIDER := "res://scenes/player/glider.tscn"


func _initialize() -> void:
	var scene: PackedScene = load(GLIDER)
	var glider: Node = scene.instantiate()
	root.add_child(glider)
	await process_frame
	await process_frame

	var skin: Node = glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	if tree == null:
		push_error("AnimationTree missing")
		quit(1)
		return
	if not tree.active:
		push_error("AnimationTree not active")
		quit(1)
		return

	var player := tree.get_node(tree.anim_player) as AnimationPlayer
	if player == null:
		push_error("AnimationPlayer path invalid: %s" % tree.anim_player)
		quit(1)
		return

	var root_playback := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if root_playback == null:
		push_error("Root playback missing")
		quit(1)
		return

	var locomotion_playback := tree.get("parameters/locomotion/playback") as AnimationNodeStateMachinePlayback
	if locomotion_playback == null:
		push_error("Locomotion playback missing")
		quit(1)
		return

	for prop in tree.get_property_list():
		if str(prop.name).contains("surf"):
			push_error("Stale surf parameter still present: %s" % prop.name)
			quit(1)
			return

	root_playback.start("grounded")
	locomotion_playback.start("forward")
	print("AnimationTree OK, clips: ", player.get_animation_list())
	quit(0)
