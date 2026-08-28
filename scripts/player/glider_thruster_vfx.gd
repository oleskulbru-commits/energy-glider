@tool
class_name GliderThrusterVfx
extends Node3D

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderBoostVfxScript = preload("res://scripts/player/glider_boost_vfx.gd")
const GliderVfxFlipbookScript = preload("res://scripts/player/glider_vfx_flipbook.gd")
const GliderVfxFadeEnvelopeScript = preload("res://scripts/player/glider_vfx_fade.gd")

const BASE_DIR := "res://assets/vfx/glider/fbx_thruster/"
const CLIP_DIR := "%sthruster_clip/" % BASE_DIR
const CLIP_PREFIX := "glider_thruster_flames"
const CYLINDER_FBX_PATH := "%sthruster_loop0.fbx" % BASE_DIR
const ORB_FBX_PATH := (
	"res://assets/vfx/glider/fbx_boost_fbx/boost_loop/glider_boost_loop0.fbx"
)
const LOOP_COUNT := 91
const ORB_NODE_NAME := "Shape3D1"
const CYLINDER_NODE_NAME := "Shape3D1_1_1"

@export_group("Meshes")
@export var orb_mesh_path: NodePath = ^"OrbMesh2":
	set(value):
		orb_mesh_path = value
		_orb_mesh = null
		if Engine.is_editor_hint():
			_update_editor_preview()
@export var cylinder_mesh_path: NodePath = ^"CylinderMesh2":
	set(value):
		cylinder_mesh_path = value
		_cylinder_mesh = null
		if Engine.is_editor_hint():
			_update_editor_preview()

@export_group("Playback")
@export var fps: float = 30.0
@export var shading_material: StandardMaterial3D:
	set(value):
		shading_material = value
		_refresh_materials()
@export var orb_shading_material: StandardMaterial3D:
	set(value):
		orb_shading_material = value
		_refresh_materials()

@export_group("Lighting")
@export var omni_light_path: NodePath = ^"OmniLight3D"

@export_group("UV Tuning")
@export var force_loop_preview := false:
	set(value):
		force_loop_preview = value
		if is_inside_tree():
			_apply_force_loop_state()

@export_group("Fade")
@export var fade_in_duration := GliderVfxFadeEnvelopeScript.DEFAULT_FADE_IN
@export var fade_out_duration := GliderVfxFadeEnvelopeScript.DEFAULT_FADE_OUT

@export_group("Idle Orb")
@export_range(0.0, 1.0, 0.01) var idle_orb_presentation := 0.5
@export var idle_orb_emission_tint := Color(1.0, 0.38, 0.0)
@export var active_orb_emission_tint := Color.WHITE

@export_group("Editor Preview")
@export_range(0, 90, 1) var editor_preview_frame: int = 0:
	set(value):
		editor_preview_frame = value
		_update_editor_preview()

var _loop_textures: Array[Texture2D] = []
var _orb_mesh_resource: Mesh
var _assets_loaded := false
var _editor_texture_cache: Dictionary = {}

var _orb_mesh: MeshInstance3D
var _cylinder_mesh: MeshInstance3D
var _orb_rest_scale := Vector3.ONE
var _orb_rest_scale_captured := false
var _omni_light: OmniLight3D
var _base_light_energy := -1.0
var _base_light_color := Color.WHITE
var _cylinder_material: StandardMaterial3D
var _orb_material: StandardMaterial3D
var _glider: GliderPlayerScript
var _active := false
var _elapsed := 0.0
var _frame_index := -1
var _intensity := 1.0
var _fade := GliderVfxFadeEnvelopeScript.new()
var _debug_forward_held := false
var _debug_braking := false
var _debug_boost_active := false


