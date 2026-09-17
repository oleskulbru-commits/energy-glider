extends SceneTree

const LaserDroneSkinScene := preload("res://scenes/enemies/laser_drone_skin.tscn")
const MissileDroneSkinScene := preload("res://scenes/enemies/missile_drone_skin.tscn")
const GunDroneSkinScene := preload("res://scenes/enemies/gun_drone_skin.tscn")
const DroneSkinPreviewScene := preload("res://scenes/test/drone_skin_preview.tscn")
const LensFlareTexture := preload("res://assets/vfx/effect_textures/lens_flare_2.png")
const DroneTypeFlareScript := preload("res://scripts/vfx/drone_type_flare.gd")

const STREAK_COLOR_RED := Color(1.6, 0.21, 0.064, 1)
const STREAK_COLOR_BLUE := Color(0.45483235, 0.7983809, 1.5999943, 1)
const STREAK_COLOR_YELLOW := Color(1.6, 1.232, 0.24, 1)

const LIGHT_RED := Color(1.6, 0.21, 0.064, 1)
const LIGHT_BLUE := Color(0.455, 0.798, 1.6, 1)
const LIGHT_YELLOW := Color(1.6, 1.232, 0.24, 1)

const THRUSTER_STREAK_NAMES := ["Streak", "Streak2", "Streak3", "Streak4", "Streak5"]
const HOVER_STREAK_NAMES := ["Streak", "Streak2", "Streak3", "Streak4"]

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_gun_muzzle_on_skin()
	if _failed:
		return
	await _verify_looping_flash_skips_restart()
	if _failed:
		return
	await _verify_tracer_size_reference()
	if _failed:
		return
	await _verify_mg_sand_burst()
	if _failed:
		return
	await _verify_death_sand_burst()
	if _failed:
		return
	await _verify_type_flare_range_fade()
	if _failed:
		return
	await _verify_skin(
		"gun",
		GunDroneSkinScene,
		STREAK_COLOR_YELLOW,
		LIGHT_YELLOW,
		"res://assets/3dmodels/enemies/drones/drone_machinegun_module_v001.glb"
	)
	if _failed:
		return
	print("Gun muzzle flash verification passed.")
	await _verify_skin(
		"laser",
		LaserDroneSkinScene,
		STREAK_COLOR_RED,
		LIGHT_RED,
		"res://assets/3dmodels/enemies/drones/drone_laser_module_v001.glb"
	)
	if _failed:
		return
	await _verify_skin(
		"missile",
		MissileDroneSkinScene,
		STREAK_COLOR_BLUE,
		LIGHT_BLUE,
		"res://assets/3dmodels/enemies/drones/drone_rocket_module_v001.glb"
	)
	if _failed:
		return
	await _verify_skin_preview_flares()
	if _failed:
		return
	print("Drone thruster color verification passed.")
	quit(0)


