class_name MuzzleFlash
extends Node3D

## Drives GPUParticles3D under this node. Tune emitters in the scene.


func _ready() -> void:
	for particles in _gpu_particles():
		particles.local_coords = true


func flash() -> void:
	for particles in _gpu_particles():
		if should_restart(particles):
			particles.restart()
		particles.emitting = true


func stop() -> void:
	for particles in _gpu_particles():
		particles.emitting = false


static func should_restart(particles: GPUParticles3D) -> bool:
	return particles != null and particles.one_shot


func _gpu_particles() -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	for node in find_children("*", "GPUParticles3D", true, false):
		var particles := node as GPUParticles3D
		if particles != null:
			out.append(particles)
	return out