func _ready() -> void:
	_fade.fade_in_duration = fade_in_duration
	_fade.fade_out_duration = fade_out_duration
	_ensure_meshes()

	if Engine.is_editor_hint():
		_update_editor_preview()
		return

	if not _ensure_assets_loaded():
		_set_active(false)
		return

	_glider = _find_glider()
	if force_loop_preview:
		_set_active(true)
	else:
		_set_active(false)
	set_process(true)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_update_editor_preview")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if force_loop_preview:
		if not _active:
			_set_active(true)
		_fade.target = 1.0
		_fade.value = 1.0
		if _loop_textures.is_empty():
			return
		_elapsed += delta
		var frame := int(_elapsed * fps) % _loop_textures.size()
		if frame != _frame_index:
			_frame_index = frame
			_apply_cylinder_frame(_frame_index)
		_update_visibility_from_fade()
		_apply_presentation()
		return

	var should_active := _is_thruster_active()
	if should_active != _active:
		_set_active(should_active)

	_fade.step(delta)
	_update_visibility_from_fade()
	_apply_presentation()

	if _fade.is_dormant() and not _active:
		_refresh_orb_material()
		return

	if _active and not _loop_textures.is_empty():
		_elapsed += delta
		var frame := int(_elapsed * fps) % _loop_textures.size()
		if frame != _frame_index:
			_frame_index = frame
			_apply_cylinder_frame(_frame_index)
	elif _frame_index >= 0:
		_refresh_materials()


func set_thruster_intensity(scale: float) -> void:
	_intensity = clampf(scale, 0.0, 1.0)
	_refresh_materials()
	_apply_presentation()


func is_active() -> bool:
	return _active


func get_presentation() -> float:
	return _presentation()


func get_frame_index() -> int:
	return _frame_index


func get_loop_mesh_count() -> int:
	return _loop_textures.size()


func get_target_mesh() -> MeshInstance3D:
	return _cylinder_mesh


func get_orb_mesh() -> MeshInstance3D:
	return _orb_mesh


func get_orb_presentation() -> float:
	return _orb_presentation()


func get_orb_material_override() -> StandardMaterial3D:
	return _orb_material


func get_orb_scale_factor() -> float:
	return _orb_scale_factor()


func get_omni_light_color() -> Color:
	_ensure_light()
	if _omni_light == null:
		return Color.BLACK
	return _omni_light.light_color


func get_omni_light_energy() -> float:
	_ensure_light()
	if _omni_light == null:
		return 0.0
	return _omni_light.light_energy


func wants_orb_visible() -> bool:
	if _is_orb_active_presentation():
		return true
	return _orb_mesh != null and (_orb_mesh.mesh != null or _orb_mesh_resource != null)


func get_material_override() -> StandardMaterial3D:
	return _cylinder_material


func refresh_idle_orb() -> void:
	_prepare_orb()
	if _orb_mesh != null and _orb_mesh.mesh != null:
		_orb_mesh.visible = true
	_refresh_orb_material()


func debug_simulate_forward_press() -> void:
	_debug_forward_held = true
	_debug_braking = false
	_set_active(_is_thruster_active())


func debug_simulate_forward_release() -> void:
	_debug_forward_held = false
	_set_active(_is_thruster_active())


func debug_simulate_brake() -> void:
	_debug_braking = true
	_set_active(_is_thruster_active())


func debug_simulate_brake_release() -> void:
	_debug_braking = false
	_set_active(_is_thruster_active())


func debug_simulate_boost_active(active: bool) -> void:
	_debug_boost_active = active
	_set_active(_is_thruster_active())


func _is_thruster_active() -> bool:
	if _glider != null:
		return (
			_glider.is_forward_held()
			and not _glider.is_braking()
			and not _glider.is_boost_active()
		)
	return _debug_forward_held and not _debug_braking and not _debug_boost_active


func _set_active(active: bool) -> void:
	_active = active
	if active:
		_elapsed = 0.0
		_frame_index = -1
		_fade.target = 1.0
		_prepare_orb()
		if not _loop_textures.is_empty():
			_apply_cylinder_frame(0)
			_frame_index = 0
	else:
		_fade.target = 0.0


func _presentation() -> float:
	return _intensity * _fade.value


func _thruster_active_blend() -> float:
	return clampf(_presentation() / maxf(_intensity, 0.0001), 0.0, 1.0)


func _idle_omni_energy() -> float:
	return _base_light_energy * idle_orb_presentation


func _active_omni_energy() -> float:
	return _base_light_energy