func _verify_skin(
	label: String,
	scene: PackedScene,
	streak_color: Color,
	light_color: Color,
	weapon_module_path: String
) -> void:
	var skin: Node3D = scene.instantiate() as Node3D
	root.add_child(skin)
	await process_frame

	var weapon := skin.get_node_or_null("Body/CSGCylinder3D/Weapon_Pivot/WeaponModule") as Node3D
	_fail_unless(weapon != null, "%s skin missing Body/CSGCylinder3D/Weapon_Pivot/WeaponModule" % label)
	if weapon == null:
		return
	_fail_unless(
		weapon.scene_file_path == weapon_module_path,
		"%s WeaponModule should instance %s (got %s)"
		% [label, weapon_module_path, weapon.scene_file_path]
	)

	var thruster_root := skin.get_node_or_null("Body/Body/Rebel_Drone/ThrusterStreaks") as Node3D
	_fail_unless(thruster_root != null, "%s skin missing ThrusterStreaks group" % label)
	for streak_name in THRUSTER_STREAK_NAMES:
		_assert_streak_color(label, thruster_root, streak_name, streak_color)

	var hover_root := skin.get_node_or_null("Body/Body/Rebel_Drone/HoverStreaks") as Node3D
	_fail_unless(hover_root != null, "%s skin missing HoverStreaks group" % label)
	var hover_color := Color(
		streak_color.r,
		streak_color.g,
		streak_color.b,
		streak_color.a * DroneStreakVfx.HOVER_BRIGHTNESS_MULT
	)
	for streak_name in HOVER_STREAK_NAMES:
		_assert_streak_color(label, hover_root, streak_name, hover_color)

	var omni := skin.get_node_or_null("Body/Body/OmniLight3D") as OmniLight3D
	_fail_unless(omni != null, "%s skin missing Body/Body/OmniLight3D" % label)
	_fail_unless(
		omni.light_color.is_equal_approx(light_color),
		"%s OmniLight3D color mismatch (got %s, expected %s)"
		% [label, omni.light_color, light_color]
	)

	var omni2 := skin.get_node_or_null("Body/Body/OmniLight3D2") as OmniLight3D
	_fail_unless(omni2 != null, "%s skin missing Body/Body/OmniLight3D2" % label)
	_fail_unless(
		omni2.light_color.is_equal_approx(light_color),
		"%s OmniLight3D2 color mismatch (got %s, expected %s)"
		% [label, omni2.light_color, light_color]
	)
	_fail_unless(
		is_equal_approx(omni2.light_energy, 0.5),
		"%s OmniLight3D2 energy should stay 0.5 (got %s)"
		% [label, omni2.light_energy]
	)

	var spot := skin.get_node_or_null("Body/SpotLight3D") as SpotLight3D
	_fail_unless(spot != null, "%s skin missing Body/SpotLight3D" % label)
	_fail_unless(
		spot.light_color.is_equal_approx(light_color),
		"%s SpotLight3D color mismatch (got %s, expected %s)"
		% [label, spot.light_color, light_color]
	)

	_verify_type_flare(label, skin, light_color)

	if label == "gun":
		_verify_gun_muzzle_flash(skin)

	skin.free()


func _verify_type_flare(label: String, skin: Node3D, flare_color: Color) -> void:
	var type_flare := skin.get_node_or_null("Body/TypeFlare")
	_fail_unless(type_flare != null, "%s skin missing Body/TypeFlare" % label)
	_fail_unless(
		type_flare.get_script() == DroneTypeFlareScript,
		"%s Body/TypeFlare should use drone_type_flare.gd" % label
	)
	if type_flare == null:
		return
	_fail_unless(
		type_flare.get_flare_color().is_equal_approx(flare_color),
		"%s TypeFlare color mismatch (got %s, expected %s)"
		% [label, type_flare.get_flare_color(), flare_color]
	)
	var core := type_flare.find_child("CoreFlare", true, false) as MeshInstance3D
	_fail_unless(core != null, "%s TypeFlare missing CoreFlare quad" % label)
	if core == null or not core.mesh is QuadMesh:
		return
	var mat := (core.mesh as QuadMesh).material as StandardMaterial3D
	_fail_unless(mat != null, "%s TypeFlare core should use StandardMaterial3D" % label)
	if mat == null:
		return
	_fail_unless(
		mat.albedo_texture == LensFlareTexture,
		"%s TypeFlare should use lens_flare_2.png (got %s)"
		% [label, mat.albedo_texture]
	)


func _verify_skin_preview_flares() -> void:
	var preview: Node3D = DroneSkinPreviewScene.instantiate() as Node3D
	root.add_child(preview)
	await process_frame
	var laser_skin := preview.get_node_or_null("LaserDroneSkin") as Node3D
	var missile_skin := preview.get_node_or_null("MissileDroneSkin") as Node3D
	var gun_skin := preview.get_node_or_null("GunDroneSkin") as Node3D
	_fail_unless(laser_skin != null, "drone_skin_preview missing LaserDroneSkin")
	_fail_unless(missile_skin != null, "drone_skin_preview missing MissileDroneSkin")
	_fail_unless(gun_skin != null, "drone_skin_preview missing GunDroneSkin")
	if laser_skin != null:
		_verify_type_flare("preview laser", laser_skin, LIGHT_RED)
	if missile_skin != null:
		_verify_type_flare("preview missile", missile_skin, LIGHT_BLUE)
	if gun_skin != null:
		_verify_type_flare("preview gun", gun_skin, LIGHT_YELLOW)
	preview.free()


