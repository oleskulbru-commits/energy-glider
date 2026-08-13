@tool
class_name SandMaterial
extends StandardMaterial3D

## World meters per texture repeat (larger = bigger tiles, fewer repeats).
@export_range(1.0, 64.0, 0.5, "or_greater")
var texture_world_scale: float = ChunkBuilder.TEXTURE_UV_WORLD_SCALE:
	set(value):
		texture_world_scale = maxf(value, 0.001)
		_apply_controls()

## Normal map intensity (0 = flat, 1 = full strength).
@export_range(0.0, 4.0, 0.05, "or_greater")
var normal_strength: float = 1.0:
	set(value):
		normal_strength = maxf(value, 0.0)
		_apply_controls()


func _init() -> void:
	_apply_controls()


func _apply_controls() -> void:
	var uv_factor := ChunkBuilder.TEXTURE_UV_WORLD_SCALE / texture_world_scale
	uv1_scale = Vector3(uv_factor, uv_factor, 1.0)
	normal_scale = normal_strength
