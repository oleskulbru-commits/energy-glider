@tool
extends Node3D

## Test-scene helper: looping damage-style sparks for tuning spark_particle.tres.
## Edit spark_particle.tres for look; use inspector on DamageSparks for motion.

const SparkParticleVfxScript := preload("res://scripts/vfx/spark_particle_vfx.gd")
const DroneDamageSparkVfxScript := preload("res://scripts/vfx/drone_damage_spark_vfx.gd")

@export var spark_color: Color = SparkParticleVfxScript.DEFAULT_COLOR:
	set(value):
		spark_color = value
		call_deferred("_apply_tint")

@export var glow_strength: float = SparkParticleVfxScript.DEFAULT_GLOW_STRENGTH:
	set(value):
		glow_strength = value
		call_deferred("_apply_tint")

@export var replay_action := &"ui_accept"
@export var sparks_path: NodePath = ^"DamageSparks"


func _ready() -> void:
	call_deferred("_apply_tint")


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed(replay_action):
		_restart_sparks()


func _apply_tint() -> void:
	var sparks := _get_sparks()
	if sparks == null:
		return
	var quad := sparks.draw_pass_1 as QuadMesh
	if quad == null:
		return
	var mat := quad.material as ShaderMaterial
	if mat == null:
		return
	SparkParticleVfxScript.apply_spark_look(mat)
	mat.set_shader_parameter("ColorParameter", spark_color)
	mat.set_shader_parameter("GlowStrength", glow_strength)


func _restart_sparks() -> void:
	var sparks := _get_sparks()
	if sparks == null:
		return
	sparks.restart()
	sparks.emitting = true


func _get_sparks() -> GPUParticles3D:
	if sparks_path == NodePath():
		return null
	return get_node_or_null(sparks_path) as GPUParticles3D
