extends SceneTree

const SwarmPillScene := preload("res://scenes/enemies/crawler/swarm_pill.tscn")
const ChargerPillScene := preload("res://scenes/enemies/crawler/charger_pill.tscn")
const TerrainManagerScript := preload("res://scripts/terrain/terrain_manager.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")
const CrawlerSandFootstepsScript := preload("res://scripts/enemies/crawler_sand_footsteps.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_crawler_sand_wiring()
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

	SandParticleVfxScript.spawn_burst(
		self,
		pill.global_position,
		terrain,
		pill.get_walk_dust_preset(),
		pill.get_sand_burst_scale_mult()
	)
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

	_fail_unless(
		pill.get_walk_dust_preset() == SandParticleVfxScript.BurstPreset.HEAVY,
		"SwarmPill walk dust should use HEAVY preset"
	)
	_fail_unless(
		is_equal_approx(pill.get_sand_burst_scale_mult(), 1.0),
		"SwarmPill sand scale mult should be 1.0"
	)

	var charger: ChargerPill = ChargerPillScene.instantiate() as ChargerPill
	root.add_child(charger)
	_fail_unless(
		charger.get_walk_dust_preset() == SandParticleVfxScript.BurstPreset.MG,
		"ChargerPill walk dust should use MG preset"
	)
	_fail_unless(
		is_equal_approx(charger.get_sand_burst_scale_mult(), 3.0),
		"ChargerPill sand scale mult should match visual scale"
	)
	var dig := charger.get_node_or_null("Visual/DigDustAnchor") as Node3D
	_fail_unless(dig != null, "Charger should expose DigDustAnchor")
	_fail_unless(
		dig.position.length() > 0.08,
		"Charger sand anchors should scale with visual size"
	)

	print("Crawler spawn gate verification passed.")
	quit(0)


func _verify_crawler_sand_wiring() -> void:
	var dust_source := FileAccess.get_file_as_string("res://scripts/enemies/sand_impact_dust.gd")
	_fail_unless(
		dust_source.find("scale_mult") != -1,
		"SandImpactDust.spawn should accept scale_mult"
	)
	_fail_unless(
		dust_source.find("shake_strength") != -1,
		"SandImpactDust.spawn should accept optional camera shake"
	)

	var anim_source := FileAccess.get_file_as_string(
		"res://scripts/enemies/crawler_anim_controller.gd"
	)
	_fail_unless(
		anim_source.find("get_climb_dust_preset") != -1,
		"CrawlerAnimController should read climb preset from host"
	)
	_fail_unless(
		anim_source.find("get_sand_burst_scale_mult") != -1,
		"CrawlerAnimController should read sand scale from host"
	)

	var footsteps_source := FileAccess.get_file_as_string(
		"res://scripts/enemies/crawler_sand_footsteps.gd"
	)
	_fail_unless(
		footsteps_source.find("get_walk_dust_preset") != -1,
		"CrawlerSandFootsteps should read walk preset from host"
	)
	_fail_unless(
		footsteps_source.find("BurstPreset.LIGHT") == -1,
		"CrawlerSandFootsteps should not hardcode LIGHT preset"
	)

	var swarm_source := FileAccess.get_file_as_string("res://scripts/enemies/swarm_pill.gd")
	_fail_unless(
		swarm_source.find("BurstPreset.HEAVY") != -1,
		"SwarmPill should use HEAVY for walk dust"
	)

	var charger_source := FileAccess.get_file_as_string("res://scripts/enemies/charger_pill.gd")
	_fail_unless(
		charger_source.find("_spawn_charge_dust") != -1,
		"ChargerPill should spawn charge dust while aggro'd"
	)
	_fail_unless(
		charger_source.find("BurstPreset.MG") != -1,
		"ChargerPill should use MG sand preset"
	)
	_fail_unless(
		charger_source.find("get_charge_dust_shake_strength") != -1,
		"ChargerPill should define charge dust camera shake"
	)

	var shake_source := FileAccess.get_file_as_string("res://scripts/player/camera_impact_shake.gd")
	_fail_unless(
		shake_source.find("compute_trauma") != -1,
		"CameraImpactShake should compute proximity trauma"
	)
	var blast_source := FileAccess.get_file_as_string("res://scripts/enemies/drone_ground_blast.gd")
	_fail_unless(
		blast_source.find("CameraImpactShakeScript.request") != -1,
		"DroneGroundBlast should request camera shake"
	)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
