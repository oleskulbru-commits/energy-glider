extends SceneTree

const PLAYER_RIG := "res://scenes/player/player_rig.tscn"
const GliderAnimTreeSchemaScript = preload("res://scripts/tools/glider_anim_tree_schema.gd")


func _initialize() -> void:
	var scene: PackedScene = load(PLAYER_RIG)
	var rig: Node = scene.instantiate()
	root.add_child(rig)
	await process_frame
	await process_frame

	var skin: Node = rig.get_node("Glider/Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	if tree == null:
		push_error("AnimationTree missing on GliderSkin")
		quit(1)
		return
	if not tree.active:
		tree.active = true
	await process_frame

	var errors := GliderAnimTreeSchemaScript.validate(tree)
	for msg in errors:
		push_error(msg)
	if not errors.is_empty():
		quit(1)
		return

	var root_bt := tree.tree_root as AnimationNodeBlendTree
	var body := root_bt.get_node(&"body") as AnimationNodeStateMachine
	var boost := body.get_node(&"boost") as AnimationNodeStateMachine
	if not boost.has_transition(&"loop", &"exit"):
		push_error("Boost nested missing loop -> exit transition")
		quit(1)
		return
	if body.has_transition(&"landing", &"jump"):
		push_error("Body must not allow landing -> jump")
		quit(1)
		return

	print("verify_glider_anim_tree: OK")
	quit(0)
