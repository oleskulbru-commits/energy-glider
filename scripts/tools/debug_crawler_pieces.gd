extends SceneTree

const FRACTURED_SCENE := preload(
	"res://assets/3dmodels/enemies/crawler/crawler_fractured_v001.glb"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var model := FRACTURED_SCENE.instantiate()
	get_root().add_child(model)
	model.scale = Vector3.ONE * SwarmPill.CRAWLER_LIVING_SCALE
	var pieces: Array[MeshInstance3D] = []
	_collect(model, pieces)
	print("piece count: ", pieces.size())
	for piece in pieces.slice(0, 3):
		var mesh: Mesh = piece.mesh
		print(
			"  ",
			piece.name,
			" mesh=",
			mesh != null,
			" aabb=",
			mesh.get_aabb() if mesh != null else "null"
		)
		if mesh != null:
			var convex := mesh.create_convex_shape(true, false)
			print("    convex=", convex != null)
	quit(0)


func _is_shard_mesh_name(name: String) -> bool:
	if name.begins_with("Crawler_Fractured_cell") or name.begins_with("Crawler_Pieces"):
		return true
	return name.begins_with("Crawler_Model_")


func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and _is_shard_mesh_name(node.name):
		out.append(node)
	for child in node.get_children():
		_collect(child, out)
