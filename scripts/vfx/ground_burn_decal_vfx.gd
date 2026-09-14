class_name GroundBurnDecalVfx
extends Node3D

## Terrain-conforming scorch mesh spawned for near-ground explosions.

const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const TerrainQueryScript := preload("res://scripts/terrain/terrain_query.gd")
const BurnShader := preload("res://assets/vfx/shaders/ground_burn_decal.gdshader")
const DefaultAlbedoPath := "res://assets/vfx/effect_textures/decals/burnt_ground_albedo.png"
const GROUND_LIFT_M := 0.03
const GRID_SEGMENTS := 16

var _mesh: MeshInstance3D
var _material: ShaderMaterial


static func spawn_from_preset(
	tree: SceneTree,
	world_pos: Vector3,
	preset: AerialExplosionPreset,
	scale_mult: float = 1.0,
	terrain: TerrainManager = null
) -> GroundBurnDecalVfx:
	if tree == null or preset == null:
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null
	var fx: GroundBurnDecalVfx = load("res://scripts/vfx/ground_burn_decal_vfx.gd").new()
	fx.name = "GroundBurnDecal"
	parent.add_child(fx)
	fx.configure(world_pos, preset, scale_mult, terrain, tree)
	return fx


func configure(
	world_pos: Vector3,
	preset: AerialExplosionPreset,
	scale_mult: float,
	terrain: TerrainManager,
	tree: SceneTree
) -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "GroundBurnMesh"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var albedo := preset.ground_burn_albedo
	if albedo == null:
		albedo = load(DefaultAlbedoPath) as Texture2D
	_material = ShaderMaterial.new()
	_material.shader = BurnShader
	_material.set_shader_parameter("albedo_tex", albedo)
	_material.set_shader_parameter("alpha_scale", preset.ground_burn_opacity)
	_material.set_shader_parameter(
		"color_tint",
		Vector3(preset.ground_burn_tint.r, preset.ground_burn_tint.g, preset.ground_burn_tint.b)
	)
	_mesh.material_override = _material
	add_child(_mesh)

	var diameter := preset.world_scale * maxf(scale_mult, 0.01) * preset.ground_burn_size_mult
	var space := _space_from_tree(tree)
	var surface := TerrainQueryScript.sample_surface(
		terrain,
		space,
		world_pos.x,
		world_pos.z,
		world_pos.y + 2.0
	)
	var conforming := not surface.is_empty() and terrain != null
	_place_on_surface(surface, world_pos, conforming)
	if conforming:
		_mesh.mesh = _build_conforming_mesh(
			surface,
			world_pos,
			diameter,
			terrain,
			space
		)
	else:
		_mesh.mesh = _build_flat_quad()
		_mesh.scale = Vector3(diameter, diameter, 1.0)
	_begin_lifetime(preset.ground_burn_lifetime_sec, preset.ground_burn_fade_sec)


func _space_from_tree(tree: SceneTree) -> PhysicsDirectSpaceState3D:
	if tree == null or tree.root == null:
		return null
	var world := tree.root.get_world_3d()
	if world == null:
		return null
	return world.direct_space_state


func _place_on_surface(surface: Dictionary, world_pos: Vector3, conforming: bool) -> void:
	if surface.is_empty():
		global_position = Vector3(world_pos.x, world_pos.y + GROUND_LIFT_M, world_pos.z)
		global_basis = Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
		return
	var normal: Vector3 = surface.normal
	var center: Vector3 = surface.position
	if conforming:
		global_position = center
		global_basis = TerrainQueryScript.basis_from_up(normal)
	else:
		global_position = center + normal * GROUND_LIFT_M
		global_basis = TerrainQueryScript.basis_from_up(normal) * Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))


func _build_conforming_mesh(
	surface: Dictionary,
	world_pos: Vector3,
	diameter: float,
	terrain: TerrainManager,
	space: PhysicsDirectSpaceState3D
) -> ArrayMesh:
	var center: Vector3 = surface.position
	var basis := TerrainQueryScript.basis_from_up(surface.normal)
	var segments := GRID_SEGMENTS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in segments - 1:
		for i in segments - 1:
			_add_conforming_quad(
				st,
				center,
				basis,
				diameter,
				terrain,
				space,
				world_pos.y + 2.0,
				i,
				j,
				segments
			)
	st.generate_normals()
	return st.commit()


func _add_conforming_quad(
	st: SurfaceTool,
	center: Vector3,
	basis: Basis,
	diameter: float,
	terrain: TerrainManager,
	space: PhysicsDirectSpaceState3D,
	height_hint: float,
	i: int,
	j: int,
	segments: int
) -> void:
	var corners := [
		Vector2i(i, j),
		Vector2i(i + 1, j),
		Vector2i(i + 1, j + 1),
		Vector2i(i, j + 1),
	]
	var tri_indices := [0, 1, 2, 0, 2, 3]
	for idx in tri_indices:
		var cell: Vector2i = corners[idx]
		var u := float(cell.x) / float(segments - 1) - 0.5
		var v := float(cell.y) / float(segments - 1) - 0.5
		var offset := basis.x * (u * diameter) + basis.z * (v * diameter)
		var sample_x := center.x + offset.x
		var sample_z := center.z + offset.z
		var ground_y := TerrainQueryScript.sample_height(
			terrain,
			space,
			sample_x,
			sample_z,
			height_hint
		)
		if is_nan(ground_y):
			ground_y = center.y
		var ground_point := Vector3(sample_x, ground_y, sample_z)
		var world_vertex := ground_point + basis.y * GROUND_LIFT_M
		var local_vertex := global_transform.affine_inverse() * world_vertex
		var uv := Vector2(float(cell.x) / float(segments - 1), float(cell.y) / float(segments - 1))
		st.set_uv(uv)
		st.add_vertex(local_vertex)


func _build_flat_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return quad


func _begin_lifetime(lifetime_sec: float, fade_sec: float) -> void:
	var tree := get_tree()
	if tree == null or _material == null:
		return
	var hold_sec := maxf(lifetime_sec - fade_sec, 0.0)
	await tree.create_timer(hold_sec).timeout
	if not is_instance_valid(self) or _material == null:
		return
	var start_alpha: float = _material.get_shader_parameter("alpha_scale")
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			if is_instance_valid(_material):
				_material.set_shader_parameter("alpha_scale", value),
		start_alpha,
		0.0,
		maxf(fade_sec, 0.01)
	)
	await tween.finished
	if is_instance_valid(self):
		queue_free()
