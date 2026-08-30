@tool
class_name GliderBoostVfx
extends Node3D

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderThrusterVfxScript = preload("res://scripts/player/glider_thruster_vfx.gd")
const GliderVfxFlipbookScript = preload("res://scripts/player/glider_vfx_flipbook.gd")
const GliderVfxFadeEnvelopeScript = preload("res://scripts/player/glider_vfx_fade.gd")

const BASE_DIR := "res://assets/vfx/glider/fbx_boost_fbx/"
const START_CLIP_DIR := "%sboost_start/boost_start_clip/" % BASE_DIR
const LOOP_CLIP_DIR := "%sboost_loop/boost_loop_clip/" % BASE_DIR
const END_CLIP_DIR := "%sboost_end/boost_end_clip/" % BASE_DIR
const START_PREFIX := "glider_boost_start"
const LOOP_PREFIX := "glider_boost_loop"
const END_PREFIX := "glider_boost_end"
const LOOP_FRAME_OFFSET := 10
const END_FRAME_OFFSET := 80
const CYLINDER_FBX_PATH := "%sboost_loop/glider_boost_loop0.fbx" % BASE_DIR
const ORB_FBX_PATH := CYLINDER_FBX_PATH
const START_COUNT := 11
const LOOP_COUNT := 71
const END_COUNT := 11
const ORB_NODE_NAME := "Shape3D1"
const CYLINDER_NODE_NAME := "Shape3D1_1"

enum Phase { OFF, START, LOOP, END }
enum EditorPreviewSequence { START, LOOP, END }

const THRUSTER_ORB_PATH := NodePath("../../ThrusterVfxPivot/ThrusterVfx/OrbMesh2")

@export_group("Meshes")
@export var orb_mesh_path: NodePath = THRUSTER_ORB_PATH:
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

@export_group("Fade")
@export var fade_in_duration := GliderVfxFadeEnvelopeScript.DEFAULT_FADE_IN
@export var fade_out_duration := GliderVfxFadeEnvelopeScript.DEFAULT_FADE_OUT

@export_group("Lighting")
@export var omni_light_path: NodePath = ^"OmniLight3D"
@export var light_color := Color(1.0, 0.38, 0.0)

@export_group("Editor Preview")
@export var editor_preview_sequence: EditorPreviewSequence = EditorPreviewSequence.LOOP:
	set(value):
		editor_preview_sequence = value
		_update_editor_preview()
@export_range(0, 70, 1) var editor_preview_frame: int = 0:
	set(value):
		editor_preview_frame = value
		_update_editor_preview()

var _start_textures: Array[Texture2D] = []
var _loop_textures: Array[Texture2D] = []
var _end_textures: Array[Texture2D] = []
var _active_textures: Array[Texture2D] = []
var _orb_mesh_resource: Mesh
var _assets_loaded := false
var _editor_texture_cache: Dictionary = {}

var _orb_mesh: MeshInstance3D
var _cylinder_mesh: MeshInstance3D
var _omni_light: OmniLight3D
var _base_omni_energy := -1.0
var _cylinder_material: StandardMaterial3D
var _cylinder_scene_material: StandardMaterial3D
var _cylinder_base_emission_energy := -1.0
var _cylinder_base_albedo_alpha := -1.0
var _orb_material: StandardMaterial3D
var _glider: GliderPlayerScript
var _phase := Phase.OFF
var _elapsed := 0.0
var _frame_index := -1
var _intensity := 1.0
var _fade := GliderVfxFadeEnvelopeScript.new()
var _was_boost_active := false
var _debug_boost_held := false
var _debug_forward_held := false


func _ready() -> void:
	_fade.fade_in_duration = fade_in_duration
	_fade.fade_out_duration = fade_out_duration
	_ensure_meshes()

	if Engine.is_editor_hint():
		_update_editor_preview()
		return

	if not _ensure_assets_loaded():
		return

	_glider = _find_glider()
	_begin_phase(Phase.OFF)
	set_process(true)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_update_editor_preview")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _glider != null:
		_update_boost_edges(_glider.is_boost_active())

	_fade.step(delta)

	if _phase == Phase.OFF:
		_try_complete_off()
		if _fade.is_dormant():
			_hide_lights()
			_refresh_thruster_idle_orb()
			return
		_update_visibility_from_fade()
		_refresh_materials()
		_apply_light_presentation()
		return

	_update_visibility_from_fade()

	if _active_textures.is_empty():
		_apply_light_presentation()
		return

	_advance_playback(delta)
	_refresh_orb_material()
	_apply_light_presentation()


