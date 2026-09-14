extends SceneTree

const GroundReticleScript := preload("res://scripts/enemies/ground_reticle.gd")
const ReticleShader := preload("res://assets/vfx/shaders/ground_reticle.gdshader")
const ReticleMaterial := preload("res://assets/materials/vfx/ground_reticle_material.tres")
const StreakBlueMaterial := preload("res://assets/materials/enemies/rebel_drone_streak_blue.tres")
const FrameTexturePath := "res://assets/vfx/effect_textures/reticles/reticle_2_frame_.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_constants()
	_verify_material()
	await _verify_spawn()
	print("Ground reticle verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _verify_constants() -> void:
	_fail_unless(
		is_equal_approx(GroundReticleScript.LIFE_SEC, 1.5),
		"Ground reticle life should be 1.5 s (got %.3f)" % GroundReticleScript.LIFE_SEC
	)
	var source := FileAccess.get_file_as_string("res://scripts/enemies/ground_reticle.gd")
	_fail_unless(
		source.find("reticle_2_frame_.png") != -1,
		"Ground reticle should use static reticle_2_frame_.png"
	)
	_fail_unless(
		source.find("VfxFlipbookScript") == -1,
		"Ground reticle should no longer use flipbook loading"
	)
	_fail_unless(
		source.find("TorusMesh") == -1,
		"Ground reticle should no longer use procedural torus mesh"
	)


func _verify_material() -> void:
	_fail_unless(ReticleMaterial.shader == ReticleShader, "Ground reticle material should use ground_reticle shader")
	var frame_tex: Texture2D = ReticleMaterial.get_shader_parameter("frame_tex")
	_fail_unless(frame_tex != null, "Ground reticle material should define frame_tex")
	_fail_unless(
		frame_tex.resource_path == FrameTexturePath,
		"Ground reticle material should use reticle_2_frame_.png"
	)
	var streak_color: Color = StreakBlueMaterial.get_shader_parameter("ColorParameter")
	var reticle_tint_param = ReticleMaterial.get_shader_parameter("color_tint")
	var reticle_tint := Vector3.ZERO
	if reticle_tint_param is Color:
		reticle_tint = Vector3(reticle_tint_param.r, reticle_tint_param.g, reticle_tint_param.b)
	elif reticle_tint_param is Vector3:
		reticle_tint = reticle_tint_param
	_fail_unless(
		reticle_tint.is_equal_approx(Vector3(streak_color.r, streak_color.g, streak_color.b)),
		"Ground reticle tint should match missile streak blue"
	)
	var streak_glow: float = StreakBlueMaterial.get_shader_parameter("GlowStrength")
	var reticle_glow: float = ReticleMaterial.get_shader_parameter("glow_strength")
	_fail_unless(
		is_equal_approx(reticle_glow, streak_glow * GroundReticleScript.BRIGHTNESS_MULT),
		"Ground reticle glow should be 75%% of streak glow (got %.3f)" % reticle_glow
	)
	_fail_unless(
		is_equal_approx(float(ReticleMaterial.get_shader_parameter("alpha_scale")), 0.75),
		"Ground reticle alpha_scale should be 0.75"
	)
	_fail_unless(
		is_equal_approx(GroundReticleScript.QUAD_SIZE_M, 5.4),
		"Ground reticle quad should be 5.4 m"
	)
	var shader_source := FileAccess.get_file_as_string(ReticleShader.resource_path)
	_fail_unless(
		shader_source.find("smoothstep(char_threshold") != -1,
		"Ground reticle shader should luminance-key grayscale-on-black frames"
	)


func _verify_spawn() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var reticle: GroundReticle = GroundReticleScript.new()
	world.add_child(reticle)
	reticle.place(Vector3(0.0, 0.0, 0.0), 1.5, null)
	await create_timer(0.05).timeout
	_fail_unless(is_instance_valid(reticle), "Ground reticle should stay valid after spawn")
	var quad := reticle.get_node_or_null("ReticleQuad") as MeshInstance3D
	_fail_unless(quad != null, "Ground reticle should expose ReticleQuad mesh")
	_fail_unless(quad.mesh is QuadMesh, "Ground reticle should use a flat QuadMesh")
	var mat := (quad.mesh as QuadMesh).material as ShaderMaterial
	_fail_unless(mat != null, "Ground reticle quad should use ShaderMaterial")
	_fail_unless(mat.shader == ReticleShader, "Ground reticle quad should use ground_reticle shader")
	var frame_tex: Texture2D = mat.get_shader_parameter("frame_tex")
	_fail_unless(
		frame_tex != null and frame_tex.resource_path == FrameTexturePath,
		"Spawned ground reticle should bind reticle_2_frame_.png"
	)
	reticle.queue_free()
	world.queue_free()
