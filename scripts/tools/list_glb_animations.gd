extends SceneTree

const SKIN_SCENE := "res://scenes/player/the_glider_skin.tscn"


func _initialize() -> void:
	var scene: PackedScene = load(SKIN_SCENE)
	var skin: Node = scene.instantiate()
	var player := skin.get_node("Model/AnimationPlayer") as AnimationPlayer
	if player == null:
		push_error("No AnimationPlayer found on GliderSkin")
		skin.free()
		quit(1)
		return
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			print("%s/%s" % [lib_name, anim_name])
	skin.free()
	quit(0)