func set_boost_intensity(scale: float) -> void:
	_intensity = clampf(scale, 0.0, 1.0)
	_refresh_materials()


func get_presentation() -> float:
	return _presentation()


func get_phase() -> int:
	return _phase as int


func get_frame_index() -> int:
	return _frame_index


func get_start_mesh_count() -> int:
	return _start_textures.size()


func get_loop_mesh_count() -> int:
	return _loop_textures.size()


func get_end_mesh_count() -> int:
	return _end_textures.size()


func get_active_mesh_count() -> int:
	return _active_textures.size()


func get_target_mesh() -> MeshInstance3D:
	return _cylinder_mesh


func get_orb_mesh() -> MeshInstance3D:
	return _orb_mesh


func wants_orb_visible() -> bool:
	return _fade.should_show()


func get_material_override() -> StandardMaterial3D:
	return _cylinder_material


func get_cylinder_base_emission_energy() -> float:
	_ensure_scene_cylinder_material()
	return _cylinder_base_emission_energy


func get_cylinder_base_albedo_alpha() -> float:
	_ensure_scene_cylinder_material()
	return _cylinder_base_albedo_alpha


func get_orb_material_override() -> StandardMaterial3D:
	return _orb_material


func get_omni_light() -> OmniLight3D:
	_ensure_lights()
	return _omni_light


func get_base_omni_energy() -> float:
	_ensure_lights()
	return _base_omni_energy


func debug_simulate_boost_only() -> void:
	_debug_boost_held = true
	_on_boost_pressed()


func debug_simulate_boost_press() -> void:
	_debug_forward_held = true
	_debug_boost_held = true
	_on_boost_pressed()


func debug_simulate_boost_release() -> void:
	_debug_boost_held = false
	_on_boost_released()


func debug_simulate_forward_press() -> void:
	_debug_forward_held = true


func debug_simulate_forward_release() -> void:
	_debug_forward_held = false


func _update_boost_edges(boosting: bool) -> void:
	if boosting and not _was_boost_active:
		_on_boost_pressed()
	elif not boosting and _was_boost_active:
		_on_boost_released()
	_was_boost_active = boosting


func _on_boost_pressed() -> void:
	if _phase == Phase.OFF or _phase == Phase.END:
		_begin_phase(Phase.START)


func _on_boost_released() -> void:
	if _phase == Phase.START or _phase == Phase.LOOP:
		_begin_phase(Phase.END)


func _begin_phase(phase: Phase) -> void:
	_phase = phase
	_elapsed = 0.0
	_frame_index = -1

	match phase:
		Phase.OFF:
			_fade.target = 0.0
			_hide_lights()
			return
		Phase.START:
			_active_textures = _start_textures
		Phase.LOOP:
			_active_textures = _loop_textures
		Phase.END:
			_active_textures = _end_textures

	if _active_textures.is_empty():
		push_error("GliderBoostVfx: no cylinder textures for phase %s" % Phase.keys()[phase])
		_begin_phase(Phase.OFF)
		return

	_fade.target = 1.0
	_apply_cylinder_frame(0)
	_frame_index = 0
	_prepare_orb()
	_update_visibility_from_fade()
	_refresh_orb_material()


func _try_complete_off() -> void:
	if not _fade.is_dormant():
		return
	_active_textures = []
	_set_cylinder_visible(false)
	_refresh_thruster_idle_orb()


func _refresh_thruster_idle_orb() -> void:
	var thruster := _find_thruster_vfx()
	if thruster != null:
		thruster.refresh_idle_orb()


func _presentation() -> float:
	return _intensity * _fade.value


func _prepare_orb() -> void:
	if _orb_mesh == null:
		return
	if _orb_mesh.mesh != null:
		return
	if _orb_mesh_resource != null:
		_orb_mesh.mesh = _orb_mesh_resource


func _update_visibility_from_fade() -> void:
	if _cylinder_mesh != null:
		_cylinder_mesh.visible = _fade.should_show()
	if _orb_mesh != null and _fade.should_show():
		_prepare_orb()
		_orb_mesh.visible = true


