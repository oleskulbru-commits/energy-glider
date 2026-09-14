class_name GliderHoverThrusterVfx
extends Node3D

## Animates HoverThruster* board quads with the same thruster flipbook as GliderThrusterVfx.

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript = preload("res://scripts/player/glider_physics.gd")
const GliderVfxFlipbookScript = preload("res://scripts/player/glider_vfx_flipbook.gd")
const GliderVfxFadeEnvelopeScript = preload("res://scripts/player/glider_vfx_fade.gd")

const CLIP_DIR := "res://assets/vfx/glider/fbx_thruster/thruster_clip/"
const CLIP_PREFIX := "glider_thruster_flames"
const LOOP_COUNT := 91
const HOVER_THRUSTER_PREFIX := "HoverThruster"

@export var shading_material: StandardMaterial3D
@export var fps: float = 30.0
@export var fade_in_duration := GliderVfxFadeEnvelopeScript.DEFAULT_FADE_IN
@export var fade_out_duration := GliderVfxFadeEnvelopeScript.DEFAULT_FADE_OUT

var _meshes: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _scene_material: StandardMaterial3D
var _base_emission_energy := -1.0
var _loop_textures: Array[Texture2D] = []
var _glider: GliderPlayerScript
var _active := false
var _elapsed := 0.0
var _frame_index := -1
var _intensity := 1.0
var _fade := GliderVfxFadeEnvelopeScript.new()


func _ready() -> void:
	_fade.fade_in_duration = fade_in_duration
	_fade.fade_out_duration = fade_out_duration
	_collect_meshes()
	if _meshes.is_empty():
		push_warning("GliderHoverThrusterVfx: no HoverThruster meshes found on %s" % get_parent())
		set_process(false)
		return
	if not _ensure_assets_loaded():
		set_process(false)
		return
	_glider = _find_glider()
	_set_active(false)
	_update_visibility()
	set_process(true)


func _process(delta: float) -> void:
	if _meshes.is_empty() or _loop_textures.is_empty():
		return

	var should_active := _is_hover_active()
	if should_active != _active:
		_set_active(should_active)

	_intensity = _hover_intensity()
	_fade.step(delta)
	_update_visibility()

	if _fade.is_dormant() and not _active:
		return

	if _active and not _loop_textures.is_empty():
		_elapsed += delta
		var frame := int(_elapsed * fps) % _loop_textures.size()
		if frame != _frame_index:
			_frame_index = frame
			_apply_frame(_frame_index)
		else:
			_refresh_materials()
	else:
		_refresh_materials()


func _collect_meshes() -> void:
	var board := get_parent()
	if board == null:
		return
	for child in board.get_children():
		if child is MeshInstance3D and String(child.name).begins_with(HOVER_THRUSTER_PREFIX):
			_meshes.append(child as MeshInstance3D)


func _capture_scene_material() -> void:
	if _scene_material != null:
		return
	if shading_material != null:
		_scene_material = shading_material.duplicate() as StandardMaterial3D
		_base_emission_energy = _scene_material.emission_energy_multiplier
		return
	for mesh in _meshes:
		var src: Material = mesh.material_override
		if src is StandardMaterial3D:
			_scene_material = (src as StandardMaterial3D).duplicate()
			_base_emission_energy = _scene_material.emission_energy_multiplier
			return


func _is_hover_active() -> bool:
	if _glider == null or _glider.is_run_ended():
		return false
	if _glider.is_boost_active():
		return false
	var clearance := _glider.get_clearance()
	var in_hover_band := clearance <= GliderPhysicsScript.HOVER_ZONE
	var low_glide := _glider.is_gliding() and clearance < GliderPhysicsScript.GLIDE_EXIT_HEIGHT
	if not (in_hover_band and (_glider.is_grounded() or low_glide)):
		return false
	return _hover_intensity() >= 0.05


func _hover_intensity() -> float:
	if _glider == null:
		return 1.0
	var clearance := _glider.get_clearance()
	var height_strength := 1.0 - smoothstep(
		GliderPhysicsScript.GLIDE_ENTER_HEIGHT,
		GliderPhysicsScript.HOVER_ZONE,
		clearance
	)
	var compression := clampf(
		(GliderPhysicsScript.BASE_HEIGHT - clearance) / 0.15,
		0.0,
		1.0
	)
	var horizontal_speed := MathUtil.horizontal_speed(_glider.velocity)
	var speed_strength := clampf(horizontal_speed / 8.0, 0.35, 1.0)
	return clampf(height_strength * lerpf(0.55, 1.0, compression) * speed_strength, 0.0, 1.0)


func _presentation() -> float:
	return _intensity * _fade.value


func _set_active(active: bool) -> void:
	_active = active
	if active:
		_elapsed = 0.0
		_frame_index = -1
		_fade.target = 1.0
		if not _loop_textures.is_empty():
			_apply_frame(0)
			_frame_index = 0
	else:
		_fade.target = 0.0


func _update_visibility() -> void:
	var show := _fade.should_show()
	for mesh in _meshes:
		mesh.visible = show


func _apply_frame(index: int) -> void:
	if index < 0 or index >= _loop_textures.size():
		return
	_refresh_materials(_loop_textures[index])


func _refresh_materials(texture: Texture2D = null) -> void:
	if texture == null and _frame_index >= 0 and _frame_index < _loop_textures.size():
		texture = _loop_textures[_frame_index]
	if texture == null or _scene_material == null:
		return
	var presentation := _presentation()
	for mat in _materials:
		mat.albedo_color = _scene_material.albedo_color
		mat.emission_energy_multiplier = _base_emission_energy
		GliderVfxFlipbookScript.apply_flipbook_presentation(mat, texture, presentation)


func _find_glider() -> GliderPlayerScript:
	var node: Node = get_parent()
	while node != null:
		if node is GliderPlayerScript:
			return node as GliderPlayerScript
		if node.get_parent() is GliderPlayerScript:
			return node.get_parent() as GliderPlayerScript
		node = node.get_parent()
	return null


func _ensure_assets_loaded() -> bool:
	_capture_scene_material()
	if _scene_material == null:
		push_warning("GliderHoverThrusterVfx: missing shading material")
		return false
	_loop_textures = GliderVfxFlipbookScript.load_texture_sequence(
		CLIP_DIR,
		CLIP_PREFIX,
		LOOP_COUNT
	)
	if _loop_textures.size() != LOOP_COUNT:
		push_error(
			"GliderHoverThrusterVfx: expected %d loop textures, got %d"
			% [LOOP_COUNT, _loop_textures.size()]
		)
		return false
	for mesh in _meshes:
		var mat := _scene_material.duplicate() as StandardMaterial3D
		mesh.material_override = mat
		_materials.append(mat)
	return true
