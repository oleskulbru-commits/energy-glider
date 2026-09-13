@tool
extends Node3D

## Test-scene helper: replay explosion fireball on Space.

const ExplosionFireballVfxScript := preload("res://scripts/vfx/explosion_fireball_vfx.gd")

@export var replay_action := &"ui_accept"
@export var world_scale := 12.0
@export var scale_mult := 1.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_spawn_preview")


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed(replay_action):
		_spawn_preview()


func _spawn_preview() -> void:
	for node in get_tree().get_nodes_in_group("explosion_fireball_vfx"):
		if is_instance_valid(node):
			node.queue_free()
	ExplosionFireballVfxScript.spawn(get_tree(), global_position, scale_mult, world_scale)
