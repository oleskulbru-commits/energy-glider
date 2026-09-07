class_name PlayerHealthBar
extends Node3D

## Anchor above the glider for floating damage numbers. No world-space HP bar.

const PlayerHealthScript = preload("res://scripts/player/player_health.gd")

const OFFSET_Y := 1.8

@export var player_health_path: NodePath

var _health: PlayerHealthScript
var _float_root: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position = Vector3(0.0, OFFSET_Y, 0.0)
	_rng.randomize()
	_float_root = Node3D.new()
	_float_root.name = "DamageFloats"
	add_child(_float_root)
	call_deferred("_connect_health")


func _connect_health() -> void:
	if player_health_path != NodePath():
		_health = get_node_or_null(player_health_path) as PlayerHealthScript
	if _health == null:
		_health = get_tree().get_first_node_in_group("player_health") as PlayerHealthScript
	if _health == null:
		return
	if _health.has_signal("damaged") and not _health.damaged.is_connected(_on_damaged):
		_health.damaged.connect(_on_damaged)


func _on_damaged(amount: int) -> void:
	if amount <= 0:
		return
	DamageFloat.spawn(_float_root, amount, _rng)
