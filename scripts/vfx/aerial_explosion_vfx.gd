class_name AerialExplosionVfx
extends Node3D

## One-shot camera-facing aerial explosion flipbook (color + normal).
## Tweak [member preset] or the preset's material resource; values are duplicated per spawn.

const VfxFlipbookScript := preload("res://scripts/vfx/vfx_flipbook.gd")
const AerialExplosionPresetScript := preload("res://scripts/vfx/aerial_explosion_preset.gd")
const CameraImpactShakeScript := preload("res://scripts/player/camera_impact_shake.gd")
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const ExplosionShader := preload("res://assets/vfx/shaders/aerial_explosion.gdshader")
const DefaultPresetPath := "res://assets/vfx/explosions/presets/aerial_explode_1.tres"

const FREE_BUFFER_SEC := 0.05

@export var preset: AerialExplosionPreset
@export var play_on_ready := false

var _preset: AerialExplosionPreset
var _scale_mult := 1.0
var _frame := 0.0
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _color_textures: Array[Texture2D] = []
var _normal_textures: Array[Texture2D] = []
var _flash_light: OmniLight3D


static func spawn(
	tree: SceneTree,
	world_pos: Vector3,
	preset_override: AerialExplosionPreset = null,
	scale_mult: float = 1.0
) -> AerialExplosionVfx:
	if tree == null:
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null
	var fx := AerialExplosionVfx.new()
	parent.add_child(fx)
	fx.global_position = world_pos
	var resolved := preset_override if preset_override != null else _load_default_preset()
	fx.configure(resolved, scale_mult)
	return fx


static func _load_default_preset() -> AerialExplosionPreset:
	return ResourceLoader.load(DefaultPresetPath) as AerialExplosionPreset


func _ready() -> void:
	if play_on_ready and preset != null:
		configure(preset)


func configure(preset_override: AerialExplosionPreset, scale_mult: float = 1.0) -> void:
	_preset = preset_override
	preset = preset_override
	_scale_mult = maxf(scale_mult, 0.01)
	if not _load_sequences():
		queue_free()
		return
	_build_mesh()
	if _preset.spawn_light:
		_add_flash_light()
	if _preset.shake_strength > 0.0 and _preset.shake_radius_m > 0.0:
		CameraImpactShakeScript.request(
			get_tree(),
			global_position,
			_preset.shake_strength,
			_preset.shake_radius_m
		)
	_set_frame(0)


func _process(delta: float) -> void:
	if _preset == null or _color_textures.is_empty():
		return
	_face_camera()
	_frame += delta * _preset.fps
	var frame_idx := int(_frame)
	if frame_idx >= _preset.frame_count:
		queue_free()
		return
	_set_frame(frame_idx)


func _load_sequences() -> bool:
	if _preset == null:
		return false
	_color_textures = VfxFlipbookScript.load_texture_sequence(
		_preset.texture_dir,
		_preset.color_prefix,
		_preset.frame_count,
		_preset.color_frame_offset
	)
	_normal_textures = VfxFlipbookScript.load_texture_sequence(
		_preset.texture_dir,
		_preset.normal_prefix,
		_preset.frame_count,
		_preset.normal_frame_offset
	)
	return (
		_color_textures.size() == _preset.frame_count
		and _normal_textures.size() == _preset.frame_count
	)


func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "ExplosionQuad"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mesh.mesh = quad
	var scale := _preset.world_scale * _scale_mult
	_mesh.scale = Vector3(scale, scale, scale)

	_material = _create_material()
	_mesh.material_override = _material
	add_child(_mesh)


func _create_material() -> ShaderMaterial:
	if _preset.material != null:
		return _preset.material.duplicate() as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = ExplosionShader
	_apply_preset_shader_params(material)
	return material


func _apply_preset_shader_params(material: ShaderMaterial) -> void:
	material.set_shader_parameter("light_dir", _preset.light_dir)
	material.set_shader_parameter("normal_strength", _preset.normal_strength)
	material.set_shader_parameter("emission_strength", _preset.emission_strength)
	material.set_shader_parameter("color_tint", Vector3(
		_preset.color_tint.r,
		_preset.color_tint.g,
		_preset.color_tint.b
	))
	material.set_shader_parameter("alpha_scale", _preset.alpha_scale)
	material.set_shader_parameter("lighting_dark", _preset.lighting_dark)
	material.set_shader_parameter("lighting_bright", _preset.lighting_bright)


func _add_flash_light() -> void:
	_flash_light = OmniLight3D.new()
	_flash_light.name = "FlashLight"
	_flash_light.light_color = _preset.light_color
	_flash_light.light_energy = _preset.light_energy
	_flash_light.omni_range = _preset.light_range_m
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	var duration := float(_preset.frame_count) / maxf(_preset.fps, 0.001) + FREE_BUFFER_SEC
	var tween := create_tween()
	tween.tween_property(_flash_light, "light_energy", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_frame(frame_idx: int) -> void:
	if _material == null:
		return
	var idx := clampi(frame_idx, 0, _preset.frame_count - 1)
	_material.set_shader_parameter("color_tex", _color_textures[idx])
	_material.set_shader_parameter("normal_tex", _normal_textures[idx])


func _face_camera() -> void:
	var cam := _find_camera()
	if cam == null:
		return
	var to_cam := cam.global_position - global_position
	if to_cam.length_squared() < 0.0001:
		return
	look_at(global_position + to_cam.normalized(), Vector3.UP)


func _find_camera() -> Camera3D:
	var rig := get_tree().get_first_node_in_group("player_rig")
	if rig != null and rig.has_method("get_follow_camera"):
		var follow := rig.call("get_follow_camera") as Camera3D
		if follow != null:
			return follow
	for node in get_tree().get_nodes_in_group("glider_camera"):
		if node is Camera3D:
			return node as Camera3D
	return get_viewport().get_camera_3d()
