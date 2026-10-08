extends SceneTree

const LEAPER_SCENE := preload(
	"res://assets/3dmodels/enemies/leaper/leaper_animated_v001.glb"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := LEAPER_SCENE.instantiate()
	get_root().add_child(root)
	_print_tree(root, "")
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		print("AnimationPlayer anims:")
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			var loop := anim.loop_mode if anim != null else -1
			var length := anim.length if anim != null else -1.0
			print("  %s length=%.4f loop=%d" % [anim_name, length, loop])
	else:
		print("No AnimationPlayer found")
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null:
		print("Skeleton3D path: ", str(root.get_path_to(skel)))
		print("Skeleton3D parent: ", skel.get_parent().name if skel.get_parent() else "")
		var parent_3d := skel.get_parent() as Node3D
		if parent_3d != null:
			print("Armature scale: ", parent_3d.transform.basis.get_scale())
	var meshes := 0
	_count_meshes(root)
	root.free()
	quit(0)


func _count_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		print(
			"Mesh %s skeleton=%s skin=%s aabb=%s"
			% [node.name, mesh.skeleton, mesh.skin != null, mesh.get_aabb()]
		)
	for child in node.get_children():
		_count_meshes(child)


func _print_tree(node: Node, indent: String) -> void:
	print("%s%s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, indent + "  ")
