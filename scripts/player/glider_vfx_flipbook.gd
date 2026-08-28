class_name GliderVfxFlipbook
extends RefCounted


static func load_texture_sequence(
	dir: String,
	prefix: String,
	count: int,
	frame_offset: int = 0
) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for i in count:
		var frame_number := i + frame_offset
		var path := "%s%s%04d.png" % [dir, prefix, frame_number]
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("GliderVfxFlipbook: missing texture %s" % path)
			return textures
		textures.append(texture)
	return textures


static func resolve_material(
	template: StandardMaterial3D,
	texture: Texture2D,
	intensity: float,
	emission_tint: Color = Color.WHITE
) -> StandardMaterial3D:
	var mat: StandardMaterial3D
	if template != null:
		mat = template.duplicate() as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	mat.albedo_color = Color(1.0, 1.0, 1.0, clampf(intensity, 0.0, 1.0))
	if texture != null:
		mat.albedo_texture = texture
	apply_flipbook_emission(mat, texture, intensity, emission_tint)
	return mat


static func apply_flipbook_emission(
	mat: StandardMaterial3D,
	texture: Texture2D,
	intensity: float,
	emission_tint: Color = Color.WHITE
) -> void:
	mat.emission_enabled = true
	mat.emission = emission_tint
	if texture != null:
		mat.emission_texture = texture
	var base_energy := mat.emission_energy_multiplier
	if base_energy <= 0.0:
		base_energy = 4.0
	mat.emission_energy_multiplier = base_energy * clampf(intensity, 0.0, 1.0)


static func resolve_mesh_resource(
	mesh_instance: MeshInstance3D,
	fbx_path: String,
	node_name: String
) -> Mesh:
	if mesh_instance != null and mesh_instance.mesh != null:
		return mesh_instance.mesh
	return load_fbx_mesh(fbx_path, node_name)


static func load_fbx_mesh(path: String, node_name: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var mesh_inst := _find_mesh_by_name(inst, node_name)
	var mesh: Mesh = null
	if mesh_inst != null:
		mesh = mesh_inst.mesh
	inst.free()
	return mesh


static func _find_mesh_by_name(node: Node, node_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == node_name:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_by_name(child, node_name)
		if found != null:
			return found
	return null