func _is_orb_active_presentation() -> bool:
	if _active or _fade.should_show():
		return true
	var boost := _find_boost_vfx()
	return (
		boost != null
		and boost.get_presentation() > GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
	)


func _orb_presentation() -> float:
	var idle := idle_orb_presentation * _intensity
	var boost := _find_boost_vfx()
	if (
		boost != null
		and boost.get_presentation() > GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
	):
		return boost.get_presentation() * _intensity
	var active_presentation := _presentation()
	return maxf(idle, active_presentation)


func _orb_emission_tint() -> Color:
	var boost := _find_boost_vfx()
	if (
		boost != null
		and boost.get_presentation() > GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
	):
		return active_orb_emission_tint
	return idle_orb_emission_tint.lerp(active_orb_emission_tint, _thruster_active_blend())


func _is_idle_orb_state() -> bool:
	var boost := _find_boost_vfx()
	if (
		boost != null
		and boost.get_presentation() > GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
	):
		return false
	return not _active


func _orb_scale_factor() -> float:
	return _orb_presentation() / maxf(_intensity, 0.0001)


func _capture_orb_rest_scale() -> void:
	if _orb_mesh == null or _orb_rest_scale_captured:
		return
	_orb_rest_scale = _orb_mesh.scale
	_orb_rest_scale_captured = true


func _apply_orb_scale() -> void:
	if _orb_mesh == null:
		return
	_capture_orb_rest_scale()
	_orb_mesh.scale = _orb_rest_scale * _orb_scale_factor()


func _orb_idle_texture(orb_mesh: Mesh) -> Texture2D:
	if not _loop_textures.is_empty():
		return _loop_textures[0]
	if orb_mesh.get_surface_count() > 0:
		var surf := orb_mesh.surface_get_material(0)
		if surf is StandardMaterial3D:
			return (surf as StandardMaterial3D).albedo_texture
	return null


func _prepare_orb() -> void:
	if _orb_mesh == null:
		return
	if _orb_mesh_resource != null:
		_orb_mesh.mesh = _orb_mesh_resource
	elif _orb_mesh.mesh == null:
		return


func _update_visibility_from_fade() -> void:
	if _orb_mesh != null:
		_prepare_orb()
		if _orb_mesh.mesh != null:
			_orb_mesh.visible = true
			_apply_orb_scale()
	if _cylinder_mesh != null:
		_cylinder_mesh.visible = _fade.should_show()


func _sibling_wants_orb() -> bool:
	var boost := _find_boost_vfx()
	return boost != null and boost.wants_orb_visible()


func _apply_presentation() -> void:
	_ensure_light()
	if _omni_light == null:
		return
	if _base_light_energy < 0.0:
		_base_light_energy = _omni_light.light_energy
		_base_light_color = _omni_light.light_color

	var boost := _find_boost_vfx()
	if (
		boost != null
		and boost.get_presentation() > GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
	):
		_omni_light.light_energy = 0.0
		_omni_light.visible = false
		return

	var blend := _thruster_active_blend()
	_omni_light.light_color = idle_orb_emission_tint.lerp(_base_light_color, blend)
	_omni_light.light_energy = lerpf(_idle_omni_energy(), _active_omni_energy(), blend)
	_omni_light.visible = (
		_omni_light.light_energy > GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
	)


func _show_orb() -> void:
	_prepare_orb()
	if _orb_mesh == null or _orb_mesh.mesh == null:
		return
	_orb_mesh.visible = true
	_refresh_orb_material()


func _set_orb_visible(is_visible: bool) -> void:
	if _orb_mesh != null:
		_orb_mesh.visible = is_visible


func _set_cylinder_visible(is_visible: bool) -> void:
	if _cylinder_mesh != null:
		_cylinder_mesh.visible = is_visible


func _apply_cylinder_frame(index: int) -> void:
	if _cylinder_mesh == null or index < 0 or index >= _loop_textures.size():
		return
	_refresh_cylinder_material(_loop_textures[index])


func _refresh_materials(texture: Texture2D = null) -> void:
	if texture == null and _frame_index >= 0 and _frame_index < _loop_textures.size():
		texture = _loop_textures[_frame_index]
	_refresh_cylinder_material(texture)
	_refresh_orb_material()


