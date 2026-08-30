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
@export var torus_path: NodePath = ^"../../Thruster_Torus"

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

@export_group("Fade")
@export var fade_in_duration := GliderVfxFadeEnvelopeScript.DEFAULT_FADE_IN
@export var fade_out_duration := GliderVfxFadeEnvelopeScript.DEFAULT_FADE_OUT

@export_group("Idle Orb")
@export_range(0.0, 1.0, 0.01) var idle_orb_presentation := 0.5
@export var idle_orb_emission_tint := Color(1.0, 0.38, 0.0)

@export_group("Lighting")
@export var omni_light_path: NodePath = ^"OmniLight3D"

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
var _torus: CSGShape3D
var _omni_light: OmniLight3D
var _base_omni_energy := -1.0
var _cylinder_material: StandardMaterial3D
var _cylinder_scene_material: StandardMaterial3D
var _cylinder_base_emission_energy := -1.0
var _cylinder_base_albedo_alpha := -1.0
var _orb_material: StandardMaterial3D
var _orb_scene_material: StandardMaterial3D
var _torus_material: StandardMaterial3D
var _torus_scene_material: StandardMaterial3D
var _orb_base_emission_energy := -1.0
var _torus_base_emission_energy := -1.0
var _orb_scene_scale := -1.0
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
	_set_active(false)
	refresh_idle_orb()
	set_process(true)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_update_editor_preview")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var should_active := _is_thruster_active()
	if should_active != _active:
		_set_active(should_active)

	_fade.step(delta)
	_update_visibility_from_fade()

	if _fade.is_dormant() and not _active:
		_refresh_orb_material()
		_apply_light_presentation()
		return

	if _active and not _loop_textures.is_empty():
		_elapsed += delta
		var frame := int(_elapsed * fps) % _loop_textures.size()
		if frame != _frame_index:
			_frame_index = frame
			_apply_cylinder_frame(_frame_index)
		else:
			_refresh_cylinder_material()
			_apply_light_presentation()
	elif _frame_index >= 0:
		_refresh_materials()
	else:
		_apply_light_presentation()


func set_thruster_intensity(scale: float) -> void:
	_intensity = clampf(scale, 0.0, 1.0)
	_refresh_materials()


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


func get_torus() -> CSGShape3D:
	_ensure_torus()
	return _torus


func get_orb_presentation() -> float:
	return _orb_presentation()


func get_orb_material_override() -> StandardMaterial3D:
	return _orb_material


func get_orb_base_emission_energy() -> float:
	_ensure_scene_orb_materials()
	return _orb_base_emission_energy


func get_torus_base_emission_energy() -> float:
	_ensure_scene_orb_materials()
	return _torus_base_emission_energy


func get_orb_scale_factor() -> float:
	return _orb_scale_factor()


func get_orb_scene_scale() -> float:
	_capture_orb_scene_scale()
	return _orb_scene_scale


func wants_orb_visible() -> bool:
	if _is_orb_active_presentation():
		return true
	return _orb_mesh != null and (_orb_mesh.mesh != null or _orb_mesh_resource != null)


func get_material_override() -> StandardMaterial3D:
	return _cylinder_material


func get_cylinder_base_emission_energy() -> float:
	_ensure_scene_cylinder_material()
	return _cylinder_base_emission_energy


func get_cylinder_base_albedo_alpha() -> float:
	_ensure_scene_cylinder_material()
	return _cylinder_base_albedo_alpha


func get_omni_light() -> OmniLight3D:
	_ensure_lights()
	return _omni_light


func get_base_omni_energy() -> float:
	_ensure_lights()
	return _base_omni_energy


func apply_orb_presentation(presentation: float) -> void:
	_apply_orb_presentation(presentation)


func refresh_idle_orb() -> void:
	_prepare_orb()
	if _orb_mesh != null and _orb_mesh.mesh != null:
		_orb_mesh.visible = true
		_sync_torus_visibility(true)
		_apply_orb_scale()
	_refresh_orb_material()
	_apply_light_presentation()


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
		_refresh_orb_material()
	else:
		_fade.target = 0.0


func _presentation() -> float:
	return _intensity * _fade.value


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


func _orb_scale_factor() -> float:
	return 1.0


