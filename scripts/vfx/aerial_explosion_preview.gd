@tool
extends Node3D

## Test-scene helper: billboards [member still_mesh], swaps still frame, Space plays full animation.
## Tune look on aerial_explosion_material.tres — the scene quad uses that material directly.

const AerialExplosionVfxScript := preload("res://scripts/vfx/aerial_explosion_vfx.gd")
const VfxFlipbookScript := preload("res://scripts/vfx/vfx_flipbook.gd")
const DefaultPresetPath := "res://assets/vfx/explosions/presets/aerial_explode_1.tres"

@export var preset: AerialExplosionPreset:
	set(value):
		preset = value
		call_deferred("_apply_preset")

@export var still_mesh: NodePath = ^"StillPreview"

## File frame number, e.g. 10 loads aerial_explode_2_v001_frame_0010.png.
@export_range(1, 120, 1) var still_frame_number := 10:
	set(value):
		still_frame_number = value
		call_deferred("_apply_still_frame")

@export var replay_action := &"ui_accept"

var _playing_animation := false


func _ready() -> void:
	if preset == null:
		preset = ResourceLoader.load(DefaultPresetPath) as AerialExplosionPreset
	call_deferred("_apply_preset")


func _process(_delta: float) -> void:
	var mesh := _get_still_mesh()
	if mesh == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	mesh.look_at(cam.global_position, Vector3.UP)
	mesh.rotate_object_local(Vector3.UP, PI)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _playing_animation:
		return
	if event.is_action_pressed(replay_action):
		_spawn_animation()


func _apply_preset() -> void:
	if preset == null:
		return
	var mesh := _get_still_mesh()
	if mesh != null:
		var scale := preset.world_scale
		mesh.scale = Vector3(scale, scale, scale)
	_apply_still_frame()


func _apply_still_frame() -> void:
	if preset == null:
		return
	var material := _get_still_material()
	if material == null:
		return
	var textures := VfxFlipbookScript.load_texture_sequence(
		preset.texture_dir,
		preset.color_prefix,
		preset.frame_count,
		preset.color_frame_offset
	)
	var frame_idx := still_frame_number - preset.color_frame_offset
	if frame_idx < 0 or frame_idx >= textures.size():
		return
	AerialExplosionVfxScript.set_frame_texture(material, textures[frame_idx])


func _get_still_mesh() -> MeshInstance3D:
	if still_mesh == NodePath():
		return null
	return get_node_or_null(still_mesh) as MeshInstance3D


func _get_still_material() -> ShaderMaterial:
	var mesh := _get_still_mesh()
	if mesh == null:
		return null
	return mesh.material_override as ShaderMaterial


func _spawn_animation() -> void:
	if preset == null or get_tree() == null:
		return
	var mesh := _get_still_mesh()
	if mesh != null:
		mesh.visible = false
	_playing_animation = true
	var fx := AerialExplosionVfxScript.spawn(get_tree(), global_position, preset)
	if fx == null:
		_finish_animation()
		return
	var duration := float(preset.frame_count) / maxf(preset.fps, 0.001)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(fx):
		await fx.tree_exited
	_finish_animation()


func _finish_animation() -> void:
	_playing_animation = false
	var mesh := _get_still_mesh()
	if mesh != null:
		mesh.visible = true
