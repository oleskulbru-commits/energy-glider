extends SceneTree

const SKIN_SCENE := "res://scenes/player/the_glider_skin.tscn"
const GliderAnimClipsScript = preload("res://scripts/player/glider_anim_clips.gd")


func _initialize() -> void:
	var scene: PackedScene = load(SKIN_SCENE)
	if scene == null:
		push_error("Failed to load skin scene: %s" % SKIN_SCENE)
		quit(1)
		return

	var skin: Node = scene.instantiate()
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	if tree == null:
		push_error("AnimationTree missing on GliderSkin")
		skin.free()
		quit(1)
		return

	var player := skin.get_node("Model/AnimationPlayer") as AnimationPlayer
	if player == null:
		push_error("AnimationPlayer missing on GliderSkin Model")
		skin.free()
		quit(1)
		return

	var glb_clips: Array[String] = []
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			glb_clips.append(anim_name)
	skin.free()

	var missing: Array[String] = []
	for clip_name in GliderAnimClipsScript.ALL_WIRED:
		if clip_name not in glb_clips:
			missing.append(clip_name)

	if not missing.is_empty():
		push_error("Missing wired GLB clips: %s" % ", ".join(missing))
		quit(1)
		return

	var orphans: Array[String] = []
	for clip_name in glb_clips:
		if not GliderAnimClipsScript.is_wired(clip_name):
			orphans.append(clip_name)

	var wired_count := GliderAnimClipsScript.ALL_WIRED.size()
	if orphans.is_empty():
		print("%d/%d wired OK, 0 orphan(s)" % [wired_count, wired_count])
	else:
		var orphan_text := ", ".join(orphans)
		push_warning("Unwired GLB clips: %s" % orphan_text)
		print("%d/%d wired OK, %d orphan(s): %s" % [wired_count, wired_count, orphans.size(), orphan_text])

	quit(0)