func _capture_orb_scene_scale() -> void:
	if _orb_mesh == null or _orb_scene_scale >= 0.0:
		return
	_orb_scene_scale = _orb_mesh.scale.x


func _apply_orb_scale() -> void:
	if _orb_mesh == null:
		return
	_capture_orb_scene_scale()
	if _orb_scene_scale < 0.0:
		return
	var scene_scale := Vector3.ONE * _orb_scene_scale
	_orb_mesh.scale = scene_scale


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
			_sync_torus_visibility(true)
			_apply_orb_scale()
	if _cylinder_mesh != null:
		_cylinder_mesh.visible = _fade.should_show()


func _sibling_wants_orb() -> bool:
	var boost := _find_boost_vfx()
	return boost != null and boost.wants_orb_visible()


func _show_orb() -> void:
	_prepare_orb()
	if _orb_mesh == null or _orb_mesh.mesh == null:
		return
	_orb_mesh.visible = true
	_sync_torus_visibility(true)
	_apply_orb_scale()
	_refresh_orb_material()


func _set_orb_visible(is_visible: bool) -> void:
	if _orb_mesh != null:
		_orb_mesh.visible = is_visible
	_sync_torus_visibility(is_visible)


func _set_cylinder_visible(is_visible: bool) -> void:
	if _cylinder_mesh != null:
		_cylinder_mesh.visible = is_visible


func _apply_cylinder_frame(index: int) -> void:
	if _cylinder_mesh == null or index < 0 or index >= _loop_textures.size():
		return
	var texture := _loop_textures[index]
	_refresh_cylinder_material(texture)
	if _active:
		_refresh_orb_material()
	_apply_light_presentation()


func _ensure_lights() -> void:
	if _omni_light == null or not is_instance_valid(_omni_light):
		_omni_light = get_node_or_null(omni_light_path) as OmniLight3D
	if _omni_light != null and _base_omni_energy < 0.0:
		_base_omni_energy = _omni_light.light_energy


func _hide_lights() -> void:
	_ensure_lights()
	if _omni_light != null:
		_omni_light.visible = false


func _apply_light_presentation() -> void:
	_ensure_lights()

	var boost := _find_boost_vfx()
	if (
		boost != null
		and boost.get_presentation() > GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD
	):
		_hide_lights()
		return

	if _debug_boost_active:
		_hide_lights()
		return

	if _fade.is_dormant() and not _active:
		_hide_lights()
		return

	var light_presentation := 0.0

	if _active or _fade.should_show():
		light_presentation = _presentation() * idle_orb_presentation
	else:
		_hide_lights()
		return

	GliderVfxFlipbookScript.apply_omni_fill(
		_omni_light,
		light_presentation,
		_base_omni_energy
	)


func _refresh_materials(texture: Texture2D = null) -> void:
	if texture == null and _frame_index >= 0 and _frame_index < _loop_textures.size():
		texture = _loop_textures[_frame_index]
	_refresh_cylinder_material(texture)
	_refresh_orb_material()
	_apply_light_presentation()


func _refresh_cylinder_material(texture: Texture2D = null, presentation_override: float = -1.0) -> void:
	if _cylinder_mesh == null:
		return
	if texture == null and _frame_index >= 0 and _frame_index < _loop_textures.size():
		texture = _loop_textures[_frame_index]
	if texture == null:
		return
	var presentation := (
		presentation_override
		if presentation_override >= 0.0
		else _presentation()
	)
	_ensure_scene_cylinder_material()
	if _cylinder_scene_material == null:
		push_warning("GliderThrusterVfx: CylinderMesh2 needs a scene material_override")
		return
	var mat := _ensure_runtime_cylinder_material()
	mat.albedo_color = _cylinder_scene_material.albedo_color
	mat.emission_energy_multiplier = _cylinder_base_emission_energy
	GliderVfxFlipbookScript.apply_flipbook_presentation(
		mat,
		texture,
		presentation
	)


func _ensure_runtime_cylinder_material() -> StandardMaterial3D:
	if _cylinder_material == null:
		_cylinder_material = _cylinder_scene_material.duplicate() as StandardMaterial3D
		_cylinder_mesh.material_override = _cylinder_material
	return _cylinder_material


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
	_apply_orb_presentation(_orb_presentation())