func _sibling_wants_orb() -> bool:
	var thruster := _find_thruster_vfx()
	return thruster != null and thruster.wants_orb_visible()


func _advance_playback(delta: float) -> void:
	if _phase == Phase.OFF or _active_textures.is_empty():
		return

	_elapsed += delta
	var frame_count := _active_textures.size()
	var frame := int(_elapsed * fps)

	if _phase == Phase.LOOP:
		frame = frame % frame_count
		if frame != _frame_index:
			_frame_index = frame
			_apply_cylinder_frame(_frame_index)
		else:
			_refresh_cylinder_material()
		return

	if frame >= frame_count:
		_on_sequence_finished()
		return

	if frame != _frame_index:
		_frame_index = frame
		_apply_cylinder_frame(_frame_index)
	else:
		_refresh_cylinder_material()


func _on_sequence_finished() -> void:
	match _phase:
		Phase.START:
			if _is_boost_held():
				_begin_phase(Phase.LOOP)
			else:
				_begin_phase(Phase.END)
		Phase.END:
			_begin_phase(Phase.OFF)
		_:
			pass


func _is_boost_held() -> bool:
	if _glider != null:
		return _glider.is_boost_active()
	return _debug_boost_held


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
	if _cylinder_mesh == null or index < 0 or index >= _active_textures.size():
		return
	var texture := _active_textures[index]
	_refresh_cylinder_material(texture)
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

	if _fade.is_dormant() and _phase == Phase.OFF:
		_hide_lights()
		return

	var presentation := _presentation()
	if not _fade.should_show():
		_hide_lights()
		return

	GliderVfxFlipbookScript.apply_omni_fill(
		_omni_light,
		presentation,
		_base_omni_energy
	)


func _refresh_materials(texture: Texture2D = null) -> void:
	if texture == null and _frame_index >= 0 and _frame_index < _active_textures.size():
		texture = _active_textures[_frame_index]
	_refresh_cylinder_material(texture)
	_refresh_orb_material()
	_apply_light_presentation()


func _refresh_cylinder_material(texture: Texture2D = null, presentation_override: float = -1.0) -> void:
	if _cylinder_mesh == null:
		return
	if texture == null and _frame_index >= 0 and _frame_index < _active_textures.size():
		texture = _active_textures[_frame_index]
	if texture == null:
		return
	var presentation := (
		presentation_override
		if presentation_override >= 0.0
		else _presentation()
	)
	_ensure_scene_cylinder_material()
	if _cylinder_scene_material == null:
		push_warning("GliderBoostVfx: CylinderMesh2 needs a scene material_override")
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
	if _fade.is_dormant() and _phase == Phase.OFF:
		return
	var presentation := _presentation()
	if presentation <= GliderVfxFadeEnvelopeScript.VISIBILITY_THRESHOLD:
		return
	var thruster := _find_thruster_vfx()
	if thruster != null:
		thruster.apply_orb_presentation(presentation)


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


func _ensure_meshes() -> void:
	if _orb_mesh == null or not is_instance_valid(_orb_mesh):
		_orb_mesh = _resolve_mesh_instance(orb_mesh_path, "OrbMesh2")
	if _cylinder_mesh == null or not is_instance_valid(_cylinder_mesh):
		_cylinder_mesh = _resolve_mesh_instance(cylinder_mesh_path, "CylinderMesh2")
	_capture_cylinder_scene_material()
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
	if fallback_name == "OrbMesh2":
		var borrowed := _borrow_thruster_orb()
		if borrowed != null:
			return borrowed
	push_warning("GliderBoostVfx: missing MeshInstance3D at %s" % path)
	return null


func _borrow_thruster_orb() -> MeshInstance3D:
	var thruster := _find_thruster_vfx()
	if thruster != null:
		return thruster.get_orb_mesh()
	var socket := get_parent()
	if socket != null:
		socket = socket.get_parent()
	if socket == null:
		return null
	return socket.get_node_or_null("ThrusterVfxPivot/ThrusterVfx/OrbMesh2") as MeshInstance3D


