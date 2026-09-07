extends SceneTree

const VfxFlipbookScript = preload("res://scripts/vfx/vfx_flipbook.gd")
const AerialExplosionPresetScript = preload("res://scripts/vfx/aerial_explosion_preset.gd")
const AerialExplosionVfxScript = preload("res://scripts/vfx/aerial_explosion_vfx.gd")
const DefaultPreset = preload("res://assets/vfx/explosions/presets/aerial_explode_1.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_preset()
	await _verify_spawn()
	print("Aerial explosion verification passed.")
	quit(0)


func _verify_preset() -> void:
	_fail_unless(DefaultPreset != null, "Default aerial explosion preset should load")
	_fail_unless(DefaultPreset.frame_count == 25, "Preset should define 25 frames")
	var colors := VfxFlipbookScript.load_texture_sequence(
		DefaultPreset.texture_dir,
		DefaultPreset.color_prefix,
		DefaultPreset.frame_count,
		DefaultPreset.color_frame_offset
	)
	_fail_unless(colors.size() == 25, "Color sequence should load 25 frames (got %d)" % colors.size())
	var normals := VfxFlipbookScript.load_texture_sequence(
		DefaultPreset.texture_dir,
		DefaultPreset.normal_prefix,
		DefaultPreset.frame_count,
		DefaultPreset.normal_frame_offset
	)
	_fail_unless(normals.size() == 25, "Normal sequence should load 25 frames (got %d)" % normals.size())
	_fail_unless(
		DefaultPreset.material != null,
		"Default preset should reference an editable aerial explosion material"
	)

	var rocket_source := FileAccess.get_file_as_string("res://scripts/enemies/drone_rocket.gd")
	_fail_unless(
		rocket_source.find("AerialExplosionVfxScript.spawn") != -1,
		"DroneRocket should spawn aerial explosion VFX"
	)
	var death_source := FileAccess.get_file_as_string("res://scripts/enemies/drone_death_burst.gd")
	_fail_unless(
		death_source.find("AerialExplosionVfxScript.spawn") != -1,
		"DroneDeathBurst should spawn aerial explosion VFX"
	)
	var player_rocket_source := FileAccess.get_file_as_string("res://scripts/weapons/rocket_missile.gd")
	_fail_unless(
		player_rocket_source.find("AerialExplosionVfxScript.spawn") != -1,
		"Player RocketMissile should spawn aerial explosion VFX"
	)
	var shader_source := FileAccess.get_file_as_string("res://assets/vfx/shaders/aerial_explosion.gdshader")
	_fail_unless(
		shader_source.find("depth_tex") == -1,
		"Aerial explosion shader should not use depth textures"
	)
	_fail_unless(
		shader_source.find("filter_nearest") != -1,
		"Aerial explosion shader should use nearest texture filtering"
	)
	_fail_unless(
		shader_source.find("ALPHA = max(col.r") != -1,
		"Aerial explosion shader should drive additive alpha from color RGB"
	)
	_fail_unless(
		shader_source.find("color_tint") != -1,
		"Aerial explosion shader should expose color_tint for preset tuning"
	)

	var vfx_source := FileAccess.get_file_as_string("res://scripts/vfx/aerial_explosion_vfx.gd")
	_fail_unless(
		vfx_source.find("_preset.material.duplicate()") != -1,
		"Aerial explosion VFX should duplicate preset material so edits are respected"
	)


func _verify_spawn() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var fx := AerialExplosionVfxScript.spawn(self, Vector3.ZERO, DefaultPreset)
	_fail_unless(fx != null, "AerialExplosionVfx.spawn should create an instance")
	await process_frame
	_fail_unless(is_instance_valid(fx), "Spawned aerial explosion should stay valid one frame")
	fx.queue_free()


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
