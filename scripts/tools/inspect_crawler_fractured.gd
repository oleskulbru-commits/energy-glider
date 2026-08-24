extends SceneTree

const FRACTURED_SCENE := preload(
	"res://assets/3dmodels/enemies/crawler/crawler_fractured_v001.glb"
)
const ANIMATED_SCENE := preload(
	"res://assets/3dmodels/enemies/crawler/crawler_animated_v001.glb"
)
const LIVING_SCALE := SwarmPill.CRAWLER_LIVING_SCALE
const FRACTURED_BURST_MULT := SwarmPill.CRAWLER_FRACTURED_BURST_MULT


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var armature := CrawlerScaleUtil.import_armature_scale()
	var animated_scale := CrawlerScaleUtil.animated_model_scale(LIVING_SCALE)
	print("Detected armature scale: ", armature)
	print("Animated model scale: ", animated_scale)
	print("Living scale (CRAWLER_LIVING_SCALE): ", LIVING_SCALE)
	print("Fractured burst multiplier: ", FRACTURED_BURST_MULT)

	var fractured := FRACTURED_SCENE.instantiate()
	get_root().add_child(fractured)
	fractured.scale = Vector3.ONE * LIVING_SCALE * FRACTURED_BURST_MULT
	print("=== Fractured GLB at living scale x burst mult ===")
	var frac_meshes: Array[MeshInstance3D] = []
	_collect_meshes(fractured, frac_meshes)
	if not frac_meshes.is_empty():
		print("Combined global AABB: ", _combined_global_aabb(frac_meshes))
	fractured.free()

	var animated := ANIMATED_SCENE.instantiate()
	get_root().add_child(animated)
	animated.scale = Vector3.ONE * animated_scale
	print("=== Animated GLB at animated_model_scale ===")
	var anim_meshes: Array[MeshInstance3D] = []
	_collect_meshes(animated, anim_meshes)
	if not anim_meshes.is_empty():
		print("Combined global AABB: ", _combined_global_aabb(anim_meshes))
	animated.free()
	quit(0)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)


func _combined_global_aabb(meshes: Array[MeshInstance3D]) -> AABB:
	var aabb := meshes[0].global_transform * meshes[0].get_aabb()
	for mesh in meshes.slice(1):
		aabb = aabb.merge(mesh.global_transform * mesh.get_aabb())
	return aabb