func _find_thruster_vfx() -> GliderThrusterVfxScript:
	var pivot := get_parent()
	if pivot == null:
		return null
	var socket := pivot.get_parent()
	if socket == null:
		return null
	return socket.get_node_or_null("ThrusterVfxPivot/ThrusterVfx") as GliderThrusterVfxScript


func _ensure_assets_loaded() -> bool:
	if _assets_loaded:
		return (
			not _start_textures.is_empty()
			and not _loop_textures.is_empty()
			and not _end_textures.is_empty()
		)

	_ensure_meshes()

	if _orb_mesh == null or _orb_mesh.mesh == null:
		_orb_mesh_resource = GliderVfxFlipbookScript.resolve_mesh_resource(
			_orb_mesh,
			ORB_FBX_PATH,
			ORB_NODE_NAME
		)
		if _orb_mesh_resource == null:
			push_warning("GliderBoostVfx: no orb mesh in scene or %s" % ORB_FBX_PATH)

	if _cylinder_mesh != null and _cylinder_mesh.mesh == null:
		var cylinder_mesh := GliderVfxFlipbookScript.load_fbx_mesh(
			CYLINDER_FBX_PATH,
			CYLINDER_NODE_NAME
		)
		if cylinder_mesh != null:
			_cylinder_mesh.mesh = cylinder_mesh

	_start_textures = GliderVfxFlipbookScript.load_texture_sequence(
		START_CLIP_DIR,
		START_PREFIX,
		START_COUNT
	)
	_loop_textures = GliderVfxFlipbookScript.load_texture_sequence(
		LOOP_CLIP_DIR,
		LOOP_PREFIX,
		LOOP_COUNT,
		LOOP_FRAME_OFFSET
	)
	_end_textures = GliderVfxFlipbookScript.load_texture_sequence(
		END_CLIP_DIR,
		END_PREFIX,
		END_COUNT,
		END_FRAME_OFFSET
	)
	_assets_loaded = (
		_start_textures.size() == START_COUNT
		and _loop_textures.size() == LOOP_COUNT
		and _end_textures.size() == END_COUNT
	)
	if not _assets_loaded:
		push_error("GliderBoostVfx: failed to load boost texture flipbooks")
	return _assets_loaded


func _editor_sequence_info() -> Array:
	match editor_preview_sequence:
		EditorPreviewSequence.START:
			return [START_CLIP_DIR, START_PREFIX, START_COUNT, 0]
		EditorPreviewSequence.END:
			return [END_CLIP_DIR, END_PREFIX, END_COUNT, END_FRAME_OFFSET]
		_:
			return [LOOP_CLIP_DIR, LOOP_PREFIX, LOOP_COUNT, LOOP_FRAME_OFFSET]


func _ensure_editor_preview_loaded() -> bool:
	if _orb_mesh != null and _orb_mesh.mesh == null and _orb_mesh_resource == null:
		_orb_mesh_resource = GliderVfxFlipbookScript.resolve_mesh_resource(
			_orb_mesh,
			ORB_FBX_PATH,
			ORB_NODE_NAME
		)
	if _cylinder_mesh != null and _cylinder_mesh.mesh == null:
		var cylinder_mesh := GliderVfxFlipbookScript.load_fbx_mesh(
			CYLINDER_FBX_PATH,
			CYLINDER_NODE_NAME
		)
		if cylinder_mesh != null:
			_cylinder_mesh.mesh = cylinder_mesh
	return _cylinder_mesh != null and _cylinder_mesh.mesh != null


func _get_editor_preview_texture() -> Texture2D:
	var info := _editor_sequence_info()
	var dir: String = info[0]
	var prefix: String = info[1]
	var count: int = info[2]
	var frame_offset: int = info[3]
	var frame := clampi(editor_preview_frame, 0, count - 1)
	var key := "%s:%d" % [dir, frame]
	if _editor_texture_cache.has(key):
		return _editor_texture_cache[key] as Texture2D

	var path := "%s%s%04d.png" % [dir, prefix, frame + frame_offset]
	var texture := load(path) as Texture2D
	if texture != null:
		_editor_texture_cache[key] = texture
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
	_refresh_cylinder_material(texture, 1.0)
	_apply_editor_light_preview()


func _apply_editor_light_preview() -> void:
	_ensure_lights()
	GliderVfxFlipbookScript.apply_omni_fill(
		_omni_light,
		1.0,
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