func _verify_gun_muzzle_on_skin() -> void:
	var skin: Node3D = GunDroneSkinScene.instantiate() as Node3D
	root.add_child(skin)
	await process_frame
	_verify_gun_muzzle_flash(skin)
	skin.free()


func _verify_gun_muzzle_flash(skin: Node3D) -> void:
	var barrel := skin.find_child("GunBarrel", true, false) as Node3D
	_fail_unless(barrel != null, "gun skin missing GunBarrel")
	if barrel == null:
		return
	var flash := barrel.get_node_or_null("MuzzleFlash") as Node3D
	_fail_unless(flash != null, "GunBarrel should instance MuzzleFlash")
	if flash == null:
		return
	_fail_unless(
		flash.scene_file_path == "res://scenes/effects/muzzle_flash.tscn",
		"GunBarrel MuzzleFlash should instance res://scenes/effects/muzzle_flash.tscn (got %s)"
		% flash.scene_file_path
	)
	var has_gpu := false
	for node in flash.find_children("*", "GPUParticles3D", true, false):
		if node is GPUParticles3D:
			has_gpu = true
			break
	_fail_unless(has_gpu, "MuzzleFlash should contain a GPUParticles3D")
	for node in flash.find_children("*", "GPUParticles3D", true, false):
		var particles := node as GPUParticles3D
		if particles == null:
			continue
		_fail_unless(
			particles.local_coords,
			"%s should use local_coords so the flash follows the barrel" % particles.name
		)
	_verify_tracer_size_reference_on_skin(skin)


func _verify_tracer_size_reference_on_skin(skin: Node3D) -> void:
	var ref := skin.find_child("TracerSizeReference", true, false) as MeshInstance3D
	_fail_unless(ref != null, "gun skin missing TracerSizeReference")
	if ref == null:
		return
	_fail_unless(ref.mesh is CapsuleMesh, "TracerSizeReference should use CapsuleMesh")
	var barrel := skin.find_child("GunBarrel", true, false) as Node3D
	_fail_unless(barrel != null, "gun skin missing GunBarrel for tracer spawn")
	if barrel == null:
		return
	_verify_tracer_spawn_basis(barrel, ref)


func _verify_tracer_spawn_basis(barrel: Node3D, ref: MeshInstance3D) -> void:
	var aim_dir := Vector3(1.0, -1.2, 0.0).normalized()
	var round := DroneMgRound.new()
	root.add_child(round)
	round.configure(aim_dir, null, DroneMgRound.SPEED_MPS, barrel, ref)
	_fail_unless(
		round.global_position.is_equal_approx(barrel.global_position),
		"tracer spawn position should match GunBarrel (got %s, expected %s)"
		% [round.global_position, barrel.global_position]
	)
	var flight_axis := -round.global_transform.basis.z
	_fail_unless(
		flight_axis.dot(aim_dir) > 0.99,
		"tracer should align to flight direction (dot=%s, aim=%s, axis=%s)"
		% [flight_axis.dot(aim_dir), aim_dir, flight_axis]
	)
	var tracer_mesh := round.get_node_or_null("Tracer") as MeshInstance3D
	_fail_unless(tracer_mesh != null, "DroneMgRound should have Tracer child")
	if tracer_mesh != null:
		_fail_unless(tracer_mesh.mesh is CapsuleMesh, "Tracer should use CapsuleMesh")
		var ref_capsule := ref.mesh as CapsuleMesh
		var tracer_capsule := tracer_mesh.mesh as CapsuleMesh
		_fail_unless(
			is_equal_approx(tracer_capsule.radius, ref_capsule.radius),
			"tracer radius should match reference mesh (got %s, expected %s)"
			% [tracer_capsule.radius, ref_capsule.radius]
		)
		_fail_unless(
			is_equal_approx(tracer_capsule.height, ref_capsule.height),
			"tracer height should match reference mesh (got %s, expected %s)"
			% [tracer_capsule.height, ref_capsule.height]
		)
		var capsule_axis_fix := Transform3D(
			Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0)),
			Vector3.ZERO
		)
		_fail_unless(
			tracer_mesh.transform.is_equal_approx(capsule_axis_fix),
			"Tracer mesh should rotate capsule Y onto flight axis"
		)
	round.free()


