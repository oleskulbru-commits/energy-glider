class_name VfxFlipbook
extends RefCounted

## Shared PNG sequence loading for world and glider flipbook VFX.


static var _sequence_cache: Dictionary = {}


static func sequence_cache_key(
	dir: String,
	prefix: String,
	count: int,
	frame_offset: int = 0
) -> String:
	return "%s|%s|%d|%d" % [dir, prefix, count, frame_offset]


static func load_texture_sequence(
	dir: String,
	prefix: String,
	count: int,
	frame_offset: int = 0
) -> Array[Texture2D]:
	var key := sequence_cache_key(dir, prefix, count, frame_offset)
	if _sequence_cache.has(key):
		return _sequence_cache[key] as Array[Texture2D]

	var textures: Array[Texture2D] = []
	for i in count:
		var frame_number := i + frame_offset
		var path := "%s%s%04d.png" % [dir, prefix, frame_number]
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("VfxFlipbook: missing texture %s" % path)
			return textures
		textures.append(texture)
	_sequence_cache[key] = textures
	return textures


static func preload_texture_sequence(
	dir: String,
	prefix: String,
	count: int,
	frame_offset: int = 0
) -> void:
	load_texture_sequence(dir, prefix, count, frame_offset)


static func clear_sequence_cache() -> void:
	_sequence_cache.clear()
