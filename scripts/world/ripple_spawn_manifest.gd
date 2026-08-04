class_name RippleSpawnManifest
extends RefCounted

class Entry:
	var ripple_index: int = 0
	var local_offset: Vector3 = Vector3.ZERO
	var world_pos: Vector3 = Vector3.ZERO
	var tier: int = 1
	var distance_m: float = 0.0
	var bearing_rad: float = 0.0


var entries: Array[Entry] = []


func clear() -> void:
	entries.clear()


func add(entry: Entry) -> void:
	entries.append(entry)


func size() -> int:
	return entries.size()


func get_entry(index: int) -> Entry:
	return entries[index]
