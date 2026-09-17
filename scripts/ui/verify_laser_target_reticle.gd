extends SceneTree

const LaserTargetReticleUIScript := preload("res://scripts/ui/laser_target_reticle_ui.gd")
const LaserDroneTelegraphScript := preload("res://scripts/enemies/laser_drone_telegraph.gd")
const VfxFlipbookScript := preload("res://scripts/vfx/vfx_flipbook.gd")
const ReticleShader := preload("res://assets/vfx/shaders/hud_laser_reticle.gdshader")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var frame_count := LaserTargetReticleUIScript.FRAME_COUNT
	var frames := VfxFlipbookScript.load_texture_sequence(
		"res://assets/vfx/effect_textures/reticles/",
		"reticle_1_frame_",
		frame_count,
		LaserTargetReticleUIScript.FRAME_OFFSET
	)
	_fail_unless(
		frames.size() == frame_count,
		"Laser HUD reticle should load %d reticle_1 frames (got %d)" % [frame_count, frames.size()]
	)

	var source := FileAccess.get_file_as_string("res://scripts/ui/laser_target_reticle_ui.gd")
	_fail_unless(
		source.find("reticle_1_frame_") != -1,
		"LaserTargetReticleUI should reference reticle_1 flipbook"
	)
	_fail_unless(
		source.find("draw_texture_rect(") == -1,
		"LaserTargetReticleUI should draw flipbook via TextureRect, not draw_texture_rect"
	)
	_fail_unless(
		source.find("hud_laser_reticle.gdshader") != -1,
		"LaserTargetReticleUI should luminance-key flipbook frames with hud_laser_reticle shader"
	)
	_fail_unless(
		source.find("FLIPBOOK_PIXEL_SCALE") != -1,
		"LaserTargetReticleUI should upscale flipbook art by integer texel scale"
	)
	_fail_unless(
		source.find("TextureRect") != -1 and source.find("flipbook_draw_rect") != -1,
		"LaserTargetReticleUI should use a TextureRect flipbook with art-native draw rects"
	)
	_fail_unless(
		source.find("scale_at(") == -1,
		"LaserTargetReticleUI should not also shrink the flipbook draw rect during the shrink phase"
	)
	_fail_unless(
		source.find("TEXTURE_FILTER_NEAREST") != -1,
		"LaserTargetReticleUI should draw flipbook frames with nearest filtering"
	)
	_fail_unless(
		source.find("STRETCH_SCALE") != -1,
		"Laser HUD flipbook should scale art to fill the integer draw rect"
	)
	_fail_unless(
		source.find("GLOW_STRENGTH") != -1,
		"Laser HUD reticle should define glow strength for the tint shader"
	)
	_fail_unless(ReticleShader != null, "HUD laser reticle shader should load")
	var shader_source := FileAccess.get_file_as_string(
		"res://assets/vfx/shaders/hud_laser_reticle.gdshader"
	)
	_fail_unless(
		shader_source.find("blend_mix") != -1,
		"HUD laser reticle shader should use blend_mix for readable red on bright scenes"
	)
	_fail_unless(
		shader_source.find("smoothstep(char_threshold") != -1,
		"HUD laser reticle shader should soften luminance keying"
	)
	_fail_unless(
		shader_source.find("char_softness") != -1,
		"HUD laser reticle shader should feather alpha with char_softness"
	)

	_fail_unless(LaserTargetReticleUIScript.frame_index_at(0.0) == 0, "Telegraph start should use frame 0")
	var last_frame := frame_count - 1
	var mid_frame := int(floor(0.5 * float(last_frame)))
	_fail_unless(
		LaserTargetReticleUIScript.frame_index_at(4.0) == mid_frame,
		"Flipbook should advance linearly across the 8 s shrink (midpoint = frame %d)"
		% mid_frame
	)
	_fail_unless(
		LaserTargetReticleUIScript.frame_index_at(8.0) == last_frame,
		"Shrink end should hold the final reticle_1 frame"
	)
	_fail_unless(
		LaserTargetReticleUIScript.frame_index_at(9.0) == last_frame,
		"Blink phase should keep the final reticle_1 frame"
	)

	var reticle := LaserTargetReticleUIScript.new()
	root.add_child(reticle)
	await process_frame
	var flipbook := reticle.get_node_or_null("Flipbook") as TextureRect
	_fail_unless(
		flipbook != null and flipbook.texture_filter == Control.TEXTURE_FILTER_NEAREST,
		"Laser HUD flipbook should use nearest texture filtering"
	)
	_fail_unless(flipbook != null, "Laser HUD reticle should host a Flipbook TextureRect")
	_fail_unless(
		flipbook.material is ShaderMaterial,
		"Laser HUD flipbook should keep hud_laser_reticle shader on the TextureRect"
	)
	_fail_unless(reticle.material == null, "Laser HUD reticle root should not carry flipbook material")
	var snapped := LaserTargetReticleUIScript.flipbook_draw_rect(
		Vector2(100.3, 200.7), frames[0]
	)
	_fail_unless(
		is_equal_approx(snapped.size.x, snapped.size.y),
		"Flipbook draw rect should stay square"
	)
	_fail_unless(
		is_equal_approx(snapped.position.x, roundf(snapped.position.x)),
		"Flipbook draw rect should use integer pixel origin"
	)
	_fail_unless(
		int(snapped.size.x)
		== LaserTargetReticleUIScript.FLIPBOOK_PIXEL_SCALE
		* LaserTargetReticleUIScript.flipbook_texel_size(frames[0]),
		"Flipbook draw rect should scale by whole texel multiples"
	)
	reticle.show_telegraph()
	reticle.update_telegraph(4.0, 0.0, Vector2(960.0, 540.0), true)
	_fail_unless(reticle.visible, "Laser HUD reticle should show when anchor is valid")
	reticle.hide_telegraph()
	_fail_unless(not reticle.visible, "Laser HUD reticle should hide after telegraph ends")
	reticle.queue_free()

	_fail_unless(
		LaserTargetReticleUIScript.frame_index_at(0.0)
		< LaserTargetReticleUIScript.frame_index_at(LaserDroneTelegraphScript.SHRINK_SEC),
		"HUD reticle shrink should come from flipbook frames, not draw-rect scaling"
	)
	_fail_unless(
		is_equal_approx(
			LaserTargetReticleUIScript.flipbook_diameter_px(frames[0]),
			float(LaserTargetReticleUIScript.flipbook_texel_size(frames[0]))
			* LaserTargetReticleUIScript.FLIPBOOK_PIXEL_SCALE
		),
		"HUD flipbook draw size should stay fixed to art texel scale"
	)

	print("Laser target reticle verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
