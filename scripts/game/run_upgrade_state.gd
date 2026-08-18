class_name RunUpgradeState
extends Node

## Per-run tower offers and rifle stacks. Survives Try Again; scene reload clears it.

signal extra_projectiles_changed(count: int)

var extra_projectiles := 0
var _offers: Dictionary = {}
var _visited_this_life: Dictionary = {}


func _ready() -> void:
	add_to_group("run_upgrade_state")
	call_deferred("_connect_director")


func _connect_director() -> void:
	var director := get_tree().get_first_node_in_group("eon_director") as EonDirector
	if director == null:
		return
	if not director.player_died.is_connected(_on_player_died):
		director.player_died.connect(_on_player_died)


func _on_player_died(_position: Vector3) -> void:
	clear_visited_this_life()


func ensure_tower(tower_index: int) -> void:
	if tower_index < 1:
		return
	if _offers.has(tower_index):
		return
	_offers[tower_index] = UpgradeCatalog.default_offers()


func get_offers(tower_index: int) -> PackedStringArray:
	ensure_tower(tower_index)
	var raw: Variant = _offers.get(tower_index, PackedStringArray())
	return raw as PackedStringArray


func remaining_count(tower_index: int) -> int:
	return get_offers(tower_index).size()


func pick_offer(tower_index: int, slot: int) -> StringName:
	var offers := get_offers(tower_index)
	if slot < 0 or slot >= offers.size():
		return &""
	var id := StringName(offers[slot])
	offers.remove_at(slot)
	_offers[tower_index] = offers
	_apply_upgrade(id)
	return id


func _apply_upgrade(id: StringName) -> void:
	if id == UpgradeCatalog.ID_EXTRA_PROJECTILE:
		add_extra_projectile()


func add_extra_projectile() -> void:
	extra_projectiles += 1
	extra_projectiles_changed.emit(extra_projectiles)


func has_visited_this_life(tower_index: int) -> bool:
	return bool(_visited_this_life.get(tower_index, false))


func mark_visited_this_life(tower_index: int) -> void:
	if tower_index < 1:
		return
	_visited_this_life[tower_index] = true


func clear_visited_this_life() -> void:
	_visited_this_life.clear()
