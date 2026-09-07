class_name VfxFlipbook
extends RefCounted

## Shared PNG sequence loading for world and glider flipbook VFX.


static func load_texture_sequence(
	dir: String,
	prefix: String,
	count: int,
	frame_offset: int = 0
) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for i in count:
		var frame_number := i + frame_offset
		var path := "%s%s%04d.png" % [dir, prefix, frame_number]
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("VfxFlipbook: missing texture %s" % path)
			return textures
		textures.append(texture)
	return textures