func _ensure_scene_cylinder_material() -> void:
	_capture_cylinder_scene_material()


func _capture_cylinder_scene_material() -> void:
	if _cylinder_mesh == null or _cylinder_scene_material != null:
		return
	var src: Material = _cylinder_mesh.material_override
	if src is StandardMaterial3D:
		_cylinder_scene_material = (src as StandardMaterial3D).duplicate()
		_cylinder_base_emission_energy = _cylinder_scene_material.emission_energy_multiplier
		_cylinder_base_albedo_alpha = _cylinder_scene_material.albedo_color.a


func _ensure_scene_orb_materials() -> void:
	_ensure_torus()
	if _orb_mesh != null and _orb_scene_material == null:
		var orb_src: Material = _orb_mesh.material_override
		if orb_src is StandardMaterial3D:
			_orb_scene_material = (orb_src as StandardMaterial3D).duplicate()
			_orb_base_emission_energy = _orb_scene_material.emission_energy_multiplier
	if _torus != null and _torus_scene_material == null:
		var torus_src: Material = _torus.material
		if torus_src is StandardMaterial3D:
			_torus_scene_material = (torus_src as StandardMaterial3D).duplicate()
			_torus_base_emission_energy = _torus_scene_material.emission_energy_multiplier


func _apply_orb_presentation(presentation: float) -> void:
	_ensure_scene_orb_materials()
	if _orb_scene_material != null and _orb_mesh != null:
		var orb_mat := _ensure_runtime_orb_material()
		GliderVfxFlipbookScript.apply_emission_presentation(
			orb_mat,
			_orb_base_emission_energy,
			presentation
		)
	if _torus_scene_material != null and _torus != null:
		var torus_mat := _ensure_runtime_torus_material()
		GliderVfxFlipbookScript.apply_emission_presentation(
			torus_mat,
			_torus_base_emission_energy,
			presentation
		)


func _ensure_runtime_orb_material() -> StandardMaterial3D:
	if _orb_material == null:
		_orb_material = _orb_scene_material.duplicate() as StandardMaterial3D
		_orb_mesh.material_override = _orb_material
	return _orb_material


func _ensure_runtime_torus_material() -> StandardMaterial3D:
	if _torus_material == null:
		_torus_material = _torus_scene_material.duplicate() as StandardMaterial3D
		_torus.material = _torus_material
	return _torus_material


func _sync_torus_visibility(is_visible: bool) -> void:
	_ensure_torus()
	if _torus != null:
		_torus.visible = is_visible


func _ensure_torus() -> void:
	if _torus != null and is_instance_valid(_torus):
		return
	if torus_path != NodePath():
		_torus = get_node_or_null(torus_path) as CSGShape3D


func _ensure_meshes() -> void:
	if _orb_mesh == null or not is_instance_valid(_orb_mesh):
		_orb_mesh = _resolve_mesh_instance(orb_mesh_path, "OrbMesh2")
	_capture_orb_scene_scale()
	if _cylinder_mesh == null or not is_instance_valid(_cylinder_mesh):
		_cylinder_mesh = _resolve_mesh_instance(cylinder_mesh_path, "CylinderMesh2")
	_capture_cylinder_scene_material()
	_ensure_torus()
	_disable_vfx_mesh_shadows()


func _disable_vfx_mesh_shadows() -> void:
	if _orb_mesh != null:
		_orb_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _cylinder_mesh != null:
		_cylinder_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	_refresh_cylinder_material(texture, idle_orb_presentation)
	_apply_editor_light_preview()


func _apply_editor_light_preview() -> void:
	_ensure_lights()
	var light_presentation := idle_orb_presentation * _intensity
	GliderVfxFlipbookScript.apply_omni_fill(
		_omni_light,
		light_presentation,
		_base_omni_energy
	)


func _find_glider() -> GliderPlayerScript:
	var node: Node = get_parent()
	while node != null:
		if node is GliderPlayerScript:
			return node as GliderPlayerScript
		if node.get_parent() is GliderPlayerScript:
			return node.get_parent() as GliderPlayerScript
		node = node.get_parent()
	return null
