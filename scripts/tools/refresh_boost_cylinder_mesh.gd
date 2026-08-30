extends SceneTree

const BOOST_CYLINDER_MESH_PATH := "res://resources/meshes/vfx/boost_cylinder.res"
const GliderBoostVfxScript = preload("res://scripts/player/glider_boost_vfx.gd")
const GliderVfxFlipbookScript = preload("res://scripts/player/glider_vfx_flipbook.gd")


func _initialize() -> void:
	var mesh := GliderVfxFlipbookScript.load_fbx_mesh(
		GliderBoostVfxScript.CYLINDER_FBX_PATH,
		GliderBoostVfxScript.CYLINDER_NODE_NAME
	)
	if mesh == null:
		push_error("Failed to load boost cylinder mesh from FBX")
		quit(1)
		return

	var old_aabb := AABB()
	if FileAccess.file_exists(BOOST_CYLINDER_MESH_PATH):
		var existing := load(BOOST_CYLINDER_MESH_PATH) as Mesh
		if existing != null:
			old_aabb = existing.get_aabb()

	var err := ResourceSaver.save(mesh, BOOST_CYLINDER_MESH_PATH)
	if err != OK:
		push_error("Failed to save boost cylinder mesh: %s" % err)
		quit(1)
		return

	print(
		"Boost cylinder mesh updated from %s (%s)"
		% [GliderBoostVfxScript.CYLINDER_FBX_PATH, GliderBoostVfxScript.CYLINDER_NODE_NAME]
	)
	print("  saved: ", BOOST_CYLINDER_MESH_PATH)
	print("  old aabb: ", old_aabb)
	print("  new aabb: ", mesh.get_aabb())
	quit(0)
