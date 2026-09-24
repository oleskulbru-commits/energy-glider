extends SceneTree

const GliderAnimClipsScript = preload("res://scripts/player/glider_anim_clips.gd")
const OUT_PATH := "res://resources/anims/glider_anim_state_machine.tres"
const XFADE := 0.5
const XFADE_START := 0.05
const SAIL_XFADE := 0.2
const AIR_XFADE := 0.2
const JUMP_ENTER_XFADE := 0.05
const JUMP_CHARGE_XFADE := 0.5
const STRAFE_BLEND := 0.5


func _initialize() -> void:
	var ease := _make_ease_in_out_curve()
	var locomotion := _build_locomotion_state_machine(ease)
	var boost := _build_boost_state_machine(ease)
	var brake := _build_brake_state_machine(ease)
	var body := _build_body_state_machine(locomotion, boost, brake, ease)
	var sail := _build_sail_state_machine(ease)
	var root := _build_root_blend_tree(body, sail)

	var err := ResourceSaver.save(root, OUT_PATH)
	if err != OK:
		push_error("Failed to save anim tree: %s" % err)
		quit(1)
		return

	_ensure_animation_loops(OUT_PATH, GliderAnimClipsScript.LOOP_LINEAR)

	print("Saved ", OUT_PATH)
	quit(0)


func _build_root_blend_tree(
	body: AnimationNodeStateMachine,
	sail: AnimationNodeStateMachine
) -> AnimationNodeBlendTree:
	# Mast blend filters are applied at runtime on the Blend2 node via GliderAnimLayerFilters.
	var tree := AnimationNodeBlendTree.new()
	var blend := AnimationNodeBlend2.new()
	tree.add_node("body", body, Vector2(0, 0))
	tree.add_node("sail", sail, Vector2(0, 200))
	tree.add_node("blend", blend, Vector2(320, 100))
	tree.connect_node(&"blend", 0, &"body")
	tree.connect_node(&"blend", 1, &"sail")
	tree.connect_node(&"output", 0, &"blend")
	return tree


func _build_body_state_machine(
	locomotion: AnimationNodeStateMachine,
	boost: AnimationNodeStateMachine,
	brake: AnimationNodeStateMachine,
	ease: Curve
) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("grounded", _make_loop_clip("Eve_Idle"), Vector2(0, 0))
	sm.add_node("locomotion", locomotion, Vector2(280, 0))
	sm.add_node("jump_charge", _make_seek_timescaled_clip("Eve_Jump"), Vector2(560, -280))
	sm.add_node("jump", _make_seek_timescaled_clip("Eve_Jump"), Vector2(560, -160))
	sm.add_node("glide", _make_glide_blendspace_clip(), Vector2(840, -160))
	sm.add_node("boost", boost, Vector2(560, 0))
	sm.add_node("brake", brake, Vector2(560, 120))
	sm.add_node("landing", _make_clip("Eve_Land"), Vector2(1120, -160))
	sm.add_node("death", _make_clip("Eve_Idle"), Vector2(1400, 0))

	var body_states := [
		"grounded", "locomotion", "jump_charge", "jump", "glide", "boost", "brake", "landing", "death",
	]
	for from_state in body_states:
		for to_state in body_states:
			if from_state == to_state:
				continue
			var xfade := _body_transition_xfade(from_state, to_state)
			sm.add_transition(from_state, to_state, _make_transition(xfade, ease))

	var start := _make_transition(XFADE_START, ease)
	sm.add_transition("Start", "grounded", start)
	return sm


func _uses_air_xfade(from_state: String, to_state: String) -> bool:
	var air_states := ["jump", "glide", "landing"]
	return from_state in air_states or to_state in air_states


func _body_transition_xfade(from_state: String, to_state: String) -> float:
	if from_state == "landing":
		return XFADE
	if to_state == "jump_charge" and from_state in ["grounded", "locomotion", "boost", "brake"]:
		return JUMP_CHARGE_XFADE
	if from_state == "jump_charge" and to_state in ["grounded", "locomotion", "boost", "brake"]:
		return JUMP_CHARGE_XFADE
	if to_state == "jump" and from_state == "jump_charge":
		return JUMP_ENTER_XFADE
	if to_state == "jump" and from_state in ["grounded", "locomotion", "boost", "brake"]:
		return JUMP_ENTER_XFADE
	if to_state == "locomotion" and from_state == "grounded":
		return JUMP_ENTER_XFADE
	if to_state == "locomotion" and from_state == "brake":
		return AIR_XFADE
	if _uses_air_xfade(from_state, to_state):
		return AIR_XFADE
	return XFADE


