extends SceneTree

const CRAWLER_SCENE := preload(
	"res://assets/3dmodels/enemies/crawler/crawler_animated_v001.glb"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := CRAWLER_SCENE.instantiate()
	get_root().add_child(root)
	_print_tree(root, "")
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		print("AnimationPlayer anims: ", player.get_animation_list())
	else:
		print("No AnimationPlayer found")
	var mesh := root.find_child("Crawler_Model", true, false) as MeshInstance3D
	if mesh != null:
		print("Crawler_Model local AABB: ", mesh.get_aabb())
		print("Crawler_Model global AABB: ", mesh.global_transform * mesh.get_aabb())
		print("Crawler_Model global scale: ", mesh.global_transform.basis.get_scale())
	var skel_root := root.get_node_or_null("Crawler_Skeleton") as Node3D
	if skel_root != null:
		print("Crawler_Skeleton transform: ", skel_root.transform)
	root.free()
	quit(0)


func _print_tree(node: Node, indent: String) -> void:
	print("%s%s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, indent + "  ")
