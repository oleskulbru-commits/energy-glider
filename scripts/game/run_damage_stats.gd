class_name RunDamageStats
extends Node

var _damage: Dictionary = {}


func _ready() -> void:
	add_to_group("run_damage_stats")


func record(weapon: StringName, amount: int) -> void:
	if amount <= 0 or weapon == StringName():
		return
	var key := String(weapon)
	_damage[key] = int(_damage.get(key, 0)) + amount


func damage_for(weapon: StringName) -> int:
	return int(_damage.get(String(weapon), 0))


func ranked_weapons(owned: PackedStringArray) -> PackedStringArray:
	var ranked: Array[String] = []
	for weapon in owned:
		ranked.append(String(weapon))
	ranked.sort_custom(func(a: String, b: String) -> bool:
		return damage_for(StringName(a)) > damage_for(StringName(b))
	)
	var out := PackedStringArray()
	for weapon in ranked:
		out.append(weapon)
	return out


func reset() -> void:
	_damage.clear()


static func find_in_tree(tree: SceneTree) -> RunDamageStats:
	if tree == null:
		return null
	return tree.get_first_node_in_group("run_damage_stats") as RunDamageStats
