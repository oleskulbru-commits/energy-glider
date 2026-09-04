extends SceneTree

const SwarmPillScene := preload("res://scenes/enemies/swarm_pill.tscn")
const TerrainManagerScript := preload("res://scripts/terrain/terrain_manager.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")
const CrawlerSandFootstepsScript := preload("res://scripts/enemies/crawler_sand_footsteps.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain: TerrainManager = TerrainManagerScript.new()
	root.add_child(terrain)

	var pill: SwarmPill = SwarmPillScene.instantiate() as SwarmPill
	root.add_child(pill)

	var target := Node3D.new()
	root.add_child(target)
	target.global_position = Vector3(10.0, 0.0, 0.0)

	pill.configure(terrain, target)

	await process_frame
	await process_frame

	var anim := pill.get_node_or_null("Visual/CrawlerAnimController") as CrawlerAnimController
	_fail_unless(anim != null, "Missing CrawlerAnimController on swarm pill")

	var footsteps := pill.get_node_or_null("Visual/CrawlerSandFootsteps") as CrawlerSandFootstepsScript
	_fail_unless(footsteps != null, "Missing CrawlerSandFootsteps on swarm pill")

	SandParticleVfxScript.spawn_burst(self, pill.global_position, terrain, SandParticleVfxScript.BurstPreset.LIGHT)
	await process_frame

	var player := pill.get_node_or_null("Visual/Model/AnimationPlayer") as AnimationPlayer
	_fail_unless(player != null, "Missing crawler AnimationPlayer")

	if player.has_animation("Crawler_ClimbUp"):
		_fail_unless(anim.is_spawn_active(), "Spawn gate should stay active while ClimbUp plays")
		var waited := 0.0
		while waited < 5.0 and anim.is_spawn_active():
			await create_timer(0.1).timeout
			waited += 0.1
		_fail_unless(not anim.is_spawn_active(), "Spawn gate should unlock after ClimbUp finishes")
	else:
		_fail_unless(not anim.is_spawn_active(), "Spawn gate should unlock immediately when ClimbUp is absent")

	_fail_unless(
		player.is_playing() and player.current_animation == &"Crawler_Forward",
		"Crawler should play Forward after spawn (got %s)" % player.current_animation
	)

	print("Crawler spawn gate verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
