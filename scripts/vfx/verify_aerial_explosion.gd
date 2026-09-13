extends SceneTree

const VfxFlipbookScript = preload("res://scripts/vfx/vfx_flipbook.gd")
const AerialExplosionVfxScript = preload("res://scripts/vfx/aerial_explosion_vfx.gd")
const ExplosionSparkVfxScript = preload("res://scripts/vfx/explosion_spark_vfx.gd")
const SandParticleVfxScript = preload("res://scripts/vfx/sand_particle_vfx.gd")
const DefaultPreset = preload("res://assets/vfx/explosions/presets/aerial_explode_1.tres")
const DroneExplosionPreset = preload("res://assets/vfx/explosions/presets/aerial_explode_drone.tres")
const ExplosionShaderPath := "res://assets/vfx/shaders/aerial_explosion.gdshader"
const GroundBurnDecalVfxScript = preload("res://scripts/vfx/ground_burn_decal_vfx.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_preset()
	_verify_shader()
	await _verify_spawn()
	print("Aerial explosion verification passed.")
	quit(0)


func _verify_preset() -> void:
	_fail_unless(DefaultPreset != null, "Default aerial explosion preset should load")
	_fail_unless(DefaultPreset.frame_count == 47, "Player preset should define 47 frames")
	_fail_unless(
		DefaultPreset.color_prefix == "aerial_explode_2_v001_frame_",
		"Player preset should use aerial_explode_2_v001 flipbook"
	)
	_fail_unless(DefaultPreset.color_frame_offset == 1, "Player preset should start at frame 0001")
	_fail_unless(
		is_equal_approx(DefaultPreset.fps, 24.0),
		"Player preset should play at 24 fps (got %s)" % DefaultPreset.fps
	)
	var colors := VfxFlipbookScript.load_texture_sequence(
		DefaultPreset.texture_dir,
		DefaultPreset.color_prefix,
		DefaultPreset.frame_count,
		DefaultPreset.color_frame_offset
	)
	_fail_unless(colors.size() == 47, "Color sequence should load 47 frames (got %d)" % colors.size())
	var drone_colors := VfxFlipbookScript.load_texture_sequence(
		DroneExplosionPreset.texture_dir,
		DroneExplosionPreset.color_prefix,
		DroneExplosionPreset.frame_count,
		DroneExplosionPreset.color_frame_offset
	)
	_fail_unless(
		DroneExplosionPreset.color_prefix == "aerial_explode_3_v001_frame_",
		"Drone preset should stay on aerial_explode_3_v001 flipbook"
	)
	_fail_unless(drone_colors.size() == 75, "Drone color sequence should load 75 frames (got %d)" % drone_colors.size())
	_fail_unless(
		DefaultPreset.material != null,
		"Default preset should reference an editable aerial explosion material"
	)
	_fail_unless(
		DefaultPreset.material is ShaderMaterial,
		"Default preset material should be ShaderMaterial"
	)

	var player_rocket_source := FileAccess.get_file_as_string("res://scripts/weapons/rocket_missile.gd")
	_fail_unless(
		player_rocket_source.find("AerialExplosionVfxScript.spawn") != -1,
		"Player RocketMissile should spawn aerial explosion VFX"
	)
	_fail_unless(
		player_rocket_source.find("_dir") != -1
		and player_rocket_source.find("AerialExplosionVfxScript.spawn") != -1,
		"Player RocketMissile should pass travel direction into explosion spawn"
	)
	_fail_unless(
		player_rocket_source.find("AerialExplosionVfxScript.spawn") != -1
		and player_rocket_source.find("pill") != -1,
		"Player RocketMissile should pass hit body into explosion spawn for burn policy"
	)

	var vfx_source := FileAccess.get_file_as_string("res://scripts/vfx/aerial_explosion_vfx.gd")
	_fail_unless(
		vfx_source.find("duplicate_material") != -1,
		"Aerial explosion VFX should duplicate preset material so edits are respected"
	)
	_fail_unless(
		vfx_source.find("ShaderMaterial") != -1,
		"Aerial explosion VFX should use ShaderMaterial"
	)
	_fail_unless(
		vfx_source.find("_build_billboard_mesh") != -1,
		"Aerial explosion VFX should build a camera-facing billboard mesh"
	)
	_fail_unless(
		vfx_source.find("_billboard_mesh") != -1,
		"Aerial explosion VFX should billboard toward the camera"
	)
	_fail_unless(
		vfx_source.find("basis_for_impact_dir") == -1,
		"Aerial explosion flipbook should not rotate with impact direction"
	)
	_fail_unless(
		vfx_source.find("normal_prefix") == -1,
		"Aerial explosion VFX should not load normal flipbook frames"
	)
	_fail_unless(
		vfx_source.find("_maybe_spawn_ground_sand") != -1,
		"Aerial explosion VFX should spawn ground sand when near terrain"
	)
	_fail_unless(
		vfx_source.find("_maybe_spawn_ground_burn_decal") != -1,
		"Aerial explosion VFX should spawn ground burn decals when near terrain"
	)
	_fail_unless(
		vfx_source.find("should_spawn_ground_burn") != -1,
		"Aerial explosion VFX should centralize ground burn eligibility"
	)
	_fail_unless(DefaultPreset.spawn_ground_burn_decal, "Default preset should enable ground burn decals")
	_fail_unless(DroneExplosionPreset.spawn_ground_burn_decal, "Drone preset should enable ground burn decals")
	_fail_unless(
		DefaultPreset.ground_burn_albedo != null,
		"Default preset should reference burnt ground albedo"
	)
	var sand_before_configure := vfx_source.find("_maybe_spawn_ground_sand")
	var burn_before_configure := vfx_source.find("_maybe_spawn_ground_burn_decal")
	var configure_call := vfx_source.find("fx.configure")
	_fail_unless(
		sand_before_configure != -1
		and configure_call != -1
		and sand_before_configure < configure_call,
		"Ground sand should spawn before explosion configure to avoid late puff"
	)
	_fail_unless(
		burn_before_configure != -1
		and configure_call != -1
		and burn_before_configure < configure_call,
		"Ground burn decal should spawn before explosion configure"
	)
	_fail_unless(
		vfx_source.find("_maybe_spawn_impact_sparks") != -1,
		"Aerial explosion VFX should spawn impact sparks from preset"
	)
	var sparks_before_configure := vfx_source.find("_maybe_spawn_impact_sparks")
	_fail_unless(
		sparks_before_configure != -1
		and configure_call != -1
		and sparks_before_configure < configure_call,
		"Impact sparks should spawn before explosion configure"
	)
	_fail_unless(
		not DefaultPreset.spawn_ground_sand,
		"Player rocket preset should disable ground sand bursts"
	)
	_fail_unless(DefaultPreset.spawn_sparks, "Player preset should enable impact sparks")
	_fail_unless(DefaultPreset.spark_count > 0, "Player preset should define spark count")
	_fail_unless(DroneExplosionPreset.spawn_sparks, "Drone preset should enable impact sparks")
	_fail_unless(
		DroneExplosionPreset.spark_color.b > DroneExplosionPreset.spark_color.r,
		"Drone explosion sparks should read cooler than player sparks"
	)

	var drone_rocket_source := FileAccess.get_file_as_string("res://scripts/enemies/drone_rocket.gd")
	_fail_unless(
		drone_rocket_source.find("AerialExplosionVfxScript.spawn") != -1,
		"DroneRocket should spawn aerial explosion VFX"
	)
	_fail_unless(
		drone_rocket_source.find("_dir") != -1,
		"DroneRocket should pass travel direction into explosion spawn"
	)


func _verify_shader() -> void:
	var text := FileAccess.get_file_as_string(ExplosionShaderPath)
	_fail_unless(text.find("col.a") != -1, "Explosion shader should use PNG alpha (col.a)")
	_fail_unless(
		text.find("filter_nearest") != -1,
		"Explosion shader should sample flipbook with nearest filtering"
	)
	_fail_unless(
		text.find("ALPHA = max(col.r") == -1,
		"Explosion shader should not derive alpha from RGB brightness"
	)
	_fail_unless(
		text.find("smoothstep") != -1,
		"Explosion shader should gate emission to hot fire pixels"
	)
	_fail_unless(
		text.find("blend_mix") != -1,
		"Explosion shader should alpha-composite smoke with blend_mix"
	)
	_fail_unless(
		text.find("blend_add") == -1,
		"Explosion shader should not use additive blend (hides dark smoke)"
	)
	_fail_unless(text.find("smoke_tint") != -1, "Explosion shader should grade cold smoke pixels")
	_fail_unless(
		text.find("ALPHA = col.a * alpha_scale") != -1,
		"Explosion shader should use exported PNG alpha for opacity"
	)
	_fail_unless(
		text.find("bg_suppress") == -1,
		"Explosion shader should not plate-key transparent PNG flipbooks"
	)
	_fail_unless(
		text.find("proximity_fade_distance") != -1,
		"Explosion shader should support proximity fade like hover dust"
	)
	var material := DefaultPreset.material as ShaderMaterial
	_fail_unless(
		is_equal_approx(
			material.get_shader_parameter("proximity_fade_distance"),
			SandParticleVfxScript.PROXIMITY_FADE_DISTANCE
		),
		"Explosion editor material should keep base proximity fade distance (1.0)"
	)
	var player_fade := AerialExplosionVfxScript.proximity_fade_distance_for(DefaultPreset, 1.0)
	_fail_unless(
		is_equal_approx(player_fade, SandParticleVfxScript.PROXIMITY_FADE_DISTANCE),
		"Player explosion fade should match hover dust at reference size (got %.3f)" % player_fade
	)
	var drone_fade := AerialExplosionVfxScript.proximity_fade_distance_for(DroneExplosionPreset, 4.0)
	_fail_unless(
		drone_fade > SandParticleVfxScript.PROXIMITY_FADE_DISTANCE,
		"Drone missile explosion fade should scale up with world size (got %.3f)" % drone_fade
	)
	var spawned_mat := AerialExplosionVfxScript.duplicate_material(DefaultPreset, 1.0) as ShaderMaterial
	_fail_unless(
		is_equal_approx(
			spawned_mat.get_shader_parameter("emission_strength"),
			DefaultPreset.emission_strength
		),
		"Spawned explosion material should apply preset emission_strength"
	)


func _verify_spawn() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var fx := AerialExplosionVfxScript.spawn(self, Vector3.ZERO, DefaultPreset)
	_fail_unless(fx != null, "AerialExplosionVfx.spawn should create an instance")
	await process_frame
	_fail_unless(is_instance_valid(fx), "Spawned aerial explosion should stay valid one frame")
	var billboard := fx.get_node_or_null("ExplosionBillboard") as MeshInstance3D
	_fail_unless(billboard != null, "Spawned aerial explosion should use ExplosionBillboard mesh")
	_fail_unless(billboard.mesh is QuadMesh, "Aerial explosion mesh should be a QuadMesh")
	_fail_unless(billboard.visible, "Explosion billboard mesh should be visible")
	_fail_unless(
		fx.global_basis.is_equal_approx(Basis.IDENTITY),
		"Explosion root should stay world-aligned while the quad billboards"
	)
	var expected_scale := AerialExplosionVfxScript.mesh_uniform_scale_for(DefaultPreset, 1.0)
	_fail_unless(
		is_equal_approx(billboard.scale.x, expected_scale),
		"Explosion billboard scale should match world_scale (got %.3f, expected %.3f)"
		% [billboard.scale.x, expected_scale]
	)
	var directed := AerialExplosionVfxScript.spawn(
		self,
		Vector3(4.0, 0.0, 0.0),
		DefaultPreset,
		1.0,
		null,
		Vector3(1.0, 0.0, 0.0)
	)
	_fail_unless(directed != null, "Explosion spawn with impact direction should succeed")
	await process_frame
	_fail_unless(
		directed.global_basis.is_equal_approx(Basis.IDENTITY),
		"Impact direction should orient sparks only, not the flipbook root"
	)
	directed.queue_free()
	var spark_fx := ExplosionSparkVfxScript.spawn_from_preset(self, Vector3(2.0, 0.0, 0.0), DefaultPreset)
	_fail_unless(spark_fx != null, "ExplosionSparkVfx should spawn for enabled preset")
	await process_frame
	var spark_burst := spark_fx.get_node_or_null("ExplosionSparkBurst") as GPUParticles3D
	_fail_unless(spark_burst != null, "Explosion spark wrapper should contain GPUParticles3D burst")
	_fail_unless(
		spark_burst.amount == DefaultPreset.spark_count,
		"Explosion spark amount should match preset (got %d)" % spark_burst.amount
	)
	fx.queue_free()
	spark_fx.queue_free()

	var high_clearance := AerialExplosionVfxScript.ground_clearance_m(Vector3(0.0, 50.0, 0.0), null, self)
	_fail_unless(
		high_clearance == INF or high_clearance > DefaultPreset.ground_sand_max_clearance_m,
		"Ground clearance helper should report far explosions as above sand threshold"
	)
	_fail_unless(
		not AerialExplosionVfxScript.should_spawn_ground_burn(DefaultPreset, high_clearance),
		"High-air explosions should skip ground burn decals"
	)
	_fail_unless(
		AerialExplosionVfxScript.should_spawn_ground_burn(DefaultPreset, 0.5),
		"Near-ground explosions should qualify for burn decals"
	)
	var burn_count_before := _count_ground_burn_decals(world)
	var burn_decal := GroundBurnDecalVfxScript.spawn_from_preset(
		self,
		Vector3(2.0, 0.0, 0.0),
		DefaultPreset
	)
	_fail_unless(burn_decal != null, "Ground burn decal spawn should return an instance")
	await process_frame
	_fail_unless(
		_count_ground_burn_decals(world) > burn_count_before,
		"Ground burn decal spawn should create a GroundBurnDecal node"
	)
	var burn_mesh := burn_decal.get_node_or_null("GroundBurnMesh") as MeshInstance3D
	_fail_unless(burn_mesh != null, "Ground burn decal should include a GroundBurnMesh")
	_fail_unless(burn_mesh.mesh != null, "Ground burn decal should assign a mesh")


func _count_ground_burn_decals(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child.name == "GroundBurnDecal":
			count += 1
	return count


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
