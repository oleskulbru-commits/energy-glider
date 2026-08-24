extends SceneTree

const CRAWLER_SCENE := preload(
	"res://assets/3dmodels/enemies/crawler/crawler_animated_v001.glb"
)


func _init() -> void:
	var root: Node = CRAWLER_SCENE.instantiate()
	var skel: Skeleton3D = root.get_node("Crawler_Skeleton/Skeleton3D") as Skeleton3D
	for i in skel.get_bone_count():
		var parent := skel.get_bone_parent(i)
		var parent_name := "" if parent < 0 else skel.get_bone_name(parent)
		print("%s (parent: %s)" % [skel.get_bone_name(i), parent_name])
	quit(0)