func _verify_tracer_size_reference() -> void:
	var mg_source := FileAccess.get_file_as_string(
		"res://scripts/enemies/machine_gun_drone.gd"
	)
	_fail_unless(
		mg_source.find("TRACER_MUZZLE_OFFSET") == -1,
		"MachineGunDrone should spawn tracers at GunBarrel without a muzzle offset constant"
	)
	_fail_unless(
		mg_source.find("_tracer_size_ref") != -1,
		"MachineGunDrone should pass live TracerSizeReference into DroneMgRound.fire"
	)
	var skin: Node3D = GunDroneSkinScene.instantiate() as Node3D
	skin.scale = Vector3.ONE * CombatDrone.DRONE_SIZE_MULT
	root.add_child(skin)
	await process_frame
	var ref := skin.find_child("TracerSizeReference", true, false) as MeshInstance3D
	var barrel := skin.find_child("GunBarrel", true, false) as Node3D
	_fail_unless(ref != null, "scaled gun skin missing TracerSizeReference")
	_fail_unless(barrel != null, "scaled gun skin missing GunBarrel")
	if ref != null and barrel != null:
		_verify_tracer_spawn_basis(barrel, ref)
	skin.free()


func _verify_mg_sand_burst() -> void:
	var mg_round_source := FileAccess.get_file_as_string(
		"res://scripts/enemies/drone_mg_round.gd"
	)
	_fail_unless(
		mg_round_source.find("BurstPreset.MG") != -1,
		"DroneMgRound should spawn sand impacts with BurstPreset.MG"
	)
	_fail_unless(
		SandParticleVfx.burst_scene(SandParticleVfx.BurstPreset.MG).resource_path
		== "res://scenes/effects/sand_burst_mg_gpu.tscn",
		"MG burst preset should use sand_burst_mg_gpu.tscn"
	)
	var burst_root: Node = SandParticleVfx.burst_scene(
		SandParticleVfx.BurstPreset.MG
	).instantiate()
	root.add_child(burst_root)
	await process_frame
	var burst := burst_root.get_node_or_null("SandBurst") as GPUParticles3D
	_fail_unless(burst != null, "MG sand burst scene should expose SandBurst GPUParticles3D")
	if burst != null and burst.process_material is ParticleProcessMaterial:
		var mat := burst.process_material as ParticleProcessMaterial
		_fail_unless(
			mat.scale_min >= 0.69,
			"MG sand burst scale_min should be at least 0.7 (got %s)" % mat.scale_min
		)
		_fail_unless(
			mat.scale_max >= 1.29,
			"MG sand burst scale_max should be at least 1.3 (got %s)" % mat.scale_max
		)
	burst_root.free()


func _verify_death_sand_burst() -> void:
	var combat_drone_source := FileAccess.get_file_as_string(
		"res://scripts/enemies/combat_drone.gd"
	)
	_fail_unless(
		combat_drone_source.find("spawn_death_if_near_ground") == -1,
		"CombatDrone should not spawn sand at kill time"
	)
	var swarm_pill_source := FileAccess.get_file_as_string(
		"res://scripts/enemies/swarm_pill.gd"
	)
	_fail_unless(
		swarm_pill_source.find("spawn_death_if_near_ground") == -1,
		"SwarmPill should not spawn sand at kill time"
	)
	var drone_burst_source := FileAccess.get_file_as_string(
		"res://scripts/enemies/drone_death_burst.gd"
	)
	_fail_unless(
		drone_burst_source.find("BurstPreset.DEATH") != -1,
		"DroneDeathBurst should pass BurstPreset.DEATH to debris sand on landing"
	)
	var debris_sand_source := FileAccess.get_file_as_string(
		"res://scripts/enemies/crawler_debris_sand.gd"
	)
	_fail_unless(
		debris_sand_source.find("landing_preset") != -1,
		"CrawlerDebrisSand should support landing_preset for first ground contact"
	)
	_fail_unless(
		debris_sand_source.find("BurstPreset.MG") != -1,
		"CrawlerDebrisSand should spawn bounce sand with BurstPreset.MG"
	)
	_fail_unless(
		SandParticleVfx.burst_scene(SandParticleVfx.BurstPreset.DEATH).resource_path
		== "res://scenes/effects/sand_burst_death_gpu.tscn",
		"DEATH burst preset should use sand_burst_death_gpu.tscn"
	)
	var burst_root: Node = SandParticleVfx.burst_scene(
		SandParticleVfx.BurstPreset.DEATH
	).instantiate()
	root.add_child(burst_root)
	await process_frame
	var burst := burst_root.get_node_or_null("SandBurst") as GPUParticles3D
	_fail_unless(burst != null, "DEATH sand burst scene should expose SandBurst GPUParticles3D")
	if burst != null and burst.process_material is ParticleProcessMaterial:
		var mat := burst.process_material as ParticleProcessMaterial
		_fail_unless(
			mat.scale_min >= 0.99,
			"DEATH sand burst scale_min should be at least 1.0 (got %s)" % mat.scale_min
		)
		_fail_unless(
			mat.scale_max >= 1.99,
			"DEATH sand burst scale_max should be at least 2.0 (got %s)" % mat.scale_max
		)
	burst_root.free()


