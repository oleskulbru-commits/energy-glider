extends Node3D

## Ground-projected laser telegraph: conforming flipbook mesh under the player, deck-forward aligned.

const GliderPlayerScript := preload("res://scripts/player/glider_player.gd")
const TerrainQueryScript := preload("res://scripts/terrain/terrain_query.gd")
const TelegraphScript := preload("res://scripts/enemies/laser_drone_telegraph.gd")
const VfxFlipbookScript := preload("res://scripts/vfx/vfx_flipbook.gd")
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const ReticleShader := preload("res://assets/vfx/shaders/laser_ground_reticle.gdshader")

const TEXTURE_DIR := "res://assets/vfx/effect_textures/reticles/"
const FRAME_PREFIX := "reticle_1_frame_"
const FRAME_COUNT := 60
const FRAME_OFFSET := 0

const GROUND_LIFT_M := 0.06
const QUAD_SIZE_M := 8.4
const GRID_SEGMENTS := 14
const NORMAL_SMOOTH := 0.18
const FORWARD_SMOOTH := 0.22
const COLOR_TINT := Vector3(1.2, 0.06, 0.015)
const LIGHT_COLOR := Color(1.2, 0.06, 0.015, 1.0)
const GLOW_STRENGTH := 3.75
const ALPHA_SCALE := 0.92
const LIGHT_RANGE_M := 7.5
const LIGHT_ENERGY_MIN := 1.2
const LIGHT_ENERGY_MAX := 4.5
const BLINK_LIGHT_DIM := 0.2

static var _frames: Array[Texture2D] = []
static var _frames_loaded := false

var _target: Node3D
var _terrain: TerrainManager
var _elapsed := 0.0
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _light: OmniLight3D
var _smoothed_normal := Vector3.UP
var _smoothed_forward := Vector3.FORWARD
var _orientation_initialized := false


static func spawn(
	tree: SceneTree,
	target: Node3D,
	terrain: TerrainManager = null
) -> Node3D:
	var reticle: Node3D = load("res://scripts/enemies/laser_ground_reticle.gd").new()
	if tree != null:
		var parent := SceneUtilScript.world_parent(tree)
		if parent == null:
			parent = tree.root
		if parent != null:
			parent.add_child(reticle)
	reticle.configure(target, terrain)
	return reticle


func configure(target: Node3D, terrain: TerrainManager = null) -> void:
	_target = target
	_terrain = terrain
	_elapsed = 0.0
	_orientation_initialized = false
	_ensure_visual()
	_align_to_target()
	_sync_material()


func update_telegraph(elapsed: float) -> void:
	_elapsed = maxf(elapsed, 0.0)
	if _target == null or not is_instance_valid(_target):
		visible = false
		return
	visible = true
	_align_to_target()
	_sync_material()


func _align_to_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_align_to_ground(_target.global_position)


func _space_state() -> PhysicsDirectSpaceState3D:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	var world := tree.root.get_world_3d()
	if world == null:
		return null
	return world.direct_space_state


func _surface_at(world_pos: Vector3) -> Dictionary:
	var space := _space_state()
	var hit := TerrainQueryScript.raycast_ground(
		space,
		world_pos.x,
		world_pos.z,
		world_pos.y + 2.0
	)
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		if normal.length_squared() < 0.0001:
			normal = Vector3.UP
		else:
			normal = normal.normalized()
		return {"position": hit.position, "normal": normal}
	return TerrainQueryScript.sample_surface(
		_terrain,
		space,
		world_pos.x,
		world_pos.z,
		world_pos.y + 2.0
	)


func _deck_forward_raw() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		return Vector3.FORWARD
	if _target is GliderPlayerScript:
		return (_target as GliderPlayerScript).get_deck_world_basis().z
	if _target.has_method("get_deck_world_basis"):
		var deck_basis: Basis = _target.call("get_deck_world_basis")
		return deck_basis.z
	return -_target.global_transform.basis.z


func _deck_forward_on_ground(normal: Vector3) -> Vector3:
	var up := normal
	if up.length_squared() < 0.0001:
		up = Vector3.UP
	else:
		up = up.normalized()
	var forward := _deck_forward_raw().slide(up)
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD.slide(up)
	if forward.length_squared() < 0.0001:
		forward = Vector3.RIGHT.slide(up)
	return forward.normalized()