func _refresh_cylinder_material(texture: Texture2D = null) -> void:
	if _cylinder_mesh == null:
		return
	if texture == null and _frame_index >= 0 and _frame_index < _loop_textures.size():
		texture = _loop_textures[_frame_index]
	if texture == null:
		return
	var presentation := _presentation()
	_cylinder_material = GliderVfxFlipbookScript.resolve_material(
		shading_material,
		texture,
		presentation
	)
	_cylinder_mesh.material_override = _cylinder_material


func _refresh_orb_material() -> void:
	if _orb_mesh == null:
		return
	_apply_orb_scale()
	var boost := _find_boost_vfx()
	if (
		boost != null
		and boost.get_presentation() > GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
	):
		return
	var orb_mesh := _orb_mesh_resource if _orb_mesh_resource != null else _orb_mesh.mesh
	if orb_mesh == null:
		return
	var presentation := _orb_presentation()
	var emission_tint := _orb_emission_tint()
	var template := orb_shading_material if orb_shading_material != null else shading_material
	if _is_idle_orb_state():
		if template != null:
			_orb_material = template.duplicate() as StandardMaterial3D
		else:
			_orb_material = StandardMaterial3D.new()
			_orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_orb_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_orb_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_orb_material.albedo_texture = null
		_orb_material.albedo_color = Color(
			emission_tint.r,
			emission_tint.g,
			emission_tint.b,
			presentation
		)
		GliderVfxFlipbookScript.apply_flipbook_emission(
			_orb_material,
			null,
			presentation,
			emission_tint
		)
		_orb_mesh.material_override = _orb_material
		return
	if template != null:
		_orb_material = template.duplicate() as StandardMaterial3D
		_orb_material.albedo_color.a = presentation
		var orb_texture := _orb_material.albedo_texture
		if orb_texture == null:
			orb_texture = _orb_idle_texture(orb_mesh)
		if orb_texture == null and orb_mesh.get_surface_count() > 0:
			var surf := orb_mesh.surface_get_material(0)
			if surf is StandardMaterial3D:
				orb_texture = (surf as StandardMaterial3D).albedo_texture
		GliderVfxFlipbookScript.apply_flipbook_emission(
			_orb_material,
			orb_texture,
			presentation,
			emission_tint
		)
	else:
		_orb_material = StandardMaterial3D.new()
		_orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_orb_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_orb_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_orb_material.albedo_color = Color(1.0, 1.0, 1.0, presentation)
		var orb_texture := _orb_idle_texture(orb_mesh)
		if orb_mesh.get_surface_count() > 0:
			var surf := orb_mesh.surface_get_material(0)
			if surf is StandardMaterial3D:
				var src := surf as StandardMaterial3D
				if orb_texture == null and src.albedo_texture != null:
					orb_texture = src.albedo_texture
					_orb_material.albedo_texture = orb_texture
				elif src.albedo_color.a > 0.0:
					_orb_material.albedo_color = Color(
						src.albedo_color.r,
						src.albedo_color.g,
						src.albedo_color.b,
						presentation
					)
		GliderVfxFlipbookScript.apply_flipbook_emission(
			_orb_material,
			orb_texture,
			presentation,
			emission_tint
		)
	_orb_mesh.material_override = _orb_material


func _ensure_light() -> void:
	if _omni_light == null or not is_instance_valid(_omni_light):
		_omni_light = get_node_or_null(omni_light_path) as OmniLight3D


func _ensure_meshes() -> void:
	if _orb_mesh == null or not is_instance_valid(_orb_mesh):
		_orb_mesh = _resolve_mesh_instance(orb_mesh_path, "OrbMesh2")
		if _orb_mesh != null:
			_orb_rest_scale_captured = false
			_capture_orb_rest_scale()
	if _cylinder_mesh == null or not is_instance_valid(_cylinder_mesh):
		_cylinder_mesh = _resolve_mesh_instance(cylinder_mesh_path, "CylinderMesh2")


