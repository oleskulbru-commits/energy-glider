class_name VestigeWallet
extends Node

## Run currency. Quotas reset at dawn. Collected balance survives Try Again until a new scene.

const VestigeBankScript := preload("res://scripts/game/vestige_bank.gd")

signal balance_changed(balance: int)

var balance := 0
var _dropped_by_level: Dictionary = {}
var _deposited := false


func _ready() -> void:
	add_to_group("vestige_wallet")
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_bind")


func get_balance() -> int:
	return balance


func dropped_count(level: int) -> int:
	return int(_dropped_by_level.get(level, 0))


func note_drop(level: int) -> void:
	var safe := maxi(level, 1)
	_dropped_by_level[safe] = dropped_count(safe) + 1


func collect_one() -> void:
	balance += 1
	balance_changed.emit(balance)


func deposit_run() -> void:
	if _deposited:
		return
	_deposited = true
	VestigeBankScript.add(balance)


func reset_quotas() -> void:
	_dropped_by_level.clear()


func clear_uncollected() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("vestige_pickup"):
		if node != null and is_instance_valid(node) and node.has_method("discard"):
			node.discard()
		elif node != null and is_instance_valid(node):
			node.queue_free()


static func find(tree: SceneTree):
	if tree == null:
		return null
	return tree.get_first_node_in_group("vestige_wallet")


func _bind() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var day_night := tree.get_first_node_in_group("day_night_cycle")
	if day_night != null and day_night.has_signal("dawn"):
		if not day_night.dawn.is_connected(_on_dawn):
			day_night.dawn.connect(_on_dawn)
	var eon := tree.get_first_node_in_group("eon_director")
	if eon != null and eon.has_signal("player_died"):
		if not eon.player_died.is_connected(_on_player_died):
			eon.player_died.connect(_on_player_died)


func _on_dawn() -> void:
	reset_quotas()


func _on_player_died(_position: Vector3 = Vector3.ZERO) -> void:
	clear_uncollected()
