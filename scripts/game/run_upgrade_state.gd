class_name RunUpgradeState
extends Node

## Per-run tower offers and rifle stacks. Survives Try Again; scene reload clears it.

signal extra_projectiles_changed(count: int)

var extra_projectiles := 0
var attack_speed_reduction := 0.0
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
	var seed := LevelRun.world_seed()
	if seed < 0:
		seed = 42
	_offers[tower_index] = UpgradeCatalog.roll_shop(seed, tower_index)


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
	var family := UpgradeCatalog.family_of(id)
	if family == UpgradeCatalog.FAMILY_PROJECTILE:
		add_extra_projectile(UpgradeCatalog.projectile_bonus(UpgradeCatalog.rarity_of(id)))
	elif family == UpgradeCatalog.FAMILY_ATTACK_SPEED:
		attack_speed_reduction += UpgradeCatalog.attack_speed_percent(
			UpgradeCatalog.rarity_of(id)
		)


func add_extra_projectile(amount: int = 1) -> void:
	extra_projectiles += maxi(amount, 0)
	extra_projectiles_changed.emit(extra_projectiles)


func has_visited_this_life(tower_index: int) -> bool:
	return bool(_visited_this_life.get(tower_index, false))


func mark_visited_this_life(tower_index: int) -> void:
	if tower_index < 1:
		return
	_visited_this_life[tower_index] = true


func clear_visited_this_life() -> void:
	_visited_this_life.clear()
