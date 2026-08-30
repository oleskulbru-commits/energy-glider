extends SceneTree

const SKIN_SCENE := "res://scenes/player/the_glider_skin.tscn"
const ANIM_LIB_PATH := "res://resources/anims/glider_skin_anim_library.res"
const MESH_DIR := "res://resources/meshes/glider_skin"
const VFX_MESH_DIR := "res://resources/meshes/vfx"

const VFX_MESH_PATHS := {
	"Model/GliderRoot/GliderBoard/ThrusterSocket/BoostVfxPivot/BoostVfx/CylinderMesh2":
		"res://resources/meshes/vfx/boost_cylinder.res",
	"Model/GliderRoot/GliderBoard/ThrusterSocket/ThrusterVfxPivot/ThrusterVfx/OrbMesh2":
		"res://resources/meshes/vfx/thruster_orb.res",
	"Model/GliderRoot/GliderBoard/ThrusterSocket/ThrusterVfxPivot/ThrusterVfx/CylinderMesh2":
		"res://resources/meshes/vfx/thruster_cylinder.res",
}

var _saved_resources: Dictionary = {}


func _initialize() -> void:
	var before_size := _file_size(SKIN_SCENE)

	var packed := load(SKIN_SCENE) as PackedScene
	if packed == null:
		push_error("Failed to load skin scene")
		quit(1)
		return

	var skin: Node = packed.instantiate()
	_ensure_directories()

	var anim_count := _externalize_animations(skin)
	var mesh_count := _externalize_meshes(skin)

	var packed_scene := PackedScene.new()
	var pack_err := packed_scene.pack(skin)
	skin.free()
	if pack_err != OK:
		push_error("Failed to pack skin scene: %s" % pack_err)
		quit(1)
		return

	var save_err := ResourceSaver.save(packed_scene, SKIN_SCENE)
	if save_err != OK:
		push_error("Failed to save skin scene: %s" % save_err)
		quit(1)
		return

	var after_size := _file_size(SKIN_SCENE)
	print("Externalized %d animation library(ies), %d mesh/skin resource(s)" % [anim_count, mesh_count])
	print("Scene size: %d bytes -> %d bytes (%.1f%% reduction)" % [
		before_size,
		after_size,
		(1.0 - float(after_size) / float(before_size)) * 100.0 if before_size > 0 else 0.0,
	])
	print("Saved ", SKIN_SCENE)
	quit(0)


func _ensure_directories() -> void:
	for dir_path in [MESH_DIR, VFX_MESH_DIR, "res://resources/anims"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))


func _externalize_animations(skin: Node) -> int:
	var player := skin.get_node_or_null("Model/AnimationPlayer") as AnimationPlayer
	if player == null:
		push_error("AnimationPlayer not found")
		return 0

	var count := 0
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		if lib == null:
			continue
		var external := lib.duplicate(true) as AnimationLibrary
		var err := ResourceSaver.save(external, ANIM_LIB_PATH)
		if err != OK:
			push_error("Failed to save animation library: %s" % err)
			continue
		player.remove_animation_library(lib_name)
		player.add_animation_library(lib_name, load(ANIM_LIB_PATH) as AnimationLibrary)
		count += 1
		print("  animations -> ", ANIM_LIB_PATH)
	return count


func _externalize_meshes(skin: Node) -> int:
	var model := skin.get_node_or_null("Model")
	if model == null:
		push_error("Model node not found")
		return 0

	var count := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var node_path := str(skin.get_path_to(mesh_instance))

		if mesh_instance.mesh != null:
			var mesh_path := _mesh_path_for(node_path, mesh_instance.name)
			var external_mesh := _save_resource(mesh_instance.mesh, mesh_path)
			if external_mesh != null:
				mesh_instance.mesh = external_mesh
				count += 1
				print("  mesh %s -> %s" % [node_path, mesh_path])

		if mesh_instance.skin != null:
			var skin_path := "%s/%s_skin.res" % [MESH_DIR, _sanitize_name(mesh_instance.name)]
			var external_skin := _save_resource(mesh_instance.skin, skin_path)
			if external_skin != null:
				mesh_instance.skin = external_skin
				count += 1
				print("  skin %s -> %s" % [node_path, skin_path])

		var shadow_mesh: Mesh = mesh_instance.get("shadow_mesh")
		if shadow_mesh != null:
			var shadow_path := "%s/%s_shadow.res" % [MESH_DIR, _sanitize_name(mesh_instance.name)]
			var external_shadow := _save_resource(shadow_mesh, shadow_path)
			if external_shadow != null:
				mesh_instance.set("shadow_mesh", external_shadow)
				count += 1
				print("  shadow_mesh %s -> %s" % [node_path, shadow_path])

	return count


func _mesh_path_for(node_path: String, node_name: String) -> String:
	if VFX_MESH_PATHS.has(node_path):
		return VFX_MESH_PATHS[node_path]
	return "%s/%s.res" % [MESH_DIR, _sanitize_name(node_name)]


func _save_resource(resource: Resource, path: String) -> Resource:
	if resource.resource_path != "" and resource.resource_path == path:
		return resource

	var resource_id := resource.get_instance_id()
	if _saved_resources.has(resource_id):
		return load(_saved_resources[resource_id]) as Resource

	var duplicate := resource.duplicate(true) as Resource
	var err := ResourceSaver.save(duplicate, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])
		return null

	_saved_resources[resource_id] = path
	return load(path) as Resource


func _sanitize_name(name: String) -> String:
	var sanitized := name.to_lower()
	sanitized = sanitized.replace(" ", "_")
	return sanitized


func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_file_as_bytes(path).size()