func _build_sail_state_machine(ease: Curve) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	# Stowed pose is Sail_Deploy t=0 (time_scale=0); avoids Sail_Down vs Sail_Deploy mismatch pops.
	sm.add_node("sail_down", _make_seek_timescaled_clip("Sail_Deploy"), Vector2(0, 0))
	sm.add_node("deploy_forward", _make_seek_timescaled_clip("Sail_Deploy"), Vector2(280, 0))
	sm.add_node("sail_up", _make_loop_clip("Sail_Up"), Vector2(560, 0))
	sm.add_node("deploy_reverse", _make_seek_timescaled_clip("Sail_Deploy"), Vector2(840, 0))

	sm.add_transition("Start", "sail_down", _make_transition(XFADE_START, ease))

	# deploy_forward→sail_up is driven via travel() in SailAnimController after deploy finishes.

	for from_state in ["sail_down", "deploy_forward", "sail_up", "deploy_reverse"]:
		for to_state in ["sail_down", "deploy_forward", "sail_up", "deploy_reverse"]:
			if from_state == to_state:
				continue
			sm.add_transition(from_state, to_state, _make_transition(SAIL_XFADE, ease))

	return sm


func _build_locomotion_state_machine(ease: Curve) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("enter", _make_clip("Eve_Idle_To_Forward"), Vector2(-280, 0))
	sm.add_node("move", _make_locomotion_blendspace_clip(), Vector2(0, 0))

	sm.add_transition("Start", "enter", _make_transition(XFADE_START, ease))
	sm.add_transition("Start", "move", _make_transition(AIR_XFADE, ease))
	sm.add_transition("enter", "move", _make_auto_end_transition(AIR_XFADE, ease))
	return sm


func _make_glide_blendspace_clip() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var blend_space := AnimationNodeBlendSpace1D.new()
	blend_space.min_space = -1.0
	blend_space.max_space = 1.0
	blend_space.add_blend_point(_make_loop_clip("Eve_Turn_Left"), -1.0)
	blend_space.add_blend_point(_make_loop_clip("Eve_Glide"), 0.0)
	blend_space.add_blend_point(_make_loop_clip("Eve_Turn_Right"), 1.0)
	tree.add_node("blend_space", blend_space, Vector2(0, 0))
	tree.connect_node(&"output", 0, &"blend_space")
	return tree


func _make_locomotion_blendspace_clip() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var blend_space := AnimationNodeBlendSpace2D.new()
	blend_space.min_space = Vector2(-1.0, 0.0)
	blend_space.max_space = Vector2(1.0, 1.0)
	blend_space.sync = true
	blend_space.add_blend_point(_make_loop_clip("Eve_Forward"), Vector2(0.0, 0.0))
	blend_space.add_blend_point(_make_loop_clip("Eve_Forward"), Vector2(0.0, 1.0))
	blend_space.add_blend_point(_make_loop_clip("Eve_Turn_Left"), Vector2(-1.0, 0.0))
	blend_space.add_blend_point(_make_loop_clip("Eve_Turn_Right"), Vector2(1.0, 0.0))
	blend_space.add_blend_point(_make_loop_clip("Eve_Turn_Left"), Vector2(-1.0, 1.0))
	blend_space.add_blend_point(_make_loop_clip("Eve_Turn_Right"), Vector2(1.0, 1.0))
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("blend_space", blend_space, Vector2(0, 0))
	tree.add_node("time_scale", time_scale, Vector2(280, 0))
	tree.connect_node(&"time_scale", 0, &"blend_space")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _build_brake_state_machine(ease: Curve) -> AnimationNodeStateMachine:
	# Swap enter clip to Eve_Forward_To_Brake when that art lands in the GLB.
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("enter", _make_clip("Eve_Forward"), Vector2(0, 0))
	sm.add_node("loop", _make_timescaled_loop_clip("Eve_Boost"), Vector2(280, 0))

	sm.add_transition("Start", "enter", _make_transition(XFADE_START, ease))
	sm.add_transition("enter", "loop", _make_auto_end_transition(AIR_XFADE, ease))

	for from_state in ["enter", "loop"]:
		for to_state in ["enter", "loop"]:
			if from_state == to_state:
				continue
			if from_state == "enter" and to_state == "loop":
				continue
			sm.add_transition(from_state, to_state, _make_transition(AIR_XFADE, ease))

	return sm