func _verify_type_flare_range_fade() -> void:
	var flare_source := FileAccess.get_file_as_string(
		"res://scripts/vfx/drone_type_flare.gd"
	)
	_fail_unless(
		flare_source.find("near_glint_strength") != -1,
		"DroneTypeFlare should expose near_glint_strength for close-range dimming"
	)
	_fail_unless(
		flare_source.find("no_depth_test = true") == -1,
		"DroneTypeFlare should use depth testing so the drone body can occlude the flare"
	)
	_fail_unless(
		flare_source.find("_presentation_strength") != -1,
		"DroneTypeFlare should combine range and proximity fade into presentation strength"
	)
	var type_flare := DroneTypeFlareScript.new()
	_fail_unless(
		is_equal_approx(type_flare.near_glint_strength, 0.12),
		"DroneTypeFlare near_glint_strength default should be 0.12 (got %s)"
		% type_flare.near_glint_strength
	)
	_fail_unless(
		is_equal_approx(type_flare._compute_range_visibility(type_flare.near_full_fade_m), 0.12),
		"TypeFlare should reach near glint strength at near_full_fade_m"
	)
	_fail_unless(
		is_equal_approx(type_flare._compute_range_visibility(type_flare.far_full_strength_m), 1.0),
		"TypeFlare should reach full strength at far_full_strength_m"
	)
	type_flare.free()


func _verify_looping_flash_skips_restart() -> void:
	var looping := GPUParticles3D.new()
	looping.one_shot = false
	_fail_unless(
		not MuzzleFlash.should_restart(looping),
		"flash() should not restart looping GPUParticles3D"
	)
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	_fail_unless(
		MuzzleFlash.should_restart(burst),
		"flash() should restart one-shot GPUParticles3D"
	)
	var flash := MuzzleFlash.new()
	looping.emitting = false
	flash.add_child(looping)
	burst.emitting = false
	flash.add_child(burst)
	root.add_child(flash)
	await process_frame
	flash.flash()
	_fail_unless(looping.emitting, "looping muzzle particles should emit on flash")
	_fail_unless(burst.emitting, "one-shot muzzle particles should emit on flash")
	_fail_unless(looping.local_coords, "MuzzleFlash should force local_coords on GPUParticles3D")
	flash.free()


func _assert_streak_color(
	label: String,
	group: Node3D,
	streak_name: String,
	streak_color: Color
) -> void:
	var streak := group.get_node_or_null(streak_name) as MeshInstance3D
	_fail_unless(streak != null, "%s skin missing %s/%s" % [label, group.name, streak_name])
	var mat := streak.material_override
	_fail_unless(mat != null, "%s %s should have material_override" % [label, streak_name])
	_fail_unless(mat is ShaderMaterial, "%s %s should use ShaderMaterial" % [label, streak_name])
	var color: Variant = (mat as ShaderMaterial).get_shader_parameter("ColorParameter")
	_fail_unless(color is Color, "%s %s should expose ColorParameter" % [label, streak_name])
	_fail_unless(
		(color as Color).is_equal_approx(streak_color),
		"%s %s ColorParameter mismatch (got %s, expected %s)"
		% [label, streak_name, color, streak_color]
	)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
	quit(1)
