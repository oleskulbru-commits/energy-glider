extends SceneTree

const VfxFlipbookScript = preload("res://scripts/vfx/vfx_flipbook.gd")
const AerialExplosionVfxScript = preload("res://scripts/vfx/aerial_explosion_vfx.gd")
const SandParticleVfxScript = preload("res://scripts/vfx/sand_particle_vfx.gd")
const DefaultPreset = preload("res://assets/vfx/explosions/presets/aerial_explode_1.tres")
const DroneExplosionPreset = preload("res://assets/vfx/explosions/presets/aerial_explode_drone.tres")
const ExplosionShaderPath := "res://assets/vfx/shaders/aerial_explosion.gdshader"


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
		vfx_source.find("_billboard_mesh") != -1,
		"Aerial explosion VFX should billboard toward the camera"
	)
	_fail_unless(
		vfx_source.find("normal_prefix") == -1,
		"Aerial explosion VFX should not load normal flipbook frames"
	)
	_fail_unless(
		vfx_source.find("_maybe_spawn_ground_sand") != -1,
		"Aerial explosion VFX should spawn ground sand when near terrain"
	)
	var sand_before_configure := vfx_source.find("_maybe_spawn_ground_sand")
	var configure_call := vfx_source.find("fx.configure")
	_fail_unless(
		sand_before_configure != -1
		and configure_call != -1
		and sand_before_configure < configure_call,
		"Ground sand should spawn before explosion configure to avoid late puff"
	)
	_fail_unless(
		DefaultPreset.ground_sand_burst == AerialExplosionPreset.GroundSandBurst.EXPLOSION,
		"Default preset should use instant explosion sand burst"
	)
	_fail_unless(DefaultPreset.spawn_ground_sand, "Default preset should enable ground sand bursts")
	_fail_unless(
		DefaultPreset.ground_sand_max_clearance_m > 0.0,
		"Default preset should define ground sand clearance"
	)

	var drone_rocket_source := FileAccess.get_file_as_string("res://scripts/enemies/drone_rocket.gd")
	_fail_unless(
		drone_rocket_source.find("AerialExplosionVfxScript.spawn") != -1,
		"DroneRocket should spawn aerial explosion VFX"
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
	var fx := AerialExplosionVfxScript.spawn(self, Vector3.ZERO, DefaultPreset)
	_fail_unless(fx != null, "AerialExplosionVfx.spawn should create an instance")
	await process_frame
	_fail_unless(is_instance_valid(fx), "Spawned aerial explosion should stay valid one frame")
	fx.queue_free()

	var high_clearance := AerialExplosionVfxScript.ground_clearance_m(Vector3(0.0, 50.0, 0.0), null, self)
	_fail_unless(
		high_clearance == INF or high_clearance > DefaultPreset.ground_sand_max_clearance_m,
		"Ground clearance helper should report far explosions as above sand threshold"
	)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
