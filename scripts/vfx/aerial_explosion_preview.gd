extends Node3D

## Preview aerial explosions in isolation. Press Space to replay at this node.

const AerialExplosionVfxScript := preload("res://scripts/vfx/aerial_explosion_vfx.gd")
const DefaultPresetPath := "res://assets/vfx/explosions/presets/aerial_explode_1.tres"

@export var preset: AerialExplosionPreset
@export var play_on_ready := true
@export var replay_action := &"ui_accept"


func _ready() -> void:
	if preset == null:
		preset = ResourceLoader.load(DefaultPresetPath) as AerialExplosionPreset
	if play_on_ready:
		_spawn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(replay_action):
		_spawn()


func _spawn() -> void:
	if preset == null:
		return
	AerialExplosionVfxScript.spawn(get_tree(), global_position, preset)