func _build_boost_state_machine(ease: Curve) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("enter", _make_clip("Eve_Forward_To_Boost"), Vector2(0, 0))
	sm.add_node("loop", _make_timescaled_loop_clip("Eve_Boost"), Vector2(280, 0))

	sm.add_transition("Start", "enter", _make_transition(XFADE_START, ease))
	sm.add_transition("enter", "loop", _make_auto_end_transition(AIR_XFADE, ease))

	for from_state in ["enter", "loop"]:
		for to_state in ["enter", "loop"]:
			if from_state == to_state:
				continue
			if from_state == "enter" and to_state == "loop":
				continue
			sm.add_transition(from_state, to_state, _make_transition(AIR_XFADE, ease))

	return sm


func _make_timescaled_loop_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_loop_clip(clip_name)
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("time_scale", time_scale, Vector2(240, 100))
	tree.connect_node(&"time_scale", 0, &"clip")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_one_shot_clip(name: String) -> AnimationNodeAnimation:
	var node := _make_clip(name)
	node.loop_mode = Animation.LOOP_NONE
	return node


func _make_timescaled_one_shot_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_one_shot_clip(clip_name)
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("time_scale", time_scale, Vector2(240, 100))
	tree.connect_node(&"time_scale", 0, &"clip")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_strafe_blend_clip(turn_clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var forward := _make_clip("Eve_Forward")
	var turn := _make_clip(turn_clip_name)
	var blend := AnimationNodeBlend2.new()
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("forward", forward, Vector2(0, 0))
	tree.add_node("turn", turn, Vector2(0, 120))
	tree.add_node("blend", blend, Vector2(240, 60))
	tree.add_node("time_scale", time_scale, Vector2(480, 60))
	tree.connect_node(&"blend", 0, &"forward")
	tree.connect_node(&"blend", 1, &"turn")
	tree.connect_node(&"time_scale", 0, &"blend")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_timescaled_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_clip(clip_name)
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("time_scale", time_scale, Vector2(240, 100))
	tree.connect_node(&"time_scale", 0, &"clip")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_seek_timescaled_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_clip(clip_name)
	var seek := AnimationNodeTimeSeek.new()
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("seek", seek, Vector2(240, 100))
	tree.add_node("time_scale", time_scale, Vector2(480, 100))
	tree.connect_node(&"seek", 0, &"clip")
	tree.connect_node(&"time_scale", 0, &"seek")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_loop_clip(name: String) -> AnimationNodeAnimation:
	var node := _make_clip(name)
	node.loop_mode = Animation.LOOP_LINEAR
	return node


func _make_clip(name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node


func _make_ease_in_out_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0), 0.0, 0.0)
	curve.add_point(Vector2(0.5, 0.5), 1.0, 1.0)
	curve.add_point(Vector2(1.0, 1.0), 0.0, 0.0)
	return curve


func _make_transition(xfade: float, curve: Curve = null) -> AnimationNodeStateMachineTransition:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade
	if curve != null:
		transition.xfade_curve = curve
	return transition


func _make_auto_end_transition(xfade: float, curve: Curve = null) -> AnimationNodeStateMachineTransition:
	var transition := _make_transition(xfade, curve)
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	return transition


func _ensure_animation_loops(file_path: String, clip_names: Array) -> void:
	var content := FileAccess.get_file_as_string(file_path)
	for clip_name in clip_names:
		content = _insert_loop_mode_for_clip(content, String(clip_name))
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to patch loop_mode in %s" % file_path)
		return
	file.store_string(content)


func _insert_loop_mode_for_clip(content: String, clip_name: String) -> String:
	var needle := 'animation = &"%s"' % clip_name
	var search_from := 0
	while true:
		var anim_pos := content.find(needle, search_from)
		if anim_pos == -1:
			break
		var header_pos := content.rfind('[sub_resource type="AnimationNodeAnimation"', anim_pos)
		if header_pos == -1:
			search_from = anim_pos + needle.length()
			continue
		var line_end := content.find("\n", anim_pos)
		if line_end == -1:
			break
		var block_end := content.find("\n\n", header_pos)
		if block_end == -1:
			block_end = content.length()
		var block := content.substr(header_pos, block_end - header_pos)
		if "loop_mode" not in block:
			content = content.insert(line_end + 1, "loop_mode = 1\n")
			search_from = line_end + 12
		else:
			search_from = block_end
	return content
