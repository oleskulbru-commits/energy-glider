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
		source.find("draw_rect(") == -1,
		"LaserTargetReticleUI should no longer draw procedural bracket rects"
	)
	_fail_unless(
		source.find("hud_laser_reticle.gdshader") != -1,
		"LaserTargetReticleUI should luminance-key flipbook frames with hud_laser_reticle shader"
	)
	_fail_unless(
		source.find("FLIPBOOK_ART_SCALE") != -1,
		"LaserTargetReticleUI should scale flipbook art to match procedural bracket extent"
	)
	_fail_unless(
		source.find("TEXTURE_FILTER_NEAREST") != -1,
		"LaserTargetReticleUI should draw flipbook frames with nearest filtering"
	)
	_fail_unless(
		source.find("pixel_perfect_flip_rect") != -1,
		"LaserTargetReticleUI should snap flipbook draws to integer pixel blocks"
	)
	_fail_unless(
		source.find("GLOW_STRENGTH := 3.0") != -1,
		"Laser HUD reticle glow should match drone streak strength"
	)
	_fail_unless(ReticleShader != null, "HUD laser reticle shader should load")
	var shader_source := FileAccess.get_file_as_string(
		"res://assets/vfx/shaders/hud_laser_reticle.gdshader"
	)
	_fail_unless(
		shader_source.find("step(char_threshold") != -1,
		"HUD laser reticle shader should use hard luminance keying"
	)
	_fail_unless(
		shader_source.find("char_softness") == -1,
		"HUD laser reticle shader should not feather alpha with char_softness"
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
	_fail_unless(
		reticle.texture_filter == Control.TEXTURE_FILTER_NEAREST,
		"Laser HUD reticle should use nearest texture filtering"
	)
	_fail_unless(reticle.material == null, "Laser HUD reticle should only apply shader material during flipbook draw")
	var snapped := LaserTargetReticleUIScript.pixel_perfect_flip_rect(
		Vector2(100.3, 200.7), 250.4, frames[0]
	)
	_fail_unless(
		is_equal_approx(snapped.size.x, snapped.size.y),
		"Pixel-perfect flipbook rect should stay square"
	)
	_fail_unless(
		is_equal_approx(snapped.position.x, roundf(snapped.position.x)),
		"Pixel-perfect flipbook rect should use integer pixel origin"
	)
	_fail_unless(
		int(snapped.size.x) % int(roundf(frames[0].get_size().x)) == 0,
		"Pixel-perfect flipbook rect should scale by whole texel multiples"
	)
	reticle.show_telegraph()
	reticle.update_telegraph(4.0, 0.0, Vector2(960.0, 540.0), true)
	_fail_unless(reticle.visible, "Laser HUD reticle should show when anchor is valid")
	reticle.hide_telegraph()
	_fail_unless(not reticle.visible, "Laser HUD reticle should hide after telegraph ends")
	reticle.queue_free()

	_fail_unless(
		LaserTargetReticleUIScript.bracket_half_spread(LaserDroneTelegraphScript.START_SCALE)
		> LaserTargetReticleUIScript.bracket_half_spread(LaserDroneTelegraphScript.END_SCALE),
		"HUD reticle extent should shrink over the telegraph"
	)

	print("Laser target reticle verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
