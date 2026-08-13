extends SceneTree

const GLB := "res://assets/3dmodels/player_models/The_Glider_Animated_Skin.glb"


func _initialize() -> void:
	var scene: PackedScene = load(GLB)
	var root: Node = scene.instantiate()
	var player := _find_animation_player(root)
	if player == null:
		push_error("No AnimationPlayer found")
		quit(1)
		return
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			print("%s/%s" % [lib_name, anim_name])
	quit(0)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