func _smooth_orientation(normal: Vector3, forward: Vector3) -> Basis:
	if not _orientation_initialized:
		_smoothed_normal = normal
		_smoothed_forward = forward
		_orientation_initialized = true
	else:
		_smoothed_normal = _smoothed_normal.lerp(normal, NORMAL_SMOOTH).normalized()
		_smoothed_forward = _smoothed_forward.lerp(forward, FORWARD_SMOOTH).normalized()
	var up := _smoothed_normal
	var flat_forward := _smoothed_forward.slide(up)
	if flat_forward.length_squared() < 0.0001:
		flat_forward = Vector3.FORWARD.slide(up)
	flat_forward = flat_forward.normalized()
	var right := flat_forward.cross(up).normalized()
	flat_forward = up.cross(right).normalized()
	return Basis(right, up, flat_forward)


func _align_to_ground(world_pos: Vector3) -> void:
	var surface := _surface_at(world_pos)
	var normal := Vector3.UP
	var center := world_pos
	if not surface.is_empty():
		normal = surface.normal
		center = surface.position
	var forward := _deck_forward_on_ground(normal)
	var deck_basis := _smooth_orientation(normal, forward)
	global_position = center
	global_basis = deck_basis
	var space := _space_state()
	if _terrain != null or space != null:
		_mesh.mesh = _build_conforming_mesh(center, deck_basis, QUAD_SIZE_M, space, world_pos.y + 2.0)
	else:
		_mesh.mesh = _build_flat_quad()
		_mesh.scale = Vector3(QUAD_SIZE_M, QUAD_SIZE_M, 1.0)


func _build_conforming_mesh(
	center: Vector3,
	basis: Basis,
	diameter: float,
	space: PhysicsDirectSpaceState3D,
	height_hint: float
) -> ArrayMesh:
	var segments := GRID_SEGMENTS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in segments - 1:
		for i in segments - 1:
			_add_conforming_quad(st, center, basis, diameter, space, height_hint, i, j, segments)
	st.generate_normals()
	return st.commit()


func _add_conforming_quad(
	st: SurfaceTool,
	center: Vector3,
	basis: Basis,
	diameter: float,
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
			_terrain,
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


func _ensure_visual() -> void:
	if _mesh != null:
		return
	var frames := _ensure_frames()
	if frames.is_empty():
		push_warning("LaserGroundReticle: missing reticle flipbook frames")
		return

	_material = ShaderMaterial.new()
	_material.shader = ReticleShader
	_material.set_shader_parameter("color_tint", COLOR_TINT)
	_material.set_shader_parameter("glow_strength", GLOW_STRENGTH)
	_material.set_shader_parameter("alpha_scale", ALPHA_SCALE)

	_mesh = MeshInstance3D.new()
	_mesh.name = "ReticleQuad"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _material
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.name = "ReticleLight"
	_light.shadow_enabled = false
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE_M
	_light.position = Vector3(0.0, 0.35, 0.0)
	add_child(_light)


func _sync_material() -> void:
	if _material == null:
		return
	var frames := _ensure_frames()
	if frames.is_empty():
		return
	var frame_idx := TelegraphScript.frame_index_for_telegraph(_elapsed, FRAME_COUNT)
	frame_idx = clampi(frame_idx, 0, frames.size() - 1)
	var texture := frames[frame_idx]
	if texture != null:
		_material.set_shader_parameter("frame_tex", texture)
	var visible := TelegraphScript.brackets_visible(_elapsed)
	_material.set_shader_parameter("bracket_visible", 1.0 if visible else 0.0)
	_sync_light(visible)


func _sync_light(brackets_visible: bool) -> void:
	if _light == null:
		return
	_light.light_color = LIGHT_COLOR
	var total := TelegraphScript.telegraph_total_sec()
	var progress := clampf(_elapsed / maxf(total, 0.001), 0.0, 1.0)
	var energy := lerpf(LIGHT_ENERGY_MIN, LIGHT_ENERGY_MAX, progress)
	if TelegraphScript.is_blinking(_elapsed) and not brackets_visible:
		energy *= BLINK_LIGHT_DIM
	_light.light_energy = energy


static func _ensure_frames() -> Array[Texture2D]:
	if _frames_loaded:
		return _frames
	_frames = VfxFlipbookScript.load_texture_sequence(
		TEXTURE_DIR,
		FRAME_PREFIX,
		FRAME_COUNT,
		FRAME_OFFSET
	)
	_frames_loaded = true
	return _frames
