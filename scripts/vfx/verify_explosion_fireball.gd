extends SceneTree

const ExplosionFireballVfxScript := preload("res://scripts/vfx/explosion_fireball_vfx.gd")
const FireShader := preload("res://assets/vfx/shaders/explosion_fireball.gdshader")
const SmokeShader := preload("res://assets/vfx/shaders/explosion_smoke_noise.gdshader")
const FireCoreMaterial := preload("res://assets/materials/vfx/explosion_fire_core.tres")
const SmokeMaterial := preload("res://assets/materials/vfx/explosion_smoke_particle.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_assets()
	_verify_spawn()
	print("Explosion fireball verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _verify_assets() -> void:
	_fail_unless(FireShader != null, "Missing explosion_fireball.gdshader")
	_fail_unless(SmokeShader != null, "Missing explosion_smoke_noise.gdshader")
	_fail_unless(FireCoreMaterial.shader == FireShader, "Fire core material should use explosion_fireball shader")
	_fail_unless(SmokeMaterial.shader == SmokeShader, "Smoke material should use explosion_smoke_noise shader")
	var fire_source := FileAccess.get_file_as_string(FireShader.resource_path)
	_fail_unless(
		fire_source.find("smoothstep(mask_threshold") != -1,
		"Fire shader should luminance-key grayscale-on-black noise"
	)
	var smoke_source := FileAccess.get_file_as_string(SmokeShader.resource_path)
	_fail_unless(
		smoke_source.find("smoothstep(mask_threshold") != -1,
		"Smoke shader should luminance-key grayscale-on-black noise"
	)
	var vfx_source := FileAccess.get_file_as_string("res://scripts/vfx/explosion_fireball_vfx.gd")
	_fail_unless(
		vfx_source.find("explosion_fire_core.tres") != -1,
		"Fireball VFX should reference fire core material"
	)
	_fail_unless(
		vfx_source.find("explosion_smoke_particle.tres") != -1,
		"Fireball VFX should reference smoke puff material"
	)
	var aerial_source := FileAccess.get_file_as_string("res://scripts/vfx/aerial_explosion_vfx.gd")
	_fail_unless(
		aerial_source.find("_maybe_spawn_fireball_vfx") != -1,
		"AerialExplosionVfx should optionally spawn fireball VFX"
	)


func _verify_spawn() -> void:
	var fx := ExplosionFireballVfxScript.spawn(self, Vector3.ZERO, 1.0, 12.0)
	_fail_unless(fx != null, "ExplosionFireballVfx.spawn should create an instance")
	_fail_unless(fx.get_child_count() >= 4, "Fireball should include shells, smoke, and light")
	var smoke := fx.get_node_or_null("SmokeBurst") as GPUParticles3D
	_fail_unless(smoke != null, "Fireball should spawn SmokeBurst GPUParticles3D")
	_fail_unless(fx.get_node_or_null("FireCore") != null, "Fireball should spawn FireCore shell")
	_fail_unless(fx.get_node_or_null("FireMid") != null, "Fireball should spawn FireMid shell")
	_fail_unless(fx.get_node_or_null("FireOuter") != null, "Fireball should spawn FireOuter shell")
	fx.queue_free()
