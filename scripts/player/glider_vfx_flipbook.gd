class_name GliderVfxFlipbook
extends RefCounted

const GliderVfxFadeEnvelopeScript = preload("res://scripts/player/glider_vfx_fade.gd")


static func apply_omni_fill(
	light: OmniLight3D,
	presentation: float,
	base_energy: float,
	threshold: float = GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
) -> void:
	if light == null:
		return
	var show := presentation > threshold
	light.visible = show
	if not show:
		return
	light.light_energy = base_energy * presentation


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
	intensity: float
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

	apply_flipbook_presentation(mat, texture, intensity)
	return mat


static func apply_flipbook_presentation(
	mat: StandardMaterial3D,
	texture: Texture2D,
	intensity: float,
	use_texture: bool = true
) -> void:
	var strength := clampf(intensity, 0.0, 1.0)
	var base_albedo := mat.albedo_color
	mat.albedo_color = Color(
		base_albedo.r,
		base_albedo.g,
		base_albedo.b,
		base_albedo.a * strength
	)
	if use_texture and texture != null:
		mat.albedo_texture = texture
		if mat.emission_enabled:
			mat.emission_texture = texture
	else:
		mat.albedo_texture = null
		if mat.emission_enabled:
			mat.emission_texture = null

	if not mat.emission_enabled:
		return

	var base_energy := mat.emission_energy_multiplier
	if base_energy <= 0.0:
		return
	mat.emission_energy_multiplier = base_energy * strength


static func apply_solid_emission_presentation(
	mat: StandardMaterial3D,
	intensity: float
) -> void:
	var strength := clampf(intensity, 0.0, 1.0)
	mat.albedo_texture = null
	mat.emission_texture = null

	var tint := mat.emission
	if not mat.emission_enabled or tint.r + tint.g + tint.b < 0.01:
		tint = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, 1.0)
	mat.emission_enabled = true
	mat.emission = tint
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 1.0)
	finalize_opaque_orb(mat)

	var base_energy := mat.emission_energy_multiplier
	if base_energy <= 0.0:
		base_energy = 4.0
	mat.emission_energy_multiplier = base_energy * strength


static func apply_emission_presentation(
	mat: StandardMaterial3D,
	base_energy: float,
	intensity: float
) -> void:
	var strength := clampf(intensity, 0.0, 1.0)
	var energy := base_energy
	if energy <= 0.0:
		energy = mat.emission_energy_multiplier
	if energy <= 0.0:
		energy = 1.0
	mat.emission_energy_multiplier = energy * strength


static func finalize_opaque_orb(mat: StandardMaterial3D) -> void:
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var c := mat.albedo_color
	mat.albedo_color = Color(c.r, c.g, c.b, 1.0)


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