func _resolve_mesh_instance(path: NodePath, fallback_name: String) -> MeshInstance3D:
	if path != NodePath():
		var from_path := get_node_or_null(path) as MeshInstance3D
		if from_path != null:
			return from_path
	var from_name := get_node_or_null(fallback_name) as MeshInstance3D
	if from_name != null:
		return from_name
	push_warning("GliderThrusterVfx: missing MeshInstance3D at %s" % path)
	return null


func _resolve_orb_mesh_resource() -> Mesh:
	var mesh := GliderVfxFlipbookScript.resolve_mesh_resource(
		_orb_mesh,
		CYLINDER_FBX_PATH,
		ORB_NODE_NAME
	)
	if mesh != null:
		return mesh
	return GliderVfxFlipbookScript.resolve_mesh_resource(
		_orb_mesh,
		ORB_FBX_PATH,
		ORB_NODE_NAME
	)


func _find_boost_vfx() -> GliderBoostVfxScript:
	var pivot := get_parent()
	if pivot == null:
		return null
	var socket := pivot.get_parent()
	if socket == null:
		return null
	return socket.get_node_or_null("BoostVfxPivot/BoostVfx") as GliderBoostVfxScript


func _ensure_assets_loaded() -> bool:
	if _assets_loaded:
		return _loop_textures.size() == LOOP_COUNT

	_ensure_meshes()

	_orb_mesh_resource = _resolve_orb_mesh_resource()
	if _orb_mesh_resource == null:
		push_warning("GliderThrusterVfx: no orb mesh in scene or FBX fallback")

	if _cylinder_mesh != null and _cylinder_mesh.mesh == null:
		var cylinder_mesh := GliderVfxFlipbookScript.load_fbx_mesh(
			CYLINDER_FBX_PATH,
			CYLINDER_NODE_NAME
		)
		if cylinder_mesh != null:
			_cylinder_mesh.mesh = cylinder_mesh

	_loop_textures = GliderVfxFlipbookScript.load_texture_sequence(
		CLIP_DIR,
		CLIP_PREFIX,
		LOOP_COUNT
	)
	_assets_loaded = _loop_textures.size() == LOOP_COUNT
	if not _assets_loaded:
		push_error(
			"GliderThrusterVfx: expected %d loop textures, got %d"
			% [LOOP_COUNT, _loop_textures.size()]
		)
	return _assets_loaded


func _ensure_editor_preview_loaded() -> bool:
	if _orb_mesh_resource == null:
		_orb_mesh_resource = _resolve_orb_mesh_resource()
	if _cylinder_mesh != null and _cylinder_mesh.mesh == null:
		var cylinder_mesh := GliderVfxFlipbookScript.load_fbx_mesh(
			CYLINDER_FBX_PATH,
			CYLINDER_NODE_NAME
		)
		if cylinder_mesh != null:
			_cylinder_mesh.mesh = cylinder_mesh
	return _cylinder_mesh != null and _cylinder_mesh.mesh != null


func _get_editor_preview_texture() -> Texture2D:
	var frame := clampi(editor_preview_frame, 0, LOOP_COUNT - 1)
	if _editor_texture_cache.has(frame):
		return _editor_texture_cache[frame] as Texture2D

	var path := "%s%s%04d.png" % [CLIP_DIR, CLIP_PREFIX, frame]
	var texture := load(path) as Texture2D
	if texture != null:
		_editor_texture_cache[frame] = texture
	return texture


func _update_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return

	_ensure_meshes()
	if not _ensure_editor_preview_loaded():
		return

	_show_orb()

	var texture := _get_editor_preview_texture()
	if texture == null:
		return

	_set_cylinder_visible(true)
	_refresh_cylinder_material(texture)


func _apply_force_loop_state() -> void:
	if Engine.is_editor_hint():
		_update_editor_preview()
		return
	if not _ensure_assets_loaded():
		return
	if force_loop_preview:
		_set_active(true)
	else:
		_set_active(_is_thruster_active())


func _find_glider() -> GliderPlayerScript:
	var node: Node = get_parent()
	while node != null:
		if node is GliderPlayerScript:
			return node as GliderPlayerScript
		if node.get_parent() is GliderPlayerScript:
			return node.get_parent() as GliderPlayerScript
		node = node.get_parent()
	return null
